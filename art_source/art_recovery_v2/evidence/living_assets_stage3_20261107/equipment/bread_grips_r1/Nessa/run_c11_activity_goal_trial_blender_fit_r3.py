"""Repeat C11 geometry fitting with JSON-safe native palm telemetry."""
import argparse
import json
import os
from pathlib import Path
import re

from run_c11_activity_goal_trial_blender_fit_r2 import (BLENDER, NATIVE, OUT as PREVIOUS_FIT, PRIOR, PROPS, ROOT,
    MOTION, PREVIOUS, accepted_trial, launch_owned, load_props, read, require, seconds_left, sha, utc_deadline)

OUT = MOTION / "c11_activity_goal_trial_blender_fit_r3"
PREP = MOTION / "c11_activity_goal_trial_fit_retry_preparation_r3.json"
PALM_BEFORE = b'"palm": list(best["contact"] / scale)'
PALM_AFTER = b'"palm": [float(value) for value in best["contact"] / scale]'


def stage_tools(staged, prior):
    staged.mkdir()
    results = {}
    for name, expected in prior["staged_source_sha256"].items():
        path = Path(name).resolve()
        require(path.parent == (PRIOR / "tools").resolve() and sha(path) == expected, "Retained trial tool changed")
        data = path.read_bytes()
        if path.name == "probe_c11_activity_fits.py":
            require(data.count(PALM_BEFORE) == 1, "Expected one palm telemetry conversion")
            data = data.replace(PALM_BEFORE, PALM_AFTER)
        target = staged / path.name
        target.write_bytes(data)
        results[str(target)] = sha(target)
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--deadline-utc", type=utc_deadline, required=True)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    frozen = read(PREP)
    require(not OUT.exists(), "A fresh isolated fit retry directory is required")
    require(all(sha(ROOT / name) == expected for name, expected in frozen["source_sha256"].items()), "Fit retry freeze changed")
    failed = read(PREVIOUS_FIT / "receipt.json")
    require(failed["completed"] is False and failed["process"]["exit_code"] == 1 and
            failed["process"]["owned_tree_exited"] is True and not failed["process"]["timed_out"], "Unexpected previous retry result")
    require("TypeError: Object of type float32 is not JSON serializable" in (PREVIOUS_FIT / "fit.log").read_text(),
            "Retry only applies to the observed telemetry error")
    checkpoint = read(PREVIOUS_FIT / "fit/receipt.json")
    require(checkpoint["fits"]["bread"]["verified_frames"] == 720 and "supply" not in checkpoint["fits"],
            "Unexpected previous durable evidence")
    prior = read(PRIOR / "receipt.json")
    proof = PRIOR / "import_fidelity.json"
    require(prior["runs"][0]["passed"] is True and sha(proof) == failed["retained_inspection_sha256"] and
            read(proof)["verified"] is True, "Retained Blender trial inspection is required")
    carrier, native = accepted_trial()
    require(sha(NATIVE) == prior["native_receipt_sha256"] and sha(carrier) == prior["trial_carrier_receipt_sha256"],
            "Retained inspection refers to a different trial")
    _, props = load_props(ROOT, PROPS)
    baseline = read(PREVIOUS)
    require(baseline["accepted"] is True and sha(BLENDER) == baseline["blender_sha256"], "Blender binary changed")
    require(seconds_left(args.deadline_utc) >= 340, "Need 340 seconds for fit and shutdown")
    print(json.dumps({"source_ready": True, "execute": args.execute, "retained_native_receipt_sha256": native["trial_receipt_sha256"],
                      "retained_prior_bread_scene_sha256": frozen["retained_previous_bread_scene_sha256"]}), flush=True)
    if not args.execute: return 0

    OUT.mkdir()
    staged = OUT / "tools"
    staged_hashes = stage_tools(staged, prior)
    fit_output = OUT / "fit"
    log = OUT / "fit.log"
    command = [str(BLENDER), "--background", "--factory-startup", "--threads", "2", "--python-exit-code", "1",
               "--python", str(staged / "probe_c11_activity_fits.py"), "--", "--root", str(ROOT),
               "--activity-receipt", str(carrier), "--blender-proof", str(proof), "--props-proof", str(PROPS),
               "--output", str(fit_output), "--work-seconds", "300"]
    report = {"scope": "C11 source fitting and editable scene evidence only", "completed": False,
              "grip_verified": False, "runtime_output": False, "visual_accepted": False,
              "geometry_logic_changed": False, "native_or_inspection_repeated": False,
              "source_sha256": frozen["source_sha256"], "staged_source_sha256": staged_hashes,
              "command": command, "log": str(log)}
    try:
        keys = ("BLENDER_USER_CONFIG", "BLENDER_USER_SCRIPTS", "BLENDER_USER_DATAFILES", "PYTHONDONTWRITEBYTECODE")
        previous_env = {key: os.environ.get(key) for key in keys}
        try:
            for key in keys[:-1]:
                directory = OUT / "profiles" / key.lower()
                directory.mkdir(parents=True)
                os.environ[key] = str(directory)
            os.environ[keys[-1]] = "1"
            require(not fit_output.exists() and seconds_left(args.deadline_utc) >= 335, "No fresh fitting output or safe time margin")
            process = launch_owned(command, log, 325)
        finally:
            for key, value in previous_env.items():
                if value is None: os.environ.pop(key, None)
                else: os.environ[key] = value
        report["process"] = process
        require(process.get("passed") and process.get("owned_tree_exited"), "Blender fit process did not exit cleanly")
        require(not re.search(r"Traceback|^Error:|^ERROR:|Python script failed", log.read_text(encoding="utf-8", errors="replace"), re.MULTILINE),
                "Blender fit reported errors")
        fit_receipt = fit_output / "receipt.json"
        fit = read(fit_receipt)
        require(fit["status"] == "source_probe_complete" and fit["grip_verified"] is False, "Fitting stage did not complete")
        require(set(fit["fits"]) == {"bread", "supply"}, "Both props must have durable source results")
        result = {}
        for style, frames in (("bread", 839), ("supply", 422)):
            row = fit["fits"][style]
            require(row["expected_frames"] == frames, "Original full-cycle sample gate changed")
            result[style] = {key: row[key] for key in ("verified_frames", "expected_frames", "surface_clearance_verified",
                                                        "closed_component_containment_verified", "proposal")}
            scene = row.get("editable_scene")
            if scene:
                path = (fit_output / scene["path"]).resolve()
                require(path.parent == fit_output.resolve() and sha(path) == scene["sha256"], "Editable scene proof changed")
                require(row["verified_frames"] == frames and row["surface_clearance_verified"] and
                        row["closed_component_containment_verified"] and row["proposal"]["maximum_contact_error_m"] <= .001,
                        "Editable proposal lacks complete contact and clearance proof")
                result[style]["editable_scene"] = scene
        require(all(sha(Path(name)) == expected for name, expected in {**props, **staged_hashes}.items()), "Fitting input changed")
        require(all(sha(ROOT / name) == expected for name, expected in frozen["source_sha256"].items()), "Preserved evidence changed")
        accepted_trial()
        report.update(completed=True, fitting_receipt_sha256=sha(fit_receipt), fits=result)
    except (ValueError, OSError, KeyError) as error:
        report["failure"] = str(error)
    (OUT / "receipt.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in ("completed", "fits", "failure", "process") if key in report}), flush=True)
    return 0 if report["completed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
