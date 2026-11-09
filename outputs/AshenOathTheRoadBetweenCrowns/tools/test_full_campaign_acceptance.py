"""No engine: prove complete-route receipts cannot accept seeded shortcuts."""
import copy
import json
import unittest

import run_full_campaign_acceptance as full
from community_acceptance_legacy import build_adapter


def legacy_seed(case):
    ids = full.chapter_ids(False)
    count = 5 if "_ash_" in case else 8
    zone = "old_mill" if count == 5 else "undercroft"
    flags = {} if case.endswith("missing") else {"campaign_revision": 1}
    return {"zone": zone, "world_sector": zone, "story_state": {"flags": flags},
            "quests": {"completed": dict.fromkeys(ids[:count], True), "active": {ids[count]: {"objectives": []}}}}


def ferry_seed():
    ids = full.chapter_ids(True)
    return {"zone": "hart_glade", "world_sector": "hart_glade", "story_state": {"flags": {
        "campaign_revision": 2, "community_route": "ferry", "community_route_ready": True, "community_refuge_ready": True, "confession_method": "witnesses",
        **dict.fromkeys(["community_work:"+key for key in ["ferry_landing","ferry_rope","ferry_load","refuge_bunks","refuge_shelves","refuge_places"]], True)}},
        "quests": {"completed": dict.fromkeys(ids[:-1], True), "active": {ids[-1]: {"objectives": []}}}}


def report(expected):
    fresh = expected["suite"] == "full_campaign"
    events = expected["expected_chapters"][len(expected["initial_completed"]):]
    events += ["main_hart_remembers"] * (len(expected["expected_endings"]) - 1)
    return {"suite": expected["suite"], "started_with_new_game": fresh, "seeded_boundary": not fresh,
            "initial_completed": expected["initial_completed"].copy(), "observed_chapters": expected["expected_chapters"].copy(),
            "chapter_events": [{"id": id} for id in events],
            "endings": [{"ending": id, "ritual_steps": 0 if id == "kill" else 3,
                         "visible_options": expected["expected_options"].copy(), "memorial_reload": True,
                         "return_home": True, "epilogue_presented": True, "cards": ["Authored card"],
                         "consequences": {"route": expected.get("required_departure_route", "crossing"), **dict.fromkeys(["route_crossed", "arrival", "losses_persisted", "human_evidence_preserved", "named_consent_only", "native_households", "concord_revocation_verified"], True)}}
                        for id in expected["expected_endings"]]}


