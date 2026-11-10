"""Run one C01 fit with the retained r1 measurement and corrected receipt output."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys

import run_anwen_activity_fit as r1

CAPS = {"bread": (330, 355, 370), "supply": (220, 245, 260)}
PROBE = r1.TOOLS / "probe_anwen_activity_fits.py"
FAILED = r1.OUTPUT
CHECKPOINT = {"blender.log", "receipt.json", "fit/receipt.json", "fit/C01_bread_fit_proposal.blend"}
OLD_PALM = '"palm": list(best["contact"] / scale)'
NEW_PALM = '"palm": [float(component) for component in best["contact"] / scale]'


def replace(source, old, new):
    r1.require(source.count(old) == 1, "Original C01 probe no longer matches the reviewed retry seam")
    return source.replace(old, new)


def probe_source(text):
    text = replace(text, 'sys.path.insert(0, str(Path(__file__).resolve().parent))',
                   'sys.path.insert(0, sys.argv[sys.argv.index("--root") + 1] + "/art_source/art_recovery_v2/tools")')
    text = replace(text, 'for style, phases in FIT_CLIPS.items():', 'for style in (args.style,):\n            phases = FIT_CLIPS[style]')
    text = replace(text, OLD_PALM, NEW_PALM)
    text = replace(text, '            old = set(scene.objects)', '            record()\n            old = set(scene.objects)')
    text = replace(text, '    parser.add_argument("--work-seconds",',
                   '    parser.add_argument("--style", choices=FIT_CLIPS, required=True)\n    parser.add_argument("--work-seconds",')
    return text.encode("utf-8")


def failed_trial():
    evidence = {name: FAILED / name for name in CHECKPOINT}
    proof, outer = r1.read(evidence["fit/receipt.json"]), r1.read(evidence["receipt.json"])
    process = outer["process"]
    r1.require(process["passed"] is False and process["timed_out"] is False and process["owned_tree_exited"] is True and
               process["active_processes_after_cleanup"] == 0 and outer["source_probe_complete"] is False and
               proof["fits"]["bread"]["verified_frames"] == 720 and proof["fits"]["bread"]["expected_frames"] == 839 and
               proof["fits"]["bread"]["proposal"] is None, "Expected preserved incomplete C01 r1 measurement")
    log = evidence["blender.log"].read_text(encoding="utf-8")
    r1.require('Saved as "C01_bread_fit_proposal.blend"' in log and 'TypeError: Object of type float32 is not JSON serializable' in log,
               "Expected exact C01 r1 receipt serialization failure")
    r1.require(outer["source_sha256"][str(PROBE)] == r1.digest(PROBE) and
               outer["source_sha256"][str(Path(r1.__file__).resolve())] == r1.digest(r1.__file__), "Original C01 r1 sources changed")
    return tuple(evidence.values())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--style", choices=r1.FIT_CLIPS, required=True)
    parser.add_argument("--deadline-utc")
    parser.add_argument("--source-set-sha256")
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    style = args.style
    work_seconds, process_seconds, minimum = CAPS[style]
    output = r1.MOTION / ("anwen_baseline_fit_r2_" + style)
    r1.require(output.resolve().is_relative_to(r1.MOTION) and not output.exists(), "Fresh C01 r2 evidence directory required")
    creatures = r1.ROOT / ".verification/creatures"
    sys.path.insert(0, str(creatures))
    from run_candidate_serial import launch_owned, seconds_left, utc_deadline

    native, queue_paths = r1.native_receipt(r1.NATIVE_QUEUE)
    paths, _, staff, clips, props, helpers, frozen = r1.exact_inputs(r1.ROOT, native, r1.BLENDER_IMPORT, r1.PROPS)
    r1.require(str(r1.BLENDER) in frozen and len(staff["rows"]) == 714, "Accepted C01 import tool or retained staff identity changed")
    carrier, manifest, _ = props[style]
    points, faces, anchors, plans, _ = r1.retained_prop_geometry(carrier, manifest)
    components, degenerate = helpers.component_topology(points, faces, [()] * len(points))
    inventory = {"visuals": list(plans), "vertices": len(points), "triangles": len(faces), "primary_anchors": len(anchors),
                 "closed_components": sum(c["closed"] for c in components), "degenerate_triangles": degenerate}
    provenance = (*queue_paths, PROBE, *failed_trial(), Path(__file__), Path(r1.__file__), Path(sys.executable),
                  r1.MOTION / "test_anwen_fit_retry_serialization.py", r1.MOTION / "run_anwen_blender_import.py",
                  creatures / "run_candidate_serial.py", creatures / "run_candidate_authoring.py")
    frozen.update({str(path.resolve()): r1.digest(path) for path in provenance})
    staged = output / "probe_anwen_activity_fits_r2.py"
    source = probe_source(PROBE.read_text(encoding="utf-8"))
    compile(source, str(staged), "exec")
    frozen[str(staged)] = hashlib.sha256(source).hexdigest()
    fingerprint = hashlib.sha256(json.dumps(frozen, sort_keys=True).encode()).hexdigest()
    fit_output = output / "fit"
    command = [str(r1.BLENDER), "--background", "--factory-startup", "--threads", "2", "--python-exit-code", "1", "--python", str(staged),
               "--", "--root", str(r1.ROOT), "--activity-receipt", str(native), "--blender-receipt", str(r1.BLENDER_IMPORT),
               "--props-receipt", str(r1.PROPS), "--output", str(fit_output), "--style", style, "--work-seconds", str(work_seconds)]
    frames = {clip: clips[clip]["frames"] for clip in r1.FIT_CLIPS[style]}
    report = {"asset": "C01", "style": style, "source_ready": True, "execute": args.execute, "source_set_sha256": fingerprint,
              "source_sha256": frozen, "native_carrier": str(paths["carrier"]), "frames": frames, "prop_inventory": inventory,
              "command": command, "deadline_utc": args.deadline_utc, "work_seconds": work_seconds, "process_seconds": process_seconds,
              "minimum_window_seconds": minimum, "source_probe_complete": False, "proposal_styles": [], "grip_verified": False,
              "body_clearance_verified": False, "visual_accepted": False, "runtime_output": False}
    print(json.dumps(report), flush=True)
    if not args.execute:
        return 0
    r1.require(args.source_set_sha256 == fingerprint and args.deadline_utc is not None,
               "Execute requires the exact dry-preflight source set SHA-256 and a UTC deadline")
    deadline = utc_deadline(args.deadline_utc)
    r1.require(seconds_left(deadline) >= minimum, "UTC boundary leaves too little time for the owned C01 r2 job")
    output.mkdir()
    with staged.open("xb") as stream:
        stream.write(source)
    for key in ("BLENDER_USER_CONFIG", "BLENDER_USER_SCRIPTS", "BLENDER_USER_DATAFILES"):
        profile = output / key.lower()
        profile.mkdir()
        os.environ[key] = str(profile)
    os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
    log = output / "blender.log"
    report["process"] = launch_owned(command, log, process_seconds)
    errors = [line for line in log.read_text(encoding="utf-8", errors="replace").splitlines() if re.search(r"Traceback|^Error:|^ERROR:", line)]
    report["errors"] = errors
    report["source_unchanged"] = all(Path(path).is_file() and r1.digest(path) == expected for path, expected in frozen.items())
    if report["process"]["passed"] and report["process"]["owned_tree_exited"] and report["source_unchanged"] and not errors:
        try:
            proof_path = fit_output / "receipt.json"
            proof = r1.read(proof_path)
            r1.require(proof["asset"] == "C01" and proof["status"] == "source_probe_complete" and not proof["errors"] and
                       set(proof["fits"]) == {style}, "Exact C01 r2 style proof did not complete")
            r1.require(all(proof[key] is False for key in ("grip_verified", "body_clearance_verified", "visual_accepted", "runtime_output")),
                       "C01 r2 trial asserted untested scope")
            fit = proof["fits"][style]
            if fit["proposal"] is not None:
                r1.require(fit["verified_frames"] == fit["expected_frames"] == sum(frames.values()) and
                           fit["surface_clearance_verified"] and fit["closed_component_containment_verified"] and
                           fit["proposal"]["bone"] == "hand_l" and 0 <= fit["proposal"]["maximum_contact_error_m"] <= 0.001,
                           "C01 r2 proposal missed sample, contact or clearance requirements")
                scene = fit_output / ("C01_" + style + "_fit_proposal.blend")
                r1.require(fit["editable_scene"]["path"] == scene.name and fit["editable_scene"]["sha256"] == r1.digest(scene),
                           "C01 r2 editable proposal bytes changed")
                report["proposal_styles"].append(style)
            report["source_probe_complete"] = True
            report["fit_receipt_sha256"] = r1.digest(proof_path)
        except (KeyError, OSError, ValueError) as error:
            errors.append(str(error))
    with (output / "receipt.json").open("x", encoding="utf-8") as stream:
        json.dump(report, stream, indent=2, allow_nan=False)
        stream.write("\n")
    print(json.dumps({key: report[key] for key in ("source_probe_complete", "proposal_styles", "process", "errors")}), flush=True)
    return 0 if report["source_probe_complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
