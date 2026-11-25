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
import struct
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


def target_preflight(project: Path, profiles: dict) -> dict:
    """Reject stale fixture realms before starting an engine or dispatching travel."""
    registry_path = project / "scripts/zone_composition_router.gd"
    registry_source = registry_path.read_text(encoding="utf-8")
    registered = []
    for name in ("CORE_ZONES", "CAMPAIGN_ZONES"):
        matches = re.findall(r"const\s+" + name + r"\s*:\s*Array\[String\]\s*(?::=|=)\s*(\[[\s\S]*?\])", registry_source)
        if len(matches) != 1:
            raise ValueError("cannot read authoritative literal zone registry: " + name)
        registered.extend(json.loads(re.sub(r",\s*\]$", "]", matches[0])))
    source = (project / "tools/capture_monster_vitality.gd").read_text(encoding="utf-8")
    blocks = re.findall(r"const ENEMIES\s*:=\s*\{([\s\S]*?)\n\}", source)
    if len(blocks) != 1:
        raise ValueError("cannot read reviewed native capture target table")
    native_rows = re.findall(r'"(M\d{2})"\s*:\s*\{\s*"role"\s*:\s*"([^"]+)"\s*,\s*"zone"\s*:\s*"([^"]+)"', blocks[0])
    targets = {asset: {"role":role,"zone":zone,"kind":"native_enemy"} for asset,role,zone in native_rows}
    if len(targets) != len(native_rows) or len(targets) != 10:
        raise ValueError("native capture target table is incomplete or duplicated")
    ecology = json.loads((project / "data/design_pack_ecology.json").read_bytes())
    for row in ecology["sightings"]:
        asset = row["design"]
        if asset in targets:
            raise ValueError("duplicate source capture species: " + asset)
        targets[asset] = {"role":row["role"],"zone":row["zone"],"kind":"observational_ecology"}
    if set(targets) != set(profiles["assets"]):
        raise ValueError("capture targets do not cover the actual native source inventory")
    for asset, target in targets.items():
        if target["zone"] not in registered:
            raise ValueError("unregistered source capture realm: " + asset + " / " + target["zone"])
    return {"validated_before_engine_start":True,"registry_path":str(registry_path),
            "registry_sha256":digest(registry_path),"registered_zones":sorted(registered),"assets":targets}


