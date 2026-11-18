"""Prepare adjusted 1c baseline and run isolated, serial live-route comparisons.

Default is preparation/plan only. --execute --engine-slot-granted is required
to launch any renderer. No material capture files or runtime owners are edited.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid

from background_native_capture import spawn_background
from compare_monster_live_route import compare, validate_pilot_pair
from live_route_import_projection import native_staff_images, prepare_projection, validate_prepared_identity, validate_projection
from run_living_cast_capture import isolated_configuration
from run_monster_vitality_capture import junction

PROJECT = Path(__file__).resolve().parents[1]
SCRIPT = PROJECT / "tools/profile_monster_live_route.gd"
COORDINATES = PROJECT / "tools/qa_viewport_coordinates.gd"
QA_TOOL_FILES = [SCRIPT,COORDINATES,Path(__file__).resolve(),PROJECT/"tools/compare_monster_live_route.py",
                 PROJECT/"tools/background_native_capture.py",PROJECT/"tools/run_living_cast_capture.py",
                 PROJECT/"tools/run_monster_vitality_capture.py",PROJECT/"tools/live_route_import_projection.py"]
GODOT = Path.home() / ".cache/codex-runtimes/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe"
BASE = "1cbea51"
RELATIVE_PROJECT = Path("outputs/AshenOathTheRoadBetweenCrowns")
OVERLAY = {
    "scripts/views/player_character_view.gd": "Explicit typed bone alias lists across dynamic calls",
    "scripts/views/player_equipment_view.gd": "Explicit typed bow/back bone alias lists across dynamic calls",
    "scripts/character_role_spec.gd": "Plain bandit target height 1.72; existing collision/facing/LOD retained",
    "scripts/companion_controller.gd": "Canonical SavePayloadFields zone normalization API after extraction",
    "scripts/zone_residency_service.gd": "Validity-before-typed assignment in retirement traversal worklists",
    "scripts/views/living_cast_station_view.gd": "Freed actor/driver release guards; reservation/FX/prop cleanup retained",
    "scripts/everyday_life.gd": "Valid zone root before life controller lookup during retirement",
    "scripts/hud_navigation_dial.gd": "Skip only untriangulatable minimap clip output; original1c CanvasItem drawing defect",
}


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def save(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def qa_toolchain() -> list[dict]:
    return [{"path":str(path),"sha256":sha(path)} for path in QA_TOOL_FILES]


def git(repository: Path, *arguments: str) -> bytes:
    result = subprocess.run(["git", "-C", str(repository), *arguments], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise ValueError("Git failed: " + result.stderr.decode("utf-8", errors="replace"))
    return result.stdout


def overlay_paths() -> set[str]:
    return {(RELATIVE_PROJECT / path).as_posix() for path in OVERLAY}


def prepare_baseline(repository: Path, destination: Path, receipt_path: Path) -> dict:
    """A genuine detached 1c worktree; only eight reviewed prerequisites differ."""
    if destination.exists():
        raise ValueError("Baseline destination must not exist: " + str(destination))
    candidate = repository / RELATIVE_PROJECT
    base_commit = git(repository, "rev-parse", BASE + "^{commit}").decode().strip()
    git(repository, "worktree", "add", "--no-checkout", "--detach", str(destination), base_commit)
    git(destination, "sparse-checkout", "init", "--cone")
    git(destination, "sparse-checkout", "set", RELATIVE_PROJECT.as_posix())
    git(destination, "checkout", base_commit)
    rows = []
    baseline = destination / RELATIVE_PROJECT
    for relative, purpose in OVERLAY.items():
        source, target = candidate / relative, baseline / relative
        original = target.read_bytes()
        patch = git(repository, "diff", "--no-ext-diff", "--no-color", base_commit, "--", str(RELATIVE_PROJECT / relative))
        if not patch:
            raise ValueError("Approved prerequisite diff missing: " + relative)
        shutil.copyfile(source, target)
        rows.append({"path": relative, "purpose": purpose, "baseline_sha256": hashlib.sha256(original).hexdigest(),
                     "overlay_sha256": sha(target), "reviewed_diff_sha256": hashlib.sha256(patch).hexdigest(),
                     "reviewed_diff": patch.decode("utf-8")})
    # Reuse unchanged source import artifacts, not candidate runtime scripts.
    # Native runtime never runs editor import; each source gets a separate cache.
    cache = baseline / ".godot"
    cache.mkdir(exist_ok=False)
    junction(cache / "imported", candidate / ".godot/imported")
    for name in ("global_script_class_cache.cfg", "uid_cache.bin"):
        source = candidate / ".godot" / name
        if source.is_file(): shutil.copyfile(source, cache / name)
    receipt = {"kind": "adjusted_1c_prerequisite_baseline", "base_commit": base_commit,
               "baseline_project": str(baseline), "candidate_project": str(candidate), "overlay": rows,
               "scope": "Adjusted source baseline, not unmodified 1c. No candidate mechanics, palette, enemy data or story changes copied.",
               "cache": "Unchanged imported resources reused by directory link; independent class/UID cache copies"}
    save(receipt_path, receipt)
    verify_overlay(receipt)
    return receipt


def verify_overlay(receipt: dict, native_extraction: dict | None = None) -> None:
    baseline = Path(receipt["baseline_project"])
    repository = baseline.parents[1]
    if git(repository, "rev-parse", "HEAD").decode().strip() != receipt["base_commit"]:
        raise ValueError("Adjusted baseline is no longer based on the exact 1c commit")
    changed = git(repository, "diff", "--name-only", "HEAD").decode().splitlines()
    if set(changed) != overlay_paths():
        raise ValueError("Baseline contains missing or additional runtime modifications: " + repr(changed))
    allowed = set()
    if native_extraction is not None:
        if native_staff_images(baseline,Path(receipt["candidate_project"])) != native_extraction:
            raise ValueError("Native import extraction does not match its exact baseline GLB proof")
        allowed = {(RELATIVE_PROJECT/row["resource"]).as_posix() for row in native_extraction["images"]}
    untracked = git(repository, "ls-files", "--others", "--exclude-standard").decode().splitlines()
    if set(untracked)-allowed:
        raise ValueError("Baseline has unrecorded files: " + repr(untracked[:10]))
    rows = receipt.get("overlay", [])
    if {row["path"] for row in rows} != set(OVERLAY):
        raise ValueError("Adjusted baseline overlay is incomplete")
    for row in rows:
        relative = row["path"]
        if sha(baseline / relative) != row["overlay_sha256"] or sha(Path(receipt["candidate_project"]) / relative) != row["overlay_sha256"]:
            raise ValueError("Prerequisite bytes differ between baseline/candidate: " + relative)


def source_snapshot(project: Path) -> dict:
    """Hash actual runtime inputs, including prepared assets; exclude exports/cache."""
    files = []
    for directory in ("scripts", "data", "scenes", "assets", "assets_external", "shaders"):
        for path in sorted((project / directory).rglob("*")):
            if path.is_file(): files.append({"path": path.relative_to(project).as_posix(), "bytes": path.stat().st_size, "sha256": sha(path)})
    files.append({"path": "project.godot", "bytes": (project / "project.godot").stat().st_size, "sha256": sha(project / "project.godot")})
    for path in sorted(project.glob("*.json")):
        files.append({"path":path.name,"bytes":path.stat().st_size,"sha256":sha(path)})
    return {"files": files, "sha256": hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()}


def prepare_run(project: Path, output: Path, viewport: str, godot: Path, snapshot: dict) -> dict:
    output.mkdir(parents=True, exist_ok=False)
    isolated = output / "isolated_project"
    isolated.mkdir()
    profile = "AshenOathCapture/monster_route_" + uuid.uuid4().hex
    configuration = isolated_configuration((project / "project.godot").read_bytes(), profile)
    import re
    width, height = (960, 540) if viewport == "touch" else (1280, 720)
    for key, value in (("viewport_width", width), ("viewport_height", height)):
        configuration, count = re.subn(rb"(?m)^(window/size/" + key.encode() + rb"=)[^\r\n]*",
                                        lambda match: match[1] + str(value).encode(), configuration)
        if count != 1: raise ValueError("Missing viewport configuration")
    (isolated / "project.godot").write_bytes(configuration)
    for source in project.iterdir():
        if source.name == "project.godot": continue
        target = isolated / source.name
        if source.is_dir(): junction(target, source)
        elif source.is_file(): shutil.copyfile(source, target)
    roaming, local = output / "profile/roaming", output / "profile/local"
    roaming.mkdir(parents=True)
    local.mkdir(parents=True)
    command = [str(godot), "--path", str(isolated), "--windowed", "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3",
               "--script", str(SCRIPT), "--log-file", str(output / "godot.log"), "--",
               "--profile=" + profile, "--viewport=" + viewport, "--output=" + str(output / "report.json"),
               "--coordinates-helper=" + str(COORDINATES)]
    return {"command": command, "project": str(project), "isolated_project": str(isolated), "output": str(output),
            "environment": {"APPDATA": str(roaming), "LOCALAPPDATA": str(local)}, "profile": profile,
            "expected_user_data_dir": str(roaming / Path(profile)), "qa_script_sha256": sha(SCRIPT),
            "qa_coordinates_path":str(COORDINATES),"qa_coordinates_sha256":sha(COORDINATES),
            "qa_toolchain":qa_toolchain(),
            "godot_sha256":sha(godot),
            "source_snapshot_sha256": snapshot["sha256"], "configuration_sha256": sha(isolated / "project.godot")}


def execute_run(receipt: dict, timeout: int) -> dict:
    output, process = Path(receipt["output"]), None
    receipt["started_utc"] = datetime.now(timezone.utc).isoformat()
    save(output / "receipt.json", receipt)
    try:
        if qa_toolchain()!=receipt["qa_toolchain"]: raise ValueError("QA toolchain changed before launch")
        if sha(Path(receipt["command"][0]))!=receipt["godot_sha256"]: raise ValueError("Godot executable changed before launch")
        for name in ("import_projection","prepared_identity"):
            if sha(Path(receipt[name+"_file"]))!=receipt[name+"_sha256"]: raise ValueError("Frozen baseline preparation proof changed")
        environment = os.environ.copy()
        environment.update(receipt["environment"])
        with (output / "stdout.log").open("wb") as stdout:
            process = spawn_background(receipt["command"], cwd=receipt["isolated_project"], env=environment, stdout=stdout)
            receipt["owned_pid"], receipt["private_desktop"] = process.pid, process.desktop_receipt
            receipt["exit_code"] = process.wait(timeout=timeout)
        report = json.loads((output / "report.json").read_text(encoding="utf-8"))
        errors = []
        for name in ("stdout.log", "godot.log"):
            errors += [line for line in (output / name).read_text(encoding="utf-8", errors="replace").splitlines()
                       if "ERROR:" in line or "SCRIPT ERROR:" in line or "_save_to_cache" in line]
        if receipt["exit_code"] != 0 or report.get("passed") is not True or errors:
            raise ValueError("Live route runtime failed: " + repr(errors[:10]) + repr(report.get("failures")))
        if str(report.get("user_data_dir", "")).replace("\\", "/").casefold() != receipt["expected_user_data_dir"].replace("\\", "/").casefold():
            raise ValueError("Renderer did not use its isolated profile")
        if sha(SCRIPT) != receipt["qa_script_sha256"] or sha(COORDINATES)!=receipt["qa_coordinates_sha256"] or sha(Path(receipt["isolated_project"]) / "project.godot") != receipt["configuration_sha256"]:
            raise ValueError("QA script/configuration changed during observation")
        if qa_toolchain()!=receipt["qa_toolchain"]: raise ValueError("QA toolchain changed during observation")
        for name in ("import_projection","prepared_identity"):
            if sha(Path(receipt[name+"_file"]))!=receipt[name+"_sha256"]: raise ValueError("Baseline preparation proof changed during observation")
        if source_snapshot(Path(receipt["project"]))["sha256"] != receipt["source_snapshot_sha256"]:
            raise ValueError("Runtime source bytes changed during observation")
        receipt["evidence_files"] = {name:sha(output/name) for name in ("report.json","stdout.log","godot.log")}
        receipt["status"] = "pass"
        return report
    except BaseException as error:
        receipt["status"], receipt["error"] = "fail", str(error)
        raise
    finally:
        if process is not None:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=20)
            process.close()
        receipt["finished_utc"] = datetime.now(timezone.utc).isoformat()
        save(output / "receipt.json", receipt)


def observation_key(item: dict) -> tuple[str, str, int]:
    if not isinstance(item,dict) or not isinstance(item.get("report"),dict):
        raise ValueError("Malformed saved observation")
    viewport = tuple(item["report"].get("viewport",[]))
    name = {(1280,720):"desktop",(960,540):"touch"}.get(viewport)
    version, repeat = item.get("version"), item.get("repeat")
    if name is None or version not in ("baseline","candidate") or type(repeat) is not int or repeat not in range(3):
        raise ValueError("Invalid saved observation identity")
    return name,version,repeat


def toolchain_sha256(value: list[dict]) -> str:
    return hashlib.sha256(json.dumps(value,sort_keys=True).encode()).hexdigest()


def validate_resume(observations: list[dict], output: Path, projects: dict, snapshots: dict,
                    tools: list[dict], script_hash: str, coordinates_hash: str, godot_hash: str) -> set[tuple]:
    """Reuse only completed runs whose original bytes and every input still match."""
    if not isinstance(observations,list): raise ValueError("Saved observations must be a list")
    completed: set[tuple] = set()
    for item in observations:
        key = observation_key(item)
        if key in completed: raise ValueError("Duplicate saved observation")
        completed.add(key)
        version = key[1]
        if item.get("qa_script_sha256")!=script_hash or item.get("qa_toolchain_sha256")!=toolchain_sha256(tools):
            raise ValueError("Cannot resume observations from another QA toolchain")
        if item.get("source_snapshot_sha256")!=snapshots[version]["sha256"]:
            raise ValueError("Cannot resume observations from changed runtime source bytes")
        directory = Path(item.get("run_directory","")).resolve(strict=True)
        if not directory.is_relative_to(output.resolve()) or directory==output.resolve():
            raise ValueError("Saved run escapes the current matrix directory")
        receipt_path = directory/"receipt.json"
        if sha(receipt_path)!=item.get("receipt_sha256"):
            raise ValueError("Saved run receipt bytes changed")
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        if receipt.get("status")!="pass" or receipt.get("exit_code")!=0:
            raise ValueError("A failed/incomplete attempt cannot be reused")
        if Path(receipt.get("project","")).resolve()!=projects[version].resolve() or Path(receipt.get("output","")).resolve()!=directory:
            raise ValueError("Saved run project/directory identity changed")
        if receipt.get("qa_toolchain")!=tools or receipt.get("source_snapshot_sha256")!=snapshots[version]["sha256"]:
            raise ValueError("Saved receipt does not match the frozen source/toolchain")
        if receipt.get("qa_script_sha256")!=script_hash or receipt.get("qa_coordinates_sha256")!=coordinates_hash or receipt.get("godot_sha256")!=godot_hash:
            raise ValueError("Saved QA/helper/engine identity changed")
        for field,name in (("import_projection","baseline_import_projection.json"),("prepared_identity","prepared_monster_identity.json")):
            proof = output/name
            if Path(receipt.get(field+"_file","")).resolve()!=proof.resolve() or sha(proof)!=receipt.get(field+"_sha256"):
                raise ValueError("Saved baseline preparation proof changed")
        evidence = receipt.get("evidence_files",{})
        if set(evidence)!={"report.json","stdout.log","godot.log"}:
            raise ValueError("Saved report/log evidence is incomplete")
        for name, digest in evidence.items():
            if sha(directory/name)!=digest: raise ValueError("Saved report/log bytes changed: "+name)
        report = json.loads((directory/"report.json").read_text(encoding="utf-8"))
        if report!=item["report"] or report.get("passed") is not True or report.get("failures") or report.get("engine_errors"):
            raise ValueError("Saved report is not the exact successful observation")
        if str(report.get("user_data_dir","")).replace("\\","/").casefold()!=str(receipt.get("expected_user_data_dir","")).replace("\\","/").casefold():
            raise ValueError("Saved observation did not use its isolated profile")
        if not Path(receipt["expected_user_data_dir"]).resolve().is_relative_to((directory/"profile").resolve()):
            raise ValueError("Saved profile escapes its disposable run directory")
        if receipt.get("environment")!={"APPDATA":str(directory/"profile/roaming"),"LOCALAPPDATA":str(directory/"profile/local")}:
            raise ValueError("Saved profile environment differs from the isolated run")
        config = Path(receipt.get("isolated_project",""))/"project.godot"
        if not config.resolve(strict=True).is_relative_to(directory) or sha(config)!=receipt.get("configuration_sha256"):
            raise ValueError("Saved isolated configuration bytes changed or escaped")
    return completed


def attempt_directory(output: Path, viewport: str, version: str, repeat: int, resume: bool) -> Path:
    if viewport not in ("desktop","touch") or version not in ("baseline","candidate") or type(repeat) is not int or repeat not in range(3):
        raise ValueError("Invalid retry identity")
    base = output/f"{viewport}_{repeat}_{version}"
    if not base.exists(): return base
    if not resume: raise ValueError("Existing attempt preserved; use explicit --resume or a new matrix output")
    number = 2
    while (output/(base.name+f"_attempt{number}")).exists(): number+=1
    return output/(base.name+f"_attempt{number}")


def validate_ready_pilots(observations: list[dict], output: Path) -> None:
    for name, viewport in (("desktop",[1280,720]),("touch",[960,540])):
        pair = [item for item in observations if item["repeat"]==0 and item["report"]["viewport"]==viewport]
        if len(pair)!=2: continue
        pilot = validate_pilot_pair(pair)
        save(output/("pilot_"+name+".json"),pilot)
        if not pilot["valid_for_matched_sampling"]:
            raise ValueError("First paired route is not matched; stopped before remaining repetitions: "+repr(pilot["issues"]))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-worktree", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--godot", type=Path, default=GODOT)
    parser.add_argument("--prepare-baseline", action="store_true")
    parser.add_argument("--prepare-import-remaps", action="store_true",help="Project only missing generated remaps for byte-identical1c source resources")
    parser.add_argument("--prior-import-projection",type=Path,help="Preserve the exact origin receipt for already projected remaps")
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--engine-slot-granted", action="store_true")
    parser.add_argument("--resume", action="store_true",help="Reuse only hash-validated successful runs; retries get new attempt directories")
    parser.add_argument("--timeout", type=int, default=600)
    args = parser.parse_args()
    output, baseline_tree = args.output.resolve(), args.baseline_worktree.resolve()
    repository = Path(git(PROJECT, "rev-parse", "--show-toplevel").decode().strip())
    overlay_path = output / "baseline_overlay.json"
    if args.prepare_baseline:
        if overlay_path.exists(): raise ValueError("Do not overwrite a baseline overlay receipt")
        overlay = prepare_baseline(repository, baseline_tree, overlay_path)
    else:
        overlay = json.loads(overlay_path.read_text(encoding="utf-8"))
    projects = {"baseline": Path(overlay["baseline_project"]), "candidate": PROJECT}
    projection_path = output/"baseline_import_projection.json"
    prepared_path = output/"prepared_monster_identity.json"
    native_extraction = None
    if projection_path.exists(): native_extraction = json.loads(projection_path.read_text(encoding="utf-8")).get("native_image_extraction")
    if args.prepare_import_remaps:
        native_extraction = native_staff_images(projects["baseline"],projects["candidate"])
        save(output/"native_import_extraction.json",native_extraction)
    verify_overlay(overlay,native_extraction)
    if args.prepare_import_remaps:
        validate_prepared_identity(json.loads(prepared_path.read_text(encoding="utf-8")),projects["baseline"],projects["candidate"])
        print("Preparing exact-source import remaps and artifact hashes; no engine started",flush=True)
        native_staff_images(projects["baseline"],projects["candidate"],create=True)
        projection = prepare_projection(projects["baseline"],projects["candidate"],projection_path,args.prior_import_projection,native_extraction)
        verify_overlay(overlay,native_extraction)
        print(f"Prepared {projection['projected_count']} missing remaps; retained {projection['retained_count']} existing remaps",flush=True)
    # Alternating A/B, B/A, A/B reduces systematic thermal/order bias.
    order = [(viewport, version, repeat) for viewport in ("desktop", "touch") for repeat in range(3)
             for version in (("baseline", "candidate") if repeat % 2 == 0 else ("candidate", "baseline"))]
    save(output / "plan.json", {"kind": "live_route_plan", "order": order, "engines_started": False,
                               "overlay_receipt": str(overlay_path), "qa_script_sha256": sha(SCRIPT)})
    if not args.execute:
        print("Live route prepared; no engine launched. Use --execute --engine-slot-granted after serial QA slot handoff.")
        return 0
    if not args.engine_slot_granted: raise ValueError("Explicit serialized engine slot is required")
    projection = json.loads(projection_path.read_text(encoding="utf-8"))
    prepared = json.loads(prepared_path.read_text(encoding="utf-8"))
    # Full shared-artifact hashes are checked before and after the frozen
    # matrix. Every run additionally hashes its actual source/remap bytes and
    # pins both preparation receipts. No editor/importer runs in this interval.
    print("Validating frozen remap/artifact and prepared-scene proofs; no engine started",flush=True)
    validate_projection(projection,projects["baseline"],projects["candidate"])
    validate_prepared_identity(prepared,projects["baseline"],projects["candidate"])
    observations_path = output/"observations.json"
    if observations_path.exists() and not args.resume:
        raise ValueError("Completed observations exist; use explicit --resume or preserve this matrix and start another")
    observations = json.loads(observations_path.read_text(encoding="utf-8")) if args.resume and observations_path.exists() else []
    snapshots = {}
    for version,project in projects.items():
        snapshots[version] = source_snapshot(project)
        print(f"Frozen {version}: {len(snapshots[version]['files'])} source files / {snapshots[version]['sha256']}",flush=True)
    tools = qa_toolchain()
    godot = args.godot.resolve(strict=True)
    completed = validate_resume(observations,output,projects,snapshots,tools,sha(SCRIPT),sha(COORDINATES),sha(godot))
    for version, snapshot in snapshots.items():
        path = output/(version+"_source_snapshot.json")
        if path.exists() and json.loads(path.read_text(encoding="utf-8"))!=snapshot:
            raise ValueError("Existing frozen source snapshot differs; preserve it and start a new matrix")
        save(path,snapshot)
    validate_ready_pilots(observations,output)
    for viewport, version, repeat in order:
        if (viewport,version,repeat) in completed:
            print(f"Reused verified {viewport} {repeat} {version}",flush=True)
            continue
        verify_overlay(overlay,native_extraction)
        if qa_toolchain()!=tools: raise ValueError("Frozen QA toolchain changed between repetitions")
        receipt = prepare_run(projects[version],attempt_directory(output,viewport,version,repeat,args.resume),viewport,godot,snapshots[version])
        receipt.update(import_projection_file=str(projection_path),import_projection_sha256=sha(projection_path),
                       prepared_identity_file=str(prepared_path),prepared_identity_sha256=sha(prepared_path))
        report = execute_run(receipt, args.timeout)
        observations.append({"version": version, "repeat": repeat, "report": report,
                             "qa_script_sha256":receipt["qa_script_sha256"],"qa_toolchain_sha256":toolchain_sha256(receipt["qa_toolchain"]),
                             "source_snapshot_sha256":receipt["source_snapshot_sha256"],"run_directory":receipt["output"],
                             "receipt_sha256":sha(Path(receipt["output"])/"receipt.json")})
        save(observations_path,observations)
        validate_ready_pilots(observations,output)
        print(f"Completed {viewport} {repeat} {version}", flush=True)
    validate_projection(projection,projects["baseline"],projects["candidate"])
    validate_prepared_identity(prepared,projects["baseline"],projects["candidate"])
    result = compare(observations)
    save(output / "comparison.json", result)
    print(json.dumps(result, indent=2))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
