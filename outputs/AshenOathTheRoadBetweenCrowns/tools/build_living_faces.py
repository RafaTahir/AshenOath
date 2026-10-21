"""Compile the CAST Greyfen facial sample into retained, skinned assemblies.

The source atlas and mesh topology are retained. New facial joints deform the
existing skin, brows and eyes; no detached face geometry or runtime mesh work.
"""

from __future__ import annotations

import json
import struct
from pathlib import Path

import build_opening_character_assemblies as assembly


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = assembly.OUTPUT
SAMPLE_ROLES = ("anwen", "villager_male", "villager_worker")
CONTROLS = (
    "Face_Eye_L", "Face_Eye_R", "Face_LidUpper_L", "Face_LidUpper_R",
    "Face_LidLower_L", "Face_LidLower_R", "Face_Brow_L", "Face_Brow_R",
    "Face_Mouth_L", "Face_Mouth_R", "Face_Jaw",
)


def values(document: dict, binary: bytearray, index: int) -> list[tuple]:
    accessor = document["accessors"][index]
    components = assembly.TYPE_COMPONENTS[accessor["type"]]
    code = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}[accessor["componentType"]]
    payload = assembly.accessor_bytes(document, binary, index)
    return list(struct.iter_unpack("<" + code * components, payload))


def write_values(document: dict, binary: bytearray, index: int, data: list[tuple]) -> None:
    accessor = document["accessors"][index]
    view = document["bufferViews"][accessor["bufferView"]]
    code = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}[accessor["componentType"]]
    fmt = "<" + code * assembly.TYPE_COMPONENTS[accessor["type"]]
    stride = int(view.get("byteStride", struct.calcsize(fmt)))
    offset = int(view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0))
    for i, row in enumerate(data):
        struct.pack_into(fmt, binary, offset + i * stride, *row)


def band(value: float, center: float, radius: float) -> float:
    return max(0.0, 1.0 - abs(value - center) / radius) ** 2


def add_joint(document: dict, inverse_head: tuple, name: str, center: tuple) -> tuple[int, tuple]:
    skin = document["skins"][0]
    head = next(index for index in skin["joints"] if document["nodes"][index]["name"] == "Head")
    # Column-major inverse head bind multiplied by a world-space translation.
    local = list(inverse_head)
    for row in range(4):
        local[12 + row] = sum(inverse_head[col * 4 + row] * center[col] for col in range(3)) + inverse_head[12 + row]
    document["nodes"].append({"name": name, "matrix": local})
    document["nodes"][head].setdefault("children", []).append(len(document["nodes"]) - 1)
    skin["joints"].append(len(document["nodes"]) - 1)
    inverse = (1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -center[0], -center[1], -center[2], 1)
    return len(skin["joints"]) - 1, inverse


