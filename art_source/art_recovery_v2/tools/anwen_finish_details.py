"""Tailored shoulder closure and reference-specific worn belt/bell details."""
import bpy,math,sys,random
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(HERE.parents[0]/'design_pack_v1/tools'))
import build_anwen as shared
bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_contact_v020.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')

# Tailor the shoulder opening into a neck opening instead of leaving a wide
# cylindrical top edge to intersect the shawl at the shoulder.
for name in ('Anwen_Wool_ContinuousPattern','Anwen_Linen_ContinuousPattern'):
    obj=bpy.data.objects[name]
    for v in obj.data.vertices:
        p=v.co;t=max(0,min(1,(p.z-1.36)/.085));t=t*t*(3-2*t)
        p.x*=1-.59*t;p.y=.025+(p.y-.025)*(1-.46*t)
    obj.data.update()

for mat in bpy.data.materials:
    if any(mat.name.startswith(s) for s in ('Anwen_Repaired_Slate_Wool','Anwen_Ash_Wool_Shawl','Anwen_Repair_Older_Slate_Wool','Anwen_Unbleached_Linen')):
        for n in mat.node_tree.nodes:
            if n.type=='BUMP':n.inputs['Distance'].default_value=.00065 if 'Wool' in mat.name else .0004

# The opaque scalp is a shadow/root foundation, not a painted silver shell.
root=bpy.data.objects['Anwen_Hair_v004_FittedRoots']
mat=shared.material('Anwen_v021_RootShadow',(.070,.062,.048),.85)
n=mat.node_tree.nodes;l=mat.node_tree.links;b=n.get('Principled BSDF')
tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=170
ramp=n.new('ShaderNodeValToRGB')
ramp.color_ramp.elements[0].color=(.040,.035,.028,1)
ramp.color_ramp.elements[1].color=(.125,.115,.095,1)
l.new(tex.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],b.inputs['Base Color'])
root.data.materials[0]=mat
for obj in bpy.data.objects:
    if obj.name.startswith('Anwen_Hair_v019_Swept'):
        # Match the root field to the beginning of each lock, leaving an
        # irregular, semitransparent edge rather than a straight helmet rim.
        for v in obj.data.vertices:
            if v.co.z>1.745:v.co.z+=.0018*math.sin(v.co.x*140+v.co.y*83)
        obj.data.update()

leather=bpy.data.materials['Anwen_Worn_Belt']
nodes=leather.node_tree.nodes;links=leather.node_tree.links;b=nodes.get('Principled BSDF')
for n in nodes:
    if n.type=='BUMP':n.inputs['Distance'].default_value=.00032
b.inputs['Specular IOR Level'].default_value=.25
metal=shared.material('Anwen_v021_Aged_Bell_Alloy',(.135,.112,.074),.48,.80)
n=metal.node_tree.nodes;l=metal.node_tree.links;b=n.get('Principled BSDF')
noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=160;noise.inputs['Detail'].default_value=4
ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.28;ramp.color_ramp.elements[0].color=(.038,.030,.017,1)
ramp.color_ramp.elements[1].position=.72;ramp.color_ramp.elements[1].color=(.22,.183,.121,1)
l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],b.inputs['Base Color'])
bump=n.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.00012;bump.inputs['Strength'].default_value=.45
l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],b.inputs['Normal'])
for obj in list(bpy.data.objects):
    if obj.name in ('C01_DullBellToken','C01_BellStrap','Anwen_Worn_Buckle'):
        bpy.data.objects.remove(obj,do_unlink=True)

fixed=lambda p:{'pelvis':1}
center=Vector((.114,-.124,.900))
# Closed-section bell: rolled lip, thin interior, crown and a real hanging eye.
profile=[(0,.027),(.001,.030),(.004,.031),(.007,.029),(.010,.027),(.017,.023),
    (.029,.018),(.041,.014),(.047,.0125),(.049,.009),(.049,.006),
    (.046,.007),(.044,.0105),(.039,.012),(.028,.016),(.016,.021),(.008,.025),(.004,.026)]
