import hashlib
import tempfile
import unittest
from pathlib import Path

from verify_web_export import verify_pack_files


class PackCompleteness(unittest.TestCase):
    def setUp(self):
        temp_root = Path("D:/Temp/AshenOath")
        temp_root.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="pack-completeness-", dir=temp_root)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "packs").mkdir()
        self.payload = b"GDPCfixture"
        self.pack = {"url": "packs/opening.pck?v=test", "status": "streamed_web_candidate",
                     "bytes": len(self.payload), "sha256": hashlib.sha256(self.payload).hexdigest(),
                     "dependencies": ["base"]}
        self.manifest = {"packs": {"base": {"status": "embedded_current_pck", "url": ""}, "opening": self.pack}}

    def write_pack(self):
        (self.root / "packs/opening.pck").write_bytes(self.payload)

    def test_missing_pack_fails(self):
        self.assertIn("missing required pack", " ".join(verify_pack_files(self.root, self.manifest)))

    def test_valid_pack_passes(self):
        self.write_pack()
        self.assertEqual([], verify_pack_files(self.root, self.manifest))

    def test_corrupt_pack_fails(self):
        self.write_pack()
        (self.root / "packs/opening.pck").write_bytes(b"broken")
        errors = " ".join(verify_pack_files(self.root, self.manifest))
        self.assertIn("byte count", errors)
        self.assertIn("SHA-256", errors)

    def test_escape_fails(self):
        self.pack["url"] = "packs/%2e%2e/elsewhere.pck"
        self.assertIn("inside exported packs", " ".join(verify_pack_files(self.root, self.manifest)))

    def test_unknown_dependency_fails(self):
        self.write_pack()
        self.pack["dependencies"] = ["absent"]
        self.assertIn("unknown dependency", " ".join(verify_pack_files(self.root, self.manifest)))

    def test_conflicting_ownership_fails(self):
        self.pack["status"] = "embedded_current_pck"
        self.assertIn("conflicts", " ".join(verify_pack_files(self.root, self.manifest)))

    def test_dependency_cycle_fails(self):
        self.write_pack()
        self.manifest["packs"]["base"]["dependencies"] = ["opening"]
        self.assertIn("cyclic", " ".join(verify_pack_files(self.root, self.manifest)))

    def test_invalid_manifest_fails(self):
        self.assertIn("must be an object", " ".join(verify_pack_files(self.root, [])))


if __name__ == "__main__":
    unittest.main()
