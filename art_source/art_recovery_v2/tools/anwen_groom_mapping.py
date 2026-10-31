"""Correct strand orientation and apply the new groom atlas to C01 only."""
import bpy,math
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_review_v027.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
atlas=bpy.data.images.load(str(HERE/'materials/anwen_groom_v029.png'),check_existing=False)
card=bpy.data.materials.new('Anwen_v029_Oriented_AshBlonde_Strands');card.use_nodes=True
card.surface_render_method='DITHERED';card.use_backface_culling=False
nodes=card.node_tree.nodes;links=card.node_tree.links;b=nodes.get('Principled BSDF')
tex=nodes.new('ShaderNodeTexImage');tex.image=atlas
tint=nodes.new('ShaderNodeMixRGB');tint.blend_type='MULTIPLY';tint.inputs[0].default_value=1
tint.inputs[2].default_value=(.8,.8,.76,1)
links.new(tex.outputs['Color'],tint.inputs[1]);links.new(tint.outputs[0],b.inputs['Base Color'])
links.new(tex.outputs['Alpha'],b.inputs['Alpha'])
b.inputs['Roughness'].default_value=.73;b.inputs['Specular IOR Level'].default_value=.28
plait=card.copy();plait.name='Anwen_v029_AshBlonde_Plait'
b=plait.node_tree.nodes.get('Principled BSDF')
for link in list(b.inputs['Alpha'].links):plait.node_tree.links.remove(link)
b.inputs['Alpha'].default_value=1
cards=[];braids=[]
for obj in bpy.data.objects:
    if obj.type!='MESH' or not obj.name.startswith('Anwen_Hair_'):continue
    if any(token in obj.name for token in ('Swept','RearLock','LooseTemple','Nape_','TempleWisp')):
        obj.data.materials.clear();obj.data.materials.append(card);cards.append(obj)
        # The new image's dense root is at image-bottom / UV v=0. Its feathery
        # tip is at image-top / UV v=1, matching the guide's root-to-tip cursor.
        obj['strand_uv_direction']='root=v0; tip=v1; atlas roots at PNG bottom'
    elif any(token in obj.name for token in ('PinnedPlait','SidePlait')):
        obj.data.materials.clear();obj.data.materials.append(plait);braids.append(obj)
        for loop in obj.data.uv_layers.active.data:
            loop.uv.x=.03+.19*loop.uv.x
            loop.uv.y=.15+.65*loop.uv.y
assert cards and braids,'Expected the existing fitted groom and connected plaits'
rig['art_status']='REWORK_v029_NOT_ACCEPTED'
rig['groom_atlas']='AI-authored diffuse/alpha texture; not model evidence; materials/anwen_groom_v029.png'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_groom_v029.blend'),compress=True)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=720;scene.render.resolution_y=900;scene.render.resolution_percentage=100
out=HERE/'evidence/anwen_v029';out.mkdir(parents=True,exist_ok=True)
camera=scene.camera;camera.data.type='ORTHO';camera.data.ortho_scale=.38
for label,pos,target in [('face',(.8,-2,1.70),(0,0,1.666)),('side',(2,0,1.70),(0,0,1.666)),('rear',(0,2,1.70),(0,0,1.70))]:
    camera.location=pos;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True)
print('GROOM_ORIENTATION_SOURCE_COMPLETE',len(cards),len(braids),flush=True)
