#!/usr/bin/env python3
"""Author original organic Wychwood meshes while retaining the native 43-joint rig.

Ordinary Python launches Blender CPU. Inputs are read-only; NPZ, metadata and
native-animation preview glTFs are written under .release-gate/spectral-monsters.
The NPZ positions/normals are source mesh accessor-local (glTF Y-up) coordinates.
JOINTS_0 indexes the original skin.joints array, never Blender bone indices.
Authoring volumes are fused/remeshed offline; runtime receives one triangle mesh.
"""
from __future__ import annotations

import argparse
import base64
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys

import numpy as np

PROJECT = Path(__file__).resolve().parents[1]
REPO = PROJECT.parents[1]
OUTPUT_ROOT = REPO / ".release-gate/spectral-monsters"
SOURCES = {"stalker": "Demon", "raider": "Orc", "brute": "BlueDemon"}
DTYPES = {5121: "u1", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def arguments():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--roles", nargs="+", choices=SOURCES, default=list(SOURCES))
    parser.add_argument("--output", type=Path, default=OUTPUT_ROOT / "anatomical-bodies")
    parser.add_argument("--blender", default="/usr/bin/blender")
    parser.add_argument("--threads", type=int, default=8)
    parser.add_argument("--triangles", type=int, default=17000)
    parser.add_argument("--voxel-size", type=float, default=0.014)
    args = parser.parse_args(argv)
    args.output = args.output.resolve()
    if not args.output.is_relative_to(OUTPUT_ROOT.resolve()):
        parser.error("--output must be under .release-gate/spectral-monsters")
    if not 8000 <= args.triangles <= 18000 or not 0.008 <= args.voxel_size <= 0.03:
        parser.error("Use 8000–18000 triangles and a 0.008–0.03 authoring voxel size")
    return args


def read_source(path):
    document = json.loads(path.read_bytes())
    uri = document["buffers"][0]["uri"]
    assert len(document["buffers"]) == 1
    binary = bytearray(base64.b64decode(uri.split(",", 1)[1]) if uri.startswith("data:") else (path.parent / uri).read_bytes())
    return document, binary


def read_array(document, binary, accessor):
    a = document["accessors"][accessor]
    v = document["bufferViews"][a["bufferView"]]
    dtype = np.dtype(DTYPES[a["componentType"]])
    width = WIDTHS[a["type"]]
    values = np.ndarray((a["count"], width), dtype=dtype, buffer=binary,
        offset=v.get("byteOffset", 0) + a.get("byteOffset", 0),
        strides=(v.get("byteStride", width * dtype.itemsize), dtype.itemsize)).copy()
    if a.get("normalized"):
        values = values.astype(np.float32) / np.iinfo(dtype).max
    return values


def append_array(document, binary, values, kind, component=5126):
    while len(binary) % 4:
        binary.append(0)
    a = np.asarray(values, dtype=DTYPES[component]).reshape(-1, WIDTHS[kind])
    view = len(document["bufferViews"])
    raw = a.tobytes()
    document["bufferViews"].append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(raw)})
    binary.extend(raw)
    accessor = {"bufferView": view, "componentType": component, "count": len(a), "type": kind}
    if kind == "VEC3":
        accessor.update(min=a.min(0).tolist(), max=a.max(0).tolist())
    index = len(document["accessors"])
    document["accessors"].append(accessor)
    return index


