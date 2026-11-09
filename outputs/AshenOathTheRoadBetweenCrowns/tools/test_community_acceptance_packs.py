"""Synthetic PCKs only: no engine, imported assets or user profiles."""
import gzip
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import community_acceptance_packs as packs
from test_compact_runtime_packs import fixture


def identity(path, content, compressed=False):
    record = {"path":path,"bytes":len(content),"sha256":hashlib.sha256(content).hexdigest()}
    if compressed:
        transport = gzip.compress(content)
        record.update(bytes=len(transport),sha256=hashlib.sha256(transport).hexdigest(),
                      content_encoding="gzip",decoded_bytes=len(content),decoded_sha256=hashlib.sha256(content).hexdigest())
    return record


def candidate(folder, *, missing=None, override_manifest=False, remap=False):
    folder=Path(folder)
    external=folder/"runtime-packs"; external.mkdir()
    resources={key:b"synthetic resource; no native validity claim" for key in packs.REQUIRED_RESOURCES}
    if missing: resources.pop(missing)
    if remap:
        resources.pop("scenes/main.tscn")
        resources["scenes/main.tscn.remap"]=b'[remap]\npath="res://.godot/exported/main.scn"\n'
        resources[".godot/exported/main.scn"]=b"synthetic remapped scene"
    if override_manifest: resources["runtime_pack_manifest.json"]=b'{"stale":true}'
    child=fixture(resources)
    (external/"community.pck").write_bytes(child)
    digest=hashlib.sha256(child).hexdigest()
    manifest={"release_id":"test-release","generated_from_commit":"a"*40,"packs":{
        "base":{"status":"embedded_current_pck","url":"","bytes":0,"sha256":"","dependencies":[]},
        "community":{"status":"candidate_external","url":"packs/community.pck?v="+digest,
                     "bytes":len(child),"sha256":digest,"dependencies":["base"],"candidate_artifact":"community.pck"}}}
    manifest_bytes=json.dumps(manifest).encode()
    root=fixture({"runtime_pack_manifest.json":manifest_bytes,"project.binary":b"frozen configuration",
                  ".godot/global_script_class_cache.cfg":b'list=[]\n'})
    root_path=folder/"root.pck"; root_path.write_bytes(root)
    root_record=identity("index.pck",root,True)
    manifest_record=identity("runtime_pack_manifest.json",manifest_bytes)
    release={"build_id":"test-release","source":{"git_commit":"a"*40},"root_pck":root_record,
             "runtime_pack_manifest":manifest_record,"artifacts":[root_record,manifest_record,identity("packs/community.pck",child,True)],
             "packs":[{"id":key,**{field:row[field] for field in ["url","bytes","sha256","dependencies"]},
                       "embedded":row["status"].startswith("embedded")} for key,row in manifest["packs"].items()]}
    receipt=folder/"release_manifest.json"; receipt.write_text(json.dumps(release),encoding="utf-8")
    return root_path,external,receipt


class CandidatePackTests(unittest.TestCase):
    def test_verified_release_excludes_unlisted_intermediate_base(self):
        with tempfile.TemporaryDirectory() as folder:
            root,external,receipt=candidate(folder)
            (external/"base.pck").write_bytes(b"old invalid intermediate")
            (external/"unrelated.pck").write_bytes(b"unrelated preserved file")
            result=packs.verify_candidate(root,external,receipt)
            self.assertEqual([row["id"] for row in result["packs"]],["community"])
            self.assertFalse(result["resource_instantiation_validated"])
            self.assertFalse(result["deferred_loading_tested"])

    def test_compressed_native_root_and_secondary_fail_before_launch(self):
        for selected in ["root","child"]:
            with self.subTest(selected=selected),tempfile.TemporaryDirectory() as folder:
                root,external,receipt=candidate(folder)
                path=root if selected=="root" else external/"community.pck"
                path.write_bytes(gzip.compress(path.read_bytes()))
                with self.assertRaisesRegex(ValueError,"uncompressed PCK"):
                    packs.verify_candidate(root,external,receipt)

    def test_mutated_root_or_child_cannot_match_release(self):
        for selected in ["root","child"]:
            with self.subTest(selected=selected),tempfile.TemporaryDirectory() as folder:
                root,external,receipt=candidate(folder)
                path=root if selected=="root" else external/"community.pck"
                path.write_bytes(path.read_bytes()+b"changed")
                with self.assertRaises(ValueError): packs.verify_candidate(root,external,receipt)

    def test_missing_declared_pack_is_not_silently_skipped(self):
        with tempfile.TemporaryDirectory() as folder:
            root,external,receipt=candidate(folder)
            (external/"community.pck").unlink()
            with self.assertRaises(OSError): packs.verify_candidate(root,external,receipt)

    def test_cemetery_preload_missing_fails_static_closure(self):
        with tempfile.TemporaryDirectory() as folder:
            root,external,receipt=candidate(folder,missing="assets_external/environment/village/Cemetery_memory_window_Authored.res")
            with self.assertRaisesRegex(ValueError,"Cemetery_memory_window"):
                packs.verify_candidate(root,external,receipt)

    def test_export_remap_resolves_to_present_resource(self):
        with tempfile.TemporaryDirectory() as folder:
            root,external,receipt=candidate(folder,remap=True)
            self.assertIn("scenes/main.tscn",packs.verify_candidate(root,external,receipt)["known_required_resources"])

    def test_secondary_cannot_replace_authoritative_manifest(self):
        with tempfile.TemporaryDirectory() as folder:
            root,external,receipt=candidate(folder,override_manifest=True)
            with self.assertRaisesRegex(ValueError,"override the root runtime manifest"):
                packs.verify_candidate(root,external,receipt)

    def test_release_metadata_tampering_is_rejected(self):
        for field in ["build_id","packs","artifacts"]:
            with self.subTest(field=field),tempfile.TemporaryDirectory() as folder:
                root,external,receipt=candidate(folder)
                release=json.loads(receipt.read_text())
                if field=="build_id": release[field]="stale"
                else: release[field].append(release[field][0])
                receipt.write_text(json.dumps(release),encoding="utf-8")
                with self.assertRaises(ValueError): packs.verify_candidate(root,external,receipt)

    def test_runtime_entry_uses_explicit_verified_list(self):
        project=Path(__file__).resolve().parents[1]
        regional=(project/"tools/verify_community_world_input.gd").read_text(encoding="utf-8")
        complete=(project/"tools/verify_full_campaign_input.gd").read_text(encoding="utf-8")
        for source in [regional,complete]:
            self.assertNotIn("DirAccess.get_files_at",source)
            self.assertIn("_mount_verified_candidate()",source)
        self.assertIn('FileAccess.get_sha256("res://runtime_pack_manifest.json")',regional)


if __name__=="__main__": unittest.main()
