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


def profile_snapshot(path: Path) -> list[dict]:
    root = path.resolve(strict=True)
    rows = []
    for item in sorted(root.rglob("*")):
        if not item.resolve().is_relative_to(root):
            raise ValueError("isolated profile contains an escaping link")
        if item.is_file():
            rows.append({"path":item.relative_to(root).as_posix(), "bytes":item.stat().st_size, "sha256":sha256(item)})
    return rows


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


def validate_touch_source(script_source: Path, extra_files: dict[str, bytes] | None) -> None:
    if script_source == HARNESS:
        return
    if script_source != PROJECT / "tools/verify_full_campaign_input.gd":
        raise ValueError("entry script has no reviewed genuine-touch input contract")
    from community_acceptance_legacy import build_adapter, validate_touch_adapter
    supplied = extra_files or {}
    try:
        adapter = supplied["tools/generated_legacy_input.gd"].decode("utf-8-sig")
        source = supplied["tools/source_legacy_input.gd.txt"].decode("utf-8-sig")
    except (KeyError, UnicodeDecodeError) as error:
        raise ValueError("full touch route requires its exact maintained source and generated closure") from error
    validate_touch_adapter(adapter)
    expected, _ = build_adapter(source, "touch")
    if adapter != expected:
        raise ValueError("full touch closure differs from the reviewed source transformation")


def prepare(args: argparse.Namespace, *, script_source: Path = HARNESS,
            seed_contract: dict | None = None, extra_files: dict[str, bytes] | None = None,
            allow_no_seed: bool = False, runner_sources: list[Path] | None = None) -> tuple[dict, Path]:
    input_mode = getattr(args, "input_mode", None) or ("touch" if args.viewport == "touch" else "keyboard_mouse")
    if input_mode not in ("keyboard_mouse", "touch"):
        raise ValueError("unsupported acceptance input mode")
    if input_mode == "touch":
        if args.viewport != "touch":
            raise ValueError("genuine touch acceptance requires the touch viewport")
        validate_touch_source(script_source, extra_files)
    root_pack = args.root_pack.resolve(strict=True)
    pack_dir = args.packs.resolve(strict=True)
    from community_acceptance_packs import verify_candidate
    closure = verify_candidate(root_pack, pack_dir, args.release_manifest)
    packs = [Path(row["path"]) for row in closure["packs"]]
    engine = args.godot.resolve(strict=True)
    cache = args.class_cache.resolve(strict=True)
    seed = args.seed_save.resolve(strict=True).read_bytes() if args.seed_save else None
    if seed is None and not allow_no_seed:
        raise ValueError("this case requires an explicit boundary seed")
    if seed_contract is None:
        seed_contract = validate_seed(seed, args.case)
    if root_pack.suffix.lower() != ".pck" or not root_pack.is_file() or not packs or root_pack in packs:
        raise ValueError("a separate root PCK and nonempty secondary pack directory are required")
    if not engine.is_file() or not cache.is_file():
        raise ValueError("pinned Godot and generated global class cache are required")
    if sha256(cache) != closure["class_cache_sha256"]:
        raise ValueError("isolated global class cache must match the exact final root metadata")
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
    script = isolated / "tools" / script_source.name
    script.write_bytes(script_source.read_bytes())
    pack_list = isolated / "verified_native_packs.json"
    write(pack_list, closure)
    extras = []
    fixture_files = dict(extra_files or {})
    if input_mode == "touch":
        fixture_files["tools/community_touch_input.gd"] = (PROJECT / "tools/community_touch_input.gd").read_bytes()
    for relative, content in fixture_files.items():
        destination = (isolated / relative).resolve()
        if not destination.is_relative_to(isolated.resolve()) or destination == script.resolve():
            raise ValueError("extra fixture input must stay within its isolated project and cannot replace the entry script")
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(content)
        extras.append(destination)
    # Redirect application data before engine startup, including renderer caches.
    app_data = output / "profile/roaming"
    local_data = output / "profile/local"
    user_data = app_data / profile
    user_data.mkdir(parents=True)
    local_data.mkdir(parents=True)
    seed_inputs = []
    if seed is not None:
        (user_data / "ashen_oath_save.json").write_bytes(seed)
        seed_copy = output / "seed.json"
        seed_copy.write_bytes(seed)
        seed_inputs.append(seed_copy)
    command = [str(engine), "--path", str(isolated), "--windowed", "--rendering-method", "gl_compatibility",
               "--rendering-driver", "opengl3", "--script", str(script), "--log-file", str(output / "godot.log"),
               "--", "--root-pack=" + root_pack.as_posix(), "--pack-list=" + pack_list.as_posix(),
               "--case=" + args.case, "--viewport=" + args.viewport, "--output=" + output.as_posix(),
               "--background-rendered=true", "--input-mode=" + input_mode]
    immutable = [isolated / "project.godot", isolated / ".godot/global_script_class_cache.cfg", script, pack_list, *seed_inputs, *extras,
                 Path(__file__).resolve(), PROJECT / "tools/run_living_cast_capture.py", PROJECT / "tools/background_native_capture.py",
                 PROJECT / "tools/resume_community_acceptance.py",
                 PROJECT / "tools/community_acceptance_packs.py", PROJECT / "tools/runtime_pack_artifacts.py",
                 PROJECT / "tools/runtime_pack_validation.py", PROJECT / "tools/compact_runtime_packs.py",
                 Path(closure["release_manifest"]), *(runner_sources or []), engine, root_pack, *packs]
    receipt = {
        "schema_version": 1, "kind": "community_world_input_runner", "status": "prepared",
        "case": args.case, "git_commit": commit, "source_status": git("status", "--short").decode(),
        "seed_contract": seed_contract, "output": str(output), "isolated_project": str(isolated),
        "candidate_closure": closure,
        "expected_user_data_dir": str(user_data), "environment": {"APPDATA": str(app_data), "LOCALAPPDATA": str(local_data)},
        "profile": profile, "command": command, "timeout_seconds": args.timeout,
        "immutable_inputs": [{"path": str(path), "bytes": path.stat().st_size, "sha256": sha256(path)} for path in immutable],
        "source_project_sha256": hashlib.sha256(config).hexdigest(), "physical_phone_coverage": False,
        "touch_input_coverage": False, "viewport": args.viewport, "input_mode": input_mode,
        "execution_mode": "background-rendered",
        "progression_setup": "one supplied seed before engine startup" if seed is not None else "empty profile; actual New Game",
        "initial_profile_files": profile_snapshot(user_data),
    }
    receipt_path = output / "runner.json"
    write(receipt_path, receipt)
    return receipt, receipt_path


