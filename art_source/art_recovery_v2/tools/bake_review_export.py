"""Bake review derivatives from the layered source; never changes production DB."""
import bpy,sys
from pathlib import Path
HERE=Path(__file__).resolve().parents[1]
GAME=HERE.parents[1]/'outputs/AshenOathTheRoadBetweenCrowns'
OUT=GAME/'art_review/anwen'; OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_reconstruction_v002.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
for p in rig.pose.bones:p.rotation_quaternion=(1,0,0,0)
for o in list(bpy.data.objects):
    if o.type not in ('MESH','ARMATURE') or o.name.startswith('PREVIEW'):
        bpy.data.objects.remove(o,do_unlink=True)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=4
scene.render.bake.margin=12
meshes=[o for o in bpy.data.objects if o.type=='MESH']
head=bpy.data.objects['Anwen_MatureFace_Neck']
hair=bpy.data.objects['Anwen_Hair_Cards']
for label,objects,size in [('face',[head],2048),('body',[o for o in meshes if o not in (head,hair)],2048)]:
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join();obj=bpy.context.object;obj.name='Anwen_Review_'+label
    # Freeze source UV ownership before selecting the new atlas layout.
    for m in obj.data.materials:
        if not m or not m.use_nodes:continue
        for n in list(m.node_tree.nodes):
            if n.type=='TEX_IMAGE' and not n.inputs['Vector'].is_linked:
                uv=m.node_tree.nodes.new('ShaderNodeUVMap');uv.uv_map=obj.data.uv_layers.active.name
                m.node_tree.links.new(uv.outputs[0],n.inputs['Vector'])
    atlas=obj.data.uv_layers.new(name='ReviewAtlas');obj.data.uv_layers.active=atlas
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.008)
    bpy.ops.object.mode_set(mode='OBJECT')
    materials=[m for m in obj.data.materials if m]
    maps={}; originals={}
    for channel in ('basecolor','normal','orm'):
        image=bpy.data.images.new('Anwen_'+label+'_'+channel,width=size,height=size,alpha=False)
        if channel!='basecolor':image.colorspace_settings.name='Non-Color'
        for m in materials:
            nodes=m.node_tree.nodes;links=m.node_tree.links
            target=nodes.new('ShaderNodeTexImage');target.image=image
            for n in nodes:n.select=False
            nodes.active=target;target.select=True
            if channel=='orm':
                out=next(n for n in nodes if n.type=='OUTPUT_MATERIAL');bsdf=next((n for n in nodes if n.type=='BSDF_PRINCIPLED'),None)
                originals[m]=out.inputs['Surface'].links[0].from_socket
                emission=nodes.new('ShaderNodeEmission')
                rough=bsdf.inputs['Roughness'].default_value if bsdf else .8
                metal=bsdf.inputs['Metallic'].default_value if bsdf else 0
                emission.inputs[0].default_value=(1,rough,metal,1)
                links.new(emission.outputs[0],out.inputs['Surface'])
        bpy.ops.object.bake(type='DIFFUSE' if channel=='basecolor' else 'NORMAL' if channel=='normal' else 'EMIT',pass_filter={'COLOR'} if channel=='basecolor' else set())
        image.filepath_raw=str(OUT/(image.name+'.png'));image.file_format='PNG';image.save()
        maps[channel]=image
        if channel=='orm':
            for m,socket in originals.items():m.node_tree.links.new(socket,next(n for n in m.node_tree.nodes if n.type=='OUTPUT_MATERIAL').inputs['Surface'])
    material=bpy.data.materials.new('Anwen_Review_'+label+'_PBR');material.use_nodes=True
    nodes=material.node_tree.nodes;links=material.node_tree.links;bsdf=nodes.get('Principled BSDF')
    for channel,image in maps.items():
        tex=nodes.new('ShaderNodeTexImage');tex.image=image
        if channel=='basecolor':links.new(tex.outputs[0],bsdf.inputs['Base Color'])
        elif channel=='normal':
            normal=nodes.new('ShaderNodeNormalMap');links.new(tex.outputs[0],normal.inputs['Color']);links.new(normal.outputs[0],bsdf.inputs['Normal'])
        else:
            separate=nodes.new('ShaderNodeSeparateColor');links.new(tex.outputs[0],separate.inputs[0]);links.new(separate.outputs[1],bsdf.inputs['Roughness']);links.new(separate.outputs[2],bsdf.inputs['Metallic'])
    obj.data.materials.clear();obj.data.materials.append(material)
    for p in obj.data.polygons:p.material_index=0
    for name in [uv.name for uv in obj.data.uv_layers if uv.name!='ReviewAtlas']:
        obj.data.uv_layers.remove(obj.data.uv_layers[name])
    obj.data.uv_layers.active_index=0;obj.data.uv_layers[0].active_render=True
    print('BAKED',label,flush=True)
bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'anwen_review.glb'),export_format='GLB',use_selection=True,export_animations=False,export_skins=True,export_yup=True)
print('REVIEW GLB',OUT/'anwen_review.glb',flush=True)
