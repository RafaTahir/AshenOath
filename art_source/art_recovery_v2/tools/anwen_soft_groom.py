"""Finish soft brow fibres and loose temple locks on the continuous source."""
import bpy,math
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_pattern_v017.blend'))
fresh=bpy.data.images.load(str(HERE/'evidence/anwen_v014/Anwen_Brow_Fibers.png'),check_existing=False)
for mat in bpy.data.materials:
    if mat.name.startswith('Anwen_Soft_Brow_Fibers'):
        for node in mat.node_tree.nodes:
            if node.type=='TEX_IMAGE':node.image=fresh
locks=[o for o in bpy.data.objects if o.type=='MESH' and 'Anwen_Hair_v004_TempleWisp' in o.name]
for index,obj in enumerate(locks):
    count=len(obj.data.vertices)//9
    main=index%12 in (0,2,5,9)
    for row in range(count):
        t=row/(count-1)
        vertices=[obj.data.vertices[row*9+j] for j in range(9)]
        center=sum((v.co for v in vertices),Vector())/9
        # Retain fine flyaways, with a few connected, fuller temple locks.
        width=(7.5 if main else 1.6)*max(.015,(1-t)**.65)
        for v in vertices:v.co=center+(v.co-center)*width
    obj.data.update()
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig['art_status']='REWORK_v018_NOT_ACCEPTED'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_soft_v018.blend'),compress=True)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.cycles.use_denoising=True;scene.render.resolution_percentage=100
scene.render.resolution_x=720;scene.render.resolution_y=900
out=HERE/'evidence/anwen_v018';out.mkdir(parents=True,exist_ok=True)
cam=scene.camera;cam.data.type='ORTHO';cam.data.ortho_scale=.38
for label,pos in [('face',(0,-2,1.70)),('quarter_face',(.8,-2,1.70)),('rear_face',(0,2,1.70))]:
    cam.location=pos;cam.rotation_euler=(Vector((0,0,1.666))-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True)
print('SOFT_GROOM_SOURCE_COMPLETE',flush=True)
