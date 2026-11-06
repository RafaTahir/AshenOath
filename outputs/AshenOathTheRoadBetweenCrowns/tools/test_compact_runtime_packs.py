"""Binary preservation, fail-closed metadata ownership, and receipt regressions."""

from dataclasses import replace
import gzip
import hashlib
from pathlib import Path
import struct
import tempfile
import unittest

import compact_runtime_packs as compact


def uid_cache(mappings):
    result = bytearray(struct.pack("<I", len(mappings)))
    for uid, path in mappings.items():
        encoded = path.encode("utf-8")
        result.extend(struct.pack("<QI", uid, len(encoded)) + encoded)
    return bytes(result)


def fixture(resources, compressed=False):
    header = bytearray(compact.HEADER_BYTES)
    struct.pack_into("<6IQQ", header, 0, 0x43504447, 3, 4, 6, 3, 2, 112, 112)
    entries = []
    for path, payload in resources.items():
        encoded = path.encode("utf-8")
        encoded += b"\0" * (-len(encoded) % 4)
        entries.append(compact.PckEntry(path, encoded, payload, hashlib.md5(payload).digest()))
    return compact.encode_archive(compact.PckArchive(bytes(header), tuple(entries), compressed))


def content(payload):
    return {entry.path: entry.payload for entry in compact.parse_archive(payload).entries}


