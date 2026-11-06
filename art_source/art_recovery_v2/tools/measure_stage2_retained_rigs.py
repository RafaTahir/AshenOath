"""Read retained production GLBs without an engine; never change source assets.

This is rest-geometry planning evidence. Native Idle and final authored surface
contacts still require the Blender and Godot fixtures before acceptance.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
ASSETS = {
    "C11": ("nessa", 1.66), "C05": ("elna", 1.66),
    "C06": ("toma", 1.72), "C12": ("nera", 1.69),
    "C07": ("senn", 1.75), "C09": ("vale", 1.66),
    "C10": ("merrow", 1.82), "C08": ("edric", 1.82),
}


def node_matrix(node):
    if "matrix" in node:
        return np.array(node["matrix"]).reshape((4, 4)).T
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    result = np.eye(4)
    result[:3, :3] = np.array([
        [1-2*y*y-2*z*z, 2*x*y-2*z*w, 2*x*z+2*y*w],
        [2*x*y+2*z*w, 1-2*x*x-2*z*z, 2*y*z-2*x*w],
        [2*x*z-2*y*w, 2*y*z+2*x*w, 1-2*x*x-2*y*y],
    ]) @ np.diag(node.get("scale", [1, 1, 1]))
    result[:3, 3] = node.get("translation", [0, 0, 0])
    return result


def measure(game):
    registry = json.loads((game / "data/design_pack_assets.json").read_text())
    cast = json.loads((game / "data/design_pack_cast.json").read_text())
    rows = []
    for asset, (identity, target_height) in ASSETS.items():
        entry = registry["assets"][asset]
        path = game / entry["path"].removeprefix("res://")
        raw = path.read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        bounds = entry["authored_bind_bounds"]
        if digest != bounds["asset_sha256"]:
            raise ValueError(f"Stale retained bounds for {asset}")
        json_length, chunk_type = struct.unpack_from("<II", raw, 12)
        if chunk_type != 0x4E4F534A:
            raise ValueError("GLB must start with JSON")
        doc = json.loads(raw[20:20+json_length])
        nodes = doc["nodes"]
        by_name = {node.get("name"): index for index, node in enumerate(nodes)}
        parents = {child: index for index, node in enumerate(nodes)
                   for child in node.get("children", [])}
        worlds = {}

        def world(index):
            if index not in worlds:
                local = node_matrix(nodes[index])
                worlds[index] = world(parents[index]) @ local if index in parents else local
            return worlds[index]

        scale = target_height / bounds["size"][1]
        low = np.array(bounds["position"])
        size = np.array(bounds["size"])
        origin = low + size * [.5, 0, .5]

        def point(name):
            p = (world(by_name[name])[:3, 3] - origin) * scale
            # Actor presentation applies +180 degrees around Y. Report the
            # authoring convention: lateral, forward (-Godot Z), height.
            return np.array([-p[0], p[2], p[1]])

        points = {name: point(name).tolist() for name in (
            "spine_01", "spine_02", "spine_03", "Head", "upperarm_l", "upperarm_r",
            "lowerarm_l", "lowerarm_r", "hand_l", "hand_r", "foot_l", "foot_r")}
        arms = {}
        for side, sign in (("l", -1), ("r", 1)):
            shoulder, elbow, hand = [point(name + "_" + side)
                                     for name in ("upperarm", "lowerarm", "hand")]
            lengths = [float(np.linalg.norm(elbow-shoulder)), float(np.linalg.norm(hand-elbow))]
            goal = np.array([sign*.12, .40, 1.10 if asset == "C12" else 1.02])
            arms[side] = {
                "upper_length_m": lengths[0], "lower_length_m": lengths[1],
                "total_length_m": sum(lengths), "proposed_surface_lateral_forward_height": goal.tolist(),
                "rest_origin_reach_m": float(np.linalg.norm(goal-shoulder)),
                "note": "Rest-origin estimate only; a measured palm offset and authored native shoulder pose decide acceptance.",
            }
        aliases = [key for key, value in cast.get("legacy_cast", {}).items()
                   if value == identity or isinstance(value, dict) and value.get("canonical") == identity]
        rows.append({
            "asset": asset, "identity": identity, "production_resource": entry["path"],
            "source_sha256": digest, "source_bytes": len(raw), "target_height_m": target_height,
            "normalization_scale": scale, "bind_bounds": bounds, "bone_count": len(doc["skins"][0]["joints"]),
            "source_animation_count": len(doc.get("animations", [])), "rest_points_lateral_forward_height": points,
            "arms": arms, "aliases": aliases,
            "garment_clearance_preexisting_m": bounds.get("garment_arm_clearance_m", 0),
        })
    return {"schema_version": 1, "status": "rest_measurements_only", "source_game": str(game),
            "runtime_verified": False, "visual_accepted": False, "actors": rows}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-game", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "evidence/living_cast_stage2_20261107/rest_geometry.json")
    args = parser.parse_args()
    result = measure(args.source_game)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    for row in result["actors"]:
        print(row["asset"], row["identity"], "arm lengths", {side: round(value["total_length_m"], 4)
              for side, value in row["arms"].items()}, "scale", round(row["normalization_scale"], 6))
