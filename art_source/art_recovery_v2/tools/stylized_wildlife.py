"""Individual, retained-mesh wildlife revisions. Never imports the v1 factory.

From PowerShell, after the biped/human work (commands for the main author):
  & 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python 'D:/Projects/AshenOath/art_source/art_recovery_v2/tools/stylized_wildlife.py' -- --asset M08
Repeat that command with ONE other ID, in order:
M13 M07 M11 M09 M10 M12 M14 M15 M16 M17 M18. There is no batch option.
Use --revision v002 for another preserved candidate, never overwrite v001.
Ordinary Python --asset M08 --describe prints the recipe without importing bpy.

Sources remain intact. Outputs are recovery/models/<ID>_*_<revision>.blend,
game/art_review/stylized/<ID>/<revision>/{*.glb,*basecolor.png,candidate.json},
and recovery/evidence/stylized/<ID>/<revision>/{front,side,rear,quarter}.png.
The game is outputs/AshenOathTheRoadBetweenCrowns, not a new game directory.
No manifests, global ledgers, acceptance gates, or production assets are written.
The retained Wolf/animated-animal and four-legged Dragon sources are not forced
onto incompatible reptile, invertebrate or two-legged wyvern rigs. M08 uses the
actual licensed native animated stag; other recipes keep their v1 native rigs.

These are bounded best-effort edits, not finished creature reconstructions.
Native motion is retained, not improved by the existence of a mesh revision.
Workbench views are opaque studio-texture previews, not PBR/transparency,
Godot, arena-clearance, deformation, or user-acceptance evidence.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import sys


RECOVERY = Path(__file__).resolve().parents[1]
REPO = RECOVERY.parents[1]
V1 = RECOVERY.parent / "design_pack_v1"
GAME = REPO / "outputs/AshenOathTheRoadBetweenCrowns"
ORDER = ("M08", "M13", "M07", "M11", "M09", "M10", "M12", "M14", "M15", "M16", "M17", "M18")
NAMES = {
    "M08": "White_Hart_Avatar", "M13": "Hearthscale",
    "M07": "Ashwing_Carrion_Drake", "M11": "Glassmoth", "M09": "Silt_Maw",
    "M10": "Millback", "M12": "Knell_Leech", "M14": "Gallows_Weaver",
    "M15": "Reed_Choir", "M16": "Inkblind", "M17": "Cairn_Mother", "M18": "Shroud_Swimmer",
}
RECIPES = {
    "M08": ["Use the licensed native WhiteHart_Stag mesh, weights and clips, not the v1 cervid factory.",
            "Broaden chest planes, tuck lower flank, widen uneven antler beams at retained pedicles.",
            "Map native material regions into the existing ivory/antler/hoof atlas; alias real native locomotion clips."],
    "M13": ["Retain the connected v1 reptile, four leg chains, head, tail and claws.",
            "Flatten/broaden snout and shoulder planes; remove tiny mineral scale inserts.",
            "Replace them with overlapping closed shield plates, largest at shoulders, smaller toward tail."],
    "M07": ["Retain the existing two-leg/two-wing drake mesh and its dedicated rig/clips.",
            "Reshape hooked skull, sternum and bare throat; fold retained membrane grids.",
            "Blend membrane weights to existing load-bearing wing fingers instead of wrist-only motion."],
    "M11": ["Retain body, six legs, eyes, feeding coil and comb antennae; remove v1 wing components.",
            "Build four scalloped, cambered membrane grids with integral raised vein ribs on the existing wing bones.",
            "Use the existing atlas and bounded alpha; do not promise clear-window/PBR appearance in Workbench."],
    "M09": ["Retain continuous annulated body, spline weights and jaw rig; flatten belly and digger skull.",
            "Make the head a broader shovel wedge and reduce mechanical equal-height annulations.",
            "Add two compact closed lateral jaw plates attached to the retained Jaw bone."],
    "M10": ["Keep six walking legs, two claw chains and eye stalks; remove the inflated shell and ridge inserts.",
            "Lower the retained body, compact the working claws, and add a closed stepped oval carapace.",
            "A broad asymmetric polished rim replaces decorative shell noise."],
    "M12": ["Retain the continuous annulated body and both suction-disc topologies.",
            "Flatten the belly, vary annulus compression and recess the radial teeth into the anterior cup.",
            "Flare the large front lip and compact the smaller rear anchoring pad."],
    "M14": ["Retain eight leg chains, exactly eight eyes, chelicerae and two spinnerets.",
            "Reshape the retained abdominal component into a rear-heavy pear; lower the compact thorax.",
            "Raise the upper-leg arches, sharpen knee bends and shorten exposed fang tips."],
    "M15": ["Retain connected amphibian core, four folded leg chains and AirSac0/1/2 controls.",
            "Remove detached sac/vein components; extrude three bellows from dorsal body faces.",
            "Add bounded per-sac inflation shape keys; do not claim authored pressure-call motion."],
    "M16": ["Retain blind head, six legs, long feelers, feeding brushes and native rig.",
            "Remove stacked elytron inserts; replace them with one closed wedge shield and recessed central seam.",
            "Lower the body and shorten legs visually without introducing eyes or wings."],
    "M17": ["Retain spiral shell tube, muscular foot, head and all four feeler controls.",
            "Remove pyramid mineral accretions and repetitive foot-margin rods.",
            "Broaden and flatten the retained sole; sculpt layered mineral ledges into the actual spiral surface."],
    "M18": ["Retain ray disc, fin chains, unbarbed tail, dorsal eyes and ventral anatomy.",
            "Reshape the oval disc into a diamond with a thicker central load path and flexible edges.",
            "Weld coincident top/bottom perimeter vertices and blend fin weights by span; pale ventral atlas tile."],
}
LIMITATIONS = {
    "M08": "Native low-poly face/fur remain simplified. Antler roots are retained, not rebuilt. Witness/mercy clips are not authored.",
    "M13": "Plate articulation and low stance require playback; no heat, grit, throat-control or kiln implementation.",
    "M07": "V1 drake body is retained, not replaced by a native four-legged Dragon with incompatible extra limbs. Wing folds/weights need playback; no flight physics or arena clearance check.",
    "M11": "Four wings remain rigidly controlled per wing. Clear windows are not painted; uniform bounded alpha and raised veins are a best-effort membrane, not a final glass material.",
    "M09": "No burrow effects or collision changes. Existing jaw/spline motion is generic; lateral jaw plates share the Jaw control.",
    "M10": "Existing pincer chains remain; shell/leg clearance and sideways locomotion are untested. No river weed simulation.",
    "M12": "Existing open suction topology is retained. Teeth are recessed, not rebuilt into gum topology. No latch, compression or wetness animation authored.",
    "M14": "Bristles and existing limb topology remain simplified. No web, pounce, accessibility mode or contact IK implementation.",
    "M15": "Connected extrusions and fixed-maximum morphs need deformation review. Inflation keys are unanimated; pressure-call and hop clips are not supplied.",
    "M16": "Brushes remain simple retained geometry. Shield/antenna clearance and feeding are untested. No new antenna controls or archive behavior.",
    "M17": "Retained spiral is refined, not full shell retopology. Sole contact and crawl remain untested; no lichen painting or shell-withdraw motion.",
    "M18": "Perimeter welding is local, not whole-body retopology. Fin waves, ventral clearance, and water interaction need review; no aquatic controller changes.",
}
COMMON = ("Idle", "Walking", "Running", "Attack", "HitReact", "Death")
STAG_ALIASES = {"Idle": "Idle", "Death": "Death", "Walking": "Walk", "Running": "Gallop", "Attack": "Attack_Headbutt",
                "AttackHeavy": "Attack_Kick", "HitReact": "Idle_HitReact1", "Feed": "Eating",
                "Windup": "Idle_Headlow", "Recovery": "Idle_2", "Block": "Idle_Headlow",
                "Investigate": "Idle_2", "Threaten": "Idle_Headlow", "Sleep": "Idle_Headlow", "Interact": "Idle_2"}


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def source_for(asset):
    if asset == "M08":
        return GAME / "assets_external/enemies/WhiteHart_Stag.glb"
    return V1 / "models" / f"{asset}_{NAMES[asset]}.blend"


def parse_args(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter,
                                     allow_abbrev=False)
    parser.add_argument("--asset", required=True, choices=ORDER)
    parser.add_argument("--revision", default="v001", help="New output revision, e.g. v002; no overwriting")
    parser.add_argument("--describe", action="store_true", help="Print recipe only, without Blender or output writes")
    args = parser.parse_args(argv)
    if sum(a == "--asset" or a.startswith("--asset=") for a in argv) != 1:
        parser.error("exactly one --asset is allowed per invocation")
    if not re.fullmatch(r"v[0-9]{3,6}", args.revision):
        parser.error("--revision must be v followed by 3-6 digits")
    return args


def components(obj):
    """Connected islands survive the v1 join; UV tiles identify their purpose."""
    parents = list(range(len(obj.data.vertices)))

    def root(i):
        while parents[i] != i:
            parents[i] = parents[parents[i]]
            i = parents[i]
        return i

    for edge in obj.data.edges:
        a, b = (root(i) for i in edge.vertices)
        parents[b] = a
    groups = {}
    for vertex in obj.data.vertices:
        groups.setdefault(root(vertex.index), []).append(vertex.index)
    result = []
    for indices in groups.values():
        points = [obj.data.vertices[i].co for i in indices]
        low = Vector(tuple(min(p[k] for p in points) for k in range(3)))
        high = Vector(tuple(max(p[k] for p in points) for k in range(3)))
        result.append({"ids": indices, "center": (low + high) / 2, "span": high - low})
    return result


def dominant(obj, index):
    groups = obj.data.vertices[index].groups
    return obj.vertex_groups[max(groups, key=lambda g: g.weight).group].name if groups else ""


def tile_indices(obj):
    result = {}
    layer = obj.data.uv_layers.active
    if layer is None:
        raise ValueError(f"Missing retained atlas UVs: {obj.name}")
    for face in obj.data.polygons:
        uv = layer.data[face.loop_start].uv
        tile = min(3, max(0, int(uv.x * 4))) + 4 * min(1, max(0, int(uv.y * 2)))
        for i in face.vertices:
            result.setdefault(i, tile)
    return result


def remove_islands(obj, predicate):
    tiles = tile_indices(obj)
    discard = set()
    for part in components(obj):
        ids = part["ids"]
        part["tile"] = max(range(8), key=lambda t: sum(tiles.get(i) == t for i in ids))
        votes = {}
        for i in ids:
            bone = dominant(obj, i)
            votes[bone] = votes.get(bone, 0) + 1
        part["bone"] = max(votes, key=votes.get)
        if predicate(part):
            discard.update(ids)
    if discard:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[bm.verts[i] for i in sorted(discard)], context="VERTS")
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
    return len(discard)


def deform(obj, function):
    maximum, moved = 0.0, 0
    for vertex in obj.data.vertices:
        old = vertex.co.copy()
        vertex.co = function(old.copy(), vertex.index)
        distance = (vertex.co - old).length
        maximum = max(maximum, distance)
        moved += distance > 1e-7
    obj.data.update()
    return {"moved_vertices": moved, "maximum_local_displacement_m": maximum}


def atlas_uv(u, v, tile):
    return ((tile % 4) * .25 + .006 + .238 * u, (tile // 4) * .5 + .006 + .488 * v)


def patch_mesh(name, vertices, faces, uvs, material, rig, bone):
    """Only the replacement shell/wing/plate patches use new topology."""
    if bone not in rig.data.bones:
        raise ValueError(f"Missing patch attachment bone: {bone}")
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    uv = mesh.uv_layers.new(name="UVMap")
    for face in mesh.polygons:
        for loop in face.loop_indices:
            uv.data[loop].uv = uvs[mesh.loops[loop].vertex_index]
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(material)
    obj.parent = rig
    obj.matrix_world = rig.matrix_world.copy()
    modifier = obj.modifiers.new("Retained rig attachment", "ARMATURE")
    modifier.object = rig
    obj.vertex_groups.new(name=bone).add(list(range(len(vertices))), 1, "REPLACE")
    obj["authored_change"] = "Purpose-specific patch; retained rig, not a regenerated body"
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    return obj


def shield(name, center, width, length, height, tile, material, rig, bone="Body", wedge=False):
    """Closed radial shield with a beveled rim; not an anatomical body primitive."""
    vertices, faces, uvs = [], [], []
    count = 32
    for ring, (radius, elevation) in enumerate(((1, 0), (1, .12), (.94, .28), (.70, .78), (.28, 1))):
        for j in range(count):
            a = math.tau * j / count
            x, y = width * radius * math.cos(a), length * radius * math.sin(a)
            z = height * elevation
            if wedge:
                z *= .70 + .30 * (y / length + 1) / 2
                z -= height * .07 * math.exp(-(x / (width * .045)) ** 2)
            else:
                z += height * .045 * math.cos(a * 7 + ring * .8) * radius
            vertices.append(tuple(Vector(center) + Vector((x, y, z))))
            uvs.append(atlas_uv(.5 + x / width * .47, .5 + y / length * .47, tile))
            if ring:
                k = ring * count + j
                q = ring * count + (j + 1) % count
                faces.append((k - count, q - count, q, k))
    top = len(vertices)
    vertices.append(tuple(Vector(center) + Vector((0, 0, height))))
    uvs.append(atlas_uv(.5, .5, tile))
    for j in range(count):
        faces.append((4 * count + j, 4 * count + (j + 1) % count, top))
    faces.append(tuple(reversed(range(count))))
    return patch_mesh(name, vertices, faces, uvs, material, rig, bone)


def wing_patch(name, root, tip, width, material, rig, bone):
    # A thin closed, cambered wing with raised longitudinal veins in its grid.
    root, tip = Vector(root), Vector(tip)
    lateral = (tip - root).cross(Vector((0, 0, 1))).normalized()
    vertices, faces, uvs = [], [], []
    rows, cols = 16, 12
    layer_count = (rows + 1) * (cols + 1)
    for bottom in (False, True):
        for row in range(rows + 1):
            t = row / rows
            for col in range(cols + 1):
                u = col / cols * 2 - 1
                edge = math.sin(math.pi * (.025 + .95 * t)) ** .65
                scallop = 1 - .06 * math.cos(t * math.tau * 4) * abs(u) ** 5
                p = root.lerp(tip, t) + lateral * width * edge * u * scallop
                p.z += .085 * math.sin(math.pi * t) * (1 - u * u)
                p.z += .009 * max(0, math.cos(u * math.pi * 3)) ** 12 * math.sin(math.pi * t)
                p.z += -.003 if bottom else .003
                vertices.append(tuple(p))
                uvs.append(atlas_uv(col / cols, t, 6))
                if row and col:
                    k = len(vertices) - 1
                    f = (k - cols - 2, k - cols - 1, k, k - 1)
                    faces.append(tuple(reversed(f)) if bottom else f)
    perimeter = (list(range(cols + 1)) + [r * (cols + 1) + cols for r in range(1, rows + 1)]
                 + [rows * (cols + 1) + c for c in range(cols - 1, -1, -1)]
                 + [r * (cols + 1) for r in range(rows - 1, 0, -1)])
    for a, b in zip(perimeter, perimeter[1:] + perimeter[:1]):
        faces.append((a, a + layer_count, b + layer_count, b))
    return patch_mesh(name, vertices, faces, uvs, material, rig, bone)


def extrude_sacs(obj, rig):
    """Extrude actual dorsal faces so each bellows shares the retained body."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    layer = bm.verts.layers.deform.verify()
    uv = bm.loops.layers.uv.active
    if uv is None:
        raise ValueError("Sac extrusion requires retained UVs")
    for index, x in enumerate((-.27, 0, .27)):
        name = "AirSac" + str(index)
        group = obj.vertex_groups.get(name)
        if group is None or name not in rig.data.bones:
            raise ValueError(f"Missing retained sac control: {name}")
        faces = [f for f in bm.faces if f.normal.z > .45 and f.calc_center_median().z > .49
                 and ((f.calc_center_median().x - x) / .115) ** 2
                 + ((f.calc_center_median().y - .23) / .14) ** 2 < 1
                 and int(f.loops[0][uv].uv.x * 4) == 0 and f.loops[0][uv].uv.y < .5]
        if not faces:
            bm.free()
            raise ValueError(f"No connected dorsal patch for {name}; source requires manual revision")
        center = sum((f.calc_center_median() for f in faces), Vector()) / len(faces)
        old_faces = faces
        for step, (spread, rise) in enumerate(((1.05, .075), (1.12, .075), (.80, .08), (.40, .045))):
            old_vertices = {v for face in old_faces for v in face.verts}
            result = bmesh.ops.extrude_face_region(bm, geom=old_faces)
            new = [v for v in result["geom"] if isinstance(v, bmesh.types.BMVert)]
            # Remove the old cap, but retain its boundary to the body/wall.
            bmesh.ops.delete(bm, geom=old_faces, context="FACES_ONLY")
            new_set = set(new)
            old_faces = [f for f in bm.faces if all(v in new_set for v in f.verts)]
            for v in new:
                v.co.x = center.x + (v.co.x - center.x) * spread
                v.co.y = center.y + (v.co.y - center.y) * spread
                v.co.z += rise * (1.15 if index == 1 else 1)
                v[layer].clear()
                v[layer][group.index] = .75 if step == 0 else 1
                if step == 0:
                    v[layer][obj.vertex_groups["Body"].index] = .25
            for v in old_vertices:
                for f in v.link_faces:
                    for loop in f.loops:
                        if loop.vert in new_set:
                            loop[uv].uv = atlas_uv((loop.vert.co.x - x + .18) / .36,
                                                  (loop.vert.co.y - .23 + .22) / .44, 6)
            for f in old_faces:
                for loop in f.loops:
                    loop[uv].uv = atlas_uv((loop.vert.co.x - x + .18) / .36,
                                          (loop.vert.co.y - .23 + .22) / .44, 6)
        bm.normal_update()
    wire = [e for e in bm.edges if e.is_wire]
    if wire:
        bmesh.ops.delete(bm, geom=wire, context="EDGES")
    loose = [v for v in bm.verts if not v.link_edges]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    if obj.data.shape_keys is None:
        obj.shape_key_add(name="Basis")
    for index, x in enumerate((-.27, 0, .27)):
        key = obj.shape_key_add(name=f"Sac{index}_Inflate")
        key.slider_min, key.slider_max, key.value = 0, 1, 0
        group_index = obj.vertex_groups["AirSac" + str(index)].index
        for vertex in obj.data.vertices:
            weight = sum(g.weight for g in vertex.groups if g.group == group_index)
            if weight:
                p = key.data[vertex.index].co
                p.z += .20 * weight
                p.x = x + (p.x - x) * (1 + .12 * weight)
                p.y = .23 + (p.y - .23) * (1 + .12 * weight)