def verify_inputs(receipt: dict) -> None:
    for row in receipt["immutable_inputs"]:
        path = Path(row["path"])
        if not path.is_file() or path.stat().st_size != row["bytes"] or sha256(path) != row["sha256"]:
            raise ValueError(f"frozen input changed: {path}")


def load_prepared(receipt_path: Path) -> dict:
    """Resume only a never-started receipt and its unchanged isolated profile."""
    receipt_path = receipt_path.resolve(strict=True)
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if receipt.get("kind") != "community_world_input_runner" or receipt.get("status") != "prepared" or "owned_pid" in receipt:
        raise ValueError("only a never-started prepared acceptance receipt can resume")
    output = Path(receipt["output"]).resolve(strict=True)
    if receipt_path != output / "runner.json" or Path(receipt["isolated_project"]).resolve() != output / "project":
        raise ValueError("prepared receipt has an inconsistent isolated output")
    expected_environment = {"APPDATA":output / "profile/roaming", "LOCALAPPDATA":output / "profile/local"}
    if any(Path(receipt["environment"].get(key, "")).resolve() != path for key, path in expected_environment.items()):
        raise ValueError("prepared environment no longer selects its disposable profile")
    profile = Path(receipt["expected_user_data_dir"]).resolve(strict=True)
    if not profile.is_relative_to(expected_environment["APPDATA"]):
        raise ValueError("prepared user data escaped the disposable profile")
    if "initial_profile_files" not in receipt or profile_snapshot(profile) != receipt["initial_profile_files"]:
        raise ValueError("prepared profile changed or has already been used; prepare a new run")
    verify_inputs(receipt)
    return receipt


