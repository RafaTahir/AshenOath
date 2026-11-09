"""Run only under an explicit serial-engine grant; preserve old memorial bytes."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "outputs/AshenOathTheRoadBetweenCrowns"
GODOT = Path("C:/Users/User/.cache/codex-runtimes/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe")
LEGACY = ("witness", "mercy", "duty", "ash")
NEW = ("concord", "open_road")
BAD = re.compile(r"SCRIPT ERROR|Parse Error|(?:^|\n)ERROR:|ObjectDB instances leaked|resources still in use", re.I)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def asset(covenant):
    return GAME / f"assets_external/environment/forest/HartAftermath_{covenant}_Authored.res"


def row(path):
    return {"path":str(path), "sha256":sha(path), "bytes":path.stat().st_size}


def stable(rows):
    return all(Path(item["path"]).is_file() and sha(Path(item["path"])) == item["sha256"] for item in rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z0-9_-]+", args.label):
        parser.error("label must be a simple new evidence-directory name")
    output = Path(__file__).parent / args.label
    output.mkdir(exist_ok=False)
    source_paths = [Path(__file__), GODOT, GAME / "project.godot", GAME / ".godot/global_script_class_cache.cfg"]
    source_paths += [GAME / path for path in ("tools/build_hart_aftermath.gd", "tools/build_hart_landscape.gd",
                    "tools/verify_hart_aftermath_assets.gd", "scripts/ending_catalog.gd", "scripts/campaign_revision.gd")]
    sources = [row(path) for path in source_paths]
    legacy = [row(asset(covenant)) for covenant in LEGACY]
    before_new = []
    for covenant in NEW:
        path = asset(covenant)
        if path.exists():
            record = row(path)
            retained = output / (covenant + "_before.res")
            retained.write_bytes(path.read_bytes())
            record["retained_copy"] = str(retained)
            before_new.append(record)
    environment = os.environ.copy()
    for name in ("APPDATA", "LOCALAPPDATA"):
        folder = output / name.lower()
        folder.mkdir()
        environment[name] = str(folder)
    jobs = [("builder_parse", "tools/build_hart_aftermath.gd", True, []),
            ("fixture_parse", "tools/verify_hart_aftermath_assets.gd", True, []),
            ("build_only_new", "tools/build_hart_aftermath.gd", False, ["--only-new"]),
            ("validate_all_six", "tools/verify_hart_aftermath_assets.gd", False, [])]
    receipt = {"kind":"new_hart_memorial_resources", "sources":sources, "legacy_before":legacy,
               "new_before":before_new, "runs":[], "passed":False, "visual_acceptance":False,
               "enactment_verified":False, "gameplay_acceptance":False}
    receipt_path = output / "receipt.json"
    def save():
        receipt_path.write_text(json.dumps(receipt, indent=2)+"\n", encoding="utf-8")
    save()
    try:
        for label, script, parse_only, arguments in jobs:
            if not stable(sources + legacy):
                raise ValueError("Source or retained legacy memorial changed")
            command = [str(GODOT), "--headless", "--path", str(GAME), "--script", "res://"+script]
            if parse_only:
                command += ["--check-only"]
            if arguments:
                command += ["--", *arguments]
            log = output / (label+".log")
            run = {"label":label, "command":command, "log":str(log), "passed":False, "timed_out":False}
            receipt["runs"].append(run)
            process = None
            started = time.monotonic()
            try:
                with log.open("xb") as stream:
                    process = subprocess.Popen(command, cwd=GAME, env=environment, stdout=stream,
                                               stderr=subprocess.STDOUT,
                                               creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
                    run["pid"] = process.pid
                    save()
                    try:
                        run["exit_code"] = process.wait(timeout=90)
                    except subprocess.TimeoutExpired:
                        run["timed_out"] = True
            finally:
                if process is not None:
                    if process.poll() is None:
                        process.kill()
                    run["exit_code"] = process.wait(timeout=10)
                    run["owned_process_exited"] = process.poll() is not None
                run["seconds"] = round(time.monotonic()-started, 3)
                save()
            text = log.read_text(encoding="utf-8", errors="replace")
            if run["exit_code"] != 0 or run["timed_out"] or BAD.search(text):
                raise ValueError("Native memorial step failed: "+label)
            if label == "build_only_new":
                if not all("HART AFTERMATH BAKE: "+covenant+" " in text for covenant in NEW):
                    raise ValueError("Both new memorial build markers are required")
                if any("HART AFTERMATH BAKE: "+covenant+" " in text for covenant in LEGACY):
                    raise ValueError("Only the two new memorials may be rebuilt")
            if label == "validate_all_six":
                lines = [line.removeprefix("HART_AFTERMATH_ASSETS ") for line in text.splitlines() if line.startswith("HART_AFTERMATH_ASSETS ")]
                result = json.loads(lines[-1]) if lines else {}
                if result.get("status") != "pass" or {item["covenant"] for item in result.get("resources", [])} != set(LEGACY+NEW):
                    raise ValueError("All six actual memorial resources must pass")
                receipt["resource_validation"] = result
            if not stable(sources + legacy):
                raise ValueError("Native job changed a source or legacy memorial")
            run["passed"] = True
            save()
            print(json.dumps(run), flush=True)
        receipt["new_outputs"] = [row(asset(covenant)) for covenant in NEW]
        if any(item["bytes"] >= 100*1024**2 for item in receipt["new_outputs"]):
            raise ValueError("Memorial resource exceeds the committed-file limit")
        receipt["legacy_byte_identical"] = stable(legacy)
        receipt["passed"] = True
    except BaseException as error:
        receipt["failure"] = type(error).__name__+": "+str(error)
        print(receipt["failure"], file=sys.stderr, flush=True)
    finally:
        save()
    return 0 if receipt["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