class Anatomy:
    """Closed sculpting volumes plus bind-space weight samples for the final skin."""

    def __init__(self, names):
        self.names = names
        self.vertices, self.faces, self.weights = [], [], []

    def owner(self, value):
        result = np.zeros(len(self.names), dtype=np.float64)
        if isinstance(value, str):
            result[self.names.index(value)] = 1
        else:
            for name, amount in value.items():
                result[self.names.index(name)] = amount
        return result / result.sum()

    def ellipsoid(self, center, radii, owner, rotation=None, rings=12, segments=20):
        center, radii = np.asarray(center), np.asarray(radii)
        rot = np.eye(3) if rotation is None else np.asarray(rotation)
        start = len(self.vertices)
        weights = self.owner(owner)
        # Closed pole fans avoid zero-area polygons at the sphere tips.
        local = [(0, radii[1], 0)]
        for row in range(1, rings):
            phi = math.pi * row / rings
            for col in range(segments):
                theta = 2 * math.pi * col / segments
                local.append((radii[0] * math.sin(phi) * math.cos(theta),
                    radii[1] * math.cos(phi), radii[2] * math.sin(phi) * math.sin(theta)))
        local.append((0, -radii[1], 0))
        self.vertices.extend((np.asarray(local) @ rot.T + center).tolist())
        self.weights.extend([weights] * len(local))
        for col in range(segments):
            self.faces.append((start, start + 1 + (col + 1) % segments, start + 1 + col))
        for row in range(rings - 2):
            for col in range(segments):
                a = start + 1 + row * segments + col
                b = start + 1 + row * segments + (col + 1) % segments
                self.faces.append((a, b, b + segments, a + segments))
        bottom = start + len(local) - 1
        for col in range(segments):
            a = start + 1 + (rings - 2) * segments + col
            b = start + 1 + (rings - 2) * segments + (col + 1) % segments
            self.faces.append((a, b, bottom))

    def tube(self, path, radii, owners, sides=12):
        path = np.asarray(path, dtype=float)
        start = len(self.vertices)
        if isinstance(owners, (str, dict)):
            owners = [owners] * len(path)
        for index, center in enumerate(path):
            tangent = path[min(index + 1, len(path) - 1)] - path[max(index - 1, 0)]
            tangent /= np.linalg.norm(tangent)
            cross_axis = np.array((0, 0, 1)) if abs(tangent[2]) < 0.9 else np.array((0, 1, 0))
            u = np.cross(tangent, cross_axis)
            u /= np.linalg.norm(u)
            v = np.cross(tangent, u)
            radius = radii[index]
            ru, rv = (radius, radius) if np.isscalar(radius) else radius
            weight = self.owner(owners[index])
            for side in range(sides):
                angle = side * 2 * math.pi / sides
                self.vertices.append(center + u * math.cos(angle) * ru + v * math.sin(angle) * rv)
                self.weights.append(weight)
        for row in range(len(path) - 1):
            for side in range(sides):
                a = start + row * sides + side
                b = start + row * sides + (side + 1) % sides
                self.faces.append((a, b, b + sides, a + sides))
        self.faces.append(tuple(start + side for side in reversed(range(sides))))
        self.faces.append(tuple(start + (len(path) - 1) * sides + side for side in range(sides)))


