"""Extract exactly eight catalog-matching prepared scenes; never mount old code."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT.parents[1]/"outputs/AshenOathTheRoadBetweenCrowns"
sys.path.insert(0, str(GAME/"tools"))
from compact_runtime_packs import parse_archive
from living_cast_stage2_profiles import PROFILES


def main(folder):
    catalog = json.loads((GAME/"data/prepared_actors.json").read_text())
    records = []
    for asset in PROFILES:
        row = next(value for value in catalog.values() if "/"+asset+"_" in value.get("source", ""))
        source = folder/("actor_"+asset.lower()+".pck")
        raw = source.read_bytes()
        archive = parse_archive(raw)
        relative = row["path"][6:]
        entry = next(value for value in archive.entries if value.path == relative)
        digest = hashlib.sha256(entry.payload).hexdigest()
        if digest != row["compiled_sha256"]:
            raise ValueError("Frozen scene differs from isolated catalog: "+asset)
        target = (GAME/relative).resolve()
        if not target.is_relative_to(GAME.resolve()):
            raise ValueError("Frozen actor path escapes isolated project")
        if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            raise ValueError("Refusing to replace isolated authored scene: "+relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            target.write_bytes(entry.payload)
        records.append({"asset": asset, "resource": row["path"], "sha256": digest,
                        "bytes": len(entry.payload), "frozen_pack": str(source),
                        "frozen_pack_sha256": hashlib.sha256(raw).hexdigest(),
                        "catalog_match": True})
    output = ROOT/"evidence/living_cast_stage2_20261107/frozen_prepared_inputs.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({"schema_version": 1, "old_code_mounted": False,
        "files": records, "total_bytes": sum(row["bytes"] for row in records)}, indent=2)+"\n")
    print("FROZEN_ACTOR_INPUTS", len(records), sum(row["bytes"] for row in records), "bytes; all catalog hashes match")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--frozen-packs", required=True, type=Path)
    main(parser.parse_args().frozen_packs)
