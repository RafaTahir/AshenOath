"""Bake review derivatives from the layered source; never changes production DB."""
import bpy,sys,argparse
from pathlib import Path


def pack_fine_palette(obj, output):
    """Share authored constant fibre colours without removing geometry."""
    slots=list(obj.data.materials)
    colors=[]
    for material in slots:
        if material is None or not material.use_nodes:continue
        bsdf=material.node_tree.nodes.get('Principled BSDF')
        if bsdf is not None and not bsdf.inputs['Base Color'].is_linked and not bsdf.inputs['Alpha'].is_linked and bsdf.inputs['Alpha'].default_value==1:
            if material not in colors:colors.append(material)
    if not colors:return
    count=len(colors);verts=[];faces=[]
    for i in range(count):
        verts.extend([(i,0,-10),(i+1,0,-10),(i+1,1,-10),(i,1,-10)])
        faces.append(tuple(range(i*4,i*4+4)))
    data=bpy.data.meshes.new('TEMP_FinePalette');data.from_pydata(verts,[],faces);data.update()
    proxy=bpy.data.objects.new('TEMP_FinePalette',data);bpy.context.collection.objects.link(proxy)
    for material in colors:data.materials.append(material)
    uv=data.uv_layers.new(name='PaletteUV');uv.active_render=True
    for i,poly in enumerate(data.polygons):
        poly.material_index=i
        for loop,point in zip(poly.loop_indices,[(.02,.02),(.98,.02),(.98,.98),(.02,.98)]):
            uv.data[loop].uv=((i+point[0])/count,point[1])
    bpy.ops.object.select_all(action='DESELECT');proxy.select_set(True);bpy.context.view_layer.objects.active=proxy
    images={}
    for channel in ('basecolor','orm'):
        image=bpy.data.images.new('AnwenFine_'+channel,width=count*32,height=32,alpha=False)
        if channel=='orm':image.colorspace_settings.name='Non-Color'
        original={}
        for material in colors:
            nodes=material.node_tree.nodes;links=material.node_tree.links;bsdf=nodes.get('Principled BSDF');out=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
            original[material]=out.inputs['Surface'].links[0].from_socket
            emission=nodes.new('ShaderNodeEmission')
            emission.inputs[0].default_value=bsdf.inputs['Base Color'].default_value if channel=='basecolor' else (1,bsdf.inputs['Roughness'].default_value,bsdf.inputs['Metallic'].default_value,1)
            links.new(emission.outputs[0],out.inputs['Surface'])
            target=nodes.new('ShaderNodeTexImage');target.image=image;nodes.active=target
        bpy.ops.object.bake(type='EMIT',uv_layer='PaletteUV',margin=2)
        image.filepath_raw=str(output/(image.name+'.png'));image.file_format='PNG';image.save();images[channel]=image
        for material,socket in original.items():
            material.node_tree.links.new(socket,next(n for n in material.node_tree.nodes if n.type=='OUTPUT_MATERIAL').inputs['Surface'])
    bpy.data.objects.remove(proxy,do_unlink=True)
    palette=bpy.data.materials.new('Anwen_Authored_Fibre_Palette');palette.use_nodes=True
    nodes=palette.node_tree.nodes;links=palette.node_tree.links;bsdf=nodes.get('Principled BSDF')
    tex=nodes.new('ShaderNodeTexImage');tex.image=images['basecolor'];links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
    orm=nodes.new('ShaderNodeTexImage');orm.image=images['orm'];separate=nodes.new('ShaderNodeSeparateColor')
    links.new(orm.outputs['Color'],separate.inputs[0]);links.new(separate.outputs[1],bsdf.inputs['Roughness']);links.new(separate.outputs[2],bsdf.inputs['Metallic'])
    bsdf.inputs['Specular IOR Level'].default_value=.5
    indices=[];used=[]
    uv=obj.data.uv_layers.active
    for poly in obj.data.polygons:
        source=slots[poly.material_index]
        if source in colors:
            column=colors.index(source)
            for loop in poly.loop_indices:
                p=uv.data[loop].uv
                p.x=(column+.12+.76*max(0,min(1,p.x)))/count;p.y=.12+.76*max(0,min(1,p.y))
            source=palette
        if source not in used:used.append(source)
        indices.append(used.index(source))
    obj.data.materials.clear()
    for material in used:obj.data.materials.append(material)
    for poly,index in zip(obj.data.polygons,indices):poly.material_index=index
    print('FINE_PALETTE',count,'authored colours; no missing-texture fallback',flush=True)


