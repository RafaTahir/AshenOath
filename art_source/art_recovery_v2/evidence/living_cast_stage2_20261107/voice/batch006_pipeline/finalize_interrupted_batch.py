"""Finalize stamped output from an exited, timed-out inference batch."""

import argparse
from datetime import datetime, timezone
import json
import os
import subprocess
import time

from finish_batch import GAME, OUT, ROOT, digest, read, require


def finalize(batch):
    prefix = OUT / f"voice-batch-{batch:03d}"
    before = read(prefix.with_name(prefix.name + "-before.json"))
    prior = read(prefix.with_name(prefix.name + "-process.json"))
    require(prior["timed_out"] and prior["owned_process_exited"], "Original inference must have timed out and exited")
    require(prior["previous_delivered_bytes_unchanged"] and prior["sources_unchanged"], "Original production inputs changed")
    manifest = GAME / "voice_production_manifest.json"
    require(digest(manifest) == prior["manifest_sha256"], "Manifest changed after timed-out run")
    require(all(digest(ROOT / name) == expected for name, expected in before["source_inputs"].items()), "Frozen sources changed")
    require(all(digest(GAME / name) == expected for name, expected in before["files"].items()), "Previous recordings changed")
    deadline = datetime.fromisoformat(read(OUT / "progress.json")["asset_window_deadline_utc"])
    require((deadline - datetime.now(timezone.utc)).total_seconds() >= 145, "Reserve finalization and cleanup time")
    result_path = prefix.with_name(prefix.name + "-recovery-process.json")
    log = prefix.with_name(prefix.name + "-recovery.log")
    require(not result_path.exists() and not log.exists(), "Existing recovery evidence must be preserved")
    command = [*prior["command"], "--finalize-existing"]
    require(command[1] == str(GAME / "tools/natural_story_voices.py"), "Unexpected original inference entry point")
    started = time.monotonic()
    timed_out = False
    with log.open("xb") as stream:
        child = subprocess.Popen(command, cwd=GAME, stdout=stream, stderr=subprocess.STDOUT,
                                 env={**os.environ, "OMP_NUM_THREADS": "1"}, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            child.wait(timeout=120)
        except subprocess.TimeoutExpired:
            timed_out = True
            child.kill()
            child.wait(timeout=15)
    result = {"batch": f"{batch:03d}", "command": command, "pid": child.pid, "exit_code": child.returncode,
              "timed_out": timed_out, "owned_process_exited": child.poll() is not None,
              "seconds": round(time.monotonic() - started, 3), "manifest_sha256": digest(manifest),
              "previous_delivered_bytes_unchanged": all(digest(GAME / name) == expected for name, expected in before["files"].items()),
              "sources_unchanged": all(digest(ROOT / name) == expected for name, expected in before["source_inputs"].items()),
              "original_process_receipt_sha256": digest(prefix.with_name(prefix.name + "-process.json")),
              "log": str(log), "inference_started": False, "delivery_verified": False}
    result_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))
    return 0 if child.returncode == 0 and not timed_out else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("batch", type=int)
    raise SystemExit(finalize(parser.parse_args().batch))
