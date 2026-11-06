"""Validate actual derivative curves and protected native bytes before compilation."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

import numpy as np

from living_creature_motion_profiles import REPLACED_CLIPS, SPECIES
from preserve_creature_action_bytes import read_glb, action_digest, accessor_bytes

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT/"models/living_assets_stage3_20261107/creatures"


def verify(asset):
    folder = MODELS/asset
    receipt = json.loads((folder/"authoring.json").read_text())
    source = Path(receipt["production_input_path"])
    candidate = folder/(asset+"_living_candidate.glb")
    source_digest = hashlib.sha256(source.read_bytes()).hexdigest()
    candidate_digest = hashlib.sha256(candidate.read_bytes()).hexdigest()
    if source_digest != receipt["production_sha256"] or candidate_digest != receipt["candidate_sha256"]:
        raise ValueError("Creature derivative no longer matches authored source bytes")
    old, old_binary = read_glb(source)
    new, new_binary = read_glb(candidate)
    previous = {clip["name"]: clip for clip in old["animations"]}
    current = {clip["name"]: clip for clip in new["animations"]}
    if set(previous) != set(current):
        raise ValueError("Creature clip identity set changed")
    signatures = {}
    for name, clip in previous.items():
        if name in REPLACED_CLIPS:
            continue
        expected = action_digest(old, old_binary, clip)
        actual = action_digest(new, new_binary, current[name])
        if expected != actual:
            raise ValueError("Protected native action samples changed: "+asset+"/"+name)
        signatures[name] = actual
    required_morphs = ["Sac0_Inflate", "Sac1_Inflate", "Sac2_Inflate"] if asset == "M15" else (
        ["AntennaProbe_L", "AntennaProbe_R", "BrushFeed_L", "BrushFeed_R"] if asset == "M16" else [])
    reports, durations = {}, {}
    for name in REPLACED_CLIPS:
        animation = current[name]
        active_morphs, active_bones = {}, []
        duration = 0.0
        for channel in animation["channels"]:
            target = channel["target"]
            sampler = animation["samplers"][channel["sampler"]]
            times = np.frombuffer(accessor_bytes(new, new_binary, sampler["input"]), dtype="<f4")
            accessor = new["accessors"][sampler["output"]]
            values = np.frombuffer(accessor_bytes(new, new_binary, sampler["output"]), dtype="<f4")
            if not np.isfinite(times).all() or not np.isfinite(values).all() or np.any(np.diff(times) <= 0):
                raise ValueError("Nonfinite or unordered creature animation samples")
            duration = max(duration, float(times[-1]))
            node = new["nodes"][target["node"]]
            if target["path"] == "weights":
                names = new["meshes"][node["mesh"]].get("extras", {}).get("targetNames", [])
                if not names or len(values) != len(times)*len(names):
                    raise ValueError("Creature morph channels must have actual named, linearly sampled mesh targets")
                values = values.reshape((len(times), len(names)))
                if np.any(values < -.0001) or np.any(values > 1.0001):
                    raise ValueError("Creature morph exceeded its retained authored envelope")
                for index, shape in enumerate(names):
                    if float(np.ptp(values[:, index])) > .0001:
                        active_morphs[shape] = node["name"]
            else:
                width = {"VEC3": 3, "VEC4": 4}[accessor["type"]]
                values = values.reshape((-1, width))
                if len(values) != len(times):
                    raise ValueError("Creature bone channels must be linearly sampled")
                variation = float(np.max(np.abs(values-values[0])))
                if node.get("name", "").lower() == "root" and variation > 1e-5:
                    raise ValueError("New ambient action moves the retained root")
                if variation > .0001:
                    active_bones.append(node["name"])
            if float(np.max(np.abs(values[0]-values[-1]))) > .0001:
                raise ValueError("Creature ambient loop does not close: "+asset+"/"+name)
        expected_duration = float(receipt["ambient_clips"][name]["duration_seconds"])
        if abs(duration-expected_duration) > 1e-5:
            raise ValueError("Creature ambient duration changed")
        if not active_bones and not active_morphs:
            raise ValueError("Creature ambient clip has no actual motion")
        if not set(required_morphs).issubset(active_morphs):
            raise ValueError("Missing or flat anatomical morph motion: "+asset+"/"+name)
        reports[name] = {"active_bones": sorted(set(active_bones)), "actual_mesh_morph_bindings": active_morphs}
        durations[name] = duration
    report = {"schema_version": 1, "asset": asset, "status": "source_contract_pass",
              "candidate_sha256": candidate_digest, "retained_source_sha256": source_digest,
              "protected_action_bytes_equal": True, "protected_action_signatures": signatures,
              "required_morphs": required_morphs, "durations": durations, "clips": reports,
              "native_prepared_binding_verified": False, "attack_recalibration_required": True,
              "visual_accepted": False, "user_accepted": False}
    (folder/"source_contract.json").write_text(json.dumps(report, indent=2)+"\n")
    print("CREATURE_SOURCE_CONTRACT_PASS", asset)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset", required=True, choices=SPECIES)
    verify(parser.parse_args().asset)
