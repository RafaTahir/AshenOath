from __future__ import annotations

import json
import struct
from copy import deepcopy
from pathlib import Path


COMPONENT_FORMAT = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}
COMPONENT_SIZE = {5121: 1, 5123: 2, 5125: 4, 5126: 4}


def accessor_values(document: dict, payload: bytes, accessor_index: int):
    accessor = document["accessors"][accessor_index]
    view = document["bufferViews"][accessor["bufferView"]]
    component_type = accessor["componentType"]
    component_count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    component_size = COMPONENT_SIZE[component_type]
    stride = view.get("byteStride", component_size * component_count)
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    fmt = "<" + COMPONENT_FORMAT[component_type] * component_count
    return [struct.unpack_from(fmt, payload, offset + index * stride) for index in range(accessor["count"])]


def build_shell(source_gltf: Path, output_gltf: Path, minimum_y: float) -> None:
    document = json.loads(source_gltf.read_text(encoding="utf-8"))
    source_bin = source_gltf.with_name(document["buffers"][0]["uri"])
    payload = source_bin.read_bytes()
    result = deepcopy(document)
    for image in result.get("images", []):
        uri = image.get("uri", "")
        if uri.endswith("_png.png"):
            image["uri"] = uri.removesuffix("_png.png") + ".png"
    body_mesh_index = len(result["meshes"]) - 1
    primitive = result["meshes"][body_mesh_index]["primitives"][0]
    positions = accessor_values(result, payload, primitive["attributes"]["POSITION"])
    indices = [value[0] for value in accessor_values(result, payload, primitive["indices"])]
    retained: list[int] = []
    for offset in range(0, len(indices), 3):
        triangle = indices[offset : offset + 3]
        if len(triangle) < 3:
            continue
        # Every vertex must be above the neck line. An average-height test lets
        # long shoulder triangles survive and creates detached skin shards.
        # The peasant outfit owns all geometry below this line.
        if min(positions[index][1] for index in triangle) >= minimum_y:
            retained.extend(triangle)
    if not retained:
        raise RuntimeError(f"head crop removed every triangle from {source_gltf.name}")
    source_accessor = result["accessors"][primitive["indices"]]
    component_type = source_accessor["componentType"]
    fmt = "<" + COMPONENT_FORMAT[component_type] * len(retained)
    while len(payload) % 4:
        payload += b"\0"
    index_offset = len(payload)
    index_bytes = struct.pack(fmt, *retained)
    payload += index_bytes
    view_index = len(result["bufferViews"])
    result["bufferViews"].append(
        {"buffer": 0, "byteOffset": index_offset, "byteLength": len(index_bytes), "target": 34963}
    )
    accessor_index = len(result["accessors"])
    result["accessors"].append(
        {
            "bufferView": view_index,
            "componentType": component_type,
            "count": len(retained),
            "type": "SCALAR",
            "min": [min(retained)],
            "max": [max(retained)],
        }
    )
    primitive["indices"] = accessor_index
    output_bin = output_gltf.with_suffix(".bin")
    result["buffers"][0]["uri"] = output_bin.name
    result["buffers"][0]["byteLength"] = len(payload)
    result["asset"]["generator"] = "Ashen Oath universal head-shell builder"
    output_gltf.write_text(json.dumps(result, indent=2), encoding="utf-8")
    output_bin.write_bytes(payload)
    print(f"HEAD SHELL {output_gltf.name}: {len(retained) // 3} triangles")


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    characters = root / "assets_external" / "characters_universal"
    build_shell(characters / "Superhero_Male_FullBody.gltf", characters / "Male_Head.gltf", 1.535)
    build_shell(characters / "Superhero_Female_FullBody.gltf", characters / "Female_Head.gltf", 1.50)


if __name__ == "__main__":
    main()
