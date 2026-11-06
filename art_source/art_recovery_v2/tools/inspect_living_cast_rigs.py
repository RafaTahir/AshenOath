import bpy,json
from pathlib import Path
repo=Path(r'D:/Projects/AshenOath');game=repo/'outputs/AshenOathTheRoadBetweenCrowns'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(game/'assets_external/design_pack_v1/humans/C01_Anwen.glb'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
r={'version':bpy.app.version_string,'target':rig.name,'matrix':list(map(list,rig.matrix_world)),'bones':[{'name':b.name,'parent':b.parent.name if b.parent else '', 'head':list(b.head_local),'tail':list(b.tail_local),'rest':list(map(list,b.matrix_local))} for b in rig.data.bones]}
old=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(game/'assets_external/animations/AnimationLibrary_Godot_Standard.glb'))
source=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE' and o not in old)
r['source']=source.name;r['source_matrix']=list(map(list,source.matrix_world));r['actions']=[{'name':a.name,'range':list(a.frame_range),'slots':[s.identifier for s in a.slots]} for a in bpy.data.actions]
r['rest_errors']={b.name:max(abs(b.matrix_local[i][j]-source.data.bones[b.name].matrix_local[i][j]) for i in range(4) for j in range(4)) for b in rig.data.bones if b.name in source.data.bones}
(repo/'art_source/art_recovery_v2/evidence/living_cast_20261107/rig_inspection.json').write_text(json.dumps(r,indent=2))
print('INSPECTION',rig.name,len(r['bones']),source.name,r['actions'])
