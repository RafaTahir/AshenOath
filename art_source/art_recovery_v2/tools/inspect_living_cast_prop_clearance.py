"""Inspect retained hand skin against the actual supported solid prop geometry.

Open leaf/page sheets are reported separately; this check never treats an open
surface as a solid volume. Timber-table checks remain the separate full-trajectory
fixture. Source checks do not replace native animation/prop visual review.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]


def inside_solid(tree, point):
    # Ray parity does not depend on source triangle winding. A nearest-face
    # normal test can incorrectly call points outside a concave/inside-out
    # retained ribbon solid, so it cannot be the containment authority.
    votes=0
    for vector in ((.811,.367,.455),(-.273,.907,.319),(.191,-.433,.881)):
        direction=Vector(vector).normalized()
        origin=point.copy();crossings=0
        for unused in range(128):
            hit,normal,index,distance=tree.ray_cast(origin,direction)
            if hit is None:
                votes+=crossings%2
                break
            crossings+=1
            origin=hit+direction*.00001
        else:raise ValueError('Solid-prop ray exceeded bounded intersection count')
    # A single ray can graze a shared triangle edge. Independent directions
    # resolve that numerical ambiguity without assuming convex geometry.
    return votes>=2


def main(asset):
    folder=ROOT/'models/living_cast_stage2_20261107'/asset
    receipt=json.loads((folder/'authoring.json').read_text())
    source=folder/(asset+'_living_cast_v001.blend')
    if hashlib.sha256(source.read_bytes()).hexdigest()!=receipt['blend_sha256']:
        raise ValueError('Prop-clearance source is stale')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    rig=next(obj for obj in bpy.context.scene.objects if obj.type=='ARMATURE')
    for track in rig.animation_data.nla_tracks:track.mute=True
    action=bpy.data.actions['Life_Work']
    rig.animation_data.action=action
    rig.animation_data.action_slot=action.slots[0]
    actors=[]
    for obj in bpy.context.scene.objects:
        if obj.type!='MESH' or not obj.vertex_groups:continue
        groups={group.index for group in obj.vertex_groups if group.name.startswith(
            ('lowerarm_','hand_','index_','middle_','ring_','pinky_','thumb_'))}
        indices=[v.index for v in obj.data.vertices if sum(g.weight for g in v.groups if g.group in groups)>=.80]
        if indices:actors.append((obj,indices))
    identity=receipt['profile']['identity']
    carrier=folder.parent/'props'/('station_'+identity+'.glb')
    prop_receipt=json.loads((carrier.with_name('station_'+identity+'_authoring.json')).read_text())
    if hashlib.sha256(carrier.read_bytes()).hexdigest()!=prop_receipt['carrier_sha256']:
        raise ValueError('Supported prop carrier is stale')
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(carrier))
    props=[obj for obj in bpy.data.objects if obj not in before]
    for obj in props:
        if obj.parent is None:obj.location=(0,.40,1.00)
    bpy.context.view_layer.update()
    solids=[];open_parts=[];open_supports=[]
    for obj in props:
        if obj.type!='MESH':continue
        points=[];lookup={};index_map={}
        for vertex in obj.data.vertices:
            point=obj.matrix_world @ vertex.co
            key=tuple(round(v,6) for v in point)
            if key not in lookup:
                lookup[key]=len(points);points.append(point)
            index_map[vertex.index]=lookup[key]
        faces=[[index_map[index] for index in polygon.vertices] for polygon in obj.data.polygons]
        edges=Counter(tuple(sorted((face[i],face[(i+1)%len(face)])))
                      for face in faces for i in range(len(face)))
        bounds=([min(p[i] for p in points) for i in range(3)],
                [max(p[i] for p in points) for i in range(3)])
        if not edges or any(count!=2 for count in edges.values()):
            open_parts.append(obj.name)
            if obj.name in ('RetainedReliefCrate','RetainedSeedTray','RetainedLedgerBinding'):
                open_supports.append((obj.name,BVHTree.FromPolygons(points,faces),bounds))
            continue
        tolerance=.003 if obj.name=='WorkContactPart' and identity in ('nessa','elna') else .002
        solids.append((obj.name,BVHTree.FromPolygons(points,faces),bounds,tolerance))
    intrusions=[]
    for frame in range(121):
        bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
        graph=bpy.context.evaluated_depsgraph_get();hits=[]
        for obj,indices in actors:
            evaluated=obj.evaluated_get(graph);mesh=evaluated.to_mesh()
            for index in indices:
                point=evaluated.matrix_world @ mesh.vertices[index].co
                for name,tree,(minimum,maximum),tolerance in solids:
                    if any(point[i]<=minimum[i] or point[i]>=maximum[i] for i in range(3)):continue
                    closest,normal,face,distance=tree.find_nearest(point)
                    if closest is not None and distance>tolerance and inside_solid(tree,point):
                        hits.append({'prop_mesh':name,'actor_mesh':obj.name,'vertex':index,
                                     'depth':distance,'point':list(point)})
                for name,tree,(minimum,maximum) in open_supports:
                    if any(point[i]<=minimum[i] or point[i]>=maximum[i] for i in range(3)):continue
                    hit,normal,face,distance=tree.ray_cast(point,Vector((0,0,1)),.04)
                    if hit is not None and .002<distance<.04 and abs(normal.z)>.60:
                        hits.append({'prop_mesh':name,'actor_mesh':obj.name,'vertex':index,
                                     'depth':distance,'point':list(point),'method':'beneath actual upward support triangle'})
            evaluated.to_mesh_clear()
        if hits:
            intrusions.append({'phase':frame/120,'vertices':len(hits),'deepest':max(hits,key=lambda hit:hit['depth'])})
    report={'asset':asset,'blend_sha256':receipt['blend_sha256'],'review_glb_sha256':receipt['review_glb_sha256'],
            'prop_sha256':prop_receipt['carrier_sha256'],'sample_hz':30,
            'solid_parts':[entry[0] for entry in solids],'open_parts_not_treated_as_solid':open_parts,
            'open_rigid_supports_checked_by_upward_surface_ray':[entry[0] for entry in open_supports],
            'solid_prop_intrusions':intrusions,'solid_prop_trajectory_clear':bool(solids) and not intrusions,
            'native_verified':False,'visual_accepted':False}
    (folder/'source_prop_clearance.json').write_text(json.dumps(report,indent=2)+'\n')
    print('SOURCE_PROP_CLEARANCE',asset,'solids',len(solids),'open',open_parts,'intrusion_frames',len(intrusions),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--asset',required=True,nargs='+')
    for asset in parser.parse_args(sys.argv[sys.argv.index('--')+1:]).asset:main(asset)
