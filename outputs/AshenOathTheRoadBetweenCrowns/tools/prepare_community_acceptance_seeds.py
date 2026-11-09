"""Prepare explicitly synthetic boundary saves; never a full-campaign proof.

Reads only committed/worktree source definitions and writes under the isolated
repository's .release-gate/community-runtime. No profile or existing save is read.
The native import/quest-load receipt remains pending until its memory fixture runs.
"""
from __future__ import annotations

import argparse
import copy
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess

import run_community_acceptance as community_runner
import run_full_campaign_acceptance as full_runner

PROJECT = Path(__file__).resolve().parents[1]
GATE = PROJECT / ".release-gate/community-runtime"
CASES = list(community_runner.CASES) + [case for case in full_runner.CASES if case != "full_six_endings"]
SOURCES = ["scripts/save_manager.gd", "scripts/campaign_revision.gd", "scripts/quest_manager.gd",
           "scripts/inventory_manager.gd", "scripts/health_component.gd", "scripts/stamina_component.gd",
           "scripts/equipment_loadout.gd", "data/quests.json", "data/campaign_dialogue.json",
           "data/community_campaign.json", "data/journal_evidence_details.json", "world_sector_manifest.json",
           "tools/prepare_community_acceptance_seeds.py", "tools/run_community_acceptance.py",
           "tools/run_full_campaign_acceptance.py", "tools/verify_community_acceptance_seeds.gd",
           "tools/test_community_acceptance_seeds.py", "tools/community_acceptance_legacy.py",
           "tools/verify_full_campaign_input.gd", "tools/verify_community_world_input.gd"]


def read_json(relative):
    return json.loads((PROJECT / relative).read_text(encoding="utf-8-sig"))


def gd_literal(relative, constant):
    source = (PROJECT / relative).read_text(encoding="utf-8-sig")
    match = re.search(r"const " + re.escape(constant) + r"\s*:?=\s*(\{[\s\S]*?\}|\[[\s\S]*?\]|\d+)", source)
    if not match:
        raise ValueError("missing authoritative constant: " + constant)
    return json.loads(re.sub(r",\s*([}\]])", r"\1", match.group(1)))


def choice_flags(dialogue, scene, flag, value):
    matches = [action for action in dialogue[scene]["actions"] if action.get("sets_flags", {}).get(flag) == value]
    if len(matches) != 1:
        raise ValueError(f"expected one authored boundary outcome: {scene}/{flag}/{value}")
    return copy.deepcopy(matches[0]["sets_flags"])


