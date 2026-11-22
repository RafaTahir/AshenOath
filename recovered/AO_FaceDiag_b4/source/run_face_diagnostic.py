"""One authorized rendered facial diagnostic on the frozen published candidate."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
QA = HERE.parent
NATIVE = QA / "native"
PROJECT = Path("D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns")
OUTPUT = QA / "single_runtime_check"
BUILD = "combined-loading-cast-20261111-ba93115-r6"
CASE = "lower_face_diagnostic"
TIMEOUT = 720

sys.path.insert(0, str(PROJECT / "tools"))
import run_community_acceptance as community
from background_native_capture import spawn_background


def prepare(script: Path, harness: Path) -> Path:
    args = argparse.Namespace(
        case=CASE, seed_save=None, root_pack=NATIVE / "index.pck",
        packs=NATIVE / "packs", release_manifest=NATIVE / "release_manifest.json",
        class_cache=NATIVE / "global_script_class_cache.cfg", godot=community.GODOT,
        output=OUTPUT, viewport="desktop", input_mode="keyboard_mouse", timeout=TIMEOUT,
    )
    receipt, path = community.prepare(
        args, script_source=script, seed_contract={"suite": CASE, "expected_work": []},
        extra_files={"tools/verify_community_world_input.gd": harness.read_bytes()},
        allow_no_seed=True, runner_sources=[Path(__file__).resolve(), script, harness],
    )
    if receipt["candidate_closure"]["build_id"] != BUILD:
        raise ValueError("The check must use the exact currently published build")
    receipt.update(diagnostic_only=True, authorized_engine_processes=1,
                   diagnostic_scope="Kael, Anwen and Tor: normal facial evaluation versus disabled/rest facial controls; single native process")
    community.write(path, receipt)
    return path


def run() -> int:
    path = OUTPUT / "runner.json"
    receipt = community.load_prepared(path)
    if not receipt.get("diagnostic_only") or receipt["candidate_closure"]["build_id"] != BUILD:
        raise ValueError("Exact never-started facial diagnostic receipt is required")
    process = None
    receipt["status"] = "running"
    community.write(path, receipt)
    try:
        with (OUTPUT / "stdout.log").open("wb") as log:
            process = spawn_background(receipt["command"], cwd=receipt["isolated_project"],
                                       env={**os.environ, **receipt["environment"]}, stdout=log)
            receipt["owned_pid"] = process.pid
            receipt["desktop"] = process.desktop_receipt.copy()
            community.write(path, receipt)
            receipt["exit_code"] = process.wait(timeout=receipt["timeout_seconds"])
        community.verify_inputs(receipt)
        diagnostic_path = OUTPUT / "report.json"
        diagnostic = json.loads(diagnostic_path.read_bytes())
        errors = [line for line in (OUTPUT / "stdout.log").read_text(encoding="utf-8", errors="replace").splitlines()
                  if line.startswith(("ERROR:", "SCRIPT ERROR:")) or "ObjectDB instances leaked" in line]
        receipt.update(status="diagnosis_collected" if receipt["exit_code"] == 0 and diagnostic.get("status") == "pass" else "diagnostic_incomplete",
                       diagnostic_sha256=community.sha256(diagnostic_path), engine_errors=errors,
                       diagnostic_outcome=diagnostic.get("outcome", diagnostic.get("status", "see_diagnostic")))
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        receipt.update(status="diagnostic_incomplete", failure=str(error))
    finally:
        if process is not None:
            try:
                community.stop_owned_process(process)
                process.close()
                receipt["desktop"] = process.desktop_receipt.copy()
            except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
                receipt.update(status="diagnostic_incomplete", cleanup_error=str(error))
        community.write(path, receipt)
    print(json.dumps({key: receipt[key] for key in ("status", "diagnostic_outcome", "failure", "engine_errors") if key in receipt}), flush=True)
    return 0 if receipt["status"] == "diagnosis_collected" else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--prepare-only", action="store_true")
    mode.add_argument("--execute-prepared", action="store_true")
    parser.add_argument("--script", type=Path)
    parser.add_argument("--harness", type=Path)
    args = parser.parse_args()
    if args.prepare_only:
        if args.script is None or args.harness is None:
            parser.error("prepare requires --script and --harness")
        print(json.dumps({"status": "prepared", "receipt": str(prepare(args.script, args.harness)), "engine_started": False}), flush=True)
    else:
        raise SystemExit(run())
