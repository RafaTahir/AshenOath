#!/usr/bin/env python3
"""Run a continuous New Game / fourteen-chapter / six-ending input acceptance.

Legacy saves at either insertion point are separate cases, never substitutes for
the complete journey. This tool launches no engine with --prepare-only.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

import run_community_acceptance as common
from community_acceptance_legacy import build_adapter

PROJECT = common.PROJECT
HARNESS = PROJECT / "tools/verify_full_campaign_input.gd"
LEGACY_SOURCE = PROJECT / "tools/verify_opening_real_input_native.gd"
CASES = ["full_six_endings", "legacy_ash_missing", "legacy_ash_v1", "legacy_witness_missing", "legacy_witness_v1", "seeded_departure_ferry"]
ENDINGS = ["expose", "free", "bind", "kill", "share", "depart"]
FULL_WORK = ["kitchen_trestle", "kitchen_screen", "kitchen_places", "crossing_beam", "crossing_rail", "crossing_load",
             "refuge_bunks", "refuge_shelves", "refuge_places", "promise_meal", "promise_alarm", "promise_records"]


def chapter_ids(expanded: bool) -> list[str]:
    source = (PROJECT / "scripts/campaign_revision.gd").read_text(encoding="utf-8")
    name = "EXPANDED_CHAPTERS" if expanded else "LEGACY_CHAPTERS"
    match = re.search(r"const " + name + r" := (\[[\s\S]*?\])", source)
    if not match:
        raise ValueError("authoritative chapter array changed; review the acceptance contract")
    result = json.loads(match.group(1))
    if not isinstance(result, list) or len(result) != (14 if expanded else 10) or len(set(result)) != len(result):
        raise ValueError("authoritative campaign must have fourteen expanded or ten original chapters")
    return result


def contract(case: str, seed: bytes | None) -> dict:
    if case not in CASES:
        raise ValueError("unsupported complete campaign case")
    if case == "seeded_departure_ferry":
        return ferry_contract(seed)
    expanded = case == "full_six_endings"
    chapters = chapter_ids(expanded)
    before = []
    if expanded:
        if seed is not None:
            raise ValueError("full campaign proof must start with an empty profile and actual New Game")
    else:
        if seed is None:
            raise ValueError("legacy insertion case requires its explicit raw save")
        data = json.loads(seed.decode("utf-8-sig"))
        if not isinstance(data, dict) or not isinstance(data.get("story_state"), dict) or not isinstance(data.get("quests"), dict):
            raise ValueError("legacy seed must be a raw save with story and quest state")
        flags = data["story_state"].get("flags")
        quests = data["quests"]
        if not isinstance(flags, dict) or not isinstance(quests.get("completed"), dict) or not isinstance(quests.get("active"), dict):
            raise ValueError("legacy seed contains malformed state maps")
        if case.endswith("missing"):
            if "campaign_revision" in flags:
                raise ValueError("missing-marker case requires the marker to be absent")
        elif type(flags.get("campaign_revision")) not in (int, float) or flags["campaign_revision"] != 1:
            raise ValueError("explicit legacy case requires revision one")
        zone, count = ("old_mill", 5) if "_ash_" in case else ("undercroft", 8)
        if data.get("zone") != zone or data.get("world_sector", zone) != zone:
            raise ValueError("legacy seed must be at its named insertion point")
        if data.get("replay_session") is True:
            raise ValueError("legacy campaign acceptance requires a campaign seed")
        before = [id for id in chapters if quests["completed"].get(id) is True or quests["completed"].get(id) == 1]
        if before != chapters[:count] or chapters[count] not in quests["active"]:
            raise ValueError("legacy seed must have exactly the original preceding chain and its original next chapter")
        new_ids = set(chapter_ids(True)) - set(chapters)
        if any(id in quests["active"] or quests["completed"].get(id) for id in new_ids):
            raise ValueError("legacy insertion seed must not contain expansion progression")
    return {"suite": "full_campaign" if expanded else "legacy_insertion", "expected_chapters": chapters,
            "initial_completed": before, "expected_endings": ENDINGS if expanded else ["expose"],
            "expected_options": ENDINGS if expanded else ENDINGS[:4], "expected_work": FULL_WORK if expanded else []}


def ferry_contract(seed: bytes | None) -> dict:
    """A named ending-boundary setup, never evidence of an earned full chain."""
    if seed is None:
        raise ValueError("seeded ferry ending requires an explicit raw ending-boundary save")
    value = json.loads(seed.decode("utf-8-sig"))
    if not isinstance(value, dict) or not isinstance(value.get("story_state"), dict) or not isinstance(value.get("quests"), dict):
        raise ValueError("ferry seed must contain story and quest maps")
    flags = value.get("story_state", {}).get("flags", {})
    quests = value.get("quests", {})
    world = value.get("world_state", {})
    if not all(isinstance(row, dict) for row in (flags, quests, world, quests.get("completed"), quests.get("active"))):
        raise ValueError("ferry seed has malformed story or quest records")
    if type(flags.get("campaign_revision")) not in (int, float) or flags["campaign_revision"] != 2:
        raise ValueError("ferry ending seed requires an explicit expanded journey")
    if value.get("zone") != "hart_glade" or value.get("world_sector", "hart_glade") != "hart_glade":
        raise ValueError("ferry ending boundary must be the Hart glade")
    chapters = chapter_ids(True)
    before = [id for id in chapters if quests["completed"].get(id) is True]
    if before != chapters[:-1] or "main_hart_remembers" not in quests["active"]:
        raise ValueError("ferry seed must label exactly thirteen preceding chapters as setup")
    if value.get("replay_session") is True or world.get("pending_ending", "") or flags.get("final_covenant", "") or flags.get("final_choice_completed", False):
        raise ValueError("ferry seed cannot be a replay or prechosen/completed ending")
    if flags.get("community_route") != "ferry" or flags.get("community_route_ready") is not True or flags.get("community_refuge_ready") is not True:
        raise ValueError("ferry seed requires the prepared ferry and refuge")
    if flags.get("confession_method") not in ("edric", "witnesses", "kael"):
        raise ValueError("ferry boundary must retain the assembly's actual recorded testimony method")
    community = json.loads((PROJECT / "data/community_campaign.json").read_text(encoding="utf-8-sig"))
    tasks = community["chapters"]["main_road_kept_open"]["choices"]["ferry"]["work"] + community["chapters"]["main_house_many_names"]["work"]
    if any(flags.get("community_work:"+task) is not True for task in tasks):
        raise ValueError("ferry and refuge preparation must match the authored physical task setup")
    if any(key.startswith("open_road_") for key in flags) or flags.get("covenant_ritual_started", False) or flags.get("covenant_ritual_step", 0):
        raise ValueError("ferry seed cannot pre-earn any departure enactment or passage")
    return {"suite": "seeded_departure", "expected_chapters": chapters, "initial_completed": before,
            "expected_endings": ["depart"], "expected_options": ENDINGS, "expected_work": [], "required_departure_route": "ferry"}


def validate_report(report: dict, expected: dict) -> list[str]:
    failures = []
    full = expected["suite"] == "full_campaign"
    if report.get("suite") != expected["suite"] or report.get("started_with_new_game") is not full or report.get("seeded_boundary") is not (not full):
        failures.append("campaign report mislabels New Game or boundary setup")
    if report.get("initial_completed") != expected["initial_completed"] or report.get("observed_chapters") != expected["expected_chapters"]:
        failures.append("campaign does not cover the exact continuous chapter history")
    events = report.get("chapter_events", [])
    required = expected["expected_chapters"][len(expected["initial_completed"]):]
    ids = [row.get("id") for row in events if isinstance(row, dict)]
    if ids[:len(required)] != required or ids[len(required):] != ["main_hart_remembers"] * (len(expected["expected_endings"]) - 1):
        failures.append("chapter completion events skip, reorder or manufacture required chapters")
    endings = report.get("endings", [])
    if not isinstance(endings, list) or not all(isinstance(row, dict) for row in endings) or [row.get("ending") for row in endings] != expected["expected_endings"]:
        failures.append("ending coverage differs from the exact requested alternatives")
    else:
        for row in endings:
            if row.get("visible_options") != expected["expected_options"]:
                failures.append("visible ending menu exposed the wrong revision's choices")
            if row.get("ritual_steps") != (0 if row["ending"] == "kill" else 3):
                failures.append("peaceful ending was not enacted through all three physical steps")
            consequences = row.get("consequences", {})
            if not isinstance(consequences, dict):
                failures.append("ending consequences receipt is malformed")
                continue
            if row["ending"] == "depart" and not all(consequences.get(key) is True for key in ["route_crossed", "arrival", "losses_persisted", "human_evidence_preserved", "named_consent_only", "native_households"]):
                failures.append("Open Road omitted actual relocation, consent, evidence preservation or its irreversible costs")
            if row["ending"] == "depart" and expected.get("required_departure_route") and consequences.get("route") != expected["required_departure_route"]:
                failures.append("seeded ferry ending did not exercise its explicitly prepared ferry")
            if row["ending"] == "share" and consequences.get("concord_revocation_verified") is not True:
                failures.append("Concord did not verify a revocable continuing obligation with a real vacancy")
            if not all(row.get(key) is True for key in ["memorial_reload", "return_home", "epilogue_presented"]) or not row.get("cards"):
                failures.append("ending omitted its restored memorial, return home or actual epilogue")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", choices=CASES, default="full_six_endings")
    parser.add_argument("--seed-save", type=Path)
    parser.add_argument("--root-pack", type=Path, required=True)
    parser.add_argument("--packs", type=Path, required=True)
    parser.add_argument("--release-manifest", type=Path, required=True, help="maintained final Web release receipt; native packs must match decoded hashes")
    parser.add_argument("--class-cache", type=Path, default=PROJECT / ".godot/global_script_class_cache.cfg")
    parser.add_argument("--godot", type=Path, default=common.GODOT)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--viewport", choices=["desktop", "touch"], default="desktop")
    parser.add_argument("--input-mode", choices=["keyboard_mouse", "touch"], help="defaults to touch at 960x540; keyboard runs at that size do not claim touch coverage")
    parser.add_argument("--timeout", type=int, default=10800)
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    if not 60 <= args.timeout <= 43200:
        parser.error("--timeout must be between 60 and 43200 seconds")
    try:
        seed = args.seed_save.resolve(strict=True).read_bytes() if args.seed_save else None
        expected = contract(args.case, seed)
        original = LEGACY_SOURCE.read_bytes()
        args.input_mode = args.input_mode or ("touch" if args.viewport == "touch" else "keyboard_mouse")
        adapter, helpers = build_adapter(original.decode("utf-8-sig"), args.input_mode)
        extras = {"tools/verify_community_world_input.gd": common.HARNESS.read_bytes(),
                  "tools/generated_legacy_input.gd": adapter.encode("utf-8"),
                  "tools/source_legacy_input.gd.txt": original}
        receipt, receipt_path = common.prepare(args, script_source=HARNESS, seed_contract=expected,
                                               extra_files=extras, allow_no_seed=args.case == "full_six_endings",
                                               runner_sources=[Path(__file__).resolve(), PROJECT / "tools/community_acceptance_legacy.py"])
        receipt["legacy_input_helpers"] = helpers
        common.write(receipt_path, receipt)
        if args.prepare_only:
            print(json.dumps({"status": "prepared", "receipt": str(receipt_path), "engine_started": False}))
            return 0
        return common.run(receipt, receipt_path, validate_report)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(2, f"full campaign acceptance preparation failed: {error}\n")


if __name__ == "__main__":
    sys.exit(main())
