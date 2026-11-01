"""Final material-only revision after native inspection; no repeated sculpt."""
import ast,hashlib,json,math,sys,argparse
from pathlib import Path
import bpy,numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];GAME=ROOT.parents[1]/'outputs/AshenOathTheRoadBetweenCrowns'
code=ast.parse((ROOT/'tools/improve_bipeds_20261101.py').read_text())
surface=next(n for n in code.body if isinstance(n,ast.FunctionDef) and n.name=='surface_images')
parser=argparse.ArgumentParser();parser.add_argument('--ids',nargs='*');args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
for key in (args.ids or ['M01','M05','M02','M19','M20','M03','M04','M06']):
    evidence=ROOT/'evidence/refinement_20261101/bipeds'/key
    report=json.loads((evidence/'candidate.json').read_text())
    previous=Path(report.get('previous_finishing_source',report['source_path']))
    bpy.ops.wm.open_mainfile(filepath=str(previous),load_ui=False)
    out=Path(report['runtime_path']).parent
    namespace=dict(bpy=bpy,np=np,math=math,key=key,out=out)
    exec(compile(ast.Module(body=[surface],type_ignores=[]),'<retained surface recipe>','exec'),namespace)
    rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.find_armature()==rig]
    materials=list(dict.fromkeys(m for o in meshes for m in o.data.materials if m))
    for i,mat in enumerate(materials):namespace['surface_images'](mat,i)
    if key=='M04':
        # Original iron albedo is only sRGB 17/22/24, which disappears at
        # gameplay distance. Raise its retained texture values, not the cloth.
        mat=next(m for m in materials if 'PittedIron' in m.name)
        bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        queue=[link.from_node for link in bsdf.inputs['Base Color'].links]
        seen=set();tex=None
        while queue:
            node=queue.pop(0)
            if node in seen:continue
            seen.add(node)
            if node.type=='TEX_IMAGE':tex=node;break
            queue.extend(link.from_node for socket in node.inputs for link in socket.links)
        assert tex is not None,'Missing retained iron albedo upstream of factor nodes'
        source=tex.image
        # A copied packed image retains its old packed payload: glTF can export
        # that instead of changed pixels. Use a fresh datablock and pack it.
        copy=bpy.data.images.new('M04_ReadablePittedIron_albedo',width=source.size[0],height=source.size[1],alpha=True)
        copy.colorspace_settings.name=source.colorspace_settings.name
        values=np.array(source.pixels[:],dtype=np.float32).reshape(-1,4);values[:,:3]=np.clip(values[:,:3]*7,0,1)
        copy.pixels.foreach_set(values.ravel());copy.filepath_raw=str(out/'M04_ReadablePittedIron_albedo.png');copy.file_format='PNG';copy.save();copy.pack();tex.image=copy
        report['changes'].append('Retained pitted-iron albedo lifted from near-black for readable armor, shield and sword; linen unchanged')
        # Validation cleans bevel-generated zero-area faces, retaining all
        # surviving UV/material data and normalized export weights.
        for mesh in meshes:mesh.data.validate(clean_customdata=False)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in meshes+[rig]:ob.select_set(True)
    parent=rig.parent
    while parent:parent.select_set(True);parent=parent.parent
    bpy.context.view_layer.objects.active=rig
    # Import-time keys were authored in Blender's 24 fps scene.
    bpy.context.scene.render.fps=24
    bpy.ops.export_scene.gltf(filepath=report['runtime_path'],export_format='GLB',use_selection=True,export_skins=True,
        export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_yup=True,export_extras=True)
    for image in bpy.data.images:
        if image.source=='FILE':
            try:image.pack()
            except RuntimeError:pass
    final=previous.with_name(key+'_refined_surface_v002.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(final))
    report['previous_finishing_source']=str(previous);report['source_path']=str(final)
    report['changes'].append('Native-inspected final surface uses subtle stochastic pores in place of repeating directional skin grain')
    report['source_sha256']=hashlib.sha256(final.read_bytes()).hexdigest()
    report['runtime_sha256']=hashlib.sha256(Path(report['runtime_path']).read_bytes()).hexdigest()
    scene=bpy.context.scene
    if rig.animation_data:
        rig.animation_data.action=None
        for track in rig.animation_data.nla_tracks:track.mute=True
        idle=bpy.data.actions.get('Idle')
        if idle:
            rig.animation_data.action=idle
            if idle.slots:rig.animation_data.action_slot=idle.slots[0]
    scene.frame_set(8);bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
    pts=[o.evaluated_get(deps).matrix_world@Vector(p) for o in meshes for p in o.evaluated_get(deps).bound_box]
    lo=Vector([min(p[i] for p in pts) for i in range(3)]);hi=Vector([max(p[i] for p in pts) for i in range(3)]);center=(lo+hi)*.5;span=max(hi-lo)*1.32
    scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.color_type='TEXTURE'
    scene.display.shading.show_shadows=True;scene.display.shading.show_cavity=True;scene.display.shading.cavity_type='WORLD'
    scene.display.shading.background_type='WORLD'
    if scene.world is None:scene.world=bpy.data.worlds.new('Neutral source inspection')
    scene.world.color=(.06,.07,.08)
    scene.render.resolution_x=480;scene.render.resolution_y=600;scene.render.resolution_percentage=100
    camdata=bpy.data.cameras.new('Final source inspection');cam=bpy.data.objects.new(camdata.name,camdata);scene.collection.objects.link(cam);scene.camera=cam
    camdata.type='ORTHO';camdata.ortho_scale=span
    for label,angle in [('front',0),('quarter',.65),('side',math.pi/2),('rear',math.pi)]:
        cam.location=center+Vector((math.sin(angle),-math.cos(angle),.04))*span*3
        cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(evidence/(label+'.png'));bpy.ops.render.render(write_still=True)
    report['source_render_scope']='Final textured Workbench source views; current native engine views evaluate the normal/ORM shading'
    (evidence/'candidate.json').write_text(json.dumps(report,indent=2)+'\n')
    print('FINAL_SURFACE',key,flush=True)