def author(asset, meshes, rig, material, membrane):
    primary = max(meshes, key=lambda obj: len(obj.data.vertices))
    extra, operations = [], []
    if asset == "M08":
        bounds = world_bounds(meshes)
        height = bounds[1].z - bounds[0].z
        for obj in meshes:
            material_by_vertex = {}
            for f in obj.data.polygons:
                for i in f.vertices:
                    material_by_vertex.setdefault(i, obj.data.materials[f.material_index].name)
            to_world, to_local = obj.matrix_world.copy(), obj.matrix_world.inverted()

            def stag(p, i):
                world = to_world @ p
                z = (world.z - bounds[0].z) / height
                region = material_by_vertex.get(i, "")
                if "Antler" in region:
                    world.x *= 1.12 + .025 * math.sin(world.z * 5)
                    world.z += .025 * height * abs(world.x) / max(height, 1e-6)
                elif "Coat" in region or "Throat" in region:
                    chest = math.exp(-((z - .43) / .13) ** 2)
                    world.x *= 1 + .10 * chest
                    world.z -= .012 * height * math.exp(-((z - .33) / .08) ** 2)
                return to_local @ world
            operations.append(deform(obj, stag))
        return extra, operations

    tiles = tile_indices(primary)
    if asset == "M13":
        removed = remove_islands(primary, lambda c: c["tile"] == 4 and len(c["ids"]) < 100)
        operations.append({"removed_mineral_insert_vertices": removed})
        def reptile(p, i):
            front = math.exp(-((p.y + .55) / .23) ** 2)
            p.x *= 1 + .16 * front
            p.z = .40 + (p.z - .40) * (1 - .20 * front)
            return p
        operations.append(deform(primary, reptile))
        for row in range(6):
            for side in (-1, 1):
                y = -.35 + row * .19
                extra.append(shield(f"M13_OverlappingShield_{row}_{side}",
                                    (side * (.16 - row * .012), y, .67 - row * .013),
                                    .20 - row * .015, .18 - row * .012, .085 - row * .007,
                                    4, material, rig, "Body"))
        for row in range(4):
            extra.append(shield(f"M13_TailShield_{row}", (0, .90 + row * .23, .43 - row * .073),
                                .14 - row * .026, .17 - row * .023, .045, 4, material, rig,
                                "Tail_" + str(min(2, row))))
    elif asset == "M07":
        wing = {i for part in components(primary) if part["span"].x > .6
                and all(tiles.get(j) == 6 for j in part["ids"]) for i in part["ids"]}
        if not wing:
            raise ValueError("Retained drake wing islands no longer match the v1 atlas; revise this recipe explicitly")
        def drake(p, i):
            if i in wing:
                p.z -= .12 * math.sin(min(1, abs(p.x) / 4.25) * math.pi) * (.6 + .4 * math.sin(p.y * 4))
            else:
                head = math.exp(-((p.z - 3.98) / .24) ** 2 - ((p.y + 1.03) / .43) ** 2)
                p.x *= 1 + .14 * head
                p.z -= .055 * head * max(0, (-p.y - 1.08) / .4)
                p.y -= .06 * math.exp(-((p.z - 2.4) / .55) ** 2) * max(0, 1 - abs(p.x) / .5)
            return p
        operations.append(deform(primary, drake))
        for index in sorted(wing):
            p = primary.data.vertices[index].co
            side = -1 if p.x < 0 else 1
            bones = [b for b in rig.data.bones if b.name.startswith(f"WingFinger{side}_")]
            if len(bones) != 4:
                raise ValueError("Expected four existing wing fingers on each drake wing")
            nearest = sorted(bones, key=lambda b: segment_distance(p, b.head_local, b.tail_local))[:2]
            weights = [1 / max(.04, segment_distance(p, b.head_local, b.tail_local)) ** 2 for b in nearest]
            set_weights(primary, index, {b.name: w / sum(weights) for b, w in zip(nearest, weights)}, rig)
        operations.append({"membrane_vertices_reweighted_to_existing_fingers": len(wing)})
    elif asset == "M11":
        operations.append({"removed_wing_vertices": remove_islands(primary, lambda c: c["bone"].startswith(("ForeWing", "HindWing")))})
        for side in (-1, 1):
            for rear in (False, True):
                bone = ("HindWing" if rear else "ForeWing") + str(side)
                extra.append(wing_patch("M11_Cambered_" + bone,
                                        (side * .12, .10 if rear else -.04, .59),
                                        (side * (.86 if rear else 1.04), .63 if rear else -.49, .79 if rear else 1.12),
                                        .28 if rear else .33, membrane, rig, bone))
        operations.append(deform(primary, lambda p, i: Vector((p.x * (1.06 if p.y < .1 else 1), p.y, p.z))))
    elif asset == "M09":
        def burrower(p, i):
            head = math.exp(-((p.y + 1.35) / .30) ** 2)
            p.x *= 1 + .28 * head
            p.z = .22 + (p.z - .22) * (.82 - .18 * head)
            p.z = max(.025, p.z)
            p.y += .018 * math.sin(p.y * 12) * (1 - head)
            return p
        operations.append(deform(primary, burrower))
        for side in (-1, 1):
            extra.append(shield(f"M09_LateralJaw_{side}", (side * .28, -1.41, .20),
                                .12, .22, .07, 1, material, rig, "Jaw", True))
    elif asset == "M10":
        removed = remove_islands(primary, lambda c: (c["tile"] == 4 and c["span"].x > 1)
                                 or (c["tile"] == 1 and c["span"].x > .7))
        operations.append({"removed_shell_ridge_vertices": removed})
        def crab(p, i):
            p.z *= .83
            if p.y < -.75:
                p.y = -.75 + (p.y + .75) * .72
            return p
        operations.append(deform(primary, crab))
        extra.append(shield("M10_SteppedCarapace", (0, .06, .48), .69, .76, .29, 4, material, rig))
    elif asset == "M12":
        def leech(p, i):
            front = max(0, min(1, (-p.y - .62) / .15))
            back = max(0, min(1, (p.y - .72) / .18))
            p.x *= 1 - .10 * back + .09 * front
            p.z = .20 + (p.z - .20) * (.72 + .14 * front)
            p.z = max(.018, p.z)
            if tiles.get(i) == 1 and p.y < -.65:
                p.y += .035
            p.y += .010 * math.sin(p.y * 17) * (1 - front) * (1 - back)
            return p
        operations.append(deform(primary, leech))
    elif asset == "M14":
        def spider(p, i):
            abdomen = max(0, min(1, (p.y + .02) / .7)) if abs(p.x) < .46 else 0
            p.x *= 1 + .20 * abdomen
            p.z -= .08 * (1 - abdomen) * max(0, 1 - abs(p.x) / .35)
            if abs(p.x) > .45 and p.z > .45:
                p.z += .075 * math.sin(min(1, abs(p.x) / 1.2) * math.pi)
            if p.y < -.67 and p.z < .4:
                p.y = -.67 + (p.y + .67) * .65
            return p
        operations.append(deform(primary, spider))
    elif asset == "M15":
        operations.append({"removed_detached_sac_vertices": remove_islands(primary, lambda c: c["bone"].startswith("AirSac"))})
        extrude_sacs(primary, rig)
        operations.append({"connected_dorsal_bellows": 3, "bounded_inflation_shape_keys": 3})
    elif asset == "M16":
        operations.append({"removed_elytron_vertices": remove_islands(primary, lambda c: c["tile"] == 4 and c["span"].x > .3)})
        operations.append(deform(primary, lambda p, i: Vector((p.x, p.y, p.z * .88))))
        extra.append(shield("M16_ContinuousWedgeShield", (0, .08, .23), .245, .405, .15,
                            4, material, rig, "Body", True))
    elif asset == "M17":
        operations.append({"removed_accretion_margin_vertices": remove_islands(primary, lambda c:
                           c["tile"] == 1 and len(c["ids"]) < 100 and c["center"].y > -1.2)})
        def mollusc(p, i):
            if tiles.get(i) == 4:
                p.x *= 1.03 + .04 * math.floor((p.z - .5) / .16) / 8
                shelf = ((p.z - .55) / .19) % 1
                p.x += math.copysign(.045 * math.sin(math.pi * shelf) ** 4
                                     * min(1, abs(p.x) / .28), p.x)
                p.z += .025 * math.sin(math.atan2(p.z - 1.02, p.y - .28) * 17)
            elif p.z < .45 and p.y > -1.1:
                p.x *= 1.09
                p.z = max(.015, p.z * .78)
            return p
        # Deletion compacts vertex indices: recompute before region-based sculpt.
        tiles = tile_indices(primary)
        operations.append(deform(primary, mollusc))
    elif asset == "M18":
        disc = {i for part in components(primary) if len(part["ids"]) > 1000 for i in part["ids"]}
        def ray(p, i):
            if i in disc:
                t = max(0, min(1, (p.y + .94) / 1.92))
                old = math.sin(math.pi * t) ** .85
                new = max(0, 1 - abs(2 * t - 1)) ** .82
                p.x *= new / old if old > 1e-6 else 1
                p.z += .045 * (1 - min(1, abs(p.x) / 1.4)) ** 2 * math.sin(math.pi * t)
            return p
        operations.append(deform(primary, ray))
        uv = primary.data.uv_layers.active
        for face in primary.data.polygons:
            if all(i in disc for i in face.vertices) and face.normal.z < -.3:
                for loop in face.loop_indices:
                    u, v = uv.data[loop].uv
                    uv.data[loop].uv = atlas_uv((u % .25 - .004) / .242, (v % .5 - .004) / .492, 1)
        bm = bmesh.new()
        bm.from_mesh(primary.data)
        bm.verts.ensure_lookup_table()
        boundary = [bm.verts[i] for i in disc if bm.verts[i].is_boundary]
        before = len(bm.verts)
        bmesh.ops.remove_doubles(bm, verts=boundary, dist=.0001)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(primary.data)
        operations.append({"welded_disc_boundary_vertices": before - len(bm.verts)})
        bm.free()
        for vertex in primary.data.vertices:
            p = vertex.co
            if abs(p.x) > .25 and -.95 <= p.y <= .99:
                side = -1 if p.x < 0 else 1
                position = max(0, min(2, abs(p.x) / .45 - .5))
                lo, hi = int(position), min(2, int(position) + 1)
                t = position - lo
                weights = {f"Fin{side}_{lo}": 1 - t}
                weights[f"Fin{side}_{hi}"] = weights.get(f"Fin{side}_{hi}", 0) + t
                set_weights(primary, vertex.index, weights, rig)
    else:
        raise ValueError(asset)
    return extra, operations


