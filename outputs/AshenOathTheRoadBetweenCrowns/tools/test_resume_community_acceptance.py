"""Prepare actual isolated fixture receipts; never launch an engine."""
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import run_community_acceptance as common
from test_community_acceptance_packs import candidate
from test_community_acceptance_runner import seed


class PreparedAcceptanceResumeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.folder = Path(self.temp.name)
        root, packs, release = candidate(self.folder)
        cache = self.folder / "classes.cfg"
        cache.write_bytes(b'list=[]\n')
        engine = self.folder / "never-launched-engine.exe"
        engine.write_bytes(b"fixture executable identity only")
        source = self.folder / "boundary.json"
        source.write_text(json.dumps(seed("lantern_crossing")), encoding="utf-8")
        self.args = SimpleNamespace(root_pack=root, packs=packs, release_manifest=release,
                                    godot=engine, class_cache=cache, seed_save=source, case="lantern_crossing",
                                    output=self.folder / "run", viewport="desktop", timeout=60)

    def tearDown(self):
        self.temp.cleanup()

    def prepare(self, **kwargs):
        def git(*arguments):
            if arguments[0] == "rev-parse":
                return b"a" * 40
            if arguments[0] == "show":
                return b'[application]\nconfig/name="Fixture"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
            return b""
        with patch.object(common, "git", git):
            return common.prepare(self.args, **kwargs)

    def test_resumes_unchanged_never_started_seeded_receipt(self):
        receipt, path = self.prepare()
        loaded = common.load_prepared(path)
        self.assertEqual(loaded, receipt)
        self.assertEqual(loaded["status"], "prepared")
        self.assertEqual([row["path"] for row in loaded["initial_profile_files"]], ["ashen_oath_save.json"])

    def test_modified_seed_profile_or_previously_started_run_cannot_resume(self):
        receipt, path = self.prepare()
        saved = Path(receipt["expected_user_data_dir"]) / "ashen_oath_save.json"
        saved.write_text("changed since prepare")
        with self.assertRaisesRegex(ValueError, "profile changed"):
            common.load_prepared(path)
        for status in ["running", "pass", "fail"]:
            receipt["status"] = status
            common.write(path, receipt)
            with self.assertRaisesRegex(ValueError, "never-started"):
                common.load_prepared(path)

    def test_changed_frozen_input_rejected_before_process_creation(self):
        receipt, path = self.prepare()
        entry = Path(receipt["isolated_project"]) / "tools/verify_community_world_input.gd"
        entry.write_text("changed fixture")
        with self.assertRaisesRegex(ValueError, "frozen input changed"):
            common.load_prepared(path)

    def test_empty_new_game_profile_stays_empty_until_launch(self):
        self.args.seed_save = None
        receipt, path = self.prepare(allow_no_seed=True, seed_contract={"suite":"full_campaign", "expected_work":[]})
        self.assertEqual(receipt["initial_profile_files"], [])
        self.assertEqual(common.load_prepared(path)["initial_profile_files"], [])
        (Path(receipt["expected_user_data_dir"]) / "unexpected_save.json").write_text("{}")
        with self.assertRaisesRegex(ValueError, "profile changed"):
            common.load_prepared(path)

    def test_redirecting_prepared_profile_is_rejected(self):
        receipt, path = self.prepare()
        receipt["environment"]["APPDATA"] = str(self.folder)
        common.write(path, receipt)
        with self.assertRaisesRegex(ValueError, "disposable profile"):
            common.load_prepared(path)


if __name__ == "__main__":
    unittest.main()
