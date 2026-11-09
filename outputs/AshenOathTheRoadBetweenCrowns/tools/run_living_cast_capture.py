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
import statistics
import sys
import time
from datetime import datetime, timezone
import uuid

from background_native_capture import spawn_background


PROJECT = Path(__file__).resolve().parents[1]
REPOSITORY = PROJECT.parents[1]
GATE = REPOSITORY / ".release-gate" / "living-cast-20261107"
GODOT = Path.home() / ".cache/codex-runtimes/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe"
CAPTURE = PROJECT / "tools/capture_living_cast.gd"
GEOMETRY = PROJECT / "tools/living_cast_capture_geometry.gd"
CLASS_CACHE = PROJECT / ".godot/global_script_class_cache.cfg"
BACKGROUND_LAUNCHER = PROJECT / "tools/background_native_capture.py"
CAPTURE_ZONES = {"greyfen", "marsh_crossing", "bandit_road", "record_hall", "vargan_court", "ruins", "lantern_reach", "hearthward"}
WORK_KINDS = {
    "anwen":{"care"}, "tor":{"forge","repair"}, "mira":{"sort_herbs","herb_stall"},
    "rook":{"check_supplies","repair"}, "nessa":{"bake","care"}, "elna":{"fold_cloth"},
    "toma":{"tend","sort_seeds","check_supplies"}, "nera":{"check_rope","check_supplies"},
    "senn":{"watch","lookout"}, "vale":{"read","write"}, "merrow":{"check_supplies","read","administer"},
    "edric":{"read","review_dispatch"},
}
REST_KINDS = {"rest","sleep","idle","sit","remember","pray","talk","shelter"}


def _finite_number(value) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def measured_contact(event: dict, identity: str) -> bool:
    """Accept real contact from this native cycle, not an old cached wrist sample."""
    state = event.get("state", {})
    native = state.get("native_life", {})
    if not event.get("event") or native.get("clip") != "life/Life_Work": return False
    phase, contact = native.get("phase"), native.get("contact_fraction")
    if not _finite_number(phase) or not _finite_number(contact) or not 0 < contact < 1 or not 0 <= phase < 1 or not 0 <= phase-contact <= .12: return False
    if not isinstance(native.get("cycle"),int) or isinstance(native.get("cycle"),bool) or native["cycle"] < 0: return False
    sides = {"left":"cloth"} if identity == "anwen" else ({"right":"hammer"} if identity == "tor" else {"left":"palm","right":"palm"})
    probes = state.get("contact_probes", {})
    for side, kind in sides.items():
        probe = probes.get(side, {})
        if probe.get("kind") != kind or probe.get("cycle") != native.get("cycle"): return False
        if not _finite_number(probe.get("error")) or not 0 <= probe["error"] <= .06: return False
        points = [probe.get(name) for name in ("target", "actual")]
        if any(not isinstance(point,list) or len(point)!=3 or not all(_finite_number(v) for v in point) for point in points): return False
        if math.dist(*points) > .06: return False
    return True