def segment_distance(point, a, b):
    line = b - a
    t = max(0, min(1, (point - a).dot(line) / max(line.length_squared, 1e-10)))
    return (point - a - t * line).length


def set_weights(obj, index, weights, rig):
    for group in obj.vertex_groups:
        group.remove([index])
    for name, weight in weights.items():
        if name not in rig.data.bones:
            raise ValueError(f"Missing retained deform bone: {name}")
        group = obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
        if weight > 1e-6:
            group.add([index], weight, "REPLACE")


def world_bounds(meshes):
    points = [obj.matrix_world @ v.co for obj in meshes for v in obj.data.vertices]
    return (Vector(tuple(min(p[i] for p in points) for i in range(3))),
            Vector(tuple(max(p[i] for p in points) for i in range(3))))


def metrics(meshes):
    result = []
    for obj in meshes:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        result.append({"name": obj.name, "vertices": len(obj.data.vertices),
                       "triangles": sum(len(p.vertices) - 2 for p in obj.data.polygons),
                       "connected_components": len(components(obj)),
                       "boundary_edges": sum(e.is_boundary for e in bm.edges),
                       "nonmanifold_edges": sum(not e.is_manifold for e in bm.edges),
                       "geometry_sha256": hashlib.sha256(b"".join(
                           struct.pack("<3f", *v.co) for v in obj.data.vertices) + b"".join(
                           struct.pack("<I", i) for f in obj.data.polygons for i in f.vertices)).hexdigest()})
        bm.free()
    low, high = world_bounds(meshes)
    return {"meshes": result, "bounds_min_m": list(low), "bounds_max_m": list(high),
            "dimensions_m": list(high - low), "triangles": sum(r["triangles"] for r in result)}


