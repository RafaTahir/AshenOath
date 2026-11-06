import gzip
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import build_web_runtime_manifest as transport


class EngineTransportCache(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix="ashen-transport-")
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.decoded = b"\x00asm" + b"unchanged engine bytes;" * 1000
        self.compact = gzip.compress(self.decoded, compresslevel=9, mtime=0)
        self.large = gzip.compress(self.decoded, compresslevel=0, mtime=0)
        self.cache = self.root / "cache" / "engine.wasm.gz"
        self.cache_patch = patch.object(transport, "engine_gzip_cache_path", return_value=self.cache)
        self.cache_patch.start()
        self.addCleanup(self.cache_patch.stop)

    def test_retained_chooses_smallest_matching_stream(self):
        self.cache.parent.mkdir()
        self.cache.write_bytes(self.compact)
        with patch.object(transport, "__file__", str(self.root / "a/b/c/tool.py")):
            published = self.root / "web/engine/first"
            published.mkdir(parents=True)
            (published / "index.wasm").write_bytes(self.large)
            self.assertEqual(self.compact, transport.retained_gzip(self.decoded, "index.wasm"))

    def test_bad_cache_is_not_reused(self):
        self.cache.parent.mkdir()
        self.cache.write_bytes(gzip.compress(b"different engine", mtime=0))
        with patch.object(transport, "__file__", str(self.root / "a/b/c/tool.py")):
            self.assertIsNone(transport.retained_gzip(self.decoded, "index.wasm"))
        self.cache.write_bytes(b"\x1f\x8bbroken")
        with patch.object(transport, "__file__", str(self.root / "a/b/c/tool.py")):
            self.assertIsNone(transport.retained_gzip(self.decoded, "index.wasm"))

    def test_preencoded_engine_does_not_regress_to_larger_retained_stream(self):
        engine = self.root / "index.wasm"
        engine.write_bytes(self.compact)
        with patch.object(transport, "retained_gzip", return_value=self.large):
            transport.compress_wasm(engine)
        self.assertEqual(self.compact, engine.read_bytes())
        self.assertEqual(self.compact, self.cache.read_bytes())

    def test_clean_export_reuses_and_keeps_exact_engine_bytes(self):
        engine = self.root / "index.wasm"
        engine.write_bytes(self.decoded)
        with patch.object(transport, "retained_gzip", return_value=self.compact):
            transport.compress_wasm(engine)
        self.assertEqual(self.decoded, gzip.decompress(engine.read_bytes()))
        self.assertEqual(self.compact, self.cache.read_bytes())

    def test_unwritable_optional_cache_does_not_break_export(self):
        engine = self.root / "index.wasm"
        engine.write_bytes(self.compact)
        self.cache.parent.write_bytes(b"file blocks cache directory")
        with patch.object(transport, "retained_gzip", return_value=None):
            transport.compress_wasm(engine)
        self.assertEqual(self.decoded, gzip.decompress(engine.read_bytes()))

    def test_rejects_non_engine_without_caching(self):
        engine = self.root / "index.wasm"
        engine.write_bytes(b"not WebAssembly")
        with self.assertRaises(ValueError):
            transport.compress_wasm(engine)
        self.assertFalse(self.cache.exists())

    def test_late_stronger_cache_is_not_overwritten_by_stale_selection(self):
        engine = self.root / "index.wasm"
        engine.write_bytes(self.large)
        self.cache.parent.mkdir()
        self.cache.write_bytes(self.compact)
        with patch.object(transport, "retained_gzip", return_value=None):
            transport.compress_wasm(engine)
        self.assertEqual(self.compact, engine.read_bytes())
        self.assertEqual(self.compact, self.cache.read_bytes())

    def test_busy_cache_does_not_touch_another_builds_lock(self):
        engine = self.root / "index.wasm"
        engine.write_bytes(self.compact)
        self.cache.parent.mkdir()
        lock = self.cache.with_name(self.cache.name + ".lock")
        lock.write_bytes(b"another build")
        with patch.object(transport, "retained_gzip", return_value=None):
            transport.compress_wasm(engine)
        self.assertEqual(self.compact, engine.read_bytes())
        self.assertEqual(b"another build", lock.read_bytes())


if __name__ == "__main__":
    unittest.main()
