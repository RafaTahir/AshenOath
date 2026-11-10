"""Measure a curled-palm anchor against evaluated retained hand vertices."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'models/living_cast_stage2_20261107'
PALM=Vector((0,.045,-.012))


def main(asset,clip='Life_Work'):
    folder=OUT/asset
    receipt=json.loads((folder/'authoring.json').read_text())
    if hashlib.sha256((folder/(asset+'_living_cast_v001.blend')).read_bytes()).hexdigest()!=receipt['blend_sha256']:
        raise ValueError('Palm inspection input differs from the source receipt')
    bpy.ops.wm.open_mainfile(filepath=str(folder/(asset+'_living_cast_v001.blend')))
    rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    for track in rig.animation_data.nla_tracks:track.mute=True
    action=bpy.data.actions[clip];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    bpy.context.scene.frame_set(60);bpy.context.view_layer.update()
    graph=bpy.context.evaluated_depsgraph_get();measurements={}; failures=[]
    for side in ['l','r']:
        calibration=receipt.get('contact_probes_blender',{}).get(side)
        minimum_weight=float(calibration.get('minimum_hand_weight',.90)) if calibration else .90
        if minimum_weight<.60:raise ValueError('Palm calibration is outside the retained hand-skin domain')
        bone=rig.pose.bones['hand_'+side]
        matrix=rig.matrix_world @ bone.matrix;inverse=matrix.inverted()
        candidates=[]; finger_points=[]; palm_normals={}
        for obj in bpy.context.scene.objects:
            if obj.type!='MESH':continue
            group=obj.vertex_groups.get('hand_'+side)
            if group is None:continue
            evaluated=obj.evaluated_get(graph);mesh=evaluated.to_mesh()
            for original,vertex in zip(obj.data.vertices,mesh.vertices):
                weight=sum(g.weight for g in original.groups if g.group==group.index)
                finger_weight=sum(g.weight for g in original.groups if obj.vertex_groups[g.group].name.endswith('_'+side) and obj.vertex_groups[g.group].name.startswith(('index_','middle_','ring_','pinky_','thumb_')))
                if finger_weight>=.90:
                    finger_points.append(evaluated.matrix_world @ vertex.co)
                if weight<minimum_weight:continue
                point=inverse @ (evaluated.matrix_world @ vertex.co)
                if .025<=point.y<=.085:
                    candidates.append((point,original.index,obj.name,weight))
                    palm_normals[(obj.name,original.index)]=(evaluated.matrix_world.to_3x3().inverted().transposed() @ vertex.normal).normalized()
            evaluated.to_mesh_clear()
        if not candidates:raise ValueError(asset+' lacks retained hand-surface candidates: '+side)
        selected=min(candidates,key=lambda entry:(entry[0]-PALM).length)
        if calibration:
            selected=next(entry for entry in candidates if entry[1]==calibration['source_vertex_index'] and entry[2]==calibration['source_mesh'])
        nearest=selected[0]
        points=[entry[0] for entry in candidates]
        measurements[side]={'local_grip_anchor':list(PALM),'world_grip_anchor':list(matrix @ PALM),
            'world_wrist':list(matrix.translation),'nearest_retained_hand_surface_local':list(nearest),
            'world_surface_probe':list(matrix @ nearest),'source_mesh':selected[2],'source_vertex_index':selected[1],'hand_bone_weight':selected[3],
            'nearest_surface_distance':(nearest-PALM).length,'sampled_hand_vertices':len(candidates),
            'palm_region_bounds':{'min':[min(p[i] for p in points) for i in range(3)],'max':[max(p[i] for p in points) for i in range(3)]},
            'actual_palm_normal':list(palm_normals[(selected[2],selected[1])]),
            'palm_down_alignment':palm_normals[(selected[2],selected[1])].dot(Vector((0,0,-1))),
            'finger_surface_vertices':len(finger_points),
            'finger_surface_minimum_height':min((p.z for p in finger_points),default=None)}
        if calibration:
            recorded=matrix @ Vector(calibration['local'])
            actual=matrix @ nearest
            measurements[side]['actual_surface_to_recorded_probe_distance']=(actual-recorded).length
            contact=next(sample for sample in receipt['clips'][clip]['sampled_points'] if sample['phase']==.5)
            target=Vector(contact['world_contact_probes'][side])
            measurements[side]['actual_surface_to_authored_contact_distance']=(actual-target).length
            if (actual-target).length>.002:failures.append(asset+'/'+side+' palm probe differs from evaluated hand surface by over2mm')
            if asset not in ('C07','C12'):
                measurements[side]['finger_clearance_to_work_plane']=min(p.z-target.z for p in finger_points)
                if measurements[side]['palm_down_alignment']<.85:
                    failures.append(asset+'/'+side+' palm is not directed into its work plane')
                if measurements[side]['finger_clearance_to_work_plane']<-.003:
                    failures.append(asset+'/'+side+' fingers penetrate the supported work plane by over3mm')
    report={'asset':asset,'clip':clip,'phase':.5,'method':'independent evaluated-skin check of the recorded front-palm vertex in the authored contact pose; actual normals and full finger surfaces sampled',
            'blend_sha256':receipt['blend_sha256'],'review_glb_sha256':receipt['review_glb_sha256'],
            'measurements':measurements,'failures':failures,'status':'failed' if failures else 'source_surface_pass','runtime_verified':False,'user_accepted':False}
    suffix='' if clip=='Life_Work' else '_'+clip
    (folder/('palm_surface_inspection'+suffix+'.json')).write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report),flush=True)
    if failures:raise ValueError('; '.join(failures))


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--asset',required=True)
    parser.add_argument('--clip',default='Life_Work',choices=['Life_Work','Life_Settle_Ledger'])
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);main(args.asset,args.clip)
