"""One-at-a-time, retained-topology human authoring. No baking or game edits.

Inspect inputs (ordinary Python, no bpy):
    python stylized_humans.py --asset C04 --plan
Author a new editable candidate (run explicitly by the main author):
    blender --background --python stylized_humans.py -- --asset C04
Add --render for labelled Workbench turnarounds, after inspecting the source.
Use a new --revision on subsequent passes. C01 belongs to the Anwen tools.

The old pack is face/rig/keepsake salvage, NOT the finished costume. Finished
licensed Peasant/Ranger meshes provide the clothing, limbs and working PBR
bindings. This module deliberately never imports build_humans/build_anwen or
their source-bake/body-generation entry points. Visual acceptance is human.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import shutil
import struct
import sys
import tempfile
from urllib.parse import unquote


RECOVERY = Path(__file__).resolve().parents[1]
REPO = RECOVERY.parents[1]
LEGACY = REPO / "art_source/design_pack_v1"
GAME = REPO / "outputs/AshenOathTheRoadBetweenCrowns"
UNIVERSAL = GAME / "assets_external/characters_universal"
FACE_BONES = tuple("Face_" + name for name in (
    "Eye_L", "Eye_R", "LidUpper_L", "LidUpper_R", "LidLower_L", "LidLower_R",
    "Brow_L", "Brow_R", "Mouth_L", "Mouth_R", "Jaw"))

# jaw, cheek, nose projection, chin length, left eyelid, nose asymmetry (metres).
# Chest/waist/depth/forearm are local surface changes, never rest-bone edits.
# C04 is intentionally first: it is the next authoring invocation, not a batch.
RECIPES = {
    "C04": dict(face=(.006, .003, .002, .002, -.0018, .001),
                body=(1.14, 1.13, 1.16, 1.19), hem=.92, costume="split_apron",
                hair="bald", beard=True, note="Barrel chest, thick forearms, square face; split forge apron, patched thigh, bald scalp and close beard."),
    "C02": dict(face=(-.003, .004, .002, .001, .0004, -.001),
                body=(.94, .92, .95, .97), hem=.77, costume="short_coat",
                hair="compressed_curls", beard=False, note="Narrow cart-working coat, prominent cheekbones, asymmetric smile and cap-flattened curls."),
    "C03": dict(face=(.003, .004, -.001, -.001, -.0005, .0006),
                body=(1.07, 1.10, 1.05, 1.06), hem=.17, costume="work_apron",
                hair="long_braid", beard=False, note="Compact strong build, broad cheeks and squared nose; olive overdress, sage apron and thick braid."),
    "C05": dict(face=(-.003, -.001, .006, .003, -.001, -.0007),
                body=(.91, .96, .94, .94), hem=.15, costume="shawl",
                hair="low_coil", beard=False, note="Narrow shoulders, aquiline nose and settled cheek planes; repaired plum dress, ash shawl and low coil."),
    "C06": dict(face=(-.002, .001, .003, .003, -.0007, .002),
                body=(.95, .93, .96, 1.04), hem=.80, costume="open_vest",
                hair="forward_sweep", beard=True, note="Rangy torso, healed off-centre nose; ochre tunic, open overvest, uneven short beard and forward hair."),
    "C07": dict(face=(.005, .001, .002, .001, -.0012, -.0005),
                body=(1.10, 1.14, 1.09, 1.06), hem=.46, costume="military",
                hair="close_crop", beard=False, ranger=True,
                note="Heavy veteran frame, broad jaw; tailored blue-grey coat, limited breastplate and cropped grey hair."),
    "C08": dict(face=(.001, -.001, .003, .002, -.0005, .0003),
                body=(1.02, .98, 1.01, 1.0), hem=.39, costume="long_coat",
                hair="receding_part", beard=True, note="Controlled mouth and lean cheek planes; symmetrical oxblood overcoat with precise lapels, receding part."),
    "C09": dict(face=(.001, .002, .004, .005, -.0015, -.0004),
                body=(.95, .94, .96, .98), hem=.16, costume="tabard",
                hair="silver_coils", beard=False, note="Tall spare build, long broad-nosed face; indigo gown, parchment tabard and close silver coils."),
    "C10": dict(face=(.004, .004, -.001, -.002, -.0006, .0007),
                body=(1.04, 1.23, 1.14, 1.04), hem=.76, costume="short_coat",
                hair="bare_crown", beard="moustache", note="Pear-shaped waist, soft broad jaw; short tobacco coat, green cuffs, bare crown and trimmed moustache."),
    "C11": dict(face=(.004, .005, -.002, -.002, .0005, .0014),
                body=(1.10, 1.16, 1.09, 1.10), hem=.16, costume="baker_apron",
                hair="crown_braid", beard=False, note="Full strong build, round face and crooked nose; terracotta skirt, indigo bodice, canvas apron and copper braid crown."),
    "C12": dict(face=(.004, .002, .003, .002, -.001, -.0008),
                body=(1.08, .96, 1.01, 1.09), hem=.50, costume="split_coat",
                hair="side_braid", beard=False, note="Wiry shoulders, angular face; split teal weather coat, short rust scarf, close back and practical side braid."),
    "P01": dict(face=(.003, .002, .003, .002, -.0006, .0008),
                body=(1.06, 1.00, 1.04, 1.06), hem=.68, costume="hunter",
                hair="broken_sweep", beard=True, ranger=True,
                note="Athletic hunter, weathered cheek planes; shortened field coat, reinforced shoulder, oath cord and broken side sweep."),
}


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def definitions():
    path = LEGACY / "tools/human_designs.py"
    spec = importlib.util.spec_from_file_location("retained_human_designs", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.DESIGNS


def plan(asset, revision):
    design = definitions()[asset]
    female = design["gender"] == "female"
    prefix = "Female_Peasant" if female else "Male_Peasant"
    libraries = [(UNIVERSAL / (prefix + ".gltf"),
                  [prefix + suffix for suffix in ("_Body", "_Arms", "_Legs", "_Feet")])]
    if RECIPES[asset].get("ranger"):
        libraries[0] = (UNIVERSAL / "Male_Ranger.gltf",
                        ["Male_Ranger_Body", "Male_Ranger_Arms", "Male_Ranger_Legs"])
        libraries.append((UNIVERSAL / "Male_Peasant.gltf", ["Male_Peasant_Feet"]))
    style = RECIPES[asset]["hair"]
    if style != "bald":
        hair = "Hair_Buzzed" if style in ("close_crop", "silver_coils", "compressed_curls", "side_braid") else "Hair_SimpleParted"
        libraries.append((UNIVERSAL / (hair + ".gltf"), [hair]))
    name = asset + "_" + design["name"] + "_stylized_" + revision
    entries = json.loads((LEGACY / "AshenOath_Asset_Pack/data/characters.json").read_text(encoding="utf-8"))["characters"]
    dossier = next((entry for entry in entries if entry["id"] == asset), {})
    return dict(asset=asset, revision=revision, design=design, recipe=RECIPES[asset],
                dossier=dossier, source=LEGACY / "models" / (asset + "_" + design["name"] + ".blend"),
                libraries=libraries, blend=RECOVERY / "models" / (name + ".blend"),
                review=GAME / "art_review/stylized" / asset / revision,
                evidence=RECOVERY / "evidence/stylized" / asset / revision)


def local_resources(path, document):
    result = []
    for group in ("buffers", "images"):
        for item in document.get(group, []):
            uri = item.get("uri", "")
            if uri and not uri.startswith("data:"):
                if re.match(r"^[a-zA-Z]+://", uri):
                    raise ValueError("Only local licensed library resources are allowed: " + uri)
                resource = (path.parent / unquote(uri)).resolve()
                if not resource.is_relative_to(UNIVERSAL.resolve()) or not resource.is_file():
                    raise ValueError("Missing or non-library resource: " + str(resource))
                result.append((group, item, resource))
    return result


def preflight(job):
    inputs = [job["source"], Path(__file__).resolve(), LEGACY / "tools/human_designs.py",
              LEGACY / "AshenOath_Asset_Pack/data/characters.json"]
    if job['asset']=='C05':
        inputs.append(RECOVERY/'models/C01_anwen_stylized_v044.blend')
    for path, names in job["libraries"]:
        doc = json.loads(path.read_text(encoding="utf-8"))
        available = {node.get("name") for node in doc["nodes"] if "mesh" in node}
        if not set(names) <= available:
            raise ValueError(f"Library {path.name} lacks {set(names) - available}")
        inputs.append(path)
        inputs.extend(item[2] for item in local_resources(path, doc))
    if not job["source"].is_file():
        raise FileNotFoundError(job["source"])
    return [{"path": str(path.relative_to(REPO)), "bytes": path.stat().st_size,
             "sha256": sha256(path)} for path in dict.fromkeys(inputs)]


def identity_offset(point, head_z, values):
    x, y, z = point
    z -= head_z
    jaw, cheek, nose, chin, lid, asymmetry = values
    front = max(0., min(1., (.025 - y) / .075))
    field = lambda cx, cz, rx, rz: math.exp(-((abs(x) - cx) / rx) ** 2 - ((z - cz) / rz) ** 2) * front
    jaw_field = field(.045, .045, .045, .030)
    cheek_field = field(.050, .084, .025, .023)
    nose_field = field(0., .100, .018, .028)
    lid_field = field(.030, .110, .019, .009)
    return ((-1 if x < 0 else 1) * (jaw * jaw_field + cheek * cheek_field) + asymmetry * nose_field,
            -nose * nose_field + abs(cheek) * .25 * field(.04, .065, .02, .016),
            -chin * field(0., .028, .050, .025) + lid * lid_field * (1 if x > 0 else .18))


def rig_contract(rig):
    return {bone.name: {"parent": bone.parent.name if bone.parent else None,
                        "rest": [round(value, 7) for row in bone.matrix_local for value in row],
                        "deform": bone.use_deform} for bone in rig.data.bones}


def runtime_object(obj, rig):
    obj.parent = rig
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.matrix_basis = Matrix.Identity(4)
    obj.hide_set(False)
    obj.hide_render = False
    obj["stylized_runtime"] = True
    for modifier in obj.modifiers:
        if modifier.type == "ARMATURE":
            modifier.object = rig
    return obj


def trim(obj, keep):
    bm = bmesh.new()
    try:
        bm.from_mesh(obj.data)
        bmesh.ops.delete(bm, geom=[face for face in bm.faces if not keep(face)], context="FACES")
        bmesh.ops.delete(bm, geom=[vertex for vertex in bm.verts if not vertex.link_faces], context="VERTS")
        bm.to_mesh(obj.data)
    finally:
        bm.free()
    obj.data.update()
    if not obj.data.polygons:
        raise ValueError("Empty retained selection: " + obj.name)


def sculpt(obj, name, offset):
    if obj.data.shape_keys is None:
        obj.shape_key_add(name="Basis")
    key = obj.shape_key_add(name=name, from_mix=False)
    key.value = 1.
    changed, maximum = 0, 0.
    for vertex, target in zip(obj.data.vertices, key.data):
        delta = Vector(offset(vertex.co))
        target.co = vertex.co + delta
        if delta.length > .00001:
            changed += 1
        maximum = max(maximum, delta.length)
    # Subsequent fitting uses authored rest coordinates, not evaluated pose.
    # Keep the edit reversible, with Basis as the pre-sculpt surface.
    obj.data.update()
    return {"mesh": obj.name, "key": name, "changed_vertices": changed, "max_delta_m": maximum}


def authored_tree(obj):
    key = obj.data.shape_keys
    coords = key.key_blocks[-1].data if key else obj.data.vertices
    return BVHTree.FromPolygons([point.co.copy() for point in coords],
                               [list(face.vertices) for face in obj.data.polygons])


def retained_head(source, rig, asset):
    head = source.copy()
    head.data = source.data.copy()
    bpy.context.collection.objects.link(head)
    head.name = asset + "_RetainedWeightedFace"
    head.data.transform(rig.matrix_world.inverted() @ source.matrix_world)
    slots = list(head.data.materials)
    neck_z = rig.data.bones["neck_01"].head_local.z - .035
    trim(head, lambda f: "anatom" in slots[f.material_index].name.lower()
         and f.calc_center_median().z > neck_z and abs(f.calc_center_median().x) < .22)
    return runtime_object(head, rig)


def import_library(path, names, rig):
    """Import only selected meshes; omit donor clips and discard its skeleton."""
    document = json.loads(path.read_text(encoding="utf-8"))
    document.pop("animations", None)
    for node in document["nodes"]:
        if "mesh" in node and node.get("name") not in names:
            node.pop("mesh")
            node.pop("skin", None)
    before = set(bpy.data.objects)
    scratch = Path('D:/Temp/AshenOath/stylized_authoring')
    scratch.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="human-library-", dir=scratch) as folder:
        folder = Path(folder)
        for index, (_, item, resource) in enumerate(local_resources(path, document)):
            target = folder / (str(index) + resource.suffix)
            shutil.copyfile(resource, target)
            item["uri"] = target.name
        temporary = folder / "selected.gltf"
        temporary.write_text(json.dumps(document), encoding="utf-8")
        bpy.ops.import_scene.gltf(filepath=str(temporary))
        imported = set(bpy.data.objects) - before
        donors = [obj for obj in imported if obj.type == "ARMATURE"]
        if len(donors) != 1:
            raise ValueError("Expected one compatible library skeleton")
        donor = donors[0]
        result = [obj for obj in imported if obj.type == "MESH"
                  and re.sub(r'\.\d+$', '', obj.name) in names]
        if len(result) != len(names):
            raise ValueError(f"Selective import mismatch: {names}, {[o.name for o in result]}")
        for obj in result:
            obj.name = 'Library_' + re.sub(r'\.\d+$', '', obj.name)
        transforms = {bone.name: rig.data.bones[bone.name].matrix_local @ bone.matrix_local.inverted()
                      for bone in donor.data.bones if bone.name in rig.data.bones}
        for obj in result:
            to_donor = donor.matrix_world.inverted() @ obj.matrix_world
            obj.data.transform(to_donor)
            for vertex in obj.data.vertices:
                weights = [(obj.vertex_groups[g.group].name, g.weight) for g in vertex.groups if g.weight > 1e-8]
                if not weights or any(name not in transforms for name, _ in weights):
                    raise ValueError("Unmapped donor weights on " + obj.name)
                vertex.co = sum((transforms[name] @ vertex.co * weight for name, weight in weights), Vector()) / sum(w for _, w in weights)
            runtime_object(obj, rig)
            obj["licensed_library"] = str(path.relative_to(REPO))
            # Load images before the temporary resource paths disappear.
            for mat in obj.data.materials:
                if mat and mat.use_nodes:
                    for node in mat.node_tree.nodes:
                        if node.type == "TEX_IMAGE" and node.image:
                            node.image.pack()
        for obj in imported - set(result):
            bpy.data.objects.remove(obj, do_unlink=True)
    return result


def body_offset(point, rig, recipe):
    x, y, z = point
    chest, waist, depth, arm = recipe["body"]
    upper = rig.data.bones["spine_03"].head_local.z
    middle = rig.data.bones["spine_01"].head_local.z
    torso = math.exp(-(abs(x) / .28) ** 6)
    c = math.exp(-((z - upper + .06) / .15) ** 2) * torso
    w = math.exp(-((z - middle) / .18) ** 2) * torso
    dx = x * ((chest - 1) * c + (waist - 1) * w)
    dy = (y - .02) * (depth - 1) * max(c, w)
    dz = 0.
    for side in ("l", "r"):
        elbow = rig.data.bones["lowerarm_" + side].head_local
        wrist = rig.data.bones["hand_" + side].head_local
        axis = wrist - elbow
        t = (point - elbow).dot(axis) / axis.length_squared
        if 0 < t < 1:
            center = elbow + axis * t
            radial = point - center
            if radial.length < .10:
                delta = radial * (arm - 1) * math.sin(math.pi * t)
                dx += delta.x
                dy += delta.y
                dz += delta.z
    return dx, dy, dz


def tailor_body(obj, rig, recipe):
    is_torso = obj.name.endswith("_Body")
    bottom = min(v.co.z for v in obj.data.vertices)
    def offset(p):
        delta = Vector(body_offset(p, rig, recipe))
        if is_torso:
            blend = max(0., min(1., (bottom + .18 - p.z) / .18)) ** 2
            delta.z += (recipe["hem"] - bottom) * blend
            if recipe["hem"] < .30:
                delta.x += p.x * .65 * blend
                delta.y += (p.y - .02) * .35 * blend
                delta.y += .005 * math.sin(p.x * 110) * blend
            if recipe["costume"] in ("split_coat", "short_coat", "hunter"):
                delta.z += .025 * math.sin(p.x * 6) * blend
        return delta
    return sculpt(obj, "TailoredSilhouette", offset)


def mesh_piece(name, vertices, faces, rig, mat, tile, weights, uv=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    layer = data.uv_layers.new(name="UVMap")
    for face in data.polygons:
        face.use_smooth = True
        for loop in face.loop_indices:
            index = data.loops[loop].vertex_index
            u, v = uv[index] if uv else (index % 2, (index // 2) / max(1, len(vertices) // 2 - 1))
            layer.data[loop].uv = ((tile % 4 + .02 + .96 * u) / 4, (tile // 4 + .02 + .96 * v) / 2)
    for index, point in enumerate(vertices):
        values = weights(Vector(point))
        total = sum(values.values())
        if not total or len(values) > 4 or not set(values) <= set(rig.data.bones.keys()):
            raise ValueError("Invalid new-piece binding: " + name)
        for bone, weight in values.items():
            if weight > 0:
                group = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
                group.add([index], weight / total, "REPLACE")
    obj.modifiers.new("RetainedRig", "ARMATURE").object = rig
    return runtime_object(obj, rig)


def torso_weights(point):
    levels = ((.96, "pelvis"), (1.10, "spine_01"), (1.24, "spine_02"), (1.40, "spine_03"))
    for (low, lower), (high, upper) in zip(levels, levels[1:]):
        if point.z < high:
            t = max(0., min(1., (point.z - low) / (high - low)))
            return {lower: 1 - t, upper: t}
    return {"spine_03": 1.}


def tube(name, points, radius, rig, mat, bone="Head", tile=5):
    vertices, faces, uv = [], [], []
    for index, point in enumerate(points):
        point = Vector(point)
        tangent = Vector(points[min(index + 1, len(points) - 1)]) - Vector(points[max(0, index - 1)])
        tangent.normalize()
        cross = tangent.cross(Vector((0, 1, 0)))
        if cross.length < .01:
            cross = tangent.cross(Vector((1, 0, 0)))
        cross.normalize()
        normal = tangent.cross(cross).normalized()
        taper = .28 + .72 * math.sin(math.pi * (.1 + .8 * index / max(1, len(points) - 1)))
        for col in range(6):
            angle = math.tau * col / 6
            vertices.append(tuple(point + radius * taper * (cross * math.cos(angle) + normal * math.sin(angle))))
            uv.append((col / 5, index / max(1, len(points) - 1)))
            if index:
                a = index * 6 + col
                faces.append((a, index * 6 + (col + 1) % 6, (index - 1) * 6 + (col + 1) % 6, a - 6))
    faces.extend((tuple(reversed(range(6))), tuple((len(points) - 1) * 6 + j for j in range(6))))
    return mesh_piece(name, vertices, faces, rig, mat, tile, lambda p: {bone: 1.}, uv)


def costume(job, rig, torso, atlas, clothing):
    """Draft fitted overlays on finished clothing; not replacement anatomy."""
    asset, kind = job["asset"], job["recipe"]["costume"]
    vertices, faces, garment_weights = [], [], []
    for garment in clothing:
        if not garment.name.endswith(('_Body','_Legs')):
            continue
        offset = len(vertices)
        keys = garment.data.shape_keys
        points = keys.key_blocks[-1].data if keys else garment.data.vertices
        vertices.extend(p.co.copy() for p in points)
        garment_weights.extend({garment.vertex_groups[g.group].name:g.weight for g in vertex.groups if g.weight>0}
                               for vertex in garment.data.vertices)
        faces.extend([offset+i for i in f.vertices] for f in garment.data.polygons)
    tree = BVHTree.FromPolygons(vertices, faces)
    from mathutils.kdtree import KDTree
    weight_tree = KDTree(len(vertices))
    for index, point in enumerate(vertices):
        weight_tree.insert(point, index)
    weight_tree.balance()
    def fitted_weights(point):
        _, index, _ = weight_tree.find(point)
        values = garment_weights[index]
        return values or torso_weights(point)
    height_offset = rig.data.bones["neck_01"].head_local.z - 1.45
    def panel(label, low, high, width, tile, split=False, shift=0.):
        vertices, faces, uv = [], [], []
        rows, cols = 28, 20
        for row in range(rows + 1):
            v = row / rows
            z = low + (high - low) * v + height_offset
            half = width * (1 - .35 * max(0., (v - .6) / .4))
            for col in range(cols + 1):
                u = col / cols
                x = shift + (u * 2 - 1) * half
                zz = z + (.13 * max(0., 1 - abs(x) / .025) * (1 - v) ** 4 if split else 0)
                hit, _, _, _ = tree.ray_cast(Vector((x, -.8, zz)), Vector((0, 1, 0)), 1.6)
                y = min(-.10, hit.y) - .025 if hit is not None else -.185
                y -= .003 * math.sin(u * math.pi * 8) * (1 - v)
                vertices.append((x, y, zz))
                uv.append((u, v))
                if row and col:
                    a = row * (cols + 1) + col
                    faces.append((a - cols - 2, a - 1, a, a - cols - 1))
        obj = mesh_piece(asset + "_" + label, vertices, faces, rig, atlas, tile, fitted_weights, uv)
        solid = obj.modifiers.new("TailoredEdgeThickness", "SOLIDIFY")
        solid.thickness = .0025
        solid.offset = 0
        return obj
    pieces = []
    if kind == "split_apron":
        pieces += [panel("SplitLeatherApron", .46, 1.42, .235, 3, True),
                   panel("HotScaleThighPatch", .53, .72, .055, 2, shift=.10)]
    elif kind in ("work_apron", "baker_apron"):
        pieces.append(panel("FittedWorkApron", .29, 1.38, .205, 2 if kind == "work_apron" else 1))
    elif kind == "tabard":
        pieces.append(panel("ArchiveTabard", .35, 1.43, .145, 1))
    elif kind in ("short_coat", "long_coat", "split_coat", "hunter", "open_vest", "military"):
        if not job['recipe'].get('ranger') and kind!='split_coat':
            # Use actual fitted garment topology around the sides/back, not
            # two free-standing rectangles masquerading as coat lapels.
            coat=torso.copy()
            coat.data=torso.data.copy()
            bpy.context.collection.objects.link(coat)
            coords=[p.co.copy() for p in torso.data.shape_keys.key_blocks[-1].data]
            coat.shape_key_clear()
            for vertex,point in zip(coat.data.vertices,coords):
                vertex.co=point
            low=max(.28,job['recipe']['hem'])+.035
            neckline=rig.data.bones['neck_01'].head_local.z
            def keep_coat(face):
                p=face.calc_center_median()
                gap=.035+.105*max(0.,(p.z-(neckline-.28))/.28)
                return p.z>low and p.z<neckline-.015 and not(p.y<.03 and abs(p.x)<gap)
            trim(coat,keep_coat)
            coat.data.update()
            for vertex in coat.data.vertices:
                vertex.co+=vertex.normal*.018
            coat.data.materials.clear()
            coat.data.materials.append(atlas)
            tile=3 if kind in ('short_coat','open_vest') else 0
            for face in coat.data.polygons:
                face.material_index=0
                for loop in face.loop_indices:
                    p=coat.data.vertices[coat.data.loops[loop].vertex_index].co
                    u=max(0.,min(1.,p.x/.6+.5))
                    v=max(0.,min(1.,(p.z-low)/max(.1,neckline-low)))
                    coat.data.uv_layers.active.data[loop].uv=((tile%4+.02+.96*u)/4,(tile//4+.02+.96*v)/2)
            coat.name=asset+'_FittedOpenOvercoat'
            thickness=coat.modifiers.new('RealGarmentEdge','SOLIDIFY')
            thickness.thickness=.003
            pieces.append(runtime_object(coat,rig))
        if kind == 'military':
            pieces.append(panel('CutOathRibbon',1.23,1.37,.012,1,shift=.085))
        if kind == "split_coat":
            vertices,faces,uv=[],[],[]
            neck=rig.data.bones['neck_01'].head_local.z
            for row in range(7):
                v=row/6
                for col in range(33):
                    a=math.tau*col/32
                    vertices.append(((.080+.055*v)*math.sin(a),.025-(.065+.047*v)*math.cos(a),
                                     neck-.015-.075*v+.006*math.sin(a*3)*v))
                    uv.append((col/32,v))
                    if row and col:
                        k=row*33+col
                        faces.append((k-34,k-33,k,k-1))
            scarf=mesh_piece(asset+'_WrappedRustScarf',vertices,faces,rig,atlas,2,
                             lambda p:{'spine_03':.8,'neck_01':.2},uv)
            scarf.modifiers.new('ScarfEdge','SOLIDIFY').thickness=.002
            pieces.append(scarf)
    if kind == "shawl":
        path=RECOVERY/'models/C01_anwen_stylized_v044.blend'
        with bpy.data.libraries.load(str(path),link=False) as (available,loaded):
            loaded.objects=['Anwen_Diagonal_Wrapped_Shawl']
        shawl=loaded.objects[0]
        bpy.context.collection.objects.link(shawl)
        donor=shawl.find_armature()
        if donor is None:
            raise ValueError('Retained diagonal wrap has no compatible garment binding')
        transform=donor.matrix_world.inverted()@shawl.matrix_world
        corrections={bone.name:rig.data.bones[bone.name].matrix_local@bone.matrix_local.inverted()
                     for bone in donor.data.bones if bone.name in rig.data.bones}
        for vertex in shawl.data.vertices:
            p=transform@vertex.co
            values={shawl.vertex_groups[g.group].name:g.weight for g in vertex.groups if g.weight>0}
            if not values or not set(values)<=set(corrections):
                raise ValueError('Unmapped retained wrap weight')
            vertex.co=sum((corrections[name]@p*value for name,value in values.items()),Vector())/sum(values.values())
            vertex.co.x*=.94
            vertex.co.y=(vertex.co.y-.02)*1.08+.02
        shawl.parent=rig
        shawl.matrix_parent_inverse=Matrix.Identity(4)
        shawl.matrix_basis=Matrix.Identity(4)
        shawl.modifiers.clear()
        shawl.modifiers.new('RetainedWrapRig','ARMATURE').object=rig
        shawl.modifiers.new('WoolThickness','SOLIDIFY').thickness=.003
        shawl.name = asset + "_AsymmetricAshShawl"
        shawl.data.materials.clear()
        shawl.data.materials.append(atlas)
        for polygon in shawl.data.polygons:
            polygon.material_index = 0
            for loop in polygon.loop_indices:
                p=shawl.data.vertices[shawl.data.loops[loop].vertex_index].co
                shawl.data.uv_layers.active.data[loop].uv = (.51+.22*max(0.,min(1.,p.x/.65+.5)),.02+.45*max(0.,min(1.,(p.z-1.15)/.5)))
        pieces.append(runtime_object(shawl, rig))
    return pieces


def groom(job, rig, head, hair_objects, atlas):
    asset, recipe = job["asset"], job["recipe"]
    base = rig.data.bones["Head"].head_local.z
    tree = authored_tree(head)
    center = Vector((0, .015, base + .135))
    style = recipe["hair"]
    for obj in hair_objects:
        # Reuse the person's existing directional-hair atlas tile. This also
        # keeps the added braid/beard and the licensed scalp surface coherent.
        uv = obj.data.uv_layers.active
        if uv is None:
            raise ValueError("Licensed hairstyle has no working UVs: " + obj.name)
        for loop in uv.data:
            u, v = loop.uv
            loop.uv = ((1.02 + .96 * max(0., min(1., u))) / 4,
                       (1.02 + .96 * max(0., min(1., v))) / 2)
        obj.data.materials.clear()
        obj.data.materials.append(atlas)
        for polygon in obj.data.polygons:
            polygon.material_index = 0
        for vertex in obj.data.vertices:
            direction = (vertex.co - center).normalized()
            hit, normal, _, _ = tree.ray_cast(center + direction * .4, -direction, .8)
            if hit is not None:
                extra = .003 if style in ("close_crop", "side_braid") else .008
                extra += .003 * math.sin(vertex.co.x * 160) ** 2 if style in ("silver_coils", "compressed_curls") else 0
                if style == "forward_sweep":
                    extra += .008 * max(0., -direction.y) * max(0., direction.z)
                elif style == "broken_sweep":
                    extra += .005 * math.sin(direction.x * 19 + direction.z * 13) ** 2 * max(0., direction.z)
                vertex.co = hit + normal * extra
                if style == "compressed_curls" and vertex.co.x < 0:
                    vertex.co.z -= .003
        trim(obj, lambda f: f.calc_center_median().z > base + .12 or f.calc_center_median().y > .025)
        if style in ("bare_crown", "receding_part"):
            trim(obj, lambda f: f.calc_center_median().z < base + .215
                 or (abs(f.calc_center_median().x) > (.058 if style == "bare_crown" else .035)))
        obj.name = asset + "_" + style + "_FittedLicensedHair"
    pieces = []
    if style in ("long_braid", "side_braid", "crown_braid", "low_coil"):
        anchor, anchor_normal, _, _ = tree.find_nearest(Vector((.06 if style=='side_braid' else .02,.075,base+.13)))
        for strand in range(3):
            points = []
            for step in range(25):
                t = step / 24
                a = math.tau * (t * (3 if style in ("long_braid", "side_braid") else 1) + strand / 3)
                if style == "crown_braid":
                    q = math.tau * t
                    point = (.082 * math.sin(q), .012 + .085 * math.cos(q), base + .195 + .006 * math.sin(a))
                elif style == "low_coil":
                    q = math.tau * t
                    point = (.028 * math.cos(q), .105 + .006 * math.sin(a), base + .09 + .026 * math.sin(q))
                else:
                    side = .083 if style == "side_braid" else .025
                    length = .12 if style == "side_braid" else .34
                    point = (side + .009 * math.cos(a), .105 + .008 * math.sin(a), base + .12 - length * t)
                    if anchor is not None:
                        old_root = Vector((side,.105,base+.12))
                        point = Vector(point) + (anchor+anchor_normal*.004-old_root)*(1-t)**3
                points.append(point)
            pieces.append(tube(asset + "_BraidedLock_" + str(strand), points, .006, rig, atlas))
    for sign, side in ((1, "L"), (-1, "R")):
        points = []
        for step in range(7):
            x = sign * (.012 + .042 * step / 6)
            z = base + .130 + .005 * math.sin(step / 6 * math.pi)
            hit, _, _, _ = tree.ray_cast(Vector((x, -.5, z)), Vector((0, 1, 0)), 1.)
            if hit is not None:
                points.append((x, hit.y - .0025, z))
        if len(points) > 1:
            pieces.append(tube(asset + "_Brow_" + side, points, .0018, rig, atlas, "Face_Brow_" + side))
    if recipe["beard"]:
        # A fitted continuous lower-face surface replaces the tooth-like row
        # of disconnected tubes. Leave the actual lip opening uncovered.
        vertices, faces, uv, grid = [], [], [], {}
        moustache = recipe['beard']=='moustache'
        for row in range(9):
            t = row/8
            for col in range(21):
                u = col/20
                x = (2*u-1)*(.048 if moustache else .055)*(1-.12*t)
                z = base + (.078-.012*t if moustache else .048-.033*t-.003*(1-abs(2*u-1)))
                hit, normal, _, _ = tree.ray_cast(Vector((x,-.5,z)),Vector((0,1,0)),1.)
                if hit is None: continue
                grid[row,col] = len(vertices)
                vertices.append(tuple(hit+normal*.002))
                uv.append((u,t))
                corners = [(row-1,col-1),(row,col-1),(row,col),(row-1,col)]
                if row and col and all(c in grid for c in corners):
                    faces.append(tuple(grid[c] for c in corners))
        if faces:
            beard = mesh_piece(asset+'_FittedContinuousBeard',vertices,faces,rig,atlas,5,
                               lambda p:{'Head':.7,'Face_Jaw':.3},uv)
            solid = beard.modifiers.new('Close beard surface','SOLIDIFY')
            solid.thickness = .0015
            pieces.append(beard)
    return pieces


def salvage_keepsakes(source, rig, asset):
    """Keep only small detached belt keepsakes, never the factory body/clothes."""
    bm = bmesh.new()
    selected = set()
    try:
        bm.from_mesh(source.data)
        bm.verts.ensure_lookup_table()
        seen = set()
        for start in bm.verts:
            if start in seen:
                continue
            todo, component = [start], set()
            while todo:
                vertex = todo.pop()
                if vertex in component:
                    continue
                component.add(vertex)
                todo.extend(edge.other_vert(vertex) for edge in vertex.link_edges if edge.other_vert(vertex) not in component)
            seen.update(component)
            if not 8 <= len(component) <= 550:
                continue
            center = sum((v.co for v in component), Vector()) / len(component)
            span = [max(v.co[i] for v in component) - min(v.co[i] for v in component) for i in range(3)]
            if .58 < center.z < 1.12 and .105 < abs(center.x) < .32 and center.y < -.10 and max(span) < .24:
                selected.update(v.index for v in component)
    finally:
        bm.free()
    if not selected:
        return []
    obj = source.copy()
    obj.data = source.data.copy()
    bpy.context.collection.objects.link(obj)
    obj.data.transform(rig.matrix_world.inverted() @ source.matrix_world)
    obj.name = asset + "_LegacyBeltKeepsakeSalvage"
    trim(obj, lambda f: all(v.index in selected for v in f.verts))
    obj["semantic_status"] = "Legacy detached belt pieces; dossier-specific prop fidelity requires inspection"
    return [runtime_object(obj, rig)]


def private_materials(meshes, directory, design):
    """Copy existing working maps; no rebake, procedural surface or source edits."""
    directory.mkdir(parents=True)
    materials, images, manifest = {}, {}, []
    for obj in meshes:
        for slot in obj.material_slots:
            original = slot.material
            if original is None:
                raise ValueError("Unbound runtime material on " + obj.name)
            if original not in materials:
                mat = original.copy()
                materials[original] = mat
                mat.name = design["name"] + "_" + original.name
                if mat.use_nodes:
                    for node in mat.node_tree.nodes:
                        if node.type != "TEX_IMAGE" or node.image is None:
                            continue
                        old = node.image
                        if old not in images:
                            image = old.copy()
                            if max(image.size)>1024:
                                ratio = 1024/max(image.size)
                                image.scale(max(1,round(image.size[0]*ratio)),max(1,round(image.size[1]*ratio)))
                            if 'basecolor' in old.name.lower() and ('peasant' in old.name.lower() or 'ranger' in old.name.lower()):
                                # Recolour the identifiable light fabric/green
                                # cloth regions, not skin, dark leather or metal.
                                import numpy as np
                                pixels = np.empty(len(image.pixels),dtype=np.float32)
                                image.pixels.foreach_get(pixels)
                                pixels = pixels.reshape((-1,4))
                                r,g,b = pixels[:,0],pixels[:,1],pixels[:,2]
                                cloth = ((r>.35)&(g>.33)&(b>.25)&((r-b)<.20)&(r<g*1.3)&(r<.94))
                                cloth |= (g>r*1.15)&(g>b*1.05)&(g>.12)
                                code = design['colors'][0]
                                target = np.array([int(code[i:i+2],16)/255 for i in (0,2,4)])
                                luminance = .2126*r+.7152*g+.0722*b
                                pixels[cloth,:3] = np.clip(luminance[cloth,None]/.65*target[None,:],0,1)
                                image.pixels.foreach_set(pixels.reshape(-1))
                            safe = re.sub(r"[^A-Za-z0-9_.-]", "_", old.name)[:70]
                            path = directory / (f"{len(images):02d}_" + safe + ".png")
                            image.filepath_raw = str(path)
                            image.file_format = "PNG"
                            image.save()
                            # An Image.copy can retain the donor's packed PNG.
                            # Replace those bytes explicitly after resizing.
                            encoded = path.read_bytes()
                            image.pack(data=encoded, data_len=len(encoded))
                            images[old] = image
                            manifest.append({"file": path.name, "size": list(image.size),
                                             "colorspace": image.colorspace_settings.name,
                                             "sha256": sha256(path)})
                        node.image = images[old]
                    bsdf = mat.node_tree.nodes.get("Principled BSDF")
                    if bsdf and bsdf.inputs["Base Color"].is_linked:
                        node = bsdf.inputs["Base Color"].links[0].from_node
                        if node.type == "TEX_IMAGE":
                            mat.node_tree.nodes.active = node
            slot.material = materials[original]
    return manifest


def validate_runtime(meshes, rig):
    face_weights = set()
    for obj in meshes:
        if not obj.data.uv_layers.active or not obj.data.materials:
            raise ValueError("Missing UV/material contract: " + obj.name)
        for vertex in obj.data.vertices:
            weights = [(obj.vertex_groups[g.group].name, g.weight) for g in vertex.groups
                       if g.weight > 1e-7 and obj.vertex_groups[g.group].name in rig.data.bones]
            if not weights or len(weights) > 4 or abs(sum(w for _, w in weights) - 1) > .002:
                raise ValueError(f"Invalid retained skin weights: {obj.name}:{vertex.index}")
            face_weights.update(name for name, _ in weights if name.startswith("Face_"))
        if not any(m.type == "ARMATURE" and m.object == rig for m in obj.modifiers):
            raise ValueError("Missing retained-rig modifier on " + obj.name)
    missing = set(FACE_BONES) - face_weights
    if missing:
        raise ValueError("Lost facial control bindings: " + str(sorted(missing)))


def runtime_metrics(meshes):
    result = []
    graph = bpy.context.evaluated_depsgraph_get()
    for obj in meshes:
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        try:
            mesh.calc_loop_triangles()
            result.append({"name": obj.name, "vertices": len(mesh.vertices),
                           "triangles": len(mesh.loop_triangles),
                           "materials": [slot.material.name for slot in obj.material_slots]})
        finally:
            evaluated.to_mesh_clear()
    return result


def glb_metrics(path):
    with path.open("rb") as stream:
        magic, version, length = struct.unpack("<4sII", stream.read(12))
        size, kind = struct.unpack("<I4s", stream.read(8))
        if magic != b"glTF" or version != 2 or kind != b"JSON" or length != path.stat().st_size:
            raise ValueError("Invalid GLB header")
        doc = json.loads(stream.read(size))
    joints = {doc["nodes"][index]["name"] for skin in doc.get("skins", []) for index in skin["joints"]}
    if not set(FACE_BONES) <= joints or doc.get("animations") or doc.get("cameras"):
        raise ValueError("GLB violated face/runtime-only/no-native-clips contract")
    if any("uri" in image for image in doc.get("images", [])):
        raise ValueError("GLB contains non-private external images")
    triangles = 0
    for mesh in doc.get("meshes", []):
        for primitive in mesh["primitives"]:
            if primitive.get("mode", 4) != 4:
                raise ValueError("Unexpected non-triangle runtime primitive")
            accessor = primitive.get("indices", primitive["attributes"]["POSITION"])
            triangles += doc["accessors"][accessor]["count"] // 3
    return {"triangles": triangles, "meshes": len(doc.get("meshes", [])),
            "joints": len(joints), "native_clips": 0, "embedded_images": len(doc.get("images", []))}


def relaxed_pose(rig):
    rig.data.pose_position = "POSE"
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    for side, sign in (("l", 1), ("r", -1)):
        bone = rig.pose.bones["upperarm_" + side]
        bone.rotation_mode = "QUATERNION"
        direction = rig.data.bones[bone.name].matrix_local.to_3x3().inverted() @ Vector((sign * .40, 0, -.9165))
        bone.rotation_quaternion = Vector((0, 1, 0)).rotation_difference(direction.normalized())
    bpy.context.view_layer.update()


def render_previews(job, rig, meshes):
    relaxed_pose(rig)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x, scene.render.resolution_y = 640, 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    shading = scene.display.shading
    shading.light = "STUDIO"
    studio_names = {light.name for light in bpy.context.preferences.studio_lights if light.type == "STUDIO"}
    if "paint.sl" in studio_names:
        shading.studio_light = "paint.sl"
    shading.color_type = "TEXTURE"
    shading.background_type = "WORLD"
    scene.world = bpy.data.worlds.new(job["asset"] + "_NeutralReviewWorld")
    scene.world.color = (.18, .18, .18)
    shading.show_shadows = True
    shading.show_cavity = True
    camera = bpy.data.objects.new(job["asset"] + "_ReviewCamera", bpy.data.cameras.new("NeutralOrtho"))
    bpy.context.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = "ORTHO"
    graph = bpy.context.evaluated_depsgraph_get()
    bounds = [obj.matrix_world @ Vector(corner) for source in meshes
              for obj in [source.evaluated_get(graph)] for corner in obj.bound_box]
    low = Vector(tuple(min(p[i] for p in bounds) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in bounds) for i in range(3)))
    center = (low + high) * .5
    camera.data.ortho_scale = max((high.z - low.z) * 1.20, max(high.x - low.x, high.y - low.y) * 1.5)
    scene.render.use_stamp = True
    scene.render.use_stamp_note = True
    scene.render.use_stamp_date = False
    scene.render.use_stamp_time = False
    scene.render.use_stamp_frame = False
    scene.render.use_stamp_filename = False
    scene.render.use_stamp_camera = False
    scene.render.use_stamp_scene = False
    scene.render.stamp_font_size = 12
    result = []
    for view, direction in (("front", (0, -1, 0)), ("side", (1, 0, 0)),
                            ("back", (0, 1, 0)), ("quarter", (1, -2, .08))):
        camera.location = center + Vector(direction).normalized() * 4
        camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.stamp_note_text = job["asset"] + " | " + view.upper() + " | WORKBENCH TEXTURE | NOT PBR / NOT APPROVED"
        path = job["evidence"] / (view + "_workbench_texture.png")
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        result.append({"view": view, "path": str(path.relative_to(REPO)), "sha256": sha256(path),
                       "engine": "BLENDER_WORKBENCH", "color_type": "TEXTURE", "pbr_validation": False})
    return result


def author(job, inputs, render=False):
    for target in (job["blend"], job["review"], job["evidence"]):
        if target.exists():
            raise FileExistsError(f"Preserving existing candidate: {target}; use a new --revision")
    bpy.ops.wm.open_mainfile(filepath=str(job["source"]), load_ui=False)
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"
            and set(FACE_BONES) <= set(obj.data.bones.keys())]
    if len(rigs) != 1:
        raise ValueError("Expected exactly one retained human rig with 11 facial controls")
    rig = rigs[0]
    rig.hide_set(False)
    rig.hide_render = False
    contract = rig_contract(rig)
    source = max((o for o in bpy.context.scene.objects if o.type == "MESH" and o.find_armature() == rig),
                 key=lambda o: len(o.data.vertices))
    atlas = next((mat for mat in source.data.materials if "ClothesAtlas" in mat.name), None)
    if atlas is None:
        raise ValueError("Missing legacy working costume atlas; inspect source before authoring")
    for action in bpy.data.actions:
        action.use_fake_user = True
    if rig.animation_data:
        rig.animation_data.action = None
        rig.animation_data.use_nla = False
    rig.data.pose_position = "REST"
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    for obj in list(bpy.context.scene.objects):
        if obj != rig:
            obj.hide_render = True
            obj.hide_set(True)
            obj["stylized_runtime"] = False
    head = retained_head(source, rig, job["asset"])
    face_edit = sculpt(head, job["asset"] + "_IndividualFacePlanes", lambda p: identity_offset(
        p, rig.data.bones["Head"].head_local.z, job["recipe"]["face"]))
    if face_edit["changed_vertices"] < 20 or face_edit["max_delta_m"] < .001:
        raise ValueError("Face edit did not reach retained facial topology; inspect source")
    meshes, hair, edits = [head], [], [face_edit]
    for path, names in job["libraries"]:
        imported = import_library(path, names, rig)
        for obj in imported:
            if "Hair_" in obj.name:
                hair.append(obj)
            else:
                edits.append(tailor_body(obj, rig, job["recipe"]))
        meshes.extend(imported)
    torso = next(obj for obj in meshes if obj.name.endswith("_Body"))
    meshes.extend(costume(job, rig, torso, atlas, meshes))
    meshes.extend(groom(job, rig, head, hair, atlas))
    meshes.extend(salvage_keepsakes(source, rig, job["asset"]))
    validate_runtime(meshes, rig)
    if rig_contract(rig) != contract:
        raise ValueError("Retained bone hierarchy/rest matrices changed")
    if sha256(job["source"]) != inputs[0]["sha256"]:
        raise ValueError("Original source changed during authoring; refusing output")
    job["blend"].parent.mkdir(parents=True, exist_ok=True)
    job["review"].mkdir(parents=True)
    job["evidence"].mkdir(parents=True)
    textures = private_materials(meshes, job["review"] / "textures", job["design"])
    rig["asset_design_id"] = job["asset"]
    rig["character_silhouette_baked"] = True
    rig["character_prebaked_identity"] = True
    rig["art_status"] = "GROUNDED_STYLIZED_CANDIDATE_AWAITING_USER"
    rig["production_policy"] = "Best effort candidate; final user acceptance required; no runtime cutover"
    # Compile only a disposable copy. Authored static sculpt keys remain
    # editable in the source; runtime expression is owned by Face_* bones.
    copies = []
    for original in meshes:
        copy = original.copy()
        copy.data = original.data.copy()
        bpy.context.collection.objects.link(copy)
        bpy.context.view_layer.objects.active = copy
        copy.select_set(True)
        if copy.data.shape_keys:
            bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
        for modifier in list(copy.modifiers):
            if modifier.type!='ARMATURE':
                bpy.ops.object.modifier_move_to_index(modifier=modifier.name,index=0)
                bpy.ops.object.modifier_apply(modifier=modifier.name)
        copies.append(copy)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in copies: obj.select_set(True)
    bpy.context.view_layer.objects.active = copies[0]
    bpy.ops.object.join()
    compiled = bpy.context.object
    compiled.name = job['asset']+'_RuntimeAssembly'
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    path = job["review"] / (job["asset"] + "_stylized.glb")
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                              export_animations=False, export_skins=True, export_yup=True,
                              export_extras=True, export_apply=False)
    metrics = glb_metrics(path)
    bpy.data.objects.remove(compiled, do_unlink=True)
    if metrics["joints"] != len(contract):
        raise ValueError("GLB did not preserve the complete retained skeleton")
    evaluated = runtime_metrics(meshes)
    previews = render_previews(job, rig, meshes) if render else []
    if not render:
        relaxed_pose(rig)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(job["blend"]), compress=True)
    report = dict(schema="stylized_human_candidate_v1", id=job["asset"], revision=job["revision"],
                  status="candidate_awaiting_user_acceptance", user_accepted=False,
                  visual_quality_verified=False, gameplay_tested=False, source_preserved=True,
                  inputs=inputs, recipe=job["recipe"], dossier=job["dossier"], geometry_edits=edits,
                  rig={"bone_count": len(contract), "face_controls": list(FACE_BONES),
                       "rest_contract_sha256": hashlib.sha256(json.dumps(contract, sort_keys=True).encode()).hexdigest(),
                       "rest_preserved": True, "weights": "retained, normalized, at most four influences"},
                  animation={"provider": "current character_animation_fusion.gd / shared humanoid library",
                             "native_clips_in_glb": False, "private_path_not_runtime_integrated": True,
                             "fusion_playback_tested": False},
                  runtime_meshes=evaluated, glb_metrics=metrics, textures=textures, previews=previews,
                  triangle_budget={"target": [12000, 20000], "actual": metrics["triangles"],
                                   "over_target": metrics["triangles"] > 20000,
                                   "note": "No destructive auto-decimation of licensed facial/garment topology; inspect any exception."},
                  limitations=["Workbench texture previews are not PBR lighting validation.",
                               "Small legacy belt salvage has not been semantically validated against the dossier.",
                               "Hair fit, cloth clearance, facial expression range and Fusion playback need author inspection.",
                               "Existing working PBR maps are reused, not claimed as newly painted or baked."],
                  license="Retained project-licensed Quaternius Universal/Modular Fantasy CC0 topology and maps; authored alterations",
                  outputs=[{"path": str(p.relative_to(REPO)), "bytes": p.stat().st_size, "sha256": sha256(p)}
                           for p in (job["blend"], path)])
    if sha256(job["source"]) != inputs[0]["sha256"]:
        raise ValueError("Source preservation check failed")
    report_path = job["evidence"] / "source_candidate.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("HUMAN_CANDIDATE=" + str(report_path), flush=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--asset", required=True, choices=tuple(RECIPES), help="One human only; never C01")
    parser.add_argument("--revision", default="v001", help="New candidate version, e.g. v002; no overwrites")
    parser.add_argument("--plan", action="store_true", help="Read-only inputs/output plan; works without Blender")
    parser.add_argument("--render", action="store_true", help="Opt-in neutral Workbench front/side/back/quarter previews")
    if argv is None:
        argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    args = parser.parse_args(argv)
    if not re.fullmatch(r"v[0-9]{3,6}", args.revision):
        parser.error("--revision must be v followed by 3 to 6 digits")
    job = plan(args.asset, args.revision)
    inputs = preflight(job)
    if args.plan:
        print(json.dumps({**job, "inputs": inputs, "render_requested": args.render,
                          "writes": False, "user_accepted": False}, indent=2, default=str))
        return 0
    global bpy, bmesh, Vector, Matrix, BVHTree
    try:
        import bpy
        import bmesh
        from mathutils import Matrix, Vector
        from mathutils.bvhtree import BVHTree
    except ImportError:
        parser.error("Authoring requires Blender's Python; use --plan for read-only inspection")
    author(job, inputs, args.render)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