HERE=Path(__file__).resolve().parents[1]
GAME=HERE.parents[1]/'outputs/AshenOathTheRoadBetweenCrowns'
parser=argparse.ArgumentParser()
parser.add_argument('--source',default='C01_anwen_reconstruction_v002.blend')
parser.add_argument('--face-only',action='store_true')
parser.add_argument('--out-subdir',default='anwen')
parser.add_argument('--runtime-groom',action='store_true')
parser.add_argument('--low-head',action='store_true')
parser.add_argument('--texture-size',type=int,choices=(1024,2048),default=2048)
parser.add_argument('--body-triangles',type=int,default=0)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=GAME/'art_review'/args.out_subdir
assert OUT.resolve().is_relative_to((GAME/'art_review').resolve())
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(HERE/'models'/args.source))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
for p in rig.pose.bones:p.rotation_quaternion=(1,0,0,0)
for o in list(bpy.data.objects):
    face_mesh=(o.name=='Anwen_MatureFace_Neck' or o.name.startswith(('Anwen_EyeCorrected_','Anwen_Brow_v003','Anwen_Brow_v004','Anwen_Brow_v019')))
    fine_source_fibre=args.runtime_groom and o.name.startswith(('Anwen_Hair_v022_HairlineFibers','Anwen_Brow_v019_'))
    if o.type not in ('MESH','ARMATURE') or o.name.startswith('PREVIEW') or o.get('review_baseline_only',False) or (o.type=='MESH' and o.hide_render) or fine_source_fibre or (args.face_only and o.type=='MESH' and not face_mesh):
        bpy.data.objects.remove(o,do_unlink=True)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=4
scene.render.bake.margin=12
meshes=[o for o in bpy.data.objects if o.type=='MESH']
head=bpy.data.objects['Anwen_MatureFace_Neck']
hair=bpy.data.objects.get('Anwen_Hair_Cards')
groom=[o for o in meshes if o.name.startswith('Anwen_Hair_')]
alpha_groom=[o for o in groom if any(m and m.use_nodes and m.node_tree.nodes.get('Principled BSDF') and m.node_tree.nodes['Principled BSDF'].inputs['Alpha'].is_linked for m in o.data.materials)]
alpha_groom += [o for o in groom if o.name.startswith('Anwen_Hair_v022_') and o not in alpha_groom]
opaque_groom=[o for o in groom if o not in alpha_groom]
alpha_faces=[o for o in meshes if o.name.startswith('Anwen_Brow_v004') and any(m and m.use_nodes and m.node_tree.nodes.get('Principled BSDF') and m.node_tree.nodes['Principled BSDF'].inputs['Alpha'].is_linked for m in o.data.materials)]
# Real brow fibres retain their solid material rather than becoming subpixel
# islands in the much larger face atlas.
alpha_faces += [o for o in meshes if o.name.startswith('Anwen_Brow_v019')]
face_parts=[o for o in meshes if (o==head or o.name.startswith(('Anwen_EyeCorrected_','Anwen_Brow_v004'))) and o not in alpha_faces]
if head.data.shape_keys:
    bpy.context.view_layer.objects.active=head
    bpy.ops.object.shape_key_remove(all=True,apply_mix=True)
