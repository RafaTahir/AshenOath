#!/usr/bin/env python3
"""Run native cast observations with user data isolated before Godot starts.

The renderer initializes caches before SceneTree._initialize(). A script-time
custom_user_dir_name change is therefore too late. This runner creates a tiny
project from the committed configuration and mounts the supplied frozen packs
from the capture script, never through --main-pack (which replaces settings).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
import uuid


PROJECT = Path(__file__).resolve().parents[1]
REPOSITORY = PROJECT.parents[1]
GATE = REPOSITORY / ".release-gate" / "living-cast-20261107"
GODOT = Path.home() / ".cache/codex-runtimes/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe"
CAPTURE = PROJECT / "tools/capture_living_cast.gd"
GEOMETRY = PROJECT / "tools/living_cast_capture_geometry.gd"
CLASS_CACHE = PROJECT / ".godot/global_script_class_cache.cfg"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def isolated_configuration(original: bytes, profile: str) -> bytes:
    """Preserve the committed config except the two application isolation keys."""
    if not re.fullmatch(r"AshenOathCapture/[a-zA-Z0-9_-]+", profile):
        raise ValueError("invalid isolated profile name")
    text = original.decode("utf-8")
    newline = "\r\n" if "\r\n" in text else "\n"
    sections = list(re.finditer(r"(?m)^\[application\]\r?$", text))
    if len(sections) != 1:
        raise ValueError("committed project must contain exactly one application section")
    start = sections[0].end()
    next_section = re.search(r"(?m)^\[", text[start:])
    end = start + next_section.start() if next_section else len(text)
    body = re.sub(
        r"(?m)^config/(?:use_custom_user_dir|custom_user_dir_name)=[^\r\n]*(?:\r?\n|$)",
        "", text[start:end],
    )
    settings = (f"{newline}config/use_custom_user_dir=true{newline}"
                f'config/custom_user_dir_name="{profile}"{newline}')
    # A CRLF section match already consumed CR, while its LF is in body.
    if start and text[start - 1] == "\r":
        start -= 1
        body = text[start:end]
        body = re.sub(
            r"(?m)^config/(?:use_custom_user_dir|custom_user_dir_name)=[^\r\n]*(?:\r?\n|$)",
            "", body,
        )
    return (text[:start] + settings + body.lstrip("\r\n") + text[end:]).encode("utf-8")


def git(*arguments: str) -> bytes:
    return subprocess.run(["git", "-C", str(REPOSITORY), *arguments],
                          check=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, timeout=30).stdout


def write_receipt(path: Path, receipt: dict) -> None:
    path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")


def stop_owned_process(process: subprocess.Popen) -> None:
    """Never enumerate or terminate unrelated Godot/editor processes."""
    if process.poll() is not None:
        return
    if os.name == "nt":
        # Godot does not normally spawn children, but keep cleanup owned-tree only.
        try:
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=15, check=False,
                           creationflags=subprocess.CREATE_NO_WINDOW)
        except (OSError, subprocess.TimeoutExpired):
            # Still terminate the process whose handle this runner owns.
            pass
    if process.poll() is None:
        process.kill()
    process.wait(timeout=15)


def prepare(args: argparse.Namespace) -> tuple[dict, Path]:
    root_pack = args.root_pack.resolve(strict=True)
    packs = args.packs.resolve(strict=True)
    godot = args.godot.resolve(strict=True)
    if not root_pack.is_file() or root_pack.suffix.lower() != ".pck":
        raise ValueError("--root-pack must be an existing PCK file")
    if not packs.is_dir():
        raise ValueError("--packs must be a directory")
    pack_files = sorted(packs.glob("*.pck"))
    if not pack_files:
        raise ValueError("--packs contains no PCK files")
    if root_pack in pack_files:
        raise ValueError("root pack must be outside the secondary pack directory")
    if not godot.is_file() or not CAPTURE.is_file() or not GEOMETRY.is_file() or not CLASS_CACHE.is_file():
        raise ValueError("Godot, capture/geometry scripts, and existing global class cache are required")
    if not os.environ.get("APPDATA"):
        raise ValueError("APPDATA is required for Windows custom user data isolation")
    commit = git("rev-parse", "HEAD").decode("ascii").strip()
    relative_project = (PROJECT / "project.godot").relative_to(REPOSITORY).as_posix()
    original = git("show", f"{commit}:{relative_project}")
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "_" + uuid.uuid4().hex[:10]
    profile = "AshenOathCapture/" + run_id
    isolated = GATE / "capture-projects" / run_id
    output = args.output.resolve() if args.output else GATE / "captures" / run_id
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise ValueError(f"output must be new or empty, preventing stale acceptance: {output}")
    output.mkdir(parents=True, exist_ok=True)
    (isolated / ".godot").mkdir(parents=True, exist_ok=False)
    (isolated / "source_project.godot").write_bytes(original)
    (isolated / "project.godot").write_bytes(isolated_configuration(original, profile))
    copied_cache = isolated / ".godot/global_script_class_cache.cfg"
    copied_cache.write_bytes(CLASS_CACHE.read_bytes())
    # Create the exact user directory before renderer cache initialization as well.
    user_data = Path(os.environ["APPDATA"]) / Path(profile)
    user_data.mkdir(parents=True, exist_ok=False)
    command = [str(godot), "--path", str(isolated),
               "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3",
               "--script", str(CAPTURE.resolve()), "--log-file", str(output / "godot.log"),
               "--", "--root-pack=" + root_pack.as_posix(), "--packs=" + packs.as_posix(),
               "--profile=" + profile, "--output=" + output.as_posix(),
               "--viewport=" + args.viewport, "--label=" + args.label,
               "--actors=" + args.actors, "--performance=" + str(args.performance).lower(),
               "--geometry-script=" + GEOMETRY.resolve().as_posix(),
               "--scenarios=" + args.scenarios, "--environments=" + args.environments,
               "--duration=" + str(args.duration), "--sample-hz=" + str(args.sample_hz),
               "--frames-per-scenario=" + str(args.frames_per_scenario)]
    reference = args.reference_report.resolve(strict=True) if args.reference_report else None
    if reference:
        prior = json.loads(reference.read_text(encoding="utf-8"))
        if not isinstance(prior, dict) or prior.get("status") != "pass" or len(prior.get("performance_preflight", [])) != 3:
            raise ValueError("reference must be a passing report with all three performance anchors")
        command.append("--reference-report=" + reference.as_posix())
    receipt = {
        "schema_version": 1, "status": "prepared", "kind": "native_living_cast_runner",
        "git_commit": commit, "isolated_project": str(isolated), "profile": profile,
        "expected_user_data_dir": str(user_data), "output": str(output),
        "source_project_sha256": hashlib.sha256(original).hexdigest(),
        "isolated_project_sha256": sha256(isolated / "project.godot"),
        "global_class_cache_sha256": sha256(copied_cache), "capture_script_sha256": sha256(CAPTURE),
        "geometry_script_sha256": sha256(GEOMETRY),
        "root_pack": {"path": str(root_pack), "sha256": sha256(root_pack)},
        "secondary_packs": [{"path": str(path), "bytes": path.stat().st_size,
                             "sha256": sha256(path)} for path in pack_files],
        "command": command, "timeout_seconds": args.timeout,
        "scenario_configuration": {"actors":args.actors.split(","), "scenarios":args.scenarios.split(","),
                                   "environments":args.environments.split(","), "duration":args.duration,
                                   "sample_hz":args.sample_hz, "frames_per_scenario":args.frames_per_scenario},
        "reference_report": {"path":str(reference), "sha256":sha256(reference)} if reference else None,
        "gameplay_acceptance": False, "physical_phone_coverage": False,
    }
    receipt_path = output / "runner.json"
    write_receipt(receipt_path, receipt)
    return receipt, receipt_path


def verify_prepared_inputs(receipt: dict) -> None:
    """A prepared observation must run and finish against the recorded bytes."""
    isolated = Path(receipt["isolated_project"])
    checks = [
        (isolated / "project.godot", receipt["isolated_project_sha256"]),
        (isolated / ".godot/global_script_class_cache.cfg", receipt["global_class_cache_sha256"]),
        (CAPTURE, receipt["capture_script_sha256"]),
        (GEOMETRY, receipt["geometry_script_sha256"]),
        (Path(receipt["root_pack"]["path"]), receipt["root_pack"]["sha256"]),
    ]
    checks.extend((Path(pack["path"]), pack["sha256"]) for pack in receipt["secondary_packs"])
    if receipt.get("reference_report"):
        checks.append((Path(receipt["reference_report"]["path"]), receipt["reference_report"]["sha256"]))
    for path, expected in checks:
        if not path.is_file() or sha256(path) != expected:
            raise ValueError(f"prepared capture input changed: {path}")


def run_capture(receipt: dict, receipt_path: Path) -> int:
    output = Path(receipt["output"])
    process = None
    started = time.monotonic()
    receipt["started_at_utc"] = datetime.now(timezone.utc).isoformat()
    receipt["status"] = "running"
    write_receipt(receipt_path, receipt)
    try:
        verify_prepared_inputs(receipt)
        with (output / "stdout.log").open("wb") as stdout:
            process = subprocess.Popen(receipt["command"], cwd=receipt["isolated_project"],
                                       stdout=stdout, stderr=subprocess.STDOUT,
                                       creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
            receipt["owned_pid"] = process.pid
            write_receipt(receipt_path, receipt)
            receipt["exit_code"] = process.wait(timeout=receipt["timeout_seconds"])
        verify_prepared_inputs(receipt)
        failures = []
        if receipt["exit_code"] != 0:
            failures.append(f"Godot exited with {receipt['exit_code']}")
        report = json.loads((output / "report.json").read_text(encoding="utf-8"))
        if not isinstance(report, dict):
            raise ValueError("capture report must be an object")
        if report.get("status") != "pass" or report.get("failures") or not report.get("frames"):
            failures.append("capture report did not pass with rendered frames")
        expected = receipt["scenario_configuration"]
        requested = {(actor, environment, scenario) for actor in expected["actors"]
                     for environment in expected["environments"] for scenario in expected["scenarios"]}
        actual = {(row.get("actor"), row.get("environment"), row.get("scenario")) for row in report.get("scenarios", [])}
        if requested != actual:
            failures.append("capture report does not cover the exact requested scenario matrix")
        if any(frame.get("validation") or not frame.get("camera", {}).get("current") for frame in report.get("frames", [])):
            failures.append("a frame failed visual/projection validation or fixture camera ownership")
        if any(not row.get("frames") or not row.get("samples") for row in report.get("scenarios", [])):
            failures.append("a requested scenario produced no frames or telemetry")
        rendered_frames = []
        for frame in report.get("frames", []):
            path = Path(frame.get("path", "")).resolve(strict=True)
            if not path.is_relative_to(output.resolve()) or path.suffix.lower() != ".png" or path.stat().st_size == 0:
                raise ValueError("rendered frame must be a nonempty PNG within the capture output")
            rendered_frames.append({"path":str(path),"bytes":path.stat().st_size,"sha256":sha256(path)})
        receipt["rendered_frames"] = rendered_frames
        actual_user_data = str(report.get("user_data_dir", "")).replace("\\", "/").casefold()
        expected_user_data = str(receipt["expected_user_data_dir"]).replace("\\", "/").casefold()
        if actual_user_data != expected_user_data:
            failures.append("capture report user data directory differs from isolated configuration")
        error_lines = []
        for path in (output / "godot.log", output / "stdout.log"):
            if path.is_file():
                error_lines.extend(line for line in path.read_text(encoding="utf-8", errors="replace").splitlines()
                                   if "ERROR:" in line or "_save_to_cache" in line)
        if error_lines:
            failures.append("engine logs contain errors; see engine_error_lines")
            receipt["engine_error_lines"] = list(dict.fromkeys(error_lines))[:40]
        receipt["failures"] = failures
        receipt["status"] = "pass" if not failures else "fail"
    except subprocess.TimeoutExpired:
        receipt["status"] = "timeout"
        receipt["failures"] = ["owned Godot process exceeded the capture deadline"]
    except KeyboardInterrupt:
        receipt["status"] = "cancelled"
        receipt["failures"] = ["capture interrupted; owned process cleanup requested"]
    except (OSError, ValueError) as error:
        receipt["status"] = "fail"
        receipt["failures"] = [str(error)]
    finally:
        if process is not None:
            try:
                stop_owned_process(process)
            except (OSError, subprocess.TimeoutExpired) as error:
                receipt["status"] = "fail"
                receipt.setdefault("failures", []).append(f"owned process cleanup failed: {error}")
            receipt["exit_code"] = process.poll()
        receipt["elapsed_seconds"] = round(time.monotonic() - started, 3)
        receipt["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
        write_receipt(receipt_path, receipt)
    return 0 if receipt["status"] == "pass" else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root-pack", required=True, type=Path)
    parser.add_argument("--packs", required=True, type=Path)
    parser.add_argument("--output", type=Path, help="New or empty capture directory")
    parser.add_argument("--godot", type=Path, default=GODOT)
    parser.add_argument("--viewport", choices=("desktop", "touch"), default="desktop")
    parser.add_argument("--label", default="candidate")
    parser.add_argument("--actors", default="anwen,tor,mira,rook")
    parser.add_argument("--performance", action="store_true")
    parser.add_argument("--scenarios", default="observe", help="Comma-separated observe,idle,work,approach,dialogue,interruption,resume")
    parser.add_argument("--environments", default="day", help="Comma-separated day,night,rain")
    parser.add_argument("--full", action="store_true", help="All six lifecycle scenarios in day, night and rain")
    parser.add_argument("--duration", type=float, default=4.4, help="Seconds observed per scenario")
    parser.add_argument("--sample-hz", type=float, default=10.0, help="Requested telemetry frequency; actual frequency is recorded")
    parser.add_argument("--frames-per-scenario", type=int, default=5)
    parser.add_argument("--reference-report", type=Path, help="Require identical preflight performance cameras to a passing baseline")
    parser.add_argument("--timeout", type=float, default=600.0)
    parser.add_argument("--prepare-only", action="store_true", help="Write isolation and command receipts without launching Godot")
    args = parser.parse_args()
    if not math.isfinite(args.timeout) or not 1 <= args.timeout <= 3600:
        parser.error("--timeout must be between 1 and 3600 seconds")
    if args.full:
        args.scenarios = "idle,work,approach,dialogue,interruption,resume"
        args.environments = "day,night,rain"
    for name, allowed in (("scenarios", {"observe","idle","work","approach","dialogue","interruption","resume"}),
                          ("environments", {"day","night","rain"})):
        values = getattr(args, name).split(",")
        if not values or len(values) != len(set(values)) or any(value not in allowed for value in values):
            parser.error(f"--{name} must contain distinct supported values")
    actors = args.actors.split(",")
    if len(actors) != len(set(actors)) or any(not re.fullmatch(r"[a-z][a-z0-9_]*", actor) for actor in actors):
        parser.error("--actors must contain distinct actor IDs")
    if not math.isfinite(args.duration) or not 1 <= args.duration <= 60:
        parser.error("--duration must be between 1 and 60 seconds")
    if not math.isfinite(args.sample_hz) or not 1 <= args.sample_hz <= 60:
        parser.error("--sample-hz must be between 1 and 60")
    if not 1 <= args.frames_per_scenario <= 600:
        parser.error("--frames-per-scenario must be between 1 and 600")
    if args.reference_report and not args.performance:
        parser.error("--reference-report requires --performance")
    try:
        receipt, path = prepare(args)
        result = 0 if args.prepare_only else run_capture(receipt, path)
        print(f"LIVING CAST RUNNER: {receipt['status'].upper()} - {path}")
        return result
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"LIVING CAST RUNNER: FAIL - {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
