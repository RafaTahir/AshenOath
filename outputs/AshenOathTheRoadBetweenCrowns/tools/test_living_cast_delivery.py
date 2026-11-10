import json
from pathlib import Path
import tempfile
import unittest

from verify_living_cast_delivery import ART, GAME, PROP_RESOURCES, digest, expected_clips, verify, resource, verify_stage2_prop


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
        self.assertNotIn("stage2_props", result)

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


class CompiledPropIdentity(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.game = self.root / GAME
        self.models = self.root / ART / "models/living_cast_stage2_20261107"
        self.props = self.models / "props"
        self.asset = "station_nessa"
        self.scene = PROP_RESOURCES + self.asset + ".scn"
        self.component = PROP_RESOURCES + self.asset + "_00.res"
        self.carrier = self.props / (self.asset + ".glb")
        self.receipt = self.props / (self.asset + "_compile.json")
        self.authoring = self.props / (self.asset + "_authoring.json")
        self.authored = {"identity":"nessa", "runtime_resource":self.scene, "sources":[],
                         "carrier_sha256":self.put(self.carrier, b"authored carrier")}
        self.compiled = {"identity":"nessa", "path":self.scene, "geometry_contact_verified":True, "support_bounds_verified":True,
                         "source_sha256":self.authored["carrier_sha256"],
                         "sha256":self.put(resource(self.game, self.scene), b"compiled scene"),
                         "resources":[{"path":self.component, "sha256":self.put(resource(self.game, self.component), b"compiled mesh")}]}
        self.put(self.authoring, self.authored)
        self.put(self.receipt, self.compiled)

    def put(self, path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(value if isinstance(value, bytes) else json.dumps(value).encode())
        return digest(path)

    def test_opt_in_requires_all_eight_prop_receipts(self):
        result = verify(self.root, [], verify_stage2_props=True)
        self.assertEqual(result["status"], "fail")
        self.assertEqual([row["asset"] for row in result["stage2_props"]], [self.asset])
        self.assertEqual(len(result["errors"]), 7)
        self.assertTrue(any(error.startswith("merrow_cup: ") for error in result["errors"]))

    def test_updated_carrier_rejects_stale_compiler_receipt(self):
        self.authored["carrier_sha256"] = self.put(self.carrier, b"changed authored carrier")
        self.put(self.authoring, self.authored)
        with self.assertRaisesRegex(ValueError, "Authored carrier differs"):
            verify_stage2_prop(self.root, self.asset)

    def test_changed_or_unrecorded_component_is_rejected(self):
        mesh = resource(self.game, self.component)
        self.put(mesh, b"changed compiled mesh")
        with self.assertRaisesRegex(ValueError, "Compiled station component hash differs"):
            verify_stage2_prop(self.root, self.asset)
        self.put(mesh, b"compiled mesh")
        self.put(mesh.with_name("station_nessa_01.res"), b"unrecorded component")
        with self.assertRaisesRegex(ValueError, "Actual prop component inventory differs"):
            verify_stage2_prop(self.root, self.asset)

    def test_inline_cup_binds_relocated_calibration_and_clearance(self):
        actor = self.models / "C10"
        scene = PROP_RESOURCES + "merrow_cup.scn"
        cup_hash = self.put(self.props / "merrow_cup_world.glb", b"authored cup")
        actor_hash = self.put(actor / "C10_life_review.glb", b"authored actor")
        self.put(actor / "authoring.json", {"review_glb_sha256":actor_hash, "baseline_sha256":"b"*64})
        clearance = actor / "source_cup_clearance.json"
        clearance_hash = self.put(clearance, {"actor_carrier_sha256":actor_hash, "cup_carrier_sha256":cup_hash,
                                              "source_trajectory_clear":True, "full_trajectory_sampled":True})
        calibration = {"identity":"merrow", "runtime_resource":scene, "carrier_sha256":cup_hash, "baseline_sha256":"b"*64,
                       "grip_verified":True, "rim_calibrated":True, "sources":[]}
        calibration_hash = self.put(self.props / "merrow_cup_calibration.json", calibration)
        archive = "merrow_cup_calibration_" + calibration_hash + ".json"
        self.put(self.props / "receipts" / archive, calibration)
        self.put(self.props / "merrow_cup_compile.json", {"path":scene, "source_sha256":cup_hash,
                 "sha256":self.put(resource(self.game, scene), b"inline cup scene"), "inline_mesh_count":2,
                 "calibration_sha256":calibration_hash, "calibration_archive":"C:/old/checkout/"+archive,
                 "compiler_sha256":self.put(self.game / "tools/build_merrow_cup.gd", b"compiler"),
                 "actor_source_sha256":actor_hash, "source_clearance_sha256":clearance_hash,
                 "source_full_motion_clearance_verified":True})
        self.assertEqual(verify_stage2_prop(self.root, "merrow_cup")["components"], [])
        self.put(clearance, b"changed proof")
        with self.assertRaisesRegex(ValueError, "Cup source clearance hash differs"):
            verify_stage2_prop(self.root, "merrow_cup")


if __name__ == "__main__": unittest.main()
