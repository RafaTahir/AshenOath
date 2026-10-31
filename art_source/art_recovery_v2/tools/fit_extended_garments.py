"""Fit one extended garment's lower skinning before isolated motion inspection."""
import argparse
import hashlib
import json
import sys
import math
from pathlib import Path
import bpy
from mathutils import Matrix
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT.parents[1]/'outputs/AshenOathTheRoadBetweenCrowns'
parser=argparse.ArgumentParser()
parser.add_argument('--id',required=True,choices=tuple('C%02d'%i for i in range(2,13))+('P01',))
parser.add_argument('--revision',default='v001',choices=('v001','v002','v003','v004'))
parser.add_argument('--proportions',action='store_true')
parser.add_argument('--apron-clearance',action='store_true')
parser.add_argument('--waist-binding',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
ledger=json.loads((ROOT/'stylized_roster.json').read_text())
row=next(r for r in ledger['assets'] if r['id']==args.id)
source=Path(row['source_path'])
source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
out=GAME/'art_review/stylized'/args.id/'motionfit'/args.revision
out.mkdir(parents=True,exist_ok=False)
bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False)
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE' and len(o.data.bones)==76)
rig.data.pose_position='REST'
for bone in rig.pose.bones:
    bone.matrix_basis=Matrix.Identity(4)
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('stylized_runtime',False)]
if not meshes:
    raise ValueError('No authored runtime pieces')
proportions={
    'C04':(.23,.20,.22,.18,.12,.22),
    'C11':(.16,.43,.24,.36,.18,.12),
    'C10':(.06,.48,.12,.39,.10,.06),
}
if args.proportions:
    if args.id not in proportions:
        raise ValueError('Proportion correction is limited to the three reviewed builds')
    chest,waist,hips,depth,cheek,forearm=proportions[args.id]
    head=rig.data.bones['Head'].head_local.z
    for obj in meshes:
        bpy.context.view_layer.objects.active=obj
        obj.select_set(True)
        if obj.data.shape_keys:
            bpy.ops.object.shape_key_remove(all=True,apply_mix=True)
        for vertex in obj.data.vertices:
            p=vertex.co
            mask=math.exp(-(abs(p.x)/.44)**6)
            c=math.exp(-((p.z-1.30)/.18)**2)*mask
            w=math.exp(-((p.z-1.12)/.19)**2)*mask
            h=math.exp(-((p.z-.98)/.16)**2)*mask
            p.x*=1+chest*c+waist*w+hips*h
            p.y=.025+(p.y-.025)*(1+depth*max(c,w,h))
            if args.id in ('C11','C10'):
                p.y-=.025*w
            face=math.exp(-((p.z-head-.042)/.055)**2)*math.exp(-(abs(p.x)/.14)**6)
            neck=math.exp(-((p.z-head+.045)/.045)**2)*math.exp(-(abs(p.x)/.10)**6)
            p.x*=1+cheek*face+.12*neck
            p.y=.025+(p.y-.025)*(1+.08*neck)
            for side in ('l','r'):
                a=rig.data.bones['lowerarm_'+side].head_local
                b=rig.data.bones['hand_'+side].head_local
                axis=b-a
                t=(p-a).dot(axis)/axis.length_squared
                if 0<t<1:
                    radial=p-(a+axis*t)
                    if radial.length<.115:
                        p+=radial*forearm*math.sin(math.pi*t)
        obj.data.update()