class CompactionTests(unittest.TestCase):
    def setUp(self):
        self.root_resources = {
            compact.UID_CACHE: uid_cache({1: "res://a.res", 2: "res://b.res"}),
            ".godot/global_script_class_cache.cfg": b"list=[{class=Actor}]\n",
            "assets/icons/icon.svg": b"<svg>retained icon</svg>",
            "project.binary": b"root Web settings",
            "scripts/core.gdc": b"root bytecode",
        }
        self.root = fixture(self.root_resources)
        self.child_resources = {
            compact.UID_CACHE: uid_cache({1: "res://a.res"}),
            ".godot/global_script_class_cache.cfg": self.root_resources[".godot/global_script_class_cache.cfg"],
            "assets/icons/icon.svg": self.root_resources["assets/icons/icon.svg"],
            "project.binary": b"supplemental settings",
            "assets/model.scn": bytes(range(256)) * 10,
            "assets/texture.ctex": gzip.compress(b"texture bytes" * 300),
            "assets/empty.res": b"",
            ".godot/other_cache.bin": b"not whitelisted",
        }

    def test_raw_and_gzip_preserve_every_content_byte_and_settings(self):
        for compressed in (False, True):
            with self.subTest(compressed=compressed):
                original = fixture(self.child_resources, compressed)
                result, report, mappings = compact.compact_payload(original, compact.parse_archive(self.root))
                self.assertLess(len(result), len(original))
                self.assertEqual(compact.parse_archive(result).was_gzip, compressed)
                self.assertEqual({entry["path"] for entry in report["removed"]}, compact.METADATA_PATHS)
                self.assertEqual(mappings, {1: "res://a.res"})
                self.assertEqual(content(result), {k: v for k, v in self.child_resources.items() if k not in compact.METADATA_PATHS})
                self.assertEqual(content(result)["project.binary"], b"supplemental settings")
                self.assertTrue(report["content_payloads_preserved"])
                self.assertEqual(report["retained_resources_sha256"],
                                 compact.retained_resource_fingerprint(compact.parse_archive(result).entries))

    def test_conflicting_or_new_uid_is_kept(self):
        for mappings in ({1: "res://different.res"}, {1: "res://a.res", 3: "res://new.res"}):
            resources = dict(self.child_resources, **{compact.UID_CACHE: uid_cache(mappings)})
            result, report, required = compact.compact_payload(fixture(resources), compact.parse_archive(self.root))
            self.assertEqual(content(result)[compact.UID_CACHE], resources[compact.UID_CACHE])
            self.assertNotIn(compact.UID_CACHE, {entry["path"] for entry in report["removed"]})
            self.assertEqual(required, {})

    def test_different_classes_and_icons_stay_in_the_pack(self):
        resources = dict(self.child_resources)
        resources[".godot/global_script_class_cache.cfg"] = b"list=[{class=NewActor}]"
        resources["assets/icons/icon.svg"] = b"<svg>different icon</svg>"
        result, report, _ = compact.compact_payload(fixture(resources), compact.parse_archive(self.root))
        self.assertEqual({row["path"] for row in report["removed"]}, {compact.UID_CACHE})
        self.assertEqual(content(result)["assets/icons/icon.svg"], resources["assets/icons/icon.svg"])
        self.assertEqual(content(result)[".godot/global_script_class_cache.cfg"], resources[".godot/global_script_class_cache.cfg"])

    def test_no_authority_resource_means_no_removal(self):
        empty_authority = compact.parse_archive(fixture({"project.binary": b"settings"}))
        original = fixture(self.child_resources, True)
        result, report, _ = compact.compact_payload(original, empty_authority)
        self.assertEqual(result, original)
        self.assertEqual(report["removed"], [])

    def test_compaction_is_idempotent(self):
        authority = compact.parse_archive(self.root)
        result, _, _ = compact.compact_payload(fixture(self.child_resources, True), authority)
        repeated, report, _ = compact.compact_payload(result, authority)
        self.assertEqual(repeated, result)
        self.assertEqual(report["removed"], [])

    def test_uid_parser_rejects_truncation_duplicate_ids_and_trailing_bytes(self):
        for payload in (uid_cache({1: "res://a.res"})[:-1], uid_cache({}) + b"x",
                        struct.pack("<I", 2) + (struct.pack("<QI", 1, 1) + b"x") * 2):
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                compact.read_uid_cache(payload)

    def test_pck_parser_rejects_corrupt_payloads_flags_and_directory(self):
        original = fixture(self.child_resources)
        corrupted = bytearray(original)
        corrupted[compact.HEADER_BYTES] ^= 1
        with self.assertRaisesRegex(ValueError, "digest mismatch"):
            compact.parse_archive(bytes(corrupted))
        for offset, format_, value in ((20, "<I", 3), (4, "<I", 2), (32, "<Q", len(original) + 1)):
            mutated = bytearray(original)
            struct.pack_into(format_, mutated, offset, value)
            with self.subTest(offset=offset), self.assertRaises(ValueError):
                compact.parse_archive(bytes(mutated))
        with self.assertRaises(ValueError):
            compact.parse_archive(original + b"trailing bytes")
        archive = compact.parse_archive(original)
        duplicated = compact.encode_archive(replace(archive, entries=archive.entries + archive.entries[:1]))
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            compact.parse_archive(duplicated)

    def test_replace_resources_changes_only_explicit_paths(self):
        for compressed in (False, True):
            original = fixture(self.child_resources, compressed)
            result = compact.replace_resources(original, {"assets/model.scn": b"new serialized bytes"})
            expected = dict(self.child_resources, **{"assets/model.scn": b"new serialized bytes"})
            self.assertEqual(content(result), expected)
            self.assertEqual(compact.parse_archive(result).was_gzip, compressed)
        with self.assertRaisesRegex(ValueError, "missing"):
            compact.replace_resources(original, {"not-present.json": b"{}"})

    def test_directory_receipt_checks_actual_export_authority(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            root = base / "root.pck"
            child = base / "actor.pck"
            root.write_bytes(self.root)
            original = fixture(self.child_resources, True)
            child.write_bytes(original)
            preview = compact.compact_directory(base, root, dry_run=True)
            self.assertEqual(child.read_bytes(), original)
            self.assertEqual(root.read_bytes(), self.root)
            self.assertGreater(preview["saved_bytes"], 0)
            report = compact.compact_directory(base, root)
            self.assertEqual(child.stat().st_size, report["packs"][0]["after_bytes"])
            self.assertEqual(report["packs"][0]["file"], "actor.pck")
            compact.verify_authority(self.root, report)
            newer = dict(self.root_resources, **{compact.UID_CACHE: uid_cache({1: "res://a.res", 2: "res://b.res", 3: "res://c.res"})})
            compact.verify_authority(fixture(newer), report)
            stale = dict(self.root_resources, **{compact.UID_CACHE: uid_cache({1: "res://changed.res"})})
            with self.assertRaisesRegex(ValueError, "UID mapping"):
                compact.verify_authority(fixture(stale), report)
            stale = dict(self.root_resources, **{"assets/icons/icon.svg": b"different"})
            with self.assertRaisesRegex(ValueError, "metadata"):
                compact.verify_authority(fixture(stale), report)
            with self.assertRaisesRegex(ValueError, "receipt"):
                compact.verify_authority(self.root, {})

    def test_empty_directory_fails_instead_of_claiming_success(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "root.pck"
            root.write_bytes(self.root)
            with self.assertRaisesRegex(ValueError, "no supplemental"):
                compact.compact_directory(Path(directory), root)


if __name__ == "__main__":
    unittest.main()
