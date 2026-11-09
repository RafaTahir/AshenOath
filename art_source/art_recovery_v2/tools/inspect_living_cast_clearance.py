"""Measure actual animated hand skin against the agreed supported table slab."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]


def main(asset, clip='Life_Work'):
    folder = ROOT / 'models/living_cast_stage2_20261107' / asset
    receipt = json.loads((folder/'authoring.json').read_text())
    blend = folder/(asset+'_living_cast_v001.blend')
    digest = hashlib.sha256(blend.read_bytes()).hexdigest()
    if digest != receipt['blend_sha256']:
        raise ValueError('Animated clearance input is stale')
    bpy.ops.wm.open_mainfile(filepath=str(blend))
    rig = next(obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE')
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    selections = []
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH' or not obj.vertex_groups:
            continue
        hand_groups = {group.index for group in obj.vertex_groups if group.name.startswith(('lowerarm_', 'hand_', 'index_', 'middle_', 'ring_', 'pinky_', 'thumb_'))}
        indices = [vertex.index for vertex in obj.data.vertices if sum(g.weight for g in vertex.groups if g.group in hand_groups) >= .80]
        if indices:
            selections.append((obj, indices))
    action = bpy.data.actions[clip]
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    samples = []
    if receipt['profile'].get('contact_required', True):
        for frame in range(0, 121):
            bpy.context.scene.frame_set(frame)
            bpy.context.view_layer.update()
            graph = bpy.context.evaluated_depsgraph_get()
            intrusions = []
            for obj, indices in selections:
                evaluated = obj.evaluated_get(graph)
                mesh = evaluated.to_mesh()
                for index in indices:
                    point = evaluated.matrix_world @ mesh.vertices[index].co
                    if abs(point.x) < .55 and .365 < point.y < 1.16 and .950 < point.z < .998:
                        intrusions.append((point,index,obj.name))
                evaluated.to_mesh_clear()
            if intrusions:
                point,index,name = min(intrusions,key=lambda row:row[0].z)
                samples.append({'phase':frame/120,'vertices':len(intrusions),'maximum_slab_depth':1-point.z,
                                'source_mesh':name,'source_vertex_index':index,'world_point':list(point)})
    garment = {}
    if asset == 'C05':
        idle = bpy.data.actions['Life_Idle_A']
        rig.animation_data.action = idle
        rig.animation_data.action_slot = idle.slots[0]
        bpy.context.scene.frame_set(0)
        bpy.context.view_layer.update()
        graph = bpy.context.evaluated_depsgraph_get()
        desired = Vector((-.14,.16,1.28))
        candidates = []
        for obj, unused in selections:
            groups = {g.index for g in obj.vertex_groups if g.name.startswith(('spine_', 'clavicle_'))}
            evaluated = obj.evaluated_get(graph)
            mesh = evaluated.to_mesh()
            normals = evaluated.matrix_world.to_3x3().inverted().transposed()
            for original, vertex in zip(obj.data.vertices, mesh.vertices):
                if sum(g.weight for g in original.groups if g.group in groups) < .65:
                    continue
                point = evaluated.matrix_world @ vertex.co
                normal = (normals @ vertex.normal).normalized()
                if normal.y > .4:
                    candidates.append((point,normal,original.index,obj.name))
            evaluated.to_mesh_clear()
        if candidates:
            point,normal,index,name = min(candidates,key=lambda row:(row[0]-desired).length)
            garment = {'desired':list(desired),'actual_surface':list(point),'normal':list(normal),
                       'source_mesh':name,'source_vertex_index':index,'distance':(point-desired).length,
                       'use_as_contact_approved':False}
    report = {'asset':asset,'clip':clip,'blend_sha256':digest,'review_glb_sha256':receipt['review_glb_sha256'],
              'sample_hz':30,'evaluated_region':'forearm, hand and all five finger chains',
              'table_slab_lateral_forward_height':{'min':[-.55,.36,.95],'max':[.55,1.16,1.0]},
              'hand_slab_intrusions':samples,'garment_surface_candidate':garment,
              'source_trajectory_clear':not samples,'native_verified':False,'visual_accepted':False}
    suffix='' if clip=='Life_Work' else '_'+clip
    (folder/('source_clearance'+suffix+'.json')).write_text(json.dumps(report,indent=2)+'\n')
    print('SOURCE_HAND_CLEARANCE',asset,clip,'intrusion_frames',len(samples),'garment',garment,flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--asset',required=True,nargs='+')
    parser.add_argument('--clip',default='Life_Work',choices=['Life_Work','Life_Settle_Ledger'])
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    for identity in args.asset:
        main(identity,args.clip)
