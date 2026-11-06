"""Measure a curled-palm anchor against evaluated retained hand vertices."""
import argparse
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'models/living_cast_20261107'
PALM=Vector((0,.045,-.012))


def main(asset):
    folder=OUT/asset
    receipt=json.loads((folder/'authoring.json').read_text())
    bpy.ops.wm.open_mainfile(filepath=str(folder/(asset+'_living_cast_v001.blend')))
    rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    for track in rig.animation_data.nla_tracks:track.mute=True
    action=bpy.data.actions['Life_Work'];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    bpy.context.scene.frame_set(60);bpy.context.view_layer.update()
    graph=bpy.context.evaluated_depsgraph_get();measurements={}
    for side in ['l','r']:
        bone=rig.pose.bones['hand_'+side]
        matrix=rig.matrix_world @ bone.matrix;inverse=matrix.inverted()
        candidates=[]
        for obj in bpy.context.scene.objects:
            if obj.type!='MESH':continue
            group=obj.vertex_groups.get('hand_'+side)
            if group is None:continue
            evaluated=obj.evaluated_get(graph);mesh=evaluated.to_mesh()
            for original,vertex in zip(obj.data.vertices,mesh.vertices):
                weight=sum(g.weight for g in original.groups if g.group==group.index)
                if weight<.90:continue
                point=inverse @ (evaluated.matrix_world @ vertex.co)
                if .025<=point.y<=.085:candidates.append((point,original.index,obj.name,weight))
            evaluated.to_mesh_clear()
        if not candidates:raise ValueError(asset+' lacks retained hand-surface candidates: '+side)
        calibration=receipt.get('contact_probes_blender',{}).get(side)
        selected=min(candidates,key=lambda entry:(entry[0]-PALM).length)
        if calibration:
            selected=next(entry for entry in candidates if entry[1]==calibration['source_vertex_index'] and entry[2]==calibration['source_mesh'])
        nearest=selected[0]
        points=[entry[0] for entry in candidates]
        measurements[side]={'local_grip_anchor':list(PALM),'world_grip_anchor':list(matrix @ PALM),
            'world_wrist':list(matrix.translation),'nearest_retained_hand_surface_local':list(nearest),
            'world_surface_probe':list(matrix @ nearest),'source_mesh':selected[2],'source_vertex_index':selected[1],'hand_bone_weight':selected[3],
            'nearest_surface_distance':(nearest-PALM).length,'sampled_hand_vertices':len(candidates),
            'palm_region_bounds':{'min':[min(p[i] for p in points) for i in range(3)],'max':[max(p[i] for p in points) for i in range(3)]}}
        if calibration:
            recorded=matrix @ Vector(calibration['local'])
            actual=matrix @ nearest
            measurements[side]['actual_surface_to_recorded_probe_distance']=(actual-recorded).length
            contact=next(sample for sample in receipt['clips']['Life_Work']['sampled_points'] if sample['phase']==.5)
            target=Vector(contact['world_contact_probes'][side])
            measurements[side]['actual_surface_to_authored_contact_distance']=(actual-target).length
            if (actual-target).length>.01:raise ValueError(asset+' palm probe differs from evaluated hand surface by over1cm')
    report={'asset':asset,'phase':.5,'method':'nearest evaluated retained palm surface vertex to curled-palm reference, hand weight>=.90 in distal palm region',
            'measurements':measurements,'runtime_verified':False,'user_accepted':False}
    (folder/'palm_surface_inspection.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--asset',required=True)
    main(parser.parse_args(sys.argv[sys.argv.index('--')+1:]).asset)