def bone_signature(rig):
    record = [(b.name, b.parent.name if b.parent else None, list(b.head_local), list(b.tail_local),
               [list(row) for row in b.matrix_local], b.use_deform) for b in rig.data.bones]
    return hashlib.sha256(json.dumps(record, sort_keys=True).encode()).hexdigest()


def action_curves(action):
    if hasattr(action, "fcurves"):
        return list(action.fcurves)
    curves = []
    for layer in action.layers:
        for strip in layer.strips:
            for slot in action.slots:
                bag = strip.channelbag(slot)
                if bag:
                    curves.extend(bag.fcurves)
    return curves


def action_signature(action):
    record = [(c.data_path, c.array_index, [(list(k.co), k.interpolation,
               list(k.handle_left), list(k.handle_right)) for k in c.keyframe_points]) for c in action_curves(action)]
    return hashlib.sha256(json.dumps(record, sort_keys=True).encode()).hexdigest()


def load_source(asset):
    source = source_for(asset)
    if asset == "M08":
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(source))
    else:
        bpy.ops.wm.open_mainfile(filepath=str(source))
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if len(rigs) != 1:
        raise ValueError(f"Expected one retained skeleton, found {len(rigs)}")
    rig = rigs[0]
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"
              and (asset == 'M08' or any(m.type == "ARMATURE" and m.object == rig for m in obj.modifiers))]
    if asset == 'M08':
        # Native antlers are rigid Head children, not Armature-modified skin.
        # Keep and bind them instead of silently dropping a defining body part.
        for obj in meshes:
            if not any(m.type == 'ARMATURE' for m in obj.modifiers):
                world = obj.matrix_world.copy()
                for vertex in obj.data.vertices:
                    vertex.co = rig.matrix_world.inverted() @ world @ vertex.co
                obj.parent_type = 'OBJECT'
                obj.parent = rig
                obj.matrix_parent_inverse = Matrix.Identity(4)
                obj.matrix_basis = Matrix.Identity(4)
                obj.vertex_groups.clear()
                obj.vertex_groups.new(name='Head').add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
                obj.modifiers.new('NativeAntlerHeadBinding', 'ARMATURE').object = rig
                if not obj.data.materials:
                    # The glTF node is Stag_Horns, but Blender names this mesh
                    # Cube.001. This source's sole rigid component is antlers.
                    obj.data.materials.append(bpy.data.materials.get('HartAntler') or bpy.data.materials.new('HartAntler'))
    if not meshes:
        raise ValueError("Source has no meshes skinned to its native rig")
    keep = set(meshes + [rig])
    for obj in list(keep):
        parent = obj.parent
        while parent:
            keep.add(parent)
            parent = parent.parent
    for obj in list(bpy.context.scene.objects):
        if obj not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)
    if rig.animation_data:
        rig.animation_data.action = None
        for track in rig.animation_data.nla_tracks:
            track.mute = True
    for bone in rig.pose.bones:
        bone.matrix_basis.identity()
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    return rig, meshes