def build_seed(case):
    if case not in CASES:
        raise ValueError("only labelled boundary cases may receive a synthetic seed")
    legacy = case.startswith("legacy_")
    chapters = full_runner.chapter_ids(not legacy)
    if case.startswith("lantern_") or "_ash_" in case:
        count, zone = 5, "old_mill"
    elif case.startswith("hearth_") or "_witness_" in case:
        count, zone = (8 if legacy else 10), "undercroft"
    else:
        count, zone = 13, "hart_glade"
    completed, active = chapters[:count], chapters[count]
    definitions = read_json("data/quests.json")
    dialogue = read_json("data/campaign_dialogue.json")
    authored = read_json("data/community_campaign.json")
    flags = {} if case.endswith("_missing") else {"campaign_revision": 1 if legacy else 2}
    decisions = [("crow_shrine_choice", "crow_shrine_state", "cleansed"),
                 ("bog_core_choice", "bog_core_fate", "returned"),
                 ("names_decision", "names_policy", "published"),
                 ("miller_record", "mill_operation", "closed")]
    flags.update(evidence_report="public", wychwood_pack_cleared=True, bell_eater_defeated=True,
                 rootbound_colossus_defeated=True, ashwing_defeated=True)
    absent = case == "hearth_protected"
    if "main_last_witness" in completed:
        decisions += [("captain_senn", "senn_fate", "exile" if absent else "testimony"),
                      ("vargan_ledger_choice", "vargan_ledger_left_copied", True),
                      ("edric_campaign", "edric_stance", "exposed" if absent else "cooperate"),
                      ("halvern", "halvern_fate", "witness")]
        flags.update(castle_haunting_cleared=True)
        if not legacy:
            flags["escort_abandonment_acknowledged"] = not absent
    if "main_crowns_without_mercy" in completed:
        decisions.append(("assembly_choice", "confession_method", "witnesses"))
    for scene, key, value in decisions:
        flags.update(choice_flags(dialogue, scene, key, value))
    choices = {"main_empty_tables":"central", "main_road_kept_open":"ferry" if case == "seeded_departure_ferry" else "crossing",
               "main_house_many_names":"protected"}
    for chapter in completed:
        if chapter not in authored["chapters"]:
            continue
        row = authored["chapters"][chapter]
        flags["community_account:" + chapter] = True
        flags["community_aftermath:" + chapter] = True
        flags["campaign_" + chapter.removeprefix("main_") + "_completed"] = True
        if chapter in choices:
            flags[row["choice"]] = choices[chapter]
        work = row.get("work", row.get("choices", {}).get(choices.get(chapter), {}).get("work", []))
        flags.update({"community_work:" + task: True for task in work})
        if chapter == "main_empty_tables": flags["community_kitchen_ready"] = True
        if chapter == "main_road_kept_open":
            flags.update(community_route_ready=True, community_route_load_crossed=True, community_route_load_carried=False)
            flags.update({"community_survey:near":True, "community_survey:far":True})
        if chapter == "main_house_many_names": flags["community_refuge_ready"] = True
        if chapter == "main_what_we_promise": flags["community_rota_posted"] = True
    # All supplied history is declared synthetic. Keep explicit optional facts
    # rather than allowing a completed chapter to imply an unrecorded action.
    facts = {}
    for chapter in completed:
        facts[chapter] = {row["id"]: not row.get("optional", False) for row in definitions[chapter]["objectives"]}
        groups = {}
        for row in definitions[chapter]["objectives"]:
            if row.get("optional") and row.get("group"):
                seen = groups.get(row["group"], 0)
                facts[chapter][row["id"]] = seen < row.get("required_count", 1)
                groups[row["group"]] = seen + 1
    objectives = [dict(copy.deepcopy(row), done=False) for row in definitions[active]["objectives"]]
    inventory = {"items":gd_literal("scripts/inventory_manager.gd", "STARTING_ITEMS"),
                 "ingredients":gd_literal("scripts/inventory_manager.gd", "STARTING_INGREDIENTS"),
                 "coin":gd_literal("scripts/inventory_manager.gd", "STARTING_COIN"),
                 "active_oil":"", "oil_version":1, "oil_remaining_seconds":0.0,
                 "weapon_upgrades":[], "reward_deliveries":{}}
    # At least one explicit human record makes the ferry ending's preservation
    # assertion non-vacuous; the text comes from the current evidence catalog.
    evidence_id = "command_proof" if "main_last_witness" in completed else "mill_accounts"
    evidence = next(row for row in read_json("data/journal_evidence_details.json")["details"] if row["id"] == evidence_id)
    observation = next(row for row in evidence["sections"] if row["kind"] == "observation")
    local = [0.0, 1.0, 12.0]  # existing SaveManager default for all three sources
    manifest = read_json("world_sector_manifest.json")
    cell = manifest["sectors"][zone]["coordinate"]
    world = [local[0] + cell[0]*manifest["cell_size"][0], local[1], local[2] + cell[1]*manifest["cell_size"][1]]
    seed = {"version":gd_literal("scripts/save_manager.gd", "CURRENT_VERSION"), "game_id":"ashen-oath",
            "journey_id":"synthetic-acceptance-" + case, "slot_name":"SYNTHETIC BOUNDARY: " + case,
            "replay_session":False, "zone":zone, "world_sector":zone, "player_position":local, "world_position":world,
            "player_health":{"health":100.0,"max_health":100.0,"dead":False},
            "player_stamina":{"stamina":100.0,"max_stamina":100.0},
            "equipment":{"schema_version":3,"active_weapon":"sword","selected_blade_id":"steel","sword_drawn":False,
                         "bow_drawn":False,"bow_aiming":False,"selected_arrow_id":"standard_arrow"},
            "inventory":inventory, "progression":{},
            "quests":{"active":{active:{"objectives":objectives}}, "completed":dict.fromkeys(completed,True),
                      "completed_objectives":facts,"evidence_history":{},"unlocked":dict.fromkeys(completed+[active],True),
                      "world_flags":{},"tracked_quest_id":active,"tracked_quest_is_manual":False,"tracker_context_zone":zone},
            "story_state":{"version":2,"flags":flags,"values":{"anwen_trust":0,"greyfen_fear":0,"hart_debt":0},
                           "evidence":{evidence_id:{"title":observation["title"],"text":observation["body"],
                                                  "kind":"record","zone":"undercroft" if evidence_id=="command_proof" else "old_mill"}}},
            "world_state":{"pending_ending":"","removed_interactions":{},"wychwood_pack_kills":5,"ghoulkin_kills":5,
                           "wychwood_encounter":{"started":True,"wave":5},"boss_states":{},
                           "day_night":{"world_time_minutes":600.0,"day_count":0}},
            "settings":{"difficulty":"standard","quality_preset":"balanced","pause_on_focus_loss":False},
            "acceptance_fixture":{"synthetic":True,"case":case,"proof":"boundary_only","full_campaign_proof":False}}
    return seed, {"initial_completed":completed,"active_chapter":active,"starting_flags":flags,
                  "authored_choice_sources":[{"scene":scene,"flag":key,"value":value} for scene,key,value in decisions],
                  "inventory_policy":"authoritative starting stock; no added supplies or weapon upgrades",
                  "progression_policy":"empty progression; ordinary restore_journey reconciles the declared synthetic history",
                  "position_policy":"SaveManager default local position; world coordinate derived from current sector manifest",
                  "native_import_validated":False,"physical_arrival_validated":False}


