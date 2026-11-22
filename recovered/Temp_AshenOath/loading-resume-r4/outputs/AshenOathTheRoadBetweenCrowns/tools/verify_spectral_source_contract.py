#!/usr/bin/env python3
"""Capture immutable monster source contracts, then compare authored replacements.

This checks source data only; animation playback, contact sockets and imported
FBX rig semantics remain the companion Godot verifier's responsibility.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import gzip
import json
import math
import struct
import sys
from pathlib import Path
from urllib.parse import unquote


PROJECT = Path(__file__).resolve().parents[1]
BASELINE = PROJECT / ".release-gate/spectral-monsters/source_baseline.json"
RUNTIME_BASELINE = PROJECT / ".release-gate/spectral-monsters/baseline.json"
PROFILES = PROJECT / "data/spectral_monster_profiles.json"
UNIVERSAL = "assets_external/characters_universal/runtime/"
ENEMIES = "assets_external/enemies/"
SOURCES = {
    "ghoulkin": (UNIVERSAL + "Ghoulkin_Authored_Atlas.gltf", UNIVERSAL + "spectral/Ghoulkin_Spectral_Atlas.gltf", 18000),
    "bog_wretch": (UNIVERSAL + "BogWretch_Playfix.glb", UNIVERSAL + "spectral/BogWretch_Spectral_Atlas.gltf", 18000),
    "bell_eater": (UNIVERSAL + "BellEater_Playfix.glb", UNIVERSAL + "spectral/BellEater_Spectral_Atlas.gltf", 24000),
    "wychwood_stalker": (ENEMIES + "ultimate_monsters/Demon.gltf", ENEMIES + "spectral/Stalker_Spectral.gltf", 18000),
    "wychwood_raider": (ENEMIES + "ultimate_monsters/Orc.gltf", ENEMIES + "spectral/Raider_Spectral.gltf", 18000),
    "wychwood_brute": (ENEMIES + "ultimate_monsters/BlueDemon.gltf", ENEMIES + "spectral/Brute_Spectral.gltf", 18000),
    "gravebound_knight": (ENEMIES + "Skeleton.fbx", ENEMIES + "spectral/Gravebound_Spectral.gltf", 20000),
    "rootbound_colossus": (ENEMIES + "ultimate_monsters/Creep.glb", ENEMIES + "spectral/Rootbound_Spectral.gltf", 24000),
    "ashwing": (ENEMIES + "Ashwing_Playfix.glb", ENEMIES + "spectral/Ashwing_Spectral.gltf", 24000),
    "white_hart_avatar": (ENEMIES + "WhiteHart_Stag.glb", ENEMIES + "spectral/WhiteHart_Spectral.gltf", 24000),
}
COMPONENTS = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}
IDENTITY = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_contract_json(path: Path, kind: str) -> dict:
    if path.exists(): return json.loads(path.read_text(encoding="utf-8"))
    return json.loads(gzip.decompress((PROJECT / 'tools/fixtures' / ('spectral_' + kind + '_baseline.json.gz')).read_bytes()))


def multiply(a: list, b: list) -> list:
    return [sum(a[k * 4 + row] * b[col * 4 + k] for k in range(4)) for col in range(4) for row in range(4)]


def matrix(node: dict) -> list:
    if "matrix" in node:
        return node["matrix"]
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    sx, sy, sz = node.get("scale", [1, 1, 1])
    tx, ty, tz = node.get("translation", [0, 0, 0])
    return [(1-2*y*y-2*z*z)*sx, (2*x*y+2*z*w)*sx, (2*x*z-2*y*w)*sx, 0,
            (2*x*y-2*z*w)*sy, (1-2*x*x-2*z*z)*sy, (2*y*z+2*x*w)*sy, 0,
            (2*x*z+2*y*w)*sz, (2*y*z-2*x*w)*sz, (1-2*x*x-2*y*y)*sz, 0, tx, ty, tz, 1]


def transform(frame: list, point: tuple) -> list:
    return [sum(frame[k * 4 + row] * point[k] for k in range(3)) + frame[12 + row] for row in range(3)]


def image_size(raw: bytes) -> list[int]:
    if raw.startswith(b"\x89PNG\r\n\x1a\n"):
        return list(struct.unpack_from(">II", raw, 16))
    if raw[:2] == b"\xff\xd8":
        offset = 2
        while offset + 4 <= len(raw):
            if raw[offset] != 255:
                offset += 1
                continue
            marker = raw[offset + 1]
            offset += 2
            if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
                continue
            length = struct.unpack_from(">H", raw, offset)[0]
            if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                height, width = struct.unpack_from(">HH", raw, offset + 3)
                return [width, height]
            offset += length
    raise ValueError("Unsupported texture encoding; dimension measurement requires PNG or JPEG")


class Document:
    def __init__(self, path: Path):
        self.path = path
        raw = path.read_bytes()
        self.files = {path.relative_to(PROJECT).as_posix(): {"bytes": len(raw), "sha256": digest(raw)}}
        binary = None
        if path.suffix.lower() == ".glb":
            magic, version, length = struct.unpack_from("<4sII", raw)
            if magic != b"glTF" or version != 2 or length != len(raw):
                raise ValueError("Invalid GLB header")
            chunks = {}
            offset = 12
            while offset < len(raw):
                size, kind = struct.unpack_from("<II", raw, offset)
                chunks[kind] = raw[offset + 8:offset + 8 + size]
                offset += size + 8
            self.data = json.loads(chunks[0x4E4F534A])
            binary = chunks.get(0x004E4942)
        else:
            self.data = json.loads(raw)
        self.buffers = []
        for buffer in self.data.get("buffers", []):
            content = self.uri(buffer["uri"]) if "uri" in buffer else binary
            if content is None or len(content) < buffer["byteLength"]:
                raise ValueError("Missing or truncated buffer")
            self.buffers.append(content)
        self.cache: dict[int, tuple[list, dict]] = {}
        self.parents = {}
        for index, node in enumerate(self.data.get("nodes", [])):
            for child in node.get("children", []):
                if child in self.parents:
                    raise ValueError("Node has multiple parents")
                self.parents[child] = index

    def uri(self, uri: str) -> bytes:
        if uri.startswith("data:"):
            header, content = uri.split(",", 1)
            return base64.b64decode(content) if ";base64" in header else unquote(content).encode()
        path = (self.path.parent / unquote(uri)).resolve()
        if not path.is_relative_to(PROJECT):
            raise ValueError("Resource URI escapes project")
        raw = path.read_bytes()
        self.files[path.relative_to(PROJECT).as_posix()] = {"bytes": len(raw), "sha256": digest(raw)}
        return raw

    def view(self, index: int) -> bytes:
        view = self.data["bufferViews"][index]
        start = view.get("byteOffset", 0)
        result = self.buffers[view["buffer"]][start:start + view["byteLength"]]
        if len(result) != view["byteLength"]:
            raise ValueError("Truncated buffer view")
        return result

    def accessor(self, index: int) -> tuple[list, dict]:
        if index in self.cache:
            return self.cache[index]
        spec = self.data["accessors"][index]
        kind, size = COMPONENTS[spec["componentType"]]
        count, width = spec["count"], WIDTHS[spec["type"]]
        side = int(math.sqrt(width)) if spec["type"].startswith("MAT") else 0
        column_stride = ((side * size + 3) // 4) * 4 if side else 0
        positions = [(i // side) * column_stride + (i % side) * size for i in range(width)] if side else [i * size for i in range(width)]
        element_size = side * column_stride if side else width * size

        def read_rows(raw: bytes, offset: int, stride: int, amount: int) -> list:
            return [tuple(struct.unpack_from("<" + kind, raw, offset + row * stride + pos)[0] for pos in positions) for row in range(amount)]

        rows = [tuple(0 for _ in range(width)) for _ in range(count)]
        if "bufferView" in spec:
            view_spec = self.data["bufferViews"][spec["bufferView"]]
            rows = read_rows(self.view(spec["bufferView"]), spec.get("byteOffset", 0), view_spec.get("byteStride", element_size), count)
        if "sparse" in spec:
            sparse = spec["sparse"]
            indices = sparse["indices"]
            index_kind, index_size = COMPONENTS[indices["componentType"]]
            values = read_rows(self.view(sparse["values"]["bufferView"]), sparse["values"].get("byteOffset", 0), element_size, sparse["count"])
            raw_indices = self.view(indices["bufferView"])
            for row, value in enumerate(values):
                target = struct.unpack_from("<" + index_kind, raw_indices, indices.get("byteOffset", 0) + row * index_size)[0]
                rows[target] = value
        if any(not math.isfinite(value) for row in rows for value in row):
            raise ValueError("Nonfinite accessor attribute")
        payload = b"".join(struct.pack("<" + kind * width, *row) for row in rows)
        contract = {key: spec[key] for key in ("componentType", "type", "count")}
        contract.update(normalized=bool(spec.get("normalized", False)), sha256=digest(payload))
        self.cache[index] = rows, contract
        return rows, contract

    def node_name(self, index: int) -> str:
        return self.data["nodes"][index].get("name", "@unnamed:%d" % index)

    def world(self, index: int, visited: tuple = ()) -> list:
        if index in visited:
            raise ValueError("Cyclic node hierarchy")
        local = matrix(self.data["nodes"][index])
        return multiply(self.world(self.parents[index], visited + (index,)), local) if index in self.parents else local

    def snapshot(self) -> dict:
        nodes = self.data.get("nodes", [])
        skins = []
        for skin in self.data.get("skins", []):
            joints = skin["joints"]
            inverse = self.accessor(skin["inverseBindMatrices"])[0] if "inverseBindMatrices" in skin else [IDENTITY] * len(joints)
            if len(inverse) != len(joints):
                raise ValueError("Inverse bind count differs from joint count")
            bones = []
            for joint, bind in zip(joints, inverse):
                bones.append({"name": self.node_name(joint), "parent": self.node_name(self.parents[joint]) if joint in self.parents else None,
                              "local": matrix(nodes[joint]), "inverse_bind": bind})
            if len({bone["name"] for bone in bones}) != len(bones):
                raise ValueError("Duplicate bone names cannot be compared unambiguously")
            skins.append({"bones": sorted(bones, key=lambda bone: bone["name"])})
        animations = []
        for index, animation in enumerate(self.data.get("animations", [])):
            channels = []
            for channel in animation.get("channels", []):
                target = channel["target"]
                sampler = animation["samplers"][channel["sampler"]]
                channels.append({"node": self.node_name(target["node"]), "path": target["path"], "interpolation": sampler.get("interpolation", "LINEAR"),
                                 "input": self.accessor(sampler["input"])[1], "output": self.accessor(sampler["output"])[1]})
            animations.append({"name": animation.get("name", "@unnamed:%d" % index), "channels": sorted(channels, key=lambda item: json.dumps(item, sort_keys=True))})
        points, triangles, surfaces, skinned, max_weight_error, zero_weights = [], 0, 0, 0, 0.0, 0
        for node_index, node in enumerate(nodes):
            if "mesh" not in node:
                continue
            frame = self.world(node_index)
            for primitive in self.data["meshes"][node["mesh"]]["primitives"]:
                attributes = primitive["attributes"]
                positions = self.accessor(attributes["POSITION"])[0]
                points.extend(transform(frame, point) for point in positions)
                surfaces += 1
                for accessor in attributes.values():
                    if len(self.accessor(accessor)[0]) != len(positions):
                        raise ValueError("Mesh attribute vertex counts differ")
                for target in primitive.get("targets", []):
                    for accessor in target.values():
                        if len(self.accessor(accessor)[0]) != len(positions):
                            raise ValueError("Morph attribute vertex counts differ")
                indices = self.accessor(primitive["indices"])[0] if "indices" in primitive else None
                if indices is not None and any(len(index) != 1 or not isinstance(index[0], int) or index[0] < 0 or index[0] >= len(positions) for index in indices):
                    raise ValueError("Invalid mesh vertex index")
                count = len(indices) if indices is not None else len(positions)
                mode = primitive.get("mode", 4)
                if mode not in (4, 5, 6):
                    raise ValueError("Nontriangle monster primitive")
                if mode == 4 and count % 3:
                    raise ValueError("Incomplete mesh triangle")
                if "material" not in primitive or not 0 <= primitive["material"] < len(self.data.get("materials", [])):
                    raise ValueError("Mesh surface has no valid material")
                triangles += count // 3 if mode == 4 else max(0, count - 2)
                if "skin" in node:
                    skinned += 1
                    totals = [0.0] * len(positions)
                    joint_count = len(self.data["skins"][node["skin"]]["joints"])
                    if "WEIGHTS_0" not in attributes or "JOINTS_0" not in attributes:
                        raise ValueError("Skinned primitive lacks weights or joints")
                    for name, accessor in attributes.items():
                        if not name.startswith("WEIGHTS_"):
                            continue
                        weights, meta = self.accessor(accessor)
                        joints = self.accessor(attributes["JOINTS_" + name.split("_")[1]])[0]
                        if len(weights) != len(positions) or len(joints) != len(positions):
                            raise ValueError("Skin attribute vertex counts differ")
                        divisor = {5121: 255, 5123: 65535}.get(meta["componentType"], 1) if meta["normalized"] else 1
                        for vertex, (values, bindings) in enumerate(zip(weights, joints)):
                            if any(value < 0 for value in values) or any(binding < 0 or binding >= joint_count for binding in bindings):
                                raise ValueError("Invalid skin weights or bone index")
                            totals[vertex] += sum(values) / divisor
                    zero_weights += sum(value <= 1e-8 for value in totals)
                    max_weight_error = max(max_weight_error, max((abs(value - 1) for value in totals), default=0))
        if not points:
            raise ValueError("Monster has no mesh positions")
        minimum = [min(point[axis] for point in points) for axis in range(3)]
        maximum = [max(point[axis] for point in points) for axis in range(3)]
        if any(not math.isfinite(value) for value in minimum + maximum):
            raise ValueError("Nonfinite transformed bounds")
        images = []
        for image in self.data.get("images", []):
            raw = self.uri(image["uri"]) if "uri" in image else self.view(image["bufferView"])
            images.append({"dimensions": image_size(raw), "bytes": len(raw), "sha256": digest(raw)})
        materials = self.data.get("materials", [])
        return {"format": "gltf2", "files": self.files, "skins": skins,
                "animations": sorted(animations, key=lambda item: item["name"]),
                "bounds": {"minimum": minimum, "maximum": maximum, "height": maximum[1] - minimum[1], "floor": minimum[1], "center": [(a+b)/2 for a,b in zip(minimum,maximum)]},
                "mesh": {"triangles": triangles, "surfaces": surfaces, "skinned_surfaces": skinned, "materials": len(materials),
                         "textured_materials": sum("baseColorTexture" in mat.get("pbrMetallicRoughness", {}) for mat in materials),
                         "maximum_weight_error": max_weight_error, "zero_weight_vertices": zero_weights, "finite_attributes": True}, "images": images}


def snapshot(relative: str) -> dict:
    path = PROJECT / relative
    if path.suffix.lower() == ".fbx":
        raw = path.read_bytes()
        return {"format": "fbx", "files": {relative: {"bytes": len(raw), "sha256": digest(raw)}},
                "limitation": "FBX binary rig/animation payload comparison is unavailable across conversion; require companion Godot runtime contract."}
    return Document(path).snapshot()


def near(a: object, b: object, tolerance: float = 1e-6) -> bool:
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return abs(a - b) <= tolerance
    if isinstance(a, (list, tuple)) and isinstance(b, (list, tuple)):
        return len(a) == len(b) and all(near(x, y, tolerance) for x, y in zip(a, b))
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(near(a[key], b[key], tolerance) for key in a)
    return a == b


def aabb_bounds(value: object) -> dict:
    if not isinstance(value, dict) or set(value) != {"position", "size"}:
        raise ValueError("Canonical normalization bounds must contain position and size")
    for key in ("position", "size"):
        vector = value[key]
        if not isinstance(vector, list) or len(vector) != 3 or any(isinstance(component, bool) or not isinstance(component, (int, float)) or not math.isfinite(component) for component in vector):
            raise ValueError("Canonical normalization bounds require finite vectors")
    if any(size <= 0 for size in value["size"]):
        raise ValueError("Canonical normalization bounds require positive dimensions")
    minimum = value["position"]
    maximum = [position + size for position, size in zip(minimum, value["size"])]
    return {"minimum": minimum, "maximum": maximum, "height": value["size"][1], "floor": minimum[1], "center": [(a+b)/2 for a,b in zip(minimum, maximum)]}


def canonical_bounds(role: str, source: str, replacement: str, current: dict, profiles: dict, runtime_baseline: dict) -> dict:
    """Trust canonical placement only when its identity and immutable oracle agree."""
    entry = profiles["assets"].get("res://" + replacement)
    if not isinstance(entry, dict):
        raise ValueError("Replacement has no registered spectral normalization profile")
    actor = runtime_baseline.get("actors", {}).get(role)
    if not isinstance(actor, dict):
        raise ValueError("Runtime baseline has no canonical actor")
    expected_source = "res://" + source
    if entry.get("enemy_id") != role or entry.get("source") != expected_source or actor.get("source") != expected_source:
        raise ValueError("Canonical normalization profile identity/source differs from immutable baseline")
    bounds = aabb_bounds(entry.get("normalization_bounds"))
    aabb_bounds(actor.get("source_bounds"))
    if not near(entry["normalization_bounds"], actor["source_bounds"], 1e-6):
        raise ValueError("Canonical normalization bounds differ from immutable runtime baseline")
    raw_height = entry.get("raw_height")
    if isinstance(raw_height, bool) or not isinstance(raw_height, (int, float)) or not math.isfinite(raw_height) or abs(raw_height - current["height"]) > max(1e-5, bounds["height"] * 1e-5):
        raise ValueError("Profile raw_height differs from independently measured geometry")
    displacement = entry.get("max_visual_displacement")
    if isinstance(displacement, bool) or not isinstance(displacement, (int, float)) or not math.isfinite(displacement) or not 0 <= displacement <= 0.03:
        raise ValueError("Profile visual displacement must be finite and within 0.03")
    return bounds


def geometry_envelope(bounds: dict, actual: dict) -> list[str]:
    """Bound new silhouettes independently; no hidden vertices to mimic old depth."""
    failures = []
    margin = bounds["height"] * 0.20
    tolerance = max(1e-5, bounds["height"] * 1e-5)
    if any(actual["minimum"][axis] < bounds["minimum"][axis] - margin - tolerance or actual["maximum"][axis] > bounds["maximum"][axis] + margin + tolerance for axis in range(3)):
        failures.append("actual geometry exceeds canonical bounds expanded by 20% of source height")
    if actual["height"] < bounds["height"] * 0.65 - tolerance:
        failures.append("actual geometry height is below 65% of canonical source height")
    return failures


def compare(baseline: dict, profiles: dict | None = None, runtime_baseline: dict | None = None) -> dict:
    errors, limitations, results = [], [], {}
    if baseline.get("schema") != 1 or set(baseline.get("roles", {})) != set(SOURCES):
        raise ValueError("Baseline schema or role roster differs")
    if profiles is not None:
        if profiles.get("version") != 1 or not isinstance(profiles.get("assets"), dict):
            raise ValueError("Spectral normalization profile schema is invalid")
        if not isinstance(runtime_baseline, dict) or runtime_baseline.get("schema_version") != 1 or runtime_baseline.get("kind") != "actual_spawn_rig_contact_baseline":
            raise ValueError("Canonical profiles require the immutable actual-spawn runtime baseline")
        limitations.append("Canonical normalization metadata requires the companion Godot normalized placement, culling and sampled world-contact verifier; raw mesh bounds do not prove those contracts.")
    for role, (source, replacement, budget) in SOURCES.items():
        original = baseline["roles"][role]
        if original.get("source") != source or original.get("replacement") != replacement:
            errors.append(role + ": baseline path contract differs")
            continue
        for path, record in original["snapshot"]["files"].items():
            actual = (PROJECT / path).read_bytes()
            if len(actual) != record["bytes"] or digest(actual) != record["sha256"]:
                errors.append(role + ": retained source changed: " + path)
        try:
            current = snapshot(replacement)
        except (OSError, ValueError, KeyError, IndexError, struct.error) as exc:
            errors.append(role + ": " + str(exc))
            continue
        before = original["snapshot"]
        if before["format"] == "fbx":
            limitations.append(role + ": FBX-to-glTF rig/animation equivalence requires the companion Godot verifier.")
        else:
            if not near(before["skins"], current["skins"]):
                errors.append(role + ": bone names/parents/local transforms/inverse binds changed")
            if before["animations"] != current["animations"]:
                errors.append(role + ": animation channel or accessor payload changed")
        canonical = None
        if profiles is not None:
            try:
                canonical = canonical_bounds(role, source, replacement, current["bounds"], profiles, runtime_baseline)
                errors.extend(role + ": " + failure for failure in geometry_envelope(canonical, current["bounds"]))
            except (ValueError, KeyError, TypeError) as exc:
                errors.append(role + ": " + str(exc))
        if canonical is None and before["format"] != "fbx":
            tolerance = max(1e-5, before["bounds"]["height"] * 1e-5)
            a, b = before["bounds"], current["bounds"]
            if any(abs(a[key] - b[key]) > tolerance for key in ("height", "floor")) or any(abs(a["center"][axis] - b["center"][axis]) > tolerance for axis in (0, 2)):
                errors.append(role + ": source height/floor/horizontal center changed")
        mesh = current["mesh"]
        if mesh["triangles"] > budget:
            errors.append("%s: %d triangles exceed %d" % (role, mesh["triangles"], budget))
        if mesh["zero_weight_vertices"] or mesh["maximum_weight_error"] > 1e-4:
            errors.append(role + ": skin weights are not normalized")
        if not current["skins"] or not mesh["skinned_surfaces"]:
            errors.append(role + ": no skinned monster geometry")
        if any(max(image["dimensions"]) > 1024 for image in current["images"]):
            errors.append(role + ": texture dimensions exceed 1024")
        results[role] = {"before_bounds": before.get("bounds"), "canonical_bounds": canonical, "after_bounds": current["bounds"],
                         "actual_width_depth": [current["bounds"]["maximum"][axis] - current["bounds"]["minimum"][axis] for axis in (0, 2)],
                         "placement_mode": "registered_canonical_bounds" if canonical is not None else "raw_source_bounds", "runtime_contact_verifier_required": True,
                         "before_mesh": before.get("mesh"), "after_mesh": mesh,
                         "before_image_dimensions": [image["dimensions"] for image in before.get("images", [])], "after_image_dimensions": [image["dimensions"] for image in current["images"]]}
    return {"passed": not errors, "roles": results, "errors": errors, "limitations": limitations}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture", action="store_true", help="Create a new baseline; refuses to overwrite an existing file")
    parser.add_argument("--baseline", type=Path, default=BASELINE)
    parser.add_argument("--profiles", type=Path, default=PROFILES, help="Registered canonical bounds; absent file retains strict raw-bound comparison")
    parser.add_argument("--runtime-baseline", type=Path, default=RUNTIME_BASELINE, help="Immutable actual-spawn oracle required when profiles exist")
    parser.add_argument("--report", type=Path, help="Optional comparison report; comparison otherwise writes no files")
    args = parser.parse_args()
    try:
        if args.capture:
            if args.baseline.exists():
                raise ValueError("Refusing to overwrite existing baseline: %s" % args.baseline)
            baseline = {"schema": 1, "roles": {role: {"source": source, "replacement": replacement, "triangle_budget": budget, "snapshot": snapshot(source)} for role, (source, replacement, budget) in SOURCES.items()}}
            args.baseline.parent.mkdir(parents=True, exist_ok=True)
            with args.baseline.open("x", encoding="utf-8") as output:
                json.dump(baseline, output, indent=2, allow_nan=False)
                output.write("\n")
            print("SPECTRAL SOURCE BASELINE: captured 10 roles; FBX equivalence requires Godot runtime verification")
            return 0
        profiles = json.loads(args.profiles.read_text(encoding="utf-8")) if args.profiles.exists() else None
        runtime_baseline = read_contract_json(args.runtime_baseline, 'runtime') if profiles is not None else None
        report = compare(read_contract_json(args.baseline, 'source'), profiles, runtime_baseline)
        if args.report:
            if args.report.resolve() in {args.baseline.resolve(), args.runtime_baseline.resolve(), args.profiles.resolve()}:
                raise ValueError("Report must not overwrite a baseline or registered profile")
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n", encoding="utf-8")
        print("SPECTRAL SOURCE CONTRACT: %s roles=%d errors=%d" % ("PASS" if report["passed"] else "FAIL", len(report["roles"]), len(report["errors"])))
        for message in report["errors"] + report["limitations"]:
            print(message)
        return 0 if report["passed"] else 1
    except (OSError, ValueError, KeyError, IndexError, struct.error) as exc:
        print("SPECTRAL SOURCE CONTRACT: FAIL - " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
