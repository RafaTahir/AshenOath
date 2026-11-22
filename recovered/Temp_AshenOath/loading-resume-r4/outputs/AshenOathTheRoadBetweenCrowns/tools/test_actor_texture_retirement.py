import json
import tempfile
import unittest
from pathlib import Path

from partition_actor_packs import ACTOR_TEXTURE_DIRECTORIES, retired_actor_textures


class ActorTextureRetirement(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix="ashen-atlas-")
        self.addCleanup(self.folder.cleanup)
        self.project = Path(self.folder.name)
        (self.project / "data").mkdir()
        (self.project / "scripts").mkdir()
        self.directory = ACTOR_TEXTURE_DIRECTORIES[1]
        self.old = "res://" + self.directory + "M01_Old_basecolor.png"
        self.active = "res://" + self.directory + "color_current.png"
        for path in [self.old, self.active]:
            file = self.project / path.removeprefix("res://")
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_bytes(b"editable source remains intact")

    def test_current_closure_kept_and_old_unowned_atlas_retired(self):
        retired = retired_actor_textures(self.project, {self.active}, {self.old, self.active})
        self.assertEqual({self.old}, retired)
        self.assertTrue((self.project / self.old.removeprefix("res://")).is_file())

    def test_direct_loader_and_basename_construction_are_retained(self):
        for statement in [f'var t = load("{self.old}")', 'var filename = "M01_Old_basecolor.png"']:
            (self.project / "scripts/consumer.gd").write_text(statement)
            self.assertNotIn(self.old, retired_actor_textures(self.project, {self.active}, {self.old}))

    def test_computed_directory_load_conservatively_keeps_namespace(self):
        (self.project / "scripts/consumer.gd").write_text(f'const TEX = "res://{self.directory}"')
        self.assertEqual(set(), retired_actor_textures(self.project, set(), {self.old, self.active}))

    def test_environment_user_is_preserved(self):
        (self.project / "data/environment_material_dependencies.json").write_text(json.dumps({"textures": {self.old: {"owner": "opening"}}}))
        self.assertNotIn(self.old, retired_actor_textures(self.project, {self.active}, {self.old}))

    def test_unrelated_dynamic_skins_are_never_managed(self):
        skin = "res://assets_external/textures/runtime/ghoulkin_skin.jpg"
        self.assertNotIn(skin, retired_actor_textures(self.project, {self.active}, {skin}))

    def test_retired_root_level_atlas_is_retired_but_model_is_not(self):
        image = "res://assets_external/design_pack_v1/creatures/M01_Ghoulkin_M01_basecolor.png"
        model = "res://assets_external/design_pack_v1/creatures/M01_Ghoulkin.glb"
        retired = retired_actor_textures(self.project, {self.active}, {image, model})
        self.assertIn(image, retired)
        self.assertNotIn(model, retired)

    def test_template_loader_preserves_unknown_legacy_root_images(self):
        image = "res://assets_external/design_pack_v1/creatures/M01_basecolor.png"
        (self.project / "scripts/consumer.gd").write_text('var path = "res://assets_external/design_pack_v1/creatures/%s_basecolor.png" % id')
        self.assertNotIn(image, retired_actor_textures(self.project, {self.active}, {image}))

    def test_family_classification_does_not_keep_every_old_image(self):
        image = "res://assets_external/design_pack_v1/creatures/M01_basecolor.png"
        (self.project / "scripts/consumer.gd").write_text('var creature = path.begins_with("res://assets_external/design_pack_v1/creatures/")')
        self.assertIn(image, retired_actor_textures(self.project, {self.active}, {image}))


if __name__ == "__main__":
    unittest.main()