hip=rig.data.bones['pelvis'].head_local.z
knee=rig.data.bones['calf_l'].head_local.z
changed=0
if args.apron_clearance:
    if args.id not in ('C03','C04','C09','C11'):
        raise ValueError('Clearance repair is limited to the observed layered garments')
    for obj in meshes:
        if obj.data.shape_keys:
            bpy.context.view_layer.objects.active=obj
            obj.select_set(True)
            bpy.ops.object.shape_key_remove(all=True,apply_mix=True)
    underlayer=next(o for o in meshes if o.name.endswith('_Body'))
    underlayer.data.calc_loop_triangles()
    triangles=[tuple(t.vertices) for t in underlayer.data.loop_triangles]
    points=[v.co.copy() for v in underlayer.data.vertices]
    tree=BVHTree.FromPolygons(points,triangles,all_triangles=True)
    def surface_weights(p):
        hit,normal,index,_=tree.ray_cast(Vector((p.x,-.9,p.z)),Vector((0,1,0)),1.8)
        if hit is None:
            hit,normal,index,_=tree.find_nearest(p)
        if hit is None:
            raise ValueError('Garment has no retained surface support')
        a,b,c=(points[i] for i in triangles[index])
        ab,ac,ap=b-a,c-a,hit-a
        aa,bb,cc=ab.dot(ab),ab.dot(ac),ac.dot(ac)
        denominator=aa*cc-bb*bb
        if abs(denominator)<1e-12:
            blend=(1.,0.,0.)
        else:
            v=(cc*ap.dot(ab)-bb*ap.dot(ac))/denominator
            w=(aa*ap.dot(ac)-bb*ap.dot(ab))/denominator
            blend=(1-v-w,v,w)
        values={}
        for vi,amount in zip(triangles[index],blend):
            for group in underlayer.data.vertices[vi].groups:
                name=underlayer.vertex_groups[group.group].name
                values[name]=values.get(name,0.)+group.weight*max(0.,amount)
        return hit,values
    def assign(obj,vertex,values):
        values=dict(sorted(values.items(),key=lambda pair:pair[1],reverse=True)[:4])
        total=sum(values.values())
        if total<=0:
            raise ValueError('Underlayer has no usable garment binding')
        for group in obj.vertex_groups:
            group.remove([vertex.index])
        for name,value in values.items():
            if value>0:
                group=obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
                group.add([vertex.index],value/total,'REPLACE')
    if args.waist_binding:
        # The separate trousers' upper seam was moving through the outer
        # garment. Match that concealed waist to its actual outer-layer owner,
        # retaining original leg articulation below the short transition.
        for obj in meshes:
            if not obj.name.endswith('_Legs'):
                continue
            for vertex in obj.data.vertices:
                t=max(0.,min(1.,(vertex.co.z-(hip-.12))/.20))
                if t<=0:
                    continue
                _,values=surface_weights(vertex.co)
                old={obj.vertex_groups[g.group].name:g.weight for g in vertex.groups}
                mixed={name:weight*(1-t) for name,weight in old.items()}
                for name,weight in values.items():
                    mixed[name]=mixed.get(name,0.)+weight*t
                assign(obj,vertex,mixed)
                changed+=1
    for obj in meshes:
        if not any(label in obj.name for label in ('Apron','ArchiveTabard')):
            continue
        for vertex in obj.data.vertices:
            p=vertex.co.copy()
            hit,values=surface_weights(p)
            assign(obj,vertex,values)
            # Keep its authored contour; move only inward points out of the
            # underlayer, with explicit clearance for the matching deformation.
            vertex.co.y=min(p.y,hit.y-.035)
            changed+=1
        obj.data.update()
for obj in meshes:
    if args.apron_clearance:
        continue
    if args.id not in ('C03','C05','C07','C08','C09','C11','C12','P01') or not any(token in obj.name for token in ('_Body','Overcoat','Apron','Tabard')):
        continue
    points=obj.data.shape_keys.key_blocks[-1].data if obj.data.shape_keys else obj.data.vertices
    for vertex,point in zip(obj.data.vertices,points):
        p=point.co
        t=max(0.,min(1.,(hip-.04-p.z)/.28))
        if not t:
            continue
        old={obj.vertex_groups[g.group].name:g.weight for g in vertex.groups if g.weight>0}
        left=max(0.,min(1.,p.x/.15+.5))
        calf=max(0.,min(.85,(knee+.06-p.z)/.28))
        values={name:value*(1-t) for name,value in old.items()}
        for side,weight in [('l',left),('r',1-left)]:
            for name,value in [('thigh_'+side,weight*(1-calf)),('calf_'+side,weight*calf)]:
                values[name]=values.get(name,0)+value*t
        values=dict(sorted(values.items(),key=lambda pair:pair[1],reverse=True)[:4])
        total=sum(values.values())
        for group in obj.vertex_groups:
            group.remove([vertex.index])
        for name,value in values.items():
            if value>1e-7:
                group=obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
                group.add([vertex.index],value/total,'REPLACE')
        changed+=1