def validate_input_report(report: dict, receipt: dict) -> list[str]:
    """A small viewport alone is never accepted as evidence of touch input."""
    mode = receipt.get("input_mode", "keyboard_mouse")
    errors = []
    if report.get("input_mode", "keyboard_mouse") != mode:
        errors.append("observed input mode differs from the requested route")
    if mode == "touch":
        counts = report.get("screen_input_counts")
        if not isinstance(counts, dict) or any(type(counts.get(key)) is not int or counts[key] <= 0
                for key in ("screen_touch", "screen_drag", "ui", "move", "look", "action")):
            errors.append("touch route lacks screen contact, drag, menu, movement, look or action evidence")
        if any(type(report.get(key)) is not int or report[key] != 0 for key in ("injected_keyboard_events", "injected_mouse_events")):
            errors.append("touch route injected keyboard or mouse input")
        if report.get("touch_input_coverage") is not True:
            errors.append("touch route did not complete its input coverage")
        if report.get("physical_phone_coverage") is not False:
            errors.append("native touch viewport cannot claim physical-phone coverage")
        if report.get("native_touchscreen_emulation") is not True:
            errors.append("native touch route did not record its simulated touchscreen")
        evidence = report.get("screen_action_evidence", {})
        if not isinstance(evidence, dict):
            evidence = {}
        actions = evidence.get("actions", {})
        if not isinstance(actions, dict):
            actions = {}
        menus = evidence.get("menu_actions", {})
        reacquired = evidence.get("menu_reacquisitions", {})
        labels = evidence.get("ui_labels", {})
        if evidence.get("open_contacts") != 0 or type(evidence.get("open_contacts")) is not int:
            errors.append("touch route left open or unrecorded fingers")
        valid_actions = True
        for action, row in actions.items():
            if (not isinstance(action, str) or not isinstance(row, dict)
                    or any(type(row.get(key)) is not int for key in ("pressed", "released", "held_ms"))
                    or row.get("pressed", 0) <= 0 or row.get("pressed") != row.get("released") or row.get("held_ms", -1) < 0):
                valid_actions = False
        if not actions or not valid_actions:
            errors.append("touch action contacts lack balanced press/release evidence")
        elif isinstance(counts, dict) and sum(row["pressed"] for row in actions.values()) != counts.get("action"):
            errors.append("touch action totals differ from their per-control evidence")
        for name, values in [("menu_actions", menus), ("menu_reacquisitions", reacquired), ("ui_labels", labels)]:
            if not isinstance(values, dict) or any(not isinstance(key, str) or type(value) is not int or value <= 0 for key, value in values.items()):
                errors.append(f"touch route has malformed {name} evidence")
        if isinstance(labels, dict) and (not labels or isinstance(counts, dict) and sum(value for value in labels.values() if type(value) is int) != counts.get("ui")):
            errors.append("touch UI totals differ from their visible-button evidence")
        if isinstance(menus, dict) and valid_actions:
            more = actions.get("touch_more", {}).get("pressed", 0)
            if sum(value for value in menus.values() if type(value) is int) != more:
                errors.append("More contacts lack one corresponding visible action each")
        if isinstance(reacquired, dict) and valid_actions:
            for action, count in reacquired.items():
                if action not in ("aim_bow", "block") or type(count) is not int or count >= actions.get(action, {}).get("pressed", 0):
                    errors.append("More reacquisition lacks a new supported held-action contact")
        required = {"interact", "pause"}
        if receipt.get("seed_contract", {}).get("suite") == "full_campaign":
            required.update(["touch_more", "light_attack", "aim_bow", "fire_bow"])
            if not isinstance(menus, dict) or not all(type(menus.get(key)) is int and menus[key] > 0 for key in ("weapon_sword", "weapon_bow")):
                errors.append("full touch campaign lacks visible sword/bow selection")
            if type(evidence.get("simultaneous_aim_fire")) is not int or evidence["simultaneous_aim_fire"] <= 0:
                errors.append("full touch campaign lacks overlapping Aim and Draw contacts")
            aim_requests = evidence.get("aim_mode_requests", [])
            if (not isinstance(aim_requests, list) or not aim_requests
                    or any(not isinstance(row, dict) or row.get("mode") not in ("hold", "toggle")
                           or any(type(row.get(key)) is not bool for key in ("requested", "initial", "final"))
                           or row.get("final") != row.get("requested") for row in aim_requests)
                    or {row.get("requested") for row in aim_requests if isinstance(row, dict)} != {True, False}):
                errors.append("full touch campaign did not verify its live Aim policy on and off")
            if "target_lock" not in actions and (not isinstance(menus, dict) or "target_lock" not in menus):
                errors.append("full touch campaign lacks its actual visible target-lock action")
        if required - actions.keys():
            errors.append("touch route lacks required per-action evidence: " + ", ".join(sorted(required - actions.keys())))
    elif report.get("touch_input_coverage", False):
        errors.append("keyboard route cannot claim touch-input coverage")
    return errors


