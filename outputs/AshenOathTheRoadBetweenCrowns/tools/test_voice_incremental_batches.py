"""Exercise bounded production and resume with real codecs and stub inference.

Run with the pinned voice runtime on PYTHONPATH. The fixture never loads a model,
downloads files, or writes into the game's production assets.
"""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest import mock

import natural_story_voices as voices

try:
    import numpy as np
    import soundfile as sf
except ImportError:
    np = sf = None


@unittest.skipIf(np is None or sf is None, "requires the pinned voice codec runtime")
class IncrementalVoiceBatch(unittest.TestCase):
    def test_changed_recipe_remains_pending_until_its_own_new_recording(self):
        self.check_resumable_batch(["--max-new-recordings", "1"], "bounded_batch_limit")

    def test_elapsed_limit_finalizes_the_completed_recording(self):
        self.check_resumable_batch(["--max-inference-seconds", "2"], "bounded_inference_time", [0, 1, 3])

    def check_resumable_batch(self, first_limits, expected_reason, first_clock=None):
        with tempfile.TemporaryDirectory(prefix="ashen-voice-batch-fixture-") as folder:
            game = Path(folder)
            (game / "data").mkdir()
            profile = {"voices":{"new_voice":1.0}, "lang":"en-us", "speed":1.0}
            cast = {"revision":"fixture-2", "model":"fixture-model", "roles":{"nera":profile}}
            (game / "data/voice_cast.json").write_text(json.dumps(cast), encoding="utf-8")
            scheduled = [("community:fixture:one", "nera", "First exact line.", "nera", ""),
                         ("community:fixture:two", "nera_alias", "Second exact line.", "nera", "")]
            old_rows = []
            for number, (_, speaker, text, _, _) in enumerate(scheduled):
                path = game / f"assets_external/audio/voices/community/old_{number}.ogg"
                path.parent.mkdir(parents=True, exist_ok=True)
                sf.write(path, np.zeros(240, dtype=np.float32), 24000, format="OGG", subtype="VORBIS")
                old_rows.append({"speaker_id":speaker, "cast_role":"nera", "text":text,
                                 "text_sha256":hashlib.sha256(text.encode()).hexdigest(),
                                 "page_key":f"old_{number}", "path":"res://" + path.relative_to(game).as_posix(),
                                 "audio_sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
            manifest_path = game / "voice_production_manifest.json"
            manifest_path.write_text(json.dumps({"roles":{"nera":dict(profile, voices={"old_voice":1.0})},
                                                "lines":old_rows}), encoding="utf-8")
            generated = []

            class Engine:
                def get_voice_style(self, name):
                    return np.ones(4, dtype=np.float32)

                def create(self, text, **kwargs):
                    generated.append(text)
                    samples = np.sin(np.arange(2400, dtype=np.float32) * 0.1) * 0.1
                    return samples, 24000

            ort = types.ModuleType("onnxruntime")
            ort.__version__ = "fixture-no-inference"
            ort.SessionOptions = types.SimpleNamespace
            ort.InferenceSession = lambda *args, **kwargs: object()
            kokoro = types.ModuleType("kokoro_onnx")
            kokoro.Kokoro = types.SimpleNamespace(from_session=lambda *args: Engine())

            def fixture_download(url, path):
                path.parent.mkdir(parents=True, exist_ok=True)
                if not path.exists():
                    path.write_bytes(b"fixture only; not a model or attribution source")

            argv = ["natural_story_voices.py", "--runtime", str(game / "runtime"),
                    "--models", str(game / "models"), "--incremental", "--max-new-recordings", "1"]
            with contextlib.ExitStack() as patches:
                patches.enter_context(mock.patch.object(voices, "GAME", game))
                patches.enter_context(mock.patch.object(voices, "REPO", game))
                patches.enter_context(mock.patch.object(voices, "utterances", lambda cast: iter(scheduled)))
                patches.enter_context(mock.patch.object(voices, "canonical_speaker", lambda game, who: "nera"))
                patches.enter_context(mock.patch.object(voices, "download", fixture_download))
                patches.enter_context(mock.patch.dict(sys.modules, {"onnxruntime":ort, "kokoro_onnx":kokoro}))
                patches.enter_context(mock.patch.object(sys, "argv", argv))
                patches.enter_context(mock.patch.object(sys, "path", list(sys.path)))
                patches.enter_context(contextlib.redirect_stdout(io.StringIO()))
                with mock.patch.object(sys, "argv", argv[:-2] + first_limits):
                    clock = mock.patch.object(voices, "monotonic", side_effect=first_clock) if first_clock else contextlib.nullcontext()
                    with clock:
                        voices.main()
                first = json.loads(manifest_path.read_text(encoding="utf-8"))
                self.assertEqual(generated, ["First exact line."])
                self.assertEqual([line["text"] for line in first["lines"]], ["First exact line."])
                self.assertEqual(len(first["pending_recordings"]), 1)
                self.assertEqual(first["pending_recordings"][0]["reason"], expected_reason)
                original_path = game / first["lines"][0]["path"][6:]
                first_hash = hashlib.sha256(original_path.read_bytes()).hexdigest()
                voices.main()
                second = json.loads(manifest_path.read_text(encoding="utf-8"))
                self.assertEqual(generated, ["First exact line.", "Second exact line."])
                self.assertEqual(second["pending_recordings"], [])
                self.assertEqual(second["synthesized_this_run"], 1)
                self.assertEqual(second["retained_previous_recordings"], 1)
                self.assertEqual(len(second["lines"]), 2)
                self.assertEqual(hashlib.sha256(original_path.read_bytes()).hexdigest(), first_hash)
                self.assertTrue(all(line["speaker_id"] == "nera" for line in second["lines"]))
                self.assertTrue(all("old_" not in line["path"] for line in second["lines"]))
                self.assertFalse(manifest_path.with_suffix(".json.partial").exists())
                voices.main()
                third = json.loads(manifest_path.read_text(encoding="utf-8"))
                self.assertEqual(third["synthesized_this_run"], 0)
                self.assertEqual(third["retained_previous_recordings"], 2)
                self.assertEqual(len(generated), 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
