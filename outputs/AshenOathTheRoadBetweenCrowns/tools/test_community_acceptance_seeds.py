"""Source-only checks for labelled boundary setup; no engine or profile access."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import prepare_community_acceptance_seeds as seeds


class BoundarySeedTests(unittest.TestCase):
    def test_all_nine_cases_match_their_actual_runner_contract(self):
        self.assertEqual(len(seeds.CASES),9)
        for case in seeds.CASES:
            with self.subTest(case=case):
                value, provenance = seeds.build_seed(case)
                seeds.seed_contract(case,json.dumps(value).encode())
                self.assertEqual(list(value["quests"]["completed"]),provenance["initial_completed"])
                self.assertEqual(list(value["quests"]["active"]),[provenance["active_chapter"]])
                self.assertTrue(all(row["done"] is False for row in value["quests"]["active"][provenance["active_chapter"]]["objectives"]))
                self.assertFalse(value["acceptance_fixture"]["full_campaign_proof"])
                self.assertFalse(provenance["native_import_validated"])
                self.assertFalse(provenance["physical_arrival_validated"])

    def test_full_campaign_seed_is_forbidden_even_if_other_data_is_valid(self):
        with self.assertRaises(ValueError): seeds.build_seed("full_six_endings")
        value,_=seeds.build_seed("seeded_departure_ferry")
        with self.assertRaises(ValueError): seeds.full_runner.contract("full_six_endings",json.dumps(value).encode())

    def test_legacy_marker_forms_and_new_progression_remain_separate(self):
        for case in seeds.CASES:
            if not case.startswith("legacy_"): continue
            value,_=seeds.build_seed(case)
            flags=value["story_state"]["flags"]
            self.assertEqual("campaign_revision" in flags,case.endswith("_v1"))
            self.assertFalse(any(key.startswith("community_") for key in flags))
            self.assertTrue(set(value["quests"]["completed"]).isdisjoint(set(seeds.full_runner.chapter_ids(True))-set(seeds.full_runner.chapter_ids(False))))

    def test_seeded_ferry_has_no_ending_or_personal_consent_credit(self):
        value,_=seeds.build_seed("seeded_departure_ferry")
        flags=value["story_state"]["flags"]
        self.assertEqual(flags["community_route"],"ferry")
        self.assertFalse(any(key.startswith(("open_road_","covenant_ritual_","community_departure_","community_keeper_")) for key in flags))
        self.assertNotIn("final_covenant",flags)
        self.assertEqual(value["world_state"]["pending_ending"],"")
        self.assertTrue(value["story_state"]["evidence"])

    def test_ordinary_stock_no_stat_boost_and_known_source_coordinates(self):
        manifest=seeds.read_json("world_sector_manifest.json")
        stock=seeds.gd_literal("scripts/inventory_manager.gd","STARTING_ITEMS")
        for case in seeds.CASES:
            value,_=seeds.build_seed(case)
            self.assertEqual(value["inventory"]["items"],stock)
            self.assertEqual(value["player_health"]["max_health"],100.0)
            self.assertEqual(value["player_stamina"]["max_stamina"],100.0)
            self.assertEqual(value["inventory"]["weapon_upgrades"],[])
            self.assertEqual(value["progression"],{})
            cell=manifest["sectors"][value["zone"]]["coordinate"]
            self.assertEqual(value["world_position"],[cell[0]*48.0,1.0,cell[1]*40.0+12.0])

    def test_present_and_absent_cast_cases_do_not_infer_consent(self):
        present,_=seeds.build_seed("hearth_distributed")
        absent,_=seeds.build_seed("hearth_protected")
        self.assertEqual(present["story_state"]["flags"]["senn_fate"],"testimony")
        self.assertEqual(absent["story_state"]["flags"]["senn_fate"],"exile")
        self.assertEqual(absent["story_state"]["flags"]["edric_stance"],"exposed")
        self.assertFalse(absent["story_state"]["flags"]["escort_abandonment_acknowledged"])
        for value in [present,absent]:
            self.assertNotIn("community_keeper_consent",value["story_state"]["flags"])
            self.assertNotIn("community_departure_consent",value["story_state"]["flags"])

    def test_existing_exact_seed_inventory_is_reused_without_rewriting(self):
        with tempfile.TemporaryDirectory() as folder,patch.object(seeds,"GATE",Path(folder)):
            path,reused=seeds.prepare()
            self.assertFalse(reused)
            original=path.read_bytes()
            again,reused=seeds.prepare()
            self.assertEqual(again,path)
            self.assertTrue(reused)
            self.assertEqual(path.read_bytes(),original)
            item=json.loads(original)["seeds"][0]
            changed=path.parent/item["file"]
            changed.write_bytes(b"changed fixture")
            with self.assertRaisesRegex(ValueError,"existing prepared seed changed"):
                seeds.prepare()
            self.assertEqual(changed.read_bytes(),b"changed fixture")

    def test_output_escape_is_rejected_before_creating_anything(self):
        with tempfile.TemporaryDirectory() as folder,patch.object(seeds,"GATE",Path(folder)/"gate"):
            destination=Path(folder)/"outside"
            with self.assertRaisesRegex(ValueError,"must stay inside"):
                seeds.prepare(destination)
            self.assertFalse(destination.exists())


if __name__=="__main__": unittest.main()
