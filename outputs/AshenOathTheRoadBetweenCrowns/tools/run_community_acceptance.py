#!/usr/bin/env python3
"""Freeze and run one real-input community route with an isolated boundary save.

The seed is the only allowed progression setup. The GDScript harness drives
normal input after Continue and never changes quests, flags or player position.
Run all four cases in separate profiles; the union covers all 15 physical tasks.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

from run_living_cast_capture import isolated_configuration, sha256, stop_owned_process

PROJECT = Path(__file__).resolve().parents[1]
REPOSITORY = PROJECT.parents[1]
HARNESS = PROJECT / "tools/verify_community_world_input.gd"
GODOT = Path.home() / ".cache/codex-runtimes/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe"
CASES = {
    "lantern_crossing": ("old_mill", "main_empty_tables", ["kitchen_trestle", "kitchen_screen", "kitchen_places", "crossing_beam", "crossing_rail", "crossing_load"]),
    "lantern_ferry": ("old_mill", "main_empty_tables", ["kitchen_trestle", "kitchen_screen", "kitchen_places", "ferry_landing", "ferry_rope", "ferry_load"]),
    "hearth_distributed": ("undercroft", "main_house_many_names", ["refuge_bunks", "refuge_shelves", "refuge_places", "promise_meal", "promise_alarm", "promise_records"]),
    "hearth_protected": ("undercroft", "main_house_many_names", ["refuge_bunks", "refuge_shelves", "refuge_places", "promise_meal", "promise_alarm", "promise_records"]),
}


def git(*arguments: str) -> bytes:
    return subprocess.run(["git", "-C", str(REPOSITORY), *arguments], check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30).stdout


def write(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def validate_seed(seed: bytes, case: str) -> dict:
    data = json.loads(seed.decode("utf-8-sig"))
    if not isinstance(data, dict):
        raise ValueError("seed must be a raw save object, not an export wrapper")
    source, chapter, tasks = CASES[case]
    story = data.get("story_state")
    quests = data.get("quests")
    if not isinstance(story, dict) or not isinstance(quests, dict):
        raise ValueError("seed must contain story_state and quests objects")
    flags = story.get("flags")
    if not isinstance(flags, dict):
        raise ValueError("seed story flags must be an object")
    if type(flags.get("campaign_revision")) not in (int, float) or flags["campaign_revision"] != 2:
        raise ValueError("seed must explicitly carry campaign_revision=2")
    if data.get("zone") != source or data.get("world_sector", source) != source:
        raise ValueError(f"seed must start in {source}, before physical arrival")
    if data.get("replay_session") is True:
        raise ValueError("this campaign route requires a campaign seed; replay uses its separate fixtures")
    active = quests.get("active")
    if not isinstance(active, dict) or not isinstance(active.get(chapter), dict):
        raise ValueError(f"seed must have {chapter} active at its first arrival objective")
    objectives = active[chapter].get("objectives")
    arrival = "reach_lantern_reach" if case.startswith("lantern") else "reach_hearthward"
    if (not isinstance(objectives, list) or not objectives or not isinstance(objectives[0], dict)
            or objectives[0].get("id") != arrival or any(not isinstance(row, dict) or row.get("done") is not False for row in objectives)):
        raise ValueError("seed must leave every starting chapter objective explicitly unfinished")
    if any(flags.get("community_work:" + task) is True for task in tasks):
        raise ValueError("a task under test is already awarded in the seed")
    if any(flags.get(key) for key in (["community_distribution", "community_route"] if case.startswith("lantern") else ["community_records", "community_rota_posted"])):
        raise ValueError("a tested choice is already present in the seed")
    conditional_cast = (flags.get("senn_fate") == "testimony", flags.get("edric_stance") == "cooperate",
                        flags.get("escort_abandonment_acknowledged") is True and "side_escort_04" not in active)
    if case == "hearth_distributed" and not all(conditional_cast):
        raise ValueError("hearth_distributed covers all twelve actors: Senn testimony, cooperative Edric, introduced Nera with no active escort")
    if case == "hearth_protected" and any(conditional_cast):
        raise ValueError("hearth_protected covers absent Senn, Edric and Nera; their choices must keep all three unavailable")
    return {"zone": source, "chapter": chapter, "expected_work": tasks}


def prepare(args: argparse.Namespace) -> tuple[dict, Path]:
    root_pack = args.root_pack.resolve(strict=True)
    pack_dir = args.packs.resolve(strict=True)
    packs = sorted(pack_dir.glob("*.pck"))
    engine = args.godot.resolve(strict=True)
    cache = args.class_cache.resolve(strict=True)
    seed_path = args.seed_save.resolve(strict=True)
    seed = seed_path.read_bytes()
    seed_contract = validate_seed(seed, args.case)
    if root_pack.suffix.lower() != ".pck" or not root_pack.is_file() or not packs or root_pack in packs:
        raise ValueError("a separate root PCK and nonempty secondary pack directory are required")
    if not engine.is_file() or not cache.is_file():
        raise ValueError("pinned Godot and generated global class cache are required")
    commit = git("rev-parse", "HEAD").decode().strip()
    project_path = (PROJECT / "project.godot").relative_to(REPOSITORY).as_posix()
    config = git("show", f"{commit}:{project_path}")
    run_id = "community_" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "_" + uuid.uuid4().hex[:10]
    output = args.output.resolve() if args.output else REPOSITORY / ".release-gate/community-world" / run_id
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise ValueError("output must be new or empty")
    output.mkdir(parents=True, exist_ok=True)
    isolated = output / "project"
    (isolated / ".godot").mkdir(parents=True, exist_ok=False)
    (isolated / "tools").mkdir()
    profile = "AshenOathCapture/" + run_id
    (isolated / "project.godot").write_bytes(isolated_configuration(config, profile))
    (isolated / ".godot/global_script_class_cache.cfg").write_bytes(cache.read_bytes())
    script = isolated / "tools/verify_community_world_input.gd"
    script.write_bytes(HARNESS.read_bytes())
    # Redirect application data before engine startup, including renderer caches.
    app_data = output / "profile/roaming"
    local_data = output / "profile/local"
    user_data = app_data / profile
    user_data.mkdir(parents=True)
    local_data.mkdir(parents=True)
    (user_data / "ashen_oath_save.json").write_bytes(seed)
    seed_copy = output / "seed.json"
    seed_copy.write_bytes(seed)
    command = [str(engine), "--path", str(isolated), "--rendering-method", "gl_compatibility",
               "--rendering-driver", "opengl3", "--script", str(script), "--log-file", str(output / "godot.log"),
               "--", "--root-pack=" + root_pack.as_posix(), "--packs=" + pack_dir.as_posix(),
               "--case=" + args.case, "--viewport=" + args.viewport, "--output=" + output.as_posix()]
    immutable = [isolated / "project.godot", isolated / ".godot/global_script_class_cache.cfg", script, seed_copy, engine, root_pack, *packs]
    receipt = {
        "schema_version": 1, "kind": "community_world_input_runner", "status": "prepared",
        "case": args.case, "git_commit": commit, "source_status": git("status", "--short").decode(),
        "seed_contract": seed_contract, "output": str(output), "isolated_project": str(isolated),
        "expected_user_data_dir": str(user_data), "environment": {"APPDATA": str(app_data), "LOCALAPPDATA": str(local_data)},
        "profile": profile, "command": command, "timeout_seconds": args.timeout,
        "immutable_inputs": [{"path": str(path), "bytes": path.stat().st_size, "sha256": sha256(path)} for path in immutable],
        "source_project_sha256": hashlib.sha256(config).hexdigest(), "physical_phone_coverage": False,
        "touch_input_coverage": False, "viewport": args.viewport, "progression_setup": "one supplied seed before engine startup",
    }
    receipt_path = output / "runner.json"
    write(receipt_path, receipt)
    return receipt, receipt_path


def verify_inputs(receipt: dict) -> None:
    for row in receipt["immutable_inputs"]:
        path = Path(row["path"])
        if not path.is_file() or path.stat().st_size != row["bytes"] or sha256(path) != row["sha256"]:
            raise ValueError(f"frozen input changed: {path}")


def run(receipt: dict, receipt_path: Path) -> int:
    output = Path(receipt["output"])
    process = None
    started = time.monotonic()
    receipt["status"] = "running"
    write(receipt_path, receipt)
    try:
        verify_inputs(receipt)
        environment = os.environ.copy()
        environment.update(receipt["environment"])
        with (output / "stdout.log").open("wb") as log:
            process = subprocess.Popen(receipt["command"], cwd=receipt["isolated_project"], env=environment,
                                       stdout=log, stderr=subprocess.STDOUT,
                                       creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
            receipt["owned_pid"] = process.pid
            write(receipt_path, receipt)
            receipt["exit_code"] = process.wait(timeout=receipt["timeout_seconds"])
        verify_inputs(receipt)
        report = json.loads((output / "report.json").read_text(encoding="utf-8"))
        errors = []
        if receipt["exit_code"] != 0 or report.get("status") != "pass" or report.get("failures"):
            errors.append("engine or acceptance report failed")
        if report.get("case") != receipt["case"] or report.get("completed_work") != receipt["seed_contract"]["expected_work"]:
            errors.append("physical task coverage differs from requested case")
        if report.get("progression_injection") is not False or report.get("input_events", 0) < 50:
            errors.append("real-input evidence is incomplete")
        expected = Path(receipt["expected_user_data_dir"]).resolve()
        if Path(report.get("user_data_dir", "")).resolve() != expected:
            errors.append("engine used a different user data directory")
        if not report.get("observations"):
            errors.append("no rendered observations")
        images = []
        for observation in report.get("observations", []):
            path = Path(observation["image"]).resolve(strict=True)
            if not path.is_relative_to(output) or path.suffix.lower() != ".png" or path.stat().st_size == 0:
                raise ValueError("invalid rendered observation path")
            images.append({"path": str(path), "sha256": sha256(path)})
        for log_name in ["godot.log", "stdout.log"]:
            log = output / log_name
            if log.is_file():
                errors.extend(line for line in log.read_text(encoding="utf-8", errors="replace").splitlines()
                              if "SCRIPT ERROR:" in line or line.startswith("ERROR:"))
        receipt["failures"] = errors
        receipt["images"] = images
        receipt["status"] = "pass" if not errors else "fail"
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        receipt["status"] = "fail"
        receipt["failures"] = [str(error)]
    finally:
        if process is not None:
            stop_owned_process(process)
        receipt["elapsed_seconds"] = round(time.monotonic() - started, 3)
        write(receipt_path, receipt)
    print(json.dumps({"status": receipt["status"], "receipt": str(receipt_path)}))
    return 0 if receipt["status"] == "pass" else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", choices=CASES, required=True)
    parser.add_argument("--seed-save", type=Path, required=True)
    parser.add_argument("--root-pack", type=Path, required=True)
    parser.add_argument("--packs", type=Path, required=True)
    parser.add_argument("--class-cache", type=Path, default=PROJECT / ".godot/global_script_class_cache.cfg")
    parser.add_argument("--godot", type=Path, default=GODOT)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--viewport", choices=["desktop", "touch"], default="desktop")
    parser.add_argument("--timeout", type=int, default=1800)
    parser.add_argument("--prepare-only", action="store_true", help="freeze inputs and profile without launching Godot")
    args = parser.parse_args()
    if not 60 <= args.timeout <= 3600:
        parser.error("--timeout must be between 60 and 3600 seconds")
    try:
        receipt, receipt_path = prepare(args)
        if args.prepare_only:
            print(json.dumps({"status": "prepared", "receipt": str(receipt_path), "engine_started": False}))
            return 0
        return run(receipt, receipt_path)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(2, f"community acceptance preparation failed: {error}\n")


if __name__ == "__main__":
    sys.exit(main())