def validate_behavior(report: dict, mode: str) -> dict:
    """Candidate acceptance and historical observation have distinct receipts."""
    if mode not in {"candidate", "baseline-observation"}: raise ValueError("invalid acceptance mode")
    issues, coverage = [], []
    for row in report.get("scenarios", []):
        samples = row.get("samples", [])
        initial, final = row.get("initial", {}), row.get("final", {})
        identity, scenario = row.get("identity", row.get("actor", "")), row.get("scenario")
        label = "/".join(str(row.get(key,"")) for key in ("actor","environment","scenario"))
        activity = str(initial.get("activity", ""))
        observed_activity = any(sample.get("activity_active") is True for sample in samples)
        failures = []
        purpose = "observed_runtime"
        if scenario == "idle":
            clips = {sample.get("native_life",{}).get("clip") for sample in samples}
            if not {"life/Life_Idle_A","life/Life_Idle_B"} <= clips: failures.append("both authored idle variations were not observed")
        elif scenario == "work":
            if not observed_activity: failures.append("activity ownership was not observed")
            if activity in WORK_KINDS.get(identity,set()):
                purpose = "contact_free_watch" if identity == "senn" else "physical_occupation"
                if not any(sample.get("native_life",{}).get("clip") == "life/Life_Work" for sample in samples):
                    failures.append("authored native work clip was not observed")
                if identity != "senn" and not any(measured_contact(event,identity) for event in row.get("contacts",[])):
                    failures.append("no fresh, measured native contact event")
            elif row.get("environment") == "day":
                failures.append("daytime occupation was replaced by " + activity)
                purpose = "missing_occupation"
            elif activity in REST_KINDS:
                purpose = "scheduled_rest"
                if activity == "sleep":
                    supported = any(sample.get("attention")=="sleep" and sample.get("rest_supported") is True and sample.get("presentation")=="life:sleep" for sample in samples)
                    standing = any(sample.get("attention")=="neutral" and sample.get("rest_supported") is False and sample.get("presentation")=="life:rest" for sample in samples)
                    if not supported and not standing: failures.append("scheduled sleep lacks verified seated support or standing-rest fallback")
                elif not any(str(sample.get("presentation","")).startswith("life:") and sample.get("activity_active") is True for sample in samples):
                    failures.append("scheduled rest presentation was not observed")
            else:
                purpose = "unsupported_activity"
                failures.append("undeclared scheduled activity " + activity)
        elif scenario == "approach":
            greeting = any(float(sample.get("greeting_remaining",0))>0 for sample in samples)
            sleeping = initial.get("attention")=="sleep" and initial.get("rest_supported") is True
            if not greeting and not sleeping: failures.append("neither acknowledgement nor verified sleeping was observed")
        elif scenario == "dialogue":
            if not any(sample.get("dialogue_owned") is True for sample in samples): failures.append("dialogue ownership was not observed")
        elif scenario == "interruption":
            if not any(float(sample.get("reaction_time",0))>0 for sample in samples): failures.append("threat interruption was not observed")
        elif scenario == "resume":
            if float(final.get("reaction_time",0))>0 or final.get("dialogue_owned") is True or not observed_activity:
                failures.append("scheduler did not regain activity ownership")
        coverage.append({"scenario":label,"purpose":purpose,"behavior_verified":not failures and scenario!="observe","issues":failures})
        issues.extend(label + ": " + failure for failure in failures)
    return {"mode":mode,"candidate_behavior_accepted":mode=="candidate" and bool(coverage) and all(row["behavior_verified"] for row in coverage),
            "errors":issues if mode=="candidate" else [],
            "limitations":issues if mode=="baseline-observation" else [],"coverage":coverage,
            "visual_acceptance":False,"real_input_acceptance":False}


def compare_performance(candidate: dict, baseline: dict) -> dict:
    errors, comparisons = [], []
    if baseline.get("status") != "pass" or baseline.get("acceptance_mode") != "baseline-observation":
        errors.append("reference is not an explicit passing baseline observation")
    if any(report.get("configuration",{}).get("window_mode") != "background-rendered" for report in (candidate,baseline)):
        errors.append("performance requires matching explicit background-rendered observations")
    for key in ("viewport","zone"):
        if candidate.get(key)!=baseline.get(key): errors.append("performance "+key+" differs from baseline")
    for key in ("quality","renderer","physics_ticks_per_second","window_mode"):
        if candidate.get("configuration",{}).get(key)!=baseline.get("configuration",{}).get(key):
            errors.append("performance configuration differs: "+key)
    anchors=candidate.get("performance_preflight",[])
    if len(anchors)!=3 or anchors!=baseline.get("performance_preflight"):
        errors.append("performance requires three identical reference anchors")
    def groups(report):
        result={json.dumps(anchor,sort_keys=True):[] for anchor in anchors}
        rows=report.get("performance",[])
        if len(rows)!=9: errors.append("performance requires all nine measurement windows")
        for row in rows:
            key=json.dumps(row.get("anchor"),sort_keys=True)
            if key not in result:
                errors.append("performance measurement used an unknown anchor")
                continue
            if not isinstance(row.get("samples"),int) or row["samples"]<1 or any(not _finite_number(row.get(metric)) or row[metric]<=0 for metric in ("p50_ms","p95_ms")):
                errors.append("performance measurement is missing finite positive samples")
                continue
            result[key].append(row)
        for rows in result.values():
            if len(rows)!=3 or {row.get("repeat") for row in rows}!={0,1,2}: errors.append("performance anchor requires three distinct repeats")
        return result
    current,previous=groups(candidate),groups(baseline)
    if not errors:
        for index,anchor in enumerate(anchors):
            key=json.dumps(anchor,sort_keys=True)
            for metric in ("p50_ms","p95_ms"):
                old=statistics.median(row[metric] for row in previous[key])
                new=statistics.median(row[metric] for row in current[key])
                ratio=new/old
                comparisons.append({"anchor":index,"metric":metric,"baseline_median_ms":old,"candidate_median_ms":new,"ratio":ratio})
                if ratio>1.10+1e-9: errors.append(f"anchor {index} {metric} regressed {(ratio-1)*100:.2f}% (maximum 10%)")
    return {"accepted":not errors,"errors":errors,"comparisons":comparisons,"maximum_regression":0.10,"statistic":"median of three repeats per anchor, p50 and p95"}


