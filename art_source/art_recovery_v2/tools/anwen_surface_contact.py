"""Correct the observed scalp normal and scarf support defects from v019."""
import bpy,math,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(HERE.parents[0]/'design_pack_v1/tools'))
import build_anwen as shared
bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_crafted_v019.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
head=bpy.data.objects['Anwen_MatureFace_Neck']
tree=BVHTree.FromObject(head,bpy.context.evaluated_depsgraph_get())
cap=bpy.data.objects['Anwen_Hair_v004_FittedRoots']
for v in cap.data.vertices:
    hit,normal,_,_=tree.find_nearest(v.co)
    a=math.atan2(hit.x+.012,.010-hit.y)
    top=max(0,min(1,(hit.z-1.66)/.12))
    part=math.exp(-((hit.x+.012)/.009)**2)*max(0,min(1,(.06-hit.y)/.13))
    v.co=hit+normal*(.0022+(.002+.004*math.sin(a*3.3+hit.z*55)**2)*top*(1-.8*part))
cap.data.update()
for poly in cap.data.polygons:
    _,normal,_,_=tree.find_nearest(poly.center)
    if poly.normal.dot(normal)<0:poly.flip()
plait=bpy.data.materials['Anwen_Ash_Plait_Fibers']
for obj in bpy.data.objects:
    if obj.name.startswith('Anwen_Hair_v019_SidePlait'):
        obj.data.materials[0]=plait
for obj in list(bpy.data.objects):
    if obj.name.startswith('Anwen_v019_Wrapped_Scarf_'):
        bpy.data.objects.remove(obj,do_unlink=True)
mat=bpy.data.materials['Anwen_Ash_Wool_Shawl']
def weights(p):
    arm=max(0,min(.20,(abs(p.x)-.16)*2.5))
    return {'spine_03':1-arm,'upperarm_l' if p.x>0 else 'upperarm_r':arm}
for layer in range(2):
    verts=[];faces=[];uv=[];rows=32;cols=160
    for row in range(rows+1):
        t=row/rows
        for col in range(cols+1):
            a=math.tau*col/cols
            front=max(0,math.cos(a));back=max(0,-math.cos(a))
            q=t if layer==0 else .16+.64*t
            rx=.061+.188*math.sin(q*math.pi/2)
            ry=.059+.099*math.sin(q*math.pi/2)
            z=1.480-q*(.141+.105*back)
            z+=.013*math.sin(a-.6)*q+.006*math.sin(a*4+q*2)*q
            if layer:z+=.015
            fold=(.009*math.cos(q*math.pi*5+a*.4)+.003*math.sin(q*math.pi*9-a))*math.sin(math.pi*q)**.8
            x=(rx+fold)*math.sin(a);y=.025-(ry+fold)*math.cos(a)
            if layer:y-=.003*front
            verts.append((x,y,z));uv.append((col/cols,q))
            if row and col:
                k=row*(cols+1)+col;faces.append((k-cols-2,k-1,k,k-cols-1))
    obj=shared.mesh_object('Anwen_v020_Fitted_Scarf_'+str(layer),verts,faces,mat,uv)
    shared.bind(obj,rig,weights)
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Turned wool edge','SOLIDIFY');mod.thickness=.0025
    bpy.ops.object.modifier_move_up(modifier=mod.name);bpy.ops.object.modifier_apply(modifier=mod.name)
rig['art_status']='REWORK_v020_NOT_ACCEPTED'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_contact_v020.blend'),compress=True)
scene=bpy.context.scene;scene.cycles.samples=32
out=HERE/'evidence/anwen_v020';out.mkdir(parents=True,exist_ok=True)
cam=scene.camera
for label,pos,target,size in [('quarter_face',(.8,-2,1.70),(0,0,1.666),.38),
    ('quarter',(2.5,-4,1.6),(0,0,.95),2.12),('rear',(0,4,1.2),(0,0,.92),2.12),
    ('cloth_detail',(.3,-2,1.2),(0,-.02,1.32),.64)]:
    cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=size;scene.render.filepath=str(out/(label+'.png'))
    bpy.ops.render.render(write_still=True)
print('SURFACE_CONTACT_SOURCE_COMPLETE',flush=True)
