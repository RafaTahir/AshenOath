"""Source-only checks for acceptance isolation and non-injected coverage."""
import json
import contextlib
import io
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import run_community_acceptance as runner


def seed(case):
    zone, chapter, _ = runner.CASES[case]
    flags = {"campaign_revision": 2}
    if case == "hearth_distributed":
        flags.update(senn_fate="testimony", edric_stance="cooperate", escort_abandonment_acknowledged=True)
    return {"zone": zone, "world_sector": zone, "replay_session": False,
            "story_state": {"flags": flags},
            "quests": {"active": {chapter: {"objectives": [
                {"id": "reach_lantern_reach" if case.startswith("lantern") else "reach_hearthward", "done": False}
            ]}}}}


class AcceptanceContractTests(unittest.TestCase):
    def validate(self, value, case="lantern_crossing"):
        return runner.validate_seed(json.dumps(value).encode(), case)

    def test_four_cases_cover_all_fifteen_authored_tasks(self):
        covered = set()
        for case in runner.CASES:
            contract = self.validate(seed(case), case)
            self.assertEqual(len(contract["expected_work"]), 6)
            covered.update(contract["expected_work"])
        authored = json.loads((runner.PROJECT / "data/community_campaign.json").read_text(encoding="utf-8"))
        self.assertEqual(covered, set(authored["work"]))
        self.assertEqual(len(covered), 15)

    def test_legacy_missing_and_malformed_revision_are_rejected(self):
        for revision in [None, 1, True, "2", 2.1]:
            value = seed("lantern_crossing")
            value["story_state"]["flags"]["campaign_revision"] = revision
            with self.subTest(revision=revision), self.assertRaises(ValueError):
                self.validate(value)

    def test_awarded_tasks_and_choices_are_rejected(self):
        for case, (_, _, tasks) in runner.CASES.items():
            for task in tasks:
                value = seed(case)
                value["story_state"]["flags"]["community_work:" + task] = True
                with self.subTest(case=case, task=task), self.assertRaises(ValueError):
                    self.validate(value, case)
            value = seed(case)
            value["story_state"]["flags"]["community_distribution" if case.startswith("lantern") else "community_records"] = "already_selected"
            with self.assertRaises(ValueError):
                self.validate(value, case)

    def test_arrival_cannot_be_preawarded_or_moved_to_destination(self):
        value = seed("lantern_crossing")
        value["quests"]["active"]["main_empty_tables"]["objectives"][0]["done"] = True
        with self.assertRaises(ValueError):
            self.validate(value)
        value = seed("lantern_crossing")
        value["world_sector"] = "lantern_reach"
        with self.assertRaises(ValueError):
            self.validate(value)

    def test_malformed_save_shapes_fail_closed(self):
        for field in ["story_state", "quests"]:
            for malformed in [None, [], "bad"]:
                value = seed("lantern_crossing")
                value[field] = malformed
                with self.subTest(field=field, malformed=malformed), self.assertRaises(ValueError):
                    self.validate(value)

    def test_hearth_cases_require_present_and_absent_cast_coverage(self):
        for case in ["hearth_distributed", "hearth_protected"]:
            value = seed(case)
            value["story_state"]["flags"]["senn_fate"] = "punished" if case == "hearth_distributed" else "testimony"
            with self.assertRaises(ValueError):
                self.validate(value, case)

    def test_user_directory_is_configured_before_engine_start(self):
        original = b'[application]\nconfig/name="Ashen Oath"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
        isolated = runner.isolated_configuration(original, "AshenOathCapture/community_fixture").decode()
        self.assertIn('config/custom_user_dir_name="AshenOathCapture/community_fixture"', isolated)
        self.assertIn("config/use_custom_user_dir=true", isolated)
        self.assertIn('renderer/rendering_method="gl_compatibility"', isolated)
        with self.assertRaises(ValueError):
            runner.isolated_configuration(original, "../real-profile")

    def test_world_harness_has_no_progression_or_position_shortcuts(self):
        source = runner.HARNESS.read_text(encoding="utf-8")
        for forbidden in [".set_flag(", ".complete_objective(", ".complete_choice(", ".record_consent(",
                          ".apply_board_action(", ".global_position =", ".global_position=", ".choose(",
                          ".activate(", "_handle_interaction(", "._apply_mouse_motion(", ".emit_signal(",
                          "DisplayServer.window_move_to_foreground(", "Input.warp_mouse("]:
            self.assertNotIn(forbidden, source)
        self.assertIn("Input.parse_input_event(event)", source)


