"""Serial real scenery extraction, Blender authoring and geometry acceptance.

Run only in the granted native/Blender slot. A checkpoint can resume unchanged;
a failed or interrupted run must retain its directory and start a new receipt.
Create OUTPUT/STOP_AFTER_STEP to stop after the active owned child finishes and
its output is verified. Remove that marker before explicitly resuming.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

from freeze_living_world_originals import freeze, OUTPUTS

ROOT = Path(__file__).resolve().parents[3]
GAME = ROOT / "outputs/AshenOathTheRoadBetweenCrowns"
ART = ROOT / "art_source/art_recovery_v2"
EVIDENCE = ART / "evidence/living_assets_stage3_20261107/scenery"
MODELS = ART / "models/living_assets_stage3_20261107/scenery"
PARTS = GAME / "assets_external/environment_prepared/living_world"
IDS = {"checkpoint_cloth":2,"marsh_reeds":5,"hart_ferns":6,"ash_mill_wheel":1}
GODOT = Path(r"C:/Users/User/.cache/codex-runtimes/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe")
BLENDER = Path(r"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe")
STEPS = ["extract_campaign", "extract_hart", "extract_mill", *["author_"+key for key in IDS], "compile", "equivalence"]
BAD = re.compile(r"SCRIPT ERROR|Parse Error|(?:^|\n)ERROR:|Traceback \(most recent call last\)|ObjectDB instances leaked|resources still in use", re.I)


def sha(path: Path) -> str: return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path: Path, value) -> None: path.write_text(json.dumps(value, indent=2)+"\n", encoding="utf-8")
def record(path: Path) -> dict: return {"path":str(path.resolve()),"sha256":sha(path),"bytes":path.stat().st_size}
def check(rows: list[dict]) -> None:
    for row in rows:
        path = Path(row["path"])
        if not path.is_file() or path.stat().st_size != row["bytes"] or sha(path) != row["sha256"]:
            raise ValueError("frozen pipeline input/output changed: " + str(path))


def originals() -> list[dict]:
    if not (EVIDENCE / "combined_original/manifest.json").is_file():
        raise ValueError("immutable original archive must already exist before pipeline preparation")
    manifest = freeze(ROOT) # Existing immutable freeze is verified, never rebased.
    if manifest.get("purpose") != "combined-static-before-scenery-split" or {row["id"] for row in manifest["meshes"]} != set(OUTPUTS):
        raise ValueError("pipeline requires the exact original nine-mesh archive")
    folder = EVIDENCE / "combined_original"
    paths = [folder / "manifest.json"]
    for row in manifest["meshes"] + manifest["source_snapshots"]:
        if Path(row["frozen"]).name != row["frozen"]: raise ValueError("original archive path escaped")
        paths.append(folder / row["frozen"])
    return [record(path) for path in paths]


def mutable_paths() -> list[Path]:
    paths = [GAME / relative for relative in OUTPUTS.values()]
    for identity in IDS:
        paths += [PARTS / (identity+".scn"), MODELS / identity / "authoring.json"]
        paths += [EVIDENCE / (identity+suffix) for suffix in ("_baseline.scn", "_baseline.glb", "_baseline.json", "_compile.json")]
    return paths + [EVIDENCE / "split_equivalence.json"]


def source_inputs() -> list[dict]:
    preflight = ROOT / ".verification/scenery/extraction_preflight_r1.json"
    inventory = json.loads(preflight.read_text(encoding="utf-8"))
    if not inventory.get("passed_static_preflight"): raise ValueError("native extraction preflight has not passed")
    mutable = {path.resolve() for path in mutable_paths()}
    paths = set()
    for row in inventory["resources"] + inventory["parser_scripts"]:
        path = (GAME / row["path"]).resolve(strict=True)
        if not path.is_relative_to(GAME.resolve()): raise ValueError("extraction input escaped the isolated game")
        if path in mutable: continue
        # The resource restoration receipt is immutable. Source scripts may
        # have authorized edits since that receipt; freeze their current bytes.
        if "destination_sha256" in row and (sha(path) != row["destination_sha256"] or path.stat().st_size != row["bytes"]):
            raise ValueError("verified extraction resource changed: " + str(path))
        paths.add(path)
    paths.update([preflight, Path(__file__), GODOT, BLENDER, GAME / ".godot/global_script_class_cache.cfg",
                  ART / "tools/author_living_world_parts.py", ART / "tools/living_world_gltf_transport.py"])
    paths.update(GAME / "tools" / name for name in ["freeze_living_world_originals.py", "living_world_part_baker.gd",
                 "build_living_world_blender.gd", "living_world_geometry_contract.gd", "verify_living_world_split.gd"])
    return [record(path) for path in sorted(paths)]


def validate_checkpoint(receipt: dict, output: Path, through: str) -> None:
    runs = receipt.get("runs", [])
    if (receipt.get("schema_version") != 1 or receipt.get("kind") != "living_scenery_actual_pipeline"
            or receipt.get("status") != "checkpoint" or Path(receipt.get("output", "")) != output
            or "owned_pid" in receipt or not runs or len(runs) >= len(STEPS)
            or [row.get("step") for row in runs] != STEPS[:len(runs)]
            or any(row.get("passed") is not True or row.get("exit_code") != 0 or row.get("timed_out") is not False for row in runs)):
        raise ValueError("only an unchanged completed boundary checkpoint may resume")
    if STEPS.index(through) < len(runs): raise ValueError("resume must advance to a later process boundary")
    check(receipt["originals"] + receipt["sources"] + list(receipt["current_outputs"].values()))


def run_child(invocation: list[str], deadline: int, log: Path, environment: dict, row: dict, on_started) -> str:
    """Stop and reap only this owned child, including interrupt/callback errors."""
    process = None
    started = time.monotonic()
    row.update({"command":invocation,"deadline_seconds":deadline,"log":str(log),"passed":False,
                "pid":None,"exit_code":None,"timed_out":False,"owned_process_exited":False})
    try:
        with log.open("xb") as stream:
            try:
                process = subprocess.Popen(invocation,cwd=GAME,env=environment,stdout=stream,stderr=subprocess.STDOUT,
                                           creationflags=subprocess.CREATE_NO_WINDOW if os.name=="nt" else 0)
                row["pid"] = process.pid
                on_started(process.pid)
                try:
                    row["exit_code"] = process.wait(timeout=deadline)
                except subprocess.TimeoutExpired:
                    row["timed_out"] = True
            finally:
                if process is not None:
                    if process.poll() is None: process.kill()
                    row["exit_code"] = process.wait(timeout=10)
                    row["owned_process_exited"] = process.poll() is not None
    finally:
        row["seconds"] = round(time.monotonic()-started,3)
    return log.read_text(encoding="utf-8",errors="replace")


def command(step: str) -> tuple[list[str], int, list[str]]:
    native = [str(GODOT), "--headless", "--path", str(GAME), "--script"]
    builders = {"extract_campaign":("build_campaign_wilds.gd","CAMPAIGN WILDS BAKE: PASS"),
                "extract_hart":("build_hart_woodland.gd","HART WOODLAND BAKE: PASS"),
                "extract_mill":("build_ash_mill.gd","ASH MILL BAKE: PASS")}
    if step in builders:
        script, marker = builders[step]
        return native + ["res://tools/"+script], 180, [marker]
    if step.startswith("author_"):
        identity = step.removeprefix("author_")
        if identity not in IDS: raise ValueError("unknown scenery authoring step")
        return [str(BLENDER), "--background", "--threads", "2", "--python-exit-code", "1", "--python",
                str(ART / "tools/author_living_world_parts.py"), "--", "--asset", identity, "--art-root", str(ART)], 480, ["LIVING_WORLD_BLENDER_AUTHORED "+identity]
    if step == "compile":
        return native + ["res://tools/build_living_world_blender.gd"], 180, ["LIVING_WORLD_BLENDER_COMPILED "+key for key in IDS]
    if step == "equivalence":
        return native + ["res://tools/verify_living_world_split.gd"], 180, ["SCENERY_SPLIT_EQUIVALENCE: PASS meshes=9"]
    raise ValueError("unknown pipeline step")


def outputs(step: str) -> list[Path]:
    if step.startswith("extract_"):
        identities = list(OUTPUTS)[:7] if step == "extract_campaign" else ["hart"] if step == "extract_hart" else ["mill"]
        parts = ["checkpoint_cloth","marsh_reeds"] if step == "extract_campaign" else ["hart_ferns"] if step == "extract_hart" else ["ash_mill_wheel"]
        paths = [GAME / OUTPUTS[key] for key in identities]
        for key in parts:
            paths.append(PARTS / (key+".scn"))
            paths += [EVIDENCE / (key+suffix) for suffix in ("_baseline.scn","_baseline.glb","_baseline.json","_compile.json")]
            baseline = json.loads((EVIDENCE / (key+"_baseline.json")).read_text(encoding="utf-8-sig"))
            if baseline.get("schema_version") != 2 or baseline.get("asset") != key or len(baseline.get("parts", [])) != IDS[key]:
                raise ValueError("native retained input receipt incomplete: " + key)
            for field,suffix in (("carrier","_baseline.glb"),("native_baseline","_baseline.scn")):
                retained = EVIDENCE / (key+suffix)
                if Path(baseline[field]).resolve() != retained.resolve() or sha(retained) != baseline[field+"_sha256"]:
                    raise ValueError("native retained input identity changed: " + key + "/" + field)
            if not baseline.get("source_hashes"): raise ValueError("native retained input has no source provenance")
            for resource,digest in baseline["source_hashes"].items():
                source = (GAME / resource.removeprefix("res://")).resolve(strict=True)
                if not resource.startswith("res://") or not source.is_relative_to(GAME.resolve()) or sha(source) != digest:
                    raise ValueError("native retained source changed: " + resource)
        return paths
    if step.startswith("author_"):
        key = step.removeprefix("author_")
        receipt_path = MODELS / key / "authoring.json"
        receipt = json.loads(receipt_path.read_text(encoding="utf-8-sig"))
        if receipt.get("asset") != key or receipt.get("blender_authored") is not True or len(receipt.get("parts", [])) != IDS[key]:
            raise ValueError("real Blender authoring receipt incomplete: " + key)
        paths = [receipt_path]
        for field in ("blend","carrier","recipe","retained_input","retained_native","retained_receipt","transport_helper","raw_carrier"):
            path = (ART / receipt[field]).resolve(strict=True)
            if not path.is_relative_to(ART.resolve()) or sha(path) != receipt[field+"_sha256"]:
                raise ValueError("authored scenery provenance mismatch: " + key + "/" + field)
            paths.append(path)
        if (receipt["recipe_sha256"] != sha(ART / "tools/author_living_world_parts.py")
                or receipt["transport_helper_sha256"] != sha(ART / "tools/living_world_gltf_transport.py")
                or receipt.get("normal_transport", {}).get("verified") is not True
                or receipt["normal_transport"].get("before_sha256") != receipt["raw_carrier_sha256"]
                or receipt["normal_transport"].get("after_sha256") != receipt["carrier_sha256"]):
            raise ValueError("scenery delivery has stale recipe/helper or missing raw normal binding: " + key)
        return paths
    if step == "compile":
        paths = []
        for key, count in IDS.items():
            path = EVIDENCE / (key+"_compile.json")
            receipt = json.loads(path.read_text(encoding="utf-8-sig"))
            runtime = PARTS / (key+".scn")
            authored = MODELS / key / "authoring.json"
            if (receipt.get("blender_authored") is not True or receipt.get("asset") != key or receipt.get("sha256") != sha(runtime)
                    or len(receipt.get("parts", [])) != count or receipt.get("dependencies") != []
                    or receipt.get("authoring_receipt_sha256") != sha(authored)
                    or receipt.get("compiler_sha256") != sha(GAME / "tools/build_living_world_blender.gd")
                    or receipt.get("geometry_contract_sha256") != sha(GAME / "tools/living_world_geometry_contract.gd")
                    or any(row.get("triangle_attribute_multiplicity_equivalent") is not True for row in receipt["parts"])):
                raise ValueError("native Blender equivalence receipt incomplete: " + key)
            paths += [path, runtime]
        return paths
    path = EVIDENCE / "split_equivalence.json"
    receipt = json.loads(path.read_text(encoding="utf-8-sig"))
    if (receipt.get("passed") is not True or receipt.get("failures") or len(receipt.get("meshes", [])) != 9
            or receipt.get("original_manifest_sha256") != sha(EVIDENCE / "combined_original/manifest.json")
            or {row.get("id") for row in receipt["meshes"]} != set(OUTPUTS)
            or sum(row.get("parts", 0) for row in receipt["meshes"]) != 14
            or any(row.get("comparison", {}).get("passed") is not True for row in receipt["meshes"])):
        raise ValueError("real nine-static/fourteen-part union comparison failed")
    part_map = {"checkpoint":"checkpoint_cloth","marsh_crossing":"marsh_reeds","hart":"hart_ferns","mill":"ash_mill_wheel"}
    for row in receipt["meshes"]:
        key = row["id"]
        if row.get("rebuilt_sha256") != sha(GAME / OUTPUTS[key]): raise ValueError("union receipt contains stale static geometry: " + key)
        if key in part_map and row.get("parts_sha256") != sha(PARTS / (part_map[key]+".scn")):
            raise ValueError("union receipt contains stale moving geometry: " + key)
    return [path]


def execute(args) -> int:
    output = args.output.resolve()
    receipt_path = output / "pipeline.json"
    if args.resume:
        if (output / "STOP_AFTER_STEP").exists(): raise ValueError("remove the stop marker before explicitly resuming")
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        validate_checkpoint(receipt,output,args.through)
    else:
        if output.exists() and any(output.iterdir()): raise ValueError("preserve prior runs; output must be new or empty")
        output.mkdir(parents=True, exist_ok=True)
        receipt = {"schema_version":1,"kind":"living_scenery_actual_pipeline","output":str(output),"status":"prepared",
                   "started_utc":datetime.now(timezone.utc).isoformat(),"originals":originals(),"sources":source_inputs(),
                   "runs":[],"current_outputs":{},"visual_acceptance":False,"actual_level_acceptance":False,"user_acceptance":False}
        prior = output / "prior_outputs"
        prior.mkdir()
        receipt["prior_outputs"] = []
        for path in mutable_paths():
            if not path.is_file(): continue
            copy = prior / (sha(path)[:16]+"_"+path.name)
            if not copy.exists(): shutil.copyfile(path, copy)
            receipt["prior_outputs"].append({**record(path),"retained_copy":str(copy)})
        write(receipt_path, receipt)
    environment = os.environ.copy()
    for name in ("APPDATA","LOCALAPPDATA"):
        folder = output / name.lower()
        folder.mkdir(exist_ok=True)
        environment[name] = str(folder)
    last = STEPS.index(args.through)
    try:
        for index in range(len(receipt["runs"]), last+1):
            step = STEPS[index]
            check(receipt["originals"] + receipt["sources"] + list(receipt["current_outputs"].values()))
            invocation, deadline, markers = command(step)
            log = output / (f"{index:02d}_"+step+".log")
            receipt["status"] = "running"
            row = {"step":step,"passed":False}
            receipt["runs"].append(row)
            write(receipt_path, receipt)
            def on_started(pid):
                receipt["owned_pid"] = pid
                write(receipt_path, receipt)
            try:
                text = run_child(invocation,deadline,log,environment,row,on_started)
            finally:
                if row.get("owned_process_exited"): receipt.pop("owned_pid",None)
                write(receipt_path,receipt)
            if row["exit_code"] != 0 or row["timed_out"] or BAD.search(text) or not all(marker in text for marker in markers):
                raise ValueError("native/Blender step failed: " + step)
            check(receipt["originals"] + receipt["sources"])
            row["outputs"] = [record(path) for path in outputs(step)]
            for item in row["outputs"]: receipt["current_outputs"][item["path"]] = item
            row["passed"] = True
            receipt["status"] = "checkpoint"
            write(receipt_path,receipt)
            print(json.dumps({key:row[key] for key in ("step","pid","seconds","passed","log")}),flush=True)
            if (output / "STOP_AFTER_STEP").exists():
                receipt["stop_request_observed_after"] = step
                break
        receipt["status"] = "passed_geometry" if len(receipt["runs"]) == len(STEPS) else "checkpoint"
        write(receipt_path,receipt)
        return 0
    except BaseException as error:
        receipt["status"] = "failed"
        receipt["failure"] = type(error).__name__ + ": " + str(error)
        write(receipt_path,receipt)
        print(str(error),file=sys.stderr,flush=True)
        return 130 if isinstance(error,KeyboardInterrupt) else 1


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--through",choices=STEPS,required=True,help="stop at an explicit safe process boundary")
    parser.add_argument("--resume",action="store_true",help="resume only a completed, unchanged boundary checkpoint")
    args=parser.parse_args()
    try: return execute(args)
    except (OSError,ValueError,subprocess.SubprocessError) as error: parser.exit(2,str(error)+"\n")


if __name__=="__main__": sys.exit(main())