def seed_contract(case, content):
    return community_runner.validate_seed(content, case) if case in community_runner.CASES else full_runner.contract(case, content)


def prepare(output=None):
    sources = [{"path":name,"sha256":hashlib.sha256((PROJECT/name).read_bytes()).hexdigest()} for name in SOURCES]
    source_hash = hashlib.sha256(json.dumps(sources,sort_keys=True).encode()).hexdigest()
    output = (Path(output) if output else GATE / ("boundary-seeds-"+source_hash[:12])).resolve()
    if not output.is_relative_to(GATE.resolve()):
        raise ValueError("synthetic seeds must stay inside this isolated community-runtime gate")
    receipt_path = output / "manifest.json"
    if receipt_path.exists():
        old = json.loads(receipt_path.read_text(encoding="utf-8"))
        if old.get("source_sha256") != source_hash or old.get("sources")!=sources:
            raise ValueError("existing seed folder belongs to different source; choose a new output")
        if old.get("kind")!="synthetic_boundary_seed_inventory" or [row.get("case") for row in old.get("seeds",[])]!=CASES:
            raise ValueError("existing seed inventory does not contain exactly the nine boundary cases")
        for row in old["seeds"]:
            path = output / row["file"]
            if not path.resolve().is_relative_to(output) or hashlib.sha256(path.read_bytes()).hexdigest() != row["sha256"]:
                raise ValueError("existing prepared seed changed; preserve it and prepare a new folder")
            seed_contract(row["case"],path.read_bytes())
        return receipt_path, True
    if output.exists() and any(output.iterdir()):
        raise ValueError("new seed folder must be empty")
    output.mkdir(parents=True,exist_ok=True)
    rows = []
    for case in CASES:
        seed, provenance = build_seed(case)
        content = (json.dumps(seed,ensure_ascii=False,indent=2)+"\n").encode("utf-8")
        contract = seed_contract(case,content)
        path = output / (case+".json")
        path.write_bytes(content)
        rows.append({"case":case,"file":path.name,"bytes":len(content),"sha256":hashlib.sha256(content).hexdigest(),
                     "contract":contract,"python_contract_validated":True,**provenance})
    commit = subprocess.run(["git","-C",str(PROJECT),"rev-parse","HEAD"],check=True,capture_output=True,text=True,timeout=15).stdout.strip()
    receipt = {"schema_version":1,"kind":"synthetic_boundary_seed_inventory","created_at":datetime.now(timezone.utc).isoformat(),
               "source_commit":commit,"source_sha256":source_hash,"sources":sources,"seeds":rows,
               "full_six_endings":{"seed":"FORBIDDEN","required_start":"empty disposable profile + actual New Game"},
               "user_profile_access":False,"engine_started":False,"native_import_status":"pending_memory_fixture",
               "gameplay_status":"not_run","supply_or_position_changes_after_startup":False}
    receipt_path.write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return receipt_path, False


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path)
    args = parser.parse_args()
    path,reused=prepare(args.output)
    print(json.dumps({"manifest":str(path),"seeds":len(CASES),"reused":reused,"engine_started":False,"native_import_validated":False}))