sys.path.insert(0,str(ROOT/'tools'))
import stylized_humans as humans
humans.bpy,humans.Vector,humans.Matrix=bpy,Vector,Matrix
body=next(o for o in meshes if o.name.endswith('_Body'))
points=body.data.shape_keys.key_blocks[-1].data if body.data.shape_keys else body.data.vertices
surface=BVHTree.FromPolygons([p.co.copy() for p in points],[list(f.vertices) for f in body.data.polygons])
loops=0
for prop in list(meshes):
    if 'LegacyBeltKeepsakeSalvage' not in prop.name or not prop.data.vertices:
        continue
    if any(o.name.startswith(args.id+'_AttachedBeltLoop') for o in meshes):
        continue
    top=max(prop.data.vertices,key=lambda v:v.co.z).co.copy()
    anchor,normal,_,_=surface.find_nearest(top+Vector((0,.035,.12)))
    if anchor is None:
        raise ValueError('Kept equipment has no garment attachment surface')
    anchor+=normal*.009
    if (anchor-top).length>.012:
        atlas=next((m for o in meshes for m in o.data.materials if m and 'ClothesAtlas' in m.name),None)
        if atlas is None:
            raise ValueError('Missing retained leather atlas for belt loop')
        strap=humans.tube(args.id+'_AttachedBeltLoop',[anchor,anchor.lerp(top,.5)+Vector((0,-.004,0)),top],
                          .0045,rig,atlas,bone='pelvis',tile=3)
        meshes.append(strap)
        loops+=1
copies=[]
for obj in meshes:
    copy=obj.copy()
    copy.data=obj.data.copy()
    bpy.context.collection.objects.link(copy)
    bpy.context.view_layer.objects.active=copy
    copy.select_set(True)
    if copy.data.shape_keys:
        bpy.ops.object.shape_key_remove(all=True,apply_mix=True)
    for modifier in list(copy.modifiers):
        if modifier.type!='ARMATURE':
            bpy.ops.object.modifier_move_to_index(modifier=modifier.name,index=0)
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    copies.append(copy)
bpy.ops.object.select_all(action='DESELECT')
for obj in copies:
    obj.select_set(True)
bpy.context.view_layer.objects.active=copies[0]
bpy.ops.object.join()
compiled=bpy.context.object
compiled.name=args.id+'_MotionFittedAssembly'
rig.select_set(True)
bpy.context.view_layer.objects.active=rig
glb=out/(args.id+'_motionfit.glb')
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_skins=True,
                          export_animations=False,export_yup=True,export_extras=True)
bpy.data.objects.remove(compiled,do_unlink=True)
rig.data.pose_position='POSE'
humans.relaxed_pose(rig)
humans.render_previews({'asset':args.id,'evidence':out},rig,meshes)
model=ROOT/'models'/(source.stem+'_motionfit_'+args.revision+'.blend')
if model.exists():
    raise FileExistsError(model)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(model),compress=True)
if hashlib.sha256(source.read_bytes()).hexdigest()!=source_hash:
    raise ValueError('Original authored source changed')
(out/'candidate.json').write_text(json.dumps({'id':args.id,'source_path':str(model),'runtime_path':str(glb),
    'source':str(source),'source_sha256':source_hash,'lower_garment_vertices_fitted':changed,'belt_attachment_loops':loops,
    'local_rest_matrices_changed':False,'user_accepted':False,'proportion_correction':args.proportions,'apron_clearance':args.apron_clearance,'waist_binding':args.waist_binding,
    'limitations':row['limitations']+' Extended lower garments now blend into retained thigh/calf chains with four normalized influences; this is skinning, not cloth simulation or motion acceptance.'},indent=2)+'\n')
print('EXTENDED_GARMENT_FITTED',args.id,changed,flush=True)