def prepare_atlas(asset, meshes, directory):
    image = next((i for i in bpy.data.images if i.name == asset + "_basecolor"), None)
    if image is None:
        path = V1 / "exports" / asset / f"{asset}_basecolor.png"
        if not path.is_file():
            raise FileNotFoundError(f"Required existing atlas: {path}")
        image = bpy.data.images.load(str(path), check_existing=False)
    # Blender file images decode lazily; inspect actual pixels before declaring
    # a newly loaded, valid atlas missing.
    if len(image.pixels):
        _ = image.pixels[0]
    if not image.has_data or min(image.size) < 32:
        raise ValueError("Missing/invalid base-color atlas; white fallback is forbidden")
    path = directory / f"{asset}_basecolor.png"
    image.filepath_raw, image.file_format = str(path), "PNG"
    image.save()
    image.pack()
    mat = bpy.data.materials.new(asset + "_RecoveryAtlas")
    mat.use_nodes = True
    mat.diffuse_color = (.4, .4, .4, 1)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = .78
    bsdf.inputs["Metallic"].default_value = 0
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = image
    node.interpolation = "Linear"
    mat.node_tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
    mat.node_tree.nodes.active = node
    membrane = mat.copy()
    membrane.name = asset + "_BoundedWingMembrane"
    membrane.use_backface_culling = False
    membrane.node_tree.nodes.get("Principled BSDF").inputs["Alpha"].default_value = .56
    membrane.surface_render_method = "DITHERED"
    return mat, membrane, path