high_face=None
if args.low_head:
    high_parts=[]
    for source in face_parts:
        duplicate=source.copy();duplicate.data=source.data.copy()
        bpy.context.collection.objects.link(duplicate);high_parts.append(duplicate)
    before=len(head.data.vertices)
    bpy.context.view_layer.objects.active=head
    modifier=head.modifiers.new('Recover retained facial edge loops','DECIMATE')
    modifier.decimate_type='UNSUBDIV';modifier.iterations=4
    while list(head.modifiers).index(modifier)>0:bpy.ops.object.modifier_move_up(modifier=modifier.name)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    print('HEAD_TOPOLOGY',before,'->',len(head.data.vertices),'vertices; high-detail normals retained for projection',flush=True)
    for eye in face_parts:
        if not eye.name.startswith('Anwen_EyeCorrected_'):continue
        bpy.context.view_layer.objects.active=eye
        modifier=eye.modifiers.new('Curved eye review topology','DECIMATE');modifier.ratio=.35
        while list(eye.modifiers).index(modifier)>0:bpy.ops.object.modifier_move_up(modifier=modifier.name)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in high_parts:obj.select_set(True)
    bpy.context.view_layer.objects.active=high_parts[0]
    bpy.ops.object.join();high_face=bpy.context.object;high_face.name='TEMP_HighDetail_Face_Normal_Source'
