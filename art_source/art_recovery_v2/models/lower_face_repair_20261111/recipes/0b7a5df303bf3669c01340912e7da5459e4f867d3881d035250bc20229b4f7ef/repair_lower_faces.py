"""Restore donor-mapped lower faces in fresh private Blender/GLB successors.

Run with Blender --background --python this_file -- --asset P01 --output <new-dir>.
The production GLB is patched in place in memory. Its JSON, rig, skin, UVs,
weights, animation and all unrelated bytes retain their original layout.
"""
from __future__ import annotations

import argparse
import copy
import decimal
import hashlib
import importlib.util
import json
import math
import struct
import sys
from pathlib import Path
from urllib.parse import unquote

ASSETS = ("C02", "C03", "C04", "C06", "C07", "C08", "C09", "C10", "C11", "C12", "P01")
UV_TOLERANCE = 1e-6
UV_BUCKET = 1e-5
REPOSITORY = Path("D:/Projects/AshenOath")
COMPONENTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
CODES = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def record(path):
    data = path.read_bytes()
    return {"path": str(path), "sha256": sha(data), "bytes": len(data)}


def read_model(path):
    raw = path.read_bytes()
    if raw[:4] == b"glTF":
        if struct.unpack_from("<II", raw, 4) != (2, len(raw)):
            raise ValueError("Unsupported GLB header")
        length, kind = struct.unpack_from("<II", raw, 12)
        if kind != 0x4E4F534A:
            raise ValueError("GLB JSON chunk is missing")
        document = json.loads(raw[20:20 + length])
        size, kind = struct.unpack_from("<II", raw, 20 + length)
        if kind != 0x004E4942 or len(document["buffers"]) != 1:
            raise ValueError("Repair requires one embedded GLB binary buffer")
        start = 28 + length
        return {"path": path, "raw": raw, "document": document,
                "buffers": [bytearray(raw[start:start + size])], "binary_start": start,
                "dependencies": [record(path)]}
    document = json.loads(raw)
    buffers, dependencies = [], [record(path)]
    for buffer in document["buffers"]:
        dependency = (path.parent / unquote(buffer["uri"])).resolve(strict=True)
        buffers.append(bytearray(dependency.read_bytes()))
        dependencies.append(record(dependency))
    return {"path": path, "document": document, "buffers": buffers,
            "dependencies": dependencies}


def accessor(model, index):
    item = model["document"]["accessors"][index]
    if "sparse" in item:
        raise ValueError("Sparse geometry requires a separate authored repair")
    view = model["document"]["bufferViews"][item["bufferView"]]
    fmt = "<" + CODES[item["componentType"]] * COMPONENTS[item["type"]]
    offset = view.get("byteOffset", 0) + item.get("byteOffset", 0)
    stride = view.get("byteStride", struct.calcsize(fmt))
    data = model["buffers"][view.get("buffer", 0)]
    return [struct.unpack_from(fmt, data, offset + i * stride) for i in range(item["count"])]


def write_vertex(model, index, vertex, value):
    item = model["document"]["accessors"][index]
    view = model["document"]["bufferViews"][item["bufferView"]]
    if item["componentType"] != 5126 or item["type"] != "VEC3" or view.get("buffer", 0) != 0:
        raise ValueError("Repair only writes retained float32 VEC3 attributes")
    offset = view.get("byteOffset", 0) + item.get("byteOffset", 0)
    offset += vertex * view.get("byteStride", 12)
    struct.pack_into("<3f", model["buffers"][0], offset, *value)
    return [model["binary_start"] + offset, 12]


