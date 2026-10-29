"""Author the C01 source-model draft in Blender, outside the runtime tree.

Run with Blender --background --factory-startup --python this_file.py.
Retains licensed base anatomy and its skin weights; authors the reference's
garments and accessories as editable meshes. Does not modify game manifests.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
import struct
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bake_anatomy import bake_anwen_surface


HERE = Path(__file__).resolve().parents[1]
REPO = HERE.parents[1]
GAME = REPO / "outputs" / "AshenOathTheRoadBetweenCrowns"
BASE = GAME / "assets_external" / "characters_universal"
SOURCE = BASE / "runtime" / "Anwen_A_Set_Atlas.gltf"
TAU = math.tau
COAT_RINGS = [(.19, .31, .22, .035), (.34, .29, .20, .035),
              (.57, .24, .17, .035), (.80, .19, .14, .035),
              (.99, .15, .112, .027), (1.09, .147, .107, .023),
              (1.22, .175, .128, .012), (1.32, .184, .122, .015),
              (1.40, .176, .096, .025), (1.45, .075, .062, .025)]


def material(name, color, roughness=0.8, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


def mesh_object(name, vertices, faces, mat, uv=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    data.materials.append(mat)
    for polygon in data.polygons:
        polygon.use_smooth = True
    if uv:
        layer = data.uv_layers.new(name="UVMap")
        for polygon in data.polygons:
            for loop in polygon.loop_indices:
                layer.data[loop].uv = uv[data.loops[loop].vertex_index]
    return obj


def bind(obj, rig, weight_function):
    obj.parent = rig
    modifier = obj.modifiers.new("C01 skin", "ARMATURE")
    modifier.object = rig
    for vertex in obj.data.vertices:
        weights = weight_function(vertex.co)
        weights = sorted(weights.items(), key=lambda item: -item[1])[:4]
        total = sum(weight for _, weight in weights)
        for name, weight in weights:
            if weight <= 0 or total <= 0:
                continue
            if name not in rig.data.bones:
                raise ValueError(f"Missing required bone {name}")
            group = obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
            group.add([vertex.index], weight / total, "REPLACE")


def body_weights(position):
    z = position.z
    if z < 0.96:
        leg = min(0.7, max(0, (0.96 - z) * 1.6))
        left = max(0, min(1, .5 + position.x / .18))
        return {"pelvis": 1 - leg, "thigh_l": leg * left,
                "thigh_r": leg * (1 - left)}
    levels = [(0.96, "pelvis"), (1.10, "spine_01"),
              (1.24, "spine_02"), (1.40, "spine_03")]
    for (low, lower), (high, upper) in zip(levels, levels[1:]):
        if z <= high:
            t = max(0.0, (z - low) / (high - low))
            return {lower: 1 - t, upper: t}
    return {"spine_03": 1.0}


def garment(name, rings, mat, rig, count=64, opening=0.0, folds=0.007):
    vertices, faces, uv = [], [], []
    for row, (z, rx, ry, center_y) in enumerate(rings):
        for column in range(count + 1):
            t = column / count
            angle = opening + (TAU - 2 * opening) * t
            fold = folds * (math.sin(angle * 13) + 0.3 * math.sin(angle * 23))
            vertices.append(((rx + fold) * math.sin(angle),
                             center_y - (ry + fold) * math.cos(angle), z))
            uv.append((t, row / (len(rings) - 1)))
    for row in range(len(rings) - 1):
        for column in range(count):
            a = row * (count + 1) + column
            faces.append((a, a + 1, a + count + 2, a + count + 1))
    obj = mesh_object(name, vertices, faces, mat, uv)
    bind(obj, rig, body_weights)
    return obj


def tube(name, points, radii, mat, rig, weights, sides=10):
    vertices, faces, uv = [], [], []
    for index, point in enumerate(points):
        center = Vector(point)
        tangent = Vector(points[min(index + 1, len(points) - 1)]) - Vector(points[max(index - 1, 0)])
        tangent.normalize()
        axis = tangent.cross(Vector((0, 1, 0)))
        if axis.length < 0.01:
            axis = tangent.cross(Vector((1, 0, 0)))
        axis.normalize()
        other = tangent.cross(axis).normalized()
        for column in range(sides + 1):
            angle = TAU * column / sides
            v = center + radii[index] * (math.cos(angle) * axis + math.sin(angle) * other)
            vertices.append(tuple(v))
            uv.append((column / sides, index / max(1, len(points) - 1)))
    for index in range(len(points) - 1):
        for column in range(sides):
            a = index * (sides + 1) + column
            faces.append((a, a + 1, a + sides + 2, a + sides + 1))
    faces.append(tuple(reversed(range(sides + 1))))
    start = (len(points) - 1) * (sides + 1)
    faces.append(tuple(start + i for i in range(sides + 1)))
    obj = mesh_object(name, vertices, faces, mat, uv)
    bind(obj, rig, weights)
    return obj


def torso_surface(rig, mat):
    # Open-front coat, not a tube crossing the arms or neck.
    return garment("C01_SlateWool_Coat", COAT_RINGS, mat, rig, opening=.10)


def shawl(rig, mat):
    vertices, faces, uv = [], [], []
    rows, columns = 9, 64
    for row in range(rows):
        t = row / (rows - 1)
        for column in range(columns + 1):
            angle = TAU * column / columns
            back = max(0, -math.cos(angle))
            # The front wraps across the collar; the back drapes lower. The
            # shoulders follow the upper arms instead of staying a rigid cone.
            z = 1.484 - t * (.098 + .20 * back) + .012 * math.sin(angle + .6) * t
            rx = .067 + .176 * math.sin(t * math.pi / 2)
            ry = .072 + .078 * t
            ripple = .005 * math.sin(angle * 9 + t * 4)
            vertices.append(((rx + ripple) * math.sin(angle),
                             .018 - (ry + ripple) * math.cos(angle), z))
            uv.append((column / columns, t))
    for row in range(rows - 1):
        for column in range(columns):
            a = row * (columns + 1) + column
            faces.append((a, a + 1, a + columns + 2, a + columns + 1))
    obj = mesh_object("C01_AshWool_ShoulderShawl", vertices, faces, mat, uv)
    def shawl_weights(p):
        shoulder = max(0, min(.65, (abs(p.x) - .13) * 5))
        return {"spine_03": 1 - shoulder,
                "upperarm_l" if p.x > 0 else "upperarm_r": shoulder}
    bind(obj, rig, shawl_weights)
    for layer in range(3):
        points = []
        for index in range(49):
            angle = TAU * index / 48
            points.append(((.081 + layer * .018) * math.sin(angle),
                           .018 - (.078 + layer * .014) * math.cos(angle),
                           1.475 - layer * .024 - .016 * math.cos(angle - .3)))
        tube("C01_WrappedShawlFold_" + str(layer), points,
             [.012 - layer * .002] * len(points), mat, rig, shawl_weights, 8)
    return obj


def sleeve(rig, side, mat, linen):
    sign = 1 if side == "l" else -1
    upper = rig.data.bones["upperarm_" + side]
    lower = rig.data.bones["lowerarm_" + side]
    points = []
    radii = []
    for i in range(16):
        t = i / 15
        points.append((sign * (.115 + t * .455), .055, 1.418))
        radii.append((.035 + min(1, t * 5) * .039) - .023 * t + .003 * math.sin(t * math.pi * 9))

    def weights(position):
        if abs(position.x) < .21:
            t = max(0, min(1, (abs(position.x) - .15) / .06))
            return {"spine_03": 1 - t, upper.name: t}
        t = max(0, min(1, (abs(position.x) - .35) / .085))
        return {upper.name: 1 - t, lower.name: t}

    tube("C01_SlateSleeve_" + side, points, radii, mat, rig, weights, 20)
    tube("C01_LinenCuff_" + side,
         [(sign * .55, .055, 1.418), (sign * .605, .055, 1.418)],
         [.056, .052], linen, rig, lambda p: {lower.name: 1.0}, 20)


def retain_anatomy(rig, combined, skin_material):
    # Reuse authored hands, boots and facial skin/weights; replace the costume.
    bm = bmesh.new()
    bm.from_mesh(combined.data)
    uv_layer = bm.loops.layers.uv.active
    combined.data.materials.append(skin_material)
    hand_material = len(combined.data.materials) - 1
    remove = []
    for face in bm.faces:
        center = face.calc_center_median()
        keep = center.z > 1.475 or abs(center.x) > .59 or center.z < .17
        # Hair and brows occupy one known atlas tile. Replace both with a
        # pinned-low hair mesh rather than retaining the old high side buns.
        coords = [loop[uv_layer].uv for loop in face.loops]
        if all(.75 < p.x < 1 and .5 < p.y < 1 for p in coords):
            keep = True
        if all(.25 < p.x < .50 and 0 < p.y < .50 for p in coords):
            keep = False
        if all(0 < p.x < .25 and .5 < p.y < 1 for p in coords):
            if center.z > 1.475 and abs(center.x) < .59:
                keep = False
            if abs(center.x) > .605:
                face.material_index = hand_material
        if not keep:
            remove.append(face)
    bmesh.ops.delete(bm, geom=remove, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(combined.data)
    bm.free()
    combined.name = "C01_AuthoredAnatomy_HandsBootsFace"
    combined["provenance"] = "CC0 Quaternius Universal anatomy, existing facial weights; costume replaced"
    return combined


def mature_face(combined):
    # Preserve the topology and expression weights while changing the neutral
    # proportions. Smooth local fields avoid seams between facial skin islands.
    face_vertices = set()
    uv = combined.data.uv_layers.active
    for polygon in combined.data.polygons:
        if all(.75 < uv.data[i].uv.x < 1 and .5 < uv.data[i].uv.y < 1
               for i in polygon.loop_indices):
            face_vertices.update(polygon.vertices)

    def falloff(p, center, radius):
        return math.exp(-sum(((p[i] - center[i]) / radius[i]) ** 2 for i in range(3)) * 2)

    for index in face_vertices:
        vertex = combined.data.vertices[index]
        p = vertex.co.copy()
        x, y, z = p
        if z < 1.51:
            # Close the retained neck into the collar; no floating head cap.
            vertex.co.z -= .016 * max(0, min(1, (1.53 - z) / .045))
            continue
        front = max(0, min(1, (.02 - y) / .07))
        cheek = falloff(p, (math.copysign(.049, x), -.057, 1.62), (.030, .07, .035))
        jaw = falloff(p, (math.copysign(.040, x), -.032, 1.575), (.037, .07, .034))
        bridge = falloff(p, (0, -.08, 1.65), (.018, .065, .036))
        brow = falloff(p, (math.copysign(.030, x), -.063, 1.683), (.031, .045, .018))
        vertex.co.x += math.copysign(.0045 * jaw - .0038 * cheek, x) * front
        vertex.co.y += (.006 * cheek - .004 * bridge - .0028 * brow) * front
        vertex.co.z -= .0055 * jaw * front
        for level in (1.703, 1.715, 1.726):
            line = level + .002 * math.cos(x * 47)
            vertex.co.y += .00045 * math.exp(-((z - line) / .0015) ** 2) * math.exp(-(x / .060) ** 4) * front
    combined.data.update()
    return face_vertices


def cloth_thickness():
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH" or not any(word in obj.name for word in
                ("Coat", "Undergown", "Collar", "Shawl", "Sleeve", "Cuff")):
            continue
        if "Fold" in obj.name:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        modifier = obj.modifiers.new("Woven edge thickness", "SOLIDIFY")
        modifier.thickness = .0025
        modifier.offset = -.4
        modifier.use_even_offset = True
        bpy.ops.object.modifier_move_up(modifier=modifier.name)
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def staff_asset(destination):
    # Separate hand-owned resource. It is not welded into Anwen's skin and
    # cannot remain floating when she puts it down for a care interaction.
    wood = material("C01_StaffAshWood", (.13, .079, .035), .9)
    leather = material("C01_StaffGrip", (.055, .037, .023), .85)
    objects = []
    for name, lower, upper, radius, mat in [
            ("C01_AshStaff", -.86, .65, .018, wood),
            ("C01_PolishedGrip", -.045, .11, .021, leather)]:
        vertices, faces, uv = [], [], []
        rows, columns = (20, 12) if name == "C01_AshStaff" else (9, 12)
        for row in range(rows):
            t = row / (rows - 1)
            z = lower + (upper - lower) * t
            for column in range(columns + 1):
                a = TAU * column / columns
                r = radius * (1 + .06 * math.sin(a * 5 + t * 9))
                bend = .006 * math.sin(t * 4) if name == "C01_AshStaff" else 0
                vertices.append((r * math.cos(a) + bend, r * math.sin(a), z))
                uv.append((column / columns, t))
        for row in range(rows - 1):
            for column in range(columns):
                a = row * (columns + 1) + column
                faces.append((a, a + 1, a + columns + 2, a + columns + 1))
        faces.append(tuple(reversed(range(columns))))
        faces.append(tuple((rows - 1) * (columns + 1) + i for i in range(columns)))
        objects.append(mesh_object(name, vertices, faces, mat, uv))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj["attachment_origin"] = "grip center; local +Y up in exported glTF"
    obj["owner"] = "existing actor activity/equipment hand socket"
    bpy.ops.export_scene.gltf(filepath=str(destination / "C01_ash_staff.glb"),
        export_format="GLB", use_selection=True, export_animations=False, export_yup=True)
    bpy.data.objects.remove(obj, do_unlink=True)


def retained_rig_contract(path, source_path=SOURCE):
    raw = path.read_bytes()
    size, chunk_type = struct.unpack_from("<II", raw, 12)
    if chunk_type != 0x4E4F534A:
        raise ValueError("GLB JSON chunk missing")
    exported = json.loads(raw[20:20 + size])
    source = json.loads(source_path.read_text(encoding="utf-8"))
    source_skin, skin = source["skins"][0], exported["skins"][0]
    source_nodes = {source["nodes"][i]["name"]: source["nodes"][i] for i in source_skin["joints"]}
    exported_nodes = {exported["nodes"][i]["name"]: exported["nodes"][i] for i in skin["joints"]}
    if source_nodes.keys() != exported_nodes.keys():
        raise ValueError("Export changed the retained joint set")
    def local_matrix(node):
        if "matrix" in node:
            values = node["matrix"]
            return Matrix([values[i:i + 4] for i in range(0, 16, 4)]).transposed()
        x, y, z, w = node.get("rotation", [0, 0, 0, 1])
        return Matrix.LocRotScale(Vector(node.get("translation", [0, 0, 0])),
                                  Quaternion((w, x, y, z)),
                                  Vector(node.get("scale", [1, 1, 1])))
    max_error = 0.0
    for name, expected in source_nodes.items():
        actual = exported_nodes[name]
        a, b = local_matrix(expected), local_matrix(actual)
        error = max(abs(a[row][column] - b[row][column]) for row in range(4) for column in range(4))
        if error > 1e-5:
            raise ValueError(f"Rest transform changed: {name}: {error}")
        max_error = max(max_error, error)
        source_children = {source["nodes"][i]["name"] for i in expected.get("children", [])
                           if i in source_skin["joints"]}
        children = {exported["nodes"][i]["name"] for i in actual.get("children", [])
                    if i in skin["joints"]}
        if source_children != children:
            raise ValueError(f"Joint hierarchy changed: {name}")
    return {"joint_count": len(source_nodes), "max_rest_component_error": max_error,
            "scope": "joint names, hierarchy and local rest transforms; not runtime motion acceptance"}


def pinned_hair(rig, mat):
    vertices, faces, uv = [], [], []
    rows, columns = 10, 40
    for row in range(rows):
        t = .025 + .975 * row / (rows - 1)
        for column in range(columns + 1):
            a = TAU * column / columns
            phi = t * (1.15 + .88 * max(0, -math.cos(a)))
            ripple = .0024 * math.sin(a * 22 + t * 9) + .001 * math.sin(a * 47 - t * 6)
            vertices.append(((.087 + ripple) * math.sin(phi) * math.sin(a),
                             .015 - (.087 + ripple) * math.sin(phi) * math.cos(a),
                             1.67 + .117 * math.cos(phi)))
            uv.append((column / columns, t))
    for row in range(rows - 1):
        for column in range(columns):
            a = row * (columns + 1) + column
            faces.append((a, a + 1, a + columns + 2, a + columns + 1))
    obj = mesh_object("C01_PartedHairCap", vertices, faces, mat, uv)
    bind(obj, rig, lambda p: {"Head": 1.0})
    for side in (-1, 1):
        for lock in range(4):
            points = []
            for i in range(17):
                t = i / 16
                points.append((side * (.069 + .012 * math.sin(t * 5 + lock * .24)),
                               -.024 + .014 * lock + .025 * t,
                               1.735 - .118 * t + .004 * math.sin(t * 8 + lock)))
            tube(f"C01_TempleWisp_{side}_{lock}", points,
                 [.0028 * (1 - .85 * i / 16) for i in range(17)], mat, rig,
                 lambda p: {"Head": 1.0}, 5)
    for side in (-1, 1):
        for lock in range(7):
            points = []
            for i in range(12):
                t = i / 11
                p0 = Vector((side * .004, .008 + lock * .004, 1.791 - lock * .001))
                p1 = Vector((side * .052, -.10 + lock * .004, 1.79 - lock * .003))
                p2 = Vector((side * .083, -.018 + lock * .005, 1.673 - lock * .003))
                points.append(tuple((1 - t) ** 2 * p0 + 2 * t * (1 - t) * p1 + t * t * p2))
            tube(f"C01_ForeheadSweep_{side}_{lock}", points,
                 [.004 - .002 * i / 11 for i in range(12)], mat, rig,
                 lambda p: {"Head": 1.0}, 5)
        for strand in range(3):
            points = []
            for i in range(25):
                t = i / 24
                a = t * math.pi * 8 + strand * TAU / 3
                points.append((side * (.075 * (1 - t) + .011 * math.cos(a)),
                               .01 + .103 * t + .009 * math.sin(a),
                               1.73 - .13 * t + .004 * math.sin(a)))
            tube(f"C01_LowBraid_{side}_{strand}", points, [.006] * len(points),
                 mat, rig, lambda p: {"Head": 1.0}, 6)
    for strand in range(3):
        points = []
        for i in range(33):
            a = i * TAU / 32
            r = .025 + .004 * math.sin(a * 6 + strand * TAU / 3)
            points.append((r * math.cos(a), .113 + .005 * strand,
                           1.608 + r * .78 * math.sin(a)))
        tube("C01_PinnedBraidCoil_" + str(strand), points, [.007] * 33,
             mat, rig, lambda p: {"Head": 1.0}, 6)
    for side, label in ((1, "L"), (-1, "R")):
        points = [(side * (.014 + i * .009), -.074, 1.683 + .006 * math.sin(i * math.pi / 4)) for i in range(5)]
        tube("C01_Brow_" + label, points, [.002, .003, .003, .002, .001],
             mat, rig, lambda p, label=label: {"Face_Brow_" + label: 1.0}, 6)


def cloth_atlas(materials, destination, prefix="C01"):
    import numpy as np

    size = 1024
    color = np.ones((size, size, 4), dtype=np.float32)
    orm = np.ones_like(color)
    normal = np.ones_like(color)
    normal[:, :, :3] = (.5, .5, 1)
    for index, mat in enumerate(materials):
        x0, x1 = index % 4 * size // 4, (index % 4 + 1) * size // 4
        y0, y1 = index // 4 * size // 2, (index // 4 + 1) * size // 2
        y, x = np.mgrid[y0:y1, x0:x1]
        weave = np.sin(x * math.pi / 2) * np.sin(y * math.pi / 2)
        mottling = np.sin(x * .043 + np.sin(y * .061)) * np.sin(y * .037)
        modulation = 1 + .035 * weave + .045 * mottling
        if index == 5:
            # Directional hair fibers, not the cloth weave used by garments.
            modulation = 1 + .14 * np.sin(x * 1.7 + np.sin(y * .024)) + .05 * np.sin(x * 3.1 - y * .007)
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        base = bsdf.inputs["Base Color"].default_value[:3]
        for channel in range(3):
            color[y0:y1, x0:x1, channel] = np.clip(base[channel] * modulation, 0, 1)
        orm[y0:y1, x0:x1, 1] = bsdf.inputs["Roughness"].default_value
        orm[y0:y1, x0:x1, 2] = bsdf.inputs["Metallic"].default_value
        if index < 3:
            normal[y0:y1, x0:x1, 0] = .5 + .035 * np.cos(x * math.pi / 2)
            normal[y0:y1, x0:x1, 1] = .5 + .035 * np.cos(y * math.pi / 2)
        for obj in bpy.context.scene.objects:
            if obj.type != "MESH" or mat not in list(obj.data.materials):
                continue
            uv = obj.data.uv_layers.active
            for polygon in obj.data.polygons:
                if obj.data.materials[polygon.material_index] != mat:
                    continue
                for loop_index in polygon.loop_indices:
                    loop = uv.data[loop_index]
                    u, v = loop.uv
                    loop.uv = ((x0 + 4 + u * (x1 - x0 - 8)) / size,
                               (y0 + 4 + v * (y1 - y0 - 8)) / size)
    images = {}
    for name, pixels in (("basecolor", color), ("orm", orm), ("normal", normal)):
        if name == "basecolor":
            linear = pixels[:, :, :3].copy()
            pixels[:, :, :3] = np.where(linear <= .0031308, linear * 12.92,
                                       1.055 * np.power(linear, 1 / 2.4) - .055)
        img = bpy.data.images.new(prefix + "_" + name, width=size, height=size, alpha=True)
        img.colorspace_settings.name = "sRGB" if name == "basecolor" else "Non-Color"
        img.pixels.foreach_set(pixels.reshape(-1))
        img.filepath_raw = str(destination / (prefix + "_" + name + ".png"))
        img.file_format = "PNG"
        img.save()
        img.reload()
        images[name] = img
    mat = material(prefix + "_AuthoredClothesAtlas", (1, 1, 1))
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    texture_nodes = {}
    for name, img in images.items():
        node = nodes.new("ShaderNodeTexImage")
        node.image = img
        texture_nodes[name] = node
    links.new(texture_nodes["basecolor"].outputs["Color"], bsdf.inputs["Base Color"])
    separate = nodes.new("ShaderNodeSeparateColor")
    links.new(texture_nodes["orm"].outputs["Color"], separate.inputs["Color"])
    links.new(separate.outputs["Green"], bsdf.inputs["Roughness"])
    links.new(separate.outputs["Blue"], bsdf.inputs["Metallic"])
    normal_node = nodes.new("ShaderNodeNormalMap")
    links.new(texture_nodes["normal"].outputs["Color"], normal_node.inputs["Color"])
    links.new(normal_node.outputs["Normal"], bsdf.inputs["Normal"])
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        for slot in obj.material_slots:
            if slot.material in materials:
                slot.material = mat


def bell(rig, mat, leather):
    position = Vector((.13, -.12, .90))
    rings = [(0, .030), (.008, .032), (.022, .023), (.045, .015), (.053, .013)]
    vertices, faces, uv = [], [], []
    for row, (height, radius) in enumerate(rings):
        for i in range(25):
            angle = TAU * i / 24
            vertices.append(tuple(position + Vector((radius * math.cos(angle), radius * math.sin(angle), height))))
            uv.append((i / 24, row / 4))
    for row in range(4):
        for i in range(24):
            a = row * 25 + i
            faces.append((a, a + 1, a + 26, a + 25))
    obj = mesh_object("C01_DullBellToken", vertices, faces, mat, uv)
    bind(obj, rig, lambda p: {"pelvis": 1.0})
    tube("C01_BellStrap", [(.13, -.12, .95), (.14, -.123, .995), (.13, -.13, 1.045)],
         [.005] * 3, leather, rig, lambda p: {"pelvis": 1.0}, 8)


def author():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    combined = bpy.data.objects["Anwen_Combined"]
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH" and obj != combined:
            bpy.data.objects.remove(obj, do_unlink=True)
    rig.name = "C01_Anwen_Rig"
    skin = material("C01_HandsSkin", (.59, .42, .29), .73)
    retain_anatomy(rig, combined, skin)
    face_vertices = mature_face(combined)
    slate = material("C01_SlateWool", (.072, .12, .165))
    linen = material("C01_WarmLinen", (.57, .52, .39))
    ash = material("C01_AshWool", (.070, .072, .068))
    leather = material("C01_WornLeather", (.065, .043, .025), .75)
    pewter = material("C01_DullPewter", (.23, .22, .18), .66, .65)
    hair = material("C01_PaleAshHair", (.31, .28, .22), .66)
    inner_rings = [(z, rx - .019, ry - .019, cy) for z, rx, ry, cy in COAT_RINGS]
    inner_rings[0] = (.145, .29, .20, .035)
    garment("C01_LinenUndergown", inner_rings, linen, rig, folds=.004)
    garment("C01_LinenCollar", [(1.435, .070, .065, .025), (1.515, .054, .054, .025)],
            linen, rig, count=32, opening=.12, folds=.002)
    torso_surface(rig, slate)
    shawl(rig, ash)
    for side in ("l", "r"):
        sleeve(rig, side, slate, linen)
    garment("C01_LeatherBelt", [(1.015, .154, .116, .025), (1.07, .152, .114, .025)],
            leather, rig, count=48, folds=0)
    tube("C01_BeltTongue", [(0, -.096, 1.045), (.008, -.123, .94), (.014, -.144, .81)],
         [.012, .011, .009], leather, rig, body_weights, 6)
    buckle_points = [(.028 * math.cos(TAU * i / 32), -.102, 1.043 + .026 * math.sin(TAU * i / 32)) for i in range(33)]
    tube("C01_BeltRing", buckle_points, [.004] * 33, pewter, rig, lambda p: {"pelvis": 1.0}, 8)
    bell(rig, pewter, leather)
    pinned_hair(rig, hair)
    cloth_thickness()
    exports = HERE / "exports"
    exports.mkdir(parents=True, exist_ok=True)
    bake_anwen_surface(combined, face_vertices, exports)
    cloth_atlas([slate, linen, ash, leather, pewter, hair, skin], exports)
    staff_asset(exports)
    # Keep reference invisible to renders and excluded from GLB selection.
    reference = bpy.data.objects.new("REFERENCE_C01_NotRuntime", None)
    reference.empty_display_type = "IMAGE"
    reference.data = bpy.data.images.load(str(HERE / "AshenOath_Asset_Pack/images/characters/C01_Anwen.png"))
    bpy.context.collection.objects.link(reference)
    reference.location = (2.4, 1, 1.0)
    reference.empty_display_size = 2.0
    reference.hide_render = True
    rig["asset_design_id"] = "C01"
    rig["production_status"] = "source_model_draft_not_integrated"
    rig["authored_height_m"] = 1.68
    rig["animation_contract"] = "Retained skeleton; runtime clips supplied by existing animation fusion"
    return rig


def preview_scene(rig):
    # A relaxed source pose, not proof of in-game animation or deformation.
    for side, sign in (("l", 1), ("r", -1)):
        bone = rig.pose.bones["upperarm_" + side]
        bone.rotation_mode = "QUATERNION"
        target = rig.data.bones[bone.name].matrix_local.to_3x3().inverted() @ Vector((sign * .40, 0, -.9165))
        bone.rotation_quaternion = Vector((0, 1, 0)).rotation_difference(target.normalized())
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.015))
    floor = bpy.context.object
    floor.name = "PREVIEW_Floor_NotRuntime"
    floor.data.materials.append(material("PREVIEW_Floor", (.085, .095, .10)))
    for name, location, power, size in [
        ("PREVIEW_Key", (3, -4, 4), 550, 4),
        ("PREVIEW_Fill", (-3, -2, 2.5), 280, 3),
        ("PREVIEW_Rim", (1, 3, 3), 650, 3),
    ]:
        data = bpy.data.lights.new(name, "AREA")
        data.energy = power
        data.shape = "DISK"
        data.size = size
        obj = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(obj)
        obj.location = location
        obj.rotation_euler = (Vector((0, 0, 1)) - obj.location).to_track_quat("-Z", "Y").to_euler()
    data = bpy.data.cameras.new("PREVIEW_Camera")
    camera = bpy.data.objects.new(data.name, data)
    bpy.context.collection.objects.link(camera)
    camera.location = (2.6, -5, 2.3)
    camera.rotation_euler = (Vector((0, 0, .94)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    data.type = "ORTHO"
    data.ortho_scale = 2.25
    scene = bpy.context.scene
    scene.camera = camera
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 900
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.world.color = (.16, .16, .16)
    return scene


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    rig = author()
    models = HERE / "models"
    exports = HERE / "exports"
    models.mkdir(parents=True, exist_ok=True)
    exports.mkdir(parents=True, exist_ok=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    meshes = [bpy.context.object]
    meshes[0].name = "C01_Anwen_Skinned"
    bpy.context.scene.render.engine = "CYCLES"
    # Import display helpers and startup brush materials are not source assets.
    for mat in list(bpy.data.materials):
        if mat.users == 0:
            bpy.data.materials.remove(mat)
    for obj in bpy.context.scene.objects:
        obj.select_set(obj == rig or obj in meshes)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(exports / "C01_anwen_draft.glb"), export_format="GLB",
        use_selection=True, export_animations=False, export_skins=True, export_yup=True)
    rig_contract = retained_rig_contract(exports / "C01_anwen_draft.glb")
    scene = preview_scene(rig)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(models / "C01_anwen_v001.blend"), compress=True)
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    report = {
        "id": "C01", "status": "source_model_draft", "integrated": False,
        "reference": "AshenOath_Asset_Pack/images/characters/C01_Anwen.png",
        "base_topology": str(SOURCE.relative_to(REPO)), "base_sha256": source_hash,
        "license": "Quaternius Universal CC0; existing topology and facial skin weights",
        "meshes": [{"name": o.name, "vertices": len(o.data.vertices),
                    "triangles": sum(len(p.vertices) - 2 for p in o.data.polygons)} for o in meshes],
        "bones": len(rig.data.bones), "runtime_acceptance": "not_performed",
        "retained_rig_contract": rig_contract,
        "runtime_material_surfaces": len({slot.material.name for slot in meshes[0].material_slots}),
        "glb_bytes": (exports / "C01_anwen_draft.glb").stat().st_size,
        "glb_sha256": hashlib.sha256((exports / "C01_anwen_draft.glb").read_bytes()).hexdigest(),
        "remaining": ["Reference-specific facial surface and detailed hair refinement",
                      "Arm deformation and long-skirt stride clearance",
                      "Authored staff socket and retained clip integration",
                      "Godot wrapper, dependency manifests and in-game appearance"],
    }
    (exports / "C01_anwen_draft.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if args.render:
        scene.render.filepath = str(exports / "C01_anwen_draft.png")
        bpy.ops.render.render(write_still=True)
    print("C01_BUILD=" + json.dumps(report))


if __name__ == "__main__":
    main()
