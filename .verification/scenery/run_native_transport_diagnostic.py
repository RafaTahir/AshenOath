"""Read-only native channel diagnostic. Queued: requires an explicit engine grant."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "outputs/AshenOathTheRoadBetweenCrowns"
ART = ROOT / "art_source/art_recovery_v2"
GODOT = Path(r"C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe")
BAD = re.compile(r"SCRIPT ERROR|Parse Error|(?:^|\n)ERROR:|ObjectDB instances leaked|resources still in use", re.I)


def main() -> int:
    destination = ROOT / ".verification/scenery/native_transport_diagnostic_r1"
    destination.mkdir(exist_ok=False)
    project = destination / "project"
    project.mkdir()
    (project / "project.godot").write_text(
        'config_version=5\n[application]\nconfig/name="Read-only scenery diagnostic"\n'
        'config/use_custom_user_dir=true\nconfig/custom_user_dir_name="SceneryDiagnostic"\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8"
    )
    sources = [Path(__file__).with_name("diagnose_native_transport.gd"), GAME / "tools/living_world_geometry_contract.gd"]
    inputs = []
    for source in sources:
        shutil.copyfile(source, project / source.name)
        inputs.append({"path": str(source), "sha256": hashlib.sha256(source.read_bytes()).hexdigest()})
    for identity in ("marsh_reeds",):
        source = ART / "models/living_assets_stage3_20261107/scenery" / identity / "authoring.json"
        receipt = json.loads(source.read_text())
        for value in [source, *(ART / receipt[key] for key in ("retained_native", "retained_input", "carrier"))]:
            inputs.append({"path": str(value), "sha256": hashlib.sha256(value.read_bytes()).hexdigest()})
    environment = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA"):
        path = destination / key.lower()
        path.mkdir()
        environment[key] = str(path)
    receipt = {"inputs": inputs, "runs": [], "passed": False, "acceptance": False}
    jobs = [
        ("parse", ["--check-only", "--script", "res://diagnose_native_transport.gd"], None),
        ("diagnostic", ["--script", "res://diagnose_native_transport.gd", "--", str(ART), str(destination / "channels.json")], "SCENERY_NATIVE_TRANSPORT_DIAGNOSTIC COMPLETE parts=1 acceptance=false"),
    ]
    for label, arguments, expected in jobs:
        log = destination / (label + ".log")
        command = [str(GODOT), "--headless", "--path", str(project), *arguments]
        process = None
        timed_out = False
        with log.open("wb") as stream:
            try:
                process = subprocess.Popen(command, cwd=project, env=environment, stdout=stream, stderr=subprocess.STDOUT,
                                           creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
                try:
                    status = process.wait(timeout=45)
                except subprocess.TimeoutExpired:
                    timed_out = True
                    process.kill()
                    status = process.wait(timeout=10)
            finally:
                if process is not None and process.poll() is None:
                    process.kill()
                    process.wait(timeout=10)
        output = log.read_text(encoding="utf-8", errors="replace")
        passed = status == 0 and not timed_out and not BAD.search(output) and (expected is None or expected in output)
        row = {"label": label, "command": command, "pid": process.pid, "exit_code": status, "timed_out": timed_out,
               "owned_process_exited": process.poll() is not None, "passed": bool(passed), "log": str(log)}
        receipt["runs"].append(row)
        (destination / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
        print(json.dumps(row), flush=True)
        if not passed:
            print(output, flush=True)
            return 1
    for entry in inputs:
        if hashlib.sha256(Path(entry["path"]).read_bytes()).hexdigest() != entry["sha256"]:
            raise RuntimeError("Read-only diagnostic input changed: " + entry["path"])
    receipt["passed"] = True
    (destination / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
