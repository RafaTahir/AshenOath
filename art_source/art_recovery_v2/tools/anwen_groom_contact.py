"""Seat the swept hair cards against the scalp and attach the pinned coil."""
import bpy
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_brow_v014.blend'))
head=bpy.data.objects['Anwen_MatureFace_Neck']
tree=BVHTree.FromObject(head,bpy.context.evaluated_depsgraph_get())
for obj in bpy.data.objects:
    if obj.type!='MESH' or not obj.name.startswith('Anwen_Hair_v004_'):continue
    if '_Swept_' in obj.name or '_Nape_' in obj.name:
        for vertex in obj.data.vertices:
            point,normal,_,_=tree.find_nearest(vertex.co)
            vertex.co=point+normal*.0035
        obj.data.update()
    elif '_PinnedPlait_' in obj.name:
        for vertex in obj.data.vertices:vertex.co.y-=.010
        obj.data.update()
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_groomed_v015.blend'),compress=True)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.cycles.use_denoising=True;scene.render.resolution_percentage=100
scene.render.resolution_x=720;scene.render.resolution_y=900
out=HERE/'evidence/anwen_v015';out.mkdir(parents=True,exist_ok=True)
cam=scene.camera;cam.data.type='ORTHO';cam.data.ortho_scale=.38
for label,pos in [('quarter_face',(.8,-2,1.70)),('profile',(2,0,1.70)),('rear_face',(0,2,1.70))]:
    cam.location=pos;cam.rotation_euler=(Vector((0,0,1.666))-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True)
print('GROOM_CONTACT_SOURCE_COMPLETE',flush=True)
