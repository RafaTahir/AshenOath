"""Calibrate the retained mug to Merrow's actual palm and mouth surfaces.

The isolated native baseline must exist first. No guessed wrist or lip point is
accepted: both authored poses must pass actual evaluated-mesh contact checks.
The carrier remains in source world space; its compiler rebases through the
actual imported Drink hand pose, avoiding Blender/Godot bone-axis assumptions.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.geometry import closest_point_on_tri

sys.path.insert(0, str(Path(__file__).resolve().parent))
import author_living_cast_stage2 as retained


def xyz(point):
    return Vector((point[0], -point[2], point[1]))


def read_mesh(game):
    path = game/'assets_external/environment/props/Mug.gltf'
    document = json.loads(path.read_text())
    buffers = [(path.parent/item['uri']).read_bytes() for item in document['buffers']]

    def accessor(index):
        item = document['accessors'][index]
        view = document['bufferViews'][item['bufferView']]
        width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[item['type']]
        kind = {5121: 'B', 5123: 'H', 5125: 'I', 5126: 'f'}[item['componentType']]
        fmt = '<'+kind*width
        stride = view.get('byteStride', struct.calcsize(fmt))
        offset = view.get('byteOffset', 0)+item.get('byteOffset', 0)
        return [struct.unpack_from(fmt, buffers[view['buffer']], offset+i*stride) for i in range(item['count'])]

    primitives = []
    for primitive in document['meshes'][0]['primitives']:
        vertices = accessor(primitive['attributes']['POSITION'])
        normals = accessor(primitive['attributes']['NORMAL'])
        indices = [row[0] for row in accessor(primitive['indices'])]
        primitives.append({'vertices': vertices, 'normals': normals,
                           'faces': [indices[i:i+3] for i in range(0, len(indices), 3)]})
    return primitives, [{'resource': 'res://assets_external/environment/props/'+name,
        'sha256': retained.sha(path.parent/name)} for name in ('Mug.gltf', 'Mug.bin')]


def actual_lip_probe(rig):
    centres = [rig.matrix_world @ rig.pose.bones[name].head for name in ('Face_Mouth_L', 'Face_Mouth_R')]
    reference = (centres[0]+centres[1])*.5
    graph = bpy.context.evaluated_depsgraph_get()
    candidates = []
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        groups = [obj.vertex_groups.get(name) for name in ('Face_Mouth_L', 'Face_Mouth_R')]
        ids = {group.index for group in groups if group is not None}
        if not ids:
            continue
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        for original, vertex in zip(obj.data.vertices, mesh.vertices):
            weight = sum(group.weight for group in original.groups if group.group in ids)
            if weight < .25:
                continue
            point = evaluated.matrix_world @ vertex.co
            distance = (point-reference).length
            if distance < .05:
                candidates.append((distance, point.copy(), obj.name, original.index, weight))
        evaluated.to_mesh_clear()
    if not candidates:
        raise ValueError('No evaluated retained mouth surface can be calibrated')
    distance, point, name, index, weight = min(candidates, key=lambda row: row[0])
    return point, {'mesh': name, 'vertex': index, 'mouth_weight': weight,
                   'distance_from_mouth_bone_centre': distance, 'world_blender': list(point)}


def pose_hand(rig, wrist, rotation):
    retained.world_hand_goal(rig, 'r', wrist, 1.0, (.32, .04, 1.02))
    hand = rig.pose.bones['hand_r']
    hand.matrix = Matrix.LocRotScale(hand.matrix.translation, rotation, hand.matrix.to_scale())
    bpy.context.view_layer.update()


def main(game, art, render=False):
    folder = art/'models/living_cast_stage2_20261107/props'
    folder.mkdir(parents=True, exist_ok=True)
    baseline_path = art/'evidence/living_cast_stage2_20261107/C10_baseline.glb'
    if not baseline_path.is_file():
        raise ValueError('Export exact retained C10 baseline before cup calibration')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.import_scene.gltf(filepath=str(baseline_path))
    rig = next(obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE')
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    idle = bpy.data.actions['Idle']
    rig.animation_data.action = idle
    rig.animation_data.action_slot = idle.slots[0]
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    baseline = {bone.name: bone.matrix_basis.copy() for bone in rig.pose.bones}
    palm = retained.measure_palm_surfaces(rig)['r']
    rig.animation_data.action = None
    retained.turn(rig, 'Head', (1, 0, 0), -.035)
    mouth, mouth_report = actual_lip_probe(rig)
    primitives, sources = read_mesh(game)
    # Exact retained surface vertices, not an invented mug centre or proxy.
    handle_candidates = []
    reference = Vector((.119, .12, -.002))
    for face_index, indices in enumerate(primitives[1]['faces']):
        triangle = [Vector(primitives[1]['vertices'][i]) for i in indices]
        normal = (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).normalized()
        if normal.x < .9 or min(p.x for p in triangle) < .105:
            continue
        point = closest_point_on_tri(reference, *triangle)
        handle_candidates.append(((point-reference).length, face_index, point, normal))
    if not handle_candidates:
        raise ValueError('Retained mug handle cannot be identified')
    _, grip_face, grip_gltf, grip_normal = min(handle_candidates, key=lambda row: row[0])
    rim_candidates = [(primitive_index, i, p) for primitive_index, primitive in enumerate(primitives)
                      for i, p in enumerate(primitive['vertices']) if p[1] > .15 and p[2] > .045]
    if not rim_candidates:
        raise ValueError('Retained near rim cannot be identified')
    rim_primitive, rim_index, rim_gltf = min(rim_candidates,
        key=lambda row: (Vector(row[2])-Vector((0, .169, .072))).length)
    grip, rim = xyz(grip_gltf), xyz(rim_gltf)
    original_world = rig.matrix_world @ rig.pose.bones['hand_r'].matrix
    scale = original_world.to_scale()
    if max(scale)-min(scale) > .0001 or min(scale) <= 0:
        raise ValueError('Cup fit requires the retained uniform hand frame')
    # Match the actual closed-palm normal to the actual outer handle normal,
    # with the finger ray descending around the retained handle. A guessed
    # wrist basis can put a palm point on the handle while facing sideways.
    palm_normal=Vector(palm['local_surface_normal']).normalized()
    local_fingers=Vector((0,1,0))
    local_fingers=(local_fingers-palm_normal*local_fingers.dot(palm_normal)).normalized()
    handle_normal=xyz(grip_normal).normalized()
    desired_normal=-handle_normal
    desired_fingers=Vector((0,1,0))
    desired_fingers=(desired_fingers-desired_normal*desired_fingers.dot(desired_normal)).normalized()
    local_frame=Matrix((local_fingers.cross(palm_normal),local_fingers,palm_normal)).transposed()
    handle_frame=Matrix((desired_fingers.cross(desired_normal),desired_fingers,desired_normal)).transposed()
    hand_upright=(handle_frame @ local_frame.transposed()).to_quaternion()
    sip_rotation = Quaternion((1, 0, 0), math.radians(18))
    cup_transforms = {
        'hold': Matrix.LocRotScale(Vector((.10, .25, 1.10)), Quaternion(), Vector((1, 1, 1))),
        'sip': Matrix.LocRotScale(mouth+Vector((0, .002, 0))-sip_rotation @ rim,
                                 sip_rotation, Vector((1, 1, 1))),
    }
    poses = {}
    for label, cup_world in cup_transforms.items():
        for bone in rig.pose.bones:
            bone.matrix_basis = baseline[bone.name].copy()
        if label == 'sip':
            retained.turn(rig, 'Head', (1, 0, 0), -.035)
        rotation = cup_world.to_quaternion() @ hand_upright
        frame = Matrix.LocRotScale(Vector(), rotation, scale)
        desired_palm = cup_world @ grip
        wrist = desired_palm-frame.to_3x3() @ Vector(palm['local'])
        target = rig.matrix_world.inverted() @ Matrix.LocRotScale(wrist, rotation, scale)
        pose_hand(rig, wrist, target.to_quaternion())
        hand_world = rig.matrix_world @ rig.pose.bones['hand_r'].matrix
        actual_palm = hand_world @ Vector(palm['local'])
        bpy.context.view_layer.update()
        palm_mesh = bpy.data.objects[palm['source_mesh']]
        evaluated = palm_mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        skin = evaluated.to_mesh()
        actual_skin = evaluated.matrix_world @ skin.vertices[palm['source_vertex_index']].co
        evaluated.to_mesh_clear()
        residual = (actual_skin-desired_palm).length
        if (actual_skin-actual_palm).length > .002:
            raise ValueError('Retained cup palm probe no longer follows the actual closed-hand skin')
        shoulder = rig.matrix_world @ rig.pose.bones['upperarm_r'].head
        elbow = rig.matrix_world @ rig.pose.bones['lowerarm_r'].head
        hand = hand_world.translation
        reach_margin = (elbow-shoulder).length+(hand-elbow).length-(wrist-shoulder).length
        if residual > .002 or reach_margin < .006:
            raise ValueError('Actual retained cup hand cannot reach '+label+' pose: residual='+str(residual))
        poses[label] = {'wrist_world_blender': list(wrist), 'wrist_rotation_armature_blender_wxyz': list(target.to_quaternion()),
                        'actual_palm_world_blender':list(actual_skin),
                        'palm_residual': residual, 'reach_margin': reach_margin,
                        'cup_world_blender': [list(row) for row in cup_world]}
    root = bpy.data.objects.new('MerrowCup', None)
    bpy.context.scene.collection.objects.link(root)
    root.matrix_world = cup_transforms['sip']
    for index, primitive in enumerate(primitives):
        data = bpy.data.meshes.new('RetainedMug_'+str(index))
        data.from_pydata([xyz(point) for point in primitive['vertices']], [], primitive['faces'])
        data.update()
        obj = bpy.data.objects.new('RetainedMugMetal' if index == 0 else 'RetainedMugBodyAndHandle', data)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = root
        material = bpy.data.materials.new(obj.name+'Palette')
        material.diffuse_color = (.16, .14, .105, 1) if index == 0 else (.22, .115, .055, 1)
        material.roughness = .68 if index == 0 else .92
        material.metallic = .65 if index == 0 else 0
        data.materials.append(material)
    for name, point in [('ActualHandleGrip', grip), ('ActualDrinkingRim', rim)]:
        node = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(node)
        node.parent = root
        node.location = point
    # All body materials are packed into the editable review source. The
    # exported cup selects only its own retained geometry and small palette.
    for image in bpy.data.images:
        if image.source == 'FILE' and not image.packed_file:
            image.pack()
    blend = folder/'merrow_cup.blend'
    carrier = folder/'merrow_cup_world.glb'
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), compress=True)
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for obj in root.children:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(carrier), export_format='GLB', use_selection=True,
        export_animations=False, export_yup=True, export_extras=True)
    result = {'schema_version': 1, 'identity': 'merrow', 'bone': 'hand_r', 'sources': sources,
        'baseline_sha256': retained.sha(baseline_path), 'author_tool_sha256': retained.sha(__file__),
        'blend_sha256': retained.sha(blend), 'carrier_sha256': retained.sha(carrier),
        'actual_handle_surface': {'primitive': 1, 'triangle': grip_face, 'gltf': list(grip_gltf),
            'method': 'Closest point on retained outward handle triangle to centre of vertical grip'},
        'handle_surface_normal_blender':list(handle_normal),
        'grip_orientation_method':'Measured closed-palm surface normal opposes retained outer handle normal; finger ray crosses handle depth to wrap the vertical bar.',
        'elbow_hint_world_blender': [.32,.04,1.02],
        'actual_rim_vertex': {'primitive': rim_primitive, 'vertex': rim_index, 'gltf': list(rim_gltf)},
        'actual_palm': palm, 'actual_lip': mouth_report, 'poses': poses,
        'hold_wrist_goal_lateral_forward_height': poses['hold']['wrist_world_blender'],
        'wrist_goal_lateral_forward_height': poses['sip']['wrist_world_blender'],
        'hold_wrist_rotation_blender_wxyz': poses['hold']['wrist_rotation_armature_blender_wxyz'],
        'wrist_rotation_blender_wxyz': poses['sip']['wrist_rotation_armature_blender_wxyz'],
        'rim_to_lip_distance': (cup_transforms['sip'] @ rim-mouth).length,
        'grip_verified': True, 'rim_calibrated': True,
        'native_clearance_verified': False, 'visual_accepted': False, 'user_accepted': False,
        'runtime_resource': 'res://assets_external/environment_prepared/living_cast/merrow_cup.scn'}
    recipe_names = ['author_merrow_cup.py', 'author_living_cast_stage2.py',
                    'living_cast_stage2_motion.py', 'living_cast_stage2_profiles.py', 'living_cast_stage2_preview.py']
    recipe_directory = Path(__file__).resolve().parent
    hashes = {name: retained.sha(recipe_directory/name) for name in recipe_names}
    recipe_id = hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest()
    archive = folder/'recipes'/recipe_id[:16]
    archive.mkdir(parents=True, exist_ok=True)
    for name in recipe_names:
        target = archive/name
        if target.exists() and retained.sha(target) != hashes[name]:
            raise ValueError('Cup recipe snapshot collision')
        if not target.exists():
            target.write_bytes((recipe_directory/name).read_bytes())
    result['recipe_snapshot'] = {'sha256': recipe_id, 'files': [
        {'name': name, 'path': str((archive/name).relative_to(art)), 'sha256': hashes[name]} for name in recipe_names]}
    if render:
        scene = bpy.context.scene
        scene.render.engine = 'BLENDER_WORKBENCH'
        scene.render.resolution_x = 720
        scene.render.resolution_y = 800
        scene.render.resolution_percentage = 100
        scene.display.shading.color_type = 'MATERIAL'
        scene.display.shading.light = 'STUDIO'
        scene.display.shading.show_shadows = True
        scene.display.shading.show_cavity = True
        camera_data = bpy.data.cameras.new('CupContactReview')
        camera = bpy.data.objects.new('CupContactReview', camera_data)
        scene.collection.objects.link(camera)
        scene.camera = camera
        camera_data.type = 'ORTHO'
        camera_data.ortho_scale = .85
        target = Vector((.04, .12, 1.40))
        camera.location = target+Vector((1.05, 1.7, .3))
        camera.rotation_euler = (target-camera.location).to_track_quat('-Z', 'Y').to_euler()
        reviews = []
        for label in ('hold', 'sip'):
            for bone in rig.pose.bones:
                bone.matrix_basis = baseline[bone.name].copy()
            if label == 'sip':
                retained.turn(rig, 'Head', (1, 0, 0), -.035)
            pose_hand(rig, Vector(poses[label]['wrist_world_blender']),
                      Quaternion(poses[label]['wrist_rotation_armature_blender_wxyz']))
            root.matrix_world = cup_transforms[label]
            path = folder/('merrow_cup_'+label+'_review.png')
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            reviews.append(str(path))
        result['source_review_frames'] = reviews
    (folder/'merrow_cup_calibration.json').write_text(json.dumps(result, indent=2)+'\n')
    print('MERROW_CUP_SOURCE_CALIBRATED', carrier)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source-game', type=Path, required=True)
    parser.add_argument('--art-root', type=Path, default=retained.ROOT)
    parser.add_argument('--render', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    main(args.source_game, args.art_root, args.render)
