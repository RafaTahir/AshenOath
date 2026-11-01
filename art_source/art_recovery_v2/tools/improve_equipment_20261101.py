"""Retained staff finish and an actual hunting arrow; background Blender only."""
import bpy,math,json,hashlib,sys,shutil
import numpy as np
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1];G=R.parents[1]/'outputs/AshenOathTheRoadBetweenCrowns';E=R/'evidence/refinement_20261101/equipment';M=R/'models/refinement_20261101/equipment';E.mkdir(parents=True,exist_ok=True);M.mkdir(parents=True,exist_ok=True)
asset=sys.argv[sys.argv.index('--')+1];bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0

def material(name,color,rough=.8,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1);p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal;return m

def bounds(objects):
 pts=[o.matrix_world@v.co for o in objects for v in o.data.vertices];return np.array([[min(p[i] for p in pts) for i in range(3)],[max(p[i] for p in pts) for i in range(3)]])

def image(name,pixels,linear=False):
 im=bpy.data.images.new(name,width=pixels.shape[1],height=pixels.shape[0],alpha=False)
 if linear:im.colorspace_settings.name='Non-Color'
 im.pixels.foreach_set(pixels.astype('float32').ravel());im.pack();return im

def texture(m,im):
 n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=im;return n

if asset=='staff':
 path=G/'assets_external/design_pack_v1/C01_ash_staff.glb';backup=E/'C01_ash_staff_before.glb'
 if not backup.exists():shutil.copy2(path,backup)
 bpy.ops.import_scene.gltf(filepath=str(backup));objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];before=bounds(objects)
 for o in objects:
  bpy.context.view_layer.objects.active=o;o.select_set(True)
  bevel=o.modifiers.new('Worn ash end and lashing arrises','BEVEL');bevel.width=.00028;bevel.segments=1;bevel.limit_method='ANGLE';bevel.angle_limit=.9;bpy.ops.object.modifier_apply(modifier=bevel.name)
  uv=o.data.uv_layers.active or o.data.uv_layers.new(name='AshCylinderUV')
  for p in o.data.polygons:
   values=[]
   for loop in p.loop_indices:
    v=o.matrix_world@o.data.vertices[o.data.loops[loop].vertex_index].co;values.append((loop,(math.atan2(v.y,v.x)/math.tau+.5),(v.z+.86)/1.51))
   seam=max(v[1] for v in values)-min(v[1] for v in values)>.5
   for loop,u,v in values:uv.data[loop].uv=(u+1 if seam and u<.5 else u,v)
  for p in o.data.polygons:p.use_smooth=True
  for m in o.data.materials:
   p=m.node_tree.nodes.get('Principled BSDF');color=np.array(p.inputs['Base Color'].default_value[:3]);s=256;x,y=np.meshgrid(np.arange(s)/s,np.arange(s)/s);leather='grip' in m.name.lower()
   grain=np.sin(math.tau*(x*(39 if not leather else 71)+.11*np.sin(y*math.tau*3)))
   pores=np.sin(math.tau*x*83)*np.sin(math.tau*y*79)
   value=np.clip(1+grain*(.12 if not leather else .06)+pores*.025,.75,1.2)
   linear=color[None,None,:]*value[:,:,None];rgb=np.where(linear<=.0031308,linear*12.92,1.055*np.power(linear,1/2.4)-.055)
   rgba=np.concatenate([rgb,np.ones((s,s,1))],axis=-1);albedo=image(m.name+'_authored_grain',rgba)
   m.node_tree.links.new(texture(m,albedo).outputs['Color'],p.inputs['Base Color'])
   dy,dx=np.gradient(grain*.035+pores*.008);nx=-dx;ny=-dy;length=np.sqrt(nx*nx+ny*ny+1)
   normal=image(m.name+'_fine_normal',np.stack(((nx/length+1)*.5,(ny/length+1)*.5,(1/length+1)*.5,np.ones_like(x)),axis=-1),True)
   n=m.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.35;m.node_tree.links.new(texture(m,normal).outputs['Color'],n.inputs['Color']);m.node_tree.links.new(n.outputs['Normal'],p.inputs['Normal']);p.inputs['Roughness'].default_value=.91 if leather else .84
 after=bounds(objects);factor=(before[1]-before[0])/(after[1]-after[0])
 for o in objects:
  inverse=o.matrix_world.inverted()
  for v in o.data.vertices:v.co=inverse@Vector((np.array(o.matrix_world@v.co)-after[0])*factor+before[0])
  o.data.update()
 target=path;name='C01_ash_staff_refined';changes=['Retained grip-origin, exact fitting box and wood/leather material slots','Worn end/lashing arrises and restrained longitudinal ash grain, fine leather texture and distinct roughness','No staff sockets, reach or hand orientation changed']