class FullCampaignAcceptanceTests(unittest.TestCase):
    def test_full_run_rejects_every_seed(self):
        for seed in [b"{}", json.dumps(legacy_seed("legacy_ash_missing")).encode()]:
            with self.assertRaises(ValueError):
                full.contract("full_six_endings", seed)
        expected = full.contract("full_six_endings", None)
        self.assertEqual(len(expected["expected_chapters"]), 14)
        self.assertEqual(full.validate_report(report(expected), expected), [])

    def test_both_legacy_insertion_points_and_marker_forms(self):
        for case in [case for case in full.CASES if case.startswith("legacy_")]:
            expected = full.contract(case, json.dumps(legacy_seed(case)).encode())
            self.assertEqual(len(expected["expected_chapters"]), 10)
            self.assertEqual(full.validate_report(report(expected), expected), [])

    def test_legacy_marker_never_upgrades_by_case_or_location(self):
        for case in [case for case in full.CASES if case.startswith("legacy_")]:
            value = legacy_seed(case)
            value["story_state"]["flags"]["campaign_revision"] = 2
            with self.assertRaises(ValueError):
                full.contract(case, json.dumps(value).encode())
            value = legacy_seed(case)
            value["zone"] = "lantern_reach" if "_ash_" in case else "hearthward"
            with self.assertRaises(ValueError):
                full.contract(case, json.dumps(value).encode())

    def test_legacy_seed_cannot_precomplete_remaining_chain(self):
        for case in [case for case in full.CASES if case.startswith("legacy_")]:
            value = legacy_seed(case)
            value["quests"]["completed"]["main_hart_remembers"] = True
            with self.assertRaises(ValueError):
                full.contract(case, json.dumps(value).encode())

    def test_every_skipped_or_reordered_chapter_fails_receipt(self):
        expected = full.contract("full_six_endings", None)
        for index in range(14):
            value = report(expected)
            value["chapter_events"].pop(index)
            self.assertTrue(full.validate_report(value, expected))
        value = report(expected)
        value["observed_chapters"][5:7] = reversed(value["observed_chapters"][5:7])
        self.assertTrue(full.validate_report(value, expected))

    def test_every_ending_requires_enact_reload_home_and_epilogue(self):
        expected = full.contract("full_six_endings", None)
        for index in range(6):
            for field in ["memorial_reload", "return_home", "epilogue_presented"]:
                value = report(expected)
                value["endings"][index][field] = False
                self.assertTrue(full.validate_report(value, expected))
            value = report(expected)
            value["endings"][index]["ritual_steps"] = 0 if index != 3 else 3
            self.assertTrue(full.validate_report(value, expected))
        value = report(expected)
        value["endings"].pop()
        self.assertTrue(full.validate_report(value, expected))

    def test_expanded_endings_require_their_actual_costs_and_continuing_choices(self):
        expected = full.contract("full_six_endings", None)
        for ending, fields in [("depart", ["route_crossed", "arrival", "losses_persisted", "human_evidence_preserved", "named_consent_only", "native_households"]), ("share", ["concord_revocation_verified"])]:
            for field in fields:
                value = report(expected)
                row = next(row for row in value["endings"] if row["ending"] == ending)
                row["consequences"][field] = False
                self.assertTrue(full.validate_report(value, expected))

    def test_ferry_ending_is_separate_seeded_boundary_proof(self):
        value = ferry_seed()
        expected = full.contract("seeded_departure_ferry", json.dumps(value).encode())
        self.assertEqual(expected["suite"], "seeded_departure")
        self.assertEqual(len(expected["initial_completed"]), 13)
        self.assertEqual(full.validate_report(report(expected), expected), [])
        forged = report(expected)
        forged["suite"] = "full_campaign"
        forged["started_with_new_game"] = True
        self.assertTrue(full.validate_report(forged, expected))
        forged = report(expected)
        forged["endings"][0]["consequences"]["route"] = "crossing"
        self.assertTrue(full.validate_report(forged, expected))
        for key, bad in [("open_road_route_crossed", True), ("covenant_ritual_started", True), ("community_route", "crossing"), ("campaign_revision", 1), ("community_refuge_ready", "true"), ("community_work:ferry_rope", False), ("confession_method", "")]:
            changed = copy.deepcopy(value)
            changed["story_state"]["flags"][key] = bad
            with self.assertRaises(ValueError): full.contract("seeded_departure_ferry", json.dumps(changed).encode())
        with self.assertRaises(ValueError): full.contract("seeded_departure_ferry", None)

    def test_original_four_menu_is_preserved_for_legacy(self):
        case = "legacy_witness_missing"
        expected = full.contract(case, json.dumps(legacy_seed(case)).encode())
        value = report(expected)
        value["endings"][0]["visible_options"] = full.ENDINGS.copy()
        self.assertTrue(full.validate_report(value, expected))

    def test_adapter_is_derived_from_real_input_and_has_current_overrides(self):
        source = full.LEGACY_SOURCE.read_text(encoding="utf-8")
        adapter, helpers = build_adapter(source)
        self.assertIn("_fight_hart_ending", helpers)
        self.assertIn('owner._button("Quick Save")', adapter)
        self.assertIn('owner._travel("assembly")', adapter)
        self.assertNotIn('"hart_gate_approach"', adapter)
        self.assertNotIn('focused.text == "Save"', adapter)
        self.assertNotIn('save_png("D:', adapter)
        self.assertNotIn("func _initialize", adapter)
        changed = source.replace('func _fight_hart_ending(game: Node, covenant: String) -> void:',
                                 'func _fight_hart_ending(game: Node, covenant: String) -> void:\n\tgame.story_state.set_flag("fake",true)')
        with self.assertRaises(ValueError):
            build_adapter(changed)

    def test_inherited_stat_camera_and_replay_shortcuts_are_rejected(self):
        source = full.LEGACY_SOURCE.read_text(encoding="utf-8")
        declaration = 'func _fight_hart_ending(game: Node, covenant: String) -> void:'
        for shortcut in ['game.player.health_component.health += 100', 'game.player.stamina_component.stamina = 100',
                         'game.camera_rig.yaw = 0', 'game.player.global_transform = Transform3D.IDENTITY',
                         'game.save_manager.load_game(game)', 'game.load_save_state({})',
                         'game.player.set("health",100)', 'game.inventory.add_item("redroot_potion",5)',
                         'game.player.position.y = 12', 'game.quests.completed["main_hart_remembers"] = true',
                         'game.call("_load_zone","hart_glade")']:
            with self.subTest(shortcut=shortcut), self.assertRaises(ValueError):
                build_adapter(source.replace(declaration, declaration+'\n\t'+shortcut))

    def test_full_entry_has_no_progression_or_travel_shortcuts(self):
        source = full.HARNESS.read_text(encoding="utf-8")
        for shortcut in [".set_flag(", ".complete_objective(", ".complete_choice(", ".load_save_state(",
                         "._load_zone(", "._load_zone_after_runtime_pack(", ".global_position=", ".global_position ="]:
            self.assertNotIn(shortcut, source)
        self.assertIn('await _button("New Game" if expanded and not seeded_ferry else "Continue")', source)


if __name__ == "__main__":
    unittest.main()
