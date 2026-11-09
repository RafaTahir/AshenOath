"""Queued real-HUD input policy comparison; headless controls, no game/world."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "outputs/AshenOathTheRoadBetweenCrowns"
GODOT = Path(r"C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe")
BAD = re.compile(r"SCRIPT ERROR|Parse Error|(?:^|\n)ERROR:|ObjectDB instances leaked|resources still in use", re.I)
EXPECTED = {"Touch scrolling did not expose the requested menu action",
            "Screen presses/scrolls reach only the two requested menu buttons",
            "Real styled menu/dialogue rows scroll through native dispatch",
            "Native ScrollContainer receives the emulated motion originating from screen drag"}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path,default=ROOT / ".verification/motion/full_touch_contract_r4")
    parser.add_argument("--held-diagnostic",action="store_true",help="parse the instrumented fixture and run current policy only")
    args=parser.parse_args()
    output = args.output.resolve()
    output.mkdir(exist_ok=False)
    original_folder = ROOT / ".verification/motion/styled_touch_inputs_r1"
    baseline = original_folder / "original_hud_style.gd"
    original_receipt = json.loads((original_folder / "receipt.json").read_text())
    if hashlib.sha256(baseline.read_bytes()).hexdigest() != original_receipt["original_style_sha256"]:
        raise ValueError("original styled baseline changed")
    source_paths = [GAME / row["path"] for row in original_receipt["resources"]]
    source_paths += [GAME / "tools/community_touch_input.gd", GAME / "tools/verify_community_touch_input.gd", baseline, Path(__file__)]
    sources = [{"path":str(path),"sha256":hashlib.sha256(path.read_bytes()).hexdigest()} for path in source_paths]
    environment = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA"):
        folder = output / key.lower()
        folder.mkdir()
        environment[key] = str(folder)
    jobs = [("style_parse", GAME / "scripts/hud/hud_style.gd", "parse"),
            ("fixture_parse", GAME / "tools/verify_community_touch_input.gd", "parse"),
            ("original_policy", GAME / "tools/verify_community_touch_input.gd", "original"),
            ("fixed_policy", GAME / "tools/verify_community_touch_input.gd", "fixed")]
    if args.held_diagnostic: jobs=[jobs[1],jobs[3]]
    receipt = {"scope":"real_hud_builder_native_dispatch_comparison", "world_instantiated":False,
               "renderer":"headless", "gameplay_acceptance":False,"physical_phone_coverage":False,"sources":sources,"runs":[],"passed":False,"held_diagnostic":args.held_diagnostic}
    for label, path, kind in jobs:
        command = [str(GODOT), "--headless", "--path", str(GAME), "--script", str(path)]
        if kind == "parse": command += ["--check-only"]
        if kind == "original": command += ["--", "--original-style=" + baseline.as_posix()]
        log = output / (label + ".log")
        with log.open("wb") as stream:
            process = subprocess.Popen(command, cwd=GAME, env=environment, stdout=stream, stderr=subprocess.STDOUT,
                                       creationflags=subprocess.CREATE_NO_WINDOW if os.name=="nt" else 0)
            timeout = False
            try:
                code = process.wait(timeout=45)
            except subprocess.TimeoutExpired:
                timeout = True
            finally:
                if process.poll() is None: process.kill()
                code = process.wait(timeout=10)
        content = log.read_text(encoding="utf-8", errors="replace")
        lines = [line.removeprefix("COMMUNITY_TOUCH_INPUT ") for line in content.splitlines() if line.startswith("COMMUNITY_TOUCH_INPUT ")]
        result = json.loads(lines[-1]) if lines else {}
        if kind == "original":
            passed = (not timeout and code == 1 and result.get("actual_hud_builders") is True and result.get("original_style") is True
                      and set(result.get("failures", [])) == EXPECTED and result.get("actions", {}).get("scroll_gestures")
                      and all(row["before"] == row["after"] == 0 for row in result["actions"]["scroll_gestures"])
                      and not any(row["type"] == "ScrollContainer" for row in result.get("gui_events", []))
                      and not re.search(r"SCRIPT ERROR|Parse Error|ObjectDB instances leaked|resources still in use", content, re.I)
                      and len(re.findall(r"(?m)^ERROR:", content)) == len(EXPECTED))
        else:
            passed = code == 0 and not timeout and not BAD.search(content)
            if kind == "fixed":
                surfaces = result.get("ui_surfaces", {})
                passed = (passed and result.get("status") == "pass" and result.get("actual_hud_builders") is True
                          and result.get("original_style") is False and set(surfaces) == {"menu","dialogue"}
                          and all(row.get("clicked") == [name+" Target 0",name+" Target 5"]
                                  and row.get("scrolled") is True and row.get("native_motion") is True
                                  and row.get("gameplay_requests") == 0 for name,row in surfaces.items()))
        row = {"label":label,"command":command,"pid":process.pid,"exit_code":code,"timed_out":timeout,
               "passed":bool(passed),"expected_original_failure":kind=="original","log":str(log),"dispatch":result}
        receipt["runs"].append(row)
        print(json.dumps({key:value for key,value in row.items() if key!="dispatch"}), flush=True)
        if not passed:
            print(content[:6000], flush=True)
            break
    stable = all(hashlib.sha256(Path(row["path"]).read_bytes()).hexdigest() == row["sha256"] for row in sources)
    receipt["sources_unchanged"] = stable
    receipt["passed"] = stable and len(receipt["runs"]) == len(jobs) and all(row["passed"] for row in receipt["runs"])
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2)+"\n", encoding="utf-8")
    return 0 if receipt["passed"] else 1


if __name__ == "__main__": sys.exit(main())
