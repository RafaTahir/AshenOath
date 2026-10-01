#!/usr/bin/env python3
"""Deliberate-failure tests; all scratch data remains on D:, not Windows TEMP."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from capture_visual_provenance import begin_capture, finish_capture
from verify_screenshot_qa_003 import verify_view
from visual_evidence import REVIEW_CHECKS, capture_identity_error, file_sha256, needs_input_digest, rendering_inputs_sha256, review_error


class VisualEvidenceTests(unittest.TestCase):
    def setUp(self) -> None:
        base = Path("D:/Temp/AshenOath").resolve()
        base.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="ashen-oath-qa003-", dir=base)
        self.project = Path(self.temporary.name).resolve()
        self.assertTrue(self.project.is_relative_to(base))
        (self.project / "scripts").mkdir()
        (self.project / "scripts" / "test.gd").write_text("extends Node\n", encoding="utf-8")
        (self.project / "assets_external").mkdir()
        self.asset = self.project / "assets_external" / "actor.glb"
        self.asset.write_bytes(b"body1")
        self.gallery = self.project / "Development_Gallery" / "screenshots"
        self.gallery.mkdir(parents=True)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _capture(self) -> Path:
        self.session = begin_capture(self.project, "controlled_test_capture")
        image = self.gallery / "Capture_test.png"
        Image.new("RGB", (1280, 720), (45, 80, 120)).save(image)
        self.assertEqual([image.name], finish_capture(self.project, self.session))
        return image

    def test_fresh_capture_binds_image_and_rendering_bytes(self) -> None:
        image = self._capture()
        self.assertIsNone(capture_identity_error(image, rendering_inputs_sha256(self.project)))

    def test_asset_change_with_preserved_mtime_and_length_is_rejected(self) -> None:
        image = self._capture()
        stat = self.asset.stat()
        self.asset.write_bytes(b"body2")
        os.utime(self.asset, ns=(stat.st_atime_ns, stat.st_mtime_ns))
        self.assertIn("differ", capture_identity_error(image, rendering_inputs_sha256(self.project)))

    def test_role_change_is_rejected(self) -> None:
        role = self.project / "character_role_manifest.json"
        role.write_text('{"kael":"approved"}', encoding="utf-8")
        image = self._capture()
        role.write_text('{"kael":"fallback"}', encoding="utf-8")
        self.assertIn("differ", capture_identity_error(image, rendering_inputs_sha256(self.project)))

    def test_source_change_during_capture_never_creates_sidecars(self) -> None:
        session = begin_capture(self.project, "controlled_test_capture")
        image = self.gallery / "Capture_test.png"
        Image.new("RGB", (1280, 720)).save(image)
        self.asset.write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "changed while"):
            finish_capture(self.project, session)
        self.assertFalse(image.with_suffix(".png.capture.json").exists())

    def test_old_gallery_cannot_be_rebound_as_a_fresh_capture(self) -> None:
        self._capture()
        session = begin_capture(self.project, "capture_that_produced_nothing")
        with self.assertRaisesRegex(ValueError, "no fresh"):
            finish_capture(self.project, session)

    def test_missing_sidecar_and_changed_image_fail(self) -> None:
        image = self._capture()
        image.write_bytes(b"tampered PNG")
        self.assertIn("screenshot bytes", capture_identity_error(image, rendering_inputs_sha256(self.project)))
        image.with_suffix(".png.capture.json").unlink()
        self.assertIn("missing or invalid", capture_identity_error(image, rendering_inputs_sha256(self.project)))

    def test_semantic_review_requires_all_inspection_notes(self) -> None:
        view = {"reviewer": "Codex", "review_checks": {name: {"verdict": "accepted", "note": "Controlled review test"} for name in REVIEW_CHECKS}}
        self.assertIsNone(review_error(view))
        view["review_checks"]["anatomy"]["verdict"] = "rejected"
        self.assertIn("anatomy", review_error(view))
        view["review_checks"]["anatomy"]["verdict"] = "accepted"
        view["review_checks"]["anatomy"]["note"] = ""
        self.assertIn("inspection note", review_error(view))

    def _reviewed_view(self, image: Path) -> dict:

        return {"id": "fixture", "current_glob": image.name, "required": True,
                "status": "approved", "reviewer": "Codex", "note": "Controlled test, not a game approval",
                "expected_size": [1280, 720], "approved_sha256": file_sha256(image),
                "review_checks": {name: {"verdict": "accepted", "note": "Controlled test inspection"} for name in REVIEW_CHECKS}}

    def test_normal_mode_never_uses_dry_run_to_accept_a_blank_frame(self) -> None:
        image = self._capture()
        Image.new("RGB", (1280, 720), (0, 0, 0)).save(image)
        record_path = image.with_suffix(".png.capture.json")
        record = json.loads(record_path.read_text(encoding="utf-8"))
        record["image_sha256"] = file_sha256(image)
        record_path.write_text(json.dumps(record), encoding="utf-8")
        result = verify_view(self._reviewed_view(image), self.gallery, None, None, True, "milestone", False, True,
                             rendering_inputs_sha256(self.project))
        self.assertEqual("fail", result.status)
        self.assertIn("black", result.message)

    def test_full_gate_accepts_complete_current_fixture_and_rejects_missing_review(self) -> None:
        session = begin_capture(self.project, "controlled_test_capture")
        image = self.gallery / "Capture_pattern.png"
        frame = Image.new("RGB", (1280, 720), (35, 60, 95))
        for x in range(400, 900):
            for y in range(250, 650):
                frame.putpixel((x, y), (130, 85, 55))
        frame.save(image)
        finish_capture(self.project, session)
        view = self._reviewed_view(image)
        digest = rendering_inputs_sha256(self.project)
        self.assertTrue(needs_input_digest(self.gallery, [view]))
        result = verify_view(view, self.gallery, None, None, True, "milestone", False, True, digest)
        self.assertEqual("pass", result.status, result.message)
        del view["review_checks"]["grounding"]
        rejected = verify_view(view, self.gallery, None, None, True, "milestone", False, True, digest)
        self.assertEqual("fail", rejected.status)
        self.assertIn("grounding", rejected.message)
        self.assertFalse(needs_input_digest(self.gallery, [view]))

    def test_dry_run_report_is_never_release_success(self) -> None:
        image = self._capture()
        manifest = {"schema_version": 1, "policy": {"visual_review": "codex"}, "views": [
            {"id": "fixture", "current_glob": image.name, "required": True,
             "status": "approved", "reviewer": "Codex", "note": "Controlled dry-run test",
             "approved_sha256": file_sha256(image)}]}
        manifest_path = self.project / "manifest.json"
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        report_path = self.project / "dry-run.json"
        result = subprocess.run([sys.executable, str(Path(__file__).with_name("verify_screenshot_qa_003.py")),
                                 str(self.project), "--manifest", str(manifest_path), "--mode", "milestone",
                                 "--dry-run", "--report", str(report_path)], capture_output=True, text=True, timeout=15)
        self.assertEqual(0, result.returncode, result.stderr + result.stdout)
        self.assertNotIn("PASS", result.stdout)
        self.assertEqual("plan", json.loads(report_path.read_text(encoding="utf-8"))["status"])

    def test_approved_perceptual_baseline_rejects_a_changed_frame(self) -> None:
        image = self._capture()
        # Deliberately different fixture; this is not artistic game approval.
        baseline = self.gallery.parent / "baseline.png"
        Image.new("RGB", (1280, 720), (180, 50, 30)).save(baseline)
        view = self._reviewed_view(image)
        view["heuristics"] = {"min_channel_variance": 0}
        view["baseline"] = {"path": "baseline.png", "status": "approved", "reviewer": "Codex",
                            "note": "Controlled pixel-difference fixture", "max_mean_absolute_difference": 5.0}
        result = verify_view(view, self.gallery, None, None, True, "milestone", False, True,
                             rendering_inputs_sha256(self.project))
        self.assertEqual("fail", result.status)
        self.assertIn("exceeds", result.message)

    def test_pending_review_cannot_pass_milestone(self) -> None:
        image = self._capture()
        view = self._reviewed_view(image)
        view["status"] = "pending"
        result = verify_view(view, self.gallery, None, None, True, "milestone", False, True,
                             rendering_inputs_sha256(self.project))
        self.assertEqual("fail", result.status)
        self.assertIn("lacks approval", result.message)

    def test_rejected_review_is_not_misreported_as_changed_source(self) -> None:
        image = self._capture()
        view = self._reviewed_view(image)
        view["status"] = "rejected"
        manifest_path = self.project / "manifest.json"
        manifest_path.write_text(json.dumps({"schema_version": 1, "capture_source_revision": "fixture",
                                            "policy": {"visual_review": "codex"}, "views": [view]}), encoding="utf-8")
        report_path = self.project / "rejected.json"
        result = subprocess.run([sys.executable, str(Path(__file__).with_name("verify_qa_006.py")),
                                 str(self.project), "--manifest", str(manifest_path), "--report", str(report_path)],
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(1, result.returncode, result.stderr + result.stdout)
        report = json.loads(report_path.read_text(encoding="utf-8"))
        self.assertEqual("skipped_ineligible_reviews", report["capture_identity_check"])
        self.assertIn("review status: rejected", result.stdout)
        self.assertNotIn("differ from current", result.stdout)


if __name__ == "__main__":
    unittest.main()
