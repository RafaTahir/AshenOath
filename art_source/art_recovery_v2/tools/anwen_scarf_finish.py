"""Drape the one-piece scarf; finish pale ash-brown hair and fitted brows."""
import bpy,math,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(HERE.parents[0]/'design_pack_v1/tools'))
import build_anwen as shared
bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_settled_v025.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
old=bpy.data.objects['Anwen_v020_Fitted_Scarf_0']
half=len(old.data.vertices)//2
faces=[tuple(p.vertices) for p in old.data.polygons if all(i<half for i in p.vertices)]
assert half==33*161 and len(faces)==32*160
obj=shared.mesh_object('Anwen_OnePiece_Gravity_Shawl',[tuple(v.co) for v in list(old.data.vertices)[:half]],faces,old.data.materials[0])
uv=obj.data.uv_layers.new(name='UVMap')
for p in obj.data.polygons:
    for loop in p.loop_indices:
        i=obj.data.loops[loop].vertex_index;uv.data[loop].uv=(i%161/160,i//161/32)
pin=obj.vertex_groups.new(name='Neck seam')
for v in obj.data.vertices:
    row=v.index//161
    if row<4:pin.add([v.index],max(.15,1-row/3),'REPLACE')
helpers=[]
for source in [o for o in bpy.data.objects if o.name=='Anwen_Wool_ContinuousPattern' or o.name.startswith('Anwen_v022_TailoredSleeve_')]:
    count=len(source.data.vertices)//2
    exterior=[tuple(p.vertices) for p in source.data.polygons if all(i<count for i in p.vertices)]
    proxy=shared.mesh_object('TEMP_ShawlSupport',[tuple(v.co) for v in list(source.data.vertices)[:count]],exterior,source.data.materials[0])
    proxy.hide_render=True;bpy.context.view_layer.objects.active=proxy
    dec=proxy.modifiers.new('Collision-only reduction','DECIMATE');dec.ratio=.50
    bpy.ops.object.modifier_apply(modifier=dec.name)
    proxy.modifiers.new('Offline fabric contact','COLLISION')
    proxy.collision.thickness_outer=.004;proxy.collision.thickness_inner=.001
    helpers.append(proxy)
cloth=obj.modifiers.new('Offline scarf gravity','CLOTH')
cloth.settings.quality=6;cloth.settings.mass=.18
cloth.settings.tension_stiffness=20;cloth.settings.compression_stiffness=20
cloth.settings.shear_stiffness=8;cloth.settings.bending_stiffness=.08
cloth.settings.air_damping=3;cloth.settings.vertex_group_mass=pin.name;cloth.settings.pin_stiffness=1
cloth.collision_settings.use_collision=True;cloth.collision_settings.distance_min=.003
cloth.collision_settings.use_self_collision=True;cloth.collision_settings.self_distance_min=.0025
cloth.point_cache.frame_start=1;cloth.point_cache.frame_end=35
scene=bpy.context.scene;scene.frame_start=1;scene.frame_end=35
for frame in range(1,36):
    scene.frame_set(frame)
    if frame%5==0:print('SHAWL_DRAPE_FRAME',frame,flush=True)
bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=cloth.name)
assert all(math.isfinite(c) for v in obj.data.vertices for c in v.co)
for helper in helpers:bpy.data.objects.remove(helper,do_unlink=True)
bpy.data.objects.remove(old,do_unlink=True)
def weights(p):
    arm=max(0,min(.2,(abs(p.x)-.16)*2.5))
    return {'spine_03':1-arm,'upperarm_l' if p.x>0 else 'upperarm_r':arm}
shared.bind(obj,rig,weights)
thick=obj.modifiers.new('Wool edge after drape','SOLIDIFY');thick.thickness=.0025
bpy.ops.object.modifier_move_up(modifier=thick.name);bpy.ops.object.modifier_apply(modifier=thick.name)

for mat in bpy.data.materials:
    if mat.name.startswith(('Anwen_Authored_Ash_Strands','Anwen_Ash_Plait_Fibers')):
        nodes=mat.node_tree.nodes;links=mat.node_tree.links;b=nodes.get('Principled BSDF')
        source=b.inputs['Base Color'].links[0].from_socket
        tint=nodes.new('ShaderNodeMixRGB');tint.blend_type='MULTIPLY';tint.inputs[0].default_value=1
        tint.inputs[2].default_value=(.52,.50,.46,1)
        links.new(source,tint.inputs[1]);links.new(tint.outputs[0],b.inputs['Base Color'])
        b.inputs['Specular IOR Level'].default_value=.22

head=bpy.data.objects['Anwen_MatureFace_Neck']
tree=BVHTree.FromObject(head,bpy.context.evaluated_depsgraph_get())
previous=set(bpy.data.objects)
with bpy.data.libraries.load(str(HERE/'models/C01_anwen_soft_v018.blend'),link=False) as (source,target):
    target.objects=[name for name in source.objects if name.startswith('Anwen_Brow_v004_')]
fresh=bpy.data.images.load(str(HERE/'evidence/anwen_v026/Anwen_Brow_Fibers.png'),check_existing=False)
for brow in target.objects:
    if brow is None:continue
    bpy.context.collection.objects.link(brow);brow.parent=rig
    for mod in brow.modifiers:
        if mod.type=='ARMATURE':mod.object=rig
    for row in range(49):
        vs=[brow.data.vertices[row*7+j] for j in range(7)]
        center=sum((v.co for v in vs),Vector())/7
        for v in vs:
            p=center+(v.co-center)*1.45
            hit,normal,_,_=tree.find_nearest(p);v.co=hit+normal*.00018
    for mat in brow.data.materials:
        for node in mat.node_tree.nodes:
            if node.type=='TEX_IMAGE':node.image=fresh
    brow.data.update()
for extra in list(bpy.data.objects):
    if extra not in previous and extra.type=='ARMATURE':bpy.data.objects.remove(extra,do_unlink=True)
rig['art_status']='REWORK_v026_NOT_ACCEPTED'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_review_v026.blend'),compress=True)
scene.render.engine='CYCLES';scene.cycles.samples=32
out=HERE/'evidence/anwen_v026';out.mkdir(parents=True,exist_ok=True)
scene.render.resolution_x=720;scene.render.resolution_y=900;scene.render.resolution_percentage=100
cam=scene.camera
for label,pos,target,size in [('quarter_face',(.8,-2,1.70),(0,0,1.666),.38),
    ('front',(0,-4,1.2),(0,0,.92),2.12),('rear',(0,4,1.2),(0,0,.92),2.12),
    ('side',(4,0,1.2),(0,0,.92),2.12),('quarter',(2.5,-4,1.6),(0,0,.95),2.12),
    ('cloth_detail',(.3,-2,1.2),(0,-.02,1.25),.75)]:
    cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=size;scene.render.filepath=str(out/(label+'.png'))
    bpy.ops.render.render(write_still=True)
print('ANWEN_REVIEW_SOURCE_COMPLETE',flush=True)