def apply_atlas(asset, meshes, material):
    for obj in meshes:
        if asset == "M08":
            layer = obj.data.uv_layers.active or obj.data.uv_layers.new(name="UVMap")
            native_tiles = {"HartCoat": 0, "HartHoof": 3, "HartThroat": 6, "HartAntler": 1, "HartEye": 3}
            points = [v.co for v in obj.data.vertices]
            lo = [min(p[i] for p in points) for i in range(3)]
            span = [max(p[i] for p in points) - lo[i] for i in range(3)]
            for face in obj.data.polygons:
                name = obj.data.materials[face.material_index].name
                if name not in native_tiles:
                    raise ValueError(f"Unknown native stag material: {name}")
                axes = [i for i in range(3) if i != max(range(3), key=lambda k: abs(face.normal[k]))]
                for loop in face.loop_indices:
                    p = obj.data.vertices[obj.data.loops[loop].vertex_index].co
                    u, v = ((p[i] - lo[i]) / max(span[i], 1e-6) for i in axes)
                    layer.data[loop].uv = atlas_uv(u, v, native_tiles[name])
        elif obj.data.uv_layers.active is None:
            raise ValueError(f"Missing retained UVs: {obj.name}")
        obj.data.materials.clear()
        obj.data.materials.append(material)
        for face in obj.data.polygons:
            face.material_index = 0


