"""Regression proof for unchanged combat data during ambient-only GLB edits."""
import copy
from pathlib import Path
import struct
import tempfile
import unittest

from preserve_creature_action_bytes import action_digest, preserve, read_glb, write_glb


def fixture(attack_peak=1.0, idle_peak=.1, reorder=False):
    nodes = [{"name": "Scene", "children": [1]},
             {"name": "Root", "children": [2]},
             {"name": "Hand", "translation": [.2, 1.0, 0]}]
    doc = {"asset": {"version": "2.0"}, "buffers": [{"byteLength": 0}],
           "bufferViews": [], "accessors": [], "nodes": nodes,
           "scenes": [{"nodes": [0]}], "scene": 0, "animations": []}
    payload = bytearray()

    def accessor(values, width, strided=False):
        offset = len(payload)
        for row in values:
            payload.extend(struct.pack("<"+"f"*width, *row))
            if strided:
                payload.extend(b"PAD!")
        view = {"buffer": 0, "byteOffset": offset, "byteLength": len(payload)-offset}
        if strided:
            view["byteStride"] = width*4+4
        doc["bufferViews"].append(view)
        doc["accessors"].append({"bufferView": len(doc["bufferViews"])-1,
            "componentType": 5126, "count": len(values), "type": "SCALAR" if width == 1 else "VEC3"})
        return len(doc["accessors"])-1

    times = accessor([(0,), (.5,), (1,)], 1)
    for name, peak in [("Attack", attack_peak), ("Idle", idle_peak)]:
        output = accessor([(0, 0, 0), (peak, 0, 0), (0, 0, 0)], 3, strided=True)
        doc["animations"].append({"name": name,
            "samplers": [{"input": times, "output": output, "interpolation": "LINEAR"}],
            "channels": [{"sampler": 0, "target": {"node": 2, "path": "translation"}}]})
    if reorder:
        # IDs are exporter-dependent; identity, parentage and rest must survive.
        doc["nodes"] = [nodes[2], nodes[0], nodes[1]]
        doc["nodes"][1]["children"] = [2]
        doc["nodes"][2]["children"] = [0]
        doc["scenes"][0]["nodes"] = [1]
        for action in doc["animations"]:
            action["channels"][0]["target"]["node"] = 0
    return doc, bytes(payload)


class ProtectedActionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="ao-creature-contract-")
        self.addCleanup(self.directory.cleanup)
        self.old = Path(self.directory.name)/"original.glb"
        self.new = Path(self.directory.name)/"candidate.glb"
        write_glb(self.old, *fixture())

    @staticmethod
    def digest(path, clip):
        doc, data = read_glb(path)
        return action_digest(doc, data, next(a for a in doc["animations"] if a["name"] == clip))

    def test_restores_exact_attack_without_losing_authored_idle(self):
        write_glb(self.new, *fixture(attack_peak=9.0, idle_peak=.35, reorder=True))
        idle_before = self.digest(self.new, "Idle")
        self.assertNotEqual(self.digest(self.new, "Attack"), self.digest(self.old, "Attack"))
        report = preserve(self.old, self.new)
        self.assertTrue(report["protected_action_bytes_equal"])
        self.assertEqual(self.digest(self.old, "Attack"), self.digest(self.new, "Attack"))
        self.assertEqual(idle_before, self.digest(self.new, "Idle"))

    def reject_without_writing(self, mutate, expected):
        document, binary = fixture(attack_peak=9.0)
        mutate(document)
        write_glb(self.new, document, binary)
        before = self.new.read_bytes()
        with self.assertRaisesRegex(ValueError, expected):
            preserve(self.old, self.new)
        self.assertEqual(before, self.new.read_bytes())

    def test_rejects_changed_target_rest(self):
        self.reject_without_writing(lambda d: d["nodes"][2].update(translation=[.3, 1, 0]), "rest basis")

    def test_rejects_changed_unanimated_ancestor_rest(self):
        self.reject_without_writing(lambda d: d["nodes"][0].update(scale=[1, 2, 1]), "rest basis")

    def test_rejects_changed_parent(self):
        def change(document):
            document["nodes"][0]["children"] = [1, 2]
            document["nodes"][1]["children"] = []
        self.reject_without_writing(change, "changed parent")

    def test_rejects_ambiguous_joint_name(self):
        self.reject_without_writing(lambda d: d["nodes"].append({"name": "Hand"}), "ambiguous")

    def test_rejects_truncated_native_buffer_view(self):
        document, binary = read_glb(self.old)
        document["bufferViews"][1]["byteLength"] -= 8
        write_glb(self.old, document, binary)
        write_glb(self.new, *fixture(attack_peak=9.0))
        before = self.new.read_bytes()
        with self.assertRaisesRegex(ValueError, "exceeds"):
            preserve(self.old, self.new)
        self.assertEqual(before, self.new.read_bytes())

    def test_rejects_sparse_native_samples(self):
        document, binary = read_glb(self.old)
        document["accessors"][1]["sparse"] = {"count": 1}
        write_glb(self.old, document, binary)
        write_glb(self.new, *fixture())
        with self.assertRaisesRegex(ValueError, "Sparse"):
            preserve(self.old, self.new)

    def test_equivalent_matrix_rest_is_allowed(self):
        document, binary = fixture(attack_peak=9.0)
        node = document["nodes"][2]
        del node["translation"]
        node["matrix"] = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, .2, 1, 0, 1]
        write_glb(self.new, document, binary)
        preserve(self.old, self.new)
        self.assertEqual(self.digest(self.old, "Attack"), self.digest(self.new, "Attack"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
