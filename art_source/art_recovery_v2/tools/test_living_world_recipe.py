"""Pure archive/reproduction checks; Blender is never imported or launched."""
from pathlib import Path
import json
import tempfile
import unittest
from unittest.mock import patch

import author_living_world_parts as recipe


class RecipeIdentityTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='ao-scenery-recipe-')
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        self.folder=self.root/'models/cloth';self.folder.mkdir(parents=True)
        self.live=self.root/'tools/living_world_gltf_transport.py'
        self.live.parent.mkdir();self.live.write_text("VALUE='live'\n")
        self.archived=self.folder/'old_helper.py';self.archived.write_text("VALUE='archived'\n")
        self.receipt=self.folder/'authoring.json'
        self.receipt.write_text(json.dumps({'transport_helper':str(self.archived.relative_to(self.root)),
                                          'transport_helper_sha256':recipe.sha(self.archived)}))

    def test_archive_recipe_requires_explicit_historical_inputs(self):
        with self.assertRaisesRegex(ValueError,'archived recipe requires'):
            recipe.retained_transport(self.root,self.folder,None)

    def test_reproduction_imports_hashed_archive_instead_of_current_helper(self):
        module,path=recipe.retained_transport(self.root,self.folder,str(self.receipt.relative_to(self.root)))
        self.assertEqual(module.VALUE,'archived')
        self.assertEqual(Path(module.__file__),path)
        self.assertNotEqual(path,self.live)
        self.assertEqual(recipe.sha(path),recipe.sha(self.archived))

    def test_modified_archive_fails_before_execution(self):
        self.archived.write_text("raise RuntimeError('should never execute')\n")
        with self.assertRaisesRegex(ValueError,'helper changed'):
            recipe.retained_transport(self.root,self.folder,str(self.receipt.relative_to(self.root)))

    def test_live_authoring_executes_its_new_archive_and_retains_previous_bytes(self):
        with patch.object(recipe,'__file__',str(self.root/'tools/author_living_world_parts.py')):
            first,first_path=recipe.retained_transport(self.root,self.folder,None)
            first_bytes=first_path.read_bytes()
            self.live.write_text("VALUE='new live'\n")
            second,second_path=recipe.retained_transport(self.root,self.folder,None)
        self.assertEqual(first.VALUE,'live')
        self.assertEqual(second.VALUE,'new live')
        self.assertNotEqual(first_path,second_path)
        self.assertEqual(first_path.read_bytes(),first_bytes)


if __name__=='__main__':unittest.main()
