"""One bounded likeness/eye pass, preserving the previous editable source.

No production registry or body/clothing geometry is changed. The face sculpt is
an editable relative shape; matched neutral views expose the whole face/scalp.
"""
import bpy, math, json, sys, random
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(HERE.parents[0]/'design_pack_v1/tools'))
import build_anwen as shared
OUT=HERE/'evidence/face_v003';OUT.mkdir(parents=True,exist_ok=True)
SOURCE=HERE/'models/C01_anwen_reconstruction_v002.blend'

def falloff(p,c,r):
    return math.exp(-sum(((p[i]-c[i])/r[i])**2 for i in range(3))*2)

def sculpt_face(head):
    # Source-only subdivision supports actual orbital/facial creases. No claim
    # that this density is a reviewed runtime LOD or that more vertices are art.
    bpy.context.view_layer.objects.active=head
    bpy.ops.object.select_all(action='DESELECT');head.select_set(True)
    mod=head.modifiers.new('Source facial refinement','SUBSURF');mod.levels=1
    bpy.ops.object.modifier_move_up(modifier=mod.name)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    head.shape_key_add(name='Before_v002')
    key=head.shape_key_add(name='Anwen_ReferencePlanes_v003');key.value=1.0
    for v in key.data:
        p=v.co; x,y,z=p;side=1 if x>=0 else -1
        front=max(0,min(1,(-y-.020)/.07))
        # Cheekbone width versus cheek hollow: distinguish structure from a
        # uniformly thin or inflated face, with a supported lower cheek/jowl.
        cheek=falloff(p,(side*.049,-.078,1.642),(.027,.050,.026))*front
        hollow=falloff(p,(side*.044,-.078,1.614),(.025,.050,.023))*front
        jowl=falloff(p,(side*.043,-.057,1.578),(.024,.055,.018))*front
        p.x+=side*(.0028*cheek-.0014*hollow+.0015*jowl)
        p.y+=.0020*hollow-.0012*jowl
        # Reference's alert, uneven brow and lower orbital support. Preserve
        # an opening around the eyeball rather than painting a dark socket.
        brow=falloff(p,(side*.028,-.104,1.686),(.028,.036,.011))*front
        p.y-=.0021*brow
        p.z+=(.0012 if side<0 else -.0004)*brow
        bag=falloff(p,(side*.032,-.099,1.650),(.025,.027,.009))*front
        p.y-=.0013*bag
        # Nose: stronger bridge/ala relationship, less tiny button-like tip.
        bridge=falloff(p,(0,-.115,1.654),(.015,.045,.028))*front
        ala=falloff(p,(side*.014,-.118,1.632),(.012,.025,.012))*front
        p.y-=.0018*bridge
        p.x+=side*.0011*ala
        # Restrained mouth-corner asymmetry, philtrum and supported upper lip.
        corner=falloff(p,(side*.020,-.104,1.589),(.012,.030,.009))*front
        p.z-=(.0013 if side>0 else .0005)*corner
        p.y-=.0010*falloff(p,(0,-.110,1.596),(.023,.030,.006))*front
        # Close a little of the exposed upper sclera without shrinking the eye.
        upper=falloff(p,(side*.0303,-.098,1.670),(.022,.030,.005))*front
        p.z-=.0008*upper
        # Sculpt continuous shallow age folds, not dark painted stripes.
        for level,phase in [(1.703,0.0),(1.714,.8),(1.725,1.7)]:
            line=level+.0015*math.cos(x*42+phase)+.0005*math.sin(x*117)
            p.y+=.0005*math.exp(-((z-line)/.0013)**2)*math.exp(-(x/.052)**6)*front
        glabella=math.exp(-((abs(x)-.006)/.0015)**2)*math.exp(-((z-1.698)/.018)**4)
        p.y+=.00065*glabella*front
        tearline=1.650-abs(x-side*.029)*.20
        p.y+=.00055*math.exp(-((z-tearline)/.0018)**2)*math.exp(-((x-side*.035)/.021)**4)*front
        for angle in (-.40,.10,.58):
            dx=(abs(x)-.045); dz=z-1.664
            across=dz-dx*math.tan(angle)
            p.y+=.00032*math.exp(-(across/.0013)**2)*math.exp(-((dx-.007)/.010)**4)*front
    head['likeness_pass']='Editable Anwen_ReferencePlanes_v003; internal visual review pending'
    bpy.context.view_layer.update()
    return key