def position_bounds_json(model, edits):
    """Replace only existing accessor bounds tokens, retaining other JSON text."""
    raw = model["raw"]
    old_length = struct.unpack_from("<I", raw, 12)[0]
    text = raw[20:20 + old_length].decode("utf-8")
    decoder = json.JSONDecoder()
    spans = {}
    def whitespace(index):
        while index < len(text) and text[index].isspace(): index += 1
        return index
    def walk(index, path):
        index = whitespace(index)
        if len(path) == 3 and path[0] == "accessors" and path[2] in ("min", "max"):
            _, end = decoder.raw_decode(text, index)
            spans[path] = (index, end)
            return end
        if text[index] == "{":
            index = whitespace(index + 1)
            while text[index] != "}":
                key, index = decoder.raw_decode(text, index)
                index = whitespace(index)
                if text[index] != ":": raise ValueError("Unexpected source GLB JSON object")
                index = whitespace(walk(index + 1, path + (key,)))
                if text[index] == ",": index = whitespace(index + 1)
                elif text[index] != "}": raise ValueError("Unexpected source GLB JSON separator")
            return index + 1
        if text[index] == "[":
            index, ordinal = whitespace(index + 1), 0
            while text[index] != "]":
                index = whitespace(walk(index, path + (ordinal,)))
                ordinal += 1
                if text[index] == ",": index = whitespace(index + 1)
                elif text[index] != "]": raise ValueError("Unexpected source GLB JSON array")
            return index + 1
        _, end = decoder.raw_decode(text, index)
        return end
    walk(0, ())
    replacements = []
    for edit in edits:
        for field in ("min", "max"):
            path = ("accessors", edit["accessor"], field)
            if path not in spans: raise ValueError("Changed POSITION accessor has no existing declared bounds")
            start, end = spans[path]
            replacements.append((start, end, json.dumps(edit["after"][field], separators=(",", ":"))))
    for start, end, value in sorted(replacements, reverse=True):
        text = text[:start] + value + text[end:]
    encoded = text.rstrip().encode("utf-8")
    if len(encoded) > old_length:
        raise ValueError("Compact outward POSITION bounds do not fit the retained JSON chunk: " + json.dumps({
            "old_json_bytes":old_length, "new_json_bytes":len(encoded), "bounds_edits":edits,
        }, separators=(",", ":")))
    encoded += b" " * (old_length - len(encoded))
    updated = bytearray(raw[:20])
    updated.extend(encoded)
    updated.extend(raw[20 + old_length:])
    new_start = model["binary_start"]
    updated[new_start:new_start + len(model["buffers"][0])] = model["buffers"][0]
    return bytes(updated), {"json_bounds_edits":edits,
                            "old_binary_start":model["binary_start"], "new_binary_start":new_start,
                            "binary_layout_preserving":True, "json_chunk_length_preserved":True,
                            "old_json_sha256":sha(raw[20:20 + old_length]), "new_json_sha256":sha(encoded)}


def outward_float32_bound(value, minimum):
    """Short outward decimal that still names the exact stored float32 extreme."""
    rounding = decimal.ROUND_FLOOR if minimum else decimal.ROUND_CEILING
    exact = decimal.Decimal.from_float(value)
    for places in range(9, 19):
        candidate = float(exact.quantize(decimal.Decimal(1).scaleb(-places), rounding=rounding))
        enclosed = candidate <= value if minimum else candidate >= value
        if enclosed and struct.unpack("<f", struct.pack("<f", candidate))[0] == value:
            return candidate
    return value


