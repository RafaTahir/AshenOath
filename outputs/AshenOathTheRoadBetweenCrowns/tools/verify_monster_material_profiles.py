"""Inspect the immutable monster sources and the runtime-only pigment profiles.

This tool does not import Godot, render, run a world, or rewrite an art receipt.
An explicit baseline capture is exclusive-create; reports also refuse overwrite.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import math
import re
import struct
import subprocess
from pathlib import Path
from urllib.parse import unquote

IDS = tuple(f"M{i:02}" for i in range(1, 21))
SOURCE_PREFIX = "res://assets_external/design_pack_v1/creatures/"
REVISION = "monster_vitality_20261118"
METHODS = {"semantic", "atlas_regions"}
PARAMETERS = {
    "strength": (0.0, 1.0), "chroma_preservation": (0.0, 1.0),
    "highlight_preservation": (0.0, 1.0), "value_gain": (1.0, 1.24),
}
PIGMENT_KEYS = {"method", "neutral_color", "warm_color", "cool_color", *PARAMETERS}
BODY_BAKES = {
    ("M01", "M01_PeatSkin"): "M01_ghoulkin_peat_albedo.png",
    ("M19", "M19_OliveGreyHide"): "M19_raider_woad_albedo.png",
    ("M20", "M20_CharcoalOliveHide"): "M20_brute_scar_albedo.png",
}
EVIDENCE = "art_source/art_recovery_v2/evidence/monster_vitality_20261118"
BASELINE_NAME = "retained_material_baseline.json"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def pin(path):
    raw = path.read_bytes()
    return {"sha256": sha(raw), "bytes": len(raw)}


def resource(project, value):
    require(isinstance(value, str) and value.startswith("res://"), "Expected resource path")
    result = (project / value[6:]).resolve(strict=True)
    require(result.is_relative_to(project.resolve()), "Resource escapes project: " + value)
    return result


def number(value, lower, upper, label):
    require(isinstance(value, (float, int)) and not isinstance(value, bool)
            and math.isfinite(value) and lower <= value <= upper,
            f"{label}: expected finite number in [{lower}, {upper}]")


def vector(value, width, lower, upper, label):
    require(isinstance(value, list) and len(value) == width, label + ": invalid vector")
    for component in value:
        number(component, lower, upper, label)


def glb(path):
    raw = path.read_bytes()
    require(len(raw) >= 20, "Truncated GLB: " + str(path))
    magic, version, size = struct.unpack_from("<4sII", raw)
    require(magic == b"glTF" and version == 2 and size == len(raw), "Invalid GLB header")
    chunks = {}
    cursor = 12
    while cursor < len(raw):
        require(cursor + 8 <= len(raw), "Truncated GLB chunk")
        length, kind = struct.unpack_from("<II", raw, cursor)
        cursor += 8
        require(cursor + length <= len(raw) and kind not in chunks, "Invalid GLB chunk layout")
        chunks[kind] = raw[cursor:cursor + length]
        cursor += length
    require(0x4E4F534A in chunks, "Missing GLB JSON")
    return json.loads(chunks[0x4E4F534A]), chunks.get(0x004E4942, b""), raw


def texture_bytes(project, model, document, binary, index):
    image = document["images"][index]
    if "uri" in image:
        uri = image["uri"]
        if uri.startswith("data:"):
            header, content = uri.split(",", 1)
            require(";base64" in header, "Only base64 embedded image URIs are supported")
            return base64.b64decode(content, validate=True), None
        require(not re.match(r"^[a-zA-Z]+:", uri), "External network image URI is forbidden")
        path = (model.parent / unquote(uri)).resolve(strict=True)
        require(path.is_relative_to(project), "Texture escapes project")
        return path.read_bytes(), "res://" + path.relative_to(project).as_posix()
    view = document["bufferViews"][image["bufferView"]]
    require(view.get("buffer", 0) == 0, "Embedded image uses unsupported external buffer")
    start, length = view.get("byteOffset", 0), view["byteLength"]
    result = binary[start:start + length]
    require(len(result) == length, "Truncated image buffer")
    return result, None


def material_extensions(material, label):
    extensions = material.get("extensions", {})
    require(set(extensions).issubset({"KHR_materials_specular", "KHR_materials_ior", "KHR_materials_clearcoat"}),
            label + ": unsupported material extension")
    for name, value in extensions.items():
        require(isinstance(value, dict), label + ": malformed material extension")
        if name == "KHR_materials_specular":
            require(set(value).issubset({"specularFactor", "specularColorFactor"}),
                    label + ": textured specular extension is unsupported")
            number(value.get("specularFactor", 1), 0, 1, label + "/specularFactor")
            color = value.get("specularColorFactor", [1, 1, 1])
            vector(color, 3, 0, 2, label + "/specularColorFactor")
            require(max(color) - min(color) <= 1e-6, label + ": colored specular cannot be represented by scalar native state")
        elif name == "KHR_materials_ior":
            require(set(value).issubset({"ior"}), label + ": unsupported IOR controls")
            number(value.get("ior", 1.5), 1, 3, label + "/ior")
        else:
            require(set(value).issubset({"clearcoatFactor", "clearcoatRoughnessFactor"}),
                    label + ": textured clearcoat extension is unsupported")
            number(value.get("clearcoatFactor", 0), 0, 1, label + "/clearcoatFactor")
            number(value.get("clearcoatRoughnessFactor", 0), 0, 1, label + "/clearcoatRoughnessFactor")
    return extensions


def source_contract(project, source):
    model = resource(project, source)
    document, binary, raw = glb(model)
    materials = document.get("materials", [])
    names = [entry.get("name", "") for entry in materials]
    require(all(names) and len(names) == len(set(names)), source + ": material names must be unique")
    used = {}
    attributes = []
    for mesh in document.get("meshes", []):
        for primitive in mesh["primitives"]:
            index = primitive.get("material")
            require(isinstance(index, int) and 0 <= index < len(materials), source + ": missing material")
            used.setdefault(index, []).append(primitive)
            attributes.append(sorted(primitive["attributes"]))
            if "COLOR_0" in primitive["attributes"]:
                spec = document["accessors"][primitive["attributes"]["COLOR_0"]]
                require(spec["type"] in {"VEC3", "VEC4"} and spec["componentType"] in {5121, 5123, 5126},
                        source + ": unsupported vertex color representation")
                require(spec["componentType"] == 5126 or spec.get("normalized") is True,
                        source + ": integer vertex colors must be normalized")
    require(set(used) == set(range(len(materials))), source + ": unused material lacks an actual surface")
    records = {}
    texture_files = {}
    for index, material in enumerate(materials):
        label = source + "/" + names[index]
        extensions = material_extensions(material, label)
        require(isinstance(material.get("doubleSided", False), bool), label + ": invalid culling flag")
        alpha = material.get("alphaMode", "OPAQUE")
        require(alpha in {"OPAQUE", "BLEND"}, label + ": only retained opaque/blended materials are supported")
        number(material.get("alphaCutoff", 0.5), 0, 1, label + "/alphaCutoff")
        pbr = material.get("pbrMetallicRoughness", {})
        vector(pbr.get("baseColorFactor", [1, 1, 1, 1]), 4, 0, 1, label + "/baseColorFactor")
        vector(material.get("emissiveFactor", [0, 0, 0]), 3, 0, 1, label + "/emissiveFactor")
        require(not any(material.get("emissiveFactor", [0, 0, 0])) and not material.get("emissiveTexture"),
                label + ": emission is not used by the retained roster or supported by this pigment binder")
        require(not material.get("occlusionTexture"),
                label + ": ambient occlusion textures are not supported by this pigment binder")
        number(pbr.get("metallicFactor", 1), 0, 1, label + "/metallicFactor")
        number(pbr.get("roughnessFactor", 1), 0, 1, label + "/roughnessFactor")
        textures = {}
        texture_slots = {
            "albedo": pbr.get("baseColorTexture"),
            "metallic_roughness": pbr.get("metallicRoughnessTexture"),
            "normal": material.get("normalTexture"),
            "occlusion": material.get("occlusionTexture"),
            "emission": material.get("emissiveTexture"),
        }
        for slot, info in texture_slots.items():
            if info is None:
                continue
            require(info.get("texCoord", 0) == 0, label + "/" + slot + ": only UV0 is supported")
            require(not info.get("extensions"), label + "/" + slot + ": UV/texture extensions unsupported")
            require(all("TEXCOORD_0" in item["attributes"] for item in used[index]),
                    label + "/" + slot + ": textured surface has no UV0")
            if slot == "normal":
                number(info.get("scale", 1), 0, 2, label + "/normal_scale")
            if slot == "occlusion":
                number(info.get("strength", 1), 0, 1, label + "/occlusion_strength")
            texture = document["textures"][info["index"]]
            require(not texture.get("extensions"), label + ": unsupported texture extension")
            image = texture["source"]
            pixels, external = texture_bytes(project, model, document, binary, image)
            identity = {"sha256": sha(pixels), "bytes": len(pixels), "texcoord": 0,
                        "image": image, "external": external}
            textures[slot] = identity
            if external:
                previous = texture_files.setdefault(external, {"sha256": identity["sha256"], "bytes": len(pixels)})
                require(previous["sha256"] == identity["sha256"], "Conflicting texture identity")
        records[names[index]] = {
            "material_index": index, "alpha_mode": alpha,
            "alpha_cutoff": material.get("alphaCutoff", 0.5),
            "double_sided": material.get("doubleSided", False),
            "base_color_factor": pbr.get("baseColorFactor", [1, 1, 1, 1]),
            "roughness_factor": pbr.get("roughnessFactor", 1),
            "metallic_factor": pbr.get("metallicFactor", 1),
            "normal_scale": material.get("normalTexture", {}).get("scale", 1),
            "occlusion_strength": material.get("occlusionTexture", {}).get("strength", 1),
            "emission_factor": material.get("emissiveFactor", [0, 0, 0]),
            "extensions": extensions,
            "textures": textures,
        }
    return {"source": source, "source_sha256": sha(raw), "source_bytes": len(raw),
            "materials": records, "primitive_attribute_sets": attributes,
            "external_texture_inputs": texture_files}


def current_sources(project):
    ledger = read_json(project / "data/design_pack_assets.json")["assets"]
    require({key for key in ledger if key.startswith("M")} == set(IDS), "Canonical roster must contain exactly M01..M20")
    result = {}
    for aid in IDS:
        entry = ledger[aid]
        source = entry["path"]
        require(source.startswith(SOURCE_PREFIX + aid + "_") and source.endswith(".glb"), aid + ": wrong source scope")
        contract = source_contract(project, source)
        require(contract["source_sha256"] == entry["sha256"] and contract["source_bytes"] == entry["bytes"],
                aid + ": canonical source hash/size differs")
        result[aid] = contract
    return result


def validate_profiles(project, profiles, contracts, baseline):
    require(profiles.get("schema_version") == 1 and profiles.get("palette_revision") == REVISION,
            "Unsupported profile schema or palette revision")
    require(set(profiles.get("assets", {})) == set(IDS), "Pigment coverage must contain exactly M01..M20")
    require(isinstance(profiles.get("scope_order"), list) and profiles["scope_order"]
            and profiles["scope_order"][0] == "wychwood", "Wychwood must be the first authored scope")
    require(baseline.get("schema_version") == 1 and baseline.get("kind") == "immutable_monster_material_baseline",
            "Invalid immutable source baseline")
    require(set(baseline.get("assets", {})) == set(IDS), "Incomplete immutable source baseline")
    body_hashes = set()
    for aid in IDS:
        row, source = profiles["assets"][aid], contracts[aid]
        require(source == baseline["assets"][aid], aid + ": source/material/texture bytes differ from baseline")
        require(row.get("source") == source["source"] and row.get("source_sha256") == source["source_sha256"],
                aid + ": profile source/hash differs")
        require(row.get("method") in METHODS, aid + ": unsupported pigment method")
        require(isinstance(row.get("name"), str) and row["name"].strip()
                and isinstance(row.get("intent"), str) and row["intent"].strip(), aid + ": missing authored identity/intent")
        realms = row.get("realms")
        require(isinstance(realms, list) and realms and len(realms) == len(set(realms))
                and all(isinstance(realm, str) and re.fullmatch(r"[a-z][a-z_]*", realm) for realm in realms),
                aid + ": invalid narrative realm labels")
        require(isinstance(row.get("materials"), dict) and set(row["materials"]) == set(source["materials"]),
                aid + ": exact authored material-name coverage differs")
        graded_opaque = 0
        for name, material in row["materials"].items():
            filename = BODY_BAKES.get((aid, name))
            required = PIGMENT_KEYS | {"authored_albedo"} if filename else PIGMENT_KEYS
            require(set(material) == required and material.get("method") == row["method"],
                    aid + "/" + name + ": unsupported/missing pigment controls")
            if filename:
                expected = SOURCE_PREFIX + "textures/" + filename
                require(material["authored_albedo"] == expected, aid + "/" + name + ": incorrect authored body atlas")
                raw = resource(project, expected).read_bytes()
                require(raw.startswith(bytes.fromhex("89504e470d0a1a0a")), expected + ": expected PNG")
                identity = sha(raw)
                require(identity not in body_hashes, aid + ": duplicate authored body bake")
                require(identity != source["materials"][name]["textures"]["albedo"]["sha256"],
                        aid + ": authored body bake matches the retained native atlas")
                body_hashes.add(identity)
            for field in ("neutral_color", "warm_color", "cool_color"):
                require(isinstance(material[field], str) and re.fullmatch(r"#[0-9a-fA-F]{6}", material[field]),
                        aid + "/" + name + ": invalid sRGB color")
            for field, limits in PARAMETERS.items():
                number(material[field], *limits, aid + "/" + name + "/" + field)
            alpha_mode = source["materials"][name]["alpha_mode"]
            if alpha_mode == "BLEND":
                require(material["strength"] == 0.0,
                        aid + "/" + name + ": blended layers require exact zero strength and the native material")
            elif alpha_mode == "OPAQUE" and material["strength"] > 0.0:
                graded_opaque += 1
        require(graded_opaque > 0, aid + ": at least one opaque surface must receive positive pigment strength")
    require(len(body_hashes) == len(BODY_BAKES), "Incomplete Wychwood body atlas coverage")


def live_coverage(project, contracts, profiles):
    by_source = {row["source"]: aid for aid, row in contracts.items()}
    aliases = {aid: [] for aid in IDS}
    for filename in ("curated_runtime_assets.json", "visual_upgrade_manifest.json"):
        document = read_json(project / filename)
        selected = set()
        for category in ("enemies", "characters"):
            for role, value in document.get("roles", {}).get(category, {}).items():
                source = value.get("path", "")
                if source.startswith(SOURCE_PREFIX):
                    require(source in by_source, filename + ": unknown monster alias source: " + role)
                    aid = by_source[source]
                    selected.add(aid)
                    aliases[aid].append({"manifest": filename, "category": category, "role": role})
        require(selected == set(IDS), filename + ": not all twenty sources have live selections")
    names = {}
    for aid, rows in aliases.items():
        for row in rows:
            previous = names.setdefault(row["role"], aid)
            require(previous == aid, "A live alias selects different monsters between manifests")
    ecology = {aid: [] for aid in IDS}
    for sighting in read_json(project / "data/design_pack_ecology.json").get("sightings", []):
        aid = sighting.get("design")
        require(aid in contracts, "Ecology references unknown source")
        require(names.get(sighting.get("role")) == aid, "Ecology design/role source differs")
        ecology[aid].append({"zone": sighting["zone"], "role": sighting["role"],
                             "name": sighting["name"], "kind": "authored_observation_sighting"})
    references = {aid: [] for aid in IDS}
    pattern = re.compile(r'''["']([a-z][a-z0-9_]*)["']''')
    for file in sorted((project / "scripts").rglob("*.gd")):
        for line, text in enumerate(file.read_text(encoding="utf-8-sig").splitlines(), 1):
            if text.lstrip().startswith("#"):
                continue
            for token in set(pattern.findall(text)).intersection(names):
                aid = names[token]
                references[aid].append({"file": file.relative_to(project).as_posix(), "line": line,
                    "alias": token, "kind": "runtime_literal_reference",
                    "note": "Literal reference; does not itself establish spawn, arrival or observed gameplay."})
    return {aid: {"live_aliases": aliases[aid], "narrative_realms": profiles["assets"][aid]["realms"],
                  "explicit_ecology_zone_references": ecology[aid], "runtime_literal_references": references[aid],
                  "material_delivery": {name: {"alpha_mode": original["alpha_mode"],
                      "policy": "native_material_passthrough" if profiles["assets"][aid]["materials"][name]["strength"] == 0.0 else "opaque_pigment_variant"}
                      for name, original in contracts[aid]["materials"].items()}}
            for aid in IDS}


def exclusive_json(path, document):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(document, stream, indent=2, sort_keys=True, allow_nan=False)
        stream.write("\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--profiles", type=Path)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--capture-baseline", action="store_true", help="Exclusive-create immutable before-source snapshot")
    parser.add_argument("--report", type=Path, help="Exclusive-create current static coverage report")
    args = parser.parse_args()
    project = args.project.resolve(strict=True)
    repository = project.parents[1]
    profile_path = args.profiles or project / "data/monster_material_profiles.json"
    baseline_path = args.baseline or repository / EVIDENCE / BASELINE_NAME
    try:
        contracts = current_sources(project)
        if args.capture_baseline:
            commit = subprocess.check_output(["git", "-C", str(repository), "rev-parse", "HEAD"], text=True).strip()
            exclusive_json(baseline_path, {"schema_version": 1, "kind": "immutable_monster_material_baseline",
                "source_commit": commit, "scope": "Original twenty raw GLBs and exact material/texture input bytes",
                "render_observation": False, "user_visual_acceptance": False, "assets": contracts})
        baseline = read_json(baseline_path)
        profiles = read_json(profile_path)
        validate_profiles(project, profiles, contracts, baseline)
        coverage = live_coverage(project, contracts, profiles)
        count = sum(len(row["materials"]) for row in contracts.values())
        deliveries = [row for asset in coverage.values() for row in asset["material_delivery"].values()]
        result = {"schema_version": 1, "kind": "monster_material_static_coverage", "passed": True,
            "profile": {"path": str(profile_path), **pin(profile_path)},
            "immutable_baseline": {"path": str(baseline_path), **pin(baseline_path)},
            "verifier": {"path": "tools/verify_monster_material_profiles.py", **pin(Path(__file__))},
            "counts": {"sources": len(contracts), "materials": count,
                "external_texture_inputs_unique": len({path for row in contracts.values() for path in row["external_texture_inputs"]}),
                "opaque_pigment_variants": sum(row["policy"] == "opaque_pigment_variant" for row in deliveries),
                "native_material_passthroughs": sum(row["policy"] == "native_material_passthrough" for row in deliveries),
                "native_blended_layers": sum(row["alpha_mode"] == "BLEND" for row in deliveries)},
            "feature_contract": {"uv_sets": [0], "texture_transforms": "rejected",
                "material_extensions": "scalar neutral specular/IOR and scalar clearcoat; textures and other extensions rejected",
                "alpha_modes": ["OPAQUE", "BLEND"], "orm_channels": {"roughness": "g", "metallic": "b"},
                "blended_layers": "exact zero strength; retain identical native Material rather than reconstructing alpha in a pigment shader",
                "per_asset_coverage": "at least one OPAQUE surface with strictly positive pigment strength",
                "zero_strength": "exact native material passthrough, including optional opaque details",
                "emission": "not used by retained roster; nonzero factors and textures rejected",
                "ambient_occlusion": "not used by retained roster; textures rejected",
                "preserve": ["raw GLB bytes", "external texture bytes", "normal scale", "PBR factors", "scalar specular/IOR", "scalar clearcoat", "vertex colors", "alpha", "culling"]},
            "acceptance": {"source_byte_identity": True, "static_profile_validation": True,
                "runtime_binding_observed": False, "visual_accepted": False, "user_accepted": False},
            "coverage": coverage}
        if args.report:
            require(args.report.resolve() not in {profile_path.resolve(), baseline_path.resolve()}, "Report would overwrite an input")
            exclusive_json(args.report, result)
        print(json.dumps({"passed": True, **result["counts"], "runtime_or_visual_acceptance": False}))
        return 0
    except (ValueError, OSError, KeyError, IndexError, TypeError, struct.error) as error:
        print("MONSTER MATERIAL PROFILES: FAIL: " + str(error))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