verts=[];faces=[];uv=[];cols=64
for row,(height,radius) in enumerate(profile):
    for j in range(cols+1):
        a=j/cols*math.tau
        dent=.00028*math.sin(a*7+height*120)+.00016*math.cos(a*11-height*55)
        verts.append(tuple(center+Vector(((radius+dent)*math.cos(a),(radius+dent)*math.sin(a),height))))
        uv.append((j/cols,row/(len(profile)-1)))
        if row and j:
            k=row*(cols+1)+j;faces.append((k-cols-2,k-cols-1,k,k-1))
obj=shared.mesh_object('Anwen_v021_Bell_HollowCast',verts,faces,metal,uv);shared.bind(obj,rig,fixed)
for z,r in ((.011,.026),(.018,.0225)):
    points=[tuple(center+Vector((r*math.cos(i*math.tau/96),r*math.sin(i*math.tau/96),z+.0004*math.sin(i*.6)))) for i in range(97)]
    shared.tube('Anwen_v021_Bell_IncisedBand',points,[.00035]*97,metal,rig,fixed,4)
points=[tuple(center+Vector((.005*math.cos(i*math.tau/32),0,.053+.007*math.sin(i*math.tau/32)))) for i in range(33)]
shared.tube('Anwen_v021_Bell_HangingEye',points,[.0014]*33,metal,rig,fixed,6)
shared.tube('Anwen_v021_Bell_Clapper',[(.114,-.124,.936),(.115,-.125,.902),(.116,-.125,.894)],[.0014,.0025,.004],metal,rig,fixed,8)
shared.tube('Anwen_v021_Bell_LeatherLoop',[(.114,-.124,.956),(.123,-.129,.984),(.130,-.134,1.040)],[.0028,.0032,.0035],leather,rig,fixed,6)
for z in (1.024,1.061):
    # Continuous stitched belt edging, made from short thread segments.
    for j in range(140):
        a=math.tau*j/140;aa=a+.021
        points=[(.178*math.sin(t),.025-.141*math.cos(t),z+.0003*math.sin(j)) for t in (a,aa)]
        shared.tube('Anwen_v021_Belt_Stitch',points,[.00035,.00035],bpy.data.materials['Anwen_Unbleached_Linen'],rig,fixed,3)
points=[(.023*math.cos(i*math.tau/64),-.124,1.044+.020*math.sin(i*math.tau/64)) for i in range(65)]
shared.tube('Anwen_v021_Buckle_CastRing',points,[.0025]*65,metal,rig,fixed,8)
shared.tube('Anwen_v021_Buckle_Tongue',[(0,-.126,1.061),(.004,-.129,1.043),(.008,-.126,1.026)],[.0014]*3,metal,rig,fixed,6)
verts=[];faces=[];uv=[]
for i in range(33):
    t=i/32
    for j in range(5):
        u=j/4
        verts.append((.007+.024*u+.008*t,-.131-.012*math.sin(t*math.pi),1.043-.185*t))
        uv.append((u,t))
        if i and j:
            k=i*5+j;faces.append((k-6,k-1,k,k-5))
obj=shared.mesh_object('Anwen_v021_Belt_LooseEnd',verts,faces,leather,uv);shared.bind(obj,rig,fixed)
bpy.context.view_layer.objects.active=obj
mod=obj.modifiers.new('Leather thickness','SOLIDIFY');mod.thickness=.002
bpy.ops.object.modifier_move_up(modifier=mod.name);bpy.ops.object.modifier_apply(modifier=mod.name)
rig['art_status']='REWORK_v021_NOT_ACCEPTED'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_details_v021.blend'),compress=True)
scene=bpy.context.scene;scene.cycles.samples=32
out=HERE/'evidence/anwen_v021';out.mkdir(parents=True,exist_ok=True)
cam=scene.camera
for label,pos,target,size in [('quarter_face',(.8,-2,1.70),(0,0,1.666),.38),
    ('quarter',(2.5,-4,1.6),(0,0,.95),2.12),('rear',(0,4,1.2),(0,0,.92),2.12),
    ('belt_detail',(.2,-2,1.0),(.07,-.07,1.0),.30)]:
    cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=size;scene.render.filepath=str(out/(label+'.png'))
    bpy.ops.render.render(write_still=True)
print('ANWEN_DETAIL_SOURCE_COMPLETE',flush=True)
