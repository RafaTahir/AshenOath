import gzip
import hashlib
import json
import re
import tempfile
import unittest
from pathlib import Path

from build_web_runtime_manifest import prepare_engine_transport
from verify_web_export import engine_paths, verify_pack_files


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
        self.pack["url"] = "packs/opening.pck?sha256=" + self.pack["sha256"]
        self.pack["cache_key"] = self.pack["sha256"]
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

    def test_shell_uses_final_decoded_root_size(self):
        # Voice indexing changes the archive after Godot writes the shell.
        initial_root = b"GDPCshort"
        indexed_root = initial_root + b"indexed voice" * 30
        encoded_root = gzip.compress(indexed_root, mtime=0)
        (self.root / "index.pck").write_bytes(encoded_root)
        (self.root / "index.js").write_text("const engine = {};", encoding="utf-8")
        (self.root / "index.wasm").write_bytes(b"\x00asm")
        original = {"executable": "index", "fileSizes": {"index.pck": len(initial_root), "index.wasm": 4}}
        shell = self.root / "index.html"
        shell.write_text('const GODOT_CONFIG = ' + json.dumps(original) + ';\n<script src="index.js"></script>', encoding="utf-8")
        engine = prepare_engine_transport(self.root)
        config = json.loads(re.search(r"const GODOT_CONFIG\s*=\s*(\{[^\n]+\});", shell.read_text(encoding="utf-8")).group(1))
        self.assertEqual(config["fileSizes"], {engine["wasm"]: 4, "index.pck": len(indexed_root)})
        self.assertNotEqual(len(encoded_root), config["fileSizes"]["index.pck"])

    def test_addressed_engine_layout_retains_all_required_files(self):
        stem = "engine/" + "a" * 24 + "/index"
        engine = {"executable": stem, "script": stem + ".js", "wasm": stem + ".wasm"}
        paths = engine_paths({"engine": engine})
        self.assertEqual(stem + ".wasm", paths["index.wasm"])
        self.assertEqual(stem + ".audio.worklet.js", paths["index.audio.worklet.js"])
        self.assertEqual(4, len(paths))

    def test_engine_path_escape_and_mismatch_fail(self):
        for stem in ["../index", "engine/not-a-hash/index", "https://elsewhere/index"]:
            with self.assertRaises(ValueError):
                engine_paths({"engine": {"executable": stem, "script": stem + ".js", "wasm": stem + ".wasm"}})
        with self.assertRaises(ValueError):
            engine_paths({"engine": {"executable": "index", "script": "wrong.js", "wasm": "index.wasm"}})


if __name__ == "__main__":
    unittest.main()