def designs(repository):
    path = repository / "art_source/design_pack_v1/tools/human_designs.py"
    spec = importlib.util.spec_from_file_location("face_repair_designs", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.DESIGNS, path


def legacy_points(donor_point, head_base, neck_base, design):
    """Return the exact legacy authored point immediately before/after its clamp."""
    x, y, z = donor_point[0], -donor_point[2], donor_point[1]
    original_x, original_y, original_z = x, y, z
    local_z = z - (head_base - 1.5496)
    jaw, nose, length = design["face"]
    front = max(0.0, min(1.0, (0.025 - y) / 0.07))
    lower = math.exp(-((local_z - 1.603) / 0.045) ** 2)
    middle = math.exp(-(x / 0.021) ** 2 - ((local_z - 1.647) / 0.038) ** 2)
    x *= 1 + (jaw - 1) * lower
    y -= (nose - 1) * 0.025 * middle * front
    z += (length - 1) * (local_z - 1.69) * lower
    y += 0.0025 * design["age"] * math.exp(-((abs(original_x) - 0.046) / 0.024) ** 2
                                                  - ((local_z - 1.624) / 0.029) ** 2) * front
    if local_z < 1.51:
        z -= 0.020 * max(0.0, min(1.0, (1.53 - local_z) / 0.045))
    before = (x, y, z)
    collar_base = neck_base - 0.04
    radius = math.hypot(x / 0.047, (y - 0.025) / 0.049)
    clamped = abs(x) < 0.20 and collar_base - 0.04 < z < head_base + 0.025 and radius > 1.0
    if clamped:
        x /= radius
        y = 0.025 + (y - 0.025) / radius
    eligible = head_base - 0.035 < original_z < head_base + 0.025 and clamped
    return {"before": before, "after": (x, y, z), "eligible": eligible,
            "radius": radius, "donor_point": (original_x, -original_y, original_z)}


def uv_key(uv):
    return tuple(math.floor(v / UV_BUCKET) for v in uv)


def donor_map(model, head_base, neck_base, design):
    buckets = {}
    for mesh_index, mesh in enumerate(model["document"]["meshes"]):
        for primitive_index, primitive in enumerate(mesh["primitives"]):
            attributes = primitive["attributes"]
            for index, (point, uv) in enumerate(zip(accessor(model, attributes["POSITION"]),
                                                   accessor(model, attributes["TEXCOORD_0"]))):
                if abs(point[0]) > 0.24 or not head_base - 0.12 < point[1] < head_base + 0.12:
                    continue
                row = legacy_points(point, head_base, neck_base, design)
                row.update({"mesh": mesh_index, "primitive": primitive_index, "vertex": index,
                            "uv": uv, "position": point})
                buckets.setdefault(uv_key(uv), []).append(row)
    return buckets


def match_uv(buckets, uv, current):
    key = uv_key(uv)
    matches = []
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for row in buckets.get((key[0] + dx, key[1] + dy), []):
                if max(abs(a - b) for a, b in zip(row["uv"], uv)) > UV_TOLERANCE:
                    continue
                # UV seams may duplicate a position, but mirrored anatomy may
                # never be resolved by choosing an arbitrary nearest point.
                if current[0] * row["position"][0] < -0.0001:
                    continue
                if abs(current[2] - row["before"][2]) > 0.025:
                    continue
                if not any(math.dist(row["position"], old["position"]) < 1e-6 for old in matches):
                    matches.append(row)
    if len(matches) != 1:
        raise ValueError(f"Retained face UV {uv} has {len(matches)} unambiguous donor positions")
    return matches[0]


def matrix_from_node(node):
    from mathutils import Matrix, Quaternion, Vector
    if "matrix" in node:
        return Matrix([[node["matrix"][column * 4 + row] for column in range(4)] for row in range(4)])
    q = node.get("rotation", [0, 0, 0, 1])
    rotation = Quaternion((q[3], q[0], q[1], q[2]))
    return Matrix.LocRotScale(Vector(node.get("translation", [0, 0, 0])), rotation,
                             Vector(node.get("scale", [1, 1, 1])))


def neutral_palettes(model):
    from mathutils import Matrix
    document = model["document"]
    nodes = document["nodes"]
    parents = {child: index for index, node in enumerate(nodes) for child in node.get("children", [])}
    globals_by_node = {}
    def global_for(index):
        if index not in globals_by_node:
            local = matrix_from_node(nodes[index])
            globals_by_node[index] = global_for(parents[index]) @ local if index in parents else local
        return globals_by_node[index]
    if len(document["skins"]) != 1:
        raise ValueError("Expected the single retained human skin")
    skin = document["skins"][0]
    inverse = accessor(model, skin["inverseBindMatrices"])
    palettes, names = [], []
    for index, node in enumerate(skin["joints"]):
        value = inverse[index]
        inverse_bind = Matrix([[value[column * 4 + row] for column in range(4)] for row in range(4)])
        palettes.append(global_for(node) @ inverse_bind)
        names.append(nodes[node]["name"])
    return palettes, names, globals_by_node, global_for


def blend_palette(palettes, joints, weights):
    from mathutils import Matrix
    matrix = Matrix(((0, 0, 0, 0),) * 4)
    for bone, weight in zip(joints, weights):
        if weight:
            matrix += palettes[bone] * weight
    return matrix


def gltf_to_blender(point):
    from mathutils import Vector
    return Vector((point[0], -point[2], point[1]))


def blender_to_gltf(point):
    from mathutils import Vector
    return Vector((point[0], point[2], -point[1]))


def anatomy_material(name):
    return "anatom" in name.lower()


def beard_weights(names, joints, weights):
    values = {names[joint]: float(weight) for joint, weight in zip(joints, weights) if weight > 1e-6}
    return set(values) == {"Head", "Face_Jaw"} and abs(values["Head"] - 0.7) < 1e-5 and abs(values["Face_Jaw"] - 0.3) < 1e-5


def closest_triangle_point(point, a, b, c):
    """Ericson's triangle-region construction using Python double arithmetic."""
    point, a, b, c = (tuple(float(value) for value in vector) for vector in (point, a, b, c))
    def difference(first, second):
        return tuple(x - y for x, y in zip(first, second))
    def dot(first, second):
        return math.fsum(x * y for x, y in zip(first, second))
    def result(weights):
        return tuple(math.fsum(weights[index] * vertex[axis] for index, vertex in enumerate((a, b, c)))
                     for axis in range(3)), tuple(weights)
    ab, ac, ap = difference(b, a), difference(c, a), difference(point, a)
    d1, d2 = dot(ab, ap), dot(ac, ap)
    if d1 <= 0.0 and d2 <= 0.0:
        return result((1.0, 0.0, 0.0))
    bp = difference(point, b)
    d3, d4 = dot(ab, bp), dot(ac, bp)
    if d3 >= 0.0 and d4 <= d3:
        return result((0.0, 1.0, 0.0))
    vc = math.fsum((d1 * d4, -d3 * d2))
    if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0 and d1 != d3:
        v = d1 / (d1 - d3)
        return result((1.0 - v, v, 0.0))
    cp = difference(point, c)
    d5, d6 = dot(ab, cp), dot(ac, cp)
    if d6 >= 0.0 and d5 <= d6:
        return result((0.0, 0.0, 1.0))
    vb = math.fsum((d5 * d2, -d1 * d6))
    if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0 and d2 != d6:
        w = d2 / (d2 - d6)
        return result((1.0 - w, 0.0, w))
    va = math.fsum((d3 * d6, -d5 * d4))
    first, second = d4 - d3, d5 - d6
    if va <= 0.0 and first >= 0.0 and second >= 0.0 and first + second > 0.0:
        w = first / (first + second)
        return result((0.0, 1.0 - w, w))
    denominator = math.fsum((va, vb, vc))
    if denominator > 0.0:
        v, w = vb / denominator, vc / denominator
        return result((va / denominator, v, w))
    # A zero-area face has only edge features. Select the nearest bounded
    # edge projection with a stable edge order, without inventing a surface.
    candidates = []
    for start, end, initial, final in ((a, b, (1, 0, 0), (0, 1, 0)),
                                       (a, c, (1, 0, 0), (0, 0, 1)),
                                       (b, c, (0, 1, 0), (0, 0, 1))):
        edge = difference(end, start)
        length_squared = dot(edge, edge)
        t = max(0.0, min(1.0, dot(difference(point, start), edge) / length_squared)) if length_squared else 0.0
        candidate = result(tuple((1.0 - t) * x + t * y for x, y in zip(initial, final)))
        candidates.append(candidate)
    return min(candidates, key=lambda candidate: math.dist(point, candidate[0]))


def beard_refit(point, before_tree, before_points, after_points, triangles):
    from mathutils import Vector
    bvh_point, _, triangle_index, bvh_distance = before_tree.find_nearest(point)
    if bvh_point is None or triangle_index is None:
        raise ValueError("Authored beard has no original head triangle: " + json.dumps({
            "point":list(point), "bvh_distance_m":bvh_distance,
        }, separators=(",", ":")))
    triangle = triangles[triangle_index]
    a, b, c = (before_points[index] for index in triangle)
    exact_point, barycentric = closest_triangle_point(point, a, b, c)
    distance = math.dist(tuple(point), exact_point)
    if distance > 0.018:
        raise ValueError("Authored beard lacks bounded original surface: " + json.dumps({
            "point":list(point), "nearest":exact_point, "triangle":triangle_index,
            "triangle_vertices":[list(a), list(b), list(c)], "barycentric":barycentric,
            "distance_m":distance, "bvh_distance_m":bvh_distance, "maximum_m":0.018,
        }, separators=(",", ":")))
    if min(barycentric) < 0.0 or max(barycentric) > 1.0:
        raise ValueError("Closest triangle-region construction failed: " + json.dumps({
            "point":list(point), "triangle":triangle_index, "weights":barycentric,
            "vertices":[list(a), list(b), list(c)],
        }, separators=(",", ":")))
    before = Vector(exact_point)
    new_a, new_b, new_c = (after_points[index] for index in triangle)
    before_normal = (b - a).cross(c - a).normalized()
    new_cross = (new_b - new_a).cross(new_c - new_a)
    if new_cross.length_squared < 1e-16:
        raise ValueError("Repaired beard anchor triangle is degenerate")
    after_normal = new_cross.normalized()
    after = new_a * barycentric[0] + new_b * barycentric[1] + new_c * barycentric[2]
    changed = after + before_normal.rotation_difference(after_normal) @ (point - before)
    return changed, {"triangle":triangle_index, "barycentric":list(barycentric),
                     "old_surface_point":list(before), "new_surface_point":list(after),
                     "old_surface_distance_m":distance, "bvh_distance_m":bvh_distance,
                     "projection_method":"float64_ericson_triangle_regions", "old_normal":list(before_normal),
                     "new_normal":list(after_normal)}


def patch_runtime(model, reference, design, head_base, neck_base):
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    document = model["document"]
    palettes, names, _, _ = neutral_palettes(model)
    parts = []
    before_points, after_points, head_faces, head_triangle_ids = [], [], [], []
    for mesh_index, mesh in enumerate(document["meshes"]):
        for primitive_index, primitive in enumerate(mesh["primitives"]):
            if primitive.get("mode", 4) != 4 or "indices" not in primitive:
                raise ValueError("Expected retained indexed triangle surfaces")
            attributes = primitive["attributes"]
            positions = accessor(model, attributes["POSITION"])
            uvs = accessor(model, attributes["TEXCOORD_0"])
            joints = accessor(model, attributes["JOINTS_0"])
            weights = accessor(model, attributes["WEIGHTS_0"])
            indices = [row[0] for row in accessor(model, primitive["indices"])]
            triangles = [tuple(indices[i:i + 3]) for i in range(0, len(indices), 3)]
            material = document["materials"][primitive["material"]]["name"]
            part = {"mesh":mesh_index, "primitive":primitive_index, "attributes":attributes, "positions":positions,
                    "joints":joints, "weights":weights, "triangles":triangles, "face":[], "beard":[],
                    "donors":[], "beard_anchors":[], "material":material, "matrices":[], "before":[], "after":[]}
            for index, point in enumerate(positions):
                matrix = blend_palette(palettes, joints[index], weights[index])
                world = gltf_to_blender(matrix @ Vector(point))
                part["matrices"].append(matrix)
                part["before"].append(world.copy())
                changed = world.copy()
                if anatomy_material(material) and abs(world.x) < 0.24 and head_base - 0.06 < world.z < head_base + 0.045:
                    donor = match_uv(reference, uvs[index], world)
                    if donor["eligible"]:
                        if (world - Vector(donor["after"])).length > 0.018:
                            raise ValueError("Current sculpt differs from clamped donor: " + json.dumps({
                                "stage":"runtime", "file":str(model["path"]), "mesh":mesh_index,
                                "primitive":primitive_index, "vertex":index, "uv":uvs[index],
                                "raw_position":point, "world_blender":list(world),
                                "head_base":head_base, "neck_base":neck_base,
                                "donor":donor, "neutral_palette":[list(row) for row in matrix],
                                "residual_m":(world - Vector(donor["after"])).length,
                            }, separators=(",", ":")))
                        changed += Vector(donor["before"]) - Vector(donor["after"])
                        part["face"].append(index)
                        part["donors"].append(donor)
                part["after"].append(changed)
            if anatomy_material(material):
                offset = len(before_points)
                before_points.extend(part["before"])
                after_points.extend(part["after"])
                for triangle_index, triangle in enumerate(triangles):
                    if all(abs(part["before"][index].x) < 0.24 and part["before"][index].z > head_base - 0.10 for index in triangle):
                        head_faces.append(tuple(offset + index for index in triangle))
                        head_triangle_ids.append({"mesh":mesh_index, "primitive":primitive_index,
                                                  "triangle":triangle_index, "vertices":list(triangle)})
            parts.append(part)
    if not head_faces or not any(part["face"] for part in parts):
        raise ValueError("No uniquely mapped clamped lower-face anatomy was found")
    before_tree = BVHTree.FromPolygons(before_points, head_faces, all_triangles=True)
    for part in parts:
        if anatomy_material(part["material"]): continue
        for index, point in enumerate(part["before"]):
            if not beard_weights(names, part["joints"][index], part["weights"][index]): continue
            if abs(point.x) > 0.10 or not head_base - 0.01 < point.z < head_base + 0.12:
                raise ValueError("Beard-weighted vertex lies outside the authored lower-face region")
            changed, anchor = beard_refit(point, before_tree, before_points, after_points, head_faces)
            if (changed - point).length > 0.000001:
                part["after"][index] = changed
                part["beard"].append(index)
                anchor["surface"] = head_triangle_ids[anchor["triangle"]]
                part["beard_anchors"].append(anchor)
    edits, writes, topology = [], [], []
    for part in parts:
        moved = set(part["face"] + part["beard"])
        if not moved: continue
        attributes = part["attributes"]
        maximum = 0.0
        for index in sorted(moved):
            changed = part["matrices"][index].inverted() @ blender_to_gltf(part["after"][index])
            maximum = max(maximum, (part["after"][index] - part["before"][index]).length)
            if (part["after"][index] - part["before"][index]).length > 0.12:
                raise ValueError("Lower-face repair exceeded the source-derived 120 mm authoring envelope")
            writes.append(write_vertex(model, attributes["POSITION"], index, changed))
            part["positions"][index] = tuple(changed)
        for kind in ("face", "beard"):
            if not part[kind]: continue
            row = {"mesh":part["mesh"], "primitive":part["primitive"], "vertices":part[kind],
                   "attributes":["POSITION"], "kind":"lower_face" if kind == "face" else "beard", "max_delta_m":maximum}
            if kind == "face":
                row["donor_vertices"] = [item["vertex"] for item in part["donors"]]
                row["donor_records"] = [{key:item[key] for key in ("mesh", "primitive", "vertex", "position", "uv", "before", "after", "radius")} for item in part["donors"]]
            else:
                row["beard_anchors"] = part["beard_anchors"]
            edits.append(row)
        touching = [index for index, triangle in enumerate(part["triangles"]) if moved.intersection(triangle)]
        ring = {vertex for index in touching for vertex in part["triangles"][index]}
        touching_ring = [index for index, triangle in enumerate(part["triangles"]) if ring.intersection(triangle)]
        normal_vertices = ring
        sums = {index:Vector() for index in normal_vertices}
        for triangle in part["triangles"]:
            a, b, c = (Vector(part["positions"][index]) for index in triangle)
            normal = (b - a).cross(c - a)
            for index in triangle:
                if index in sums: sums[index] += normal
        for index in sorted(normal_vertices):
            if sums[index].length < 1e-10:
                raise ValueError("A repaired normal has no nondegenerate neighboring triangles")
            writes.append(write_vertex(model, attributes["NORMAL"], index, sums[index].normalized()))
        edits.append({"mesh":part["mesh"], "primitive":part["primitive"], "vertices":sorted(normal_vertices),
                      "attributes":["NORMAL"], "kind":"normal_ring"})
        topology.append({"mesh":part["mesh"], "primitive":part["primitive"], "position_vertices":sorted(moved),
                         "touching_triangles":touching, "normal_ring_triangles":touching_ring,
                         "triangle_indices":[list(part["triangles"][index]) for index in touching_ring]})
    bounds_edits = []
    changed_accessors = sorted({part["attributes"]["POSITION"] for part in parts if part["face"] or part["beard"]})
    for index in changed_accessors:
        item = document["accessors"][index]
        positions = accessor(model, index)
        for vertex, value in enumerate(positions):
            if any(not math.isfinite(component) for component in value):
                raise ValueError("Nonfinite repaired position")
        extrema = {"min":[min(point[axis] for point in positions) for axis in range(3)],
                   "max":[max(point[axis] for point in positions) for axis in range(3)]}
        before = {"min":item["min"], "max":item["max"]}
        after = {field:[old if value == old else outward_float32_bound(value, field == "min")
                        for value, old in zip(extrema[field], before[field])] for field in ("min", "max")}
        if before != after:
            bounds_edits.append({"accessor":index, "before":before, "after":after,
                                 "actual_float32_extrema":extrema})
    raw, bounds = position_bounds_json(model, bounds_edits)
    return raw, edits, writes, topology, bounds


def master_repair(rig, reference, head_base):
    import bpy
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.find_armature() == rig]
    world_to_rig = rig.matrix_world.inverted()
    old_points, new_points, polygons, changes = [], [], [], []
    for obj in meshes:
        uv = obj.data.uv_layers.active
        if uv is None: continue
        anatomy_vertices, vertex_uv = set(), {}
        for polygon in obj.data.polygons:
            material = obj.data.materials[polygon.material_index]
            if material is None or not anatomy_material(material.name): continue
            for loop in polygon.loop_indices:
                vertex = obj.data.loops[loop].vertex_index
                anatomy_vertices.add(vertex)
                value = uv.data[loop].uv
                vertex_uv.setdefault(vertex, []).append((float(value.x), 1.0 - float(value.y)))
        to_rig = world_to_rig @ obj.matrix_world
        old = [to_rig @ vertex.co for vertex in obj.data.vertices]
        for index in sorted(anatomy_vertices):
            world = old[index]
            if abs(world.x) >= 0.24 or not head_base - 0.06 < world.z < head_base + 0.045: continue
            matches = [match_uv(reference, value, world) for value in vertex_uv[index]]
            donor = matches[0]
            if any(math.dist(row["position"], donor["position"]) > 1e-6 for row in matches[1:]):
                raise ValueError("One editable vertex has inconsistent donor UV corners")
            if not donor["eligible"]: continue
            if (world - Vector(donor["after"])).length > 0.018:
                raise ValueError("Editable lower face differs from clamped donor: " + json.dumps({
                    "stage":"editable", "mesh":obj.name, "vertex":index,
                    "world_blender":list(world), "head_base":head_base,
                    "donor":donor, "object_to_rig":[list(row) for row in to_rig],
                    "residual_m":(world - Vector(donor["after"])).length,
                }, separators=(",", ":")))
            delta = to_rig.inverted().to_3x3() @ (Vector(donor["before"]) - Vector(donor["after"]))
            if obj.data.shape_keys:
                for key in obj.data.shape_keys.key_blocks: key.data[index].co += delta
            else:
                obj.data.vertices[index].co += delta
            changes.append({"mesh":obj.name, "vertex":index, "kind":"lower_face"})
        offset = len(old_points)
        old_points.extend(old)
        new_points.extend(to_rig @ vertex.co for vertex in obj.data.vertices)
        for polygon in obj.data.polygons:
            material = obj.data.materials[polygon.material_index]
            if material is not None and anatomy_material(material.name) and all(old[index].z > head_base - 0.10 and abs(old[index].x) < 0.24 for index in polygon.vertices):
                vertices = tuple(offset + index for index in polygon.vertices)
                polygons.extend((vertices[0], vertices[index], vertices[index + 1]) for index in range(1, len(vertices) - 1))
        obj.data.update()
    if not changes or not polygons: raise ValueError("Editable master contains no mapped repairable lower face")
    before_tree = BVHTree.FromPolygons(old_points, polygons, all_triangles=True)
    for obj in meshes:
        to_rig = world_to_rig @ obj.matrix_world
        anatomy_indices = set()
        for polygon in obj.data.polygons:
            material = obj.data.materials[polygon.material_index]
            if material is not None and anatomy_material(material.name):
                anatomy_indices.update(polygon.vertices)
        for vertex in obj.data.vertices:
            if vertex.index in anatomy_indices: continue
            values = {obj.vertex_groups[item.group].name:item.weight for item in vertex.groups if item.weight > 1e-6}
            if set(values) != {"Head", "Face_Jaw"} or abs(values["Head"]-0.7) > 1e-5 or abs(values["Face_Jaw"]-0.3) > 1e-5: continue
            point = to_rig @ vertex.co
            if abs(point.x) > 0.10 or not head_base - 0.01 < point.z < head_base + 0.12: continue
            changed, anchor = beard_refit(point, before_tree, old_points, new_points, polygons)
            delta = to_rig.inverted().to_3x3() @ (changed - point)
            if obj.data.shape_keys:
                for key in obj.data.shape_keys.key_blocks: key.data[vertex.index].co += delta
            else: vertex.co += delta
            changes.append({"mesh":obj.name, "vertex":vertex.index, "kind":"beard", "anchor":anchor})
        obj.data.update()
    return changes


