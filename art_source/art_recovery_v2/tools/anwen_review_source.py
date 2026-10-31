"""Assemble retained C01 work, excluding the rejected collapsed scarf trial."""
import bpy
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_review_v026.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
trial=bpy.data.objects.get('Anwen_OnePiece_Gravity_Shawl')
if trial:bpy.data.objects.remove(trial,do_unlink=True)
previous=set(bpy.data.objects)
with bpy.data.libraries.load(str(HERE/'models/C01_anwen_rear_v023.blend'),link=False) as (source,target):
    target.objects=['Anwen_v020_Fitted_Scarf_0']
for obj in target.objects:
    assert obj is not None
    bpy.context.collection.objects.link(obj);obj.parent=rig
    for modifier in obj.modifiers:
        if modifier.type=='ARMATURE':modifier.object=rig
for obj in list(bpy.data.objects):
    if obj not in previous and obj.type=='ARMATURE':bpy.data.objects.remove(obj,do_unlink=True)
rig['art_status']='REWORK_v027_NOT_ACCEPTED'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_review_v027.blend'),compress=True)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
out=HERE/'evidence/anwen_v027';out.mkdir(parents=True,exist_ok=True)
cam=scene.camera
for label,pos,target,size in [('front',(0,-4,1.2),(0,0,.92),2.12),
    ('rear',(0,4,1.2),(0,0,.92),2.12),('side',(4,0,1.2),(0,0,.92),2.12),
    ('quarter',(2.5,-4,1.6),(0,0,.95),2.12),('face',(.8,-2,1.70),(0,0,1.666),.38),
    ('cloth_detail',(.3,-2,1.2),(0,-.02,1.20),.75)]:
    cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=size;scene.render.filepath=str(out/(label+'.png'))
    bpy.ops.render.render(write_still=True)
print('ANWEN_RETAINED_REVIEW_SOURCE_COMPLETE',flush=True)
