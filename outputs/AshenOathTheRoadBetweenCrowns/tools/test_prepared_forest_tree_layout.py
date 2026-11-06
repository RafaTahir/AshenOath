"""Exercise exclusion proof failures without importing assets or running Godot."""

import copy
import json
from pathlib import Path
import tempfile
import unittest

from prepared_forest_tree_layout import (
    CATALOG, COMPILERS, SOURCES,
    fingerprint, load_prepared_forest_trees, resource_file, source_inputs,
)


class ForestProof(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name)
        for path in COMPILERS:
            self.write(path, b"compiler fixture")
        self.catalog = {}
        for source, prepared in SOURCES.items():
            self.write(source, b"mtllib tree.mtl\nv 1 2 3\n")
            self.write(source + ".import", b"source import settings")
            self.write(source.rsplit("/", 1)[0] + "/tree.mtl", b"source material library")
            self.write(prepared, b"compiled mesh fixture")
            compiled = fingerprint(resource_file(self.project, prepared))
            self.catalog[source] = {
                "contract_version": 1, "source_path": source, "path": prepared,
                "compiled_sha256": compiled["sha256"], "compiled_bytes": compiled["bytes"],
                "source_fingerprints": {p: fingerprint(resource_file(self.project, p))
                                        for p in source_inputs(self.project, source)},
                "compiler_fingerprints": {p: fingerprint(resource_file(self.project, p)) for p in COMPILERS},
                "source_geometry_sha256": "1" * 64, "geometry_sha256": "1" * 64,
                "material_sha256": "2" * 64, "surface_names": ["Bark_tree", "Leaves_tree"],
                "aabb": [0, 0, 0, 2, 6, 2],
                "source_scene_dependencies": [], "resource_dependencies": [],
            }
        self.save()

    def write(self, path, payload):
        file = resource_file(self.project, path)
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_bytes(payload)

    def save(self):
        path = self.project / CATALOG
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.catalog), encoding="utf-8")

    def test_complete_receipt_permits_only_the_three_approved_replacements(self):
        self.assertEqual(self.catalog, load_prepared_forest_trees(self.project))

    def test_missing_receipt_cannot_retire_sources(self):
        (self.project / CATALOG).unlink()
        self.assertEqual({}, load_prepared_forest_trees(self.project, required=False))
        with self.assertRaisesRegex(ValueError, "Required prepared forest geometry"):
            load_prepared_forest_trees(self.project)

    def test_authored_import_compiler_or_compiled_change_invalidates_receipt(self):
        source, prepared = next(iter(SOURCES.items()))
        paths = [source, source + ".import", source.rsplit("/", 1)[0] + "/tree.mtl",
                 next(iter(COMPILERS)), prepared]
        for path in paths:
            with self.subTest(path=path):
                file = resource_file(self.project, path)
                original = file.read_bytes()
                file.write_bytes(original + b"changed")
                with self.assertRaisesRegex(ValueError, "Stale"):
                    load_prepared_forest_trees(self.project)
                self.assertEqual({}, load_prepared_forest_trees(self.project, required=False))
                file.write_bytes(original)

    def test_geometry_material_dependency_and_identity_failures_close_exclusion(self):
        original = copy.deepcopy(self.catalog)
        source = next(iter(SOURCES))
        mutations = [
            {"geometry_sha256": "3" * 64}, {"material_sha256": ""},
            {"source_scene_dependencies": [source]},
            {"resource_dependencies": ["res://old_normal.png"]},
            {"surface_names": []}, {"aabb": []}, {"contract_version": 2},
            {"path": "res://wrong.res"}, {"source_fingerprints": {}},
        ]
        for update in mutations:
            with self.subTest(update=update):
                self.catalog = copy.deepcopy(original)
                self.catalog[source].update(update)
                self.save()
                with self.assertRaises(ValueError):
                    load_prepared_forest_trees(self.project)

    def test_unsafe_input_path_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Unsafe"):
            resource_file(self.project, "res://../outside")


if __name__ == "__main__":
    unittest.main()
