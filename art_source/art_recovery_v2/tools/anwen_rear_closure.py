"""Repair observed rear coverage/contact, retaining the previous review source."""
import bpy,math,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(HERE.parents[0]/'design_pack_v1/tools'))
import build_anwen as shared
sys.path.insert(0,str(HERE/'tools'))
from anwen_finish_v004 import cubic,lock_mesh
bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_tailored_v022.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
head=bpy.data.objects['Anwen_MatureFace_Neck']
head_tree=BVHTree.FromObject(head,bpy.context.evaluated_depsgraph_get())
card=next(m for m in bpy.data.materials if m.name.startswith('Anwen_Authored_Ash_Strands'))
body=bpy.data.objects['Anwen_Wool_ContinuousPattern']
tree=BVHTree.FromObject(body,bpy.context.evaluated_depsgraph_get())
overlap=bpy.data.objects.get('Anwen_v020_Fitted_Scarf_1')
if overlap:bpy.data.objects.remove(overlap,do_unlink=True)
scarf=bpy.data.objects['Anwen_v020_Fitted_Scarf_0']
half=len(scarf.data.vertices)//2
for i in range(half):
    p=scarf.data.vertices[i].co
    radial=Vector((p.x,p.y-.025,0));r=radial.length
    if r<.001:continue
    direction=radial/r
    origin=Vector((0,.025,p.z))+direction*.5
    hit,_,_,_=tree.ray_cast(origin,-direction,.5)
    if hit is None:continue
    support=(hit-Vector((0,.025,p.z))).dot(direction)+.004
    shift=max(0,support-r)*direction
    scarf.data.vertices[i].co+=shift;scarf.data.vertices[i+half].co+=shift
scarf.data.update()

# Move the additional geometric roots inside the fitted hairline and taper
# their visual thickness; v022 exposed coarse cut ends against the forehead.
fibres=bpy.data.objects['Anwen_Hair_v022_HairlineFibers']
stride=22*4
for start in range(0,len(fibres.data.vertices),stride):
    for row in range(22):
        vertices=[fibres.data.vertices[start+row*4+j] for j in range(4)]
        center=sum((v.co for v in vertices),Vector())/4
        t=row/21
        if row<5:
            center.z+=.012*(1-row/5)
            hit,normal,_,_=head_tree.find_nearest(center)
            center=hit+normal*(.0022+.008*math.sin(t*math.pi))
        old=sum((v.co for v in vertices),Vector())/4
        for v in vertices:v.co=center+(v.co-old)*.58
fibres.data.update()

# Give each swept lock a broad, soft raised centre rather than a flat film.
for obj in bpy.data.objects:
    if not obj.name.startswith('Anwen_Hair_v019_Swept'):continue
    rows=len(obj.data.vertices)//9
    for row in range(rows):
        t=row/(rows-1)
        for col in range(9):
            v=obj.data.vertices[row*9+col];_,normal,_,_=head_tree.find_nearest(v.co)
            v.co+=normal*.0025*math.sin(col/8*math.pi)*math.sin(t*math.pi)
    obj.data.update()
for side in (-1,1):
    for j in range(25):
        f=j/24
        controls=[Vector((side*(.004+.050*f),.009+.047*f,1.804-.016*f)),
            Vector((side*(.030+.042*f),.095,1.797-.025*f)),
            Vector((side*(.026+.040*f),.113,1.715-.020*f)),
            Vector((side*.018,.089,1.656))]
        guide=[]
        for i in range(40):
            t=i/39;p=cubic(controls,t);hit,normal,_,_=head_tree.find_nearest(p)
            guide.append(hit+normal*(.0035+.007*math.sin(t*math.pi)+.001*math.sin(t*12+j)))
        obj=lock_mesh('Anwen_Hair_v023_RearLock',guide,.0042,card,rig,card=True)
        for uv in obj.data.uv_layers.active.data:uv.uv.x=(j%4+uv.uv.x)/4
rig['art_status']='REWORK_v023_NOT_ACCEPTED'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_rear_v023.blend'),compress=True)
scene=bpy.context.scene;scene.cycles.samples=32
out=HERE/'evidence/anwen_v023';out.mkdir(parents=True,exist_ok=True)
cam=scene.camera
for label,pos,target,size in [('quarter_face',(.8,-2,1.70),(0,0,1.666),.38),
    ('front',(0,-4,1.2),(0,0,.92),2.12),('rear',(0,4,1.2),(0,0,.92),2.12),
    ('rear_face',(0,2,1.70),(0,0,1.70),.34),('quarter',(2.5,-4,1.6),(0,0,.95),2.12)]:
    cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=size;scene.render.filepath=str(out/(label+'.png'))
    bpy.ops.render.render(write_still=True)
print('ANWEN_REAR_CLOSURE_COMPLETE',flush=True)