def normalize_stag(meshes, rig):
    # Preserve native rest matrices, skin weights and animation channels by
    # orienting/scaling their common parent, not by applying mesh-only transforms.
    root = bpy.data.objects.new("M08_AuthoringRoot", None)
    bpy.context.collection.objects.link(root)
    for obj in list(bpy.context.scene.objects):
        if obj != root and obj.parent is None:
            obj.parent = root
    head = rig.matrix_world @ rig.data.bones["Head"].head_local
    body = rig.matrix_world @ rig.data.bones["Body"].head_local
    forward = head - body
    if forward.xy.length < 1e-5:
        raise ValueError("Cannot infer native stag facing from Head/Body")
    root.rotation_euler.z = -math.pi / 2 - math.atan2(forward.y, forward.x)
    bpy.context.view_layer.update()
    low, high = world_bounds(meshes)
    root.scale = (3.6 / (high.z - low.z),) * 3
    bpy.context.view_layer.update()
    low, high = world_bounds(meshes)
    root.location = (-(low.x + high.x) / 2, -(low.y + high.y) / 2, -low.z)
    bpy.context.view_layer.update()


def render_views(meshes, directory):
    scene = bpy.context.scene
    scene.render.stamp_note_text = directory.parent.name + ' | PRIVATE CANDIDATE | NOT ACCEPTED'
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "TEXTURE"
    shading.background_type = "WORLD"
    scene.world = scene.world or bpy.data.worlds.new("Neutral review world")
    scene.world.color = (.18, .18, .18)
    shading.show_shadows = True
    shading.show_cavity = True
    shading.cavity_type = "WORLD"
    shading.show_specular_highlight = False
    low, high = world_bounds(meshes)
    center, span = (low + high) / 2, max(high - low)
    bpy.ops.object.camera_add(location=center + Vector((0, -span * 3, span * .18)))
    camera = bpy.context.object
    camera.name = "REVIEW_Workbench_Camera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = span * 1.30
    scene.camera = camera
    files = []
    for name, direction in (("front", (0, -1, .07)), ("side", (1, 0, .07)),
                            ("rear", (0, 1, .07)), ("quarter", (.75, -1, .40))):
        camera.location = center + Vector(direction).normalized() * span * 3
        camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
        rotation = camera.rotation_euler.to_matrix()
        right, up = rotation @ Vector((1, 0, 0)), rotation @ Vector((0, 1, 0))
        points = [obj.matrix_world @ v.co - center for obj in meshes for v in obj.data.vertices]
        camera.data.ortho_scale = 1.15 * max(max(p.dot(axis) for p in points)
                                           - min(p.dot(axis) for p in points) for axis in (right, up))
        path = directory / (name + ".png")
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        files.append({"view": name, "path": str(path), "sha256": digest(path),
                      "renderer": "Blender Workbench / studio texture color; opaque, not PBR or Godot"})
    return files


def inspect_glb(path):
    with path.open("rb") as stream:
        magic, version, size, length, kind = struct.unpack("<4s4I", stream.read(20))
        if magic != b"glTF" or version != 2 or size != path.stat().st_size or kind != 0x4E4F534A:
            raise ValueError("Invalid candidate GLB header")
        doc = json.loads(stream.read(length))
    materials = doc.get("materials", [])
    for mesh in doc.get("meshes", []):
        for primitive in mesh["primitives"]:
            index = primitive.get("material")
            if index is None or "baseColorTexture" not in materials[index].get("pbrMetallicRoughness", {}):
                raise ValueError("Exported surface is missing a base-color texture")
            if "TEXCOORD_0" not in primitive["attributes"]:
                raise ValueError("Exported surface is missing UVs")
    for image in doc.get("images", []):
        if "bufferView" not in image and not image.get("uri", "").startswith("data:"):
            raise ValueError("GLB must embed all runtime texture images")
    if not doc.get("meshes") or not doc.get("skins"):
        raise ValueError("Candidate lost its skinned mesh")
    names = [a.get("name", "") for a in doc.get("animations", [])]
    missing = set(COMMON) - set(names)
    if missing:
        raise ValueError(f"Export lost required common clips: {sorted(missing)}; no success receipt written")
    return {"animations": names, "skins": len(doc["skins"]), "materials": len(materials),
            "embedded_images": len(doc.get("images", [])), "all_surfaces_basecolor_textured": True}


