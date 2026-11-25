#!/usr/bin/env python3
"""Pure frozen-smoke artifact/path regression fixtures; never launch an engine."""
from __future__ import annotations

import copy
import gzip
import json
from pathlib import Path
import tempfile
import unittest

import run_frozen_monster_smoke as smoke


class FrozenPreparationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ao-frozen-smoke-")
        self.root = Path(self.temporary.name)
        self.export = self.root / "export"
        self.export.mkdir()
        self.output = self.root / "prepared"
        self.runtime = {"release_id":"fixture-release", "packs":{
            "base":{"status":"embedded_current_pck", "url":"", "embedded_artifact":"index.pck", "bytes":0, "sha256":"", "dependencies":[]},
            "shared":{"status":"streamed_web_candidate", "dependencies":["base"], "url":"packs/shared.pck"},
            "left":{"status":"streamed_web_candidate", "dependencies":["shared"], "url":"packs/left.pck"},
            "right":{"status":"streamed_web_candidate", "dependencies":["shared"], "url":"packs/right.pck"},
            "diamond":{"status":"streamed_web_candidate", "dependencies":["left", "right"], "url":"packs/diamond.pck"}}}
        self.artifacts = []
        self.pack("index.pck", b"GDPC-root-fixture")
        for identity, row in self.runtime["packs"].items():
            if row["status"].startswith("embedded"): continue
            record = self.pack(row["url"], b"GDPC-" + identity.encode())
            row.update(bytes=record["decoded_bytes"], sha256=record["decoded_sha256"])
        self.bind()

    def tearDown(self):
        self.temporary.cleanup()

    def pack(self, name, payload):
        encoded = gzip.compress(payload, mtime=0)
        path = self.export / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(encoded)
        row = {"path":name, "bytes":len(encoded), "sha256":smoke.digest(encoded),
               "content_encoding":"gzip", "decoded_bytes":len(payload), "decoded_sha256":smoke.digest(payload)}
        self.artifacts.append(row)
        return row

    def bind(self):
        payload = (json.dumps(self.runtime) + "\n").encode()
        (self.export / "runtime_pack_manifest.json").write_bytes(payload)
        runtime_row = {"path":"runtime_pack_manifest.json", "bytes":len(payload), "sha256":smoke.digest(payload)}
        artifacts = self.artifacts + [runtime_row]
        self.release = {"build_id":"fixture-release", "source":{"git_commit":"fixture"},
                        "artifacts":artifacts, "runtime_pack_manifest":copy.deepcopy(runtime_row),
                        "root_pck":copy.deepcopy(self.artifacts[0])}
        self.release_json()

    def release_json(self):
        (self.export / "release_manifest.json").write_text(json.dumps(self.release), encoding="utf-8")

    def prepare(self):
        return smoke.prepare(self.export, self.output, "d" * 64)

    def reject(self):
        with self.assertRaises((ValueError, OSError, KeyError, TypeError, EOFError)):
            self.prepare()
        self.assertFalse(self.output.exists(), "invalid artifacts must fail before output creation")

    def test_exact_gzip_and_diamond_prepare_and_check_without_launch(self):
        receipt = self.prepare()
        self.assertEqual(receipt, smoke.check_prepared(self.output))
        self.assertFalse(receipt["engine_launched"])
        self.assertFalse(receipt["source_fallback"])
        self.assertFalse(any((self.output / "resource-root").iterdir()))
        ids = [row["id"] for row in receipt["packs"]]
        self.assertEqual(ids, ["root", "shared", "left", "right", "diamond"])
        self.assertEqual((self.output / "decoded/index.pck").read_bytes(), b"GDPC-root-fixture")

    def test_authoritative_runtime_status_schema_needs_no_embedded_boolean(self):
        self.assertNotIn("embedded", self.runtime["packs"]["base"])
        self.runtime["packs"]["base"].update(candidate_artifact="base.pck", embedded_source_artifact="base.pck", embedded_source_kind="standalone_pack_candidate")
        self.bind()
        receipt = self.prepare()
        self.assertEqual([row["id"] for row in receipt["packs"]], ["root", "shared", "left", "right", "diamond"])
        self.assertFalse((self.output / "decoded/packs/base.pck").exists())

    def test_empty_url_is_not_inferred_as_embedded(self):
        self.runtime["packs"]["base"]["status"] = "streamed_web_candidate"
        self.bind()
        self.reject()

    def test_unknown_embedded_status_rejected_even_with_pack_url(self):
        self.runtime["packs"]["base"].update(status="embedded_unknown_future", url="packs/left.pck")
        self.bind()
        with self.assertRaisesRegex(ValueError, "unsupported embedded runtime status"):
            self.prepare()
        self.assertFalse(self.output.exists())

    def test_embedded_status_cannot_hide_external_url_or_payload(self):
        for field, value in (("url", "packs/hidden.pck"), ("embedded_artifact", "other.pck"), ("bytes", 123), ("sha256", "f" * 64)):
            with self.subTest(field=field):
                original = self.runtime["packs"]["base"][field]
                self.runtime["packs"]["base"][field] = value
                self.bind()
                self.reject()
                self.runtime["packs"]["base"][field] = original

    def test_existing_output_is_preserved(self):
        self.prepare()
        before = (self.output / "preparation.json").read_bytes()
        with self.assertRaises(ValueError): self.prepare()
        self.assertEqual(before, (self.output / "preparation.json").read_bytes())

    def test_transport_corruption(self):
        (self.export / "packs/left.pck").write_bytes(b"corrupt")
        self.reject()

    def test_missing_pack(self):
        (self.export / "packs/left.pck").unlink()
        self.reject()

    def test_decoded_hash_mismatch(self):
        self.artifacts[1]["decoded_sha256"] = "0" * 64
        self.runtime["packs"]["shared"]["sha256"] = "0" * 64
        self.bind()
        self.reject()

    def test_decoded_size_mismatch(self):
        self.artifacts[1]["decoded_bytes"] += 1
        self.runtime["packs"]["shared"]["bytes"] += 1
        self.bind()
        self.reject()

    def test_missing_pck_magic(self):
        encoded = gzip.compress(b"not-a-pck", mtime=0)
        (self.export / "packs/shared.pck").write_bytes(encoded)
        self.artifacts[1].update(bytes=len(encoded), sha256=smoke.digest(encoded), decoded_bytes=9, decoded_sha256=smoke.digest(b"not-a-pck"))
        self.runtime["packs"]["shared"].update(bytes=9, sha256=smoke.digest(b"not-a-pck"))
        self.bind()
        self.reject()

    def test_invalid_gzip_bound_transport(self):
        encoded = b"\x1f\x8bnot-a-valid-deflate-stream"
        (self.export / "packs/shared.pck").write_bytes(encoded)
        self.artifacts[1].update(bytes=len(encoded), sha256=smoke.digest(encoded))
        self.bind()
        self.reject()

    def test_undeclared_pck_artifact(self):
        self.pack("packs/unlisted.pck", b"GDPC-unknown")
        self.bind()
        self.reject()

    def test_duplicate_casefold_artifact(self):
        self.release["artifacts"].append({**self.artifacts[0], "path":"INDEX.PCK"})
        self.release_json()
        self.reject()

    def test_runtime_manifest_binding_mismatch(self):
        self.release["runtime_pack_manifest"]["sha256"] = "0" * 64
        self.release_json()
        self.reject()

    def test_runtime_manifest_transport_corruption(self):
        (self.export / "runtime_pack_manifest.json").write_text("{}", encoding="utf-8")
        self.reject()

    def test_root_binding_mismatch(self):
        self.release["root_pck"]["sha256"] = "0" * 64
        self.release_json()
        self.reject()

    def test_release_identity_mismatch(self):
        self.release["build_id"] = "other"
        self.release_json()
        self.reject()

    def test_runtime_pack_identity_mismatch(self):
        self.runtime["packs"]["left"]["sha256"] = "0" * 64
        self.bind()
        self.reject()

    def test_cycle_including_embedded_pack(self):
        self.runtime["packs"]["base"]["dependencies"] = ["diamond"]
        self.bind()
        self.reject()

    def test_unknown_dependency(self):
        self.runtime["packs"]["left"]["dependencies"] = ["unknown"]
        self.bind()
        self.reject()

    def test_nonlocal_pack_url(self):
        self.runtime["packs"]["left"]["url"] = "https://example.invalid/packs/left.pck"
        self.bind()
        self.reject()

    def test_pack_path_escape(self):
        self.runtime["packs"]["left"]["url"] = "../left.pck"
        self.bind()
        self.reject()

    def test_repeated_pack_path(self):
        self.runtime["packs"]["right"]["url"] = "packs/left.pck"
        self.runtime["packs"]["right"]["sha256"] = self.runtime["packs"]["left"]["sha256"]
        self.runtime["packs"]["right"]["bytes"] = self.runtime["packs"]["left"]["bytes"]
        self.bind()
        self.reject()

    def test_invalid_profile_pin(self):
        with self.assertRaises(ValueError): smoke.prepare(self.export, self.output, "latest")
        self.assertFalse(self.output.exists())

    def test_artifact_path_inputs(self):
        for name in ("/outside", "../escape", "a/../../escape", "a\\escape", "C:/escape", "a//b", "a/./b", "", "a/\x00b"):
            with self.subTest(name=name), self.assertRaises(ValueError): smoke.relative_path(name)

    def test_prepared_pck_corruption(self):
        self.prepare()
        (self.output / "decoded/packs/left.pck").write_bytes(b"bad")
        with self.assertRaises(ValueError): smoke.check_prepared(self.output)

    def test_prepared_qa_corruption(self):
        self.prepare()
        (self.output / "qa" / smoke.QA.name).write_text("changed", encoding="utf-8")
        with self.assertRaises(ValueError): smoke.check_prepared(self.output)

    def test_prepared_coordinate_helper_corruption(self):
        receipt = self.prepare()
        path = self.output / "qa" / smoke.COORDINATES.name
        self.assertEqual(smoke.digest(path.read_bytes()), receipt["coordinate_helper_sha256"])
        path.write_text("changed", encoding="utf-8")
        with self.assertRaises(ValueError): smoke.check_prepared(self.output)

    def test_undeclared_qa_helper_rejected(self):
        self.prepare()
        (self.output / "qa/source_fallback.gd").write_text("source fallback", encoding="utf-8")
        with self.assertRaises(ValueError): smoke.check_prepared(self.output)

    def test_prepared_forest_helper_corruption(self):
        receipt = self.prepare()
        path = self.output / "qa" / smoke.FOREST.name
        self.assertEqual(smoke.digest(path.read_bytes()), receipt["forest_helper_sha256"])
        path.write_text("changed", encoding="utf-8")
        with self.assertRaises(ValueError): smoke.check_prepared(self.output)

    def test_actual_touch_client_and_internal_render_contract(self):
        report = {"requested_window_size":[960,540], "window_client_size":[960,540], "internal_render_size":[1280,720],
                  "frames":[{"width":1280,"height":720,"window_client_size":[960,540]}],
                  "inputs":[{"coordinates":{"valid":True,"logical_size":[1280,720],"window_client_size":[960,540]},
                             "logical_position":[1120,592],"window_position":[840,444],
                             "logical_delta":[-120,32],"window_delta":[-90,24]}]}
        self.assertEqual(smoke.observation_geometry_errors(report, (960,540)), [])
        wrong = copy.deepcopy(report)
        wrong["inputs"][0]["window_position"] = [1120,592]
        self.assertTrue(smoke.observation_geometry_errors(wrong, (960,540)))
        wrong = copy.deepcopy(report)
        wrong["frames"][0].update(width=960,height=540)
        self.assertTrue(smoke.observation_geometry_errors(wrong, (960,540)))
        wrong = copy.deepcopy(report)
        wrong["internal_render_size"] = [960,540]
        self.assertTrue(smoke.observation_geometry_errors(wrong, (960,540)))

    def test_desktop_input_mapping_unchanged(self):
        report = {"requested_window_size":[1280,720], "window_client_size":[1280,720], "internal_render_size":[1280,720],
                  "frames":[{"width":1280,"height":720,"window_client_size":[1280,720]}],
                  "inputs":[{"coordinates":{"valid":True,"logical_size":[1280,720],"window_client_size":[1280,720]},
                             "logical_position":[640,360],"window_position":[640,360]}]}
        self.assertEqual(smoke.observation_geometry_errors(report, (1280,720)), [])

    def test_runtime_source_fallback_rejected(self):
        self.prepare()
        (self.output / "resource-root/project.godot").write_text("source fallback", encoding="utf-8")
        with self.assertRaises(ValueError): smoke.check_prepared(self.output)

    def test_undeclared_decoded_resource_rejected(self):
        self.prepare()
        (self.output / "decoded/project.godot").write_text("source fallback", encoding="utf-8")
        with self.assertRaises(ValueError): smoke.check_prepared(self.output)


if __name__ == "__main__":
    unittest.main(verbosity=2)
