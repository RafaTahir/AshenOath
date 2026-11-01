"""Tailored retained wildlife revisions. Run ONE --asset per Blender invocation.

The latest production GLB is the immutable input. Rigs, clips, existing image
bindings and world scale are retained; derivatives never overwrite production.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT.parents[1] / 'outputs/AshenOathTheRoadBetweenCrowns'
IDS = tuple(f'M{i:02}' for i in range(7, 19))
BONE_AXES = {}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_asset(asset, override=None):
    registry = json.loads((GAME/'data/design_pack_assets.json').read_text())
    source = Path(override) if override else GAME / registry['assets'][asset]['path'][6:]
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(source))
    rigs = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.vertex_groups and not o.hide_render]
    if len(rigs) != 1 or not meshes:
        raise ValueError('Expected one retained native rig with meshes')
    rig = rigs[0]
    if rig.animation_data:
        rig.animation_data.action = None
        for track in rig.animation_data.nla_tracks:
            track.mute = True
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    return source, registry['assets'][asset]['path'], rig, meshes


def bbox(points):
    return [list(map(float, (min(p[k] for p in points) for k in range(3)))),
            list(map(float, (max(p[k] for p in points) for k in range(3))))]


def vertex_tile(obj):
    tiles = {}
    uv = obj.data.uv_layers.active
    if uv:
        for p in obj.data.polygons:
            co = uv.data[p.loop_start].uv
            tile = min(3, max(0, int(co.x*4))) + 4*min(1, max(0, int(co.y*2)))
            for idx in p.vertices:
                tiles.setdefault(idx, tile)
    return tiles


def inspect(rig, meshes):
    records = []
    for o in meshes:
        tiles = vertex_tile(o)
        groups = {}
        for v in o.data.vertices:
            dominant = max(v.groups, key=lambda g:g.weight).group if v.groups else -1
            bone = o.vertex_groups[dominant].name if dominant >= 0 else ''
            key = (bone, tiles.get(v.index, -1))
            groups.setdefault(key, []).append(o.matrix_world @ v.co)
        records.append({'object':o.name, 'bounds':bbox([o.matrix_world @ v.co for v in o.data.vertices]),
                        'groups':[{'bone':k[0],'tile':k[1],'count':len(v),'bounds':bbox(v)} for k,v in groups.items() if len(v)>8]})
    return {'objects':records,'bones':{b.name:list(rig.matrix_world @ b.head_local) for b in rig.data.bones},
            'actions':[a.name for a in bpy.data.actions]}


def component_report(meshes):
    result=[]
    for o in meshes:
        parent=list(range(len(o.data.vertices)))
        def root(i):
            while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
            return i
        for e in o.data.edges:
            a,b=map(root,e.vertices);parent[b]=a
        groups={}
        for v in o.data.vertices:groups.setdefault(root(v.index),[]).append(v)
        tiles=vertex_tile(o)
        for group in groups.values():
            if len(group)>30:
                result.append({'count':len(group),'tile':tiles.get(group[0].index),'bounds':bbox([o.matrix_world@v.co for v in group])})
    return result


def repair_tube_frames(meshes):
    """Correct retained annulus correspondence at frame sign changes.

    The original mesher chose tangent.cross(Y) independently for each ring.
    When tangent.x changes sign its circular frame jumps by 180 degrees, so
    adjoining quads twist through the body. UV rows retain the original ring
    correspondence, allowing a repair without replacing the sculpt or rig.
    """
    fixed=0
    for o in meshes:
        parent=list(range(len(o.data.vertices)))
        def root(i):
            while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
            return i
        for e in o.data.edges:
            a,b=map(root,e.vertices);parent[b]=a
        groups={}
        for v in o.data.vertices:groups.setdefault(root(v.index),[]).append(v.index)
        body=max(groups.values(),key=len)
        if len(body)<3000:raise ValueError('Retained annulated body no longer matches source')
        uvmap={}
        for p in o.data.polygons:
            for li in p.loop_indices:
                uvmap.setdefault(o.data.loops[li].vertex_index,o.data.uv_layers.active.data[li].uv.copy())
        rows={}
        for i in body:rows.setdefault(round(uvmap[i].y,5),[]).append(i)
        if len(rows)!=97 or any(len(r)!=37 for r in rows.values()):
            raise ValueError(f'Expected exactly 97 retained rings of 37 UV vertices, got {len(rows)} rows')
        previous=None
        for _,indices in sorted(rows.items()):
            indices.sort(key=lambda i:uvmap[i].x)
            points=[o.data.vertices[i].co.copy() for i in indices[:36]]
            center=sum(points,Vector())/36
            direction=(points[0]-center).normalized()
            if previous is not None and previous.dot(direction)<0:
                weights=[[(g.group,g.weight) for g in o.data.vertices[i].groups] for i in indices[:36]]
                for j,i in enumerate(indices):
                    source=(j+18)%36
                    o.data.vertices[i].co=points[source]
                    for g in list(o.data.vertices[i].groups):o.vertex_groups[g.group].remove([i])
                    for g,w in weights[source]:o.vertex_groups[g].add([i],w,'REPLACE')
                direction=(points[18]-center).normalized()
                fixed+=1
            previous=direction
        o.data.normals_split_custom_set([(0.,0.,0.)]*len(o.data.loops))
        o.data.update()
    if fixed==0:raise ValueError('Expected original frame flips were not found')
    return {'rings_realigned':fixed,'ring_vertices':37,'retained_ring_count':97,
            'method':'UV-row correspondence; half-turn ring reindexing with matched skin weights; no added geometry'}


def signature(rig):
    return sha_bytes(json.dumps([(b.name, b.parent.name if b.parent else None,
                                 [list(row) for row in b.matrix_local]) for b in rig.data.bones],sort_keys=True).encode())


def sha_bytes(value):
    return hashlib.sha256(value).hexdigest()


def smoothstep(a,b,x):
    t=max(0.,min(1.,(x-a)/(b-a)))
    return t*t*(3.-2.*t)


def dominant(obj, vertex):
    return obj.vertex_groups[max(vertex.groups,key=lambda g:g.weight).group].name if vertex.groups else ''


def revise_point(asset, p, tile, bone, bounds):
    x,y,z=p
    lo,hi=bounds
    h=max(.01,hi[2]-lo[2]);w=max(.01,hi[0]-lo[0]);length=max(.01,hi[1]-lo[1])
    if asset=='M18':
        # Cambered load-bearing disc with flexible outer fin edges. Existing
        # eyes/gills follow exactly the same continuous spatial field.
        core=math.exp(-((x/.59)**2)-(((y-.02)/1.05)**4)) if y<1.05 else 0.
        if z>.145:z += core * (z-.145)*1.55
        if abs(x)>.6 and y<.85:
            z += .045*smoothstep(.6,1.4,abs(x))*(.4+.6*math.cos(y*2.1))
        if y>1.05:
            t=smoothstep(1.05,2.93,y)
            x += .13*math.sin(t*math.pi)
            z += .055*math.sin(t*math.pi)
        # Seat the eyes without changing the fin/sucker/body topology.
        if tile==3 and p.z>.22:
            z -= .025*core
        elif tile==3 and p.z<.09:
            z += .022
        elif tile==1 and p.z<.09:
            z += .018
    elif asset=='M09':
        # Shovel-like anterior mass and broad flattened belly distinguish this
        # substrate digger from the circular suction-fed Knell Leech.
        front=1-smoothstep(lo[1]+length*.18,lo[1]+length*.55,y)
        if bone in {'Head','Jaw'}:
            x *= 1+.16*front
            z -= .035*front
        if z < lo[2]+h*.42:
            z=lo[2]+(z-lo[2])*.76
        x *= 1+.025*math.sin((y-lo[1])/length*math.pi*3)*math.sin((y-lo[1])/length*math.pi)
    elif asset=='M12':
        # Strong anterior cup and a softer compressed low belly; nonuniform
        # longitudinal contraction leaves the retained suction opening intact.
        t=(y-lo[1])/length
        if bone in {'Head','Jaw'} or t<.13:
            center=lo[2]+h*.48
            x*=1.1
            z=center+(z-center)*1.1
        if .14<t<.9:
            y += length*.012*math.sin(t*math.pi*3)
            x *= 1-.045*math.sin(t*math.pi)**2
        if z<lo[2]+h*.22:z=lo[2]+(z-lo[2])*.7
    elif asset=='M08':
        # Refine the actual stag, retaining antler attachments and hoof stance.
        if 'head' in bone.lower() and 'horn' not in bone.lower():
            x*=.985
        if ('neck' in bone.lower()) and z>lo[2]+h*.43:
            x*=.965
        if 'stag_horns' in bone.lower():pass
        # Avoid altering the antler/leg envelope: a bounded shoulder rise only.
        shoulder=math.exp(-((y-(lo[1]+length*.37))/(length*.14))**2)
        if z>lo[2]+h*.3 and z<lo[2]+h*.58 and abs(x)<w*.25:
            z+=h*.008*shoulder
    elif asset=='M07':
        # More angular sternum, hooked cranial profile and a loaded membrane.
        if 'head' in bone.lower() or 'jaw' in bone.lower():
            x*=.94
            if y<lo[1]+length*.22:z-=h*.018
        if 'wing' in bone.lower() and abs(x)>w*.15:
            s=smoothstep(w*.15,w*.48,abs(x))
            z-=h*.035*math.sin(s*math.pi)
        if bone in {'Body','Chest','Spine'} and z>lo[2]+h*.35:
            x*=.96
    elif asset=='M10':
        # Broad layered shell shoulder with a firm lower rim; walking-leg root
        # attachment remains fixed rather than scaling the entire creature.
        if tile==4 and bone in {'Body','Shell'}:
            t=(z-lo[2])/h
            if y>.06:y=.06+(y-.06)*1.28
            if t>.5:
                x*=1+.045*math.sin(min(1.,(t-.5)*2)*math.pi)
                z+=h*.025*smoothstep(.55,.9,t)
        if tile==0 and bone=='Body' and y>.2 and z>lo[2]+h*.5:
            z-=h*.21*smoothstep(.2,.7,y)*smoothstep(.5,.85,(z-lo[2])/h)
        if 'claw' in bone.lower() or 'pincer' in bone.lower():
            z-=h*.015
    elif asset=='M11':
        if 'wing' in bone.lower():
            # Preserve four independent wing bones, increase camber at their
            # midspan, and turn the existing edge into a softer scallop.
            s=min(1.,abs(x)/(w*.5))
            z += h*.04*math.sin(s*math.pi)
        if bone in {'Body','Thorax'}:
            z += h*.012*math.exp(-((y-(lo[1]+length*.5))/(length*.15))**2)
    elif asset=='M13':
        if tile in {0,4} and bone in {'Head','Jaw'}:
            x*=1.07
            z-=h*.023
        if 'Body'==bone and tile==0:
            x*=1.012
        if tile in {4,5} and z>lo[2]+h*.55:
            z+=h*.027*math.cos(y*3)
    elif asset=='M14':
        if bone in {'Body','Abdomen'}:
            # Rear-heavy pear abdomen and compact thorax, no new limb topology.
            t=(y-lo[1])/length
            x*=1+.08*smoothstep(.35,.85,t)
            z+=h*.028*smoothstep(.4,.8,t)
        if 'leg' in bone.lower() and z>lo[2]+h*.55:
            z+=h*.012
    elif asset=='M15':
        if bone in {'Head','Jaw'}:
            x*=1.07
        if bone=='Body' and tile==0:
            if z>lo[2]+h*.35:z-=h*.012
        if 'AirSac' in bone:
            x*=1.012
            z-=h*.008
    elif asset=='M16':
        if bone in {'Body','Shell'} and tile==4:
            # Raise the existing low wedge over the soft abdomen instead of
            # leaving a detached-looking rear body beyond its protection.
            z=.15+(z-.15)*1.7
            if y>.08:y=.08+(y-.08)*1.2
            x*=1.045
        elif bone=='Body' and tile==0 and z>lo[2]+h*.55:
            z-=h*.07*smoothstep(.55,.95,(z-lo[2])/h)
        if 'Head'==bone:
            x*=1.04
    elif asset=='M17':
        if bone=='Body' and z<lo[2]+h*.22:
            z=lo[2]+(z-lo[2])*.78
            x*=1.07
        if 'shell' in bone.lower() or tile in {4,5}:
            # Unequal mineral shelves follow the existing spiral, not added
            # floating pyramids. Preserve the shell's overall silhouette.
            z+=h*.006*math.sin(y*9+x*4)
    result=Vector((x,y,z))
    if asset in {'M10','M14','M16'} and bone.startswith('Leg') and tile==0 and bone in BONE_AXES:
        a,b=BONE_AXES[bone];axis=b-a
        t=max(0.,min(1.,(p-a).dot(axis)/axis.length_squared))
        anchor=a+axis*t
        radial=result-anchor
        axial=axis.normalized()*radial.dot(axis.normalized())
        radial-=axial
        amount=.22 if asset=='M14' else .16 if asset=='M16' else .10
        profile=1+amount*math.sin(t*math.pi)-.10*smoothstep(.68,1.,t)
        result=anchor+axial+radial*profile
    return result


RECIPES={
 'M07':['Narrow hooked cranial planes and angular sternum','Camber retained skinned membranes between wing supports','Retain two-leg/two-wing anatomy and all native state actions'],
 'M08':['Refine bounded shoulder rise and neck/head width on the native stag','Preserve antler attachment, hoof placement and ivory identity','Retain original horn/hoof/coat atlas separation under a matte coat response'],
 'M09':['Repair inherited half-turn tube-frame discontinuities using retained UV-ring correspondence','Broaden anterior shovel/jaw mass','Flatten digging belly and vary body contraction','Wet low-roughness skin differentiates it from terrestrial species'],
 'M10':['Extend supported carapace rearward over the exposed dorsal abdomen','Seat soft dorsal tissue beneath the protective crown and set working claws lower','Polished shell response with retained atlas and native claws'],
 'M11':['Camber each of four separately controlled membrane wings','Increase thorax continuity','Retain bounded translucent membranes and native wing controls'],
 'M12':['Repair inherited half-turn tube-frame discontinuities using retained UV-ring correspondence','Enlarge anterior suction cup relative to body','Unequal longitudinal contraction and low belly','Smooth moist skin and retained recessed tooth topology'],
 'M13':['Broaden low snout and lower jaw planes','Give existing shoulder plates slight unequal lift','Retain native quadruped/tail rig and original shield topology'],
 'M14':['Rear-heavy abdomen and more compact front body','Give existing leg tubes fusiform femurs and tapered tibiae around retained bone axes','Lift leg arches subtly while preserving foot coordinates','Dark keratin response with restrained abdomen highlights'],
 'M15':['Broader amphibian jaw','Set dorsal sac junctions closer to torso','Retain inflation morphs, leg chains and native clips'],
 'M16':['Lift and extend existing protective shield over the exposed soft dorsal abdomen','Broaden blind feeding head and give retained leg tubes tapered profiles','Retain antenna/brush/leg chains without adding eyes'],
 'M17':['Broaden and flatten muscular sole','Unequal mineral shelves on the actual spiral','Separate coarse stone response from living sole in vertex values'],
 'M18':['Thicken central ray disc through a continuous camber field','Seat eyes into the dorsal body and raise flexible outer fins','Bend unbarbed tail into a soft aquatic curve while retaining all controls'],
}


def author(asset, meshes):
    allpoints=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
    bounds=bbox(allpoints)
    for o in meshes:
        tilemap=vertex_tile(o)
        inverse=o.matrix_world.inverted()
        # Transform every retained morph with the same field, so authored sac
        # deformation remains relative to its revised anatomical attachment.
        keys=list(o.data.shape_keys.key_blocks) if o.data.shape_keys else []
        for v in o.data.vertices:
            bone=dominant(o,v);tile=tilemap.get(v.index,0)
            if keys:
                for key in keys:
                    p=o.matrix_world@key.data[v.index].co
                    key.data[v.index].co=inverse@revise_point(asset,p,tile,bone,bounds)
                v.co=keys[0].data[v.index].co
            else:
                v.co=inverse@revise_point(asset,o.matrix_world@v.co,tile,bone,bounds)
        for face in o.data.polygons:face.use_smooth=True
        o.data.update()
    rough={'M07':.71,'M08':.87,'M09':.43,'M10':.50,'M11':.52,'M12':.32,
           'M13':.72,'M14':.59,'M15':.48,'M16':.54,'M17':.87,'M18':.51}[asset]
    for m in {m for o in meshes for m in o.data.materials if m}:
        m.roughness=rough
        if m.use_nodes:
            node=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
            if node:
                node.inputs['Roughness'].default_value=rough
                if asset in {'M09','M10','M12','M15','M16','M18'}:
                    node.inputs['Coat Weight'].default_value=.14 if asset!='M12' else .22
                    node.inputs['Coat Roughness'].default_value=.28
    return bounds


def metrics(meshes):
    return {'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),
            'vertices':sum(len(o.data.vertices) for o in meshes),
            'meshes':len(meshes),
            'geometry_sha256':sha_bytes(b''.join(struct.pack('<fff',*v.co) for o in meshes for v in o.data.vertices)),
            'bounds_blender_z_up':bbox([o.matrix_world@v.co for o in meshes for v in o.data.vertices])}


def render(meshes, folder):
    scene=bpy.context.scene
    scene.render.engine='BLENDER_WORKBENCH'
    scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.display.shading.light='STUDIO'
    scene.display.shading.studiolight_rotate_z=.5
    scene.display.shading.color_type='TEXTURE'
    scene.display.shading.show_shadows=True
    scene.display.shading.show_cavity=True
    scene.display.shading.cavity_type='BOTH'
    scene.display.shading.curvature_ridge_factor=1.2
    scene.display.shading.curvature_valley_factor=.9
    scene.display.shading.background_type='WORLD'
    scene.world.color=(.13,.14,.15)
    for obj in bpy.context.scene.objects:
        if obj.type=='MESH' and obj not in meshes:obj.hide_render=True
    points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
    lo,hi=map(Vector,bbox(points));center=(lo+hi)/2
    span=hi-lo;size=max(span)*1.2
    camera_data=bpy.data.cameras.new('RefinementReviewCamera')
    camera=bpy.data.objects.new('RefinementReviewCamera',camera_data)
    scene.collection.objects.link(camera);scene.camera=camera
    camera_data.type='ORTHO';camera_data.ortho_scale=size
    output=[]
    for name,direction in [('front',(0,-1,.18)),('side',(1,0,.12)),('rear',(0,1,.18)),('quarter',(.85,-1,.6))]:
        camera.location=center+Vector(direction).normalized()*size*3
        camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
        path=folder/(name+'.png');scene.render.filepath=str(path)
        bpy.ops.render.render(write_still=True)
        output.append(str(path))
    return output


def glb_info(path):
    b=path.read_bytes();n=struct.unpack_from('<I',b,12)[0];d=json.loads(b[20:20+n])
    return {'animations':[a.get('name') for a in d.get('animations',[])],
            'clip_durations':{a['name']:max(d['accessors'][s['input']]['max'][0] for s in a['samplers'])-
                              min(d['accessors'][s['input']]['min'][0] for s in a['samplers'])
                              for a in d.get('animations',[])},
            'joints':sum(len(s['joints']) for s in d.get('skins',[])),
            'images':len(d.get('images',[])),
            'triangles':sum(d['accessors'][p['indices']]['count']//3 for m in d.get('meshes',[]) for p in m['primitives'] if 'indices'in p)}


def run(asset, source, destination, rig, meshes, revision=''):
    model_dir=ROOT/'models/refinement_20261101/wildlife'/asset
    evidence=ROOT/'evidence/refinement_20261101/wildlife'/asset
    output=GAME/'art_review/refinement_20261101/wildlife'/asset
    if revision:
        model_dir=model_dir/revision;evidence=evidence/revision;output=output/revision
    for p in [model_dir,evidence,output]:p.mkdir(parents=True,exist_ok=False)
    original_sha=sha(source);before=metrics(meshes);rig_sha=signature(rig)
    BONE_AXES.clear()
    BONE_AXES.update({b.name:(rig.matrix_world@b.head_local,rig.matrix_world@b.tail_local) for b in rig.data.bones})
    original_contract=glb_info(source)
    original_clips=original_contract['animations']
    tube_repair=repair_tube_frames(meshes) if asset in {'M09','M12'} else None
    author(asset,meshes)
    after=metrics(meshes)
    if signature(rig)!=rig_sha:raise ValueError('Native rest rig changed')
    if before==after:raise ValueError('No measured geometry refinement')
    for image in bpy.data.images:
        if image.source=='FILE' and image.has_data:
            try:image.pack()
            except RuntimeError:pass
    bpy.ops.object.select_all(action='DESELECT')
    for o in [rig]+meshes:
        o.select_set(True)
        ancestor=o.parent
        while ancestor:ancestor.select_set(True);ancestor=ancestor.parent
    bpy.context.view_layer.objects.active=rig
    rig.data.pose_position='POSE'
    for t in rig.animation_data.nla_tracks:t.mute=False
    runtime=output/(asset+'_refined_20261101.glb')
    bpy.ops.export_scene.gltf(filepath=str(runtime),export_format='GLB',use_selection=True,
        export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,
        export_skins=True,export_yup=True,export_all_influences=False,export_extras=True)
    info=glb_info(runtime)
    if set(info['animations'])!=set(original_clips):
        raise ValueError(f'Clip identity changed: {original_clips} -> {info["animations"]}')
    if any(abs(info['clip_durations'][name]-duration)>1e-5 for name,duration in original_contract['clip_durations'].items()):
        raise ValueError('Native clip duration changed')
    if info['joints']!=len(rig.data.bones):
        # Stag's two independently skinned mesh bindings repeat the same joints.
        if info['joints']!=glb_info(source)['joints']:raise ValueError('Skin joint count changed')
    rig.data.pose_position='REST'
    for t in rig.animation_data.nla_tracks:t.mute=True
    views=render(meshes,evidence)
    blend=model_dir/(asset+'_refined_20261101.blend')
    rig['refinement_input_sha256']=original_sha
    rig['refinement_recipe']='; '.join(RECIPES[asset])
    bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
    if sha(source)!=original_sha:raise ValueError('Immutable source was modified')
    record={'id':asset,'source_path':str(blend),'runtime_path':str(runtime),'destination_resource':destination,
      'input_path':str(source),'input_sha256':original_sha,'changes':RECIPES[asset],
      'metrics_before':before,'metrics_after':after,'export_metrics':info,'views':views,
      'source_sha256':sha(blend),'runtime_sha256':sha(runtime),'runtime_bytes':runtime.stat().st_size,
      'rig_signature':rig_sha,'retained_clips':original_clips,'texture_policy':'Original image bindings retained and embedded',
      'tube_frame_repair':tube_repair,
      'user_accepted':False,'integrated':False,'gameplay_tested':False,
      'limitations':['Tailored retained-mesh refinement, not complete anatomical reconstruction.',
        'Existing animation keys retained; rig fitting and in-game articulation require inspection.',
        'Workbench studio previews show silhouette/texture; do not establish final level lighting or performance.']}
    (output/'candidate.json').write_text(json.dumps(record,indent=2)+'\n')
    print('WILDLIFE_CANDIDATE='+str(output/'candidate.json'))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--asset', choices=IDS, required=True)
    parser.add_argument('--inspect', action='store_true')
    parser.add_argument('--components',action='store_true')
    parser.add_argument('--revision',default='')
    parser.add_argument('--input',default=None)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    source, destination, rig, meshes = load_asset(args.asset,args.input)
    if args.components:
        print('WILDLIFE_COMPONENTS='+json.dumps(component_report(meshes)));return
    if args.inspect:
        print('WILDLIFE_INSPECT='+json.dumps(inspect(rig, meshes)))
        return
    run(args.asset,source,destination,rig,meshes,args.revision)


if __name__ == '__main__':
    main()
