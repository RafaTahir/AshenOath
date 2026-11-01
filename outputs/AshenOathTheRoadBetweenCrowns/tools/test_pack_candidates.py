"""Current and historical decoded candidate manifests, using tiny local PCKs."""
import copy
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from deployment_policy import POLICY
from verify_pack_candidates import validate_candidates


class CandidateValidation(unittest.TestCase):
    def setUp(self):
        temp_root = Path("D:/Temp/AshenOath")
        temp_root.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="pack-candidate-fixture-", dir=temp_root)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        records = []
        for pack_id in ["base", "opening", "opening_materials", "adjacent", "campaign", "characters", "monsters", "audio", "quality_materials"]:
            payload = b"GDPCfixture:" + pack_id.encode()
            filename = pack_id + ".pck"
            (self.root / filename).write_bytes(payload)
            records.append({"id":pack_id, "version":"fixture", "artifact":filename, "bytes":len(payload), "sha256":hashlib.sha256(payload).hexdigest()})
        self.manifest = {"schema_version":2, "build_id":"fixture", "packs":records,
                         "deployment_policy_id":POLICY["id"], "max_deployment_bytes":POLICY["max_deployment_bytes"],
                         "total_bytes":sum(pack["bytes"] for pack in records)}

    def test_current_schema2_without_ticket_checks_all_nine_decoded_artifacts(self):
        self.assertNotIn("ticket", self.manifest)
        self.assertEqual([], validate_candidates(self.manifest, self.root, True))

    def test_historical_pack003_schema1_and_implicit_schema_remain_supported(self):
        for explicit in [False, True]:
            manifest = copy.deepcopy(self.manifest)
            manifest["ticket"] = "PACK-003"
            if explicit:
                manifest["schema_version"] = 1
            else:
                del manifest["schema_version"]
            self.assertEqual([], validate_candidates(manifest, self.root, True))

    def test_unknown_schema_and_invalid_lists_are_rejected(self):
        for manifest in [[], {"schema_version":99,"ticket":"PACK-003","packs":[]},
                         {"schema_version":2,"packs":{}}, {"schema_version":2,"packs":[None]}]:
            with self.subTest(manifest=manifest):
                self.assertTrue(validate_candidates(manifest))

    def test_wrong_size_hash_and_magic_each_fail(self):
        for field, value, message in [("bytes",999,"size"), ("sha256","0"*64,"SHA-256 mismatch")]:
            manifest = copy.deepcopy(self.manifest)
            manifest["packs"][0][field] = value
            self.assertIn(message, "; ".join(validate_candidates(manifest, self.root, True)))
        path = self.root / "base.pck"
        path.write_bytes(b"FAIL" + path.read_bytes()[4:])
        self.assertIn("invalid PCK magic", "; ".join(validate_candidates(self.manifest, self.root, True)))

    def test_missing_required_artifact_fails_but_optional_metadata_mode_is_preserved(self):
        (self.root / "monsters.pck").unlink()
        self.assertIn("missing", "; ".join(validate_candidates(self.manifest, self.root, True)))
        self.assertEqual([], validate_candidates(self.manifest, self.root, False))
        self.assertIn("requires --artifact-dir", "; ".join(validate_candidates(self.manifest, None, True)))

    def test_duplicate_ids_and_artifacts_are_rejected(self):
        for field in ["id", "artifact"]:
            manifest = copy.deepcopy(self.manifest)
            manifest["packs"][1][field] = manifest["packs"][0][field]
            self.assertIn("duplicate", "; ".join(validate_candidates(manifest, self.root, True)))

    def test_invalid_size_hash_and_total_metadata_are_rejected(self):
        for field, value, message in [("bytes",-1,"positive integer"), ("bytes","12","positive integer"),
                                      ("sha256","z"*64,"64 hex"), ("sha256",None,"64 hex")]:
            manifest = copy.deepcopy(self.manifest)
            manifest["packs"][0][field] = value
            self.assertIn(message, "; ".join(validate_candidates(manifest, self.root, True)))
        self.manifest["total_bytes"] += 1
        self.assertIn("total_bytes", "; ".join(validate_candidates(self.manifest, self.root, True)))

    def test_artifact_path_escapes_are_rejected_even_in_metadata_mode(self):
        for path in ["../outside.pck", "/outside.pck", "C:/outside.pck", "packs/../../outside.pck", "\\\\host\\outside.pck"]:
            manifest = copy.deepcopy(self.manifest)
            manifest["packs"][0]["artifact"] = path
            self.assertIn("artifact directory", "; ".join(validate_candidates(manifest)))

    def test_decoded_current_policy_is_distinct_from_historical_budget(self):
        self.manifest["max_deployment_bytes"] = 1
        self.assertEqual([], validate_candidates(self.manifest))
        del self.manifest["deployment_policy_id"]
        self.assertIn("exceeds its recorded budget", "; ".join(validate_candidates(self.manifest)))

    def test_cli_accepts_current_schema2_and_fails_corrupted_artifact(self):
        manifest = self.root / "candidates.json"
        manifest.write_text(json.dumps(self.manifest), encoding="utf-8")
        command = [sys.executable,"-B",str(Path(__file__).with_name("verify_pack_candidates.py")),str(manifest),"--artifact-dir",str(self.root),"--require-artifacts"]
        result = subprocess.run(command, capture_output=True, timeout=20)
        self.assertEqual(0, result.returncode, result.stdout.decode(errors="replace"))
        self.assertIn("9 packs", result.stdout.decode())
        (self.root / "opening_materials.pck").write_bytes(b"broken")
        result = subprocess.run(command, capture_output=True, timeout=20)
        self.assertEqual(1, result.returncode)
        self.assertIn("SHA-256 mismatch", result.stdout.decode(errors="replace"))


if __name__ == "__main__":
    unittest.main()