def prepare(args: argparse.Namespace) -> tuple[dict, Path]:
    output = args.output.resolve()
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise ValueError("capture output must be new or empty: " + str(output))
    output.mkdir(parents=True, exist_ok=True)
    project = args.project.resolve(strict=True)
    godot = args.godot.resolve(strict=True)
    if project != PROJECT:
        raise ValueError("run the reviewed tool from the intended project checkout")
    profiles = json.loads((project / "data/monster_material_profiles.json").read_bytes())
    preflight = target_preflight(project, profiles)
    cache = project / ".godot/global_script_class_cache.cfg"
    if not cache.is_file() or not SCRIPT.is_file():
        raise ValueError("completed source import and capture script are required")
    run_id = "monster_vitality_" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "_" + uuid.uuid4().hex[:8]
    profile = "AshenOathCapture/" + run_id
    isolated = output / "isolated_project"
    isolated.mkdir(exist_ok=False)
    original = (project / "project.godot").read_bytes()
    configured = isolated_configuration(original, profile).decode("utf-8")
    width, height = (960, 540) if args.viewport == "touch" else (1280, 720)
    for key, value in (("viewport_width", 1280), ("viewport_height", 720)):
        values = re.findall(r"(?m)^window/size/" + key + r"=([^\r\n]*)", configured)
        if values != [str(value)]:
            raise ValueError("production internal canvas changed: display/window/size/" + key)
    (isolated / "project.godot").write_bytes(configured.encode("utf-8"))
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
    species = list(profiles["assets"]) if args.species == "all" else args.species.split(",")
    if len(species) != len(set(species)) or any(name not in profiles["assets"] for name in species):
        raise ValueError("requested species must be distinct registered M IDs")
    pins = [SCRIPT, Path(__file__).resolve(), project / "project.godot", project / "tools/background_native_capture.py",
            project / "tools/living_cast_capture_geometry.gd", project / "scripts/views/monster_material_view.gd",
            project / "tools/qa_viewport_coordinates.gd",
            project / "tools/capture_monster_mechanics.gd", project / "tools/capture_bog_wretch_wychwood.gd",
            project / "scripts/views/monster_pigment_material.gd",
            project / "scripts/character_material_bindings.gd", project / "scripts/asset_spawn_helper.gd",
            project / "scripts/enemy_ai.gd", project / "scripts/game.gd", project / "scripts/zone_construction_host.gd",
            project / "data/monster_material_profiles.json", project / "data/design_pack_ecology.json",
            project / "data/enemies.json"]
    # The architecture delegates through thin adapters. Bind the actual views,
    # strike/navigation/boss owners and all runtime data, not just enemy_ai.gd.
    runtime_scripts = sorted((project / "scripts").rglob("*.gd"))
    data_json = sorted((project / "data").rglob("*.json"))
    shader_files = sorted(path for path in (project / "shaders").rglob("*")
                          if path.is_file() and path.suffix in {".gdshader", ".gdshaderinc"})
    scene_files = sorted((project / "scenes").rglob("*.tscn"))
    root_json = sorted(project.glob("*.json"))
    pins.extend(runtime_scripts + data_json + shader_files + scene_files + root_json)
    for name in species:
        asset = profiles["assets"][name]
        path = project / asset["source"].removeprefix("res://")
        if digest(path) != asset["source_sha256"]:
            raise ValueError("native source differs from reviewed material profile: " + name)
        pins.append(path)
    hunt_files = {
        "M01": ("wychwood_hunters/m01_shroud", "wychwood_hunters/m01_motion"),
        "M02": ("wychwood_hunters/m02_vanes", "wychwood_hunters/m02_motion"),
        "M19": ("wychwood_raider_regalia", "wychwood_raider_motion"),
        "M20": ("wychwood_brute_regalia", "wychwood_brute_motion"),
    }
    for asset in species:
        for stem in hunt_files.get(asset, ()):
            source = project / "assets/characters" / (stem + ".res")
            if source.is_file():
                pins.append(source)
    mechanics = None
    if args.mechanics_script:
        mechanics = args.mechanics_script.resolve(strict=True)
        if not mechanics.is_relative_to(project):
            raise ValueError("mechanics module must be inside the reviewed source project")
        pins.append(mechanics)
    command = [str(godot), "--path", str(isolated), "--windowed", "--resolution", f"{width}x{height}",
               "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
               "--rendering-driver", "opengl3", "--script", "res://tools/capture_monster_vitality.gd",
               "--log-file", str(output / "godot.log"), "--", "--profile=" + profile,
               "--output=" + output.as_posix(), "--viewport=" + args.viewport, "--species=" + args.species,
               "--poses=" + args.poses, "--environments=" + args.environments,
               "--framing-policy=" + args.framing_policy,
               "--lit-clearing=" + args.lit_clearing,
               "--dry-floor-seat=" + args.dry_floor_seat,
               "--isolate-m11=" + str(args.isolate_m11).lower(),
               "--require-hunt-gear=" + str(args.require_hunt_gear).lower(),
               "--motion-reels=" + str(args.motion_reels).lower(),
               "--performance=" + str(args.performance).lower()]
    if mechanics:
        command.append("--mechanics-script=res://" + mechanics.relative_to(project).as_posix())
    input_records = [{"path": str(path), "sha256": digest(path)} for path in dict.fromkeys(pins)]
    closure = hashlib.sha256()
    for record in sorted(input_records, key=lambda item: item["path"]):
        relative = Path(record["path"]).relative_to(project).as_posix()
        closure.update((relative + "\0" + record["sha256"] + "\n").encode("utf-8"))
    receipt = {"schema_version": 1, "kind": "source_monster_material_level_runner", "status": "prepared",
               "mode": "source_authoring_preview", "frozen_export_verified": False,
               "project": str(project), "isolated_project": str(isolated), "output": str(output),
               "profile": profile, "expected_user_data_dir": str(user_data), "window_mode": "background-rendered",
               "configured_window_size": [width, height], "configured_render_viewport": [1280, 720],
               "viewport_policy": "production_internal_canvas_with_native_window_stretch",
               "serial_execution_required": True, "source_directory_junctions": links,
               "shared_import_cache": str(project / ".godot"), "engine_cache_writes_serialized_by_caller": True,
               "isolated_project_sha256": digest(isolated / "project.godot"),
               "source_inputs": input_records,
               "target_preflight":preflight,
               "runtime_input_closure": {"kind": "runtime_scripts_data_scenes_shaders_and_selected_native_sources",
                                         "runtime_script_files": len(runtime_scripts), "data_json_files": len(data_json),
                                         "shader_files": len(shader_files), "scene_files": len(scene_files),
                                         "root_json_files": len(root_json), "input_files": len(input_records),
                                         "sha256": closure.hexdigest(),
                                         "limitation": "source-authoring code/data receipt; not frozen-export/resource-closure verification"},
               "environment": {"APPDATA": str(roaming), "LOCALAPPDATA": str(local)},
               "command": command, "timeout_seconds": args.timeout,
               "matrix": {"species": species, "environments": args.environments.split(","),
                          "poses": args.poses.split(","), "viewport": args.viewport, "isolate_m11": args.isolate_m11,
                          "lit_clearing":args.lit_clearing.split(",") if args.lit_clearing else [],
                          "dry_floor_seat":args.dry_floor_seat.split(",") if args.dry_floor_seat else []},
               "visual_acceptance": False, "earned_progress_acceptance": False,
               "real_input_acceptance": False, "physical_phone_coverage": False,
               "audio_driver": "Dummy", "audible_audio_acceptance": False}
    path = output / "runner.json"
    save(path, receipt)
    return receipt, path