else:
 # The old Ranger_Arrow.fbx contains a complete bow. Author the missing arrow
 # in the same source-unit convention used by the quiver (.30 -> .78 metres).
 wood=material('Arrow_Straight_Grain_Shaft',(.27,.16,.075),.86);steel=material('Arrow_Forged_Broadhead',(.32,.35,.37),.38,.72);feather=material('Arrow_Matte_Fletching',(.33,.30,.23),.96);binding=material('Arrow_Waxed_Lashing',(.10,.07,.035),.92)
 bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=.011,depth=2.44,location=(0,0,0));shaft=bpy.context.object;shaft.name='KaelArrowShaft';shaft.data.materials.append(wood)
 verts=[(0,0,1.30),(-.044,0,1.16),(0,-.012,1.17),(.044,0,1.16),(0,.012,1.17),(0,0,1.10)]
 faces=[(0,1,2),(0,2,3),(0,3,4),(0,4,1),(5,2,1),(5,3,2),(5,4,3),(5,1,4)]
 mesh=bpy.data.meshes.new('ForgedArrowhead');mesh.from_pydata(verts,[],faces);mesh.update();head=bpy.data.objects.new('KaelArrowBroadhead',mesh);bpy.context.collection.objects.link(head);head.data.materials.append(steel)
 for i in range(3):
  a=i*math.tau/3;radial=Vector((math.cos(a),math.sin(a),0));tangent=Vector((-math.sin(a),math.cos(a),0));points=[]
  for radius,z in [(.010,-1.22),(.055,-1.15),(.063,-.99),(.010,-.89)]:points.append(radial*radius+tangent*.002+Vector((0,0,z)))
  mesh=bpy.data.meshes.new('FletchVane');mesh.from_pydata(points,[],[(0,1,2,3)]);mesh.update();o=bpy.data.objects.new('KaelArrowFletching',mesh);bpy.context.collection.objects.link(o);o.data.materials.append(feather);mod=o.modifiers.new('Feather vane thickness','SOLIDIFY');mod.thickness=.0018;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 for z in [-1.21,-.90]:
  bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=.014,depth=.024,location=(0,0,z));bpy.context.object.data.materials.append(binding)
 # Forked nock is visibly separate from the shaft and is the rear endpoint.
 for x in [-.007,.007]:
  bpy.ops.mesh.primitive_cube_add(size=1,location=(x,0,-1.26));o=bpy.context.object;o.scale=(.007,.016,.08);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(binding)
 objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=shaft;bpy.ops.object.join();objects=[bpy.context.object];objects[0].name='Kael_Hunting_Arrow'
 target=G/'assets/characters/kael_arrow.glb';name='Kael_hunting_arrow';changes=['Actual shaft, seated forged broadhead, three matte feather vanes, bindings and split nock replace the malformed bow-as-arrow source','Local +Y tip after glTF export; 2.6 source-unit length retains .30 quiver scale and .76m ArrowVisual normalization','Project-authored mesh/materials; no external textures or licensed components added']
for o in objects:o['refinement_changes']=json.dumps(changes)
bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
model=M/(name+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(model),compress=True)
bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,export_animations=False,export_apply=True,export_extras=True)
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.color_type='TEXTURE';scene.display.shading.light='STUDIO';scene.display.shading.show_cavity=True;scene.world=bpy.data.worlds.new('NeutralEquipmentReview');scene.world.color=(.12,.13,.14);scene.render.resolution_x=400;scene.render.resolution_y=900;scene.render.resolution_percentage=100
lo,hi=[Vector(v) for v in bounds(objects)];center=(lo+hi)*.5;height=(hi-lo).z
cam=bpy.data.objects.new('InspectionCamera',bpy.data.cameras.new('InspectionCamera'));scene.collection.objects.link(cam);scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=height*1.1
for view,angle in [('front',0),('quarter',.65),('side',math.pi/2),('rear',math.pi)]:
 cam.location=center+Vector((math.sin(angle)*height*3,-math.cos(angle)*height*3,height*.1));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(E/(name+'_'+view+'.png'));bpy.ops.render.render(write_still=True)
record={'id':name,'source_path':str(model),'runtime_path':str(target),'runtime_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'source_sha256':hashlib.sha256(model.read_bytes()).hexdigest(),'changes':changes,'bounds_blender':bounds(objects).tolist(),'triangles':sum(len(p.vertices)-2 for o in objects for p in o.data.polygons),'user_accepted':False}
(E/(name+'_candidate.json')).write_text(json.dumps(record,indent=2)+'\n');print('EQUIPMENT_COMPLETE',asset,str(target),flush=True)
