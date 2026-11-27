"""Prepare one isolated chapter boundary for the rendered novel milestone driver."""
import argparse
import json
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT / "tools"))
from prepare_community_acceptance_seeds import build_seed
from run_full_campaign_acceptance import chapter_ids

CASES = {
    "tor_wrist": ("lantern_crossing", "old_mill", "main_ash_at_the_mill", "mill_encounter", [2.7, 1, 7.3]),
    "seals": ("hearth_distributed", "record_hall", "main_blood_under_stone", "recover_ledger", [-3.4, 1, 6.6]),
    "dry_floor": ("hearth_distributed", "hearthward", "main_house_many_names", "reach_hearthward", [3.5, 1, 4.6]),
    "spring_open_road": ("seeded_departure_ferry", "hearthward", "main_hart_remembers", "enter_glade", [-2.8, 1, 8.8]),
}


def prepare(case, output):
    source, sector, chapter, objective, position = CASES[case]
    payload, _ = build_seed(source)
    atlas = json.loads((PROJECT / "world_sector_manifest.json").read_text("utf8"))
    definitions = json.loads((PROJECT / "data/quests.json").read_text("utf8"))
    x, z = atlas["sectors"][sector]["coordinate"]
    payload.update(zone=sector, world_sector=sector, player_position=position,
                   world_position=[position[0] + 48*x, position[1], position[2] + 40*z],
                   journey_id="synthetic-novel-" + case)
    order = chapter_ids(True)
    index = order.index(chapter)
    quests = payload["quests"]
    quests.update(active={chapter: {"objectives": [dict(row, done=row["id"] == objective)
                  for row in definitions[chapter]["objectives"]]}}, completed=dict.fromkeys(order[:index], True),
                  unlocked=dict.fromkeys(order[:index+1], True), tracked_quest_id=chapter, tracker_context_zone=sector)
    quests["completed_objectives"] = {key: value for key, value in quests["completed_objectives"].items()
                                      if key in quests["completed"]}
    flags = payload["story_state"]["flags"]
    flags.update(novel_edition=1, novel_prologue_closed=True)
    if case == "spring_open_road":
        # The released codec requires the whole evacuation chain on a finished departure.
        flags.update(final_covenant="open_road", final_choice_completed=True, covenant_ritual_step=3,
                     open_road_households=["water_carrier","quality_sweeper"], open_road_named_roster=[],
                     open_road_protection_dismantled=True, territorial_protection_active=False,
                     hart_complete_account_access=False, human_records_preserved=True,
                     open_road_relocation_started=True, open_road_player_crossed=True,
                     open_road_route_crossed=True, open_road_crossing_progress=1.0,
                     open_road_route_delivered=True, open_road_relocation_completed=True,
                     novel_departure_legs=3, novel_departure_handover=True)
        quests["active"] = {}
        quests["completed"][chapter] = True
        quests["tracked_quest_id"] = ""
        quests["completed_objectives"][chapter] = {row["id"]: True for row in definitions[chapter]["objectives"] if not row.get("optional")}
    payload["acceptance_fixture"] = {"synthetic": True, "case": case, "proof": "boundary only"}
    output.mkdir(parents=True, exist_ok=False)
    save_dir = output / "user/Godot/app_userdata/Ashen Oath- The Road Between Crowns"
    save_dir.mkdir(parents=True)
    (save_dir / "ashen_oath_save.json").write_text(json.dumps(payload), encoding="utf8")
    (output / "scene.txt").write_text(case, encoding="utf8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("case", choices=CASES)
    parser.add_argument("new_evidence_directory", type=Path)
    args = parser.parse_args()
    prepare(args.case, args.new_evidence_directory)