def run(receipt: dict, receipt_path: Path, extra_validator=None) -> int:
    # The shared launcher creates the renderer on an owned, non-input Windows
    # desktop from its first native window. There is no foreground fallback.
    from background_native_capture import spawn_background

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
            process = spawn_background(receipt["command"], cwd=receipt["isolated_project"], env=environment, stdout=log)
            receipt["owned_pid"] = process.pid
            receipt["desktop"] = process.desktop_receipt.copy()
            write(receipt_path, receipt)
            receipt["exit_code"] = process.wait(timeout=receipt["timeout_seconds"])
        verify_inputs(receipt)
        report = json.loads((output / "report.json").read_text(encoding="utf-8"))
        errors = []
        if receipt["exit_code"] != 0 or report.get("status") != "pass" or report.get("failures"):
            errors.append("engine or acceptance report failed")
        if report.get("case") != receipt["case"] or report.get("completed_work") != receipt["seed_contract"]["expected_work"]:
            errors.append("physical task coverage differs from requested case")
        closure = receipt["candidate_closure"]
        if report.get("mounted_pack_ids") != [row["id"] for row in closure["packs"]] or report.get("candidate_build_id") != closure["build_id"]:
            errors.append("mounted candidate closure differs from the verified release")
        if report.get("progression_injection") is not False or report.get("input_events", 0) < 50:
            errors.append("real-input evidence is incomplete")
        if report.get("execution_mode") != "background-rendered" or report.get("capture_desktop") != receipt["desktop"]["desktop"]:
            errors.append("rendered fixture did not confirm its isolated desktop")
        if report.get("no_focus") is not True or report.get("headless") is not False or report.get("renderer") != "gl_compatibility":
            errors.append("fixture did not retain the unfocusable native compatibility renderer")
        expected_size = [960, 540] if receipt["viewport"] == "touch" else [1280, 720]
        if report.get("viewport_size") != expected_size:
            errors.append("rendered viewport differs from the requested dimensions")
        errors.extend(validate_input_report(report, receipt))
        if receipt["seed_contract"].get("suite"):
            if extra_validator is None:
                errors.append("complete campaign has no frozen receipt validator")
            else:
                errors.extend(extra_validator(report, receipt["seed_contract"]))
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
        receipt["touch_input_coverage"] = not errors and report.get("touch_input_coverage") is True
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        receipt["status"] = "fail"
        receipt["failures"] = [str(error)]
    finally:
        if process is not None:
            try:
                stop_owned_process(process)
            except (OSError, ValueError, subprocess.TimeoutExpired) as error:
                receipt["status"] = "fail"
                receipt.setdefault("failures", []).append("owned process cleanup: " + str(error))
            try:
                process.close()
            except (OSError, RuntimeError) as error:
                receipt["status"] = "fail"
                receipt.setdefault("failures", []).append("owned desktop cleanup: " + str(error))
            receipt["desktop"] = process.desktop_receipt.copy()
            desktop = receipt["desktop"]
            if any(desktop.get(key) == desktop["desktop"] for key in ["input_desktop_before", "input_desktop_after_launch", "input_desktop_after_exit"]):
                receipt["status"] = "fail"
                receipt.setdefault("failures", []).append("capture desktop became interactive")
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
    parser.add_argument("--release-manifest", type=Path, required=True, help="maintained final Web release_manifest.json; native packs must match its decoded hashes")
    parser.add_argument("--class-cache", type=Path, default=PROJECT / ".godot/global_script_class_cache.cfg")
    parser.add_argument("--godot", type=Path, default=GODOT)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--viewport", choices=["desktop", "touch"], default="desktop")
    parser.add_argument("--input-mode", choices=["keyboard_mouse", "touch"], help="defaults to genuine screen input at the touch viewport; viewport-only keyboard runs remain explicitly labelled")
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
