#!/usr/bin/env python3
"""Build deterministic, single-material Universal character assemblies."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
from copy import deepcopy
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets_external" / "characters_universal"
RANGER_SOURCE = ROOT / "assets_external" / "characters_ranger"
OUTPUT = SOURCE / "runtime"
ATLAS_MANIFEST = OUTPUT / "Universal_Albedo_Atlas_512.json"

ROLES = {
    "kael": {
        "sources": ["Male_Peasant.gltf", "Male_Head.gltf", "Hair_SimpleParted.gltf"],
        "output": "Kael_A_Set_Atlas.gltf",
        "atlas": "Kael_A_Set_Atlas.png",
        "colors": {
            "cloth": "202a25", "skin": "a9785f", "hair": "77756f", "eyes": "171412",
        },
    },
    "anwen": {
        "sources": ["Female_Peasant.gltf", "Female_Head.gltf", "Hair_Buns.gltf"],
        "output": "Anwen_A_Set_Atlas.gltf",
        "atlas": "Anwen_A_Set_Atlas.png",
        "colors": {
            "cloth": "28334b", "skin": "a98270", "hair": "b8b4aa", "eyes": "292525",
        },
    },
    "villager_male": {
        "sources": ["Male_Peasant.gltf", "Male_Head.gltf", "Hair_SimpleParted.gltf"],
        "output": "Villager_Male_Atlas.gltf",
        "atlas": "Villager_Male_Atlas.png",
        "colors": {
            "cloth": "49382a", "skin": "9e7058", "hair": "352820", "eyes": "211913",
        },
    },
    "villager_female": {
        "sources": ["Female_Peasant.gltf", "Female_Head.gltf", "Hair_Buns.gltf"],
        "output": "Villager_Female_Atlas.gltf",
        "atlas": "Villager_Female_Atlas.png",
        "colors": {
            "cloth": "405044", "skin": "b47f67", "hair": "6b4b35", "eyes": "282018",
        },
    },
    "villager_worker": {
        "sources": ["Male_Peasant.gltf", "Male_Head.gltf", "Hair_Buzzed.gltf"],
        "output": "Villager_Worker_Atlas.gltf",
        "atlas": "Villager_Worker_Atlas.png",
        "colors": {
            "cloth": "4e3424", "skin": "865843", "hair": "231d1a", "eyes": "161412",
        },
    },
    "villager_hooded": {
        "sources": ["Male_Peasant.gltf", "Male_Head.gltf", "Hair_Buzzed.gltf"],
        "output": "Villager_Hooded_Atlas.gltf",
        "atlas": "Villager_Hooded_Atlas.png",
        "colors": {
            "cloth": "242d35", "skin": "aa765e", "hair": "4b3024", "eyes": "1c1715",
        },
    },
    "bandit_deserter": {
        "sources": ["Male_Ranger_Runtime.gltf", "Male_Head.gltf", "Hair_Buzzed.gltf"],
        "meshes": {
            "Male_Ranger_Runtime.gltf": [
                "Male_Ranger_Arms", "Male_Ranger_Arms_Bracer",
                "Male_Ranger_Body", "Male_Ranger_Body_Belt_1", "Male_Ranger_Body_Belt_2",
                "Male_Ranger_Feet_Boots", "Male_Ranger_Legs",
            ],
        },
        "output": "Bandit_Deserter_Atlas.gltf",
        "atlas": "Bandit_Deserter_Atlas.png",
        "cloth_darken": 0.34,
        "colors": {
            "cloth": "342b2e", "ranger": "77544a", "skin": "805641", "hair": "241d18", "eyes": "211a16",
        },
    },
    "bandit_tracker": {
        "sources": ["Male_Peasant.gltf", "Male_Ranger_Runtime.gltf", "Male_Head.gltf", "Hair_SimpleParted.gltf"],
        "meshes": {
            "Male_Peasant.gltf": ["Male_Peasant_Arms", "Male_Peasant_Body", "Male_Peasant_Legs"],
            "Male_Ranger_Runtime.gltf": ["Male_Ranger_Arms_Bracer", "Male_Ranger_Feet_Boots"],
        },
        "output": "Bandit_Tracker_Atlas.gltf",
        "atlas": "Bandit_Tracker_Atlas.png",
        "cloth_darken": 0.30,
        "colors": {
            "cloth": "292f38", "ranger": "3f4c50", "skin": "aa795f", "hair": "4f3b2e", "eyes": "1c1915",
        },
    },
}

TEXTURE_TREATMENT = {
	# These assemblies use one material for Web draw-call control, so the atlas
	# must carry identity strongly enough to survive gameplay lighting. The old
	# 24% cloth wash left hero, worker, pilgrim, and guard averages within a few
	# RGB points and made adjacent actors read as clones.
	"T_Peasant_BaseColor_1K.png": ("cloth", 0.58),
	"T_Regular_Male_Dark_BaseColor_1K.png": ("skin", 0.36),
	"T_Superhero_Male_Dark_1K.png": ("skin", 0.36),
	"T_Superhero_Female_Dark_BaseColor_1K.png": ("skin", 0.36),
	"T_Hair_1_BaseColor_1K.png": ("hair", 0.76),
	"T_Hair_2_BaseColor_1K.png": ("hair", 0.76),
	"T_Eye_Brown.png": ("eyes", 0.86),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tint_tile(image: Image.Image, color_hex: str, wash: float) -> Image.Image:
    color = tuple(int(color_hex[index : index + 2], 16) for index in (0, 2, 4))
    source = image.convert("RGBA")
    # Colorize source luminance instead of multiplying by absolute dark RGB.
    # Multiplication only made every pale cloth texture darker; this retains
    # folds and painted detail while giving each role a readable hue.
    peak = max(max(color), 1)
    highlight = tuple(
        round(36 + 219 * channel / peak)
        for channel in color
    )
    colored = ImageOps.colorize(
        ImageOps.grayscale(source.convert("RGB")),
        black=(5, 5, 5),
        white=highlight,
    )
    blended = Image.blend(source.convert("RGB"), colored, wash)
    blended.putalpha(source.getchannel("A"))
    return blended


def build_role_atlas(role: dict, atlas_manifest: dict) -> Path:
    source_atlas = Image.open(OUTPUT / atlas_manifest["atlas"]).convert("RGBA")
    width, height = atlas_manifest["size"]
    has_ranger = any(name == "Male_Ranger_Runtime.gltf" for name in role["sources"])
    result = Image.new("RGBA", (width, height * 2) if has_ranger else (width, height), (0, 0, 0, 0))
    result.paste(source_atlas, (0, 0))
    padding = int(atlas_manifest["padding"])
    tile_size = int(atlas_manifest["tile_size"])
    for name, entry in atlas_manifest["entries"].items():
        color_key, wash = TEXTURE_TREATMENT[name]
        offset = entry["offset"]
        left = round(float(offset[0]) * width) - padding
        top = round(float(offset[1]) * height) - padding
        box = (left, top, left + tile_size, top + tile_size)
        tile = tint_tile(source_atlas.crop(box), role["colors"][color_key], wash)
        if color_key == "cloth" and role.get("cloth_darken", 0.0) > 0.0:
            dark = Image.new("RGB", tile.size, (0, 0, 0))
            rgb = Image.blend(tile.convert("RGB"), dark, role["cloth_darken"])
            rgb.putalpha(tile.getchannel("A"))
            tile = rgb
        result.paste(tile, box)
    if has_ranger:
        ranger_texture = Image.open(RANGER_SOURCE / "T_Ranger_BaseColor_1K.png").convert("RGBA")
        ranger_texture = tint_tile(ranger_texture, role["colors"]["ranger"], 0.82)
        result.paste(ranger_texture, (0, height))
    output = OUTPUT / role["atlas"]
    result.save(output, optimize=True)
    return output


def image_uri_for_material(document: dict, material_index: int) -> str:
    material = document["materials"][material_index]
    texture_index = material["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    image_index = document["textures"][texture_index]["source"]
    return Path(document["images"][image_index]["uri"]).name


def select_meshes(document: dict, allowed_names: list[str], source_name: str) -> None:
    allowed = set(allowed_names)
    selected = {}
    meshes = []
    for node in document["nodes"]:
        if "mesh" not in node:
            continue
        if node.get("name") not in allowed:
            node.pop("mesh")
            node.pop("skin", None)
            continue
        old_index = int(node["mesh"])
        if old_index not in selected:
            selected[old_index] = len(meshes)
            meshes.append(document["meshes"][old_index])
        node["mesh"] = selected[old_index]
        allowed.discard(node["name"])
    if allowed:
        raise ValueError(f"{source_name}: missing selected meshes {sorted(allowed)}")
    document["meshes"] = meshes


def remap_uvs(document: dict, binary: bytearray, atlas_manifest: dict, has_ranger: bool) -> None:
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            texture_name = image_uri_for_material(document, int(primitive["material"]))
            is_ranger_texture = texture_name == "T_Ranger_BaseColor_1K.png"
            entry = atlas_manifest["entries"].get(texture_name)
            if entry is None and not (has_ranger and is_ranger_texture):
                raise ValueError(f"no atlas tile for {texture_name}")
            accessor = document["accessors"][int(primitive["attributes"]["TEXCOORD_0"])]
            if accessor["componentType"] != 5126 or accessor["type"] != "VEC2":
                raise ValueError(f"unsupported UV accessor: {accessor}")
            view = document["bufferViews"][int(accessor["bufferView"])]
            stride = int(view.get("byteStride", 8))
            start = int(view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0))
            if is_ranger_texture:
                ox, oy, sx, sy = 0.0, 0.5, 0.5, 0.5
            else:
                ox, oy = map(float, entry["offset"])
                sx, sy = map(float, entry["scale"])
                if has_ranger:
                    oy *= 0.5
                    sy *= 0.5
            for vertex in range(int(accessor["count"])):
                position = start + vertex * stride
                u, v = struct.unpack_from("<ff", binary, position)
                struct.pack_into("<ff", binary, position, ox + u * sx, oy + v * sy)


def align4(binary: bytearray) -> None:
    while len(binary) % 4:
        binary.append(0)


COMPONENT_BYTES = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
TYPE_COMPONENTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
MERGED_ATTRIBUTES = ("POSITION", "NORMAL", "TEXCOORD_0", "JOINTS_0", "WEIGHTS_0")


def accessor_bytes(document: dict, binary: bytes | bytearray, accessor_index: int) -> bytes:
    accessor = document["accessors"][accessor_index]
    view = document["bufferViews"][accessor["bufferView"]]
    element_size = COMPONENT_BYTES[accessor["componentType"]] * TYPE_COMPONENTS[accessor["type"]]
    stride = int(view.get("byteStride", element_size))
    start = int(view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0))
    count = int(accessor["count"])
    if stride == element_size:
        return bytes(binary[start : start + count * element_size])
    return b"".join(
        bytes(binary[start + index * stride : start + index * stride + element_size])
        for index in range(count)
    )


def append_compact_accessor(
    document: dict,
    output_binary: bytearray,
    output_views: list[dict],
    output_accessors: list[dict],
    payload: bytes,
    template: dict,
    count: int,
    target: int,
    minimum: list[float] | None = None,
    maximum: list[float] | None = None,
) -> int:
    align4(output_binary)
    offset = len(output_binary)
    output_binary.extend(payload)
    output_views.append({
        "buffer": 0,
        "byteOffset": offset,
        "byteLength": len(payload),
        "target": target,
    })
    accessor = {
        "bufferView": len(output_views) - 1,
        "componentType": int(template["componentType"]),
        "count": count,
        "type": template["type"],
    }
    if template.get("normalized"):
        accessor["normalized"] = True
    if minimum is not None:
        accessor["min"] = minimum
    if maximum is not None:
        accessor["max"] = maximum
    output_accessors.append(accessor)
    return len(output_accessors) - 1


def merge_skinned_primitives(document: dict, binary: bytearray, role_name: str) -> bytearray:
    primitives = [
        primitive
        for mesh in document.get("meshes", [])
        for primitive in mesh.get("primitives", [])
    ]
    if not primitives:
        raise ValueError(f"{role_name}: assembly has no mesh primitives")
    for primitive in primitives:
        missing = [name for name in MERGED_ATTRIBUTES if name not in primitive.get("attributes", {})]
        if missing:
            raise ValueError(f"{role_name}: primitive misses merge attributes {missing}")
        if int(primitive.get("mode", 4)) != 4 or "indices" not in primitive:
            raise ValueError(f"{role_name}: only indexed triangle primitives can be merged")

    output_binary = bytearray()
    output_views: list[dict] = []
    output_accessors: list[dict] = []
    merged_attributes: dict[str, int] = {}
    total_vertices = sum(
        int(document["accessors"][primitive["attributes"]["POSITION"]]["count"])
        for primitive in primitives
    )

    for semantic in MERGED_ATTRIBUTES:
        source_accessors = [
            document["accessors"][primitive["attributes"][semantic]] for primitive in primitives
        ]
        template = source_accessors[0]
        signature = (template["componentType"], template["type"], bool(template.get("normalized", False)))
        if any(
            (accessor["componentType"], accessor["type"], bool(accessor.get("normalized", False))) != signature
            for accessor in source_accessors[1:]
        ):
            raise ValueError(f"{role_name}: incompatible {semantic} accessor formats")
        payload = b"".join(
            accessor_bytes(document, binary, primitive["attributes"][semantic])
            for primitive in primitives
        )
        minimum = None
        maximum = None
        if semantic == "POSITION":
            minimum = [min(float(accessor["min"][axis]) for accessor in source_accessors) for axis in range(3)]
            maximum = [max(float(accessor["max"][axis]) for accessor in source_accessors) for axis in range(3)]
        merged_attributes[semantic] = append_compact_accessor(
            document, output_binary, output_views, output_accessors,
            payload, template, total_vertices, 34962, minimum, maximum,
        )

    merged_indices: list[int] = []
    vertex_offset = 0
    for primitive in primitives:
        accessor_index = int(primitive["indices"])
        accessor = document["accessors"][accessor_index]
        payload = accessor_bytes(document, binary, accessor_index)
        component_type = int(accessor["componentType"])
        format_code = {5121: "B", 5123: "H", 5125: "I"}.get(component_type)
        if format_code is None:
            raise ValueError(f"{role_name}: unsupported index component {component_type}")
        count = int(accessor["count"])
        merged_indices.extend(index + vertex_offset for index in struct.unpack(f"<{count}{format_code}", payload))
        vertex_offset += int(document["accessors"][primitive["attributes"]["POSITION"]]["count"])
    index_payload = struct.pack(f"<{len(merged_indices)}I", *merged_indices)
    index_accessor = append_compact_accessor(
        document, output_binary, output_views, output_accessors,
        index_payload, {"componentType": 5125, "type": "SCALAR"},
        len(merged_indices), 34963,
    )

    skin = document["skins"][0]
    inverse_bind_index = int(skin["inverseBindMatrices"])
    inverse_bind_template = document["accessors"][inverse_bind_index]
    compact_inverse_bind = append_compact_accessor(
        document, output_binary, output_views, output_accessors,
        accessor_bytes(document, binary, inverse_bind_index), inverse_bind_template,
        int(inverse_bind_template["count"]), 34962,
    )
    skin["inverseBindMatrices"] = compact_inverse_bind

    mesh_nodes = [node for node in document["nodes"] if "mesh" in node]
    if not mesh_nodes:
        raise ValueError(f"{role_name}: assembly has no mesh nodes")
    for node in mesh_nodes:
        node.pop("mesh", None)
        node.pop("skin", None)
    mesh_nodes[0]["name"] = f"{role_name.capitalize()}_Combined"
    mesh_nodes[0]["mesh"] = 0
    mesh_nodes[0]["skin"] = 0
    document["meshes"] = [{
        "name": f"{role_name.capitalize()}_Combined",
        "primitives": [{
            "attributes": merged_attributes,
            "indices": index_accessor,
            "material": 0,
            "mode": 4,
        }],
    }]
    document["bufferViews"] = output_views
    document["accessors"] = output_accessors
    return output_binary


def append_layer(base: dict, base_binary: bytearray, layer: dict, layer_binary: bytes) -> None:
    align4(base_binary)
    binary_offset = len(base_binary)
    base_binary.extend(layer_binary)
    view_offset = len(base.get("bufferViews", []))
    accessor_offset = len(base.get("accessors", []))
    mesh_offset = len(base.get("meshes", []))

    for view in layer.get("bufferViews", []):
        copied = deepcopy(view)
        copied["buffer"] = 0
        copied["byteOffset"] = int(copied.get("byteOffset", 0)) + binary_offset
        base.setdefault("bufferViews", []).append(copied)
    for accessor in layer.get("accessors", []):
        copied = deepcopy(accessor)
        if "bufferView" in copied:
            copied["bufferView"] = int(copied["bufferView"]) + view_offset
        base.setdefault("accessors", []).append(copied)
    for mesh in layer.get("meshes", []):
        copied = deepcopy(mesh)
        for primitive in copied.get("primitives", []):
            primitive["material"] = 0
            primitive["attributes"] = {
                name: int(index) + accessor_offset for name, index in primitive.get("attributes", {}).items()
            }
            if "indices" in primitive:
                primitive["indices"] = int(primitive["indices"]) + accessor_offset
            for target in primitive.get("targets", []):
                for name, index in list(target.items()):
                    target[name] = int(index) + accessor_offset
        base.setdefault("meshes", []).append(copied)

    armature_index = next(
        index for index, node in enumerate(base["nodes"]) if node.get("name") == "Armature"
    )
    armature_children = base["nodes"][armature_index].setdefault("children", [])
    for node in layer.get("nodes", []):
        if "mesh" not in node:
            continue
        copied = deepcopy(node)
        copied["mesh"] = int(copied["mesh"]) + mesh_offset
        copied["skin"] = 0
        copied.pop("children", None)
        base["nodes"].append(copied)
        armature_children.append(len(base["nodes"]) - 1)


def build_assembly(role_name: str, role: dict, atlas_manifest: dict) -> dict:
    documents: list[dict] = []
    binaries: list[bytearray] = []
    for source_name in role["sources"]:
        source_dir = RANGER_SOURCE if source_name == "Male_Ranger_Runtime.gltf" else SOURCE
        source_path = source_dir / source_name
        document = json.loads(source_path.read_text(encoding="utf-8"))
        binary = bytearray((source_dir / document["buffers"][0]["uri"]).read_bytes())
        selected = role.get("meshes", {}).get(source_name)
        if selected is not None:
            select_meshes(document, selected, source_name)
        remap_uvs(document, binary, atlas_manifest, "Male_Ranger_Runtime.gltf" in role["sources"])
        documents.append(document)
        binaries.append(binary)

    base_joint_names = [documents[0]["nodes"][index]["name"] for index in documents[0]["skins"][0]["joints"]]
    for source_name, document, binary in zip(role["sources"][1:], documents[1:], binaries[1:]):
        joint_names = [document["nodes"][index]["name"] for index in document["skins"][0]["joints"]]
        if joint_names != base_joint_names:
            raise ValueError(f"{role_name}: {source_name} has an incompatible skeleton")
        base_bind = accessor_bytes(documents[0], binaries[0], documents[0]["skins"][0]["inverseBindMatrices"])
        layer_bind = accessor_bytes(document, binary, document["skins"][0]["inverseBindMatrices"])
        for joint_name in ("root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head"):
            joint = base_joint_names.index(joint_name)
            start = joint * 64
            if base_bind[start : start + 64] != layer_bind[start : start + 64]:
                raise ValueError(f"{role_name}: {source_name} has an incompatible {joint_name} bind")

    base = documents[0]
    base_binary = binaries[0]
    for primitive_mesh in base.get("meshes", []):
        for primitive in primitive_mesh.get("primitives", []):
            primitive["material"] = 0
    for layer, layer_binary in zip(documents[1:], binaries[1:]):
        append_layer(base, base_binary, layer, layer_binary)

    base_binary = merge_skinned_primitives(base, base_binary, role_name)

    output_path = OUTPUT / role["output"]
    binary_path = OUTPUT / role["reuse_binary"] if "reuse_binary" in role else output_path.with_suffix(".bin")
    atlas_path = build_role_atlas(role, atlas_manifest)
    base["asset"]["generator"] = "Ashen Oath opening character assembly pipeline"
    base["buffers"] = [{"byteLength": len(base_binary), "uri": binary_path.name}]
    base["images"] = [{"uri": atlas_path.name}]
    base["samplers"] = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}]
    base["textures"] = [{"sampler": 0, "source": 0}]
    base["materials"] = [{
        "name": f"{role_name.capitalize()}_A_Set_Atlas",
        "doubleSided": True,
        "pbrMetallicRoughness": {
            "baseColorFactor": [1.0, 1.0, 1.0, 1.0],
            "baseColorTexture": {"index": 0},
            "metallicFactor": 0.0,
            "roughnessFactor": 0.78,
        },
    }]
    for mesh in base.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            primitive["material"] = 0
    if "reuse_binary" in role:
        if not binary_path.exists() or binary_path.read_bytes() != base_binary:
            raise ValueError(f"{role_name}: reused geometry differs from {binary_path.name}")
    else:
        binary_path.write_bytes(base_binary)
    output_path.write_text(json.dumps(base, indent=2) + "\n", encoding="utf-8")
    return {
        "role": role_name,
        "runtime": f"res://assets_external/characters_universal/runtime/{output_path.name}",
        "runtime_sha256": sha256(output_path),
        "binary": f"res://assets_external/characters_universal/runtime/{binary_path.name}",
        "binary_sha256": sha256(binary_path),
        "atlas": f"res://assets_external/characters_universal/runtime/{atlas_path.name}",
        "atlas_sha256": sha256(atlas_path),
        "sources": role["sources"],
        "source_license_files": [
            "res://assets_external/licenses/Quaternius_Universal_Base_Characters_CC0.txt",
            *(["res://assets_external/licenses/Quaternius_Modular_Character_Outfits_Fantasy_CC0.txt"] if "Male_Ranger_Runtime.gltf" in role["sources"] else []),
        ],
        "material_count": len(base["materials"]),
        "mesh_count": len(base.get("meshes", [])),
        "primitive_count": sum(len(mesh.get("primitives", [])) for mesh in base.get("meshes", [])),
        "skin_count": len(base.get("skins", [])),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--role", choices=sorted(ROLES))
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    atlas_manifest = json.loads(ATLAS_MANIFEST.read_text(encoding="utf-8"))
    manifest_path = OUTPUT / "OPENING_CHARACTER_ASSEMBLY_MANIFEST.json"
    result = json.loads(manifest_path.read_text(encoding="utf-8")) if args.role else {
        "schema_version": 1,
        "pipeline": "single-material opening character assemblies",
        "license": "CC0 1.0",
        "roles": {},
    }
    selected = {args.role: ROLES[args.role]} if args.role else ROLES
    for role_name, role in selected.items():
        result["roles"][role_name] = build_assembly(role_name, role, atlas_manifest)
        print(f"OPENING ASSEMBLY {role_name}: PASS {result['roles'][role_name]['runtime']}")
    manifest_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
