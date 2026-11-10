"""Replace one retained creature's four ambient actions in Blender 5.2.

All other action F-curves remain byte-equal inside Blender. The derivative is
isolated: production is never overwritten, and attack calibration is always
required after export. Morph channels share their action with the native rig.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
from urllib.parse import unquote, urlsplit

import bpy
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from living_creature_motion_profiles import REPLACED_CLIPS, SPECIES, channels
from graft_creature_ambient import graft
from living_creature_preview import render_views

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "models/living_assets_stage3_20261107/creatures"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def snapshot_recipe():
    names = ("author_living_creature_motion.py", "living_creature_motion_profiles.py",
             "preserve_creature_action_bytes.py", "graft_creature_ambient.py", "verify_living_creature_motion.py", "living_creature_preview.py")
    source = Path(__file__).resolve().parent
    hashes = {name: sha(source/name) for name in names}
    identity = hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest()
    folder = OUT.parent/"recipes"/identity[:16]
    folder.mkdir(parents=True, exist_ok=True)
    for name in names:
        destination = folder/name
        if destination.exists() and sha(destination) != hashes[name]:
            raise ValueError("Creature recipe snapshot collision")
        if not destination.exists():
            destination.write_bytes((source/name).read_bytes())
    return {"sha256": identity, "directory": str(folder.relative_to(ROOT)), "files": hashes}


def glb_contract(path):
    raw = path.read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20+length])
    result = {}
    for animation in doc.get("animations", []):
        result[animation["name"]] = max(float(doc["accessors"][s["input"]]["max"][0]) for s in animation["samplers"])
    return result


def retain_external_inputs(source, folder):
    raw = source.read_bytes()
    size = struct.unpack_from('<I',raw,12)[0]
    document = json.loads(raw[20:20+size])
    records = []
    for item in document.get('images',[])+document.get('buffers',[]):
        uri = item.get('uri','')
        if not uri or uri.startswith('data:'):
            continue
        parsed = urlsplit(uri)
        if parsed.scheme or parsed.netloc or parsed.query or parsed.fragment:
            raise ValueError('Only retained local creature source dependencies are supported')
        relative = Path(unquote(parsed.path))
        original = (source.parent/relative).resolve()
        target = (folder/relative).resolve()
        if not original.is_relative_to(source.parent.resolve()) or not target.is_relative_to(folder.resolve()):
            raise ValueError('Retained source dependency leaves its creature folder')
        data = original.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if target.exists() and sha(target)!=digest:
            raise ValueError('Retained external creature input changed: '+uri)
        if not target.exists():
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(data)
        records.append({'uri':uri,'source_path':str(original),'path':target.relative_to(ROOT).as_posix(),
                        'sha256':digest,'bytes':len(data)})
    return records


def curve_signature(action):
    rows = []
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    rows.append((curve.data_path, curve.array_index,
                        [(tuple(key.co), tuple(key.handle_left), tuple(key.handle_right), key.interpolation)
                         for key in curve.keyframe_points]))
    return hashlib.sha256(repr(sorted(rows)).encode()).hexdigest()


def rest_signature(rig):
    rows = [(bone.name, bone.parent.name if bone.parent else "", list(map(list, bone.matrix_local)))
            for bone in rig.data.bones]
    return hashlib.sha256(json.dumps(rows, sort_keys=True).encode()).hexdigest()


def base_mesh_signature(obj):
    """Hash retained base geometry, UVs and skin; new shape deltas are separate."""
    digest = hashlib.sha256()
    def record(value):
        digest.update(repr(value).encode())
        digest.update(b"\n")
    record(tuple(tuple(row) for row in obj.matrix_world))
    record(tuple(group.name for group in obj.vertex_groups))
    for vertex in obj.data.vertices:
        record((tuple(vertex.co), tuple((item.group, item.weight) for item in vertex.groups)))
    for polygon in obj.data.polygons:
        record((tuple(polygon.vertices), polygon.material_index, polygon.use_smooth))
    for layer in obj.data.uv_layers:
        record((layer.name, tuple(tuple(item.uv) for item in layer.data)))
    return digest.hexdigest()


def vertex_tiles(obj):
    layer = obj.data.uv_layers.active
    if layer is None:
        raise ValueError("Retained atlas UVs required for anatomical component selection")
    result = {}
    for poly in obj.data.polygons:
        uv = layer.data[poly.loop_start].uv
        tile = min(3, max(0, int(uv.x*4))) + 4*min(1, max(0, int(uv.y*2)))
        for index in poly.vertices:
            result.setdefault(index, tile)
    return result


def add_inkblind_controls(meshes):
    """Local shape controls on the actual retained antenna/brush components.

    Selection follows the retained v1 component's atlas tile and owning joint,
    with its documented anatomical range; the shield/legs are excluded.
    """
    reports = []
    for obj in meshes:
        tiles = vertex_tiles(obj)
        selected = {name: [] for name in ("AntennaProbe_L", "AntennaProbe_R", "BrushFeed_L", "BrushFeed_R")}
        for vertex in obj.data.vertices:
            if not vertex.groups:
                continue
            dominant = obj.vertex_groups[max(vertex.groups, key=lambda item: item.weight).group].name
            point = obj.matrix_world @ vertex.co
            side = "L" if point.x < 0 else "R"
            if dominant == "Head" and tiles.get(vertex.index) == 4 and -.82 < point.y < -.27 and abs(point.x) > .045:
                selected["AntennaProbe_"+side].append(vertex.index)
            elif dominant == "Jaw" and tiles.get(vertex.index) == 1 and -.48 < point.y < -.28:
                selected["BrushFeed_"+side].append(vertex.index)
        if not any(selected.values()):
            continue
        if obj.data.shape_keys is None:
            obj.shape_key_add(name="Basis")
        inverse = obj.matrix_world.inverted()
        for name, indices in selected.items():
            if len(indices) < 20:
                raise ValueError("Retained anatomical morph selection is incomplete: "+obj.name+"/"+name)
            key = obj.shape_key_add(name=name)
            for index in indices:
                point = obj.matrix_world @ obj.data.vertices[index].co
                sign = -1 if point.x < 0 else 1
                if name.startswith("Antenna"):
                    t = min(1.0, max(0.0, (-point.y-.29)/.48))
                    point.x += sign*.035*t*t
                    point.z += .018*math.sin(math.pi*t)*t
                else:
                    t = min(1.0, max(0.0, (-point.y-.31)/.11))
                    point.x += sign*.008*t
                    point.z += .012*t*t
                key.data[index].co = inverse @ point
            reports.append({"mesh": obj.name, "shape_key": name, "vertices": indices,
                            "selection": "retained dominant Head/tile4 antenna or Jaw/tile1 brush; source anatomical bounds"})
    names = {row["shape_key"] for row in reports}
    if names != {"AntennaProbe_L", "AntennaProbe_R", "BrushFeed_L", "BrushFeed_R"}:
        raise ValueError("Inkblind requires both actual antennae and brush palps")
    return reports


def water_tip_sources(rig, meshes):
    result = []
    for name in ('Fin1_2', 'Fin-1_2'):
        bone = rig.data.bones.get(name)
        if bone is None:
            raise ValueError('Retained water fin binding missing: '+name)
        inverse = (rig.matrix_world @ bone.matrix_local).inverted()
        candidates = []
        for obj in meshes:
            group = obj.vertex_groups.get(name)
            if group is None:
                continue
            for vertex in obj.data.vertices:
                weight = sum(item.weight for item in vertex.groups if item.group == group.index)
                if weight < .9999:
                    continue
                world = obj.matrix_world @ vertex.co
                local = inverse @ world
                if not all(math.isfinite(value) for value in local):
                    raise ValueError('Nonfinite retained water probe')
                candidates.append((local.length_squared, obj.name, vertex.index, weight, list(local), list(world)))
        if not candidates:
            raise ValueError('No rigidly bound actual retained fin-tip vertices: '+name)
        _, mesh, index, weight, local, world = max(candidates, key=lambda row: row[0])
        result.append({'bone_name': name, 'mesh': mesh, 'source_vertex': index, 'weight': weight,
            'offset_blender_rest': local, 'world_blender_rest': world,
            'selection': 'farthest retained vertex from final fin joint; actual rigid skin weight >= .9999'})
    return result


def main(asset, game, render=False):
    registry = json.loads((game/"data/design_pack_assets.json").read_text())["assets"]
    source = game/registry[asset]["path"][6:]
    source_hash = sha(source)
    folder = OUT/asset
    folder.mkdir(parents=True, exist_ok=True)
    retained_input = folder/(asset+'_retained_input.glb')
    if retained_input.exists() and sha(retained_input) != source_hash:
        raise ValueError('Retained creature baseline changed; use an explicit new derivative revision')
    if not retained_input.exists():
        retained_input.write_bytes(source.read_bytes())
    external_inputs = retain_external_inputs(source, folder)
    original_clips = glb_contract(source)
    if not set(REPLACED_CLIPS).issubset(original_clips):
        raise ValueError("Retained source lacks required native ambient clips")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.import_scene.gltf(filepath=str(source))
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if len(rigs) != 1:
        raise ValueError("Exactly one retained native rig is required")
    rig = rigs[0]
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    rest = rest_signature(rig)
    geometry = {obj.name: base_mesh_signature(obj) for obj in meshes}
    water_probes = water_tip_sources(rig, meshes) if asset == 'M18' else []
    protected = {action.name: curve_signature(action) for action in bpy.data.actions if action.name not in REPLACED_CLIPS}
    rig.animation_data_create()
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    # Retain each authored activity's own stance. In particular, native biped
    # Sleep is a grounded lying pose and must not become a standing idle.
    baselines, baseline_phases = {}, {}
    for clip in REPLACED_CLIPS:
        retained = bpy.data.actions.get(clip)
        if retained is None:
            raise ValueError("Actual retained activity action required: "+clip)
        rig.animation_data.action = None
        for bone in rig.pose.bones:
            bone.matrix_basis = Matrix.Identity(4)
        rig.animation_data.action = retained
        rig.animation_data.action_slot = retained.slots[0]
        baseline_phase = .5 if asset == "M08" and clip == "Sleep" else 0.0
        frame = retained.frame_range[0]+baseline_phase*(retained.frame_range[1]-retained.frame_range[0])
        bpy.context.scene.frame_set(int(frame), subframe=frame-int(frame))
        bpy.context.view_layer.update()
        baselines[clip] = {bone.name: bone.matrix_basis.copy() for bone in rig.pose.bones}
        baseline_phases[clip] = baseline_phase
    rig.animation_data.action = None
    for track in list(rig.animation_data.nla_tracks):
        if track.name in REPLACED_CLIPS:
            rig.animation_data.nla_tracks.remove(track)
    for name in REPLACED_CLIPS:
        old = bpy.data.actions.get(name)
        if old is None:
            raise ValueError("Imported native ambient action missing: "+name)
        bpy.data.actions.remove(old)
    anatomical_morphs = add_inkblind_controls(meshes) if asset == "M16" else []
    key_owners = [obj for obj in meshes if obj.data.shape_keys and len(obj.data.shape_keys.key_blocks) > 1]
    for obj in key_owners:
        obj.data.shape_keys.animation_data_create()
        obj.data.shape_keys.animation_data.action = None
        for key in obj.data.shape_keys.key_blocks:
            key.value = 0
    fps = bpy.context.scene.render.fps
    clip_reports = {}
    authored_actions = {}
    for clip in REPLACED_CLIPS:
        baseline = baselines[clip]
        action = bpy.data.actions.new(clip)
        action.use_fake_user = True
        rig.animation_data.action = action
        slot = action.slots.new(id_type="OBJECT", name=rig.name)
        rig.animation_data.action_slot = slot
        morph_slots = []
        for obj in key_owners:
            keys = obj.data.shape_keys
            keys.animation_data.action = action
            keys.animation_data.action_slot = action.slots.new(id_type="KEY", name=keys.name)
            morph_slots.append((obj, keys.animation_data.action_slot))
        final_frame = original_clips[clip]*fps
        steps = max(2, int(math.ceil(final_frame)))
        frames = [index*final_frame/steps for index in range(steps+1)]
        touched, keyed_shapes = set(), set()
        for frame in frames:
            phase = frame/final_frame
            for bone in rig.pose.bones:
                bone.matrix_basis = baseline[bone.name].copy()
                bone.rotation_mode = "QUATERNION"
            rotations, morphs = channels(asset, clip, phase)
            for name, axis, angle in rotations:
                bone = rig.pose.bones.get(name)
                if bone is None:
                    raise ValueError("Unknown retained motion control: "+asset+"/"+name)
                bone.rotation_quaternion = bone.rotation_quaternion @ Quaternion(
                    {'X':(1,0,0), 'Y':(0,1,0), 'Z':(0,0,1)}[axis], angle)
                touched.add(name)
            for bone in rig.pose.bones:
                if frame in (0, final_frame):
                    for prop in ("location", "rotation_quaternion", "scale"):
                        bone.keyframe_insert(prop, frame=frame, group=bone.name)
                elif bone.name in touched:
                    bone.keyframe_insert("rotation_quaternion", frame=frame, group=bone.name)
            for obj in key_owners:
                for key in obj.data.shape_keys.key_blocks:
                    if key.name == "Basis":
                        continue
                    key.value = morphs.get(key.name, 0.0)
                    key.keyframe_insert("value", frame=frame)
                    if key.name in morphs:
                        keyed_shapes.add(key.name)
        needed_shapes = set(channels(asset, clip, .5)[1])
        if not needed_shapes.issubset(keyed_shapes):
            raise ValueError("Native morph action lacks actual retained targets: "+str(needed_shapes-keyed_shapes))
        for layer in action.layers:
            for action_strip in layer.strips:
                for bag in action_strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:
                            key.interpolation = 'LINEAR'
        rig.animation_data.action = None
        track = rig.animation_data.nla_tracks.new()
        track.name = clip
        strip = track.strips.new(clip, 0, action)
        strip.action_slot = slot
        strip.action_frame_start = 0
        strip.action_frame_end = final_frame
        track.mute = True
        for obj in key_owners:
            keys = obj.data.shape_keys
            key_slot = keys.animation_data.action_slot
            keys.animation_data.action = None
            key_track = keys.animation_data.nla_tracks.new()
            key_track.name = clip
            key_strip = key_track.strips.new(clip, 0, action)
            key_strip.action_slot = key_slot
            key_strip.action_frame_end = final_frame
            key_track.mute = True
        clip_reports[clip] = {"duration_seconds": original_clips[clip], "bones": sorted(touched),
                              "morphs": sorted(keyed_shapes), "frame_rate": fps, "source_frames": frames}
        authored_actions[clip] = (action, slot, morph_slots, original_clips[clip])
        print("CREATURE_AMBIENT_BAKED", asset, clip, flush=True)
    after = {name: curve_signature(bpy.data.actions[name]) for name in protected}
    if protected != after or rest_signature(rig) != rest:
        raise ValueError("Protected combat/locomotion curves or retained rest skeleton changed")
    if geometry != {obj.name: base_mesh_signature(obj) for obj in meshes}:
        raise ValueError("Ambient derivative changed retained base geometry, UVs, skin or mesh transforms")
    for image in bpy.data.images:
        if image.source == "FILE" and not image.packed_file:
            image.pack()
    blend = folder/(asset+"_living_v001.blend")
    exported_carrier = folder/(asset+"_living_export.glb")
    carrier = folder/(asset+"_living_candidate.glb")
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), compress=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(exported_carrier), export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="ACTIONS", export_merge_animation="ACTION",
        export_force_sampling=False, export_skins=True, export_rest_position_armature=True,
        # New anatomical targets use dense buffers, as required by the exact
        # retained-base graft. Protected action accessors remain unchanged.
        export_try_sparse_sk=False, export_yup=True, export_extras=True)
    protected_bytes = graft(source, exported_carrier, carrier)
    exported = glb_contract(carrier)
    if set(exported) != set(original_clips) or any(abs(exported[name]-duration) > 1e-5 for name, duration in original_clips.items()):
        raise ValueError("Native clip identity or exact duration changed during export")
    if sha(source) != source_hash:
        raise ValueError("Retained production source was modified")
    for item in external_inputs:
        if sha(item['source_path']) != item['sha256']:
            raise ValueError('Retained external creature source changed during authoring')
    report = {"asset": asset, "species": SPECIES[asset][0], "intent": SPECIES[asset][1],
        "production_resource": registry[asset]["path"], "production_input_path":str(retained_input), "production_sha256": source_hash,
        "retained_external_inputs": external_inputs,
        "blend_sha256": sha(blend), "candidate_sha256": sha(carrier), "candidate_bytes": carrier.stat().st_size,
        "blender_export_sha256": sha(exported_carrier),
        "author_tool_sha256": sha(__file__), "recipe_sha256": sha(Path(__file__).with_name("living_creature_motion_profiles.py")),
        "recipe_snapshot": snapshot_recipe(), "retained_activity_baseline_phases": baseline_phases,
        "retained_rig_signature": rest, "protected_curve_signatures": protected, "ambient_clips": clip_reports,
        "retained_base_mesh_signatures": geometry, "retained_base_geometry_unchanged": True,
        "protected_curve_data_unchanged": True, "protected_export_buffers":protected_bytes,
        "anatomical_morph_selections": anatomical_morphs, "runtime_morph_binding_verified": False,
        "retained_water_tip_sources": water_probes,
        "attack_recalibration_required": True, "runtime_verified": False, "visual_accepted": False,
        "publication_ready": False, "production_overwritten": False}
    (folder/"authoring.json").write_text(json.dumps(report, indent=2)+"\n")
    if render:
        previews = render_views(rig, authored_actions, meshes, folder, fps)
        report["source_review_frames"] = previews
        (folder/"authoring.json").write_text(json.dumps(report, indent=2)+"\n")
    print("CREATURE_LIFE_CANDIDATE", asset, str(carrier), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset", required=True, choices=SPECIES)
    parser.add_argument("--source-game", required=True, type=Path)
    parser.add_argument("--art-root", type=Path, default=ROOT)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    ROOT = args.art_root
    OUT = ROOT / "models/living_assets_stage3_20261107/creatures"
    main(args.asset, args.source_game, args.render)
