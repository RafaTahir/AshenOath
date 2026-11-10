"""Fresh native proof of exact v002 delivery, permitting only compiler import repair."""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "outputs/AshenOathTheRoadBetweenCrowns"
sys.path.insert(0, str(GAME / "tools"))
import run_living_scenery_pipeline as pipeline


def prepare() -> dict:
    prior = ROOT / ".verification/scenery/actual_pipeline_r2/pipeline.json"
    receipt = json.loads(prior.read_text(encoding="utf-8"))
    runs = receipt.get("runs", [])
    if (receipt.get("status") != "failed" or len(runs) != 8
            or [row.get("step") for row in runs] != pipeline.STEPS[:8]
            or any(row.get("passed") is not True or row.get("exit_code") != 0 or row.get("timed_out") is not False
                   or row.get("owned_process_exited") is not True for row in runs[:7])
            or runs[7].get("passed") is not False or runs[7].get("owned_process_exited") is not True):
        raise ValueError("expected preserved r2 extraction/authoring and stopped compiler failure")
    compiler = GAME / "tools/build_living_world_blender.gd"
    compiler_row = next(row for row in receipt["sources"] if Path(row["path"]) == compiler)
    archived_compiler = prior.parent / "source_failure/build_living_world_blender.gd"
    if pipeline.sha(archived_compiler) != compiler_row["sha256"]:
        raise ValueError("failed r2 compiler archive changed")
    old = archived_compiler.read_bytes()
    needle = b'\tvar error := document.append_from_file(str(paths.carrier), state)'
    replacement = (b'\t# The retained scenery uses uncompressed position/UV arrays. Automatic\n'
                   b'\t# GLTF compression can quantize its authored UVs beyond the strict retained\n'
                   b'\t# attribute contract, even when the exported float channels are exact.\n'
                   b'\tvar error := document.append_from_file(str(paths.carrier), state, EditorSceneFormatImporter.IMPORT_FORCE_DISABLE_MESH_COMPRESSION)')
    # Permit only newline normalization plus this exact reviewed import hunk.
    if old.count(needle) != 1 or compiler.read_bytes().replace(b'\r\n',b'\n') != old.replace(b'\r\n',b'\n').replace(needle,replacement):
        raise ValueError("compiler contains changes beyond the exact approved import repair")
    immutable = receipt["originals"] + [row for row in receipt["sources"] if Path(row["path"]) != compiler]
    # Exactly eight mutable compiler destinations may change. Every baseline
    # scene/receipt, author archive and all nine static meshes remain exact.
    mutable = {pipeline.PARTS / (name+".scn") for name in pipeline.IDS}
    mutable.update(pipeline.EVIDENCE / (name+"_compile.json") for name in pipeline.IDS)
    frozen_outputs = [row for row in receipt["current_outputs"].values() if Path(row["path"]) not in mutable]
    if len(receipt["current_outputs"]) - len(frozen_outputs) != 8:
        raise ValueError("expected exactly four runtime scene and four compile receipt destinations")
    pipeline.check(immutable + frozen_outputs)
    pipeline.originals()
    for name in pipeline.IDS:
        pipeline.outputs("author_"+name)
    return {"kind":"living_scenery_final_proof","parent_failed_pipeline":pipeline.record(prior),
            "immutable_inputs":immutable + frozen_outputs,"compiler":pipeline.record(compiler),
            "allowed_output_destinations":sorted(str(path) for path in mutable),"runs":[],"passed":False,
            "visual_acceptance":False,"actual_level_acceptance":False,"user_acceptance":False}


def main() -> int:
    receipt = prepare()
    if "--preflight-only" in sys.argv:
        print(json.dumps({"preflight":True,"immutable_inputs":len(receipt["immutable_inputs"]),
                          "allowed_output_destinations":len(receipt["allowed_output_destinations"])}))
        return 0
    output = ROOT / ".verification/scenery/actual_pipeline_r3"
    output.mkdir(exist_ok=False)
    source = output / "source"
    source.mkdir()
    for path in [Path(__file__), GAME / "tools/build_living_world_blender.gd", GAME / "tools/run_living_scenery_pipeline.py"]:
        shutil.copyfile(path,source/path.name)
    receipt["sources"] = [pipeline.record(path) for path in sorted(source.iterdir())]
    previous = output / "prior_outputs"
    previous.mkdir()
    receipt["prior_outputs"] = []
    for index, value in enumerate(receipt["allowed_output_destinations"]):
        path = Path(value)
        if path.is_file():
            archive = previous / (str(index)+"_"+path.name)
            shutil.copyfile(path,archive)
            receipt["prior_outputs"].append(pipeline.record(archive))
    environment = os.environ.copy()
    for key in ("APPDATA","LOCALAPPDATA"):
        path = output / key.lower()
        path.mkdir()
        environment[key] = str(path)
    jobs = [
        ("parser",[str(pipeline.GODOT),"--headless","--path",str(GAME),"--check-only","--script","res://tools/build_living_world_blender.gd"],45,[]),
        *[(step,*pipeline.command(step)) for step in ("compile","equivalence")],
    ]
    for step,command,deadline,markers in jobs:
        pipeline.check(receipt["immutable_inputs"]+[receipt["compiler"]])
        row = {"step":step}
        receipt["runs"].append(row)
        def started(pid):
            receipt["owned_pid"] = pid
            pipeline.write(output/"receipt.json",receipt)
        try:
            text = pipeline.run_child(command,deadline,output/(step+".log"),environment,row,started)
            if row["exit_code"] != 0 or row["timed_out"] or pipeline.BAD.search(text) or any(marker not in text for marker in markers):
                raise ValueError("strict native proof failed: "+step)
            row["outputs"] = [] if step=="parser" else [pipeline.record(path) for path in pipeline.outputs(step)]
            row["passed"] = True
        except Exception as error:
            receipt["error"] = str(error)
            print(str(error),flush=True)
            return 1
        finally:
            receipt.pop("owned_pid",None)
            pipeline.write(output/"receipt.json",receipt)
            print(json.dumps(row),flush=True)
    pipeline.check(receipt["immutable_inputs"]+[receipt["compiler"]])
    receipt["passed"] = True
    pipeline.write(output/"receipt.json",receipt)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
