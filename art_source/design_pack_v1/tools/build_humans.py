"""Blender source authoring for the twelve-person pack and Kael derivative.

Uses the retained licensed face/hand/foot topology and compatible rig, with
individually authored clothing, hair, proportion treatments and keepsakes.
Outputs stay outside Godot until the cast cutover is complete.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_anwen as shared
from bake_anatomy import bake_anwen_surface
from human_designs import DESIGNS

HERE = shared.HERE
TAU = math.tau
PATTERN_REST = {}


def pattern_rest():
    if PATTERN_REST:
        return PATTERN_REST
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(shared.SOURCE))
    imported = set(bpy.data.objects) - before
    skeleton = next(o for o in imported if o.type == "ARMATURE")
    PATTERN_REST.update({bone.name: bone.matrix_local.copy() for bone in skeleton.data.bones})
    for item in imported:
        bpy.data.objects.remove(item, do_unlink=True)
    return PATTERN_REST


def fit_authored_meshes(rig, anatomy_mesh):
    # Garment patterns use Anwen's bind frame. Male skeletons have longer arms
    # and a higher neck; fit the patterns in bind space, never change the rig.
    reference = pattern_rest()
    transforms = {bone.name: bone.matrix_local @ reference[bone.name].inverted()
                  for bone in rig.data.bones if bone.name in reference}
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH" or obj == anatomy_mesh:
            continue
        for vertex in obj.data.vertices:
            source = vertex.co.copy()
            result = Vector((0, 0, 0))
            total = 0.0
            for assignment in vertex.groups:
                name = obj.vertex_groups[assignment.group].name
                if name in transforms:
                    result += (transforms[name] @ source) * assignment.weight
                    total += assignment.weight
            if total:
                vertex.co = result / total
        obj.data.update()


def fit_hair_surfaces(rig, anatomy_mesh):
    bm=bmesh.new(); bm.from_mesh(anatomy_mesh.data)
    tree=BVHTree.FromBMesh(bm)
    center=rig.data.bones["Head"].head_local+Vector((0,0,.115))
    for obj in bpy.context.scene.objects:
        if obj.type!="MESH" or obj==anatomy_mesh:
            continue
        scalp=obj.name.startswith(("AuthoredHair_","CombedLock","HairCoil"))
        beard=obj.name.startswith(("AuthoredBeard","BeardLock","Moustache","Brow_"))
        if not scalp and not beard:
            continue
        for vertex in obj.data.vertices:
            if scalp:
                direction=(vertex.co-center).normalized()
                hit,normal,_,_=tree.ray_cast(center+direction*.4,-direction,.65)
                if hit is not None:
                    vertex.co=hit+normal*(.0045 if obj.name.startswith("AuthoredHair_") else .007)
            else:
                hit,normal,_,_=tree.ray_cast(Vector((vertex.co.x,-.6,vertex.co.z)),Vector((0,1,0)),.9)
                if hit is not None and hit.y<.04:
                    vertex.co.y=hit.y-.0025
        obj.data.update()
    bm.free()


def rgb(code):
    channels = [int(code[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4 for v in channels)


def fixed(bone):
    return lambda p: {bone: 1.0}


def ribbon(name, points, widths, mat, rig, weights=shared.body_weights):
    vertices, uv, faces = [], [], []
    for i, point in enumerate(points):
        tangent = Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(i - 1, 0)])
        lateral = tangent.cross(Vector((0, 1, 0))).normalized()
        if lateral.length < .1:
            lateral = Vector((1, 0, 0))
        for sign in (-1, 1):
            vertices.append(tuple(Vector(point) + lateral * widths[i] * sign * .5))
            uv.append(((sign + 1) / 2, i / (len(points) - 1)))
        if i:
            j = i * 2
            faces.append((j - 2, j - 1, j + 1, j))
    obj = shared.mesh_object(name, vertices, faces, mat, uv)
    shared.bind(obj, rig, weights)
    return obj


def panel(name, bottom, top, half_width, depth, mat, rig, split=False):
    vertices, faces, uv = [], [], []
    columns, rows = 18, 14
    for row in range(rows):
        t = row / (rows - 1)
        z = bottom + (top - bottom) * t
        width = half_width * (1 - .15 * t)
        for col in range(columns + 1):
            u = col / columns
            x = (u * 2 - 1) * width
            zz = z + (.08 * max(0, 1 - abs(x) / .025) * (1 - t) ** 3 if split else 0)
            y = -depth - .010 * math.sin(u * math.pi * 8) * (1 - t)
            vertices.append((x, y, zz))
            uv.append((u, t))
            if row and col:
                a = row * (columns + 1) + col
                faces.append((a - columns - 2, a - columns - 1, a, a - 1))
    obj = shared.mesh_object(name, vertices, faces, mat, uv)
    shared.bind(obj, rig, shared.body_weights)
    return obj


def pocket(name, center, size, mat, rig, bone="pelvis"):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new("Rounded stitched edges", "BEVEL")
    bevel.width = min(size) * .18
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.data.materials.append(mat)
    # Bind vertices in the same rig frame as every other garment mesh.
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    shared.bind(obj, rig, fixed(bone))
    return obj


def ring(name, center, radii, mat, rig, bone="pelvis", minor=.003):
    points = [(center[0] + radii[0] * math.cos(i * TAU / 32), center[1],
               center[2] + radii[1] * math.sin(i * TAU / 32)) for i in range(33)]
    return shared.tube(name, points, [minor] * 33, mat, rig, fixed(bone), 6)


def leg_weights(side):
    def weights(p):
        blend = max(0, min(1, (.61 - p.z) / .14))
        return {"thigh_" + side: 1 - blend, "calf_" + side: blend}
    return weights


def trousers(rig, mat, width):
    for side, sign in (("l", 1), ("r", -1)):
        points, radii = [], []
        for i in range(20):
            t = i / 19
            z = .15 + .83 * t
            points.append((sign * (.12 + .015 * math.sin(t * math.pi)), .035, z))
            radius = (.046 + .052 * t) * width + .004 * math.sin(t * 51) * (1 - .5 * t)
            radii.append(radius)
        shared.tube("Trousers_" + side, points, radii, mat, rig, leg_weights(side), 20)


def sleeves(rig, cloth, cuff, skin, rolled, width):
    for side, sign in (("l", 1), ("r", -1)):
        def weights(p, side=side):
            elbow = max(0, min(1, (abs(p.x) - .35) / .09))
            if abs(p.x) < .20:
                arm = max(0, min(1, (abs(p.x) - .12) / .08))
                return {"spine_03": 1 - arm, "upperarm_" + side: arm}
            return {"upperarm_" + side: 1 - elbow, "lowerarm_" + side: elbow}
        end = .46 if rolled else .60
        points, radii = [], []
        for i in range(18):
            t = i / 17
            x = .12 + (end - .12) * t
            points.append((sign * x, .055, 1.418))
            radii.append((.039 + .034 * math.sin(min(1, t * 4) * math.pi / 2) - .026 * t) * width
                         + .003 * math.sin(t * 47))
        shared.tube("Sleeve_" + side, points, radii, cloth, rig, weights, 20)
        shared.tube("Cuff_" + side, [(sign * (end - .04), .055, 1.418), (sign * end, .055, 1.418)],
                    [.058 * width, .053 * width], cuff, rig, weights, 20)
        if rolled:
            shared.tube("Forearm_" + side,
                        [(sign * .44, .055, 1.418), (sign * .51, .055, 1.418),
                         (sign * .59, .055, 1.418), (sign * .635, .055, 1.418)],
                        [.049 * width, .043 * width, .031, .026], skin, rig, weights, 20)


def anatomy(rig, obj, design, skin):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    uv = bm.loops.layers.uv.active
    obj.data.materials.append(skin)
    remove = []
    head_base = rig.data.bones["Head"].head_local.z
    collar_base = rig.data.bones["neck_01"].head_local.z - .04
    for face in bm.faces:
        p = face.calc_center_median()
        coords = [loop[uv].uv for loop in face.loops]
        skin_tile = all(.25 < c.x < 1 and .5 < c.y < 1 for c in coords) and p.z > collar_base-.04 and abs(p.x) < .2
        eyes = all(.5 < c.x < .75 and 0 < c.y < .5 for c in coords)
        hands = abs(p.x) > rig.data.bones["hand_l"].head_local.x - .022 and p.z > 1.3
        boots = p.z < .17
        keep = skin_tile or eyes or hands or boots
        if all(c.x < .5 and c.y < .5 for c in coords):
            keep = False
        if hands:
            face.material_index = 1
        if not keep:
            remove.append(face)
    bmesh.ops.delete(bm, geom=remove, context="FACES")
    head_faces = [f for f in bm.faces if f.calc_center_median().z > collar_base-.05
                  and abs(f.calc_center_median().x) < .2]
    head_geometry = set(head_faces)
    for face in head_faces:
        head_geometry.update(face.edges)
        head_geometry.update(face.verts)
    cut = bmesh.ops.bisect_plane(bm, geom=list(head_geometry), dist=.000001,
                                plane_co=(0,0,collar_base), plane_no=(0,0,1),
                                clear_inner=True, clear_outer=False)
    neck_edges = [edge for edge in cut["geom_cut"] if isinstance(edge,bmesh.types.BMEdge)
                  and edge.is_boundary]
    lower = {}
    deform = bm.verts.layers.deform.verify()
    neck_index = obj.vertex_groups["neck_01"].index
    for edge in neck_edges:
        for vertex in edge.verts:
            if vertex not in lower:
                p=vertex.co
                joined=bm.verts.new((p.x*.96,p.y,collar_base-.025))
                joined[deform][neck_index]=1.0
                lower[vertex]=joined
        a,b=edge.verts
        face=bm.faces.new((b,a,lower[a],lower[b]))
        face.material_index=1
        for loop,coordinate in zip(face.loops,((0,1),(1,1),(1,0),(0,0))):
            loop[uv].uv=coordinate
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    face_vertices = set()
    uv = obj.data.uv_layers.active
    for polygon in obj.data.polygons:
        if all(.25 < uv.data[i].uv.x < 1 and .5 < uv.data[i].uv.y < 1 for i in polygon.loop_indices):
            face_vertices.update(polygon.vertices)
    jaw, nose, length = design["face"]
    for index in face_vertices:
        v = obj.data.vertices[index]
        x, y, z = v.co
        head_offset = rig.data.bones["Head"].head_local.z - 1.5496
        z -= head_offset
        front = max(0, min(1, (.025 - y) / .07))
        lower = math.exp(-((z - 1.603) / .045) ** 2)
        middle = math.exp(-(x / .021) ** 2 - ((z - 1.647) / .038) ** 2)
        v.co.x *= 1 + (jaw - 1) * lower
        v.co.y -= (nose - 1) * .025 * middle * front
        v.co.z += (length - 1) * (z - 1.69) * lower
        v.co.y += .0025 * design["age"] * math.exp(-((abs(x) - .046) / .024) ** 2
                                                    - ((z - 1.624) / .029) ** 2) * front
        if z < 1.51:
            v.co.z -= .020 * max(0, min(1, (1.53 - z) / .045))
    # The source head includes a flared shoulder skirt. Keep its facial
    # topology, but fit that hidden lower skirt inside the new collar.
    for vertex in obj.data.vertices:
        if abs(vertex.co.x) < .20 and collar_base-.04 < vertex.co.z < head_base+.025:
            x, y = vertex.co.x, vertex.co.y-.025
            distance = math.sqrt((x/.047)**2 + (y/.049)**2)
            if distance > 1:
                vertex.co.x = x / distance
                vertex.co.y = .025 + y / distance
    obj.data.update()
    obj.name = design["name"] + "_Anatomy"
    return face_vertices


def hair(rig, style, mat, beard):
    if style != "bald":
        vertices, faces, uv = [], [], []
        rows, cols = 12, 48
        for row in range(rows):
            t = .012 + .988 * row / (rows - 1)
            for col in range(cols + 1):
                angle = TAU * col / cols
                back = max(0, -math.cos(angle))
                end = 1.20 + .78 * back
                if style in ("receding", "bald_crown"):
                    end -= .25 * max(0, math.cos(angle))
                phi = t * end
                if style == "bald_crown":
                    phi = .9 + t * (end - .9)
                wave = .002 * math.sin(angle * 19 + t * 11)
                if style in ("curly_cap", "silver_coils", "tousled"):
                    wave += .004 * math.sin(angle * 31 - t * 18)
                vertices.append(((.087 + wave) * math.sin(phi) * math.sin(angle),
                                 .015 - (.087 + wave) * math.sin(phi) * math.cos(angle),
                                 1.674 + (.119 + wave) * math.cos(phi)))
                uv.append((col / cols, t))
                if row and col:
                    a = row * (cols + 1) + col
                    faces.append((a - cols - 2, a - cols - 1, a, a - 1))
        obj = shared.mesh_object("AuthoredHair_" + style, vertices, faces, mat, uv)
        shared.bind(obj, rig, fixed("Head"))
        if style in ("curly_cap", "silver_coils", "bald_crown"):
            for row in range(6):
                for col in range(14):
                    a = TAU * (col + .5 * (row % 2)) / 14
                    phi = .40 + row * .24
                    if style == "bald_crown" and (phi < 1.0 or math.cos(a) > .5):
                        continue
                    center = Vector((.090 * math.sin(phi) * math.sin(a),
                                     .015 - .09 * math.sin(phi) * math.cos(a),
                                     1.674 + .125 * math.cos(phi)))
                    axis = Vector((math.cos(a), math.sin(a), 0))
                    points = [tuple(center + axis * (.007 * math.cos(i * TAU / 9))
                                    + Vector((0,0,.007 * math.sin(i * TAU / 9)))) for i in range(10)]
                    shared.tube("HairCoil", points, [.0022] * 10, mat, rig, fixed("Head"), 5)
        else:
            for strand in range(24):
                a = TAU * strand / 24
                points = []
                for i in range(10):
                    t = i / 9
                    phi = .18 + t * (1.02 + .65 * max(0, -math.cos(a)))
                    aa = a + .12 * math.sin(t * 5 + strand)
                    points.append((.090 * math.sin(phi) * math.sin(aa),
                                   .015 - .092 * math.sin(phi) * math.cos(aa),
                                   1.674 + .122 * math.cos(phi)))
                shared.tube("CombedLock", points, [.0035 * (1 - .6 * i / 9) for i in range(10)],
                            mat, rig, fixed("Head"), 5)
    if style in ("long_braid", "side_braid", "crown_braid", "low_coil"):
        for strand in range(3):
            points = []
            for i in range(49):
                t = i / 48
                a = t * TAU * 6 + strand * TAU / 3
                if style == "long_braid":
                    center = Vector((.075 + .045 * t, -.015 - .12 * t, 1.69 - .40 * t))
                elif style == "side_braid":
                    center = Vector((.082, .008 + .08 * t, 1.71 - .15 * t))
                elif style == "crown_braid":
                    center = Vector((.085 * math.sin(TAU*t), .015 - .085 * math.cos(TAU*t), 1.75))
                else:
                    center = Vector((.033 * math.cos(TAU*t), .108, 1.62 + .027 * math.sin(TAU*t)))
                points.append(tuple(center + Vector((.008 * math.cos(a), .007 * math.sin(a), 0))))
            shared.tube("BraidedHair_" + str(strand), points, [.0065 * (1 - .35 * i / 48) for i in range(49)],
                        mat, rig, fixed("Head"), 6)
    if beard not in ("none", "moustache"):
        vertices, faces, uv = [], [], []
        for row in range(9):
            t = row / 8
            for col in range(25):
                u = col / 24
                angle = (u - .5) * math.pi
                x = .063 * math.sin(angle) * (1 - .16 * t)
                y = -.036 - .054 * math.cos(angle) + .009 * t
                z = 1.602 + .045 * abs(math.sin(angle)) - t * (.047 if beard == "full" else .028)
                vertices.append((x, y, z))
                uv.append((u, t))
                if row and col:
                    i = row * 25 + col
                    faces.append((i - 26, i - 25, i, i - 1))
        obj = shared.mesh_object("AuthoredBeard", vertices, faces, mat, uv)
        shared.bind(obj, rig, fixed("Face_Jaw"))
    if beard != "none":
        for side in (-1, 1):
            if beard == "moustache":
                points = [(side * (.006 + i * .006), -.093 + i * .002, 1.613 - i * .0015) for i in range(6)]
                shared.tube("Moustache", points, [.003,.006,.006,.005,.004,.001], mat, rig, fixed("Head"), 8)
            else:
                for lock in range(8):
                    x = side * (.012 + .006 * lock)
                    length = .027 if beard == "full" else .010
                    start = Vector((x, -.053 - .025 * (1 - lock / 8), 1.60 + .007 * lock))
                    end = Vector((x * .8, start.y + .013, start.z - length))
                    points = [tuple(start.lerp(end, i / 6)) for i in range(7)]
                    shared.tube("BeardLock", points, [.005 * (1 - .6 * i / 6) for i in range(7)],
                                mat, rig, fixed("Face_Jaw"), 6)
    for side, label in ((1,"L"),(-1,"R")):
        points = [(side*(.014 + .009*i),-.075,1.682+.005*math.sin(i*math.pi/4)) for i in range(5)]
        shared.tube("Brow_"+label,points,[.002,.003,.003,.002,.001],mat,rig,fixed("Face_Brow_"+label),6)


def keepsakes(rig, design, mats):
    primary, linen, accent, leather, metal, hair_mat, skin, wood = mats
    width = design["width"]
    for kind in design["props"]:
        if kind in ("apron", "baker_apron", "smith_apron"):
            fabric = leather if kind == "smith_apron" else linen
            panel(kind + "_Skirt", .36 if kind != "smith_apron" else .56,
                  1.055, .21 * width, .158 * design["waist"], fabric, rig, kind == "smith_apron")
            if kind == "smith_apron":
                panel("SmithApron_Bib", 1.02, 1.35, .13 * width, .16, fabric, rig)
                for side in (-1,1):
                    ribbon("ApronShoulderStrap",[(side*.115,-.163,1.31),(side*.14,-.06,1.44),
                                                (side*.13,.09,1.42),(side*.10,.14,1.04)], [.025]*4,leather,rig)
                pocket("PatchedApronPocket",(.12,-.177,.75),(.13,.008,.12),leather,rig)
        elif kind in ("tabard", "open_vest", "bodice", "breastplate", "hunter_panels"):
            material = metal if kind == "breastplate" else linen if kind in ("tabard","open_vest") else accent
            if kind == "tabard":
                for side in (-1,1):
                    ribbon("ArchiveTabard",[(side*.12,-.13,.32),(side*.09,-.145,1.04),
                                           (side*.13,-.145,1.30),(side*.16,.02,1.45),
                                           (side*.13,.13,1.29),(side*.12,.14,.35)], [.13,.10,.10,.12,.12,.14],material,rig)
            else:
                shared.garment(kind,[(.95,.158*width,.123,.024),(1.08,.158*width,.125,.024),
                                    (1.27,.19*width,.143,.015),(1.39,.183*width,.11,.02)],
                               material,rig,count=48,opening=.28 if kind=="open_vest" else .1,folds=.002)
        elif kind in ("map_case","seal_case","archive_pockets","grain_packet","name_packet"):
            sign = -1 if kind in ("map_case","seal_case") else 1
            x = sign * .215 * design["waist"]
            pocket(kind,(x,-.02,.88),(.17,.07,.19 if kind=="map_case" else .13), linen if kind in ("grain_packet","name_packet") else leather,rig)
            pocket(kind+"_Flap",(x,-.058,.93),(.18,.01,.055),leather,rig)
            ribbon(kind+"_Strap",[(x,-.02,.96),(sign*.07,-.15,1.18),(-sign*.14,-.08,1.44),
                                (-sign*.14,.12,1.39),(x,.09,.96)],[.025]*5,leather,rig)
        elif kind in ("road_knot","oath_cord","rescue_rope"):
            count = 7 if kind=="rescue_rope" else 2
            for strand in range(count):
                center = (.19,.14,1.20) if kind=="rescue_rope" else (-.17,-.10,.94)
                radii = (.09,.19) if kind=="rescue_rope" else (.025,.038)
                points=[(center[0]+radii[0]*math.cos(i*TAU/40),center[1]+strand*.008,
                         center[2]+radii[1]*math.sin(i*TAU/40)) for i in range(41)]
                shared.tube(kind,points,[.006]*41,linen,rig,fixed("spine_03" if kind=="rescue_rope" else "pelvis"),6)
        elif kind in ("drawer_key","store_keys","signet","iron_ring","counterweight"):
            count=3 if kind=="store_keys" else 1
            ring(kind+"_Loop",(.18,-.13,1.0),(.018,.022),metal,rig)
            for i in range(count):
                x=.165+i*.017
                shared.tube(kind+"_Stem",[(x,-.135,.98),(x,-.135,.90)],[.0035]*2,metal,rig,fixed("pelvis"),6)
                pocket(kind+"_Bit",(x+.007,-.135,.905),(.018,.007,.015),metal,rig)
        elif kind in ("hammer_loop","utility_sheath","sword_scabbard","signal_baton","wax_pencil"):
            length={"hammer_loop":.24,"utility_sheath":.19,"sword_scabbard":.68,"signal_baton":.35,"wax_pencil":.16}[kind]
            x=-.22*design["waist"]
            shared.tube(kind,[(x,.02,.99),(x-.025,.025,.99-length)],[.018,.013],wood if kind in ("hammer_loop","signal_baton","wax_pencil") else leather,rig,fixed("pelvis"),10)
            if kind=="hammer_loop":
                pocket("HammerHead",(x,.02,.995),(.11,.045,.045),metal,rig)
        elif kind=="tally_board":
            pocket(kind,(.23,-.02,.82),(.16,.025,.24),wood,rig)
            for row in range(9):
                for column in range(3):
                    pocket("TallyPeg",(.18+column*.04,-.038,.73+row*.021),(.012,.006,.008),linen,rig)
        elif kind=="medicine_pouches":
            for side in (-1,1):
                pocket("HerbPacket",(side*.22,-.04,.92),(.085,.065,.13),linen,rig)
                ring("PacketTie",(side*.22,-.075,.985),(.020,.01),accent,rig)
        elif kind=="root_bundle":
            for i in range(12):
                points=[(.24+.003*i,-.02,.98),(.24+.006*i,-.015,.88),(.23+.009*i,-.02,.76-.006*(i%3))]
                shared.tube("TiedRoot",points,[.003,.003,.001],wood,rig,fixed("pelvis"),5)
        elif kind=="measure":
            shared.tube("WoodMeasure",[(-.22,-.02,.87),(-.22,-.02,.96)],[.035,.035],wood,rig,fixed("pelvis"),16)
        elif kind=="lantern":
            pocket("LanternFoot",(.24,-.02,.77),(.075,.075,.025),metal,rig)
            pocket("LanternHood",(.24,-.02,.92),(.085,.085,.045),metal,rig)
            for x in (.208,.272):
                for y in (-.052,.012):
                    shared.tube("LanternFrame",[(x,y,.78),(x,y,.91)],[.003]*2,metal,rig,fixed("pelvis"),6)
            shared.tube("UnlitLanternCandle",[(.24,-.02,.79),(.24,-.02,.87)],[.012]*2,linen,rig,fixed("pelvis"),10)
            ring("LanternHandle",(.24,-.02,.96),(.025,.035),metal,rig)
        elif kind in ("shawl","rust_scarf"):
            shared.shawl(rig, accent)
        elif kind in ("linen_band","kerchief"):
            points=[(.089*math.sin(i*TAU/40),.015-.083*math.cos(i*TAU/40),1.755) for i in range(41)]
            shared.tube(kind,points,[.007 if kind=="linen_band" else .016]*41,linen,rig,fixed("Head"),8)
        elif kind=="boot_cuffs":
            for side, sign in (("l",1),("r",-1)):
                shared.tube("TallBoot_"+side,[(sign*.12,.035,.12),(sign*.12,.035,.35),(sign*.12,.035,.42)],
                            [.060,.068,.071],leather,rig,fixed("calf_"+side),20)
        elif kind=="oath_ribbon":
            ribbon("CutMilitaryRibbon",[(-.12,-.15,1.38),(-.125,-.16,1.30),(-.14,-.165,1.24)],
                   [.035,.034,.025],linen,rig)
        elif kind=="sleeve_ties":
            for side,sign in (("l",1),("r",-1)):
                shared.tube("ArchiveSleeveTie",[(sign*.40,.055,1.418),(sign*.423,.055,1.418)],
                            [.065,.065],accent,rig,fixed("lowerarm_"+side),16)
        elif kind=="coat_fasteners":
            for i in range(6):
                ring("CoatFastener",(.035,-.15,1.10+i*.04),(.007,.006),metal,rig,"spine_02",.002)
        else:
            raise ValueError("Unimplemented authored prop " + kind)


def build(asset_id, render=False):
    design=DESIGNS[asset_id]
    out=HERE/"exports"/asset_id
    out.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.data.orphans_purge(do_recursive=True)
    source=shared.BASE/"runtime"/("Anwen_A_Set_Atlas.gltf" if design["gender"]=="female" else "Kael_A_Set_Atlas.gltf")
    bpy.ops.import_scene.gltf(filepath=str(source))
    rig=next(o for o in bpy.context.scene.objects if o.type=="ARMATURE")
    obj=max((o for o in bpy.context.scene.objects if o.type=="MESH"),key=lambda o:len(o.data.vertices))
    for other in list(bpy.context.scene.objects):
        if other.type=="MESH" and other!=obj:
            bpy.data.objects.remove(other,do_unlink=True)
    rig.name="Armature"
    mats=[shared.material(asset_id+"_"+str(i),rgb(code),.90 if i<4 else .58,.55 if i==4 else 0)
          for i,code in enumerate(design["colors"])]
    mats += [shared.material(asset_id+"_Hair",rgb(design["hair_color"]),.8),
             shared.material(asset_id+"_Hands",design["skin"],.77),
             shared.material(asset_id+"_Wood",rgb("776047"),.88)]
    face_vertices=anatomy(rig,obj,design,mats[6])
    bake_anwen_surface(obj,face_vertices,out,asset_id,design["tint"],design["age"],design["skin"],rig.data.bones["Head"].head_local.z-1.5496)
    width,waist=design["width"],design["waist"]
    hem=design["hem"]
    lower_radius=.29*waist if hem<.4 else .18*waist
    rings=[(hem,lower_radius,.18 if hem<.4 else .13,.03),
           ((hem+.99)*.5,lower_radius*.87,.15,.03),(.99,.15*waist,.115*waist,.025),
           (1.09,.15*waist,.115*waist,.022),(1.25,.178*width,.13,.015),
           (1.39,.18*width,.10,.025),(1.45,.071,.062,.025)]
    shared.garment("AuthoredShirtOrGown",rings,mats[0] if design["coat"] is None else mats[1],rig,folds=.005)
    shared.garment("LinenCollar",[(1.43,.071,.064,.025),(1.54,.058,.060,.025)],mats[1],rig,count=32,opening=.025,folds=.001)
    trousers(rig,mats[2],max(.95,waist))
    if design["coat"] is not None:
        lower=design["coat"]
        coat=[(lower,(.30 if lower<.6 else .20)*waist,.18 if lower<.6 else .15,.035),
              ((lower+1)*.5,.21*waist,.15,.03),(1.0,.165*waist,.13*waist,.024),
              (1.12,.165*waist,.13*waist,.024),(1.30,.196*width,.145,.014),
              (1.41,.188*width,.115,.023),(1.47,.079,.070,.025)]
        shared.garment("AuthoredOpenCoat",coat,mats[0],rig,opening=.30,folds=.004)
    sleeves(rig,mats[0] if design["coat"] is not None else mats[1],mats[2],mats[6],design["sleeves"]=="rolled",width)
    shared.garment("LeatherBelt",[(1.015,.167*waist,.133*waist,.025),(1.061,.167*waist,.133*waist,.025)],
                   mats[3],rig,count=48,folds=0)
    ring("BeltBuckle",(0,-.112*waist,1.037),(.025,.017),mats[4],rig)
    ribbon("BeltTongue",[(.02,-.118*waist,1.04),(.025,-.145*waist,.95),(.035,-.16*waist,.84)], [.022]*3,mats[3],rig)
    hair(rig,design["hair"],mats[5],design["beard"])
    if design["hair"]=="curly_cap":
        shared.garment("TravelCapBand",[(1.75,.092,.090,.015),(1.78,.096,.093,.015)],mats[3],rig,count=40,folds=.002)
        cap=shared.garment("TravelCapCrown",[(1.77,.095,.092,.015),(1.81,.086,.082,.025),(1.837,.012,.014,.04)],mats[3],rig,count=40,folds=.003)
        for o in (cap,bpy.data.objects.get("TravelCapBand")):
            o.vertex_groups.clear()
            group=o.vertex_groups.new(name="Head")
            group.add(list(range(len(o.data.vertices))),1,"REPLACE")
    keepsakes(rig,design,mats)
    if design["gender"] == "male":
        fit_authored_meshes(rig,obj)
    fit_hair_surfaces(rig,obj)
    shared.cloth_thickness()
    shared.cloth_atlas(mats,out,asset_id)
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for mesh in meshes: mesh.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.join()
    obj.name=asset_id+"_"+design["name"]+"_Skinned"
    rig["asset_design_id"]=asset_id
    rig["character_silhouette_baked"]=True
    rig["character_prebaked_identity"]=True
    rig["provenance"]="Licensed CC0 anatomy and bind rig; new design-pack clothing, hair, keepsakes and surface treatment"
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active=rig
    path=out/(asset_id+"_"+design["name"]+".glb")
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
                              export_animations=False,export_skins=True,export_yup=True)
    contract=shared.retained_rig_contract(path,source)
    reference=next(iter((HERE/"AshenOath_Asset_Pack/images/characters").glob(asset_id+"_*.png")),None)
    if reference:
        ref=bpy.data.objects.new("REFERENCE_NotRuntime",None)
        ref.empty_display_type="IMAGE"
        ref.data=bpy.data.images.load(str(reference))
        ref.location=(2.4,1,1)
        ref.empty_display_size=2
        ref.hide_render=True
        bpy.context.collection.objects.link(ref)
    scene=shared.preview_scene(rig)
    scene.render.resolution_x=800
    scene.render.resolution_y=1000
    scene.cycles.samples=24
    bpy.ops.file.pack_all()
    (HERE/"models").mkdir(exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/"models"/(asset_id+"_"+design["name"]+".blend")),compress=True)
    report={"id":asset_id,"name":design["name"],"status":"authored_pending_runtime_integration",
            "source":str(source.relative_to(shared.REPO)),"source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),
            "license":"CC0 Quaternius anatomy and rig; design-derived authoring recorded in source",
            "rig":contract,"triangles":sum(len(p.vertices)-2 for p in obj.data.polygons),
            "vertices":len(obj.data.vertices),"glb_bytes":path.stat().st_size,"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),
            "props":design["props"],"gameplay_tested":False,"user_accepted":False}
    (out/"production.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    if render:
        scene.render.filepath=str(out/(asset_id+"_model.png"))
        bpy.ops.render.render(write_still=True)
    print("HUMAN_BUILD="+json.dumps(report),flush=True)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--ids",nargs="+",default=list(DESIGNS))
    parser.add_argument("--render",action="store_true")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    for asset in args.ids:
        build(asset,args.render)
