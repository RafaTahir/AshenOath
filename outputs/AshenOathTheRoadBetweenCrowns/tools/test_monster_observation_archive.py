"""Small, disposable artifact fixtures; no game, source art or engine access."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace
import stat

import archive_monster_observations as archive


class ObservationArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ao-observation-archive-")
        self.root = Path(self.temporary.name)
        self.run = self.root / "run"
        self.run.mkdir()
        self.output = self.root / "archive"
        self.png = b"\x89PNG\r\n\x1a\nfixture-not-a-render"
        (self.run / "selected.png").write_bytes(self.png)
        self.report = {"kind":"fixture", "status":"pass", "visual_acceptance":False,
                       "source_inputs":[{"path":"D:/missing-source.glb", "sha256":"a" * 64}],
                       "rendered_images":[{"path":str(self.run / "selected.png"), "sha256":archive.sha(self.png)}]}
        self.write()

    def tearDown(self):
        self.temporary.cleanup()

    def write(self):
        (self.run / "runner.json").write_text(json.dumps(self.report), encoding="utf-8")

    def invoke(self, images=None, extras=None):
        return archive.archive([("source_preview", "test", self.run)], extras or [], images or [], self.output)

    def test_exact_receipts_source_declarations_and_optional_image(self):
        result = self.invoke([("test", "selected.png")])
        row = result["runs"][0]
        self.assertEqual(row["observed_status"], "passing_observation")
        self.assertEqual((self.output / row["archive_directory"] / "selected.png").read_bytes(), self.png)
        self.assertEqual(row["selected_images"][0]["sha256"], archive.sha(self.png))
        self.assertTrue(row["selected_images"][0]["matched_declared_image_hash"])
        self.assertFalse(result["source_assets_rehashed"])
        self.assertFalse(result["visual_acceptance"])
        self.assertFalse(result["user_acceptance"])
        self.assertEqual((self.output / row["archive_directory"] / "runner.json").read_bytes(), (self.run / "runner.json").read_bytes())

    def test_failed_and_passing_evidence_remains_separate(self):
        self.report["status"] = "fail"
        self.write()
        row = self.invoke()["runs"][0]
        self.assertEqual(row["observed_status"], "failed_diagnostics")
        self.assertTrue(row["archive_directory"].startswith("diagnostics/source_preview/"))

    def test_nested_report_failure_outweighs_runner_pass(self):
        (self.run / "report.json").write_text(json.dumps({"failures":["render cleanup failed"]}), encoding="utf-8")
        self.assertEqual(self.invoke()["runs"][0]["observed_status"], "failed_diagnostics")

    def test_incomplete_not_promoted(self):
        self.report["status"] = "prepared"
        self.write()
        self.assertEqual(self.invoke()["runs"][0]["observed_status"], "incomplete_diagnostics")

    def test_profiles_and_decoded_packs_are_never_copied(self):
        for name in ("profile", "decoded", "isolated_project", ".godot"):
            (self.run / name).mkdir()
            (self.run / name / "private.json").write_text("private", encoding="utf-8")
        self.invoke()
        copied = [path.name for path in self.output.rglob("*")]
        self.assertFalse(any(name in copied for name in ("profile", "decoded", "isolated_project", ".godot", "private.json")))

    def test_profile_selection_rejected_before_output(self):
        with self.assertRaises(ValueError): self.invoke(extras=[("test", "profile/private.json")])
        self.assertFalse(self.output.exists())

    def test_escaped_image_rejected_before_output(self):
        with self.assertRaises(ValueError): self.invoke([("test", "../selected.png")])
        self.assertFalse(self.output.exists())

    def test_selected_image_hash_mismatch_rejected(self):
        (self.run / "selected.png").write_bytes(self.png + b"changed")
        with self.assertRaises(ValueError): self.invoke([("test", "selected.png")])
        self.assertFalse(self.output.exists())

    def test_mixed_pose_and_file_hashes_keep_distinct_meanings(self):
        (self.run / "report.json").write_text(json.dumps({"status":"pass", "frames":[{
            "path":str(self.run / "selected.png"), "pose_sha256":"b" * 64,
            "source_sha256":"c" * 64}]}), encoding="utf-8")
        row = self.invoke([("test", "selected.png")])["runs"][0]
        self.assertTrue(row["selected_images"][0]["matched_declared_image_hash"])
        declarations = [entry for receipt in row["receipts"] for entry in receipt["declared_hashes"]]
        pose = next(entry for entry in declarations if entry["hash_field"] == "pose_sha256")
        self.assertEqual(pose["sha256"], "b" * 64)
        self.assertEqual(pose["hash_role"], "semantic_or_associated")
        content = next(entry for entry in declarations if entry["pointer"] == "/rendered_images/0/sha256")
        self.assertEqual(content["hash_role"], "file_content")

    def test_matching_pose_never_masks_wrong_file_content_digest(self):
        self.report["rendered_images"][0]["sha256"] = "d" * 64
        self.write()
        (self.run / "report.json").write_text(json.dumps({"frames":[{
            "path":str(self.run / "selected.png"), "pose_sha256":archive.sha(self.png)}]}), encoding="utf-8")
        with self.assertRaises(ValueError): self.invoke([("test", "selected.png")])
        self.assertFalse(self.output.exists())

    def test_all_explicit_same_path_content_digests_must_agree(self):
        (self.run / "report.json").write_text(json.dumps({"frames":[{
            "path":str(self.run / "selected.png"), "sha256":"e" * 64,
            "pose_sha256":archive.sha(self.png)}]}), encoding="utf-8")
        with self.assertRaises(ValueError): self.invoke([("test", "selected.png")])
        self.assertFalse(self.output.exists())

    def test_unknown_run_and_duplicate_image_rejected(self):
        for images in ([('unknown', 'selected.png')], [('test', 'selected.png'), ('test', 'selected.png')]):
            with self.assertRaises(ValueError): self.invoke(images)
            self.assertFalse(self.output.exists())

    def test_prior_archive_is_immutable(self):
        self.invoke()
        before = (self.output / "archive.json").read_bytes()
        with self.assertRaises(ValueError): self.invoke()
        self.assertEqual(before, (self.output / "archive.json").read_bytes())

    def test_bounded_receipt_and_only_json_or_log(self):
        (self.run / "large.json").write_bytes(b" " * (archive.MAX_RECEIPT + 1))
        with self.assertRaises(ValueError): self.invoke(extras=[("test", "large.json")])
        with self.assertRaises(ValueError): self.invoke(extras=[("test", "selected.png")])
        self.assertFalse(self.output.exists())

    def test_categories_explicit_and_distinct(self):
        with self.assertRaises(ValueError): archive.archive([("accepted", "test", self.run)], [], [], self.output)
        with self.assertRaises(ValueError): archive.archive([("fixture", "test", self.run), ("publication", "test", self.run)], [], [], self.output)
        self.assertFalse(self.output.exists())

    def test_reparse_root_rejected_before_child_lookup(self):
        original = Path.lstat
        def probe(path, *args, **kwargs):
            if path == self.run:
                return SimpleNamespace(st_mode=stat.S_IFDIR, st_file_attributes=stat.FILE_ATTRIBUTE_REPARSE_POINT)
            if self.run in path.parents:
                self.fail("reparse root must be rejected before looking up children")
            return original(path, *args, **kwargs)
        with patch.object(Path, "lstat", probe), self.assertRaises(ValueError): self.invoke()
        self.assertFalse(self.output.exists())

    def test_total_archive_bound_rejected_before_output(self):
        with patch.object(archive, "MAX_ARCHIVE", 1), self.assertRaises(ValueError): self.invoke()
        self.assertFalse(self.output.exists())


if __name__ == "__main__": unittest.main(verbosity=2)
