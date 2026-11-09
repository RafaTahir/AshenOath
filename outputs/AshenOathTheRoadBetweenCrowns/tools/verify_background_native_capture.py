"""Bounded real-renderer smoke on private desktops; no game/assets are loaded."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import uuid

from background_native_capture import spawn_background
from run_living_cast_capture import GODOT, isolated_configuration, stop_owned_process


def verify(godot: Path, output: Path, viewport: str) -> dict:
    output.mkdir(parents=True, exist_ok=False)
    project = output / "project"
    project.mkdir()
    profile = "AshenOathCapture/probe_" + uuid.uuid4().hex
    source = b'config_version=5\n[application]\nconfig/name="Background capture probe"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
    (project / "project.godot").write_bytes(isolated_configuration(source,profile))
    env = dict(os.environ, APPDATA=str(output/"profile"), LOCALAPPDATA=str(output/"profile-local"))
    script = Path(__file__).with_name("verify_background_rendering.gd")
    command = [str(godot),"--path",str(project),"--windowed","--rendering-method","gl_compatibility",
               "--rendering-driver","opengl3","--script",str(script),"--",
               "--output="+output.as_posix(),"--viewport="+viewport]
    receipt = {"command":command,"script_sha256":hashlib.sha256(script.read_bytes()).hexdigest(),
               "engine_sha256":hashlib.sha256(godot.read_bytes()).hexdigest(),"status":"running"}
    process = None
    try:
        with (output/"stdout.log").open("wb") as log:
            process = spawn_background(command,cwd=project,stdout=log,env=env)
            receipt["pid"] = process.pid
            receipt["desktop"] = process.desktop_receipt
            receipt["exit_code"] = process.wait(timeout=40)
        proof = json.loads((output/"probe.json").read_text(encoding="utf-8"))
        log = (output/"stdout.log").read_text(encoding="utf-8",errors="replace")
        expected = [960,540] if viewport=="touch" else [1280,720]
        if receipt["exit_code"]!=0 or proof.get("status")!="pass" or "ERROR:" in log or "ObjectDB instances leaked" in log:
            raise ValueError("native probe/log gate failed")
        if proof.get("desktop")!=receipt["desktop"]["desktop"] or proof.get("viewport")!=expected \
                or proof.get("renderer")!="gl_compatibility" or proof.get("headless") is not False or proof.get("no_focus") is not True:
            raise ValueError("native probe does not match the requested background renderer")
        receipt["proof"] = proof
        receipt["frames"] = [{"path":str(path),"bytes":path.stat().st_size,"sha256":hashlib.sha256(path.read_bytes()).hexdigest()}
                             for path in (output/"frame_a.png",output/"frame_b.png")]
        receipt["status"] = "pass"
    except (OSError,ValueError,subprocess.TimeoutExpired) as error:
        receipt.update(status="fail",error=str(error))
    finally:
        if process is not None:
            try:
                stop_owned_process(process)
                process.close()
            except (OSError,RuntimeError,subprocess.TimeoutExpired) as error:
                receipt.update(status="fail",cleanup_error=str(error))
        (output/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    return receipt


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot",type=Path,default=GODOT)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--viewport",choices=["desktop","touch","both"],default="both")
    args=parser.parse_args()
    output=args.output.resolve()
    if output.exists(): parser.error("output must be a fresh directory")
    godot=args.godot.resolve(strict=True)
    for viewport in (["desktop","touch"] if args.viewport=="both" else [args.viewport]):
        receipt=verify(godot,output/viewport,viewport)
        print(json.dumps(receipt),flush=True)
        if receipt["status"]!="pass": return 1
    return 0


if __name__=="__main__":
    raise SystemExit(main())