def run(args):
    asset, revision = args.asset, args.revision
    stem = f"{asset}_{NAMES[asset]}_stylized_{revision}"
    blend = RECOVERY / "models" / (stem + ".blend")
    review = GAME / "art_review/stylized" / asset / revision
    evidence = RECOVERY / "evidence/stylized" / asset / revision
    source = source_for(asset)
    dossier = next((V1 / "AshenOath_Asset_Pack/docs/dossiers").glob(asset + "_*.md"))
    license_path = GAME / ("assets_external/licenses/Quaternius_Ultimate_Animals_CC0.txt" if asset == "M08"
                           else "assets_external/design_pack_v1/PROVENANCE.md")
    if not source.is_file() or not license_path.is_file():
        raise FileNotFoundError(f"Required source/provenance is missing: {source}, {license_path}")
    for path in (blend, review, evidence):
        if path.exists():
            raise FileExistsError(f"Preserve existing candidate: {path}; choose a new --revision")
    inputs = {str(p): digest(p) for p in (source, dossier, license_path, Path(__file__))}
    if asset == "M08":
        atlas_source = V1 / "exports/M08/M08_basecolor.png"
        inputs[str(atlas_source)] = digest(atlas_source)
    rig, meshes = load_source(asset)
    before = metrics(meshes)
    skeleton_hash = bone_signature(rig)
    originals = {a.name: action_signature(a) for a in bpy.data.actions}
    if not originals:
        raise ValueError("Native source has no retained actions")
    aliases = {}
    if asset == "M08":
        normalize_stag(meshes, rig)
        for alias, native in STAG_ALIASES.items():
            # glTF import may suffix action names with the target object. NLA
            # track names retain the original glTF animation identity.
            matches = []
            if rig.animation_data:
                matches = list({s.action for t in rig.animation_data.nla_tracks if t.name == native
                                for s in t.strips if s.action is not None})
            if not matches:
                matches = [a for a in bpy.data.actions if a.name == native]
            if not matches:
                matches = [a for a in bpy.data.actions if a.name.startswith(native + "_")]
            if len(matches) != 1:
                raise ValueError(f"Native stag clip must resolve uniquely: {native}")
            if alias not in bpy.data.actions:
                action = matches[0].copy()
                action.name = alias
                action.use_fake_user = True
            aliases[alias] = matches[0].name
    for name in COMMON:
        if name not in bpy.data.actions:
            raise ValueError(f"Required native/common clip absent: {name}")
    review.mkdir(parents=True, exist_ok=False)
    evidence.mkdir(parents=True, exist_ok=False)
    blend.parent.mkdir(parents=True, exist_ok=True)
    material, membrane, texture = prepare_atlas(asset, meshes, review)
    extra, operations = author(asset, meshes, rig, material, membrane)
    apply_atlas(asset, meshes, material)
    meshes.extend(extra)
    after = metrics(meshes)
    if not any(r["geometry_sha256"] not in {b["geometry_sha256"] for b in before["meshes"]} for r in after["meshes"]):
        raise ValueError("No structural geometry change; recolor-only candidates are forbidden")
    if bone_signature(rig) != skeleton_hash:
        raise ValueError("Native rest skeleton was unexpectedly modified")
    for name, expected in originals.items():
        if name not in bpy.data.actions or action_signature(bpy.data.actions[name]) != expected:
            raise ValueError(f"Retained native action changed: {name}")
    for action in bpy.data.actions:
        action.use_fake_user = True
    rig["asset_design_id"] = asset
    rig["art_status"] = "GROUNDED_STYLIZED_CANDIDATE_AWAITING_USER"
    rig["production_policy"] = "Private best-effort derivative; user acceptance final; no production replacement"
    # Keep the individually editable source parts. Only disposable export
    # copies are consolidated; never spend a draw surface on each shell plate.
    copies = []
    for original in meshes:
        copy = original.copy()
        copy.data = original.data.copy()
        bpy.context.collection.objects.link(copy)
        copies.append(copy)
    bpy.ops.object.select_all(action='DESELECT')
    for copy in copies:
        copy.select_set(True)
    bpy.context.view_layer.objects.active = copies[0]
    if len(copies) > 1:
        bpy.ops.object.join()
    compiled = bpy.context.object
    compiled.name = asset + '_RuntimeAssembly'
    triangles = sum(len(f.vertices)-2 for f in compiled.data.polygons)
    target = 34000 if asset in {'M07','M08','M17'} else 20000
    if triangles > target and not compiled.data.shape_keys:
        modifier = compiled.modifiers.new('PreserveUVRuntimeBudget', 'DECIMATE')
        modifier.ratio = target / triangles
        modifier.delimit = {'UV', 'MATERIAL', 'SEAM'}
        bpy.ops.object.modifier_move_to_index(modifier=modifier.name, index=0)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for obj in [compiled]:
        obj.select_set(True)
        if not obj.data.uv_layers.active:
            raise ValueError(f"Untextured surface UVs: {obj.name}")
    # Include ancestor transforms so the native stag's orientation/scale survives export.
    for obj in list(bpy.context.selected_objects):
        parent = obj.parent
        while parent:
            parent.select_set(True)
            parent = parent.parent
    bpy.context.view_layer.objects.active = rig
    glb = review / (stem + ".glb")
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS",
                              export_force_sampling=True, export_skins=True, export_yup=True,
                              export_all_influences=False, export_extras=True)
    exported = inspect_glb(glb)
    bpy.data.objects.remove(compiled, do_unlink=True)
    views = render_views(meshes, evidence)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), compress=True)
    for path, expected in inputs.items():
        if digest(path) != expected:
            raise ValueError(f"Input changed during authoring: {path}; no success receipt written")
    record = {"id": asset, "revision": revision, "status": "candidate_exported_awaiting_user",
              "art_target": "grounded_stylized_best_effort", "private_review_only": True,
              "user_accepted": False, "integrated": False, "gameplay_tested": False,
              "motion_reviewed": False, "godot_run": False, "production_files_changed": False,
              "source_path": str(blend), "runtime_path": str(glb),
              "destination_resource": f"res://assets_external/design_pack_v1/creatures/{asset}_{NAMES[asset]}.glb",
              "inputs_sha256": inputs, "source": {"bytes": blend.stat().st_size, "sha256": digest(blend)},
              "runtime": {"bytes": glb.stat().st_size, "sha256": digest(glb)},
              "textures": [{"source_path": str(texture), "bytes": texture.stat().st_size,
                            "sha256": digest(texture), "embedded_in_glb": True,
                            "origin": "retained v1 basecolor atlas; new patch UVs use its existing regions"}],
              "recipe": RECIPES[asset], "structural_operations": operations,
              "metrics_before": before, "metrics_after": after, "export_metrics": exported,
              "native_skeleton_sha256": skeleton_hash, "retained_action_sha256": originals,
              "clip_aliases": aliases, "views": views, "blender_version": bpy.app.version_string,
              "renderer": "BLENDER_WORKBENCH; STUDIO light, TEXTURE color, opaque preview",
              "limitations": [LIMITATIONS[asset], "Existing action channels preserved; no new species-specific clips, runtime integration, gameplay or user acceptance established.",
                              "Existing atlas reused, not a new painted PBR set. Normal/ORM maps are not exported by this revision.",
                              "Rest bounds and topology metrics are measurements, not anatomical or visual acceptance."]}
    receipt = review / "candidate.json"
    with receipt.open("x", encoding="utf-8") as stream:
        json.dump(record, stream, indent=2)
        stream.write("\n")
    print("WILDLIFE_CANDIDATE=" + str(receipt), flush=True)


def main(argv=None):
    args = parse_args(argv)
    if args.describe:
        print(json.dumps({"id": args.asset, "source": str(source_for(args.asset)),
                          "recipe": RECIPES[args.asset], "limitations": LIMITATIONS[args.asset],
                          "execution": "one --asset only; run after biped/human work; no outputs written"}, indent=2))
        return 0
    global bpy, bmesh, Vector, Matrix
    try:
        import bpy
        import bmesh
        from mathutils import Vector, Matrix
    except ImportError as error:
        raise SystemExit("Run this file with Blender --background --factory-startup --python ... -- --asset ID; ordinary Python supports --describe only") from error
    try:
        run(args)
    except Exception:
        print("WILDLIFE_FAILED: any partial new output is unapproved; preserve it and choose a new revision. No global ledger updated.", file=sys.stderr)
        raise
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]))
