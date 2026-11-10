"""Read retained hand anatomy for deliberate contact authoring; no source edits."""
import argparse
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]


def main(asset):
    folder = ROOT / 'models/living_cast_stage2_20261107' / asset
    receipt = json.loads((folder / 'authoring.json').read_text())
    bpy.ops.wm.open_mainfile(filepath=str(folder / (asset + '_living_cast_v001.blend')))
    rig = next(obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE')
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    output = {}
    for clip, frame in [('Life_Idle_A', 0), ('Life_Work', 60)]:
        action = bpy.data.actions[clip]
        rig.animation_data.action = action
        rig.animation_data.action_slot = action.slots[0]
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        graph = bpy.context.evaluated_depsgraph_get()
        output[clip] = {'rig_world': [list(row) for row in rig.matrix_world], 'hands': {}}
        for side in ['l', 'r']:
            hand = rig.pose.bones['hand_' + side]
            matrix = rig.matrix_world @ hand.matrix
            probe = receipt['contact_probes_blender'][side]
            obj = bpy.data.objects[probe['source_mesh']]
            evaluated = obj.evaluated_get(graph)
            mesh = evaluated.to_mesh()
            vertex = mesh.vertices[probe['source_vertex_index']]
            normal = (evaluated.matrix_world.to_3x3().inverted().transposed() @ vertex.normal).normalized()
            rigid_candidates = []
            group = obj.vertex_groups['hand_'+side]
            for original, candidate in zip(obj.data.vertices, mesh.vertices):
                weight = sum(item.weight for item in original.groups if item.group == group.index)
                point = matrix.inverted() @ (evaluated.matrix_world @ candidate.co)
                if weight >= .9999 and .005 < point.y < .10:
                    n = (evaluated.matrix_world.to_3x3().inverted().transposed() @ candidate.normal).normalized()
                    rigid_candidates.append({'vertex':original.index,'point':list(point),
                                             'normal':list((matrix.to_3x3().transposed() @ n).normalized())})
            bones = {}
            for name in ['index_01_', 'index_02_', 'index_03_', 'index_04_leaf_', 'middle_01_', 'middle_04_leaf_', 'pinky_01_', 'pinky_04_leaf_']:
                bone = rig.pose.bones[name + side]
                bones[name + side] = {'head_local_hand': list(matrix.inverted() @ (rig.matrix_world @ bone.head)),
                                      'basis_rotation': list(bone.rotation_quaternion),
                                      'world': list(rig.matrix_world @ bone.head)}
            output[clip]['hands'][side] = {'matrix_world': [list(row) for row in matrix],
                                         'normal_world': list(normal),
                                         'normal_hand_local': list((matrix.to_3x3().transposed() @ normal).normalized()),
                                         'rigid_candidates':rigid_candidates,
                                         'bones': bones}
            evaluated.to_mesh_clear()
    path = folder / 'hand_anatomy.json'
    path.write_text(json.dumps(output, indent=2) + '\n')
    print('HAND_ANATOMY', str(path), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--asset', required=True)
    main(parser.parse_args(sys.argv[sys.argv.index('--') + 1:]).asset)