if args.runtime_groom:
    # Subpixel source tubes alias in the no-MSAA game preset. Keep the source
    # fibres in Blender; the derivative uses the authored strand/brow cards.
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    tree=BVHTree.FromObject(head,bpy.context.evaluated_depsgraph_get())
    for obj in alpha_faces:
        if not obj.name.startswith('Anwen_Brow_v004'):continue
        for row in range(len(obj.data.vertices)//7):
            vertices=[obj.data.vertices[row*7+j] for j in range(7)]
            center=sum((v.co for v in vertices),Vector())/7
            for vertex in vertices:
                hit,normal,_,_=tree.find_nearest(center+(vertex.co-center)*1.65)
                vertex.co=hit+normal*.00035
        obj.data.update()
groups=[('face',[o for o in meshes if o not in alpha_faces],args.texture_size)] if args.face_only else [('face',face_parts,args.texture_size),('body',[o for o in meshes if o not in face_parts and o!=hair and o not in groom and o not in alpha_faces],args.texture_size)]
if opaque_groom:groups.append(('hair',opaque_groom,1024))
for label,objects,size in groups:
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join();obj=bpy.context.object;obj.name='Anwen_Review_'+label
    if label=='body' and args.body_triangles>0:
        # Simplify before charting: collapsing a baked atlas can bridge its
        # islands and sample unused texels as dark triangular fragments.
        triangles=sum(len(p.vertices)-2 for p in obj.data.polygons)
        if triangles>args.body_triangles:
            modifier=obj.modifiers.new('Review runtime garment topology','DECIMATE')
            modifier.ratio=args.body_triangles/triangles
            modifier.use_collapse_triangulate=True
            while list(obj.modifiers).index(modifier)>0:
                bpy.ops.object.modifier_move_up(modifier=modifier.name)
            bpy.ops.object.modifier_apply(modifier=modifier.name)
            print('BODY_TOPOLOGY',triangles,'->',sum(len(p.vertices)-2 for p in obj.data.polygons),flush=True)
    # Freeze source UV ownership before selecting the new atlas layout.
    for m in obj.data.materials:
        if not m or not m.use_nodes:continue
        for n in list(m.node_tree.nodes):
            if n.type=='TEX_IMAGE' and not n.inputs['Vector'].is_linked:
                uv=m.node_tree.nodes.new('ShaderNodeUVMap');uv.uv_map=obj.data.uv_layers.active.name
                m.node_tree.links.new(uv.outputs[0],n.inputs['Vector'])
            elif n.type=='TEX_COORD' and n.outputs['UV'].is_linked:
                uv=m.node_tree.nodes.new('ShaderNodeUVMap');uv.uv_map=obj.data.uv_layers.active.name
                for link in list(n.outputs['UV'].links):
                    m.node_tree.links.new(uv.outputs[0],link.to_socket)
    atlas=obj.data.uv_layers.new(name='ReviewAtlas');obj.data.uv_layers.active=atlas;atlas.active_render=True
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
            if channel in ('basecolor','orm'):
                out=next(n for n in nodes if n.type=='OUTPUT_MATERIAL');bsdf=next((n for n in nodes if n.type=='BSDF_PRINCIPLED'),None)
                originals[m]=out.inputs['Surface'].links[0].from_socket
                emission=nodes.new('ShaderNodeEmission')
                if channel=='basecolor':
                    emission.inputs[0].default_value=bsdf.inputs['Base Color'].default_value
                    if bsdf.inputs['Base Color'].is_linked:links.new(bsdf.inputs['Base Color'].links[0].from_socket,emission.inputs[0])
                    links.new(emission.outputs[0],out.inputs['Surface'])
                    continue
                rough=bsdf.inputs['Roughness'].default_value if bsdf else .8
                metal=bsdf.inputs['Metallic'].default_value if bsdf else 0
                emission.inputs[0].default_value=(1,rough,metal,1)
                if bsdf and (bsdf.inputs['Roughness'].is_linked or bsdf.inputs['Metallic'].is_linked):
                    packed=nodes.new('ShaderNodeCombineColor');packed.inputs[0].default_value=1
                    packed.inputs[1].default_value=rough;packed.inputs[2].default_value=metal
                    if bsdf.inputs['Roughness'].is_linked:links.new(bsdf.inputs['Roughness'].links[0].from_socket,packed.inputs[1])
                    if bsdf.inputs['Metallic'].is_linked:links.new(bsdf.inputs['Metallic'].links[0].from_socket,packed.inputs[2])
                    links.new(packed.outputs[0],emission.inputs[0])
                links.new(emission.outputs[0],out.inputs['Surface'])
        project_high=high_face is not None and label=='face' and channel=='normal'
        if high_face is not None:high_face.select_set(project_high)
        scene.render.bake.use_selected_to_active=project_high
        if project_high:
            scene.render.bake.cage_extrusion=.006;scene.render.bake.max_ray_distance=.012
        bpy.ops.object.bake(type='NORMAL' if channel=='normal' else 'EMIT',uv_layer='ReviewAtlas')
        scene.render.bake.use_selected_to_active=False
        if high_face is not None:high_face.select_set(False)
        image.filepath_raw=str(OUT/(image.name+'.png'));image.file_format='PNG';image.save()
        maps[channel]=image
        if channel in ('basecolor','orm'):
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
    if label=='face' and high_face is not None:
        bpy.data.objects.remove(high_face,do_unlink=True);high_face=None
alpha_details=alpha_groom+alpha_faces
if alpha_details:
    # Keep the authored strand atlas and cutout ownership. Baking these cards
    # into an opaque scalp atlas would silently turn them into a solid shell.
    bpy.ops.object.select_all(action='DESELECT')
    for obj in alpha_details:obj.select_set(True)
    bpy.context.view_layer.objects.active=alpha_details[0]
    bpy.ops.object.join();bpy.context.object.name='Anwen_Review_fine_details'
    pack_fine_palette(bpy.context.object,OUT)
# Subdivision can interpolate extra influence groups even when source binding
# was limited to four. Resolve this explicitly on the disposable export copy.
for obj in [o for o in bpy.data.objects if o.type=='MESH']:
    for vertex in obj.data.vertices:
        weights=sorted([(g.group,g.weight) for g in vertex.groups if g.weight>1e-8],key=lambda p:-p[1])
        keep=weights[:4];total=sum(w for _,w in keep)
        for index,_ in weights[4:]:obj.vertex_groups[index].remove([vertex.index])
        if total>0:
            for index,weight in keep:obj.vertex_groups[index].add([vertex.index],weight/total,'REPLACE')
bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'anwen_review.glb'),export_format='GLB',use_selection=True,export_animations=False,export_skins=True,export_yup=True,export_extras=True)
print('REVIEW GLB',OUT/'anwen_review.glb',flush=True)