def default_source(art_root, asset):
    folder = (art_root / "models/living_cast_20261107" / asset if asset in {"C02", "C03", "C04"}
              else art_root / "models/living_assets_stage3_20261107/player/P01" if asset == "P01"
              else art_root / "models/living_cast_stage2_20261107" / asset)
    receipt = json.loads((folder / "authoring.json").read_bytes())
    return folder / (asset + "_living_cast_v001.blend"), receipt["blend_sha256"]


def retained_rig_frame(rig, model):
    """Separate the editable carrier's presentation matrix from its bind frame."""
    _, _, _, global_for = neutral_palettes(model)
    nodes = model["document"]["nodes"]
    landmarks = []
    for index in model["document"]["skins"][0]["joints"]:
        name = nodes[index]["name"]
        if name not in rig.data.bones:
            raise ValueError("Retained rig landmark cannot be identified: " + name)
        source = gltf_to_blender(global_for(index).translation)
        editable = rig.data.bones[name].head_local.copy()
        error = (source - editable).length
        landmarks.append({"bone":name, "source_bind":list(source), "editable_rig_local":list(editable), "error_m":error})
        if error > 0.0001:
            raise ValueError("Editable rig-local frame differs from the runtime bind frame: " + json.dumps(landmarks[-1]))
    head_base = next(row["source_bind"][2] for row in landmarks if row["bone"] == "Head")
    neck_base = next(row["source_bind"][2] for row in landmarks if row["bone"] == "neck_01")
    return head_base, neck_base, {"space":"retained rig local, Blender Z up", "landmarks":landmarks,
                                  "presentation_world":[list(row) for row in rig.matrix_world]}


