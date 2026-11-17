#!/usr/bin/env python3
"""Observe authored monster pigments in real source-project level lighting.

This preview uses the real main and zone owners, an isolated configuration set
before renderer startup, and an owned non-input Windows desktop. It is not a
frozen-release, earned-journey or physical-phone acceptance runner. Engine runs
must be serialized with source imports and other QA by the caller.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import sys
import time
import uuid

from background_native_capture import spawn_background
from run_living_cast_capture import isolated_configuration

PROJECT = Path(__file__).resolve().parents[1]
SCRIPT = PROJECT / "tools/capture_monster_vitality.gd"
GODOT = Path.home() / ".cache/codex-runtimes/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe"
IDENTITY = {"M02", "M09", "M11"}


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def save(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def junction(destination: Path, source: Path) -> None:
    """Create a new explicit directory link; never replace an existing path."""
    if destination.exists() or destination.is_symlink():
        raise ValueError("isolation link already exists: " + str(destination))
    quoted = lambda value: "'" + str(value).replace("'", "''") + "'"
    command = ("$ErrorActionPreference='Stop'\n"
               "New-Item -ItemType Junction -Path " + quoted(destination)
               + " -Target " + quoted(source) + " | Out-Null")
    subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", command],
                   check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def prepare(args: argparse.Namespace) -> tuple[dict, Path]:
    output = args.output.resolve()
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise ValueError("capture output must be new or empty: " + str(output))
    output.mkdir(parents=True, exist_ok=True)
    project = args.project.resolve(strict=True)
    godot = args.godot.resolve(strict=True)
    if project != PROJECT:
        raise ValueError("run the reviewed tool from the intended project checkout")
    cache = project / ".godot/global_script_class_cache.cfg"
    if not cache.is_file() or not SCRIPT.is_file():
        raise ValueError("completed source import and capture script are required")
    run_id = "monster_vitality_" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "_" + uuid.uuid4().hex[:8]
    profile = "AshenOathCapture/" + run_id
    isolated = output / "isolated_project"
    isolated.mkdir(exist_ok=False)
    original = (project / "project.godot").read_bytes()
    (isolated / "project.godot").write_bytes(isolated_configuration(original, profile))
    (isolated / "source_project.godot").write_bytes(original)
    links = []
    for source in project.iterdir():
        if source.name in {"project.godot", "source_project.godot"}:
            continue
        target = isolated / source.name
        if source.is_dir():
            junction(target, source)
            links.append({"path": str(target), "source": str(source)})
        elif source.is_file():
            shutil.copyfile(source, target)
    roaming = output / "profile/roaming"
    local = output / "profile/local"
    user_data = roaming / Path(profile)
    user_data.mkdir(parents=True, exist_ok=False)
    local.mkdir(parents=True, exist_ok=False)
    profiles = json.loads((project / "data/monster_material_profiles.json").read_bytes())
    species = list(profiles["assets"]) if args.species == "all" else args.species.split(",")
    if len(species) != len(set(species)) or any(name not in profiles["assets"] for name in species):
        raise ValueError("requested species must be distinct registered M IDs")
    pins = [SCRIPT, project / "project.godot", project / "tools/background_native_capture.py",
            project / "tools/living_cast_capture_geometry.gd", project / "scripts/views/monster_material_view.gd",
            project / "scripts/views/monster_pigment_material.gd",
            project / "scripts/character_material_bindings.gd", project / "scripts/asset_spawn_helper.gd",
            project / "scripts/enemy_ai.gd", project / "scripts/game.gd", project / "scripts/zone_construction_host.gd",
            project / "data/monster_material_profiles.json", project / "data/design_pack_ecology.json",
            project / "data/enemies.json"]
    pins.extend(project.glob("shaders/monster_pigment*"))
    for name in species:
        asset = profiles["assets"][name]
        path = project / asset["source"].removeprefix("res://")
        if digest(path) != asset["source_sha256"]:
            raise ValueError("native source differs from reviewed material profile: " + name)
        pins.append(path)
    mechanics = None
    if args.mechanics_script:
        mechanics = args.mechanics_script.resolve(strict=True)
        if not mechanics.is_relative_to(project):
            raise ValueError("mechanics module must be inside the reviewed source project")
        pins.append(mechanics)
    command = [str(godot), "--path", str(isolated), "--windowed", "--rendering-method", "gl_compatibility",
               "--rendering-driver", "opengl3", "--script", "res://tools/capture_monster_vitality.gd",
               "--log-file", str(output / "godot.log"), "--", "--profile=" + profile,
               "--output=" + output.as_posix(), "--viewport=" + args.viewport, "--species=" + args.species,
               "--poses=" + args.poses, "--environments=" + args.environments,
               "--performance=" + str(args.performance).lower()]
    if mechanics:
        command.append("--mechanics-script=res://" + mechanics.relative_to(project).as_posix())
    receipt = {"schema_version": 1, "kind": "source_monster_material_level_runner", "status": "prepared",
               "mode": "source_authoring_preview", "frozen_export_verified": False,
               "project": str(project), "isolated_project": str(isolated), "output": str(output),
               "profile": profile, "expected_user_data_dir": str(user_data), "window_mode": "background-rendered",
               "serial_execution_required": True, "source_directory_junctions": links,
               "shared_import_cache": str(project / ".godot"), "engine_cache_writes_serialized_by_caller": True,
               "isolated_project_sha256": digest(isolated / "project.godot"),
               "source_inputs": [{"path": str(path), "sha256": digest(path)} for path in dict.fromkeys(pins)],
               "environment": {"APPDATA": str(roaming), "LOCALAPPDATA": str(local)},
               "command": command, "timeout_seconds": args.timeout,
               "matrix": {"species": species, "environments": args.environments.split(","),
                          "poses": args.poses.split(","), "viewport": args.viewport},
               "visual_acceptance": False, "earned_progress_acceptance": False,
               "real_input_acceptance": False, "physical_phone_coverage": False}
    path = output / "runner.json"
    save(path, receipt)
    return receipt, path


def verify_inputs(receipt: dict) -> None:
    if digest(Path(receipt["isolated_project"]) / "project.godot") != receipt["isolated_project_sha256"]:
        raise ValueError("isolated project settings changed")
    for pin in receipt["source_inputs"]:
        if digest(Path(pin["path"])) != pin["sha256"]:
            raise ValueError("source changed during observation: " + pin["path"])


def image_diagnostics(report: dict) -> list[dict]:
    """Quantify identity mismatch and moving background; never infer visual approval."""
    from PIL import Image, ImageChops, ImageStat
    grouped = {}
    for row in report["frames"]:
        key = (row["asset"], row["zone"], row["environment"], row["pose_request"])
        grouped.setdefault(key, {})[row["mode"]] = row
    result = []
    for key, modes in grouped.items():
        if "identity" not in modes or "original" not in modes:
            continue
        before = Image.open(modes["original"]["path"]).convert("RGB")
        identity = Image.open(modes["identity"]["path"]).convert("RGB")
        difference = ImageChops.difference(before, identity)
        box = modes["original"]["projection"]
        low, high = box["min"], box["max"]
        crop = (max(0, math.floor(low[0])), max(0, math.floor(low[1])),
                min(before.width, math.ceil(high[0])), min(before.height, math.ceil(high[1])))
        stats = ImageStat.Stat(difference.crop(crop))
        background = difference.copy()
        background.paste((0, 0, 0), crop)
        background_stats = ImageStat.Stat(background)
        result.append({"asset": key[0], "zone": key[1], "environment": key[2], "pose": key[3],
                       "identity_crop": crop, "identity_mean_absolute_rgb_delta_255": stats.mean,
                       "identity_rms_rgb_delta_255": stats.rms,
                       "background_mean_absolute_rgb_delta_255": background_stats.mean,
                       "pose_identical": modes["original"]["pose_sha256"] == modes["identity"]["pose_sha256"],
                       "automatic_visual_acceptance": False,
                       "interpretation": "native-vs-zero-pigment shader difference; inspect images; background temporal noise is not a pigment change"})
    return result


def performance_diagnostics(report: dict) -> list[dict]:
    results = []
    for row in report.get("specimens", []):
        data = row.get("paired_render_cost")
        if not data:
            continue
        groups = {mode: [window for window in data["windows"] if window["mode"] == mode]
                  for mode in ("original", "candidate")}
        item = {"asset": row["asset"], "zone": row["zone"], "environment": row["environment"],
                "representative_route_benchmark": False, "comparisons": [],
                "limitation": "frozen scene, one visible specimen; shader cost diagnostic only"}
        if all(len(windows) == 3 for windows in groups.values()):
            for metric in ("p50_ms", "p95_ms"):
                old = statistics.median(window[metric] for window in groups["original"])
                new = statistics.median(window[metric] for window in groups["candidate"])
                item["comparisons"].append({"metric": metric, "original_median_ms": old,
                                            "candidate_median_ms": new, "ratio": new / old,
                                            "within_ten_percent": new <= old * 1.10})
        results.append(item)
    return results


def run(receipt: dict, receipt_path: Path) -> int:
    output = Path(receipt["output"])
    process = None
    start = time.monotonic()
    receipt["started_at_utc"] = datetime.now(timezone.utc).isoformat()
    receipt["status"] = "running"
    save(receipt_path, receipt)
    try:
        verify_inputs(receipt)
        environment = os.environ.copy()
        environment.update(receipt["environment"])
        with (output / "stdout.log").open("wb") as stdout:
            process = spawn_background(receipt["command"], cwd=receipt["isolated_project"], env=environment, stdout=stdout)
            receipt["owned_pid"] = process.pid
            receipt["background_desktop"] = process.desktop_receipt
            save(receipt_path, receipt)
            receipt["exit_code"] = process.wait(timeout=receipt["timeout_seconds"])
        verify_inputs(receipt)
        report = json.loads((output / "report.json").read_text(encoding="utf-8"))
        failures = []
        if receipt["exit_code"] != 0 or report.get("status") != "pass" or report.get("failures"):
            failures.extend(report.get("failures", []))
            failures.append("source-level capture did not finish cleanly")
        matrix = receipt["matrix"]
        expected = {(asset, environment, pose, mode) for asset in matrix["species"]
                    for environment in matrix["environments"] for pose in matrix["poses"]
                    for mode in (("original", "identity", "candidate") if asset in IDENTITY else ("original", "candidate"))}
        observed = {(row["asset"], row["environment"], row["pose_request"], row["mode"]) for row in report.get("frames", [])}
        if expected != observed:
            failures.append("requested source observation matrix is incomplete")
            receipt["missing_frames"] = sorted(expected - observed)
        if str(report.get("user_data_dir", "")).replace("\\", "/").casefold() != str(receipt["expected_user_data_dir"]).replace("\\", "/").casefold():
            failures.append("renderer did not use the disposable configured user directory")
        images = []
        for row in report.get("frames", []):
            path = Path(row["path"]).resolve(strict=True)
            if not path.is_relative_to(output) or path.suffix != ".png" or not path.stat().st_size:
                raise ValueError("invalid rendered image path")
            if row.get("source_geometry_unchanged") is not True or not row.get("camera", {}).get("current") or not row.get("projection", {}).get("safe"):
                failures.append("pose/camera/projection contract failed: " + path.name)
            images.append({"path": str(path), "bytes": path.stat().st_size, "sha256": digest(path)})
        receipt["rendered_images"] = images
        receipt["identity_diagnostics"] = image_diagnostics(report)
        receipt["performance_diagnostics"] = performance_diagnostics(report)
        errors = []
        for path in (output / "stdout.log", output / "godot.log"):
            if path.is_file():
                errors.extend(line for line in path.read_text(encoding="utf-8", errors="replace").splitlines()
                              if "ERROR:" in line or "SCRIPT ERROR:" in line or "_save_to_cache" in line)
        if errors:
            failures.append("engine logs contain errors")
            receipt["engine_error_lines"] = list(dict.fromkeys(errors))[:40]
        receipt["failures"] = failures
        receipt["status"] = "pass" if not failures else "fail"
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        receipt["status"] = "fail"
        receipt["failures"] = [str(error)]
    except KeyboardInterrupt:
        receipt["status"] = "cancelled"
        receipt["failures"] = ["interrupted; cleanup limited to the owned capture process"]
    finally:
        if process is not None:
            try:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=20)
                receipt["exit_code"] = process.poll()
                process.close()
                receipt["background_desktop"] = process.desktop_receipt
            except (OSError, RuntimeError, subprocess.SubprocessError) as error:
                receipt["status"] = "fail"
                receipt.setdefault("failures", []).append("owned process cleanup failed: " + str(error))
        receipt["elapsed_seconds"] = round(time.monotonic() - start, 3)
        receipt["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
        save(receipt_path, receipt)
    return 0 if receipt["status"] == "pass" else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=PROJECT)
    parser.add_argument("--godot", type=Path, default=GODOT)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--viewport", choices=("desktop", "touch"), default="desktop")
    parser.add_argument("--species", default="all")
    parser.add_argument("--poses", default="idle", help="idle and/or action; action is native attack reference for enemies, Feed/Investigate for wildlife")
    parser.add_argument("--environments", default="day", help="day,night,rain")
    parser.add_argument("--mechanics-script", type=Path)
    parser.add_argument("--performance", action="store_true", help="paired frozen-level shader-cost diagnostic; not a representative route benchmark")
    parser.add_argument("--timeout", type=float, default=1800)
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    for name, allowed in (("poses", {"idle", "action"}), ("environments", {"day", "night", "rain"})):
        items = getattr(args, name).split(",")
        if len(items) != len(set(items)) or not items or any(item not in allowed for item in items):
            parser.error("--" + name + " must contain distinct supported values")
    if not math.isfinite(args.timeout) or not 30 <= args.timeout <= 7200:
        parser.error("--timeout must be 30..7200 seconds")
    try:
        receipt, path = prepare(args)
        result = 0 if args.prepare_only else run(receipt, path)
        print("MONSTER LEVEL CAPTURE: " + receipt["status"].upper() + " - " + str(path))
        return result
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print("MONSTER LEVEL CAPTURE: FAIL - " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
