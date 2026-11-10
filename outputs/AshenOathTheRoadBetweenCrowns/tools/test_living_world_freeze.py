import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("freeze_scenery", Path(__file__).with_name("freeze_living_world_originals.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class FrozenOriginalsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.seed = tempfile.TemporaryDirectory(prefix="ao-scenery-source-")
        root = Path(cls.seed.name)
        game = root / "outputs/AshenOathTheRoadBetweenCrowns"
        for identity, relative in module.OUTPUTS.items():
            path = game / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"RSRC" + identity.encode())
        for relative in module.SCRIPTS:
            path = game / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"extends RefCounted\n")
        for args in [["init", "-q"], ["add", "--all"], ["-c", "user.name=Scenery fixture", "-c", "user.email=fixture@example.invalid", "-c", "commit.gpgsign=false", "-c", "core.hooksPath="+str(root/"disabled-hooks"), "commit", "-qm", "source fixture"]]:
            subprocess.run(["git", *args], cwd=root, check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        cls.seed.cleanup()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ao-scenery-check-")
        self.root = Path(self.temp.name) / "repo"
        shutil.copytree(self.seed.name, self.root)
        self.game = self.root / "outputs/AshenOathTheRoadBetweenCrowns"
        self.folder = self.root / "art_source/art_recovery_v2/evidence/living_assets_stage3_20261107/scenery/combined_original"

    def tearDown(self):
        self.temp.cleanup()

    def test_missing_sparse_source_uses_exact_commit(self):
        target = self.game / module.OUTPUTS["hart"]
        expected = target.read_bytes()
        target.unlink()
        result = module.freeze(self.root)
        row = next(row for row in result["meshes"] if row["id"] == "hart")
        self.assertEqual((self.folder / row["frozen"]).read_bytes(), expected)
        self.assertTrue(row["origin"].startswith("git:"))
        self.assertFalse(target.exists())

    def test_existing_authored_bytes_take_precedence(self):
        target = self.game / module.OUTPUTS["mill"]
        authored = b"RSCCauthored existing bytes"
        target.write_bytes(authored)
        row = next(row for row in module.freeze(self.root)["meshes"] if row["id"] == "mill")
        self.assertEqual(row["origin"], "worktree")
        self.assertEqual((self.folder / row["frozen"]).read_bytes(), authored)
        self.assertEqual(target.read_bytes(), authored)

    def test_repeat_does_not_shift_baseline_after_bake(self):
        first = module.freeze(self.root)
        (self.game / module.OUTPUTS["mill"]).write_bytes(b"RSRCnew split output")
        self.assertEqual(module.freeze(self.root), first)

    def test_corrupt_archive_is_rejected(self):
        result = module.freeze(self.root)
        (self.folder / result["meshes"][0]["frozen"]).write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "Frozen original changed"):
            module.freeze(self.root)

    def test_incomplete_archive_is_preserved(self):
        self.folder.mkdir(parents=True)
        pending = self.folder / "pending.res"
        pending.write_bytes(b"RSRCpartial")
        with self.assertRaisesRegex(ValueError, "incomplete"):
            module.freeze(self.root)
        self.assertEqual(pending.read_bytes(), b"RSRCpartial")

    def test_non_native_input_fails_before_any_freeze_write(self):
        (self.game / module.OUTPUTS["mill"]).write_bytes(b"not a native mesh")
        with self.assertRaisesRegex(ValueError, "Expected a native"):
            module.freeze(self.root)
        self.assertFalse(self.folder.exists())


class MaterialBindingSourceTests(unittest.TestCase):
    def test_split_and_static_use_the_unchanged_frozen_surface_policy(self):
        root = Path(__file__).resolve().parents[3]
        folder = root / "art_source/art_recovery_v2/evidence/living_assets_stage3_20261107/scenery/combined_original"
        manifest = json.loads((folder / "manifest.json").read_text())
        snapshot = next(row for row in manifest["source_snapshots"] if row["path"].endswith("campaign_wilds_presentation.gd"))
        original = (folder / snapshot["frozen"]).read_text()
        current = (root / "outputs/AshenOathTheRoadBetweenCrowns/scripts/zones/campaign_wilds_presentation.gd").read_text()
        old_method = original.split("static func _publish(", 1)[1].split("\nstatic func ", 1)[0]
        policy = old_method[old_method.index("\tfor surface in node.mesh.get_surface_count():"):].split("\n\tcontext.add_node(node)", 1)[0]
        helper = current.split("static func _apply_surface_materials(", 1)[1].split("\nstatic func ", 1)[0]
        self.assertEqual(helper[helper.index("\tfor surface in node.mesh.get_surface_count():"):].strip(), policy.strip())
        static = current.split("static func _publish(", 1)[1].split("\nstatic func ", 1)[0]
        moving = current.split("static func _living_parts(", 1)[1].split("\nstatic func ", 1)[0]
        self.assertIn("_apply_surface_materials(context, node)", static)
        self.assertIn("_apply_surface_materials(context, child as MeshInstance3D)", moving)


if __name__ == "__main__":
    unittest.main()