def verify_inputs(receipt: dict, phase: str) -> None:
    settings_hash = digest(Path(receipt["isolated_project"]) / "project.godot")
    settings_match = settings_hash == receipt["isolated_project_sha256"]
    project = Path(receipt["project"])
    records = []
    changed = []
    for pin in receipt["source_inputs"]:
        actual = digest(Path(pin["path"]))
        records.append({"path": pin["path"], "sha256": actual})
        if actual != pin["sha256"]:
            changed.append(pin["path"])
    closure = hashlib.sha256()
    for record in sorted(records, key=lambda item: item["path"]):
        relative = Path(record["path"]).relative_to(project).as_posix()
        closure.update((relative + "\0" + record["sha256"] + "\n").encode("utf-8"))
    actual_closure = closure.hexdigest()
    matches = settings_match and not changed and actual_closure == receipt["runtime_input_closure"]["sha256"]
    receipt.setdefault("source_validation", {})[phase] = {
        "checked_at_utc": datetime.now(timezone.utc).isoformat(), "input_files": len(records),
        "sha256": actual_closure, "matches_pinned_begin": matches,
        "isolated_project_sha256": settings_hash, "isolated_project_matches": settings_match,
        "changed_paths": changed,
    }
    if phase == "end":
        receipt["source_inputs_end"] = records
    if not matches:
        raise ValueError("source or isolated settings changed during observation: " + ", ".join(changed))


