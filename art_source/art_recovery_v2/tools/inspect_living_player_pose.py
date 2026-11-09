"""Verify planted native frames and measurable retained torso motion at30Hz."""
import hashlib
import json
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT/'models/living_assets_stage3_20261107/player/P01'


def main():
    receipt = json.loads((FOLDER/'authoring.json').read_text())
    source = FOLDER/'P01_living_cast_v001.blend'
    if hashlib.sha256(source.read_bytes()).hexdigest() != receipt['blend_sha256']:
        raise ValueError('Player retained source changed after authoring')
    baseline = ROOT/'evidence/living_assets_stage3_20261107/player/P01_baseline.glb'
    if hashlib.sha256(baseline.read_bytes()).hexdigest() != receipt['baseline_sha256']:
        raise ValueError('Player retained native Idle baseline changed')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(baseline))
    original = next(obj for obj in bpy.data.objects if obj.type == 'ARMATURE')
    for track in original.animation_data.nla_tracks:
        track.mute = True
    original.animation_data.action = bpy.data.actions['Idle']
    original.animation_data.action_slot = original.animation_data.action.slots[0]
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    names = ['hand_l', 'hand_r', 'foot_l', 'foot_r', 'root']
    retained = {name: (original.matrix_world @ original.pose.bones[name].matrix).copy() for name in names}
    original_root_frame = original.matrix_world.copy()
    bpy.ops.wm.open_mainfile(filepath=str(source))
    rig = next(obj for obj in bpy.data.objects if obj.type == 'ARMATURE')
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    rig.animation_data.action = bpy.data.actions['Life_Idle_A']
    rig.animation_data.action_slot = rig.animation_data.action.slots[0]
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    root_frame = rig.matrix_world.copy()
    if max(abs(root_frame[row][column]-original_root_frame[row][column]) for row in range(4) for column in range(4)) > .00001:
        raise ValueError('Player authored object differs from actual retained baseline')
    surfaces = []
    graph = bpy.context.evaluated_depsgraph_get()
    for obj in bpy.data.objects:
        if obj.type != 'MESH' or not obj.vertex_groups:
            continue
        groups = {g.index for g in obj.vertex_groups if g.name.startswith(('spine_', 'clavicle_'))}
        indices = [v.index for v in obj.data.vertices if sum(g.weight for g in v.groups if g.group in groups) >= .80]
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        positions = {i: (evaluated.matrix_world @ mesh.vertices[i].co).copy() for i in indices}
        evaluated.to_mesh_clear()
        if positions:
            surfaces.append((obj, positions))
    if not surfaces:
        raise ValueError('Player source has no actual retained torso surface binding')
    reports = []
    for clip, seconds in [('Life_Idle_A', 6), ('Life_Idle_B', 8)]:
        rig.animation_data.action = bpy.data.actions[clip]
        rig.animation_data.action_slot = rig.animation_data.action.slots[0]
        position_error = {name: 0.0 for name in names}
        basis_error = {name: 0.0 for name in names}
        surface_motion = 0.0
        for frame in range(seconds*30+1):
            bpy.context.scene.frame_set(frame)
            bpy.context.view_layer.update()
            if rig.matrix_world != root_frame:
                raise ValueError('Player object frame moved')
            for name in names:
                current = rig.matrix_world @ rig.pose.bones[name].matrix
                position_error[name] = max(position_error[name], (current.translation-retained[name].translation).length)
                basis_error[name] = max(basis_error[name], max(abs(current[row][column]-retained[name][row][column])
                    for row in range(3) for column in range(3)))
            graph = bpy.context.evaluated_depsgraph_get()
            for obj, positions in surfaces:
                evaluated = obj.evaluated_get(graph)
                mesh = evaluated.to_mesh()
                surface_motion = max(surface_motion, max((evaluated.matrix_world @ mesh.vertices[i].co-point).length
                    for i, point in positions.items()))
                evaluated.to_mesh_clear()
        if max(position_error.values()) > .0001 or max(basis_error.values()) > .0001:
            raise ValueError('Player native hand/foot/root frame changed: '+str((clip,position_error,basis_error)))
        if not .0001 < surface_motion < .03:
            raise ValueError('Player torso motion is flat or exceeds the restrained envelope')
        reports.append({'clip': clip, 'frames': seconds*30+1, 'maximum_position_error': position_error,
                        'maximum_basis_error': basis_error, 'maximum_retained_torso_surface_motion': surface_motion})
    report = {'asset': 'P01', 'blend_sha256': receipt['blend_sha256'],
              'retained_native_baseline_sha256': receipt['baseline_sha256'],
              'carrier_sha256': receipt['review_glb_sha256'], 'sample_hz': 30,
              'clips': reports, 'hand_foot_root_frames_preserved': True,
              'retained_torso_surface_motion_verified': True,
              'native_equipment_and_garment_fit_verified': False, 'visual_accepted': False}
    (FOLDER/'source_pose_verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print('PLAYER_SOURCE_POSE_PASS', reports, flush=True)


if __name__ == '__main__':
    main()
