import json
from pathlib import Path
import tempfile
import unittest

from verify_living_cast_delivery import ART, GAME, digest, expected_clips, verify, resource


class CompiledCastIdentity(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.folder = self.root / ART / "models/living_cast_stage2_20261107"
        self.carrier = self.folder / "C11/C11_life_review.glb"
        self.blend = self.folder / "C11/C11_living_cast_v001.blend"
        self.recipe = self.root / ART / "models/recipes/frozen.py"
        self.model = self.root / GAME / "assets_external/design_pack_v1/humans/C11_Nessa.glb"
        self.output = self.root / GAME / "assets_external/characters_prepared/animations/life_C11.res"
        for path in (self.carrier,self.blend,self.recipe,self.model,self.output):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(path.name.encode())
        self.authored = {"asset":"C11", "review_glb_sha256":digest(self.carrier), "blend":"C:/different/checkout/"+self.blend.name,
                         "blend_sha256":digest(self.blend), "production_sha256":digest(self.model),
                         "recipe_snapshot":{"files":[{"path":"models/recipes/frozen.py", "sha256":digest(self.recipe)}]}}
        self.compiled = {"asset":"C11", "source_sha256":digest(self.carrier), "sha256":digest(self.output), "bytes":self.output.stat().st_size,
                         "path":"res://"+self.output.relative_to(self.root / GAME).as_posix(),
                         "model":"res://"+self.model.relative_to(self.root / GAME).as_posix(), "model_sha256":digest(self.model),
                         "maximum_rest_error":0.0, "clips":{clip:{"duration":duration} for clip,duration in expected_clips("C11").items()}}
        self.write_receipts()

    def write_receipts(self):
        (self.folder / "C11/authoring.json").write_text(json.dumps(self.authored), encoding="utf-8")
        (self.folder / "library_compile_C11.json").write_text(json.dumps({"status":"compiled", "libraries":[self.compiled]}), encoding="utf-8")

    def result(self): return verify(self.root, ["C11"])

    def test_exact_sources_can_move_between_worktrees(self):
        result = self.result()
        self.assertEqual(result["status"], "pass", result)
        self.assertFalse(result["visual_acceptance"])

    def test_reauthored_carrier_cannot_reuse_old_native_library(self):
        self.carrier.write_bytes(b"new authored motion")
        self.authored["review_glb_sha256"] = digest(self.carrier)
        self.write_receipts()
        result = self.result()
        self.assertEqual(result["status"], "fail")
        self.assertIn("rebuild required", result["errors"][0])

    def test_changed_compiled_bytes_and_recipe_are_rejected(self):
        self.output.write_bytes(b"another library")
        self.assertEqual(self.result()["status"], "fail")
        self.output.write_bytes(self.output.name.encode())
        self.recipe.write_bytes(b"modified archived recipe")
        self.assertIn("archived recipe bytes differ", self.result()["errors"][0])

    def test_retained_model_rest_and_clip_identity_are_required(self):
        for field,value in (("model_sha256","0"*64),("maximum_rest_error",0.01),("clips",{})):
            original = self.compiled[field]
            self.compiled[field] = value
            self.write_receipts()
            self.assertEqual(self.result()["status"], "fail", field)
            self.compiled[field] = original

    def test_paths_cannot_escape_the_current_project(self):
        with self.assertRaises(ValueError): resource(self.root / GAME,"res://../../outside.res")


if __name__ == "__main__": unittest.main()
