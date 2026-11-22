"""Author a grounded cursed-human on the retained CC0 Universal skin/rig.

Geometry, not a runtime overlay, owns the gaunt anatomy and burial shroud.
The existing 65-bone bind contract and non-root-motion library are unchanged.
"""

from __future__ import annotations

import hashlib
import json
import math
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageOps

from build_opening_character_assemblies import accessor_bytes, append_compact_accessor, merge_skinned_primitives

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets_external/characters_universal"
OUTPUT = SOURCE / "runtime"
NAME = "Ghoulkin_Authored_Atlas"
DTYPES = {5121: "u1", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read_array(doc: dict, binary: bytes, index: int) -> np.ndarray:
    accessor = doc["accessors"][index]
    return np.frombuffer(accessor_bytes(doc, binary, index), dtype=DTYPES[accessor["componentType"]]).reshape(-1, WIDTHS[accessor["type"]]).copy()


def put_array(doc: dict, binary: bytearray, values: np.ndarray, kind: str, component: int = 5126) -> int:
    values = np.asarray(values, dtype=DTYPES[component])
    return append_compact_accessor(
        doc, binary, doc["bufferViews"], doc["accessors"], values.tobytes(),
        {"componentType": component, "type": kind}, len(values),
        34963 if kind == "SCALAR" else 34962,
        values.min(axis=0).tolist() if kind == "VEC3" else None,
        values.max(axis=0).tolist() if kind == "VEC3" else None,
    )


def normals(points: np.ndarray, indices: np.ndarray) -> np.ndarray:
    triangles = indices.reshape(-1, 3)
    result = np.zeros_like(points)
    faces = np.cross(points[triangles[:, 1]] - points[triangles[:, 0]], points[triangles[:, 2]] - points[triangles[:, 0]])
    for corner in range(3):
        np.add.at(result, triangles[:, corner], faces)
    lengths = np.linalg.norm(result, axis=1, keepdims=True)
    return result / np.maximum(lengths, 1e-8)


def sculpt(points: np.ndarray, joints: np.ndarray, weights: np.ndarray, centers: np.ndarray, names: list[str]) -> np.ndarray:
    result = np.zeros_like(points)
    # Contract the flesh around its own bone, not around the world origin.
    # This preserves wrists, elbows, knees and skin continuity in motion.
    for slot in range(4):
        for bone_index, name in enumerate(names):
            mask = (joints[:, slot] == bone_index) & (weights[:, slot] > 0)
            if not np.any(mask):
                continue
            p = points[mask]
            center = centers[bone_index]
            scale = np.ones(3)
            if name.startswith("spine") or name == "pelvis":
                scale = np.array([0.71, 1.0, 0.72])
            elif name.startswith(("thigh", "calf")):
                scale = np.array([0.70, 1.0, 0.70])
            elif name.startswith(("upperarm", "lowerarm")):
                scale = np.array([1.0, 0.66, 0.66])
            elif name == "Head":
                scale = np.array([0.84, 1.0, 0.94])
            elif name.startswith(("index", "middle", "ring", "pinky", "thumb")):
                scale = np.array([1.55, 0.75, 0.75])
            local = center + (p - center) * scale
            result[mask] += local * weights[mask, slot, None]
    # A continuous forward curl across chest/neck/head, shared by all skin parts.
    curl = np.clip((points[:, 1] - 1.08) / 0.62, 0.0, 1.0)
    result[:, 2] += 0.16 * curl * curl
    result[:, 1] -= 0.095 * curl
    return result


def make_atlas() -> None:
    atlas = Image.new("RGB", (1024, 1024), (37, 40, 34))
    body = Image.open(SOURCE / "T_Superhero_Male_Dark.png").convert("RGB").resize((768, 768), Image.Resampling.LANCZOS)
    grey = ImageOps.grayscale(body)
    body = ImageOps.colorize(grey, (31, 39, 36), (171, 176, 145))
    draw = ImageDraw.Draw(body)
    # Native UV face: sunk sockets, a silenced mouth and the broken oath scar.
    for x in (100, 179):
        draw.ellipse((x - 15, 113, x + 15, 148), fill=(27, 31, 26))
    draw.line([(137, 184), (150, 199), (173, 204)], fill=(70, 38, 33), width=5)
    draw.line([(119, 202), (163, 204)], fill=(33, 34, 29), width=4)
    for x in range(125, 160, 9):
        draw.line([(x, 198), (x + 2, 209)], fill=(74, 70, 53), width=2)
    # Old slash scars on the mapped chest, not alpha decals or extra surfaces.
    for x, y in ((218, 395), (546, 258), (391, 482)):
        draw.line([(x, y), (x + 19, y + 24), (x + 34, y + 30)], fill=(71, 60, 46), width=3)
    atlas.paste(body, (0, 0))
    hair = Image.new("RGB", (128, 128), (39, 41, 34))
    atlas.paste(hair, (768, 0))
    eyes = Image.new("RGB", (128, 128), (119, 111, 60))
    eye_draw = ImageDraw.Draw(eyes)
    eye_draw.ellipse((44, 30, 86, 96), fill=(21, 24, 21))
    atlas.paste(eyes, (896, 0))
    cloth = Image.new("RGB", (256, 256), (49, 51, 43))
    cloth_draw = ImageDraw.Draw(cloth)
    for x in range(0, 256, 9):
        cloth_draw.line([(x, 0), (x + 3, 256)], fill=(58, 59, 49), width=2)
    for y in (46, 109, 186):
        cloth_draw.line([(0, y), (256, y + 12)], fill=(28, 33, 30), width=3)
    atlas.paste(cloth, (768, 128))
    atlas.save(OUTPUT / f"{NAME}.png", optimize=True)


def append_cloth(doc: dict, binary: bytearray, names: list[str]) -> None:
    points, uvs, joints, weights, indices = [], [], [], [], []
    bone = {name: index for index, name in enumerate(names)}

    def rings(levels: list[tuple], start: float, end: float, segments: int, hood: bool = False) -> None:
        offset = len(points)
        for row, (y, rx, rz, cz) in enumerate(levels):
            for column in range(segments + 1):
                angle = start + (end - start) * column / segments
                hem = 0.035 * math.sin(column * 2.7) if row == len(levels) - 1 else 0.0
                points.append((rx * math.sin(angle), y + hem, cz + rz * math.cos(angle)))
                uvs.append((0.756 + 0.237 * column / segments, 0.134 + 0.233 * row / (len(levels) - 1)))
                if hood:
                    blend = min(1.0, max(0.0, (y - 1.38) / 0.31))
                    joints.append((bone["Head"], bone["spine_03"], 0, 0))
                    weights.append((blend, 1.0 - blend, 0, 0))
                else:
                    thigh = "thigh_l" if math.sin(angle) > 0 else "thigh_r"
                    blend = min(0.85, max(0.0, (0.99 - y) / 0.5))
                    joints.append((bone["pelvis"], bone[thigh], 0, 0))
                    weights.append((1.0 - blend, blend, 0, 0))
        for row in range(len(levels) - 1):
            for column in range(segments):
                a = offset + row * (segments + 1) + column
                b = a + segments + 1
                indices.extend((a, b, a + 1, a + 1, b, b + 1))

    # An open-front sewn cowl leaves native eyes, jaw and neck visible.
    rings([(1.83, 0.085, 0.09, 0.065), (1.70, 0.14, 0.135, 0.05), (1.53, 0.18, 0.13, 0.03), (1.40, 0.25, 0.13, 0.015)], 0.92, 2 * math.pi - 0.92, 18, True)
    rings([(1.01, 0.18, 0.115, -0.01), (0.86, 0.205, 0.12, -0.01), (0.65, 0.23, 0.145, -0.01), (0.49, 0.245, 0.14, -0.01)], 0, 2 * math.pi, 24)
    p = np.asarray(points, dtype="<f4")
    idx = np.asarray(indices, dtype="<u4").reshape(-1, 1)
    primitive = {"mode": 4, "material": 0, "attributes": {
        "POSITION": put_array(doc, binary, p, "VEC3"),
        "NORMAL": put_array(doc, binary, normals(p, idx), "VEC3"),
        "TEXCOORD_0": put_array(doc, binary, np.array(uvs), "VEC2"),
        "JOINTS_0": put_array(doc, binary, np.array(joints), "VEC4", doc["accessors"][doc["meshes"][0]["primitives"][0]["attributes"]["JOINTS_0"]]["componentType"]),
        "WEIGHTS_0": put_array(doc, binary, np.array(weights), "VEC4"),
    }, "indices": put_array(doc, binary, idx, "SCALAR", 5125)}
    doc["meshes"].append({"name": "Sewn_Burial_Shroud", "primitives": [primitive]})


def main() -> None:
    source_path = SOURCE / "Superhero_Male_FullBody.gltf"
    doc = json.loads(source_path.read_text(encoding="utf-8"))
    binary = bytearray((SOURCE / doc["buffers"][0]["uri"]).read_bytes())
    names = [doc["nodes"][index]["name"] for index in doc["skins"][0]["joints"]]
    inverse_binds = read_array(doc, binary, doc["skins"][0]["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
    centers = np.linalg.inv(inverse_binds)[:, :3, 3]
    atlas_tiles = {0: (0.75, 0, 0.125, 0.125), 1: (0.875, 0, 0.125, 0.125), 2: (0, 0, 0.75, 0.75)}
    source_vertices = 0
    for mesh in doc["meshes"]:
        for primitive in mesh["primitives"]:
            attrs = primitive["attributes"]
            points = read_array(doc, binary, attrs["POSITION"])
            joints = read_array(doc, binary, attrs["JOINTS_0"])
            weights = read_array(doc, binary, attrs["WEIGHTS_0"])
            if not np.allclose(weights.sum(axis=1), 1.0, atol=0.001):
                raise ValueError("source skin weights are not normalized")
            points = sculpt(points, joints, weights, centers, names)
            source_vertices += len(points)
            idx = read_array(doc, binary, primitive["indices"])
            uv = read_array(doc, binary, attrs["TEXCOORD_0"])
            ox, oy, sx, sy = atlas_tiles[primitive["material"]]
            uv[:, 0] = ox + uv[:, 0] * sx
            uv[:, 1] = oy + uv[:, 1] * sy
            attrs["POSITION"] = put_array(doc, binary, points, "VEC3")
            attrs["NORMAL"] = put_array(doc, binary, normals(points, idx), "VEC3")
            attrs["TEXCOORD_0"] = put_array(doc, binary, uv, "VEC2")
    append_cloth(doc, binary, names)
    binary = merge_skinned_primitives(doc, binary, "Ghoulkin_Authored")
    doc["asset"]["generator"] = "Ashen Oath grounded Ghoulkin authoring pipeline"
    doc["buffers"] = [{"uri": f"{NAME}.bin", "byteLength": len(binary)}]
    doc["images"] = [{"uri": f"{NAME}.png"}]
    doc["textures"] = [{"sampler": 0, "source": 0}]
    doc["samplers"] = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 33071, "wrapT": 33071}]
    doc["materials"] = [{"name": "Ash_Skin_And_Burial_Cloth", "doubleSided": True, "pbrMetallicRoughness": {
        "baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 0.91,
    }}]
    OUTPUT.mkdir(parents=True, exist_ok=True)
    make_atlas()
    (OUTPUT / f"{NAME}.bin").write_bytes(binary)
    (OUTPUT / f"{NAME}.gltf").write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    manifest = {
        "role": "ghoulkin_creature", "state": "authored_geometry_build_only",
        "source": "res://assets_external/characters_universal/Superhero_Male_FullBody.gltf",
        "source_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
        "license": "CC0 1.0", "license_file": "res://assets_external/licenses/Quaternius_Universal_Base_Characters_CC0.txt",
        "changes": ["bone-local gaunt anatomy", "continuous forward curl", "elongated native fingers", "skinned torn burial shroud", "scarred ash skin atlas"],
        "bones": len(names), "source_vertices": source_vertices,
        "triangles": doc["accessors"][doc["meshes"][0]["primitives"][0]["indices"]]["count"] // 3,
        "materials": 1, "surfaces": 1, "textures": [1024, 1024],
        "files": {f"{NAME}.{suffix}": {"bytes": (OUTPUT / f"{NAME}.{suffix}").stat().st_size, "sha256": hashlib.sha256((OUTPUT / f"{NAME}.{suffix}").read_bytes()).hexdigest()} for suffix in ("gltf", "bin", "png")},
    }
    (OUTPUT / "GROUNDED_GHOULKIN_MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
