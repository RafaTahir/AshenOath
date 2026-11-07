import copy
import hashlib
from pathlib import Path
import tempfile
import unittest

from verify_living_voice_delivery import verify, resolve_audio


class ExactVoiceDelivery(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.path = self.root / "assets_external/audio/voices/community/exact.ogg"
        self.path.parent.mkdir(parents=True)
        # Codec decoding is supplied independently; these fixture bytes are not
        # a production recording and never enter the runtime resource tree.
        self.path.write_bytes(b"delivery fixture")
        self.row = {"source_id":"community:test", "canonical_speaker":"nera", "text":"Your choice.",
                    "cast_role":"nera", "required_new_or_recipe_changed":True,
                    "text_sha256":hashlib.sha256(b"Your choice.").hexdigest()}
        self.entry = dict(self.row, speaker_id="nera", path="res://" + self.path.relative_to(self.root).as_posix(),
                          audio_sha256=hashlib.sha256(self.path.read_bytes()).hexdigest(), audio_bytes=self.path.stat().st_size,
                          duration_seconds=1.0, speech_envelope_hz=30.0, speech_envelope=[0.0, 0.5, 1.0])
        self.decoded = {"duration_seconds":1.0, "sample_rate":24000, "speech_envelope_hz":30.0, "speech_envelope":[0.0,0.5,1.0]}

    def tearDown(self): self.temporary.cleanup()

    def result(self, entries=None, row=None, decoded=None):
        return verify({"lines":entries if entries is not None else [self.entry]},
                      {"lines":[row or self.row]}, [self.root], lambda value:value,
                      lambda path: decoded or self.decoded)

    def test_exact_delivery_and_caption_provenance(self):
        result = self.result()
        self.assertEqual(result["status"], "pass")
        self.assertFalse(result["listening_acceptance"])
        self.assertFalse(result["gameplay_acceptance"])

    def test_missing_wrong_person_and_stale_text_fail(self):
        for entries in ([], [dict(self.entry, speaker_id="nessa")], [dict(self.entry, text="Different words.")],
                        [dict(self.entry, text_sha256="0" * 64)], [dict(self.entry, cast_role="nessa")]):
            self.assertEqual(self.result(entries)["status"], "fail")

    def test_corrupt_audio_and_stale_envelope_fail(self):
        self.path.write_bytes(b"different fixture")
        self.assertEqual(self.result()["status"], "fail")
        self.path.write_bytes(b"delivery fixture")
        decoded = copy.deepcopy(self.decoded)
        decoded["speech_envelope"][1] = 0.8
        self.assertEqual(self.result(decoded=decoded)["status"], "fail")

    def test_competing_recordings_and_escaping_paths_fail(self):
        duplicate = dict(self.entry, path="res://assets_external/audio/voices/community/other.ogg")
        self.assertEqual(self.result([self.entry, duplicate])["status"], "fail")
        for path in ("res://secrets.ogg", "res://assets_external/audio/voices/../../../../secret.ogg"):
            with self.assertRaises(ValueError): resolve_audio(path, [self.root])


if __name__ == "__main__": unittest.main(verbosity=2)
