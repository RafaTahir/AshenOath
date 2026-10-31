"""Offline gravity drape of the continuous thin pattern, before Solidify/skin."""
import bpy,math,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(HERE.parents[0]/'design_pack_v1/tools'))
import build_anwen as shared
sys.path.insert(0,str(HERE/'tools'))
from anwen_authored_gown import weights
bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_rear_v023.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
old=bpy.data.objects['Anwen_Wool_ContinuousPattern']
half=len(old.data.vertices)//2
faces=[tuple(p.vertices) for p in old.data.polygons if all(i<half for i in p.vertices)]
assert len(faces)==104*160,'Only the original continuous outer pattern may simulate'
vertices=[tuple(v.co) for v in list(old.data.vertices)[:half]]
obj=shared.mesh_object('Anwen_GravitySettled_ContinuousWool',vertices,faces,old.data.materials[0])
obj.parent=None
uv=obj.data.uv_layers.new(name='UVMap')
for p in obj.data.polygons:
    for loop in p.loop_indices:
        v=obj.data.vertices[obj.data.loops[loop].vertex_index].co
        uv.data[loop].uv=(.5+math.atan2(v.x,.025-v.y)/math.tau,(v.z-.2)/1.245)
pin=obj.vertex_groups.new(name='Tailored waist and shoulder seams')
for v in obj.data.vertices:
    z=v.co.z
    waist=max(0,1-abs(z-1.044)/.031)
    shoulder=max(0,min(1,(z-1.31)/.045))
    amount=max(waist,shoulder)
    if amount>0:pin.add([v.index],amount,'REPLACE')
helpers=[]
for source in [bpy.data.objects['Anwen_Linen_ContinuousPattern']]:
    count=len(source.data.vertices)//2
    exterior=[tuple(p.vertices) for p in source.data.polygons if all(i<count for i in p.vertices)]
    assert len(exterior)==104*160
    proxy=shared.mesh_object('TEMP_Anwen_DrapeSupport',[tuple(v.co) for v in list(source.data.vertices)[:count]],exterior,source.data.materials[0])
    proxy.hide_render=True
    bpy.context.view_layer.objects.active=proxy
    dec=proxy.modifiers.new('Collision-only reduction','DECIMATE');dec.ratio=.5
    bpy.ops.object.modifier_apply(modifier=dec.name)
    proxy.modifiers.new('Offline fabric contact','COLLISION')
    proxy.collision.thickness_outer=.004;proxy.collision.thickness_inner=.001
    helpers.append(proxy)
cloth=obj.modifiers.new('Offline continuous wool drape','CLOTH')
cloth.settings.quality=6;cloth.settings.mass=.22
cloth.settings.tension_stiffness=18;cloth.settings.compression_stiffness=18
cloth.settings.shear_stiffness=8;cloth.settings.bending_stiffness=.35
cloth.settings.air_damping=3
cloth.settings.vertex_group_mass=pin.name;cloth.settings.pin_stiffness=1
cloth.collision_settings.use_collision=True;cloth.collision_settings.distance_min=.003
cloth.collision_settings.use_self_collision=True;cloth.collision_settings.self_distance_min=.0025
cloth.point_cache.frame_start=1;cloth.point_cache.frame_end=45
scene=bpy.context.scene;scene.frame_start=1;scene.frame_end=45
for frame in range(1,46):
    scene.frame_set(frame)
    if frame%5==0:print('CONTINUOUS_DRAPE_FRAME',frame,flush=True)
bpy.context.view_layer.objects.active=obj
bpy.ops.object.modifier_apply(modifier=cloth.name)
assert all(math.isfinite(c) for v in obj.data.vertices for c in v.co)
assert max(abs(v.co.x) for v in obj.data.vertices)<.42,'Drape escaped its authored volume'
for proxy in helpers:bpy.data.objects.remove(proxy,do_unlink=True)
bpy.data.objects.remove(old,do_unlink=True)
obj.name='Anwen_Wool_ContinuousPattern'
shared.bind(obj,rig,weights)
thick=obj.modifiers.new('Turned fabric thickness after drape','SOLIDIFY');thick.thickness=.002
bpy.ops.object.modifier_move_up(modifier=thick.name);bpy.ops.object.modifier_apply(modifier=thick.name)
bpy.context.view_layer.update()
tree=BVHTree.FromObject(obj,bpy.context.evaluated_depsgraph_get())
for patch in [o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith(('Anwen_Handsewn_Repair','Anwen_Repair_Stitch','Anwen_v022_Visible_DarnedPatch','Anwen_v022_Patch_Thread'))]:
    for v in patch.data.vertices:
        hit,normal,_,_=tree.find_nearest(v.co)
        v.co=hit+normal*.0012
    patch.data.update()
rig['art_status']='REWORK_v025_NOT_ACCEPTED'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_settled_v025.blend'),compress=True)
scene.render.engine='CYCLES';scene.cycles.samples=32
out=HERE/'evidence/anwen_v025';out.mkdir(parents=True,exist_ok=True)
cam=scene.camera
for label,pos,target,size in [('quarter',(2.5,-4,1.6),(0,0,.95),2.12),
    ('rear',(0,4,1.2),(0,0,.92),2.12),('cloth_detail',(.3,-2,1.2),(0,-.02,1.06),.80)]:
    cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=size;scene.render.filepath=str(out/(label+'.png'))
    bpy.ops.render.render(write_still=True)
print('CONTINUOUS_DRAPE_SOURCE_COMPLETE',flush=True)
