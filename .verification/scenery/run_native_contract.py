"""Queued source-only parser and in-memory geometry checks; no asset loading."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "outputs/AshenOathTheRoadBetweenCrowns"
GODOT = Path(r"C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe")
FILES = ["build_living_world_blender.gd", "living_world_part_baker.gd", "living_world_geometry_contract.gd", "verify_living_world_split.gd"]
BAD = re.compile(r"SCRIPT ERROR|Parse Error|(?:^|\n)ERROR:|ObjectDB instances leaked|resources still in use", re.I)


def main() -> int:
    destination = ROOT / ".verification/scenery/native_contract_r2"
    destination.mkdir(exist_ok=False)
    project = destination / "project"
    (project / "tools").mkdir(parents=True)
    (project / "project.godot").write_text(
        'config_version=5\n[application]\nconfig/name="Scenery contract fixture"\n'
        'config/use_custom_user_dir=true\nconfig/custom_user_dir_name="SceneryContract"\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8"
    )
    sources = []
    for name in FILES:
        source = GAME / "tools" / name
        shutil.copyfile(source, project / "tools" / name)
        sources.append({"path": source.relative_to(ROOT).as_posix(), "sha256": hashlib.sha256(source.read_bytes()).hexdigest()})
    environment = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA"):
        path = destination / key.lower()
        path.mkdir()
        environment[key] = str(path)
    runs = [
        ("compiler_parse", ["--check-only", "--script", "res://tools/build_living_world_blender.gd"], None),
        ("extractor_parse", ["--check-only", "--script", "res://tools/living_world_part_baker.gd"], None),
        ("geometry_parse", ["--check-only", "--script", "res://tools/living_world_geometry_contract.gd"], None),
        ("split_parse", ["--check-only", "--script", "res://tools/verify_living_world_split.gd"], None),
        ("in_memory_geometry", ["--script", "res://tools/build_living_world_blender.gd", "--", "--verify-contract"], "SCENERY_BLENDER_CONTRACT: PASS checks=11 authored_assets=none"),
        ("in_memory_split", ["--script", "res://tools/verify_living_world_split.gd", "--", "--verify-contract"], "SCENERY_SPLIT_CONTRACT: PASS checks=10 authored_assets=none"),
    ]
    receipt = {"authored_assets_loaded": False, "world_loaded": False, "renderer": "headless", "sources": sources, "runs": [], "passed": False}
    for label, arguments, expected in runs:
        command = [str(GODOT), "--headless", "--path", str(project), *arguments]
        log = destination / (label + ".log")
        with log.open("wb") as stream:
            process = subprocess.Popen(command, cwd=project, env=environment, stdout=stream, stderr=subprocess.STDOUT)
            timed_out = False
            try:
                status = process.wait(timeout=35)
            except subprocess.TimeoutExpired:
                timed_out = True
                process.kill()  # Only the exact fixture process created above.
                status = process.wait(timeout=10)
        output = log.read_text(encoding="utf-8", errors="replace")
        passed = status == 0 and not timed_out and not BAD.search(output) and (expected is None or expected in output)
        row = {"label": label, "command": command, "pid": process.pid, "exit_code": status, "timed_out": timed_out, "passed": bool(passed), "log": log.relative_to(ROOT).as_posix()}
        receipt["runs"].append(row)
        print(json.dumps(row), flush=True)
        if not passed:
            print(output, flush=True)
            break
    receipt["passed"] = len(receipt["runs"]) == len(runs) and all(row["passed"] for row in receipt["runs"])
    (destination / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return 0 if receipt["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
