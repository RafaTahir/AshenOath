"""Pure receipt/resume/source-closure fixtures; never launch an engine."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from run_monster_live_route import OVERLAY, RELATIVE_PROJECT, attempt_directory, save, sha, source_snapshot, toolchain_sha256, validate_resume, verify_overlay


class LiveRouteRunnerEvidence(unittest.TestCase):
    def setUp(self):
        self.root = Path("D:/Temp/AO_MonsterVitality_20261118/pure_live_route_tests").resolve()
        self.root.mkdir(parents=True,exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=self.root,prefix="receipts_")
        self.folder = Path(self.temporary.name).resolve()
        self.assertTrue(self.folder.is_relative_to(self.root))
        self.output = self.folder/"matrix"
        self.output.mkdir()
        save(self.output/"baseline_import_projection.json",{"fixture":"import proof; no engine"})
        save(self.output/"prepared_monster_identity.json",{"fixture":"prepared proof; no engine"})
        self.projects = {name:self.folder/name for name in ("baseline","candidate")}
        for path in self.projects.values(): path.mkdir()
        self.snapshots = {name:{"sha256":name+"_snapshot"} for name in self.projects}
        self.tools = [{"path":"pure_fixture_tool.gd","sha256":"fixture_tool_hash"}]

    def tearDown(self):
        # Resolve the generated target before recursive test-artifact cleanup.
        self.assertTrue(self.folder.resolve().is_relative_to(self.root))
        self.temporary.cleanup()

    def observation(self):
        directory = self.output/"desktop_0_baseline"
        directory.mkdir()
        isolated = directory/"isolated_project"
        isolated.mkdir()
        (isolated/"project.godot").write_text("fixture isolated configuration")
        user = directory/"profile/roaming/disposable_fixture"
        report = {"viewport":[1280,720],"passed":True,"failures":[],"engine_errors":[],"user_data_dir":str(user)}
        save(directory/"report.json",report)
        (directory/"stdout.log").write_text("fixture: no engine was launched\n")
        (directory/"godot.log").write_text("fixture engine log\n")
        receipt = {"status":"pass","exit_code":0,"project":str(self.projects["baseline"]),"output":str(directory),
                   "qa_toolchain":self.tools,"source_snapshot_sha256":self.snapshots["baseline"]["sha256"],
                   "qa_script_sha256":"script_hash","qa_coordinates_sha256":"coordinate_hash","godot_sha256":"godot_hash",
                   "import_projection_file":str(self.output/"baseline_import_projection.json"),"import_projection_sha256":sha(self.output/"baseline_import_projection.json"),
                   "prepared_identity_file":str(self.output/"prepared_monster_identity.json"),"prepared_identity_sha256":sha(self.output/"prepared_monster_identity.json"),
                   "expected_user_data_dir":str(user),"isolated_project":str(isolated),"configuration_sha256":sha(isolated/"project.godot"),
                   "environment":{"APPDATA":str(directory/"profile/roaming"),"LOCALAPPDATA":str(directory/"profile/local")},
                   "evidence_files":{name:sha(directory/name) for name in ("report.json","stdout.log","godot.log")}}
        save(directory/"receipt.json",receipt)
        return {"version":"baseline","repeat":0,"report":report,"qa_script_sha256":"script_hash",
                "qa_toolchain_sha256":toolchain_sha256(self.tools),"source_snapshot_sha256":self.snapshots["baseline"]["sha256"],
                "run_directory":str(directory),"receipt_sha256":sha(directory/"receipt.json")}

    def validate(self,observations,**overrides):
        args = {"observations":observations,"output":self.output,"projects":self.projects,"snapshots":self.snapshots,
                "tools":self.tools,"script_hash":"script_hash","coordinates_hash":"coordinate_hash","godot_hash":"godot_hash"}
        args.update(overrides)
        return validate_resume(**args)

    def rewrite_receipt(self,item,mutate):
        path = Path(item["run_directory"])/"receipt.json"
        receipt = json.loads(path.read_text())
        mutate(receipt)
        save(path,receipt)
        item["receipt_sha256"] = sha(path)

    def test_exact_completed_run_can_resume_without_rerunning(self):
        self.assertEqual(self.validate([self.observation()]),{("desktop","baseline",0)})
        self.assertEqual(self.validate([]),set())

    def test_changed_sources_toolchain_or_engine_reject_reuse(self):
        item = self.observation()
        for overrides in ({"script_hash":"changed"},{"coordinates_hash":"changed"},{"godot_hash":"changed"},
                          {"tools":[{"path":"changed","sha256":"changed"}]},
                          {"snapshots":{"baseline":{"sha256":"changed"},"candidate":self.snapshots["candidate"]}}):
            with self.subTest(overrides=overrides),self.assertRaises(ValueError): self.validate([item],**overrides)

    def test_tampered_report_or_logs_cannot_resume(self):
        item = self.observation()
        for name in ("report.json","stdout.log","godot.log"):
            path = Path(item["run_directory"])/name
            old = path.read_bytes()
            path.write_bytes(old+b"changed")
            with self.subTest(file=name),self.assertRaises(ValueError): self.validate([item])
            path.write_bytes(old)

    def test_tampered_receipt_and_isolated_config_cannot_resume(self):
        item = self.observation()
        receipt = Path(item["run_directory"])/"receipt.json"
        old = receipt.read_bytes()
        receipt.write_bytes(old+b" ")
        with self.assertRaises(ValueError): self.validate([item])
        receipt.write_bytes(old)
        (Path(item["run_directory"])/"isolated_project/project.godot").write_text("changed")
        with self.assertRaises(ValueError): self.validate([item])

    def test_failed_attempt_is_never_reused_even_with_updated_receipt_hash(self):
        item = self.observation()
        self.rewrite_receipt(item,lambda receipt:receipt.update(status="fail",exit_code=1))
        with self.assertRaises(ValueError): self.validate([item])

    def test_changed_baseline_preparation_proof_cannot_resume(self):
        item = self.observation()
        for name in ("baseline_import_projection.json","prepared_monster_identity.json"):
            path = self.output/name
            old = path.read_bytes()
            path.write_bytes(old+b"changed")
            with self.subTest(proof=name),self.assertRaises(ValueError): self.validate([item])
            path.write_bytes(old)

    def test_duplicate_or_escaping_saved_run_rejected(self):
        item = self.observation()
        with self.assertRaises(ValueError): self.validate([item,copy.deepcopy(item)])
        item["run_directory"] = str(self.folder)
        with self.assertRaises(ValueError): self.validate([item])

    def test_saved_report_body_and_profile_identity_are_exact(self):
        item = self.observation()
        altered = copy.deepcopy(item)
        altered["report"]["passed"] = False
        with self.assertRaises(ValueError): self.validate([altered])
        self.rewrite_receipt(item,lambda receipt:receipt.update(environment={"APPDATA":"C:/Users/User/AppData/Roaming"}))
        with self.assertRaises(ValueError): self.validate([item])

    def test_retry_gets_fresh_directory_and_preserves_failed_artifacts(self):
        first = attempt_directory(self.output,"touch","candidate",0,False)
        first.mkdir()
        (first/"failed_report.json").write_text("retain failed evidence")
        with self.assertRaises(ValueError): attempt_directory(self.output,"touch","candidate",0,False)
        second = attempt_directory(self.output,"touch","candidate",0,True)
        self.assertEqual(second.name,"touch_0_candidate_attempt2")
        second.mkdir()
        third = attempt_directory(self.output,"touch","candidate",0,True)
        self.assertEqual(third.name,"touch_0_candidate_attempt3")
        self.assertEqual((first/"failed_report.json").read_text(),"retain failed evidence")
        with self.assertRaises(ValueError): attempt_directory(self.output,"../escape","candidate",0,True)

    def test_source_closure_pins_root_shaders_includes_and_manifests(self):
        project = self.projects["candidate"]
        (project/"project.godot").write_text("fixture project")
        (project/"shaders").mkdir()
        shader = project/"shaders/monster_pigment.gdshader"
        include = project/"shaders/monster_pigment_common.gdshaderinc"
        manifest = project/"asset_role_mappings.json"
        shader.write_text("shader fixture")
        include.write_text("include fixture")
        manifest.write_text('{"fixture":true}')
        original = source_snapshot(project)
        self.assertEqual({row["path"] for row in original["files"]},{"project.godot","shaders/monster_pigment.gdshader","shaders/monster_pigment_common.gdshaderinc","asset_role_mappings.json"})
        for path in (shader,include,manifest):
            old = path.read_text()
            path.write_text(old+" changed")
            self.assertNotEqual(source_snapshot(project)["sha256"],original["sha256"])
            path.write_text(old)

    def test_eighth_shared_hud_prerequisite_does_not_admit_intervention_or_missing_fixes(self):
        rows = []
        for name in OVERLAY:
            for project in self.projects.values():
                path = project/name
                path.parent.mkdir(parents=True,exist_ok=True)
                path.write_bytes(b"shared prerequisite fixture")
            rows.append({"path":name,"overlay_sha256":sha(self.projects["baseline"]/name)})
        receipt = {"base_commit":"fixture_base","baseline_project":str(self.projects["baseline"]),
                   "candidate_project":str(self.projects["candidate"]),"overlay":rows}
        changed = [(RELATIVE_PROJECT/name).as_posix() for name in OVERLAY]
        def fake_git(_repository,*args):
            if args[0]=="rev-parse": return b"fixture_base\n"
            if args[0]=="diff": return ("\n".join(changed)+"\n").encode()
            if args[0]=="ls-files": return b""
            raise AssertionError(args)
        with patch("run_monster_live_route.git",side_effect=fake_git):
            verify_overlay(receipt)
            hud = (RELATIVE_PROJECT/"scripts/hud_navigation_dial.gd").as_posix()
            changed.remove(hud)
            with self.assertRaises(ValueError): verify_overlay(receipt)
            changed.append(hud)
            changed.append((RELATIVE_PROJECT/"scripts/models/enemy_tactics_model.gd").as_posix())
            with self.assertRaises(ValueError): verify_overlay(receipt)


if __name__ == "__main__":
    unittest.main()
