"""Review-only biped authoring. Run inside Blender, one --asset at a time.

Preserves licensed connected anatomy, native joint rests and weights. Fifteen
contract actions are embedded: sampled UAL2 or the retained armor/wood rig's
own procedural actions, never dependent on runtime path fusion.
No gameplay, manifests, acceptance ledgers or upstream assets are modified.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path


RECOVERY = Path(__file__).resolve().parents[1]
REPO = RECOVERY.parents[1]
GAME = REPO / "outputs/AshenOathTheRoadBetweenCrowns"
EXTERNAL = GAME / "assets_external"
V1 = REPO / "art_source/design_pack_v1"
LIBRARY = EXTERNAL / "animations/UAL2_Standard.glb"
DONORS = {
    "M01": EXTERNAL / "characters_universal/Superhero_Male_FullBody.gltf",
    "M05": EXTERNAL / "characters_universal/Superhero_Male_FullBody.gltf",
    "M02": EXTERNAL / "characters_universal/Superhero_Male_FullBody.gltf",
    "M19": EXTERNAL / "characters_universal/Superhero_Male_FullBody.gltf",
    "M20": EXTERNAL / "characters_universal/Superhero_Male_FullBody.gltf",
    "M03": EXTERNAL / "characters_universal/Superhero_Male_FullBody.gltf",
    "M04": V1 / "models/M04_Gravebound_Knight.blend",
    "M06": V1 / "models/M06_Rootbound_Colossus.blend",
}
NAMES = {"M01": "Ghoulkin", "M05": "Bell_Eater", "M02": "Wychwood_Stalker",
         "M19": "Wychwood_Raider", "M20": "Wychwood_Brute", "M03": "Bog_Wretch",
         "M04": "Gravebound_Knight", "M06": "Rootbound_Colossus"}
HEIGHTS = {"M01": 1.63, "M05": 3.8, "M02": 1.60, "M19": 1.86,
           "M20": 1.98, "M03": 1.72, "M04": 1.88, "M06": 4.4}
STATES = ("Idle", "Walking", "Running", "Attack", "AttackHeavy", "Windup",
          "Recovery", "Block", "HitReact", "Death", "Investigate", "Threaten",
          "Feed", "Sleep", "Interact")

RETAINED_BODIES = {"M04", "M06"}
RELATED_PROFILES = {
    "M02": {"skin": (.22, .255, .19), "label": "SlateGreenHide",
            "features": ["blade-thin chest", "long low-reaching forearms", "small wedge muzzle",
                         "muscular shoulder ridges, no horns", "recessed eyes and shin scar"],
            "limits": ["Five retained digits; three-finger/opposing-digit topology is not resolved",
                       "No authored circling, trap inspection or rear-lunge performance"]},
    "M19": {"skin": (.31, .30, .22), "label": "OliveGreyHide",
            "features": ["narrow waist and forward shoulders", "higher injured left shoulder",
                         "blunt keratin-edged muzzle, not an oversized Ghoulkin jaw",
                         "long hooking fingers", "controlled wrist token cord; unarmed"],
            "limits": ["No token-grab or body-feint gameplay events; cord is a review prop",
                       "Sparse fur and folded-ear refinement remain incomplete"]},
    "M20": {"skin": (.24, .25, .19), "label": "CharcoalOliveHide",
            "features": ["very broad continuous shoulder mound", "low heavy head and thick neck",
                         "block-like forearms", "short-looking heavy haunches and broad feet",
                         "two short lateral tusks; no weapon or armor"],
            "limits": ["Five retained digits; three-finger/opposing-thumb topology is not resolved",
                       "Native limb pivots retained; short-leg appearance is a bind-space treatment",
                       "No authored route-slam or obstruction-break event"]},
    "M03": {"skin": (.31, .30, .20), "label": "WaterloggedOliveHide",
            "features": ["broad pelvis and lowered belly", "collapsed neck and recessed face",
                         "long dragging arms and webbed fingers", "amber chest patch below throat",
                         "torso-bound root ligatures, no antlers"],
            "limits": ["Amber core is a surface patch, not an opening or exposure mechanism",
                       "Root-hide/ash-recoil phases and belly deformation need authored review"]},
}


def import_retained_body(asset):
    """Keep the actual armored/wooden source, including its own compatible rig."""
    with bpy.data.libraries.load(str(DONORS[asset]), link=False) as (available, loaded):
        requested = (asset+"_Rig", asset+"_"+NAMES[asset]+"_Skinned")
        if not all(name in available.objects for name in requested):
            raise ValueError("Retained source objects missing: "+str(requested))
        loaded.objects = list(requested)
    for obj in loaded.objects:
        bpy.context.collection.objects.link(obj)
    rig = next(o for o in loaded.objects if o.type == "ARMATURE")
    mesh = next(o for o in loaded.objects if o.type == "MESH")
    rig.animation_data.action = None
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    if mesh.data.uv_layers.active is None:
        raise ValueError("Retained armor/wood UVs missing")
    if not any(m.type == "ARMATURE" and m.object == rig for m in mesh.modifiers):
        raise ValueError("Retained mesh lost its native armature binding")
    groups = components(mesh.data)
    counts = {}
    if asset == "M06":
        counts = {"bark_plates": sum(len(g) == 5 for g in groups),
                  "buttress_roots": sum(len(g) == 33 for g in groups),
                  "heartwood_strip": sum(len(g) == 39 for g in groups)}
        if counts["bark_plates"] < 40 or counts["buttress_roots"] < 16 or not counts["heartwood_strip"]:
            raise ValueError("Rootbound must retain bark, buttress roots and heartwood: "+str(counts))
    else:
        # These are explicit unremeshed components of knight_armor(), not a
        # recolored nude body or the large joined/remeshed anatomy component.
        counts = {"lamed_pauldrons": sum(len(g) == 231 for g in groups),
                  "shield_faces": sum(len(g) == 5 for g in groups),
                  "sword_blade": sum(len(g) == 4 for g in groups)}
        head_group = mesh.vertex_groups.get("Head")
        counts["closed_helm"] = sum(
            len(g) == 493 and all(any(w.group == head_group.index and w.weight > .99
                                      for w in mesh.data.vertices[i].groups) for i in g)
            for g in groups) if head_group else 0
        if counts["lamed_pauldrons"] < 6 or counts["shield_faces"] < 2 or not counts["sword_blade"] or not counts["closed_helm"]:
            raise ValueError("Gravebound must retain closed helm, plate, sword and shield: "+str(counts))
    metrics = {"path": str(DONORS[asset]), "joints": len(rig.data.bones),
               "vertices": len(mesh.data.vertices),
               "triangles": sum(len(p.vertices)-2 for p in mesh.data.polygons),
               "retained_components": counts, "native_rig_and_weights": True,
               "removed_nonanatomical_vertices": 0,
               "foundation": "retained armored sentinel" if asset == "M04" else "retained root/wood anatomy, not Universal human"}
    return rig, [mesh], metrics


def retained_materials(asset, meshes):
    """Preserve the source UV atlas and its iron/linen or bark/core regions."""
    replacements = {}
    for obj in meshes:
        for slot in obj.material_slots:
            original = slot.material
            if original in replacements:
                slot.material = replacements[original]
                continue
            images = {node.image.name.rsplit("_", 1)[-1].split(".")[0]: node.image
                      for node in original.node_tree.nodes
                      if node.type == "TEX_IMAGE" and node.image} if original and original.use_nodes else {}
            if "basecolor" not in images:
                raise ValueError("Missing retained textured surface: "+str(original))
            color = (.19, .21, .20) if asset == "M04" else (.29, .235, .15)
            material = shared.material(asset+"_Retained_IronLinen" if asset == "M04" else asset+"_Retained_BarkHeartwood", color, .84)
            nodes, links = material.node_tree.nodes, material.node_tree.links
            bsdf = nodes["Principled BSDF"]
            for kind, image in images.items():
                tex = nodes.new("ShaderNodeTexImage")
                tex.image = image
                if kind == "basecolor":
                    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
                elif kind == "orm":
                    channels = nodes.new("ShaderNodeSeparateColor")
                    links.new(tex.outputs["Color"], channels.inputs["Color"])
                    links.new(channels.outputs["Green"], bsdf.inputs["Roughness"])
                    links.new(channels.outputs["Blue"], bsdf.inputs["Metallic"])
                elif kind == "normal":
                    normal = nodes.new("ShaderNodeNormalMap")
                    links.new(tex.outputs["Color"], normal.inputs["Color"])
                    links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
            replacements[original] = material
            slot.material = material


def sculpt_retained(asset, meshes):
    for obj in meshes:
        world, inverse = obj.matrix_world.copy(), obj.matrix_world.inverted()
        for vertex in obj.data.vertices:
            p = world @ vertex.co
            w = weights(obj, vertex)
            if asset == "M06":
                # Existing knot head/hollows, plates, core and root feet move
                # together. No new human head or smooth replacement core.
                head = w.get("Head", 0)
                p.z -= .30*head
                p.x *= 1+.10*w.get("Body", 0)+.08*w.get("Pelvis", 0)
                if p.z < .28:
                    p.x *= 1.10
                    p.y *= 1.10
            else:
                # Preserve the enclosed visor and practical equipment. Raise
                # one plated shoulder for a deliberately asymmetric guard.
                p.z += .025*w.get("Arm1_0", 0)
                p.x += .015*w.get("Arm1_0", 0)
            vertex.co = inverse @ p
        obj.data.update()


def sculpt_related(asset, rig, meshes):
    head = rig.matrix_world @ rig.data.bones["Head"].head_local
    pelvis = rig.matrix_world @ rig.data.bones["pelvis"].head_local
    for obj in meshes:
        world, inverse = obj.matrix_world.copy(), obj.matrix_world.inverted()
        for vertex in obj.data.vertices:
            p = world @ vertex.co
            w = weights(obj, vertex)
            hw, neck = w.get("Head", 0), w.get("neck_01", 0)
            chest = w.get("spine_02", 0)+w.get("spine_03", 0)
            waist, hips = w.get("spine_01", 0), w.get("pelvis", 0)
            thighs = w.get("thigh_l", 0)+w.get("thigh_r", 0)
            arms = sum(value for name, value in w.items() if "arm_" in name or "hand_" in name
                       or name.startswith(("index_", "middle_", "pinky_", "ring_", "thumb_")))
            fingertips = sum(value for name, value in w.items()
                             if name.startswith(("index_02", "index_03", "middle_02", "middle_03",
                                                 "pinky_02", "pinky_03", "ring_02", "ring_03")))
            front = max(0., min(1., (head.y-p.y+.025)/.09))
            muzzle = math.exp(-((p.z-head.z+.035)/.045)**2)*hw*front
            if asset == "M02":
                p.x *= 1-.29*chest-.22*waist-.10*hips
                p.y = pelvis.y+(p.y-pelvis.y)*(1-.27*chest-.16*waist)
                p.x += math.copysign(.085*arms, p.x)
                p.z -= .045*arms
                p.y -= .012*fingertips
                p.z -= .014*fingertips
                p.x = p.x*(1-hw)+(head.x+(p.x-head.x)*.80)*hw
                p.z = p.z*(1-hw)+(head.z+(p.z-head.z)*.77-.018)*hw
                p.y -= .027*hw+.022*muzzle
                p.z += .015*(w.get("clavicle_l", 0)+w.get("clavicle_r", 0))
                brow = math.exp(-((p.z-head.z-.018)/.016)**2)*hw*front
                p.y -= .011*brow
                shin = math.exp(-((p.z-.36)/.035)**2-((p.x-.11)/.035)**2)
                p.y += .003*shin*w.get("calf_l", 0)
            elif asset == "M19":
                p.x *= 1-.23*waist+.10*chest
                p.x += math.copysign(.060*arms, p.x)
                p.y -= .020*fingertips
                p.z -= .020*fingertips
                injured = w.get("clavicle_l", 0)+w.get("upperarm_l", 0)
                p.z += .045*injured
                p.y -= .020*chest+.018*hw+.027*muzzle
                p.x += math.copysign(.009*muzzle, p.x)
                ear = math.exp(-((abs(p.x-head.x)-.085)/.025)**2-((p.z-head.z-.025)/.05)**2)*hw
                p.y += .018*ear
            elif asset == "M20":
                p.x *= 1+.52*chest+.26*waist+.20*hips+.25*thighs
                p.y = pelvis.y+(p.y-pelvis.y)*(1+.22*chest+.25*neck)
                p.x += math.copysign(.045*arms+.025*neck, p.x)
                p.z -= .025*chest+.055*hw
                p.x = p.x*(1-hw)+(head.x+(p.x-head.x)*1.24)*hw
                p.y -= .022*hw+.016*muzzle
                for side in ("l", "r"):
                    forearm = w.get("lowerarm_"+side, 0)
                    pivot = rig.matrix_world @ rig.data.bones["lowerarm_"+side].head_local
                    p.y += .35*forearm*(p.y-pivot.y)
                    p.z += .30*forearm*(p.z-pivot.z)
                p.z += .035*(w.get("clavicle_l", 0)+w.get("clavicle_r", 0))
                foot = w.get("foot_l", 0)+w.get("foot_r", 0)
                p.x *= 1+.12*foot
            else:
                belly = math.exp(-((p.z-pelvis.z-.12)/.22)**2)*(waist+hips)
                p.x *= 1+.40*hips+.30*waist+.12*thighs
                p.y -= .095*belly
                p.x += math.copysign(.055*arms, p.x)
                p.z -= .050*arms+.035*neck+.035*hw
                p.x = p.x*(1-hw)+(head.x+(p.x-head.x)*.90)*hw
                p.y += .012*hw-.020*neck
                p.y -= .016*math.exp(-((p.z-head.z-.025)/.022)**2)*hw*front
            vertex.co = inverse @ p
        obj.data.update()


def bind_world_detail(obj, rig, binding):
    # shared.tube creates an initial binding; replace it, never stack a second
    # deform modifier when converting these new details into armature space.
    for modifier in list(obj.modifiers):
        if modifier.type == "ARMATURE":
            obj.modifiers.remove(modifier)
    obj.vertex_groups.clear()
    inverse = rig.matrix_world.inverted()
    for vertex in obj.data.vertices:
        vertex.co = inverse @ vertex.co
    shared.bind(obj, rig, lambda p: binding(rig.matrix_world @ p))
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.matrix_basis = Matrix.Identity(4)
    return obj


def related_details(asset, rig, meshes, out):
    result = []
    if asset == "M20":
        points = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices
                  if weights(o, v).get("Head", 0) > .7]
        if not points:
            raise ValueError("Brute head anatomy missing")
        lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
        hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
        center = (lo+hi)*.5
        from mathutils.bvhtree import BVHTree
        vertices, faces = [], []
        for body in meshes:
            offset = len(vertices)
            vertices.extend(body.matrix_world @ v.co for v in body.data.vertices)
            faces.extend([offset+i for i in f.vertices] for f in body.data.polygons)
        surface = BVHTree.FromPolygons(vertices, faces)
        keratin = texture_material(asset, "WornTusk", (.49, .45, .32), out, roughness=.78)
        for side in (-1, 1):
            start = Vector((center.x+side*(hi.x-lo.x)*.34, lo.y+.015, center.z-.028))
            hit, normal, _, _ = surface.find_nearest(start)
            if hit is None:
                raise ValueError('Brute tusk has no real cheek attachment surface')
            start = hit - normal * .004
            obj = shared.tube(asset+"_ShortLateralTusk_"+str(side),
                              [start, start+Vector((side*.021, -.024, .012)),
                               start+Vector((side*.032, -.026, .045))],
                              [.015, .011, .0015], keratin, rig, lambda p: {"Head": 1.}, sides=10)
            result.append(bind_world_detail(obj, rig, lambda p: {"Head": 1.}))
    elif asset == "M19":
        hand = rig.matrix_world @ rig.data.bones["hand_l"].head_local
        hand.x += math.copysign(.060, hand.x)
        cord = texture_material(asset, "CaughtTokenCord", (.12, .095, .065), out)
        points = [hand+Vector((.005*math.sin(i*math.tau/20), .034*math.cos(i*math.tau/20),
                               .034*math.sin(i*math.tau/20))) for i in range(21)]
        obj = shared.tube(asset+"_WristTokenCord", points, [.0035]*21,
                          cord, rig, lambda p: {"hand_l": 1.}, sides=6)
        result.append(bind_world_detail(obj, rig, lambda p: {"hand_l": 1.}))
    elif asset == "M03":
        # Amber is assigned to existing connected chest faces, never a sphere
        # attached to the face. Ligatures remain controlled torso attachments.
        lo, hi = bounds(meshes)
        z = lo.z+(hi.z-lo.z)*.65
        candidates = [(o, p, o.matrix_world @ p.center) for o in meshes for p in o.data.polygons
                      if abs((o.matrix_world @ p.center).z-z) < .085
                      and abs((o.matrix_world @ p.center).x) < .065]
        if not candidates:
            raise ValueError("Bog Wretch chest patch could not be located")
        front = min(p.y for _, _, p in candidates)
        amber = texture_material(asset, "OpaqueAmberCore", (.43, .26, .07), out, roughness=.72)
        patch_count = 0
        for obj in meshes:
            obj.data.materials.append(amber)
            index = len(obj.data.materials)-1
            for polygon in obj.data.polygons:
                p = obj.matrix_world @ polygon.center
                if (p.x/.055)**2+((p.z-z)/.075)**2 < 1 and p.y < front+.035:
                    polygon.material_index = index
                    patch_count += 1
        if not patch_count:
            raise ValueError("Bog Wretch amber core selected no surface faces")
        root = texture_material(asset, "PeatRootLigature", (.15, .145, .095), out)
        for side in (-1, 1):
            points = [(side*.085, front+.025, z+.13), (side*.105, front-.012, z+.035),
                      (side*.070, front-.015, z-.095), (side*.11, front+.015, z-.16)]
            obj = shared.tube(asset+"_TorsoRoot_"+str(side), points, [.010, .012, .008, .003],
                              root, rig, lambda p: {"spine_01": .5, "spine_02": .5}, sides=8)
            result.append(bind_world_detail(obj, rig, lambda p: {"spine_01": .5, "spine_02": .5}))
        # Small web panels inherit the real hand/finger bind positions.
        for side in ("l", "r"):
            palm = rig.matrix_world @ rig.data.bones["hand_"+side].head_local
            offset = Vector((math.copysign(.055, palm.x), 0, -.050))
            fingers = [rig.matrix_world @ rig.data.bones[name+"_01_"+side].head_local+offset
                       for name in ("index", "middle", "ring", "pinky")]
            palm += offset
            for i in range(3):
                a, b = fingers[i], fingers[i+1]
                obj = shared.mesh_object(asset+"_FingerWeb_"+side+str(i),
                                         [tuple(palm), tuple(a), tuple(b)], [(0, 1, 2)],
                                         meshes[0].data.materials[0], [(0., 0.), (0., 1.), (1., 1.)])
                result.append(bind_world_detail(obj, rig, lambda p, side=side: {"hand_"+side: 1.}))
    return result


def retain_native_clips(asset, rig):
    """Retained v1 rigs are not compatible with the 65-joint UAL2 sampler."""
    report = {}
    if not rig.animation_data:
        raise ValueError("Retained source lacks native actions")
    for track in rig.animation_data.nla_tracks:
        for strip in track.strips:
            action = strip.action
            name = track.name if track.name in STATES else action.name
            if name not in STATES:
                continue
            action.name = name
            action.use_fake_user = True
            start, end = action.frame_range
            report[name] = {"source": str(DONORS[asset]), "action": name,
                            "frames": round(end-start)+1, "reversed": False,
                            "quality": "retained v1 procedural action; not bespoke or runtime accepted"}
        track.mute = True
    if set(report) != set(STATES):
        raise ValueError("Retained native contract actions missing: "+str(set(STATES)-set(report)))
    rig.animation_data.action = None
    for other in list(bpy.data.objects):
        if other.type == "ARMATURE" and other != rig:
            bpy.data.objects.remove(other, do_unlink=True)
    for action in list(bpy.data.actions):
        if action.name not in STATES:
            bpy.data.actions.remove(action)
    return report


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_files(path):
    result = [path]
    if path.suffix == ".gltf":
        doc = json.loads(path.read_text(encoding="utf-8"))
        for item in doc.get("buffers", []) + doc.get("images", []):
            uri = item.get("uri", "")
            if uri and not uri.startswith("data:"):
                from urllib.parse import unquote
                if "://" in uri:
                    raise ValueError("Network dependencies are not permitted")
                result.append(path.parent / unquote(uri))
    return result


def components(mesh):
    """Indexed connectivity; the caller welds only coincident export seams."""
    parent = list(range(len(mesh.vertices)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for edge in mesh.edges:
        a, b = (find(i) for i in edge.vertices)
        parent[b] = a
    groups = {}
    for i in range(len(parent)):
        groups.setdefault(find(i), []).append(i)
    return sorted(groups.values(), key=len, reverse=True)


def bounds(objects, evaluated=False):
    points = []
    depsgraph = bpy.context.evaluated_depsgraph_get() if evaluated else None
    for obj in objects:
        if obj.type != "MESH":
            continue
        if evaluated:
            sample = obj.evaluated_get(depsgraph)
            mesh = sample.to_mesh()
            points.extend(sample.matrix_world @ v.co for v in mesh.vertices)
            sample.to_mesh_clear()
        else:
            points.extend(obj.matrix_world @ v.co for v in obj.data.vertices)
    if not points:
        raise ValueError("No visible mesh geometry")
    lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    return lo, hi


def import_donor(asset):
    if asset in RETAINED_BODIES:
        return import_retained_body(asset)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(DONORS[asset]))
    imported = set(bpy.data.objects) - before
    rigs = [o for o in imported if o.type == "ARMATURE"]
    if len(rigs) != 1:
        raise ValueError("Expected exactly one anatomical donor armature")
    rig = rigs[0]
    rig.animation_data_clear()
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    meshes = [o for o in imported if o.type == "MESH"]
    primary = max(meshes, key=lambda o: len(o.data.vertices))
    source_metrics = {"path": str(DONORS[asset]), "joints": len(rig.data.bones),
                      "vertices": sum(len(o.data.vertices) for o in meshes),
                      "triangles": sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)}
    if len(rig.data.bones) != 65:
        raise ValueError("This recipe requires the retained 65-joint Universal rig")
    head_world = rig.matrix_world @ rig.data.bones["Head"].head_local
    kept, removed = [], 0
    for obj in meshes:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
        groups = components(obj.data)
        keep = set(groups[0]) if obj == primary else set()
        head_group = obj.vertex_groups.get("Head")
        for group in groups:
            if obj == primary and group is groups[0]:
                continue
            center = sum((obj.matrix_world @ obj.data.vertices[i].co for i in group), Vector()) / len(group)
            head_weight = sum(sum(g.weight for g in obj.data.vertices[i].groups
                                 if head_group and g.group == head_group.index) for i in group) / len(group)
            if head_weight > .8 and (center-head_world).length < .35:
                keep.update(group)
        removed += len(obj.data.vertices) - len(keep)
        if not keep:
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context="VERTS")
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
        if obj.data.uv_layers.active is None:
            raise ValueError("Donor UVs missing; refusing a white fallback")
        kept.append(obj)
    source_metrics["removed_nonanatomical_vertices"] = removed
    source_metrics["retained_primary_components"] = [len(c) for c in components(primary.data)]
    return rig, kept, source_metrics


def weights(obj, vertex):
    return {obj.vertex_groups[g.group].name: g.weight for g in vertex.groups if g.weight > 0}


def sculpt(asset, rig, meshes):
    """Bind-space edits of real connected anatomy, never replacement volumes."""
    if asset in RETAINED_BODIES:
        return sculpt_retained(asset, meshes)
    if asset in RELATED_PROFILES:
        return sculpt_related(asset, rig, meshes)
    head = rig.matrix_world @ rig.data.bones["Head"].head_local
    pelvis = rig.matrix_world @ rig.data.bones["pelvis"].head_local
    lo, hi = bounds(meshes)
    height = hi.z-lo.z
    for obj in meshes:
        world, inverse = obj.matrix_world.copy(), obj.matrix_world.inverted()
        for vertex in obj.data.vertices:
            p = world @ vertex.co
            w = weights(obj, vertex)
            hw = w.get("Head", 0)
            neck = w.get("neck_01", 0)
            torso = sum(v for k, v in w.items() if k.startswith("spine_"))
            hips = w.get("pelvis", 0)
            thighs = sum(v for k, v in w.items() if k.startswith("thigh_"))
            arms = sum(v for k, v in w.items() if "arm_" in k or "hand_" in k
                       or any(k.startswith(f) for f in ("index_", "middle_", "ring_", "pinky_", "thumb_")))
            front = max(0., min(1., (head.y-p.y+.025)/.09))
            lower_face = math.exp(-((p.z-head.z+.035)/.065)**2) * hw * front
            if asset == "M01":
                # Compact rib cage, pronounced haunches and reaching forelimbs.
                p.x *= 1 - .20*torso + .15*hips + .25*thighs
                p.y += .028*thighs
                p.x += math.copysign(.065*arms, p.x)
                p.z -= .035*arms
                p.y -= .038*hw + .015*neck
                p.z = p.z*(1-hw) + (head.z+(p.z-head.z)*.72-.025)*hw
                p.x += math.copysign(.019*lower_face, p.x)
                p.y -= .027*lower_face
                # Flatten the nose and establish a continuous heavy brow.
                nose = math.exp(-(p.x/.035)**2-((p.z-head.z+.005)/.035)**2)*hw*front
                p.y += .012*nose
                brow = math.exp(-((p.z-head.z-.025)/.018)**2)*hw*front
                p.y -= .012*brow
            else:
                # A giant's broad supporting pelvis, hanging reach, small head
                # and continuous resonant throat, not the Ghoulkin recipe scaled.
                p.x *= 1 + .38*hips + .23*thighs + .15*torso
                p.y = pelvis.y+(p.y-pelvis.y)*(1+.19*hips+.12*thighs)
                p.x += math.copysign(.090*arms, p.x)
                p.z -= .020*arms
                p.x = p.x*(1-hw) + (head.x+(p.x-head.x)*.62)*hw
                p.z = p.z*(1-hw) + (head.z+(p.z-head.z)*.80)*hw
                p.y = p.y*(1-hw) + (head.y+(p.y-head.y)*.83-.018)*hw
                p.x += math.copysign(.035*neck, p.x)
                p.y -= .055*neck
                p.y -= .015*lower_face
            vertex.co = inverse @ p
        obj.data.update()
    return height


def texture_material(asset, label, color, out, metallic=0., roughness=.8):
    """Small actual image textures, shared between source and exported GLB."""
    mat = shared.material(asset+"_"+label, color, roughness, metallic)
    n = 256
    pixels = []
    for y in range(n):
        for x in range(n):
            grain = .90 + .045*math.sin(x*.17+math.sin(y*.12))*math.cos(y*.23)
            grain += .025*math.sin(x*2.13+y*1.77)
            patina = max(0., math.sin(x*.061)*math.cos(y*.049))*.35 if label == "Bronze" else 0.
            c = tuple(min(1., color[i]*grain*(1-patina) + (.06, .12, .085)[i]*patina) for i in range(3))
            pixels.extend((*c, 1.))
    image = bpy.data.images.new(asset+"_"+label+"_BaseColor", width=n, height=n, alpha=False)
    image.colorspace_settings.name = "sRGB"
    image.pixels.foreach_set(pixels)
    image.filepath_raw = str(out/(image.name+".png"))
    image.file_format = "PNG"
    image.save()
    image.pack()
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = image
    mat.node_tree.links.new(node.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    return mat


def skin_materials(asset, meshes, out):
    if asset in RETAINED_BODIES:
        return retained_materials(asset, meshes)
    profile = RELATED_PROFILES.get(asset)
    color = profile["skin"] if profile else (.32, .30, .255) if asset == "M01" else (.43, .40, .35)
    label = profile["label"] if profile else "PeatSkin" if asset == "M01" else "ClaySkin"
    skin = texture_material(asset, label, color, out, roughness=.83)
    eye = texture_material(asset, "PaleEyes", (.48, .49, .44), out, roughness=.52)
    dark = texture_material(asset, "Charcoal", (.045, .045, .038), out)
    for obj in meshes:
        obj.data.materials.clear()
        obj.data.materials.append(skin)
        obj.data.materials.append(eye)
        obj.data.materials.append(dark)
        for polygon in obj.data.polygons:
            polygon.material_index = 0
            polygon.use_smooth = True
        # The small disconnected anatomical eye surfaces get a pale treatment;
        # the connected skin/head surface keeps the textured skin material.
        for group in components(obj.data)[1:]:
            ids = set(group)
            if 150 <= len(group) <= 260:
                for polygon in obj.data.polygons:
                    if all(i in ids for i in polygon.vertices):
                        polygon.material_index = 1


def extract_mesh(source, ids, name, mat):
    ids = set(ids)
    ordered = sorted(ids)
    remap = {old: new for new, old in enumerate(ordered)}
    polygons = [p for p in source.data.polygons if all(i in ids for i in p.vertices)]
    obj = shared.mesh_object(name, [tuple(source.matrix_world @ source.data.vertices[i].co) for i in ordered],
                             [[remap[i] for i in p.vertices] for p in polygons], mat)
    layer = obj.data.uv_layers.new(name="UVMap")
    original = source.data.uv_layers.active
    if original is None:
        raise ValueError("V1 prop UVs missing")
    for new, old in zip(obj.data.polygons, polygons):
        for nl, ol in zip(new.loop_indices, old.loop_indices):
            layer.data[nl].uv = original.data[ol].uv
    return obj


def append_bell(rig, meshes, out):
    """Append only identifiable v1 prop islands, never the ellipsoid body."""
    path = V1 / "models/M05_Bell_Eater.blend"
    with bpy.data.libraries.load(str(path), link=False) as (available, loaded):
        names = [n for n in available.objects if n.startswith("M05_") and n.endswith("_Skinned")]
        if len(names) != 1:
            raise ValueError("V1 Bell-Eater joined source not uniquely identified")
        loaded.objects = names
    source = loaded.objects[0]
    bpy.context.collection.objects.link(source)
    # The v1 mesh was built in Z-up world coordinates with an identity bind.
    source.parent = None
    source.matrix_world = Matrix.Identity(4)
    bronze = texture_material("M05", "Bronze", (.30, .24, .105), out, .72, .65)
    iron = texture_material("M05", "Iron", (.11, .12, .105), out, .8, .68)
    leather = texture_material("M05", "Harness", (.075, .055, .035), out)
    lo, hi = bounds(meshes)
    h = hi.z-lo.z
    scale = h/3.8
    # Bell sits in front of the lower ribs, rather than crossing the face.
    bell_shift = Vector((0, lo.y-.69*scale, lo.z+.48*h))-Vector((0, -.50, 1.53))*scale
    selected, counts = [], {"bell": 0, "clapper": 0, "head": 0, "strap": 0, "link": 0}
    bone_world = lambda n: rig.matrix_world @ rig.data.bones[n].head_local
    from mathutils.bvhtree import BVHTree
    vertices, faces = [], []
    for body in meshes:
        offset = len(vertices)
        vertices.extend(body.matrix_world @ v.co for v in body.data.vertices)
        faces.extend([offset+i for i in f.vertices] for f in body.data.polygons)
    surface = BVHTree.FromPolygons(vertices, faces)
    from mathutils.kdtree import KDTree
    skin_points, skin_weights = [], []
    for body in meshes:
        for vertex in body.data.vertices:
            skin_points.append(body.matrix_world@vertex.co)
            skin_weights.append(weights(body,vertex))
    skin_tree=KDTree(len(skin_points))
    for index,point in enumerate(skin_points):
        skin_tree.insert(point,index)
    skin_tree.balance()
    def on_body(seed):
        point, normal, _, _ = surface.find_nearest(seed)
        if point is None:
            raise ValueError('Bell harness has no body surface')
        return point + normal * .008
    for ids in components(source.data):
        pts = [source.data.vertices[i].co for i in ids]
        c = sum(pts, Vector())/len(pts)
        kind = None
        # Counts come from the retained v1 builder's explicit unremeshed props.
        if len(ids) == 780 and abs(c.x) < .03 and 1.7 < c.z < 2.1:
            kind = "bell"
        elif len(ids) == 30 and abs(c.x) < .03 and abs(c.y+.5) < .06 and 1.7 < c.z < 2.1:
            kind = "clapper"
        elif len(ids) == 493 and abs(c.x) < .03 and abs(c.y+.5) < .06 and 1.5 < c.z < 1.7:
            kind = "head"
        elif len(ids) == 36 and .3 < abs(c.x) < .7 and 2.3 < c.z < 2.8:
            kind = "strap"
        elif len(ids) == 78:
            side = 1 if c.x > 0 else -1
            centers = [Vector((side*(.51+.40*j/17), -.65+.40*j/17,
                               2.1-j/17-.40*math.sin(math.pi*j/17))) for j in range(18)]
            if min((c-center).length for center in centers) < .035:
                kind = "link"
        if kind is None:
            continue
        counts[kind] += 1
        if kind=='strap':
            # Replace the old four-corner bars with a continuous fitted ribbon.
            continue
        mat = leather if kind == "strap" else iron if kind == "link" else bronze
        obj = extract_mesh(source, ids, "M05_V1_"+kind+"_"+str(counts[kind]), mat)
        side = "l" if c.x > 0 else "r"
        if kind == "strap":
            old_centers = [Vector((math.copysign(x, c.x), y, z)) for x, y, z in
                           ((.35, -.65, 2.1), (.57, -.35, 3.), (.56, .24, 3.05), (.39, .39, 1.78))]
            shoulder = bone_world("clavicle_"+side)
            targets = [old_centers[0]*scale+bell_shift,
                       on_body(shoulder+Vector((math.copysign(.09*scale, c.x), -.13*scale, 0))),
                       on_body(shoulder+Vector((math.copysign(.09*scale, c.x), .13*scale, 0))),
                       on_body(bone_world("spine_01")+Vector((math.copysign(.23*scale, c.x), .18*scale, -.1*scale)))]
            for v in obj.data.vertices:
                nearest = min(range(4), key=lambda j: (v.co-old_centers[j]).length)
                v.co = targets[nearest]+(v.co-old_centers[nearest])*scale
            def binding(p, shoulder=shoulder, side=side):
                return {"spine_02": 1.}
        elif kind == "link":
            t = max(0., min(1., (abs(c.x)-.51)/.40))
            anchor = Vector((math.copysign(.51, c.x), -.65, 2.1))*scale+bell_shift
            belt = on_body(bone_world('spine_01')+Vector((math.copysign(.28*scale, c.x), -.20*scale, -.08*scale)))
            center = anchor.lerp(belt, t)-Vector((0, .10*scale*math.sin(math.pi*t), .25*scale*math.sin(math.pi*t)))
            for v in obj.data.vertices:
                v.co = center+(v.co-c)*scale
            binding = lambda p: {"pelvis": 1.}
        else:
            for v in obj.data.vertices:
                v.co = v.co*scale+bell_shift
            binding = lambda p: {"pelvis": 1.}
        # shared.bind expects mesh coordinates in the target armature frame.
        inverse = rig.matrix_world.inverted()
        for v in obj.data.vertices:
            v.co = inverse @ v.co
        world_binding = binding
        shared.bind(obj, rig, lambda p, f=world_binding: f(rig.matrix_world @ p))
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.matrix_basis = Matrix.Identity(4)
        selected.append(obj)
    def harness_binding(point):
        _,index,distance=skin_tree.find(point)
        t=max(0.,min(1.,1-distance/(.10*scale)))
        values={name:value*t for name,value in skin_weights[index].items()}
        values['pelvis']=values.get('pelvis',0)+1-t
        values=dict(sorted(values.items(),key=lambda pair:pair[1],reverse=True)[:4])
        total=sum(values.values())
        return {name:value/total for name,value in values.items() if value>0}
    for sign in (-1,1):
        side='l' if sign>0 else 'r'
        shoulder=bone_world('clavicle_'+side)
        seeds=[Vector((sign*.35,-.65,2.1))*scale+bell_shift,
               on_body(bone_world('spine_02')+Vector((sign*.17*scale,-.22*scale,0))),
               on_body(shoulder+Vector((sign*.07*scale,0,.07*scale))),
               on_body(bone_world('spine_02')+Vector((sign*.18*scale,.22*scale,0))),
               on_body(bone_world('spine_01')+Vector((sign*.20*scale,.17*scale,-.12*scale)))]
        path=[]
        for segment,(a,b) in enumerate(zip(seeds,seeds[1:])):
            for step in range(9):
                point=a.lerp(b,step/9)
                if segment>0:
                    point=on_body(point)
                path.append(point)
        path.append(seeds[-1])
        ribbon,quads,uv=[],[],[]
        for index,point in enumerate(path):
            tangent=(path[min(index+1,len(path)-1)]-path[max(0,index-1)]).normalized()
            _,normal,_,_=surface.find_nearest(point)
            across=tangent.cross(normal)
            if across.length<.01:
                across=Vector((1,0,0))
            across.normalize()
            for edge in (-1,1):
                ribbon.append(tuple(point+across*edge*.035*scale))
                uv.append(((edge+1)/2,index/(len(path)-1)))
            if index:
                k=index*2
                quads.append((k-2,k-1,k+1,k))
        obj=shared.mesh_object('M05_FittedHarness_'+side,ribbon,quads,leather,uv)
        selected.append(bind_world_detail(obj,rig,harness_binding))
    bpy.data.objects.remove(source, do_unlink=True)
    if counts != {"bell": 1, "clapper": 1, "head": 1, "strap": 2, "link": 36}:
        raise ValueError("V1 prop extraction changed; refusing accidental body salvage: "+str(counts))
    return selected, counts


def set_action(rig, action, slot=None):
    rig.animation_data_create()
    rig.animation_data.action = action
    slots = getattr(action, "slots", ())
    if slots:
        rig.animation_data.action_slot = slot or slots[0]


def embed_clips(asset, rig):
    """Sample compatible local poses into real lower-case contract actions."""
    if asset in RETAINED_BODIES:
        return retain_native_clips(asset, rig)
    # Appending a prop can pull its old armature/actions into Blender's data.
    # This disposable scene owns its clips: none of those incompatible actions
    # may survive or take the exact contract names ahead of the new samples.
    for other in list(bpy.data.objects):
        if other.type=='ARMATURE' and other!=rig:
            bpy.data.objects.remove(other,do_unlink=True)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(LIBRARY))
    imported = set(bpy.data.objects)-before
    source = next(o for o in imported if o.type == "ARMATURE")
    tracks = {}
    for track in source.animation_data.nla_tracks:
        for strip in track.strips:
            tracks[track.name] = (strip.action, getattr(strip, "action_slot", None))
            tracks[strip.action.name] = (strip.action, getattr(strip, "action_slot", None))
        track.mute = True
    if set(source.data.bones.keys()) != set(rig.data.bones.keys()):
        raise ValueError("UAL2 donor joint names differ; no implicit retargeting")
    # Preserve target pivots; convert basis deltas when the retained sculpt's
    # rest axes differ from the library rather than copying incompatible poses.
    corrections = {}
    for bone in rig.data.bones:
        other = source.data.bones[bone.name]
        if (bone.parent.name if bone.parent else None) != (other.parent.name if other.parent else None):
            raise ValueError("UAL2 parent mismatch: "+bone.name)
        corrections[bone.name] = (bone.matrix_local.to_quaternion().inverted()
                                  @ other.matrix_local.to_quaternion()).to_matrix().to_4x4()
    strike = "Melee_Hook" if asset == "M05" else "Zombie_Scratch"
    recipes = {
        "Idle": ("Zombie_Idle_Loop", .8 if asset == "M05" else 1., False, 0., 1.),
        "Walking": ("Zombie_Walk_Fwd_Loop", .7 if asset == "M05" else 1., False, 0., 1.),
        "Running": ("Zombie_Walk_Fwd_Loop", 1.1 if asset == "M05" else 1.7, False, 0., 1.),
        "Attack": (strike, .75 if asset == "M05" else 1., False, 0., 1.),
        "AttackHeavy": ("Melee_Hook", .7, False, 0., 1.),
        "Windup": (strike, 1., False, 0., .28),
        "Recovery": (strike, 1., False, .70, 1.),
        "Block": ("Zombie_Idle_Loop", .85, False, 0., 1.),
        "HitReact": ("Hit_Knockback", .8 if asset == "M05" else 1., False, 0., 1.),
        "Death": ("LayToIdle", .7 if asset == "M05" else 1., True, 0., 1.),
        "Investigate": ("Zombie_Idle_Loop", .65, False, 0., 1.),
        "Threaten": ("Zombie_Idle_Loop", .8, False, 0., 1.),
        "Feed": ("Zombie_Idle_Loop", .65, False, 0., 1.),
        "Sleep": ("LayToIdle", .6, False, 0., 0.),
        "Interact": ("Zombie_Idle_Loop", .8, False, 0., 1.),
    }
    if asset in RELATED_PROFILES:
        walk_speed, run_speed, attack_speed = {
            "M02": (1.15, 1.95, 1.20), "M19": (1.05, 1.65, 1.10),
            "M20": (.60, .95, .60), "M03": (.50, .80, .65),
        }[asset]
        strike = "Zombie_Scratch" if asset == "M02" else "Melee_Hook"
        recipes.update({
            "Walking": ("Zombie_Walk_Fwd_Loop", walk_speed, False, 0., 1.),
            "Running": ("Zombie_Walk_Fwd_Loop", run_speed, False, 0., 1.),
            "Attack": (strike, attack_speed, False, 0., 1.),
            "Windup": (strike, attack_speed, False, 0., .28),
            "Recovery": (strike, attack_speed, False, .70, 1.),
        })
        if asset in {"M03", "M20"}:
            recipes["Idle"] = ("Zombie_Idle_Loop", .65, False, 0., 1.)
            recipes["AttackHeavy"] = ("Melee_Hook", .50, False, 0., 1.)
        if asset == "M03":
            recipes["Feed"] = ("Consume", .70, False, 0., 1.)
    if asset == 'M04':
        recipes.update({
            'Idle': ('Sword_Block', .8, False, 0., 1.),
            'Attack': ('Sword_Regular_A', .85, False, 0., 1.),
            'AttackHeavy': ('Sword_Regular_B', .75, False, 0., 1.),
            'Windup': ('Sword_Regular_A', .75, False, 0., .28),
            'Recovery': ('Sword_Regular_A_Rec', .85, False, 0., 1.),
            'Block': ('Sword_Block', .85, False, 0., 1.),
        })
    report = {}
    for state, (wanted, speed, reverse, low, high) in recipes.items():
        matches = [v for k, v in tracks.items() if k == wanted or k.endswith("|"+wanted)]
        if not matches:
            raise ValueError("Required UAL2 action missing: "+wanted)
        original, slot = matches[0]
        set_action(source, original, slot)
        original_start, original_end = original.frame_range
        start = original_start + (original_end-original_start)*low
        end = original_start + (original_end-original_start)*high
        frames = max(8, round((end-start)/speed))
        action = bpy.data.actions.new(state)
        action.use_fake_user = True
        set_action(rig, action)
        for frame in range(frames+1):
            t = frame/frames
            sample = end-(end-start)*t if reverse else start+(end-start)*t
            whole = math.floor(sample)
            bpy.context.scene.frame_set(whole, subframe=sample-whole)
            for target in rig.pose.bones:
                target.rotation_mode = "QUATERNION"
                correction = corrections[target.name]
                target.matrix_basis = (correction @ source.pose.bones[target.name].matrix_basis
                                       @ correction.inverted())
                if target.name == 'Head' and state == 'Investigate':
                    target.rotation_quaternion @= Quaternion((0,1,0), .20*math.sin(t*math.tau))
                if target.name == 'spine_02' and state in ('Feed','Threaten'):
                    target.rotation_quaternion @= Quaternion((1,0,0), .20 if state=='Feed' else .04*math.sin(t*math.tau))
                if target.name == "root":
                    target.matrix_basis = Matrix.Identity(4)
                target.keyframe_insert("location", frame=frame+1, group=target.name)
                target.keyframe_insert("rotation_quaternion", frame=frame+1, group=target.name)
                target.keyframe_insert("scale", frame=frame+1, group=target.name)
        rig.animation_data.action = None
        track = rig.animation_data.nla_tracks.new()
        track.name = state
        track.strips.new(state, 1, action)
        track.mute = True
        report[state] = {"source": wanted, "speed": speed, "reversed": reverse,
                         "frames": frames+1, "quality": "unreviewed sampled adaptation"}
    source.animation_data_clear()
    for obj in imported:
        bpy.data.objects.remove(obj, do_unlink=True)
    for action in list(bpy.data.actions):
        if action.name not in STATES:
            bpy.data.actions.remove(action)
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    rig.animation_data.action = None
    bpy.context.scene.frame_set(1)
    return report


def render_views(asset, rig, meshes, out):
    # A neutral studio, no environment import or hidden game process.
    idle = bpy.data.actions.get("Idle")
    set_action(rig, idle)
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    lo, hi = bounds(meshes, evaluated=True)
    center = (lo+hi)*.5
    extent = max(hi-lo)
    scene = bpy.context.scene
    scene.render.stamp_note_text = asset + ' | PRIVATE CANDIDATE | STUDIO MATERIAL PREVIEW | NOT ACCEPTED'
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.background_type = "WORLD"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("Review_Neutral")
    scene.world.color = (.18, .18, .18)
    scene.render.resolution_x = 640
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    camera_data = bpy.data.cameras.new(asset+"_ReviewCamera")
    camera = bpy.data.objects.new(camera_data.name, camera_data)
    bpy.context.collection.objects.link(camera)
    scene.camera = camera
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = extent*1.45
    for name, direction in (("front", (0, -1, 0)), ("side", (1, 0, 0)),
                            ("rear", (0, 1, 0)), ("quarter", (1, -2, .15))):
        camera.location = center+Vector(direction).normalized()*extent*3
        camera.rotation_euler = (center-camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(out/(name+".png"))
        bpy.ops.render.render(write_still=True)
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    bpy.context.scene.frame_set(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asset", choices=tuple(DONORS), required=True)
    parser.add_argument('--revision', choices=('v002', 'v003'), default=None)
    argv = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else sys.argv[1:]
    args = parser.parse_args(argv)
    asset = args.asset
    global bpy, bmesh, Vector, Matrix, Quaternion, shared
    import bpy
    import bmesh
    from mathutils import Matrix, Vector, Quaternion
    sys.path.insert(0, str(V1 / "tools"))
    import build_anwen as shared

    inputs = source_files(DONORS[asset])+([] if asset in RETAINED_BODIES else [LIBRARY])
    if asset == "M05":
        inputs.append(V1 / "models/M05_Bell_Eater.blend")
    hashes = {str(p): sha(p) for p in inputs}
    out = GAME / "art_review/stylized" / asset
    if args.revision:
        out = out / args.revision
    out.mkdir(parents=True, exist_ok=True)
    model = RECOVERY / "models" / (asset+"_"+NAMES[asset]+"_stylized.blend")
    if args.revision:
        model = model.with_name(model.stem+'_'+args.revision+'.blend')
    model.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 24
    rig, meshes, metrics = import_donor(asset)
    rests = {b.name: tuple(value for row in b.matrix_local for value in row) for b in rig.data.bones}
    sculpt(asset, rig, meshes)
    skin_materials(asset, meshes, out)
    prop_report = None
    if asset == "M05":
        props, prop_report = append_bell(rig, meshes, out)
        meshes += props
    elif asset in RELATED_PROFILES:
        meshes += related_details(asset, rig, meshes, out)
        prop_report = {"features": RELATED_PROFILES[asset]["features"]}
    elif asset in RETAINED_BODIES:
        prop_report = metrics["retained_components"]
    # Body and equipment share one skinned assembly, not one draw surface per link.
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes: obj.select_set(True)
    bpy.context.view_layer.objects.active = max(meshes,key=lambda o:len(o.data.vertices))
    if len(meshes) > 1:
        bpy.ops.object.join()
    meshes = [bpy.context.object]
    meshes[0].name = asset+'_Connected_Anatomy_SkinnedAssembly'
    clips = embed_clips(asset, rig)
    # Keep all local joint rests intact. A single source-root scale establishes
    # meters; it is not the asset-specific silhouette construction above.
    root = bpy.data.objects.new(asset+"_ReviewRoot", None)
    bpy.context.collection.objects.link(root)
    roots = [o for o in bpy.context.scene.objects if o != root and o.parent is None]
    lo, hi = bounds([o for o in meshes if not o.name.startswith("M05_V1_")])
    factor = HEIGHTS[asset]/(hi.z-lo.z)
    for obj in roots:
        matrix = obj.matrix_world.copy()
        obj.parent = root
        obj.matrix_world = matrix
    root.scale = (factor,)*3
    root.location.z = -lo.z*factor
    bpy.context.view_layer.update()
    if rests != {b.name: tuple(value for row in b.matrix_local for value in row) for b in rig.data.bones}:
        raise ValueError("Unexpected local rest change")
    rig["asset_design_id"] = asset
    rig["art_status"] = "UNREVIEWED_AUTHORING_CANDIDATE"
    rig["root_motion"] = False
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [root, rig]+meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    glb = out/(asset+"_"+NAMES[asset]+"_stylized.glb")
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS",
                              export_force_sampling=True, export_skins=True, export_yup=True,
                              export_extras=True)
    # Check the exported payload, not merely the in-memory action names.
    import struct
    raw = glb.read_bytes()
    size, kind = struct.unpack_from("<II", raw, 12)
    if kind != 0x4E4F534A:
        raise ValueError("Exported GLB JSON missing")
    exported = json.loads(raw[20:20+size])
    exported_clips = {a["name"]: len(a.get("channels", [])) for a in exported.get("animations", [])}
    if not all(exported_clips.get(state, 0) > 0 for state in STATES):
        raise ValueError("Export did not contain all native contract clips: "+str(exported_clips))
    if not exported.get("images") or not exported.get("textures"):
        raise ValueError("Export lost the actual image textures")
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(model), compress=True)
    render_views(asset, rig, meshes, out)
    unchanged = {str(p): sha(p) for p in inputs}
    if hashes != unchanged:
        raise ValueError("An original input changed during authoring")
    report = {"asset": asset, "status": "unreviewed_authoring_candidate", "source_metrics": metrics,
              "source_sha256": hashes, "source_inputs_unchanged": True, "blend": str(model),
              "glb": str(glb), "glb_sha256": sha(glb), "height_basis": "upright bind-space anatomical bounds",
              "target_height_m": HEIGHTS[asset], "source_root_scale": factor,
              "retained_local_rest_transforms": True, "joints": len(rig.data.bones),
              "triangles": sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),
              "prop_components": prop_report, "animation_delivery": "15 retained native procedural actions" if asset in RETAINED_BODIES else "15 embedded sampled actions",
              "animations": clips, "exported_animation_channels": exported_clips,
              "renderer": "BLENDER_WORKBENCH / STUDIO / MATERIAL (geometry preview, not PBR)", "views": ["front", "side", "rear", "quarter"],
              "limitations": ["Not gameplay, deformation, visual or performance accepted",
                              "Bind-space limb reshaping retains old pivots: inspect wrists/elbows and foot contact",
                              "Run adapts walk timing; death reverses LayToIdle; neither is bespoke performance",
                              "No dossier-specific phase, summon, token or facial animation clips",
                              "No jaw articulation, sparse-hair pass or authored skin normal map",
                              "Bell, clapper and fitted harness/chains follow the torso; no physical suspension simulation"],
              "game_data_or_ledgers_modified": False}
    if asset in RELATED_PROFILES:
        report["defining_features"] = RELATED_PROFILES[asset]["features"]
        report["limitations"] = report["limitations"][:-1]+RELATED_PROFILES[asset]["limits"]
    elif asset in RETAINED_BODIES:
        report["defining_features"] = (
            ["retained closed sallet and recessed visor", "lamed plate and funerary linen",
             "asymmetric plated shoulders", "retained straight sword and tall shield"]
            if asset == "M04" else
            ["retained wood/root body and native rig", "broad buttress arms and pillar legs",
             "low knot head with dark hollows", "retained layered bark, root feet and central heartwood"])
        report["limitations"] = ["Retained v1 foundation, not new anatomical sculpting or artistic acceptance",
                                  "Native procedural actions retained; not UAL2 or bespoke encounter performance",
                                  "No gameplay, deformation or performance verification"]
        report["limitations"].append(
            "Shield guard, sword grip and planted contact still require review; no Halvern heraldry"
            if asset == "M04" else
            "Bark opening/root-lane phases are not authored; retained component islands and dense topology need review")
    (out/"source_metrics.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print("STYLIZED_BIPED_COMPLETE", asset, str(glb), flush=True)


if __name__ == "__main__":
    main()