def surface_material(head):
    old=head.data.materials[0];m=old.copy();m.name='Anwen_Face_v003_Skin'
    head.data.materials[0]=m;n=m.node_tree.nodes;l=m.node_tree.links
    b=n.get('Principled BSDF')
    base_link=b.inputs['Base Color'].links[0].from_socket
    tint=head.data.color_attributes.new(name='AnwenVascularTone',type='FLOAT_COLOR',domain='POINT')
    rough=head.data.color_attributes.new(name='AnwenSkinRoughness',type='FLOAT_COLOR',domain='POINT')
    key=head.data.shape_keys.key_blocks['Anwen_ReferencePlanes_v003']
    for i,item in enumerate(key.data):
        p=item.co;side=1 if p.x>=0 else -1
        front=max(0,min(1,(-p.y-.01)/.07))
        cheek=falloff(p,(side*.043,-.090,1.631),(.030,.040,.025))*front
        nose=falloff(p,(0,-.123,1.634),(.018,.030,.015))*front
        under=falloff(p,(side*.031,-.100,1.650),(.024,.030,.010))*front
        tint.data[i].color=(.98+.04*cheek,.96-.035*cheek-.03*nose,.91-.025*cheek,1)
        tzone=falloff(p,(0,-.106,1.676),(.027,.050,.040))*front
        r=.62-.14*tzone-.05*under
        rough.data[i].color=(r,r,r,1)
    tone=n.new('ShaderNodeVertexColor');tone.layer_name=tint.name
    mix=n.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1.0
    l.new(base_link,mix.inputs[1]);l.new(tone.outputs['Color'],mix.inputs[2]);l.new(mix.outputs[0],b.inputs['Base Color'])
    rnode=n.new('ShaderNodeVertexColor');rnode.layer_name=rough.name
    sep=n.new('ShaderNodeSeparateColor');l.new(rnode.outputs['Color'],sep.inputs[0]);l.new(sep.outputs[0],b.inputs['Roughness'])
    coords=n.new('ShaderNodeTexCoord');pores=n.new('ShaderNodeTexNoise')
    pores.inputs['Scale'].default_value=1700;pores.inputs['Detail'].default_value=2
    l.new(coords.outputs['Object'],pores.inputs['Vector'])
    bump=n.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.000055;bump.inputs['Strength'].default_value=.3
    l.new(pores.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs['Normal'],b.inputs['Normal'])
    b.inputs['Subsurface Weight'].default_value=.065
    return old,m

