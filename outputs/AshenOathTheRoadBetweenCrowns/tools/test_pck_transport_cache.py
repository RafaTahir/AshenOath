"""Pure gzip transport fixtures; no engine, export, or browser invocation."""
import gzip
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import build_web_runtime_manifest as transport


class PckTransportCache(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix="ashen-pck-transport-")
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.decoded = b"GDPC" + b"unchanged resource bytes;" * 1000
        self.compact = gzip.compress(self.decoded, compresslevel=9, mtime=0)
        self.large = gzip.compress(self.decoded, compresslevel=0, mtime=0)
        file_patch = patch.object(transport, "__file__", str(self.root / "a/b/c/tool.py"))
        file_patch.start()
        self.addCleanup(file_patch.stop)
        self.cache = transport.pck_gzip_cache_path(self.decoded)

    def export(self, name, payload=None, packs=None):
        directory = self.root / name
        directory.mkdir()
        (directory / "index.pck").write_bytes(self.decoded if payload is None else payload)
        for pack_id, body in (packs or {}).items():
            target = directory / "packs" / (pack_id + ".pck")
            target.parent.mkdir(exist_ok=True)
            target.write_bytes(body)
        return directory

    def test_clean_exports_and_different_names_reuse_exact_stream_without_encoding(self):
        first = self.export("first", packs={"old_owner": self.decoded})
        with patch.object(transport, "lossless_gzip", return_value=self.compact) as encoder:
            transport.compress_pck_transport(first)
        self.assertEqual(1, encoder.call_count)
        second = self.export("second", packs={"new_owner": self.decoded})
        with patch.object(transport, "lossless_gzip", side_effect=AssertionError("warm cache must bypass encoding")):
            transport.compress_pck_transport(second)
        for path in [first / "index.pck", first / "packs/old_owner.pck", second / "index.pck", second / "packs/new_owner.pck"]:
            self.assertEqual(self.compact, path.read_bytes())
            self.assertEqual(self.decoded, gzip.decompress(path.read_bytes()))

    def test_changed_content_never_reuses_old_stream(self):
        first = self.export("first", self.compact)
        transport.compress_pck_transport(first)
        changed = b"GDPCdifferent resource bytes"
        second = self.export("second", changed)
        changed_stream = gzip.compress(changed, mtime=0)
        with patch.object(transport, "lossless_gzip", return_value=changed_stream) as encoder:
            transport.compress_pck_transport(second)
        encoder.assert_called_once_with(changed)
        self.assertEqual(changed_stream, (second / "index.pck").read_bytes())
        self.assertEqual(self.compact, self.cache.read_bytes())

    def test_corrupt_and_wrong_body_cache_never_reaches_export(self):
        self.cache.parent.mkdir(parents=True)
        for index, bad in enumerate([b"\x1f\x8bbroken", gzip.compress(b"GDPCdifferent body", mtime=0)]):
            self.cache.write_bytes(bad)
            target = self.export("bad-" + str(index))
            with patch.object(transport, "lossless_gzip", return_value=self.compact):
                transport.compress_pck_transport(target)
            self.assertEqual(self.compact, (target / "index.pck").read_bytes())
            self.assertEqual(self.compact, self.cache.read_bytes())

    def test_preencoded_input_seeds_cache_and_never_regresses_to_larger_stream(self):
        target = self.export("preencoded", self.compact)
        with patch.object(transport, "lossless_gzip", side_effect=AssertionError("already encoded")):
            transport.compress_pck_transport(target)
            self.assertEqual(self.compact, self.cache.read_bytes())
            self.cache.write_bytes(self.large)
            transport.compress_pck_transport(target)
        self.assertEqual(self.compact, self.cache.read_bytes())
        self.assertEqual(self.compact, (target / "index.pck").read_bytes())

    def test_published_stream_seeds_cache_and_smaller_cache_improves_preencoded_input(self):
        published = self.root / "web/index.pck"
        published.parent.mkdir()
        published.write_bytes(self.compact)
        first = self.export("published")
        with patch.object(transport, "lossless_gzip", side_effect=AssertionError("published hit")):
            transport.compress_pck_transport(first)
        self.assertEqual(self.compact, self.cache.read_bytes())
        published.unlink()
        second = self.export("larger", self.large)
        transport.compress_pck_transport(second)
        self.assertEqual(self.compact, (second / "index.pck").read_bytes())

    def test_late_stronger_cache_is_not_overwritten_by_stale_selection(self):
        self.cache.parent.mkdir(parents=True)
        self.cache.write_bytes(self.compact)
        target = self.export("stale", self.large)
        with patch.object(transport, "retained_gzip", return_value=None):
            transport.compress_pck_transport(target)
        self.assertEqual(self.compact, (target / "index.pck").read_bytes())
        self.assertEqual(self.compact, self.cache.read_bytes())

    def test_busy_and_unwritable_optional_cache_do_not_break_export_or_remove_lock(self):
        self.cache.parent.mkdir(parents=True)
        lock = self.cache.with_name(self.cache.name + ".lock")
        lock.write_bytes(b"another build")
        first = self.export("busy", self.compact)
        transport.compress_pck_transport(first)
        self.assertEqual(b"another build", lock.read_bytes())
        self.assertFalse(self.cache.exists())
        blocked = self.root / "blocked"
        blocked.write_bytes(b"file blocks cache directory")
        with patch.object(transport, "pck_gzip_cache_path", return_value=blocked / "pack.pck.gz"):
            second = self.export("unwritable", self.compact)
            transport.compress_pck_transport(second)
        self.assertEqual(self.compact, (second / "index.pck").read_bytes())

    def test_invalid_input_or_encoder_cannot_seed_cache_or_replace_export(self):
        invalid = self.export("invalid", b"not a PCK")
        with self.assertRaisesRegex(ValueError, "valid Godot PCK"):
            transport.compress_pck_transport(invalid)
        valid = self.export("valid")
        with patch.object(transport, "lossless_gzip", return_value=gzip.compress(b"GDPCwrong bytes")):
            with self.assertRaisesRegex(ValueError, "changed decoded content"):
                transport.compress_pck_transport(valid)
        self.assertEqual(self.decoded, (valid / "index.pck").read_bytes())
        self.assertFalse(self.cache.exists())


if __name__ == "__main__":
    unittest.main()