def compile_role(role_name: str) -> dict:
    # Rebuild from immutable source layers, making repeated asset builds safe.
    record = assembly.build_assembly(role_name, assembly.ROLES[role_name], json.loads(assembly.ATLAS_MANIFEST.read_text()))
    path = ROOT / record["runtime"].removeprefix("res://")
    document = json.loads(path.read_text())
    binary_path = path.parent / document["buffers"][0]["uri"]
    binary = bytearray(binary_path.read_bytes())
    primitive = document["meshes"][0]["primitives"][0]
    attributes = primitive["attributes"]
    positions = values(document, binary, attributes["POSITION"])
    joints = values(document, binary, attributes["JOINTS_0"])
    weights = values(document, binary, attributes["WEIGHTS_0"])
    skin = document["skins"][0]
    head = next(i for i, node in enumerate(skin["joints"]) if document["nodes"][node]["name"] == "Head")
    # The assembly concatenates source layers and primitive vertices in order.
    regions: list[tuple[int, int, str]] = []
    offset = 0
    for name in assembly.ROLES[role_name]["sources"]:
        source = json.loads((assembly.SOURCE / name).read_text())
        for mesh in source["meshes"]:
            for part in mesh["primitives"]:
                count = source["accessors"][part["attributes"]["POSITION"]]["count"]
                label = "body"
                if name in ("Male_Head.gltf", "Female_Head.gltf"):
                    texture = assembly.image_uri_for_material(source, part["material"]).lower()
                    label = "eyes" if "eye" in texture else ("brows" if "hair" in texture else "skin")
                regions.append((offset, offset + count, label))
                offset += count
    if offset != len(positions):
        raise ValueError(f"{role_name}: source facial regions do not match compiled geometry")
    eye_range = next((start, end) for start, end, name in regions if name == "eyes")
    eyes = positions[eye_range[0]:eye_range[1]]
    eye_y = (max(p[1] for p in eyes) + min(p[1] for p in eyes)) * 0.5
    eye_z = (max(p[2] for p in eyes) + min(p[2] for p in eyes)) * 0.5
    eye_x = (max(p[0] for p in eyes) + min(p[0] for p in eyes if p[0] > 0)) * 0.5
    centers: dict[str, tuple] = {}
    for side, sign in (("L", 1), ("R", -1)):
        centers.update({
            f"Face_Eye_{side}": (sign * eye_x, eye_y, eye_z),
            f"Face_LidUpper_{side}": (sign * eye_x, eye_y + 0.014, eye_z + 0.009),
            f"Face_LidLower_{side}": (sign * eye_x, eye_y - 0.014, eye_z + 0.009),
            f"Face_Brow_{side}": (sign * eye_x, eye_y + 0.028, eye_z + 0.013),
            f"Face_Mouth_{side}": (sign * 0.016, eye_y - 0.058, eye_z + 0.016),
        })
    centers["Face_Jaw"] = (0.0, eye_y - 0.063, eye_z - 0.018)
    matrices = values(document, binary, skin["inverseBindMatrices"])
    inverse_head = matrices[head]
    controls = {}
    for name in CONTROLS:
        joint, inverse = add_joint(document, inverse_head, name, centers[name])
        controls[name] = joint
        matrices.append(inverse)
    payload = b"".join(struct.pack("<16f", *row) for row in matrices)
    skin["inverseBindMatrices"] = assembly.append_compact_accessor(
        document, binary, document["bufferViews"], document["accessors"], payload,
        {"componentType": 5126, "type": "MAT4"}, len(matrices), 34962,
    )
    affected = {name: 0 for name in CONTROLS}
    for start, end, name in regions:
        for vertex in range(start, end):
            x, y, z = positions[vertex]
            side = "L" if x >= 0.0 else "R"
            influences: dict[int, float] = {}
            if name == "eyes":
                influences[controls[f"Face_Eye_{side}"]] = 1.0
            elif name == "brows":
                influences[controls[f"Face_Brow_{side}"]] = 1.0
            elif name == "skin" and y > eye_y - 0.13 and z > eye_z - 0.008:
                eye_weight = band(abs(x), eye_x, 0.029)
                lid_name = f"Face_Lid{'Upper' if y >= eye_y else 'Lower'}_{side}"
                lid = eye_weight * band(y, eye_y + (0.012 if y >= eye_y else -0.012), 0.020)
                brow = eye_weight * band(y, eye_y + 0.031, 0.021) * 0.65
                mouth = band(x, 0.016 if x >= 0 else -0.016, 0.026) * band(y, eye_y - 0.058, 0.022) * 0.7
                jaw = band(x, 0.0, 0.085) * band(y, eye_y - 0.088, 0.045) * 0.65
                for control, weight in ((lid_name, lid), (f"Face_Brow_{side}", brow), (f"Face_Mouth_{side}", mouth), ("Face_Jaw", jaw)):
                    if weight > 0.015:
                        influences[controls[control]] = weight
                # Small fitted refinement of the original nose/lip plane; neck,
                # hair, clothing, eye placement and all triangles stay intact.
                nose = band(x, 0.0, 0.019) * band(y, eye_y - 0.025, 0.024)
                positions[vertex] = (x, y, z + nose * 0.0025)
            if not influences:
                continue
            total = sum(influences.values())
            if total > 0.9:
                influences = {joint: weight * 0.9 / total for joint, weight in influences.items()}
            remaining = max(0.0, 1.0 - sum(influences.values()))
            for joint, weight in zip(joints[vertex], weights[vertex]):
                if weight > 0:
                    influences[joint] = influences.get(joint, 0.0) + weight * remaining
            strongest = sorted(influences.items(), key=lambda pair: pair[1], reverse=True)[:4]
            normalization = sum(weight for _, weight in strongest)
            strongest += [(head, 0.0)] * (4 - len(strongest))
            joints[vertex] = tuple(joint for joint, _ in strongest)
            weights[vertex] = tuple(weight / normalization for _, weight in strongest)
            for control, joint in controls.items():
                if influences.get(joint, 0.0) > 0.015:
                    affected[control] += 1
    if any(count == 0 for count in affected.values()):
        raise ValueError(f"{role_name}: facial control has no weighted anatomy: {affected}")
    for semantic, data in (("POSITION", positions), ("JOINTS_0", joints), ("WEIGHTS_0", weights)):
        write_values(document, binary, attributes[semantic], data)
    document["buffers"][0]["byteLength"] = len(binary)
    document["asset"]["generator"] = "Ashen Oath CAST-002 fitted facial assembly"
    for node in document["nodes"]:
        if "mesh" in node:
            node.setdefault("extras", {})["ashen_facial_rig"] = "living_face_v1"
    binary_path.write_bytes(binary)
    path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    record.update({"runtime_sha256": assembly.sha256(path), "binary_sha256": assembly.sha256(binary_path),
                   "facial_rig": "living_face_v1", "facial_controls": affected})
    return record


def main() -> None:
    manifest_path = OUTPUT / "OPENING_CHARACTER_ASSEMBLY_MANIFEST.json"
    manifest = json.loads(manifest_path.read_text())
    for role in SAMPLE_ROLES:
        manifest["roles"][role] = compile_role(role)
        print(f"CAST FACE COMPILED {role}: {len(CONTROLS)} weighted controls")
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