class BackgroundReceiptTests(unittest.TestCase):
    def run_fixture(self, change=None, timeout=False):
        """Mock only process creation; exercise the complete receipt validator."""
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder)
            image = output / "observation.png"
            image.write_bytes(b"mock image; this fixture makes no rendering claim")
            report = {"status":"pass", "failures":[], "case":"fixture", "completed_work":[],
                      "progression_injection":False, "input_events":60, "execution_mode":"background-rendered",
                      "capture_desktop":"owned_fixture", "viewport_size":[1280,720],
                      "mounted_pack_ids":["community"], "candidate_build_id":"fixture",
                      "no_focus":True, "headless":False, "renderer":"gl_compatibility",
                      "user_data_dir":str(output / "profile"), "observations":[{"image":str(image)}]}
            if change:
                report.update(change)
            runner.write(output / "report.json", report)
            receipt = {"output":str(output), "immutable_inputs":[], "environment":{}, "command":["mock_engine"],
                       "isolated_project":str(output), "timeout_seconds":1, "case":"fixture",
                       "seed_contract":{"expected_work":[]}, "viewport":"desktop",
                       "candidate_closure":{"packs":[{"id":"community"}],"build_id":"fixture"},
                       "expected_user_data_dir":str(output / "profile")}
            process = SimpleNamespace(pid=123, stopped=False, closed=False, desktop_receipt={
                "desktop":"owned_fixture", "input_desktop_before":"Default", "input_desktop_after_launch":"Default"})
            def wait(timeout):
                if should_timeout:
                    raise subprocess.TimeoutExpired("mock_engine", timeout)
                return 0
            def stop(owned):
                self.assertIs(owned, process)
                process.stopped = True
            def close():
                self.assertTrue(process.stopped)
                process.closed = True
                process.desktop_receipt["input_desktop_after_exit"] = "Default"
            should_timeout = timeout
            process.wait, process.close = wait, close
            helper = SimpleNamespace(spawn_background=lambda *args, **kwargs: process)
            with patch.dict(sys.modules, {"background_native_capture":helper}), patch.object(runner,"stop_owned_process",stop), contextlib.redirect_stdout(io.StringIO()):
                code = runner.run(receipt,output / "runner.json")
            self.assertTrue(process.closed)
            self.assertEqual(receipt["desktop"]["input_desktop_after_exit"],"Default")
            return code, receipt

    def test_matching_background_receipt_closes_owned_desktop(self):
        code, receipt = self.run_fixture()
        self.assertEqual(code,0)
        self.assertEqual(receipt["status"],"pass")

    def test_wrong_desktop_and_viewport_cannot_pass(self):
        for change in [{"capture_desktop":"Default"},{"viewport_size":[960,540]},{"execution_mode":"foreground"},
                       {"no_focus":False},{"headless":True},{"renderer":"dummy"},
                       {"mounted_pack_ids":["base","community"]},{"candidate_build_id":"stale"}]:
            with self.subTest(change=change):
                code, receipt = self.run_fixture(change)
                self.assertEqual(code,1)
                self.assertTrue(receipt["failures"])

    def test_timeout_still_stops_process_and_closes_desktop(self):
        code, receipt = self.run_fixture(timeout=True)
        self.assertEqual(code,1)
        self.assertIn("timed out",receipt["failures"][0])


