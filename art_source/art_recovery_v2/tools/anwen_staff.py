"""Review-only worn ashwood staff, retaining the current grip-origin contract."""
import bpy,math,sys
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parents[1]
REPO=HERE.parents[1]
OUT=REPO/'outputs/AshenOathTheRoadBetweenCrowns/art_review/anwen_full_v026'
OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(HERE.parents[0]/'design_pack_v1/tools'))
import build_anwen as shared
bpy.ops.wm.read_factory_settings(use_empty=True)
wood=shared.material('C01_Weathered_AshWood',(.10,.060,.027),.87)
n=wood.node_tree.nodes;l=wood.node_tree.links;b=n.get('Principled BSDF')
coord=n.new('ShaderNodeTexCoord');mapping=n.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY'
mapping.inputs[1].default_value=(120,120,2.5);l.new(coord.outputs['Object'],mapping.inputs[0])
noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=2.0;noise.inputs['Detail'].default_value=5
noise.inputs['Roughness'].default_value=.72;l.new(mapping.outputs[0],noise.inputs['Vector'])
ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.22;ramp.color_ramp.elements[0].color=(.025,.019,.012,1)
ramp.color_ramp.elements[1].position=.78;ramp.color_ramp.elements[1].color=(.25,.20,.125,1)
l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],b.inputs['Base Color'])
bump=n.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.00050;bump.inputs['Strength'].default_value=.50
l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],b.inputs['Normal'])
b.inputs['Specular IOR Level'].default_value=.23
leather=shared.material('C01_Staff_Worn_Binding',(.035,.022,.012),.74)
n=leather.node_tree.nodes;l=leather.node_tree.links;b=n.get('Principled BSDF')
noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=220;noise.inputs['Detail'].default_value=3
bump=n.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.00023;bump.inputs['Strength'].default_value=.4
l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],b.inputs['Normal'])
verts=[];faces=[];uv=[];rows=128;cols=40
for row in range(rows+1):
    t=row/rows;z=-.86+1.51*t
    center=Vector((.005*math.sin(t*4.8)+.0025*math.sin(t*12),.003*math.sin(t*6+.8),z))
    for j in range(cols+1):
        a=j/cols*math.tau
        radius=.0145+.003*t+.004*math.exp(-((t-.965)/.055)**2)
        radius+=.0012*math.sin(a*5+t*16)+.0006*math.sin(a*11-t*7)
        radius+=.003*math.exp(-((t-.77)/.035)**2)*max(0,math.cos(a-.7))**4
        p=center+Vector((radius*math.cos(a),radius*math.sin(a),0))
        if row==rows:p.z+=.0015*math.sin(a*5)+.0008*math.sin(a*9)
        verts.append(tuple(p));uv.append((j/cols,t))
        if row and j:
            k=row*(cols+1)+j;faces.append((k-cols-2,k-cols-1,k,k-1))
faces.append(tuple(reversed(range(cols+1))))
faces.append(tuple(rows*(cols+1)+j for j in range(cols+1)))
shaft=shared.mesh_object('C01_Staff_Grained_Ash',verts,faces,wood,uv)
pieces=[shaft]
for band in range(2):
    points=[]
    for i in range(241):
        t=i/240;a=t*math.tau*(8 if band==0 else 2)
        z=-.042+.15*t if band==0 else .60+.027*t
        center=Vector((.005*math.sin((z+.86)/1.51*4.8),.003*math.sin((z+.86)/1.51*6+.8),z))
        points.append(center+Vector((.019*math.cos(a),.019*math.sin(a),0)))
    # Thin flattened strips, not oversized round handles.
    vv=[];ff=[];tex=[]
    for row,p in enumerate(points):
        a=row/240*math.tau*(8 if band==0 else 2)
        radial=Vector((math.cos(a),math.sin(a),0))
        for j in range(5):
            u=j/4
            vv.append(tuple(p+Vector((0,0,(u-.5)*.013))+radial*.0007*math.sin(u*math.pi)))
            tex.append((u,row/240))
            if row and j:
                k=row*5+j;ff.append((k-6,k-1,k,k-5))
    pieces.append(shared.mesh_object('C01_Staff_LeatherLashing',vv,ff,leather,tex))
