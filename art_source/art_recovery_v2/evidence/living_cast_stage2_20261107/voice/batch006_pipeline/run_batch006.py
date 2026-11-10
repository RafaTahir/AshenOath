"""Bounded voice batch 006; requires the parent-owned serial production window."""
from pathlib import Path
import datetime
import hashlib
import json
import os
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "outputs/AshenOathTheRoadBetweenCrowns"
OUT = ROOT / ".release-gate/stages234"
CACHE = Path("C:/Users/User/.cache/ashenoath-voice-living-cast")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    before = json.loads((OUT / "voice-batch-006-before.json").read_text())
    manifest = GAME / "voice_production_manifest.json"
    if sha(manifest) != before["manifest_sha256"]:
        raise ValueError("Voice manifest changed after batch preparation")
    if any(sha(GAME / name) != digest for name, digest in before["files"].items()):
        raise ValueError("Previously delivered audio changed before production")
    if any(sha(ROOT / name) != digest for name, digest in before["source_inputs"].items()):
        raise ValueError("Voice production source changed before batch")
    deadline = datetime.datetime.fromisoformat(json.loads((OUT / "progress.json").read_text())["asset_window_deadline_utc"])
    if (deadline - datetime.datetime.now(datetime.timezone.utc)).total_seconds() < 620:
        raise ValueError("Not enough time remains in the explicit production window")
    receipt_path = OUT / "voice-batch-006-process.json"
    log = OUT / "voice-batch-006.log"
    if receipt_path.exists() or log.exists():
        raise ValueError("Prior batch execution exists; preserve and inspect it")
    command = [sys.executable, str(GAME / "tools/natural_story_voices.py"),
               "--runtime", str(CACHE / "runtime"), "--models", str(CACHE / "models"),
               "--recipes", str(CACHE / "recipes"), "--incremental", "--baseline-ref", "02d0341",
               "--new-directory", "living_cast", "--retained-assets-from",
               "D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns",
               "--threads", "1", "--max-new-recordings", "25"]
    environment = os.environ.copy()
    environment.update(OMP_NUM_THREADS="1", MKL_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1")
    started = time.monotonic()
    timed_out = False
    with log.open("wb") as stream:
        child = subprocess.Popen(command, cwd=GAME, env=environment, stdout=stream,
                                 stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        print(json.dumps({"batch": "006", "pid": child.pid, "timeout_seconds": 600}), flush=True)
        try:
            child.wait(timeout=600)
        except subprocess.TimeoutExpired:
            timed_out = True
            child.kill()
            child.wait(timeout=15)
    prior_unchanged = all(sha(GAME / name) == digest for name, digest in before["files"].items())
    source_unchanged = all(sha(ROOT / name) == digest for name, digest in before["source_inputs"].items())
    receipt = {"batch": "006", "command": command, "runner_sha256": sha(Path(__file__)),
               "pid": child.pid, "exit_code": child.returncode, "timed_out": timed_out,
               "owned_process_exited": child.poll() is not None, "seconds": round(time.monotonic()-started, 3),
               "previous_delivered_bytes_unchanged": prior_unchanged, "sources_unchanged": source_unchanged,
               "manifest_sha256": sha(manifest), "log": str(log),
               "delivery_verified": False, "listening_acceptance": False, "gameplay_acceptance": False}
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(receipt), flush=True)
    return 0 if child.returncode == 0 and not timed_out and prior_unchanged and source_unchanged else 1


if __name__ == "__main__":
    raise SystemExit(main())
