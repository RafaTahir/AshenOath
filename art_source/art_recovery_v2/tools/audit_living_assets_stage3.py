"""Engine-free Stage3 inventory grounded in shipped asset identities and bytes."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "evidence/living_assets_stage3_20261107"


def inspect_glb(path):
    raw = path.read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20+length])
    binary = raw[28+length:]

    def values(index):
        accessor = doc["accessors"][index]
        view = doc["bufferViews"][accessor["bufferView"]]
        if accessor["componentType"] != 5126:
            return []
        count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[accessor["type"]]
        stride = view.get("byteStride", count*4)
        offset = view.get("byteOffset", 0)+accessor.get("byteOffset", 0)
        return [struct.unpack_from("<"+"f"*count, binary, offset+i*stride) for i in range(accessor["count"])]

    clips = []
    for animation in doc.get("animations", []):
        duration, bindings, variation = 0.0, [], {}
        for channel in animation["channels"]:
            sampler = animation["samplers"][channel["sampler"]]
            times, samples = values(sampler["input"]), values(sampler["output"])
            if times:
                duration = max(duration, times[-1][0])
            target = channel["target"]
            node = doc["nodes"][target["node"]].get("name", str(target["node"]))
            binding = node+":"+target["path"]
            bindings.append(binding)
            if samples:
                variation[binding] = max(abs(value-samples[0][i]) for sample in samples for i, value in enumerate(sample))
        clips.append({"name": animation.get("name", ""), "duration_seconds": duration,
                      "bindings": bindings, "nonflat_bindings": [key for key, value in variation.items() if value > 1e-5],
                      "weight_bindings": [key for key in bindings if key.endswith(":weights")]})
    return {"sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw),
            "bones": [doc["nodes"][index].get("name", "") for skin in doc.get("skins", []) for index in skin["joints"]],
            "meshes": [{"name": mesh.get("name", ""), "morph_names": mesh.get("extras", {}).get("targetNames", []),
                        "morph_target_counts": [len(p.get("targets", [])) for p in mesh["primitives"]]} for mesh in doc.get("meshes", [])],
            "clips": clips}


def main(game):
    designs = json.loads((game/"data/design_pack_assets.json").read_text())["assets"]
    ledger = json.loads((game/"release_reports/living_cast_20261107/asset_coverage.json").read_text())
    attack = json.loads((game/"data/native_attack_profiles.json").read_text())["profiles"]
    ecology = json.loads((game/"data/design_pack_ecology.json").read_text())["sightings"]
    cast = {row["id"]: row for row in ledger["cast"]}
    rows = []
    for identity in ["P01"]+[f"M{i:02}" for i in range(1, 21)]:
        record = designs[identity]
        info = inspect_glb(game/record["path"][6:])
        if info["sha256"] != record["sha256"]:
            raise ValueError("Design registry source hash is stale: " + identity)
        info.update(id=identity, path=record["path"], pack_owners=cast[identity]["pack_owners"],
                    compiled_resources=cast[identity]["compiled_resources"], roles=cast[identity]["roles"],
                    observed_sightings=[row for row in ecology if row["design"] == identity],
                    native_attack_profile=attack.get(record["path"], {}),
                    new_life_authored=False, runtime_verified=False, user_accepted=False)
        rows.append(info)
    runtime = json.loads((game/"runtime_asset_manifest.json").read_text())
    selected_environment = {row["id"] for row in ledger["environment"]}
    environment = [row for row in runtime["authored_environment_derivatives"] if row["id"] in selected_environment]
    equipment_path = game.parents[1]/"art_source/art_recovery_v2/evidence/refinement_20261101/equipment/checklist.json"
    equipment = json.loads(equipment_path.read_text()) if equipment_path.is_file() else {}
    result = {"schema_version": 1, "source_game_read_only": str(game), "selected_export": ledger["baseline"],
              "creatures_and_player": rows, "selected_authored_environment": environment,
              "held_equipment_checklist": equipment,
              "policy": "Current byte/rig facts only; new source changes require recalibrated native attack profiles even if Attack curves are retained.",
              "counts": {"player_and_creatures": len(rows), "equipment_entries": len(equipment.get("assets", [])),
                         "selected_environment_derivatives": len(environment)}}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT/"retained_source_inventory.json").write_text(json.dumps(result, indent=2)+"\n")
    print(json.dumps(result["counts"]))
    for row in rows:
        print(row["id"], "bones", len(row["bones"]), "clips", ",".join(clip["name"] for clip in row["clips"]),
              "morphs", [name for mesh in row["meshes"] for name in mesh["morph_names"]])


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-game", required=True, type=Path)
    main(parser.parse_args().source_game)
