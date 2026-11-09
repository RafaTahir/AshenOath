"""Verify retained source provenance; optionally undo proven Git newline conversion."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main(repair, source_game=None):
    folder = ROOT/"models/living_cast_stage2_20261107/props"
    records = []
    for receipt_path in sorted(folder.glob("station_*_authoring.json")):
        receipt = json.loads(receipt_path.read_text(encoding="utf-8-sig"))
        identity = receipt["identity"]
        verified = []
        for row in receipt["recipe_snapshot"]["files"]:
            path = ROOT/row["path"]
            raw = path.read_bytes()
            recovered = False
            if sha(raw) != row["sha256"]:
                lf = raw.replace(b"\r\n", b"\n")
                options = [value for value in (lf, lf.replace(b"\n", b"\r\n")) if sha(value) == row["sha256"]]
                if not repair or not options:
                    raise ValueError("Archived recipe does not match original receipt: "+str(path))
                path.write_bytes(options[0])
                recovered = True
            verified.append({"path": row["path"], "sha256": sha(path.read_bytes()), "newline_recovered": recovered})
        files = {row["name"]: row["sha256"] for row in receipt["recipe_snapshot"]["files"]}
        if sha(json.dumps(files, sort_keys=True).encode()) != receipt["recipe_snapshot"]["sha256"]:
            raise ValueError("Recipe set identity mismatch: "+identity)
        for extension, field in ((".blend", "blend_sha256"), (".glb", "carrier_sha256")):
            path = folder/("station_"+identity+extension)
            if sha(path.read_bytes()) != receipt[field]:
                raise ValueError("Retained authored artifact changed: "+str(path))
        for source in receipt["sources"]:
            path = source_game/source["resource"][6:] if source_game else Path(source["source"])
            if sha(path.read_bytes()) != source["sha256"]:
                raise ValueError("Retained source changed: "+str(path))
        records.append({"identity": identity, "recipe_files": verified, "blend_and_carrier_verified": True,
                        "retained_source_hashes_verified": True, "receipt_unchanged": True})
    if not records:
        raise ValueError("No completed authored prop receipts found")
    output = ROOT/"evidence/living_cast_stage2_20261107/recipe_byte_verification.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({"status": "pass", "assets": records, "recorded_hashes_changed": False}, indent=2)+"\n")
    print("LIVING_CAST_RECIPE_BYTES_PASS", len(records), "authored props", sum(row["newline_recovered"] for record in records for row in record["recipe_files"]), "proven newline restorations")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--repair-newlines", action="store_true")
    parser.add_argument("--source-game", type=Path)
    args = parser.parse_args()
    main(args.repair_newlines, args.source_game)