class TouchEvidenceTests(unittest.TestCase):
    def evidence(self):
        return {"input_mode":"touch", "touch_input_coverage":True,
                "native_touchscreen_emulation":True,
                "physical_phone_coverage":False, "injected_keyboard_events":0,
                "injected_mouse_events":0, "screen_input_counts":{
                    "screen_touch":20,"screen_drag":5,"ui":2,"move":2,"look":1,"action":2},
                "screen_action_evidence":{"open_contacts":0,"simultaneous_aim_fire":0,
                    "actions":{key:{"pressed":1,"released":1,"held_ms":30} for key in ["interact","pause"]},
                    "menu_actions":{},"menu_reacquisitions":{},"ui_labels":{"Continue":1,"Quick Save":1}}}

    def test_genuine_screen_route_requires_all_input_paths(self):
        self.assertEqual(runner.validate_input_report(self.evidence(), {"input_mode":"touch"}), [])
        for key in self.evidence()["screen_input_counts"]:
            report = self.evidence()
            report["screen_input_counts"][key] = 0
            with self.subTest(missing=key):
                self.assertTrue(runner.validate_input_report(report, {"input_mode":"touch"}))

    def test_small_viewport_does_not_prove_touch_input(self):
        report = {"viewport_size":[960,540], "input_events":1000, "status":"pass"}
        self.assertTrue(runner.validate_input_report(report, {"input_mode":"touch"}))

    def test_keyboard_fallback_and_phone_claim_are_rejected(self):
        for field, value in [("injected_keyboard_events",1), ("injected_mouse_events",1),
                             ("injected_keyboard_events",False), ("injected_mouse_events",False),
                             ("touch_input_coverage",False), ("physical_phone_coverage",True),
                             ("native_touchscreen_emulation",False),
                             ("input_mode","keyboard_mouse")]:
            report = self.evidence()
            report[field] = value
            with self.subTest(field=field):
                self.assertTrue(runner.validate_input_report(report, {"input_mode":"touch"}))
        self.assertTrue(runner.validate_input_report(self.evidence(), {"input_mode":"keyboard_mouse"}))

    def test_touch_adapter_cannot_shortcut_the_game(self):
        source = (runner.PROJECT / "tools/community_touch_input.gd").read_text(encoding="utf-8")
        for forbidden in [".set_flag(", ".complete_objective(", ".global_position=", ".global_position =",
                          ".set_virtual_axes(", ".request_virtual_action(", ".add_touch_look_delta(",
                          ".pressed.emit(", ".scroll_vertical=", ".scroll_vertical =", ".grab_focus(",
                          "Input.action_press(", "InputEventKey.new", "InputEventMouseButton.new"]:
            self.assertNotIn(forbidden, source)
        self.assertIn("InputEventScreenTouch.new()", source)
        self.assertIn("InputEventScreenDrag.new()", source)

    def test_balanced_individual_actions_and_visible_ui_are_required(self):
        mutations = [lambda row: row.pop("screen_action_evidence"),
                     lambda row: row["screen_action_evidence"].update(open_contacts=1),
                     lambda row: row["screen_action_evidence"]["actions"].pop("interact"),
                     lambda row: row["screen_action_evidence"]["actions"]["interact"].update(released=0),
                     lambda row: row["screen_action_evidence"]["actions"].update(interact="invalid"),
                     lambda row: row["screen_action_evidence"].update(ui_labels={"Continue":"invalid"}),
                     lambda row: row["screen_action_evidence"].update(menu_actions={"use_potion":1}),
                     lambda row: row["screen_action_evidence"].update(menu_reacquisitions={"fire_bow":1})]
        for change in mutations:
            value = self.evidence()
            change(value)
            self.assertTrue(runner.validate_input_report(value, {"input_mode":"touch"}))

    def full_evidence(self):
        value = self.evidence()
        evidence = value["screen_action_evidence"]
        for key in ["light_attack","aim_bow","fire_bow","target_lock"]:
            evidence["actions"][key]={"pressed":1,"released":1,"held_ms":40}
        evidence["actions"]["touch_more"]={"pressed":2,"released":2,"held_ms":40}
        evidence["menu_actions"]={"weapon_sword":1,"weapon_bow":1}
        evidence["ui_labels"].update(Steel=1,Bow=1)
        evidence["simultaneous_aim_fire"]=1
        evidence["aim_mode_requests"]=[{"mode":"toggle","initial":False,"requested":True,"final":True},
                                       {"mode":"toggle","initial":True,"requested":False,"final":False}]
        value["screen_input_counts"].update(action=8,ui=4)
        return value

    def test_full_touch_campaign_requires_its_real_combat_and_more_paths(self):
        receipt={"input_mode":"touch","seed_contract":{"suite":"full_campaign"}}
        self.assertTrue(runner.validate_input_report(self.evidence(), receipt))
        self.assertEqual(runner.validate_input_report(self.full_evidence(), receipt), [])
        for field,key in [("actions","aim_bow"),("actions","fire_bow"),("actions","light_attack"),("menu_actions","weapon_bow")]:
            value=self.full_evidence()
            value["screen_action_evidence"][field].pop(key)
            self.assertTrue(runner.validate_input_report(value, receipt))
        value=self.full_evidence()
        value["screen_action_evidence"]["simultaneous_aim_fire"]=0
        self.assertTrue(runner.validate_input_report(value, receipt))

    def test_more_reacquisition_requires_fresh_press_without_automatic_attack(self):
        value=self.full_evidence()
        evidence=value["screen_action_evidence"]
        evidence["menu_reacquisitions"]={"aim_bow":1}
        self.assertTrue(runner.validate_input_report(value, {"input_mode":"touch"}))
        evidence["actions"]["aim_bow"].update(pressed=2,released=2)
        value["screen_input_counts"]["action"]+=1
        self.assertEqual(runner.validate_input_report(value, {"input_mode":"touch"}), [])
        evidence["menu_reacquisitions"]["fire_bow"]=1
        self.assertTrue(runner.validate_input_report(value, {"input_mode":"touch"}))

    def test_full_touch_aim_policy_requires_confirmed_on_and_off(self):
        receipt={"input_mode":"touch","seed_contract":{"suite":"full_campaign"}}
        for bad in [[],None,[{"mode":"toggle","initial":True,"requested":False,"final":True}],
                    [{"mode":"toggle","initial":False,"requested":True,"final":True}],
                    [{"mode":"hold","initial":0,"requested":True,"final":True}],
                    [{"mode":"forced","initial":False,"requested":True,"final":True}]]:
            value=self.full_evidence()
            value["screen_action_evidence"]["aim_mode_requests"]=bad
            self.assertTrue(runner.validate_input_report(value,receipt))
        for mode in ("hold","toggle"):
            value=self.full_evidence()
            for row in value["screen_action_evidence"]["aim_mode_requests"]: row["mode"]=mode
            self.assertEqual(runner.validate_input_report(value,receipt),[])


if __name__ == "__main__":
    unittest.main()
