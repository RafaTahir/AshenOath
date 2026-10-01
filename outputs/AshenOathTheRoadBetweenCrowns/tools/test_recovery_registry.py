"""Registry-state tests only; these do not certify security or visual quality."""

import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch


PROJECT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("registry_gate", PROJECT / "tools/verify_recovery_004.py")
GATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GATE)
BASELINE = json.loads((PROJECT / "RECOVERY_004_ISSUE_REGISTRY.json").read_text(encoding="utf-8"))


class RegistryTests(unittest.TestCase):
    def run_gate(self, registry):
        with patch.object(sys, "argv", ["verify_recovery_004.py", str(PROJECT)]), \
                patch.object(GATE.json, "loads", return_value=registry), \
                contextlib.redirect_stdout(io.StringIO()):
            return GATE.main()

    def test_current_registry(self):
        self.assertEqual(self.run_gate(copy.deepcopy(BASELINE)), 0)

    def test_visual_review_can_complete(self):
        registry = copy.deepcopy(BASELINE)
        next(ticket for ticket in registry["tickets"] if ticket["id"] == "QA-006")["status"] = "verified"
        self.assertEqual(self.run_gate(registry), 0)

    def test_security_regression_can_be_recorded_truthfully(self):
        registry = copy.deepcopy(BASELINE)
        next(ticket for ticket in registry["tickets"] if ticket["id"] == "SECURITY-001")["status"] = "in_progress"
        self.assertEqual(self.run_gate(registry), 0)

    def test_unknown_status_is_rejected(self):
        registry = copy.deepcopy(BASELINE)
        registry["tickets"][0]["status"] = "pretend-pass"
        self.assertEqual(self.run_gate(registry), 1)

    def test_missing_ticket_is_rejected(self):
        registry = copy.deepcopy(BASELINE)
        registry["tickets"] = [ticket for ticket in registry["tickets"] if ticket["id"] != "QA-006"]
        self.assertEqual(self.run_gate(registry), 1)

    def test_current_plan_cannot_silently_shrink(self):
        registry = copy.deepcopy(BASELINE)
        del registry["current_program"]["acceptance"]["RELEASE-001"]
        self.assertEqual(self.run_gate(registry), 1)

    def test_historical_completion_does_not_change_current_acceptance(self):
        registry = copy.deepcopy(BASELINE)
        next(ticket for ticket in registry["tickets"] if ticket["id"] == "RUNTIME-001")["status"] = "verified"
        self.assertEqual(registry["current_program"]["acceptance"]["RUNTIME-001"], "accepted")
        self.assertEqual(self.run_gate(registry), 0)

    def test_current_acceptance_requires_evidence(self):
        registry = copy.deepcopy(BASELINE)
        registry["current_program"]["acceptance"]["RELEASE-001"] = "accepted"
        self.assertEqual(self.run_gate(registry), 1)

    def test_malformed_current_acceptance_rejected(self):
        registry = copy.deepcopy(BASELINE)
        registry["current_program"]["acceptance"] = []
        self.assertEqual(self.run_gate(registry), 1)


if __name__ == "__main__":
    unittest.main()