def mechanics_artifacts(output: Path, report: dict, viewport: list[int]) -> list[dict]:
    """Bind the module's actual gameplay evidence without inferring acceptance."""
    module = report.get("mechanics")
    if module is None:
        return []
    directory = (output / "mechanics").resolve(strict=True)
    report_path = (directory / "report.json").resolve(strict=True)
    artifacts = [{"kind": "mechanics_report", "path": str(report_path),
                  "bytes": report_path.stat().st_size, "sha256": digest(report_path)}]
    for capture in module.get("captures", []):
        path = Path(capture["path"]).resolve(strict=True)
        if not path.is_relative_to(directory) or path.suffix != ".png" or capture.get("error") != 0:
            raise ValueError("invalid mechanics image artifact")
        with path.open("rb") as stream:
            header = stream.read(24)
        if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError("mechanics artifact is not a complete PNG header")
        width, height = struct.unpack(">II", header[16:24])
        if [width, height] != viewport or width != capture.get("width") or height != capture.get("height"):
            raise ValueError("mechanics PNG viewport mismatch: " + path.name)
        artifacts.append({"kind": "mechanics_image", "case": capture["case"], "path": str(path),
                          "width": width, "height": height, "bytes": path.stat().st_size, "sha256": digest(path)})
    return artifacts


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
        box = modes["original"]["projection"]
        low, high = box["min"], box["max"]
        crop = (max(0, math.floor(low[0])), max(0, math.floor(low[1])),
                min(before.width, math.ceil(high[0])), min(before.height, math.ceil(high[1])))
        for control in ("identity", "identity_body", "identity_wing"):
            if control not in modes:
                continue
            identity = Image.open(modes[control]["path"]).convert("RGB")
            difference = ImageChops.difference(before, identity)
            stats = ImageStat.Stat(difference.crop(crop))
            background = difference.copy()
            background.paste((0, 0, 0), crop)
            background_stats = ImageStat.Stat(background)
            result.append({"asset": key[0], "zone": key[1], "environment": key[2], "pose": key[3], "identity_control": control,
                           "identity_crop": crop, "identity_mean_absolute_rgb_delta_255": stats.mean,
                           "identity_rms_rgb_delta_255": stats.rms,
                           "background_mean_absolute_rgb_delta_255": background_stats.mean,
                           "pose_identical": modes["original"]["pose_sha256"] == modes[control]["pose_sha256"],
                           "retained_native_materials": sorted({surface["native_name"] for surface in modes[control].get("materials", []) if surface.get("retained_native")}),
                           "automatic_visual_acceptance": False,
                           "interpretation": "native-vs-zero-pigment presentation difference; explicitly retained native surfaces are unchanged passthroughs; inspect images; background temporal noise is not a pigment change"})
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
        verify_inputs(receipt, "begin")
        environment = os.environ.copy()
        environment.update(receipt["environment"])
        with (output / "stdout.log").open("wb") as stdout:
            process = spawn_background(receipt["command"], cwd=receipt["isolated_project"], env=environment, stdout=stdout)
            receipt["owned_pid"] = process.pid
            receipt["background_desktop"] = process.desktop_receipt
            save(receipt_path, receipt)
            receipt["exit_code"] = process.wait(timeout=receipt["timeout_seconds"])
        verify_inputs(receipt, "end")
        report = json.loads((output / "report.json").read_text(encoding="utf-8"))
        receipt["mechanics_artifacts"] = mechanics_artifacts(output, report, receipt["configured_render_viewport"])
        failures = []
        if receipt["exit_code"] != 0 or report.get("status") != "pass" or report.get("failures"):
            failures.extend(report.get("failures", []))
            failures.append("source-level capture did not finish cleanly")
        matrix = receipt["matrix"]
        def modes(asset):
            if asset == "M11" and matrix.get("isolate_m11"):
                return ("original", "identity_body", "identity_wing", "identity", "candidate")
            return ("original", "identity", "candidate") if asset in IDENTITY else ("original", "candidate")
        expected = {(asset, environment, pose, mode) for asset in matrix["species"]
                    for environment in matrix["environments"] for pose in matrix["poses"]
                    for mode in modes(asset)}
        observed = {(row["asset"], row["environment"], row["pose_request"], row["mode"]) for row in report.get("frames", [])}
        if expected != observed:
            failures.append("requested source observation matrix is incomplete")
            receipt["missing_frames"] = sorted(expected - observed)
        if str(report.get("user_data_dir", "")).replace("\\", "/").casefold() != str(receipt["expected_user_data_dir"]).replace("\\", "/").casefold():
            failures.append("renderer did not use the disposable configured user directory")
        if (report.get("window_size") != receipt["configured_window_size"]
                or report.get("render_viewport") != receipt["configured_render_viewport"]
                or not report.get("dimension_checks") or any(not row.get("passed") for row in report["dimension_checks"])):
            failures.append("production canvas/native window dimension receipt failed")
        images = []
        for row in report.get("frames", []):
            path = Path(row["path"]).resolve(strict=True)
            if not path.is_relative_to(output) or path.suffix != ".png" or not path.stat().st_size:
                raise ValueError("invalid rendered image path")
            if row.get("source_geometry_unchanged") is not True or not row.get("camera", {}).get("current") or not row.get("projection", {}).get("safe"):
                failures.append("pose/camera/projection contract failed: " + path.name)
            dimensions = row.get("camera", {}).get("dimensions", {})
            if (dimensions.get("window_size") != receipt["configured_window_size"]
                    or dimensions.get("window_client_size") != receipt["configured_window_size"]
                    or dimensions.get("content_scale_size") != receipt["configured_render_viewport"]
                    or dimensions.get("visible_rect_size") != receipt["configured_render_viewport"]
                    or dimensions.get("render_texture_size") != receipt["configured_render_viewport"]
                    or not dimensions.get("mapping", {}).get("valid")):
                failures.append("native window/internal render dimensions failed: " + path.name)
            pose = row.get("pose", {})
            tolerance = float(pose.get("position_tolerance_seconds", 0.0001))
            actual_position = float(pose.get("position", -1))
            expected_position = float(pose.get("requested_position", -2))
            if (not pose.get("clip_identity_verified") or not pose.get("duration_verified")
                    or not pose.get("position_verified") or pose.get("clip") != pose.get("actual_clip")
                    or not all(math.isfinite(v) for v in (actual_position, expected_position, tolerance))
                    or not 0 < tolerance <= 0.001 or abs(actual_position - expected_position) > tolerance):
                failures.append("native clip/seek position contract failed: " + path.name)
            images.append({"path": str(path), "bytes": path.stat().st_size, "sha256": digest(path)})
        receipt["rendered_images"] = images
        diagnostics = []
        for row in report.get("diagnostics", []):
            path = Path(row["path"]).resolve(strict=True)
            if not path.is_relative_to(output) or path.suffix != ".png" or not path.stat().st_size:
                raise ValueError("invalid failed-framing diagnostic image path")
            diagnostics.append({"path": str(path), "bytes": path.stat().st_size, "sha256": digest(path),
                                "acceptance": False, "kind": row["kind"]})
        receipt["diagnostic_images"] = diagnostics
        habitats = []
        for row in report.get("habitat_observations", []):
            path = Path(row["path"]).resolve(strict=True)
            if not path.is_relative_to(output) or path.suffix != ".png" or row.get("write_error") != 0:
                raise ValueError("invalid authored habitat observation artifact")
            habitats.append({"path":str(path),"bytes":path.stat().st_size,"sha256":digest(path),"asset":row["asset"],
                             "pose":row["pose"],"mode":row["mode"],"kind":"authored_habitat_context",
                             "complete_material_coverage_acceptance":False})
        receipt["habitat_images"] = habitats
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
    parser.add_argument("--require-hunt-gear", action="store_true", help="require live fitted gear and verify near/distant animation rates")
    parser.add_argument("--motion-reels", action="store_true", help="capture fixed-camera strike phases in real encounter time for each requested enemy action")
    parser.add_argument("--performance", action="store_true", help="paired frozen-level shader-cost diagnostic; not a representative route benchmark")
    parser.add_argument("--framing-policy", choices=("authored-only", "clearing-fallback"), default="clearing-fallback",
                        help="attempt authored placement first; optional explicit floor-verified QA restage, never hide environment geometry")
    parser.add_argument("--isolate-m11", action="store_true", help="additional body-only zero-pigment and retained-native-wing passthrough controls")
    parser.add_argument("--lit-clearing", default="", help="opt-in M20/M03/M05/M06 native-lit front/threequarter floor-verified fixture restage")
    parser.add_argument("--dry-floor-seat", default="", help="opt-in M18 authored habitat context plus separately labelled dry whole-body floor-seat fixture")
    parser.add_argument("--timeout", type=float, default=1800)
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    lit_ids = args.lit_clearing.split(",") if args.lit_clearing else []
    if len(lit_ids) != len(set(lit_ids)) or any(asset not in {"M20", "M03","M05","M06"} for asset in lit_ids):
        parser.error("--lit-clearing supports distinct M20/M03/M05/M06 only")
    if args.species != "all" and not set(lit_ids).issubset(args.species.split(",")):
        parser.error("--lit-clearing IDs must be included in --species")
    dry_ids = args.dry_floor_seat.split(",") if args.dry_floor_seat else []
    if dry_ids not in ([],["M18"]) or (dry_ids and args.species!="all" and "M18" not in args.species.split(",")):
        parser.error("--dry-floor-seat supports requested M18 only")
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