def authored_volumes(role, names, centers, source_bounds):
    a = Anatomy(names)
    c = {name: centers[index] for index, name in enumerate(names)}
    brute = role == "brute"
    slender = 0.80 if role == "stalker" else 0.96 if role == "raider" else 1.36
    # Sternum/ribs, latissimus and pelvic girdle form a fused tapered trunk.
    a.ellipsoid((0, 1.49, -0.255), (0.37 * slender, 0.43, 0.245 if brute else 0.18), "Torso")
    a.ellipsoid((0, 1.14, -0.26), (0.22 * slender, 0.34, 0.15 * slender), {"Abdomen": .75, "Torso": .25})
    a.ellipsoid((0, .87, -.24), (.35 * slender, .23, .20), "Hips")
    a.ellipsoid((0, 1.73, -.31), (.43 * slender, .23, .245 if brute else .16), "Torso")
    a.tube([(0, 1.76, -.21), (0, 1.93, -.11), (0, 2.10, .015)], [.13 if brute else .09, .095, .105], ["Torso", "Neck", "Head"])
    # Raised intercostal ridges retain visible anatomical structure after fusion.
    for side in (-1, 1):
        for rib in range(5):
            y = 1.73 - rib * .115
            width = (.31 - rib * .023) * slender
            depth = .22 if brute else .155
            a.tube([(side * .025, y, -.255 + depth), (side * width * .55, y - .025, -.255 + depth * .94),
                    (side * width, y - .065, -.255 + depth * .4)], [.028, .033, .025], "Torso", sides=8)
        a.tube([(side * .08, 1.83, -.12), (side * .31 * slender, 1.81, -.14), (side * .48, 1.77, -.21)],
               [.04, .05, .08], ["Torso", "Torso", "UpperArm." + ("L" if side > 0 else "R")])
    # Long native arms are recast as tapering tendons with pronounced elbows.
    for suffix, side in [("L", 1), ("R", -1)]:
        upper, lower = "UpperArm." + suffix, "LowerArm." + suffix
        hand = "Middle1." + suffix
        shoulder, elbow, wrist = c[upper], c[lower], c[hand]
        arm_r = .12 * slender
        a.ellipsoid(shoulder, (.22 if brute else .145, .20 if brute else .14, .18 if brute else .14), upper)
        a.tube([shoulder, shoulder * .54 + elbow * .46 + (0, -.035, -.018), elbow,
                elbow * .55 + wrist * .45 + (0, .015, .025), wrist],
               [arm_r, arm_r * .93, arm_r * .67, arm_r * .77, arm_r * .46],
               [upper, upper, {upper: .5, lower: .5}, lower, lower])
        a.ellipsoid(elbow + (0, -.012, -.025), (.10, .11 if brute else .085, .105), {upper: .4, lower: .6})
        a.ellipsoid(wrist + (side * .09, .012, .005), (.17, .068 * slender, .12), hand)
        # Individually articulated pointed fingers replace the mitten silhouettes.
        for digit in ["Pinky", "Middle", "Index"]:
            b1, b2, b3 = [digit + str(i) + "." + suffix for i in (1, 2, 3)]
            p1, p2, p3 = c[b1], c[b2], c[b3]
            p1 = p1 + np.array((side * .105, .007, (p2[2] - p1[2]) * .60))
            tip = p3 + np.array((side * (.18 if digit == "Middle" else .145), -.035, .065))
            a.tube([p1, p2, p3, tip], [.043 if brute else .035, .037, .026, .0025], [b1, b2, b3, b3], sides=9)
        thumb1, thumb2 = "Thumb1." + suffix, "Thumb2." + suffix
        a.tube([c[thumb1] + (side * .03, 0, .02), c[thumb2], c[thumb2] + (side * .08, -.02, .16)],
               [.055, .04, .003], [thumb1, thumb2, thumb2], sides=9)
        # Foot soles remain at the source floor; no phantom normalization anchors.
        thigh, shin, foot = "UpperLeg." + suffix, "LowerLeg." + suffix, "Foot." + suffix
        hip, knee, ankle = c[thigh], c[shin], c[foot]
        a.tube([hip, hip * .55 + knee * .45, knee, knee * .45 + ankle * .55, ankle + (0, .06, .015)],
               [.16 * slender, .14 * slender, .10 * slender, .09 * slender, .09],
               [thigh, thigh, {thigh: .4, shin: .6}, shin, foot])
        a.ellipsoid(knee + (0, .015, .045), (.11 * slender, .13, .105), {thigh: .25, shin: .75})
        sole = float(source_bounds[0][1])
        a.ellipsoid((ankle[0], sole + .105, -.17), (.14 * slender, .105, .26), foot)
        for toe in range(3):
            x = ankle[0] + (toe - 1) * .075
            a.tube([(x, sole + .07, .015), (x, sole + .055, .13), (x + side * .012, sole + .035, .22)],
                   [.047, .036, .003], foot, sides=8)
    # Small skulls with an elongated cranial vault and a separate narrow jaw.
    skull_y = 2.27 if brute else 2.36
    skull_w = .19 if brute else .205
    a.ellipsoid((0, skull_y, .055), (skull_w, .255 if brute else .32, .20), "Head", rings=18, segments=28)
    a.ellipsoid((0, skull_y - .215, .105), (.145, .15, .15), "Head", rings=14, segments=24)
    a.ellipsoid((0, skull_y - .02, .19), (.055, .13, .115), "Head", rings=14, segments=18)
    for side in (-1, 1):
        a.ellipsoid((side * .145, skull_y - .095, .15), (.075, .115, .095), "Head")
        a.tube([(side * .035, skull_y + .075, .22), (side * .125, skull_y + .095, .205), (side * .19, skull_y + .055, .11)],
               [.047, .051, .04], "Head", sides=10)
    if role == "stalker":
        # Split antler crown, tapered bent tips and a ragged scapular mantle.
        for side in (-1, 1):
            a.tube([(side * .14, 2.52, -.005), (side * .25, 2.70, -.06), (side * .28, 2.89, -.04),
                    (side * .20, 3.104, .055)], [.10, .085, .048, .002], "Head")
            a.tube([(side * .25, 2.74, -.045), (side * .43, 2.87, -.12), (side * .49, 2.99, -.075)],
                   [.055, .035, .002], "Head")
            for strip in range(4):
                x = side * (.14 + strip * .105)
                a.tube([(x, 1.85, -.36), (x * 1.25, 1.64, -.49 - strip * .025),
                        (x * 1.45, 1.32 - strip * .08, -.43 - strip * .025)],
                       [(.07, .06), (.065, .035), (.004, .004)], "Torso", sides=8)
    elif role == "raider":
        # Pointed ossified cowl; asymmetrical hanging shreds, no rounded mohawk.
        a.tube([(0, 2.47, -.055), (-.035, 2.72, -.07), (.025, 2.98, -.13), (.02, 3.194, -.20)],
               [(.19, .145), (.15, .10), (.07, .05), .002], "Head", sides=14)
        for side in (-1, 1):
            for strip in range(4):
                x = side * (.14 + strip * .075)
                yend = .28 + (strip % 3) * .14 + (0 if side > 0 else .08)
                a.tube([(x, 1.02, -.25), (x * 1.18, .76, -.28 + (strip % 2) * .13),
                        (x * 1.34, yend, -.19 + strip * .04)],
                       [(.068, .035), (.085, .027), (.002, .003)], "Hips", sides=8)
            a.tube([(side * .27, 1.88, -.25), (side * .47, 1.91, -.31), (side * .70, 1.75, -.40)],
                   [(.09, .05), (.11, .04), .003], "Torso")
    else:
        # Hunched shoulder mass and ossified bark ridge frame a sunken small skull.
        a.ellipsoid((0, 1.90, -.43), (.48, .43, .24), "Torso", rings=16, segments=24)
        for side in (-1, 1):
            a.ellipsoid((side * .38, 1.84, -.28), (.29, .30, .25), "Torso")
            for blade in range(3):
                a.tube([(side * (.20 + blade * .14), 1.93, -.39),
                        (side * (.28 + blade * .17), 2.20 - blade * .07, -.47),
                        (side * (.30 + blade * .19), 2.41 - blade * .09, -.36)],
                       [(.11, .075), (.08, .045), .002], "Torso")
        for blade in range(5):
            y = 1.31 + blade * .17
            tip_y = y + .26 + blade * .075
            a.tube([(0, y, -.47), (0, y + .15, -.68), (0, tip_y, -.58)],
                   [(.09, .12), (.06, .10), .003], "Torso")
        a.tube([(0, 2.13, -.47), (0, 2.50, -.55), (0, 2.831, -.40)],
               [(.15, .12), (.105, .075), .002], "Torso")
    return a, skull_y


