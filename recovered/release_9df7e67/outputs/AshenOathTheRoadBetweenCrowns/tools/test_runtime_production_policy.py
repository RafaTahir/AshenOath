"""Production cannot inherit the development fallback allowance."""

import unittest
from pathlib import Path

from verify_runtime_required_components import check_production_roles


class ProductionRolePolicyTests(unittest.TestCase):
    def errors(self, **changes):
        role = {"approved": True, "export_eligible": True, "fallback_mode": "none"}
        role.update(changes)
        errors = []
        check_production_roles({"roles": {"kael": role}}, errors)
        return errors

    def test_approved_role(self):
        self.assertEqual(self.errors(), [])

    def test_unapproved_and_ineligible_roles(self):
        for field in ("approved", "export_eligible"):
            for value in (False, None, "true", "false", 1):
                with self.subTest(field=field, value=value):
                    self.assertTrue(self.errors(**{field: value}))

    def test_diagnostic_fallback_rejected_even_when_approved(self):
        self.assertTrue(self.errors(fallback_mode="diagnostic_only"))
        self.assertTrue(self.errors(fallback_mode=None))

    def test_missing_or_malformed_roles(self):
        for manifest in ({}, {"roles": {}}, {"roles": []}, {"roles": {"kael": None}}):
            with self.subTest(manifest=manifest):
                errors = []
                check_production_roles(manifest, errors)
                self.assertTrue(errors)

    def test_release_runner_selects_production_mode(self):
        source = (Path(__file__).parent / "run_release_gate.ps1").read_text()
        invocation = source.split('Invoke-ExternalGate "verify_runtime_required_components"', 1)[1]
        self.assertIn('"--production"', invocation.split("\n        )", 1)[0])


if __name__ == "__main__":
    unittest.main()