def observation_state(path: Path) -> dict:
    """Only scalar story flags; never replace quest progress in an observation."""
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(data, dict) or set(data) != {"flags"} or not isinstance(data["flags"], dict):
        raise ValueError("observation state must contain only a flags object")
    for key, value in data["flags"].items():
        if not re.fullmatch(r"[a-z][a-z0-9_]*", key) or not isinstance(value, (str, bool, int, float)):
            raise ValueError("observation flags require valid IDs and scalar values")
        if isinstance(value, float) and not math.isfinite(value):
            raise ValueError("observation flag is nonfinite")
    return data


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def isolated_configuration(original: bytes, profile: str) -> bytes:
    """Isolate saves and make the native window unfocusable before creation."""
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
    text = text[:start] + settings + body.lstrip("\r\n") + text[end:]
    sections = list(re.finditer(r"(?m)^\[display\]\r?$", text))
    if len(sections) > 1:
        raise ValueError("project has duplicate display settings")
    if not sections:
        text = text.rstrip("\r\n") + newline + "[display]" + newline
        sections = list(re.finditer(r"(?m)^\[display\]\r?$", text))
    start = sections[0].end()
    if text[start-1] == "\r": start -= 1
    next_section = re.search(r"(?m)^\[", text[start:])
    end = start + next_section.start() if next_section else len(text)
    body = re.sub(r"(?m)^window/size/(?:no_focus|mode)(?:\.[^=\r\n]+)?=[^\r\n]*(?:\r?\n|$)", "", text[start:end])
    settings = newline + "window/size/no_focus=true" + newline + "window/size/mode=0" + newline
    return (text[:start] + settings + body.lstrip("\r\n") + text[end:]).encode("utf-8")


def git(*arguments: str) -> bytes:
    return subprocess.run(["git", "-C", str(REPOSITORY), *arguments],
                          check=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, timeout=30).stdout


def write_receipt(path: Path, receipt: dict) -> None:
    path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")


