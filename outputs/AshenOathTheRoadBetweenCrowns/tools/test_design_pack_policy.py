"""Explicit design-pack inclusion remains separate from visual approval."""
import copy
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from verify_runtime_required_components import check_production_roles, check_role, has_design_pack_inclusion


class DesignPackPolicy(unittest.TestCase):
    def candidate(self):
        return {"model":"res://assets_external/design_pack_v1/humans/P01_Kael.glb", "design_id":"P01",
                "source_pack":"AshenOath_32_Asset_Design_Pack_v1", "license_file":"res://assets_external/design_pack_v1/PROVENANCE.md",
                "approved":False, "visual_reviewed":False, "user_accepted":False,
                "inclusion_authorized":True, "export_eligible":True, "authorization_kind":"user_requested_live_roster_release",
                "status":"user_authorized_release_candidate", "fallback_mode":"none"}

    def test_both_registered_authorization_kinds_preserve_review_flags(self):
        for kind in ["user_requested_blender_cast_replacement", "user_requested_live_roster_release"]:
            role = self.candidate()
            role["authorization_kind"] = kind
            before = copy.deepcopy(role)
            errors = []
            check_production_roles({"roles":{"candidate":role}}, errors)
            self.assertEqual([], errors)
            self.assertTrue(has_design_pack_inclusion(role))
            self.assertEqual(before, role)
            self.assertIs(role["approved"], False)
            self.assertIs(role["visual_reviewed"], False)
            self.assertIs(role["user_accepted"], False)

    def test_invalid_authorization_flags_source_and_model_scope_cannot_borrow_inclusion(self):
        changes = [("inclusion_authorized",False), ("inclusion_authorized","true"), ("inclusion_authorized",1),
                   ("export_eligible",False), ("export_eligible","true"), ("export_eligible",1),
                   ("authorization_kind",""), ("authorization_kind","unregistered_authorization"), ("source_pack","other"),
                   ("approved","false"), ("visual_reviewed",1),
                   ("model","res://assets_external/characters/Old.glb"),
                   ("model","res://assets_external/design_pack_v1/../Other.glb"),
                   ("model","res://assets_external/design_pack_v1/humans/./Other.glb"),
                   ("model","res://assets_external/design_pack_v1//Other.glb"),
                   ("model","res://assets_external/design_pack_v1/Other.fbx")]
        for field, value in changes:
            with self.subTest(field=field, value=value):
                role = self.candidate()
                role[field] = value
                errors = []
                check_production_roles({"roles":{"candidate":role}}, errors)
                self.assertFalse(has_design_pack_inclusion(role))
                self.assertTrue(errors)

    def fixture(self, project):
        role = self.candidate()
        model = project / role["model"].removeprefix("res://")
        model.parent.mkdir(parents=True)
        model.write_bytes(b"authored design source fixture")
        license_path = project / role["license_file"].removeprefix("res://")
        license_path.write_text("Retained source and derivative license/provenance", encoding="utf-8")
        digest = hashlib.sha256(model.read_bytes()).hexdigest()
        role["runtime_files"] = [{"path":role["model"], "bytes":model.stat().st_size, "sha256":digest}]
        ledger = {"assets":{"P01":{"path":role["model"],"bytes":model.stat().st_size,"sha256":digest}}}
        (project / "data").mkdir()
        (project / "data/design_pack_assets.json").write_text(json.dumps(ledger), encoding="utf-8")
        return role, ledger

    def test_current_design_role_schema_checks_local_hashes_without_fabricating_download_url(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            role, _ledger = self.fixture(project)
            self.assertNotIn("family", role)
            self.assertNotIn("source_url", role)
            before = copy.deepcopy(role)
            errors, blocked = [], []
            check_role(project, "candidate", role, blocked, errors)
            self.assertEqual([], errors)
            self.assertEqual([], blocked)
            self.assertEqual(before, role)

    def test_design_identity_and_exported_artifact_hashes_remain_required(self):
        for mutation in ["identity", "ledger_hash", "artifact_hash", "artifact_size", "model_binding", "license"]:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                project = Path(directory)
                role, ledger = self.fixture(project)
                if mutation == "identity":
                    role["design_id"] = "M99"
                elif mutation == "ledger_hash":
                    ledger["assets"]["P01"]["sha256"] = "a" * 64
                    (project / "data/design_pack_assets.json").write_text(json.dumps(ledger), encoding="utf-8")
                elif mutation == "artifact_hash":
                    role["runtime_files"][0]["sha256"] = "b" * 64
                elif mutation == "artifact_size":
                    role["runtime_files"][0]["bytes"] += 1
                elif mutation == "model_binding":
                    role["runtime_files"][0]["path"] = role["license_file"]
                elif mutation == "license":
                    role["license_file"] = "res://../outside-license.md"
                errors = []
                check_role(project, "candidate", role, [], errors)
                self.assertTrue(errors)


if __name__ == "__main__":
    unittest.main()