def author(args):
    import bpy
    repository = args.repo.resolve(strict=True)
    game = repository / "outputs/AshenOathTheRoadBetweenCrowns"
    art_root = args.art_root.resolve(strict=True) if args.art_root else repository / "art_source/art_recovery_v2"
    default, default_sha = default_source(art_root, args.asset)
    source = args.source.resolve(strict=True) if args.source else default.resolve(strict=True)
    source_sha = args.source_sha256 if args.source else default_sha
    if source_sha is None or sha(source.read_bytes()) != source_sha:
        raise ValueError("Latest editable source differs from its explicit retained source identity")
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()): raise FileExistsError("Repair output must be new or empty")
    if output.is_relative_to(game) or output.is_relative_to(art_root):
        raise ValueError("Author into the separate private output, preserving current art and runtime files")
    registry = json.loads((game / "data/design_pack_assets.json").read_bytes())
    logical = registry["assets"][args.asset]["path"]
    current_path = game / logical.removeprefix("res://")
    current = read_model(current_path)
    all_designs, design_path = designs(repository)
    design = all_designs[args.asset]
    gender = "Anwen" if design["gender"] == "female" else "Kael"
    donor_path = game / f"assets_external/characters_universal/runtime/{gender}_A_Set_Atlas.gltf"
    donor = read_model(donor_path)
    bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False)
    bpy.context.preferences.filepaths.save_version = 0
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE" and obj.data.bones.get("Face_Jaw")]
    if len(rigs) != 1: raise ValueError("Expected one retained editable human rig")
    rig = rigs[0]
    original_pose_position = rig.data.pose_position
    rig.data.pose_position = "REST"
    head_base, neck_base, frame = retained_rig_frame(rig, current)
    print("LOWER_FACE_AUTHOR_FRAME " + json.dumps({"asset":args.asset,
          "head_base":head_base, "neck_base":neck_base,
          "frame_max_error":max(row["error_m"] for row in frame["landmarks"]),
          "bone_count":len(frame["landmarks"])}, separators=(",", ":")), flush=True)
    reference = donor_map(donor, head_base, neck_base, design)
    repaired, allowed, ranges, topology, bounds = patch_runtime(current, reference, design, head_base, neck_base)
    editable_changes = master_repair(rig, reference, head_base)
    rig.data.pose_position = original_pose_position
    output.mkdir(parents=True, exist_ok=True)
    old_path = output / (args.asset + "_baseline.glb")
    new_path = output / (args.asset + "_face_repaired.glb")
    blend_path = output / (args.asset + "_face_repaired.blend")
    old_path.write_bytes(current["raw"])
    new_path.write_bytes(repaired)
    for image in bpy.data.images:
        if image.has_data and not image.packed_file: image.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    portable = f"art_source/art_recovery_v2/models/lower_face_repair_20261111/{args.asset}/{old_path.name}"
    life = game / f"assets_external/characters_prepared/animations/life_{args.asset}.res"
    prepared = next(row for row in json.loads((game / "data/prepared_actors.json").read_bytes()).values() if row.get("source") == logical)
    prepared_path = game / prepared["path"].removeprefix("res://")
    dependencies = []
    for item in donor["dependencies"]:
        item = dict(item)
        item["path"] = Path(item["path"]).relative_to(repository).as_posix()
        dependencies.append(item)
    certificate = {
        "schema_version":1, "certificate_kind":"lower_face_repair_v1", "asset":args.asset,
        "baseline_commit":"b4b52e4", "byte_layout_preserving":True,
        "model":{"path":logical, "baseline_sha256":sha(current["raw"]), "sha256":sha(repaired)},
        "baseline_model":{"path":portable, "sha256":sha(current["raw"])},
        "baseline_snapshot":record(old_path), "new_glb":record(new_path),
        "editable_source":record(blend_path), "editable_baseline":record(source),
        "editable_rig_frame":frame,
        "donor":{"path":donor_path.relative_to(repository).as_posix(), "sha256":sha(donor_path.read_bytes()),
                 "dependencies":dependencies, "head_base_y":head_base, "neck_base_y":neck_base,
                 "mesh":0, "primitive":0, "uv_tolerance":UV_TOLERANCE},
        "legacy_design":design, "design_source":record(design_path), "repair_tool":record(Path(__file__).resolve()),
        "allowed_edits":allowed, "byte_ranges":ranges, "primitive_witnesses":topology,
        "binary_byte_ranges":[[offset - current["binary_start"], size] for offset, size in ranges],
        "position_bounds":bounds,
        "editable_changes":editable_changes,
        "json_semantics_preserved_except_position_bounds":True,
        "original_json_prefix_sha256":sha(current["raw"][:current["binary_start"]]),
        "prepared":{"path":prepared["path"], "baseline_sha256":sha(prepared_path.read_bytes())},
        "life_library":{"path":"res://" + life.relative_to(game).as_posix(), "sha256":sha(life.read_bytes())},
        "animation_inventory":[action.name for action in bpy.data.actions],
        "authored_changes":"Source-UV inverse neck-ellipse displacement with later sculpt deltas retained; existing beard surface refitted",
        "runtime_reviewed":False, "rendered":False,
    }
    (output / "face_repair.json").write_text(json.dumps(certificate, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"asset":args.asset, "blend":str(blend_path), "glb":str(new_path), "certificate":str(output / "face_repair.json")}), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asset", choices=ASSETS, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--repo", type=Path, default=REPOSITORY)
    parser.add_argument("--art-root", type=Path)
    parser.add_argument("--source", type=Path)
    parser.add_argument("--source-sha256")
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    args = parser.parse_args(arguments)
    if bool(args.source) != bool(args.source_sha256): parser.error("Explicit source and its SHA-256 must be supplied together")
    author(args)


if __name__ == "__main__":
    main()
