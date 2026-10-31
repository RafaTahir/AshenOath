"""Retain successful C01 garment/sculpt work; reject the v042 card groom."""
import bpy
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/"models/C01_anwen_reference_v042.blend"))
rig=bpy.data.objects["C01_Anwen_Rig"]
for obj in list(bpy.data.objects):
    if obj.name.startswith("Anwen_Hair_"):bpy.data.objects.remove(obj,do_unlink=True)
before=set(bpy.data.objects)
with bpy.data.libraries.load(str(ROOT/"models/C01_anwen_review_v027.blend"),link=False) as (source,target):
    target.objects=[name for name in source.objects if name.startswith("Anwen_Hair_")]
for obj in target.objects:
    bpy.context.collection.objects.link(obj);obj.parent=rig
    for modifier in obj.modifiers:
        if modifier.type=="ARMATURE":modifier.object=rig
for obj in list(bpy.data.objects):
    if obj not in before and obj.type=="ARMATURE":bpy.data.objects.remove(obj,do_unlink=True)
rig["art_status"]="RETAINED_COMPONENT_REWORK_v043_NOT_ACCEPTED"
rig["groom_review"]="v042 mesh-card trial rejected; v027 retained groom still requires rework"
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"models/C01_anwen_retained_v043.blend"),compress=True)
print("RETAINED_REVIEW_SOURCE_SAVED_NOT_ACCEPTED",flush=True)
