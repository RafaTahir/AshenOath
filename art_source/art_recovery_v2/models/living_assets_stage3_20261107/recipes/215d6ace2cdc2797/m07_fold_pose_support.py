"""Bake only the accepted retained-rig fold and its measured feeding release."""
import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector
from m07_baked_geometry import make_checker

RECEIPT = Path(__file__).with_name('m07_fold_probe_receipt.json')
RECEIPT_SHA = '90413a7482b29d0c7edaacd2185dc95cf35721628b9f0c5a28ae5805136979d5'
WINGS = tuple(f'{prefix}{side}_{index}' for side in (1, -1) for prefix, count in [('Wing', 2), ('WingFinger', 4)] for index in range(count))
FEEDING_WING = tuple(name for name in WINGS if name.startswith(('Wing1_', 'WingFinger1_')))


def measured_fold(retained_sha):
    raw = RECEIPT.read_bytes()
    if hashlib.sha256(raw).hexdigest() != RECEIPT_SHA:
        raise ValueError('Accepted M07 probe receipt changed')
    proof = json.loads(raw)
    if proof.get('asset') != 'M07' or not all(proof.get(key) is True for key in ('pose_feasible', 'protected_clips_verified', 'inputs_unchanged')):
        raise ValueError('M07 fold measurement is not accepted')
    if not any(Path(path).name == 'M07_retained_input.glb' and digest == retained_sha for path, digest in proof['inputs'].items()):
        raise ValueError('Measured fold belongs to a different retained source')
    if set(proof['folded_basis']) != set(WINGS) or len(proof['trajectory']) != 34 or not all(row['sample_geometry_pass'] is True for row in proof['trajectory']):
        raise ValueError('Incomplete measured wing controls or trajectory')
    if not 0 < proof['selected']['width_fraction'] <= .75:
        raise ValueError('Measured fold does not meet the retained span criterion')
    rotations = {}
    for name, rows in proof['folded_basis'].items():
        if len(rows) != 4 or any(len(row) != 4 or not all(math.isfinite(v) for v in row) for row in rows):
            raise ValueError('Invalid measured local basis for ' + name)
        rotations[name] = Matrix(rows).decompose()[1]
    return rotations, proof


def set_baseline(rig, baseline):
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.matrix_basis = baseline[bone.name].copy()
    bpy.context.view_layer.update()


def _component_error(a, b):
    return max(abs(a[i][j] - b[i][j]) for i in range(4) for j in range(4))


def _joint(rig, name):
    return rig.matrix_world @ rig.pose.bones[name].head


def _rotate_world(rig, name, delta):
    bone = rig.pose.bones[name]
    world = rig.matrix_world @ bone.matrix
    posed = Matrix.LocRotScale(world.translation, delta @ world.to_quaternion(), world.to_scale())
    bone.matrix = rig.matrix_world.inverted() @ posed
    bpy.context.view_layer.update()


def apply_fold(rig, baseline, rotations, proof, clip, phase):
    pulse = math.sin(math.pi * phase) ** 2 if clip == 'Feed' else 0.0
    for name in WINGS:
        location, neutral, scale = baseline[name].decompose()
        rotation = rotations[name]
        if name in FEEDING_WING and pulse:
            rotation = rotation.slerp(neutral, .06 * pulse)
        rig.pose.bones[name].matrix_basis = Matrix.LocRotScale(location, rotation, scale)
    if clip == 'Feed':
        bpy.context.view_layer.update()
        right = Vector(proof['anatomical_frame']['right'])
        for name, angle in [('Neck', .10), ('Head', .20)]:
            _rotate_world(rig, name, Quaternion(right, angle * pulse))
        return {'Neck', 'Head', *FEEDING_WING}
    return set()


def verify_measured_basis(rig, baselines, rotations, proof):
    idle = baselines['Idle']
    # The exact retained GLB has the same Idle, Feed and Investigate phase-zero
    # transforms. Sleep starts with a distinct authored head rotation.
    for clip, baseline in baselines.items():
        for name, matrix in baseline.items():
            if clip == 'Sleep' and name == 'Head':
                continue
            if _component_error(matrix, idle[name]) > 1e-5:
                raise ValueError(f'{clip} retained neutral control diverges: {name}')
    set_baseline(rig, idle)
    for stage, expected in [('retained_idle', proof['retained_idle_joint_centers']), ('selected', proof['selected_joint_centers'])]:
        if stage == 'selected':
            apply_fold(rig, idle, rotations, proof, 'Idle', 0.0)
            bpy.context.view_layer.update()
        for side in (1, -1):
            finger_heads = [_joint(rig, f'WingFinger{side}_{i}') for i in range(4)]
            wrist = sum(finger_heads, Vector()) / len(finger_heads)
            for point, actual in [('shoulder', _joint(rig, f'Wing{side}_0')), ('elbow', _joint(rig, f'Wing{side}_1')), ('wrist', wrist)]:
                if (actual - Vector(expected[str(side)][point])).length > 1e-5:
                    raise ValueError(f'{stage} {side} {point} differs from accepted measured pose')
    set_baseline(rig, idle)


def verify_baked_actions(rig, mesh, baselines, actions, fps, proof):
    set_baseline(rig, baselines['Idle'])
    geometry, measure = make_checker(rig, mesh)
    geometry['clips'] = {}
    geometry['accepted_fold_probe_sha256'] = RECEIPT_SHA
    geometry['retained_entry_exit_samples'] = 17
    geometry['selected_probe_span_fraction'] = proof['selected']['width_fraction']
    baseline_width = geometry['baseline']['wing_width_m']
    for clip, (action, slot, _, duration) in actions.items():
        samples = []
        for index in range(17):
            set_baseline(rig, baselines[clip])
            rig.animation_data.action = action
            rig.animation_data.action_slot = slot
            frame = duration * fps * index / 16
            bpy.context.scene.frame_set(math.floor(frame), subframe=frame - math.floor(frame))
            bpy.context.view_layer.update()
            sample = measure(f'{clip}_{index:02}')
            if not sample['sample_geometry_pass']:
                raise ValueError(f'Baked M07 clip violates measured clearance: {sample}')
            sample['width_fraction'] = sample['wing_width_m'] / baseline_width
            samples.append(sample)
        geometry['clips'][clip] = samples
    if geometry['clips']['Idle'][0]['width_fraction'] > .75:
        raise ValueError('Baked M07 folded Idle span exceeds 75 percent of retained Idle')
    rig.animation_data.action = None
    return geometry