def rebuild_eyes(rig):
    materials=[]
    for name,color,rough in [('Sclera',(.58,.53,.44),.23),('IrisHazel',(.11,.065,.018),.28),('Pupil',(.002,.0025,.0015),.15)]:
        mat=shared.material('AnwenEye_v003_'+name,color,rough)
        if name=='IrisHazel':
            node=mat.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='IrisFibers'
            mat.node_tree.links.new(node.outputs['Color'],mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
        materials.append(mat)
    objects=[]
    for side in (-1,1):
        center=Vector((side*.0303,-.0847,1.6638));radius=.0129
        pupil_phi=math.asin(.00225/radius);iris_phi=math.asin(.00565/radius)
        rings=[0.0]+[pupil_phi*i/4 for i in range(1,5)]+[pupil_phi+(iris_phi-pupil_phi)*i/10 for i in range(1,11)]+[iris_phi+(math.pi-iris_phi)*i/30 for i in range(1,31)]
        count=96;points=[];uv=[];faces=[];mat_indices=[];colors=[]
        for row,phi in enumerate(rings):
            for col in range(count+1):
                a=col/count*math.tau
                p=center+Vector((radius*math.sin(phi)*math.cos(a),-radius*math.cos(phi),radius*math.sin(phi)*math.sin(a)))
                points.append(tuple(p));uv.append((col/count,phi/math.pi))
                radial=.6+.20*math.sin(a*47+.4*math.sin(phi*34))+.12*math.sin(a*89-phi*13)
                limbal=max(0,min(1,(iris_phi-phi)/.04))
                colors.append((.12*radial*limbal+.025,.075*radial*limbal+.016,.024*radial*limbal+.006,1))
                if row and col:
                    k=row*(count+1)+col
                    faces.append((k-count-2,k-1,k) if row==1 else
                                 (k-count-2,k-1,k-count-1) if row==len(rings)-1 else
                                 (k-count-2,k-1,k,k-count-1))
                    mid=(phi+rings[row-1])*.5
                    mat_indices.append(2 if mid<pupil_phi else 1 if mid<iris_phi else 0)
        obj=shared.mesh_object('Anwen_EyeCorrected_'+str(side),points,faces,materials[0],uv)
        obj.data.materials.append(materials[1]);obj.data.materials.append(materials[2])
        for p,index in zip(obj.data.polygons,mat_indices):p.material_index=index
        assert all(p.normal.dot(p.center-center)>0 for p in obj.data.polygons if p.area>1e-12), 'Eye normals must face outward'
        attr=obj.data.color_attributes.new(name='IrisFibers',type='FLOAT_COLOR',domain='POINT')
        for i,c in enumerate(colors):attr.data[i].color=c
        shared.bind(obj,rig,lambda p,s=side:{'Face_Eye_L' if s>0 else 'Face_Eye_R':1})
        obj['construction']='Single curved globe: no separate iris disc behind sclera'
        objects.append(obj)
    return objects

def brows(head,rig):
    material=shared.material('Anwen_v003_Uneven_Ash_Brows',(.035,.023,.014),.85)
    tree=BVHTree.FromObject(head,bpy.context.evaluated_depsgraph_get())
    objects=[]
    rng=random.Random(4031)
    for side in (-1,1):
        start=len(objects)
        for strand in range(460):
            t=rng.random();x=side*(.013+.038*t)
            z=1.686+.0055*math.sin(t*math.pi)+(.0012 if side<0 else 0)-.0012*t
            width=.0020*(1-t)+.0005
            z+=rng.uniform(-width,width)
            length=rng.uniform(.0013,.0029)
            dx=side*length*(.35+.85*t);dz=length*(.8-.75*t)
            points=[]
            for i in range(5):
                u=i/4
                xx=x+dx*u;zz=z+dz*u-.0004*u*u
                hit,normal,_,_=tree.ray_cast(Vector((xx,-.5,zz)),Vector((0,1,0)))
                if hit is not None:points.append(tuple(hit+Vector((0,-.00013,0))))
            if len(points)<2:continue
            radius=rng.uniform(.000045,.000085)
            obj=shared.tube('Anwen_Brow_v003',points,[radius*(1-.85*i/(len(points)-1)) for i in range(len(points))],material,rig,lambda p,s=side:{'Face_Brow_L' if s>0 else 'Face_Brow_R':1},3)
            objects.append(obj)
        pieces=objects[start:]
        if pieces:
            bpy.ops.object.select_all(action='DESELECT')
            for obj in pieces:obj.select_set(True)
            bpy.context.view_layer.objects.active=pieces[0]
            bpy.ops.object.join();combined=bpy.context.object
            combined.name='Anwen_Brow_v003_'+('L' if side>0 else 'R')
            objects[start:]=[combined]
    return objects

def setup_camera():
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
    scene.cycles.use_denoising=True
    scene.render.resolution_x=900;scene.render.resolution_y=1000
    scene.render.resolution_percentage=100
    camera=scene.camera;camera.data.type='ORTHO';camera.data.ortho_scale=.34
    # Same scene, light intensities, exposure, lens and view transform for both.
    scene.render.image_settings.file_format='PNG'
    return scene,camera

def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    head=bpy.data.objects['Anwen_MatureFace_Neck']
    before_eyes=[o for o in bpy.data.objects if o.type=='MESH' and any(t in o.name for t in ('Anwen_Eyeball','Anwen_Iris','Anwen_Pupil'))]
    key=sculpt_face(head);old_mat,new_mat=surface_material(head)
    eyes=rebuild_eyes(rig);eyebrows=brows(head,rig)
    hair=bpy.data.objects.get('Anwen_Hair_Cards');hair.hide_render=True
    scene,camera=setup_camera()
    for state in ('before','after'):
        key.value=0.0 if state=='before' else 1.0
        head.data.materials[0]=old_mat if state=='before' else new_mat
        for o in before_eyes:o.hide_render=state!='before'
        for o in eyes+eyebrows:o.hide_render=state!='after'
        for view,angle in [('front',0),('quarter',25),('profile',90)]:
            a=math.radians(angle);target=Vector((0,-.012,1.665))
            camera.location=target+Vector((math.sin(a),-math.cos(a),.018))*1.5
            camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
            scene.render.filepath=str(OUT/(state+'_'+view+'.png'))
            bpy.ops.render.render(write_still=True)
    # Restore an editable AFTER source, retaining hidden baseline eyes solely
    # for comparison. Old source file and all other cast members are untouched.
    key.value=1.0;head.data.materials[0]=new_mat
    hair.hide_render=False
    for o in before_eyes:o.hide_render=True;o.hide_viewport=True;o['review_baseline_only']=True
    for o in eyes+eyebrows:o.hide_render=False
    camera.location=(.4,-1.5,1.69);target=Vector((0,-.012,1.665))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/'after_context.png');bpy.ops.render.render(write_still=True)
    bpy.ops.file.pack_all()
    path=HERE/'models/C01_anwen_face_v003.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
    report={'status':'facial_study_pending_visual_review','source':str(path),'previous_source':str(SOURCE),
            'scope':'facial structure, eyes, eyebrows and skin only; hair/clothing not repaired',
            'eye_iris_disc_removed':True,'sculpt_shape_key':key.name,
            'neutral_comparison':'same lighting/camera; hair deliberately absent in both scalp/face diagnostic views',
            'production_changed':False,'accepted':False}
    (OUT/'study.json').write_text(json.dumps(report,indent=2))
    print('FACE_STUDY_SOURCE',path,flush=True)

def refine_brows_only():
    path=HERE/'models/C01_anwen_face_v003.blend'
    bpy.ops.wm.open_mainfile(filepath=str(path))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    head=bpy.data.objects['Anwen_MatureFace_Neck']
    for o in list(bpy.data.objects):
        if o.type=='MESH' and o.name.startswith('Anwen_Brow_v003'):
            bpy.data.objects.remove(o,do_unlink=True)
    brows(head,rig)
    hair=bpy.data.objects.get('Anwen_Hair_Cards');hair.hide_render=True
    scene,camera=setup_camera()
    for view,angle in [('front',0),('quarter',25),('profile',90)]:
        a=math.radians(angle);target=Vector((0,-.012,1.665))
        camera.location=target+Vector((math.sin(a),-math.cos(a),.018))*1.5
        camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(OUT/('after_'+view+'.png'));bpy.ops.render.render(write_still=True)
    hair.hide_render=False
    target=Vector((0,-.012,1.665));camera.location=(.4,-1.5,1.69)
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/'after_context.png');bpy.ops.render.render(write_still=True)
    bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)

if __name__=='__main__':
    if '--refine-brows' in sys.argv:refine_brows_only()
    else:main()