def stop_owned_process(process) -> None:
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
    if not godot.is_file() or not CAPTURE.is_file() or not GEOMETRY.is_file() or not CLASS_CACHE.is_file() or not BACKGROUND_LAUNCHER.is_file():
        raise ValueError("Godot, capture/geometry/background scripts, and existing global class cache are required")
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
    command = [str(godot), "--path", str(isolated), "--windowed",
               "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3",
               "--script", str(CAPTURE.resolve()), "--log-file", str(output / "godot.log"),
               "--", "--root-pack=" + root_pack.as_posix(), "--packs=" + packs.as_posix(),
               "--profile=" + profile, "--output=" + output.as_posix(),
               "--background-rendered=true",
               "--viewport=" + args.viewport, "--label=" + args.label,
               "--zone=" + args.zone,
               "--acceptance-mode=" + args.acceptance_mode,
               "--actors=" + args.actors, "--performance=" + str(args.performance).lower(),
               "--geometry-script=" + GEOMETRY.resolve().as_posix(),
               "--scenarios=" + args.scenarios, "--environments=" + args.environments,
               "--duration=" + str(args.duration), "--sample-hz=" + str(args.sample_hz),
               "--idle-duration=" + str(args.idle_duration),
               "--frames-per-scenario=" + str(args.frames_per_scenario)]
    state_receipt = None
    if args.observation_state:
        state_path = args.observation_state.resolve(strict=True)
        state_data = observation_state(state_path)
        frozen_state = isolated / "observation_state.json"
        frozen_state.write_text(json.dumps(state_data, indent=2) + "\n", encoding="utf-8")
        command.append("--observation-state=" + frozen_state.as_posix())
        state_receipt = {"path":str(frozen_state), "sha256":sha256(frozen_state), "data":state_data}
    reference = args.reference_report.resolve(strict=True) if args.reference_report else None
    if reference:
        prior = json.loads(reference.read_text(encoding="utf-8"))
        if not isinstance(prior, dict) or prior.get("status") != "pass" or prior.get("acceptance_mode") != "baseline-observation" or len(prior.get("performance_preflight", [])) != 3:
            raise ValueError("reference must be an explicit passing baseline observation with all three performance anchors")
        command.append("--reference-report=" + reference.as_posix())
    receipt = {
        "schema_version": 1, "status": "prepared", "kind": "native_living_cast_runner",
        "acceptance_mode":args.acceptance_mode,"performance_requested":args.performance,
        "git_commit": commit, "isolated_project": str(isolated), "profile": profile,
        "expected_user_data_dir": str(user_data), "output": str(output),
        "source_project_sha256": hashlib.sha256(original).hexdigest(),
        "isolated_project_sha256": sha256(isolated / "project.godot"),
        "global_class_cache_sha256": sha256(copied_cache), "capture_script_sha256": sha256(CAPTURE),
        "geometry_script_sha256": sha256(GEOMETRY),
        "background_launcher_sha256": sha256(BACKGROUND_LAUNCHER),
        "window_mode":"background-rendered",
        "root_pack": {"path": str(root_pack), "sha256": sha256(root_pack)},
        "secondary_packs": [{"path": str(path), "bytes": path.stat().st_size,
                             "sha256": sha256(path)} for path in pack_files],
        "command": command, "timeout_seconds": args.timeout,
        "scenario_configuration": {"actors":args.actors.split(","), "scenarios":args.scenarios.split(","),
                                   "acceptance_mode":args.acceptance_mode,
                                   "zone":args.zone,
                                   "environments":args.environments.split(","), "duration":args.duration,
                                   "idle_duration":args.idle_duration,
                                   "sample_hz":args.sample_hz, "frames_per_scenario":args.frames_per_scenario},
        "reference_report": {"path":str(reference), "sha256":sha256(reference)} if reference else None,
        "observation_state":state_receipt,
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
        (BACKGROUND_LAUNCHER, receipt["background_launcher_sha256"]),
        (Path(receipt["root_pack"]["path"]), receipt["root_pack"]["sha256"]),
    ]
    checks.extend((Path(pack["path"]), pack["sha256"]) for pack in receipt["secondary_packs"])
    if receipt.get("reference_report"):
        checks.append((Path(receipt["reference_report"]["path"]), receipt["reference_report"]["sha256"]))
    if receipt.get("observation_state"):
        checks.append((Path(receipt["observation_state"]["path"]), receipt["observation_state"]["sha256"]))
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
        if receipt.get("window_mode") != "background-rendered":
            raise ValueError("native capture requires an owned background-rendered desktop")
        verify_prepared_inputs(receipt)
        with (output / "stdout.log").open("wb") as stdout:
            process = spawn_background(receipt["command"], cwd=receipt["isolated_project"], stdout=stdout)
            receipt["owned_pid"] = process.pid
            receipt["background_desktop"] = process.desktop_receipt
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
        background = report.get("background_rendered", {})
        if background.get("desktop") != process.desktop_receipt["desktop"] or background.get("no_focus") is not True or background.get("headless") is not False:
            failures.append("capture report did not confirm the requested background renderer")
        expected = receipt["scenario_configuration"]
        requested = {(actor, environment, scenario) for actor in expected["actors"]
                     for environment in expected["environments"] for scenario in expected["scenarios"]}
        actual = {(row.get("actor"), row.get("environment"), row.get("scenario")) for row in report.get("scenarios", [])}
        if requested != actual:
            failures.append("capture report does not cover the exact requested scenario matrix")
        mode = expected["acceptance_mode"]
        if report.get("acceptance_mode") != mode:
            failures.append("capture acceptance mode differs from its frozen request")
        receipt["behavior_validation"] = validate_behavior(report, mode)
        failures.extend(receipt["behavior_validation"]["errors"])
        receipt["limitations"] = receipt["behavior_validation"]["limitations"]
        if receipt.get("reference_report"):
            baseline=json.loads(Path(receipt["reference_report"]["path"]).read_text(encoding="utf-8"))
            receipt["performance_validation"] = compare_performance(report,baseline)
            failures.extend(receipt["performance_validation"]["errors"])
        if report.get("zone", "greyfen") != expected.get("zone", "greyfen"):
            failures.append("capture ran in a different region")
        if any(frame.get("validation") or not frame.get("camera", {}).get("current") for frame in report.get("frames", [])):
            failures.append("a frame failed visual/projection validation or fixture camera ownership")
        if any(not row.get("frames") or not row.get("samples") for row in report.get("scenarios", [])):
            failures.append("a requested scenario produced no frames or telemetry")
        if any(len(row.get("frames", [])) != expected["frames_per_scenario"] for row in report.get("scenarios", [])):
            failures.append("a requested sequence is incomplete")
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
            try:
                process.close()
            except (OSError, RuntimeError) as error:
                receipt["status"] = "fail"
                receipt.setdefault("failures", []).append(f"owned desktop cleanup failed: {error}")
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
    parser.add_argument("--background-rendered", action="store_true", default=True,
                        help="Required/default: native renderer on an owned non-input Windows desktop")
    parser.add_argument("--viewport", choices=("desktop", "touch"), default="desktop")
    parser.add_argument("--label", default="candidate")
    parser.add_argument("--acceptance-mode", choices=("candidate","baseline-observation"), default="candidate",
                        help="Baseline observation records missing performances as limitations; it never accepts candidate behavior")
    parser.add_argument("--actors", default="anwen,tor,mira,rook")
    parser.add_argument("--zone", choices=sorted(CAPTURE_ZONES), default="greyfen")
    parser.add_argument("--observation-state", type=Path, help="Explicit fixture-only scalar flags, frozen and recorded; does not claim earned progress")
    parser.add_argument("--performance", action="store_true")
    parser.add_argument("--scenarios", default="observe", help="Comma-separated observe,idle,work,approach,dialogue,interruption,resume")
    parser.add_argument("--environments", default="day", help="Comma-separated day,night,rain")
    parser.add_argument("--full", action="store_true", help="All six lifecycle scenarios in day, night and rain")
    parser.add_argument("--duration", type=float, default=4.4, help="Seconds observed per scenario")
    parser.add_argument("--idle-duration", type=float, default=16.4, help="Allow both retained six/eight-second idle variations to complete")
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
    if not math.isfinite(args.idle_duration) or not 1 <= args.idle_duration <= 60:
        parser.error("--idle-duration must be between 1 and 60 seconds")
    if not math.isfinite(args.sample_hz) or not 1 <= args.sample_hz <= 60:
        parser.error("--sample-hz must be between 1 and 60")
    if not 1 <= args.frames_per_scenario <= 600:
        parser.error("--frames-per-scenario must be between 1 and 600")
    if args.reference_report and not args.performance:
        parser.error("--reference-report requires --performance")
    if args.performance and args.acceptance_mode == "candidate" and not args.reference_report:
        parser.error("candidate performance acceptance requires --reference-report; use baseline-observation to collect a baseline")
    if args.performance and args.zone != "greyfen":
        parser.error("the matched performance anchors are defined only for Greyfen")
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
