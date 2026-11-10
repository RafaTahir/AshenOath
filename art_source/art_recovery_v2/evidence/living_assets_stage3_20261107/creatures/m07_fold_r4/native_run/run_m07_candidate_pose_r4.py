"""Run the maintained native pose gates against the exact private M07 r4 candidate."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys

import run_candidate_poses as poses

ROOT, GAME, ENGINE = poses.ROOT, poses.GAME, poses.ENGINE
MOTION = Path(__file__).resolve().parent
CREATURES = ROOT / ".verification/creatures"
ASSET = "M07"
SOURCE_PLAN = CREATURES / "M07/revised_source_r4_readiness.json"
OUT = MOTION / "m07_candidate_pose_r4"
FIXTURE = GAME / poses.SOURCE_NAMES[0]
CONTRACT = GAME / poses.SOURCE_NAMES[1]
DEFAULT_FOLDER = ('\tvar folder := repository.path_join('
                  '"art_source/art_recovery_v2/models/living_assets_stage3_20261107/creatures").path_join(asset)')
PARSE_SECONDS = 45
NATIVE_SECONDS = 90
MINIMUM_SECONDS = 155

sys.path.insert(0, str(CREATURES))
from run_candidate_serial import launch_owned, seconds_left, utc_deadline


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def replace_exact(text, old, new, count=1):
    require(text.count(old) == count, "Maintained source no longer has the reviewed candidate-folder insertion point")
    return text.replace(old, new)


def scoped_scripts(fixture, contract):
    fixture = replace_exact(fixture, 'preload("res://tools/creature_ambient_source_contract.gd")',
                            'preload("candidate_source_contract.gd")')
    fixture = replace_exact(fixture, DEFAULT_FOLDER, DEFAULT_FOLDER + '''
\tvar candidate_folder := str(options.get("candidate-folder", "")).simplify_path() if options.has("candidate-folder") else ""
\tif not candidate_folder.is_empty():
\t\tvar private_root := repository.path_join(".verification/creatures/M07/revised_source_r4")
\t\tif asset != "M07" or not candidate_folder.is_absolute_path() or not candidate_folder.begins_with(private_root + "/") or candidate_folder.get_file() != asset:
\t\t\t_check(false, "M07 override must identify its isolated r4 candidate folder")
\t\t\t_finish(null)
\t\t\treturn
\t\tfolder = candidate_folder''')
    fixture = replace_exact(fixture, "Contract.apply_candidate(visual, asset)",
                            "Contract.apply_candidate(visual, asset, candidate_folder)")
    contract = replace_exact(contract, "apply_candidate(visual: Node3D, asset: String)",
                             'apply_candidate(visual: Node3D, asset: String, candidate_folder: String = "")')
    contract = replace_exact(contract, '_apply_to(visual, source, folder.path_join(asset + "_living_candidate.glb"))',
                             '_apply_to(visual, source, folder.path_join(asset + "_living_candidate.glb"), candidate_folder)')
    contract = replace_exact(contract, "_apply_to(visual: Node3D, source: String, bytes_path: String)",
                             '_apply_to(visual: Node3D, source: String, bytes_path: String, candidate_folder: String = "")')
    contract = replace_exact(contract, DEFAULT_FOLDER, DEFAULT_FOLDER +
                             "\n\tif not candidate_folder.is_empty(): folder = candidate_folder", count=2)
    return {"candidate_pose.gd": fixture.encode("utf-8"), "candidate_source_contract.gd": contract.encode("utf-8")}


def candidate_inputs(folder):
    plan = read(SOURCE_PLAN)
    private = (CREATURES / "M07/revised_source_r4").resolve(strict=True)
    require(folder.is_relative_to(private) and folder == Path(plan["folder"]).resolve(strict=True),
            "Explicit folder must identify the exact private M07 r4 source plan")
    receipt_path = CREATURES / "M07/revised_source_r4_owned/receipt.json"
    require(receipt_path.parent == Path(plan["evidence"]).resolve(strict=True), "M07 source receipt escaped the planned evidence folder")
    source_receipt = read(receipt_path)
    runs = source_receipt["runs"]
    require(source_receipt["asset"] == ASSET and source_receipt["passed"] is True and source_receipt["sources_unchanged"] is True and
            source_receipt["production_overwritten"] is False and [row["stage"] for row in runs] == ["blender_author", "source_contract"] and
            all(row["passed"] is True and row["owned_tree_exited"] is True and row["active_processes_after_cleanup"] == 0 for row in runs),
            "Completed owned M07 source proof is required")
    emitted = {Path(row["path"]).resolve(strict=True): row for row in source_receipt["outputs"]}
    require(len(emitted) == len(source_receipt["outputs"]) and all(path.is_relative_to(folder) for path in emitted),
            "M07 source proof includes duplicate or escaped output paths")
    files = [(folder / name).resolve(strict=True) for name in
             ("M07_living_candidate.glb", "M07_retained_input.glb", "authoring.json", "source_contract.json")]
    authored, contract = (read(path) for path in files[2:])
    require(authored["asset"] == contract["asset"] == ASSET and contract["status"] == "source_contract_pass" and
            contract["required_morphs"] == [], "M07 source receipts must describe a verified pose-only candidate")
    require(poses.sha(files[0]) == authored["candidate_sha256"] == contract["candidate_sha256"] == source_receipt["candidate_sha256"] and
            poses.sha(files[1]) == authored["production_sha256"] == contract["retained_source_sha256"],
            "Source receipts do not identify the exact candidate and retained bytes")
    production = GAME / authored["production_resource"].removeprefix("res://")
    require(production.resolve().is_relative_to(GAME) and poses.sha(production) == contract["retained_source_sha256"],
            "Current production source differs from the exact retained reference")
    for uri, expected in contract["retained_external_source_hashes"].items():
        external = (folder / uri).resolve(strict=True)
        require(external.is_relative_to(folder) and poses.sha(external) == expected, "Escaped or changed retained external input: " + uri)
        files.append(external)
    require(all(path in emitted and path.stat().st_size == emitted[path]["bytes"] and poses.sha(path) == emitted[path]["sha256"] for path in files),
            "An exact source proof output changed")
    return files, authored, (production, SOURCE_PLAN, receipt_path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-folder", required=True, type=Path)
    parser.add_argument("--deadline-utc", type=utc_deadline)
    parser.add_argument("--source-set-sha256")
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    require(OUT.resolve().is_relative_to(MOTION) and not OUT.exists(), "Fresh native evidence directory required")
    folder = args.candidate_folder.resolve(strict=True)
    files, authored, provenance = candidate_inputs(folder)
    sources = [*files, *provenance, *(GAME / name for name in poses.SOURCE_NAMES), *(GAME / "scripts").rglob("*.gd"),
               GAME / "project.godot", GAME / ".godot/global_script_class_cache.cfg", Path(__file__),
               Path(poses.__file__), MOTION / "run_candidate_morph_allowlist.py", poses.ENGINE_HELPER,
               CREATURES / "run_candidate_serial.py", CREATURES / "run_candidate_authoring.py", Path(sys.executable)]
    frozen = {str(path.resolve()): poses.sha(path) for path in sources}
    scripts = scoped_scripts(FIXTURE.read_text(encoding="utf-8"), CONTRACT.read_text(encoding="utf-8"))
    generated = {name: hashlib.sha256(content).hexdigest() for name, content in scripts.items()}
    identity = poses.capture_identity(ENGINE)
    fingerprint = hashlib.sha256(json.dumps([frozen, generated, identity], sort_keys=True).encode()).hexdigest()
    fixture = OUT / "candidate_pose.gd"
    native = OUT / "native.json"
    command = [str(ENGINE), "--headless", "--path", str(GAME), "--script", str(fixture)]
    jobs = (("parse", ["--check-only"], PARSE_SECONDS),
            ("native", ["--", "--asset=M07", "--candidate-folder=" + folder.as_posix(), "--output=" + str(native)], NATIVE_SECONDS))
    summary = {"asset": ASSET, "source_ready": True, "execute": args.execute, "source_set_sha256": fingerprint,
               "generated_sha256": generated, "candidate_folder": str(folder), "candidate_sha256": frozen[str(files[0])],
               "input_count": len(frozen), "minimum_window_seconds": MINIMUM_SECONDS, "output": str(OUT),
               "jobs": [{"name": name, "command": command + flags, "cap_seconds": cap} for name, flags, cap in jobs]}
    print(json.dumps(summary), flush=True)
    if not args.execute:
        return 0
    require(args.source_set_sha256 == fingerprint, "Execute requires the exact dry-preflight source-set SHA-256")
    require(args.deadline_utc is not None and seconds_left(args.deadline_utc) >= MINIMUM_SECONDS,
            "UTC boundary leaves insufficient time for both owned jobs and cleanup")
    OUT.mkdir()
    for name, content in scripts.items():
        with (OUT / name).open("xb") as stream:
            stream.write(content)
    all_hashes = {**frozen, **{str(OUT / name): expected for name, expected in generated.items()}}
    report = {**summary, "input_sha256": all_hashes, "engine_identity": identity, "results": [], "accepted": False,
              "candidate_only": True, "production_source_changed": False, "visual_accepted": False, "attack_profiles_recalibrated": False}

    def unchanged():
        return (all(Path(path).is_file() and poses.sha(Path(path)) == expected for path, expected in all_hashes.items()) and
                poses.capture_identity(ENGINE) == identity)

    try:
        for job in summary["jobs"]:
            name, cap = job["name"], job["cap_seconds"]
            require(seconds_left(args.deadline_utc) >= cap + 10, "UTC boundary reached before " + name)
            require(unchanged(), "Frozen native inputs changed before " + name)
            previous = {key: os.environ.get(key) for key in ("APPDATA", "LOCALAPPDATA")}
            log = OUT / (name + ".log")
            try:
                for key in previous:
                    profile = OUT / name / key.lower()
                    profile.mkdir(parents=True)
                    os.environ[key] = str(profile)
                run = launch_owned(job["command"], log, cap)
            finally:
                for key, value in previous.items():
                    if value is None:
                        os.environ.pop(key, None)
                    else:
                        os.environ[key] = value
            report["results"].append({**job, **run, "log": str(log)})
            require(run["passed"] and run["owned_tree_exited"], "Owned native job failed: " + name)
            log_text = log.read_text(encoding="utf-8", errors="replace")
            require(not re.search(r"SCRIPT ERROR:|^ERROR:|ObjectDB instances leaked|resources still in use|: FAIL", log_text, re.MULTILINE),
                    "Native job log contains errors: " + name)
            require(unchanged(), "Frozen native inputs changed after " + name)
            if name == "native":
                require("CREATURE CANDIDATE POSES: PASS" in log_text, "Native pose PASS marker missing")
                proof = read(native)
                require(Path(proof["source_path"]).resolve(strict=True) == files[0], "Native proof used a different candidate path")
                actual = {Path(path).resolve(strict=True): expected for path, expected in proof["input_sha256"].items()}
                require(actual == {path: all_hashes[str(path)] for path in files[:4]}, "Native proof used different candidate or receipt inputs")
                poses.validate_proof(proof, ASSET, all_hashes[str(files[0])], all_hashes[str(files[1])], authored)
                report.update(native_proof_sha256=poses.sha(native), native_checks=proof["checks"])
        report["accepted"] = True
    except (AssertionError, KeyError, OSError, TypeError, ValueError) as error:
        report["error"] = str(error) or type(error).__name__
    (OUT / "receipt.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in ("accepted", "native_checks", "error", "results") if key in report}), flush=True)
    return 0 if report["accepted"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
