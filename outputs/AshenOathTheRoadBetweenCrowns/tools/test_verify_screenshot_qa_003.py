#!/usr/bin/env python3
"""Small QA-003 regression suite using committed gallery screenshots."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]
VERIFIER_PATH = PROJECT / "tools" / "verify_screenshot_qa_003.py"
SPEC = importlib.util.spec_from_file_location("qa_003", VERIFIER_PATH)
assert SPEC and SPEC.loader
QA_003 = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = QA_003
SPEC.loader.exec_module(QA_003)


class ScreenshotQa003Tests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest_path = PROJECT / "Development_Gallery" / "qa_003_approval_manifest.json"
        self.manifest = json.loads(self.manifest_path.read_text(encoding="utf-8"))
        self.gallery = PROJECT / "Development_Gallery" / "screenshots"

    def test_current_gallery_resolves_all_required_views(self) -> None:
        views = QA_003.selected_views(self.manifest, None)
        required = [view for view in views if view["required"]]
        self.assertTrue(required)
        for view in required:
            self.assertIsNotNone(QA_003.newest_match(self.gallery, view["current_glob"]), view["id"])

    def test_identical_approved_baseline_has_zero_difference(self) -> None:
        image = QA_003.newest_match(self.gallery, "Capture_01_greyfen_spawn_*.png")
        self.assertIsNotNone(image)
        self.assertEqual(0.0, QA_003.mean_absolute_difference(image, image))

    def test_milestone_policy_requires_human_approval(self) -> None:
        view = self.manifest["views"][0]
        source = max(QA_003.resolve_source_paths(PROJECT, self.manifest), key=lambda path: path.stat().st_mtime_ns)
        result = QA_003.verify_view(view, self.gallery, source, None, True, "milestone", False)
        self.assertEqual("fail", result.status)
        self.assertIn("lacks approval", result.message)

    def test_ticket_policy_allows_pending_changed_view(self) -> None:
        view = self.manifest["views"][0]
        source = max(QA_003.resolve_source_paths(PROJECT, self.manifest), key=lambda path: path.stat().st_mtime_ns)
        result = QA_003.verify_view(view, self.gallery, source, None, True, "ticket", False)
        self.assertEqual("pass", result.status)
        self.assertEqual("pending human review", result.message)

    def test_approved_view_requires_reviewer_and_note(self) -> None:
        view = dict(self.manifest["views"][0])
        view["status"] = "approved"
        source = max(QA_003.resolve_source_paths(PROJECT, self.manifest), key=lambda path: path.stat().st_mtime_ns)
        result = QA_003.verify_view(view, self.gallery, source, None, True, "milestone", False)
        self.assertEqual("fail", result.status)
        self.assertIn("reviewer and note", result.message)


if __name__ == "__main__":
    unittest.main()
