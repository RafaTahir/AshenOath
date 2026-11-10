"""Synthetic final exports; no engine, world, audio or model work."""
import gzip
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from freeze_community_candidate import freeze, inside
from community_acceptance_packs import verify_web_export
from compact_runtime_packs import parse_archive
from test_community_acceptance_packs import candidate


def exported(folder, **candidate_options):
    folder = Path(folder)
    root, external, receipt = candidate(folder, **candidate_options)
    release = json.loads(receipt.read_text())
    export = folder / "web"
    (export / "packs").mkdir(parents=True)
    for relative, source in [("index.pck", root), ("packs/community.pck", external / "community.pck")]:
        content = gzip.compress(source.read_bytes(), mtime=0)
        (export / relative).write_bytes(content)
        row = next(row for row in release["artifacts"] if row["path"] == relative)
        row.update(bytes=len(content), sha256=hashlib.sha256(content).hexdigest())
        if relative == "index.pck":
            release["root_pck"] = dict(row)
    (export / "release_manifest.json").write_text(json.dumps(release), encoding="utf-8")
    runtime = next(row.payload for row in parse_archive(root.read_bytes()).entries if row.path == "runtime_pack_manifest.json")
    (export / "runtime_pack_manifest.json").write_bytes(runtime)
    return export, root, external


class NativeCandidateFreezeTests(unittest.TestCase):
    def test_web_export_is_checked_without_a_second_archive(self):
        with tempfile.TemporaryDirectory() as folder:
            export, _, _ = exported(folder, ownership={"res://data/community_campaign.json": "community"})
            before = {p.relative_to(export).as_posix(): p.read_bytes() for p in export.rglob("*") if p.is_file()}
            result = verify_web_export(export)
            self.assertEqual(result["community_resource_owners_verified"], 1)
            self.assertEqual({p.relative_to(export).as_posix(): p.read_bytes() for p in export.rglob("*") if p.is_file()}, before)
            (export / "packs/community.pck").write_bytes(before["packs/community.pck"] + b"\0")
            with self.assertRaisesRegex(ValueError, "transport bytes differ"):
                verify_web_export(export)

    def test_web_export_requires_the_expansion_owner_registry(self):
        with tempfile.TemporaryDirectory() as folder:
            export, _, _ = exported(folder)
            with self.assertRaisesRegex(ValueError, "ownership registry"):
                verify_web_export(export)

    def test_exact_final_transport_decodes_and_uses_root_class_cache(self):
        with tempfile.TemporaryDirectory() as folder:
            export, root, external = exported(folder)
            before = {p.relative_to(export).as_posix():p.read_bytes() for p in export.rglob("*") if p.is_file()}
            (export / "packs/base.pck").write_bytes(b"not a declared final artifact")
            output = Path(folder) / "native"
            result = freeze(export, output)
            self.assertEqual((output / "index.pck").read_bytes(), root.read_bytes())
            self.assertEqual((output / "packs/community.pck").read_bytes(), (external / "community.pck").read_bytes())
            self.assertEqual((output / "global_script_class_cache.cfg").read_bytes(), b'list=[]\n')
            self.assertFalse((output / "packs/base.pck").exists())
            self.assertFalse(result["engine_started"])
            self.assertFalse(result["gameplay_acceptance"])
            for path, content in before.items():
                self.assertEqual((export / path).read_bytes(), content)

    def test_changed_transport_or_decoded_hash_cannot_produce_a_passing_freeze(self):
        for mode in ["root_transport", "external_transport", "runtime_sidecar", "decoded_hash"]:
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as folder:
                export, root, external = exported(folder)
                if mode == "decoded_hash":
                    path = export / "release_manifest.json"
                    release = json.loads(path.read_text())
                    release["root_pck"]["decoded_sha256"] = "0" * 64
                    path.write_text(json.dumps(release))
                else:
                    path = export / {"root_transport":"index.pck", "external_transport":"packs/community.pck", "runtime_sidecar":"runtime_pack_manifest.json"}[mode]
                    path.write_bytes(path.read_bytes() + b"changed")
                output = Path(folder) / "native"
                with self.assertRaises(ValueError):
                    freeze(export, output)
                self.assertFalse((output / "freeze.json").exists())

    def test_preserves_existing_output_and_rejects_source_overlap(self):
        with tempfile.TemporaryDirectory() as folder:
            export, _, _ = exported(folder)
            output = Path(folder) / "native"
            output.mkdir()
            (output / "keep.txt").write_text("preserve")
            for selected in [output, export / "native", Path(folder)]:
                with self.assertRaises(ValueError):
                    freeze(export, selected)
            self.assertEqual((output / "keep.txt").read_text(), "preserve")

    def test_path_escapes_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            for relative in ["../out.pck", "/out.pck", "packs/../../out.pck", "D:/out.pck", "packs\\out.pck"]:
                with self.subTest(relative=relative), self.assertRaises(ValueError):
                    inside(Path(folder), relative)


if __name__ == "__main__":
    unittest.main()