bpy.ops.object.select_all(action='DESELECT')
for obj in pieces:obj.select_set(True)
bpy.context.view_layer.objects.active=shaft;bpy.ops.object.join()
shaft=bpy.context.object;shaft.name='C01_Anwen_AshStaff_Review'
shaft['attachment_origin']='Grip centre; exported local +Y up; lower tip -0.86 metres'
shaft['art_status']='REVIEW_ONLY_NOT_ACCEPTED'
bpy.ops.mesh.primitive_plane_add(size=20,location=(0,0,-.875))
bpy.context.object.name='PREVIEW_Floor'
bpy.context.object.data.materials.append(shared.material('PREVIEW_Floor',(.085,.095,.10),.9))
for name,pos,power,size in [('Key',(3,-4,4),550,4),('Fill',(-3,-2,2.5),280,3),('Rim',(1,3,3),650,3)]:
    data=bpy.data.lights.new('PREVIEW_'+name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    light=bpy.data.objects.new(data.name,data);bpy.context.collection.objects.link(light)
    light.location=pos;light.rotation_euler=(Vector((0,0,-.1))-light.location).to_track_quat('-Z','Y').to_euler()
camera=bpy.data.objects.new('PREVIEW_Camera',bpy.data.cameras.new('PREVIEW_Camera'))
bpy.context.collection.objects.link(camera);bpy.context.scene.camera=camera
bpy.context.scene.world=bpy.data.worlds.new('PREVIEW_World');bpy.context.scene.world.color=(.16,.16,.16)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=400;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
cam=scene.camera;cam.data.type='ORTHO';cam.data.ortho_scale=1.74
cam.location=(.4,-3,.1);cam.rotation_euler=(Vector((0,0,-.1))-cam.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_ash_staff_v002.blend'),compress=True)
evidence=HERE/'evidence/anwen_v026';evidence.mkdir(parents=True,exist_ok=True)
scene.render.filepath=str(evidence/'staff.png');bpy.ops.render.render(write_still=True)
for obj in list(bpy.data.objects):
    if obj!=shaft:bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT');shaft.select_set(True);bpy.context.view_layer.objects.active=shaft
atlas=shaft.data.uv_layers.new(name='StaffAtlas');shaft.data.uv_layers.active=atlas;atlas.active_render=True
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.006);bpy.ops.object.mode_set(mode='OBJECT')
maps={};mats=list(shaft.data.materials);scene.cycles.samples=4;scene.render.bake.margin=8
for channel in ('basecolor','normal','orm'):
    image=bpy.data.images.new('AnwenStaff_'+channel,width=1024,height=1024,alpha=False)
    if channel!='basecolor':image.colorspace_settings.name='Non-Color'
    originals={}
    for mat in mats:
        nodes=mat.node_tree.nodes;links=mat.node_tree.links;bsdf=nodes.get('Principled BSDF')
        target=nodes.new('ShaderNodeTexImage');target.image=image;nodes.active=target
        if channel!='normal':
            out=nodes.get('Material Output');originals[mat]=out.inputs['Surface'].links[0].from_socket
            emission=nodes.new('ShaderNodeEmission')
            emission.inputs[0].default_value=bsdf.inputs['Base Color'].default_value if channel=='basecolor' else (1,bsdf.inputs['Roughness'].default_value,0,1)
            if channel=='basecolor' and bsdf.inputs['Base Color'].is_linked:links.new(bsdf.inputs['Base Color'].links[0].from_socket,emission.inputs[0])
            links.new(emission.outputs[0],out.inputs['Surface'])
    bpy.ops.object.bake(type='NORMAL' if channel=='normal' else 'EMIT',uv_layer='StaffAtlas')
    image.filepath_raw=str(OUT/(image.name+'.png'));image.file_format='PNG';image.save();maps[channel]=image
    for mat,socket in originals.items():mat.node_tree.links.new(socket,mat.node_tree.nodes.get('Material Output').inputs['Surface'])
material=shared.material('AnwenStaff_Review_PBR',(1,1,1),.85)
nodes=material.node_tree.nodes;links=material.node_tree.links;b=nodes.get('Principled BSDF')
for channel,image in maps.items():
    tex=nodes.new('ShaderNodeTexImage');tex.image=image
    if channel=='basecolor':links.new(tex.outputs[0],b.inputs['Base Color'])
    elif channel=='normal':
        normal=nodes.new('ShaderNodeNormalMap');links.new(tex.outputs[0],normal.inputs[1]);links.new(normal.outputs[0],b.inputs['Normal'])
    else:
        separate=nodes.new('ShaderNodeSeparateColor');links.new(tex.outputs[0],separate.inputs[0]);links.new(separate.outputs[1],b.inputs['Roughness'])
shaft.data.materials.clear();shaft.data.materials.append(material)
for p in shaft.data.polygons:p.material_index=0
for name in [layer.name for layer in shaft.data.uv_layers if layer.name!='StaffAtlas']:shaft.data.uv_layers.remove(shaft.data.uv_layers[name])
shaft.data.uv_layers.active_index=0;shaft.data.uv_layers[0].active_render=True
bpy.ops.export_scene.gltf(filepath=str(OUT/'staff_review.glb'),export_format='GLB',use_selection=True,export_animations=False,export_extras=True)
print('ANWEN_STAFF_REVIEW_COMPLETE',flush=True)
