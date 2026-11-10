"""Check a completed incremental voice batch against its frozen inputs."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "outputs/AshenOathTheRoadBetweenCrowns"
OUT = ROOT / ".release-gate/stages234"
sys.path.insert(0, str(GAME / "tools"))
from story_voice_catalog import canonical_speaker


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def require(condition, message):
    if not condition:
        raise ValueError(message)


def finish(batch, recovered=False):
    prefix = OUT / f"voice-batch-{batch:03d}"
    before = read(prefix.with_name(prefix.name + "-before.json"))
    process_suffix = "-recovery-process.json" if recovered else "-process.json"
    process = read(prefix.with_name(prefix.name + process_suffix))
    require(process["exit_code"] == 0 and not process["timed_out"] and process["owned_process_exited"], "Production did not complete")
    require(process["sources_unchanged"] and process["previous_delivered_bytes_unchanged"], "Production inputs changed")
    manifest_path = GAME / "voice_production_manifest.json"
    require(digest(manifest_path) == process["manifest_sha256"], "Manifest changed after production")
    manifest = read(manifest_path)
    all_files = {file.relative_to(GAME).as_posix(): file for directory in ("living_cast", "community")
                 for file in (GAME / "assets_external/audio/voices" / directory).glob("*.ogg")}
    require(all(name in all_files and digest(all_files[name]) == expected for name, expected in before["files"].items()), "Existing audio changed")
    require(all(digest(ROOT / name) == expected for name, expected in before["source_inputs"].items()), "Frozen source bytes changed")
    new = sorted(set(all_files) - set(before["files"]))
    require(bool(new) and len(new) <= manifest["batch_new_recording_limit"], "Unexpected recording count")
    pending = len(manifest["pending_recordings"])
    require(pending == before["pending_before"] - len(new), "Pending recording count does not reconcile")
    catalog_paths = [ROOT / name for name, expected in before["source_inputs"].items()
                     if Path(name).name.startswith("runtime_voice_catalog_") and expected == before["catalog_sha256"]]
    require(len(catalog_paths) == 1, "Exact runtime catalog is not bound to the batch")
    catalog = read(catalog_paths[0])
    keys = {(canonical_speaker(GAME, line["speaker_id"]), line["text"]) for line in manifest["lines"]
            if line.get("path", "").removeprefix("res://") in new}
    selected = [line for line in catalog["lines"] if line.get("required_new_or_recipe_changed")
                and (line["canonical_speaker"], line["text"]) in keys]
    require(len(keys) == len(new) and {(line["canonical_speaker"], line["text"]) for line in selected} == keys,
            "New audio does not map to distinct exact required utterances")
    total_bytes = sum(file.stat().st_size for file in all_files.values())
    require(total_bytes <= 16 * 1024 * 1024 and total_bytes == manifest["new_dialogue_bytes"], "New voice payload size mismatch or limit exceeded")
    catalog_path, delivery_path, receipt_path = [prefix.with_name(prefix.name + suffix) for suffix in ("-catalog.json", "-delivery.json", "-receipt.json")]
    require(not any(path.exists() for path in (catalog_path, delivery_path, receipt_path)), "Preserve the existing delivery evidence")
    catalog_path.write_text(json.dumps({"scope": "New exact runtime utterances in this batch", "lines": selected}, indent=2) + "\n", encoding="utf-8")
    subprocess.run([sys.executable, str(GAME / "tools/verify_living_voice_delivery.py"), "--catalog", str(catalog_path),
                    "--output", str(delivery_path), "--retained-assets-from", "D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns",
                    "--runtime", "C:/Users/User/.cache/ashenoath-voice-living-cast/runtime"], cwd=GAME, check=True)
    delivery = read(delivery_path)
    require(delivery["status"] == "pass" and delivery["decoded_recordings"] == len(new), "Incomplete delivery verification")
    receipt = {"synthesized": len(new), "pending": pending, "total_new_recordings": len(all_files), "new_voice_bytes_total": total_bytes,
               "manifest_sha256": digest(manifest_path), "previous_batch_bytes_unchanged": True,
               "listening_acceptance": False, "gameplay_acceptance": False,
               "files": [{"path": name, "bytes": all_files[name].stat().st_size, "sha256": digest(all_files[name])} for name in new]}
    receipt["new_bytes_this_batch"] = sum(row["bytes"] for row in receipt["files"])
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in receipt.items() if key != "files"}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("batch", type=int)
    parser.add_argument("--recovered", action="store_true")
    args = parser.parse_args()
    finish(args.batch, args.recovered)