def make_mesh(name, anatomy):
    import bpy
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(anatomy.vertices, [], anatomy.faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def apply_modifier(obj, modifier):
    import bpy
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def construct(role, args):
    import bpy
    import bmesh
    from mathutils import Vector
    from mathutils.kdtree import KDTree

    bpy.ops.wm.read_factory_settings(use_empty=True)
    source = PROJECT / "assets_external/enemies/ultimate_monsters" / (SOURCES[role] + ".gltf")
    before_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    document, binary = read_source(source)
    source_document = copy.deepcopy(document)
    primary_node = next(i for i, n in enumerate(document["nodes"]) if n.get("mesh") == 0 and "skin" in n)
    skin_index = document["nodes"][primary_node]["skin"]
    skin = document["skins"][skin_index]
    names = [document["nodes"][i]["name"] for i in skin["joints"]]
    assert len(names) == 43 and names[7] == "Head"
    matrices = read_array(document, binary, skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
    centers = np.linalg.inv(matrices)[:, :3, 3]
    source_points = np.concatenate([read_array(document, binary, p["attributes"]["POSITION"])
        for p in document["meshes"][0]["primitives"]])
    source_bounds = np.array([source_points.min(0), source_points.max(0)])
    anatomy, skull_y = authored_volumes(role, names, centers, source_bounds)
    obj = make_mesh("Authored_" + role, anatomy)
    # Recalculate outward normals before the volumetric union.
    bm = bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(obj.data); bm.free()
    union = obj.modifiers.new("Offline organic union", "REMESH")
    union.mode = "VOXEL"; union.voxel_size = args.voxel_size
    union.use_smooth_shade = True
    apply_modifier(obj, union)
    smooth = obj.modifiers.new("Relax fused anatomy", "SMOOTH")
    smooth.factor = .42; smooth.iterations = 3
    apply_modifier(obj, smooth)
    # Carve real sockets and a narrow jaw opening: no painted cartoon eyes.
    cuts = []
    for side in (-1, 1):
        cuts.append(((side * .100, skull_y + .007, .232), (.087, .094, .155)))
    cuts += [((0, skull_y - .218, .23), (.088, .042, .14)),
             ((0, skull_y - .060, .29), (.028, .055, .067))]
    for index, (center, radii) in enumerate(cuts):
        cutter_anatomy = Anatomy(names)
        cutter_anatomy.ellipsoid(center, radii, "Head", rings=16, segments=24)
        cutter = make_mesh("Temporary facial cavity", cutter_anatomy)
        bm = bmesh.new(); bm.from_mesh(cutter.data)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bm.to_mesh(cutter.data); bm.free()
        boolean = obj.modifiers.new("Carved socket " + str(index), "BOOLEAN")
        boolean.operation = "DIFFERENCE"; boolean.solver = "EXACT"; boolean.object = cutter
        apply_modifier(obj, boolean)
        bpy.data.objects.remove(cutter, do_unlink=True)
    obj.data.calc_loop_triangles()
    triangle_count = len(obj.data.loop_triangles)
    if triangle_count > args.triangles:
        decimate = obj.modifiers.new("Runtime triangle budget", "DECIMATE")
        decimate.ratio = (args.triangles - 80) / triangle_count
        apply_modifier(obj, decimate)
    triangulate = obj.modifiers.new("Explicit runtime triangles", "TRIANGULATE")
    apply_modifier(obj, triangulate)
    # Smooth normals; subtle deterministic ridging is real geometry, not noise FX.
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    vertices = np.array([vertex.co[:] for vertex in obj.data.vertices], dtype=np.float32)
    # Preserve the visible sole plane; only sub-voxel remesh loss is compensated.
    old_min = float(vertices[:, 1].min())
    offset = float(source_bounds[0, 1] - old_min)
    sole_mask = np.clip((.16 - vertices[:, 1]) / .12, 0, 1)
    vertices[:, 1] += sole_mask * offset
    for vertex, point in zip(obj.data.vertices, vertices):
        vertex.co = point
    obj.data.update()
    vertices = np.array([vertex.co[:] for vertex in obj.data.vertices], dtype=np.float32)
    normals = np.array([vertex.normal[:] for vertex in obj.data.vertices], dtype=np.float32)
    indices = np.array([index for face in obj.data.polygons for index in face.vertices], dtype=np.uint32)
    assert len(indices) % 3 == 0 and len(indices) // 3 <= 18000
    # Transfer only from our anatomical bind samples, preventing old prop weights
    # or giant old head surfaces from contaminating the newly sculpted body.
    tree = KDTree(len(anatomy.vertices))
    for i, point in enumerate(anatomy.vertices):
        tree.insert(Vector(point), i)
    tree.balance()
    sample_weights = np.asarray(anatomy.weights)
    weights_all = np.zeros((len(vertices), len(names)), dtype=np.float64)
    for i, point in enumerate(vertices):
        nearest = tree.find_n(Vector(point), 8)
        distances = np.array([hit[2] for hit in nearest])
        influence = 1 / np.maximum(distances, .012) ** 3
        influence /= influence.sum()
        weights_all[i] = (sample_weights[[hit[1] for hit in nearest]] * influence[:, None]).sum(0)
    joints = np.argsort(weights_all, axis=1)[:, -4:][:, ::-1].astype(np.uint16)
    weights = np.take_along_axis(weights_all, joints, axis=1).astype(np.float32)
    weights /= weights.sum(1, keepdims=True)
    assert np.isfinite(vertices).all() and np.isfinite(normals).all()
    assert np.allclose(weights.sum(1), 1, atol=1e-6) and joints.max() < 43
    # A subdued diagnostic surface makes cavities and silhouettes legible.
    grain = np.sin(vertices[:, 0] * 31 + np.sin(vertices[:, 1] * 19)) * np.cos(vertices[:, 2] * 23)
    pigment = .70 + grain * .13
    tint = {"stalker": (.24, .36, .34), "raider": (.34, .30, .28), "brute": (.26, .30, .24)}[role]
    colors = np.column_stack([np.asarray(tint)[None, :] * pigment[:, None], np.ones(len(vertices))]).astype(np.float32)
    skull_mask = (vertices[:, 1] > skull_y - .37) & (np.abs(vertices[:, 0]) < .25)
    colors[skull_mask, :3] = np.array((.42, .45, .39)) * pigment[skull_mask, None]
    # Existing limb attack weights and clips remain native; no animations authored.
    output = args.output / (role + "_body.npz")
    np.savez_compressed(output, positions=vertices, normals=normals, indices=indices,
        joints=joints, weights=weights, colors=colors,
        POSITION=vertices, NORMAL=normals, JOINTS_0=joints, WEIGHTS_0=weights, COLOR_0=colors)
    primitive = {"mode": 4, "material": 0, "attributes": {
        "POSITION": append_array(document, binary, vertices, "VEC3"),
        "NORMAL": append_array(document, binary, normals, "VEC3"),
        "JOINTS_0": append_array(document, binary, joints, "VEC4", 5123),
        "WEIGHTS_0": append_array(document, binary, weights, "VEC4"),
        "COLOR_0": append_array(document, binary, colors, "VEC4")},
        "indices": append_array(document, binary, indices, "SCALAR", 5125)}
    document["meshes"][0] = {"name": "OriginalSpectralAnatomy_" + role, "primitives": [primitive]}
    # Preview clone hides every original prop; primary native node/skin is retained.
    for i, node in enumerate(document["nodes"]):
        if "mesh" in node and i != primary_node:
            del node["mesh"]
    document["materials"] = [{"name": "Diagnostic bone and spectral tissue", "doubleSided": True,
        "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0, "roughnessFactor": .83}}]
    document["buffers"] = [{"uri": "data:application/octet-stream;base64," + base64.b64encode(binary).decode(), "byteLength": len(binary)}]
    preview = output.with_suffix(".gltf")
    preview.write_text(json.dumps(document, separators=(",", ":")))
    assert document["skins"] == source_document["skins"]
    assert document["animations"] == source_document["animations"]
    assert hashlib.sha256(source.read_bytes()).hexdigest() == before_hash
    metadata = {"role": role, "source": str(source.relative_to(PROJECT)), "source_sha256": before_hash,
        "source_mesh_index": 0, "source_node": primary_node, "skin": skin_index,
        "coordinate_space": "original primary mesh accessor-local glTF Y-up bind space",
        "joint_order": names, "head_contact_joint": 7,
        "source_primary_bounds": source_bounds.tolist(),
        "actual_bounds": [vertices.min(0).tolist(), vertices.max(0).tolist()],
        "vertices": len(vertices), "triangles": len(indices) // 3,
        "voxel_size": args.voxel_size, "npz": str(output), "preview": str(preview),
        "preview_material": "diagnostic opaque vertex pigment; no runtime shader or magical FX",
        "normalization": "Use retained source prepared_source_bounds; actual authored mesh is intentionally narrower",
        "method": "original anatomical volumes fused by voxel remesh, carved cavities, decimated skinned triangle surface",
        "weights": "4 normalized native skin indices transferred from authored bind-space anatomical samples",
        "source_unchanged": True, "native_skins_and_animations_unchanged": True}
    output.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n")
    print("AUTHORED BODY: " + json.dumps(metadata), flush=True)


def main():
    args = arguments()
    args.output.mkdir(parents=True, exist_ok=True)
    try:
        import bpy  # noqa: F401
    except ImportError:
        env = os.environ.copy()
        env["BLENDER_USER_RESOURCES"] = str(OUTPUT_ROOT / ".blender-user")
        env["XDG_CACHE_HOME"] = str(OUTPUT_ROOT / ".cache")
        env["XDG_CONFIG_HOME"] = str(OUTPUT_ROOT / ".config")
        command = [args.blender, "--background", "--factory-startup", "--threads", str(args.threads),
            "--python-exit-code", "1", "--python", str(Path(__file__).resolve()), "--",
            "--roles", *args.roles, "--output", str(args.output), "--triangles", str(args.triangles),
            "--voxel-size", str(args.voxel_size), "--threads", str(args.threads)]
        return subprocess.run(command, cwd=REPO, env=env, check=False).returncode
    for role in args.roles:
        construct(role, args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
