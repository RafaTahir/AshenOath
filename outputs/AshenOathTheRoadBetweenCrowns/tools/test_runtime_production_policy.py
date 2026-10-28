"""Production cannot inherit the development fallback allowance."""

import unittest
import copy
import hashlib
import tempfile
from pathlib import Path

from verify_runtime_required_components import check_production_roles, check_role


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

    def spectral(self):
        return {"family":"monster", "status":"spectral_inclusion_authorized_visual_review_pending", "approved":False, "visual_reviewed":False,
            "inclusion_authorized":True, "export_eligible":True, "authorization_kind":"user_requested_creation_and_in_game_application",
            "source_pack":"ashenoath_spectral_bestiary", "model":"res://assets_external/enemies/spectral/Candidate.gltf", "fallback_mode":"none",
            "source_url":"https://github.com/RafaTahir/AshenOath", "license_file":"res://assets_external/licenses/CC0.txt",
            "provenance":{"source":"res://assets_external/enemies/Original.glb", "source_sha256":"a"*64,
                "license_file":"res://assets_external/licenses/CC0.txt", "license_sha256":"b"*64}}

    def test_explicit_spectral_inclusion_does_not_claim_visual_review(self):
        role = self.spectral()
        errors = []
        check_production_roles({"roles":{"candidate":role}}, errors)
        self.assertEqual(errors, [])
        self.assertIs(role["approved"], False)
        self.assertIs(role["visual_reviewed"], False)

    def test_spectral_authorization_cannot_override_scope_and_provenance(self):
        for field, value in [("inclusion_authorized",False),("inclusion_authorized","true"),("inclusion_authorized",1),
                ("export_eligible",False),("export_eligible",1),("authorization_kind",""),("source_pack","other"),
                ("model","res://assets_external/enemies/Original.glb"),("provenance",{}),("visual_reviewed",None)]:
            with self.subTest(field=field, value=value):
                role = self.spectral()
                role[field] = value
                errors = []
                check_production_roles({"roles":{"candidate":role}}, errors)
                self.assertTrue(errors)

    def test_spectral_inclusion_preserves_source_and_license_hash_checks(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            role = self.spectral()
            paths = [role["model"],role["provenance"]["source"],role["license_file"]]
            for resource in paths:
                path = project / resource.removeprefix("res://")
                path.parent.mkdir(parents=True,exist_ok=True)
                path.write_text(resource)
            def digest(resource):
                return hashlib.sha256((project / resource.removeprefix("res://")).read_bytes()).hexdigest()
            role["provenance"]["source_sha256"] = digest(role["provenance"]["source"])
            role["provenance"]["license_sha256"] = digest(role["license_file"])
            model = project / role["model"].removeprefix("res://")
            role["runtime_files"] = [{"path":role["model"],"bytes":model.stat().st_size,"sha256":digest(role["model"])}]
            errors = []
            check_role(project,"candidate",role,[],errors)
            self.assertEqual(errors,[])
            for resource, expected in [(role["provenance"]["source"],"source"),(role["license_file"],"license")]:
                path = project / resource.removeprefix("res://")
                original = path.read_bytes()
                path.write_bytes(original + b"changed")
                errors = []
                check_role(project,"candidate",role,[],errors)
                self.assertTrue(any(expected + " SHA-256" in error for error in errors),errors)
                path.write_bytes(original)


if __name__ == "__main__":
    unittest.main()
