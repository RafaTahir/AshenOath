"""Read native palm/finger anatomy before authoring a different retained rig."""
import argparse
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(Path(__file__).parent))
from living_cast_stage2_motion import relax_work_fingers


def main(asset):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'evidence/living_cast_stage2_20261107'/(asset+'_baseline.glb')))
    rig=next(obj for obj in bpy.context.scene.objects if obj.type=='ARMATURE')
    for track in rig.animation_data.nla_tracks:track.mute=True
    action=bpy.data.actions['Idle']
    rig.animation_data.action=action
    rig.animation_data.action_slot=action.slots[0]
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    rig.animation_data.action=None
    report={}
    for side in ('l','r'):
        relax_work_fingers(rig,side,1.0)
        bpy.context.view_layer.update()
        hand=rig.pose.bones['hand_'+side]
        matrix=rig.matrix_world @ hand.matrix
        inverse=matrix.inverted()
        graph=bpy.context.evaluated_depsgraph_get()
        rows=[]
        for obj in bpy.context.scene.objects:
            if obj.type!='MESH':continue
            group=obj.vertex_groups.get('hand_'+side)
            if group is None:continue
            evaluated=obj.evaluated_get(graph)
            mesh=evaluated.to_mesh()
            for original,vertex in zip(obj.data.vertices,mesh.vertices):
                weight=sum(g.weight for g in original.groups if g.group==group.index)
                if weight<.50:continue
                point=inverse @ (evaluated.matrix_world @ vertex.co)
                normal=(matrix.to_3x3().transposed() @ evaluated.matrix_world.to_3x3().inverted().transposed() @ vertex.normal).normalized()
                rows.append({'point':list(point),'normal':list(normal),'vertex':original.index,'weight':weight,'mesh':obj.name})
            evaluated.to_mesh_clear()
        bones={}
        for name in ('index_01_','index_02_','middle_01_','middle_02_','thumb_01_','thumb_03_','pinky_01_'):
            bone=rig.pose.bones[name+side]
            bones[name+side]={'head':list(inverse @ (rig.matrix_world @ bone.head)),
                              'tail':list(inverse @ (rig.matrix_world @ bone.tail)),
                              'rotation':list(bone.rotation_quaternion)}
        rows.sort(key=lambda row:(Vector(row['point'])-Vector((0,.045,-.012))).length)
        sign=1 if side=='l' else -1
        front=[row for row in rows if .025<row['point'][1]<.10 and abs(row['point'][2])<.025 and row['normal'][0]*sign>.85]
        front.sort(key=lambda row:row['point'][0]*sign,reverse=True)
        report[side]={'hand_world':list(matrix.translation),'hand_scale':list(matrix.to_scale()),'bones':bones,'nearest_palm_candidates':rows[:30],
                      'front_palm_candidates':front[:25],
                      'bounds':{'min':[min(row['point'][i] for row in rows) for i in range(3)],'max':[max(row['point'][i] for row in rows) for i in range(3)]}}
    path=ROOT/'models/living_cast_stage2_20261107'/asset/'palm_anatomy_candidates.json'
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(report,indent=2)+'\n')
    print('PALM_ANATOMY',asset,str(path),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--asset',required=True,nargs='+')
    for asset in parser.parse_args(sys.argv[sys.argv.index('--')+1:]).asset:main(asset)
