"""Refine a retained runtime biped in Blender; one explicit asset per invocation.

The previous layered master and GLB remain intact. This editable finishing master
starts from their exact runtime derivative so UVs, skin weights and action names
survive. New surface maps and sculpt changes are deliberately species-specific.
"""
import argparse, hashlib, json, math, sys
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT.parents[1]/'outputs/AshenOathTheRoadBetweenCrowns'
parser=argparse.ArgumentParser();parser.add_argument('--id',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
key=args.id
assert key in ['M01','M02','M03','M04','M05','M06','M19','M20']
row=next(r for r in json.loads((ROOT/'stylized_roster.json').read_text())['assets'] if r['id']==key)
base=Path(row['runtime_path']);digest=hashlib.sha256(base.read_bytes()).hexdigest()
out=GAME/'art_review/refinement_20261101/bipeds'/key;out.mkdir(parents=True,exist_ok=True)
evidence=ROOT/'evidence/refinement_20261101/bipeds'/key;evidence.mkdir(parents=True,exist_ok=True)
master=ROOT/'models/refinement_20261101/bipeds'/f'{key}_refined.blend';master.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(base))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.find_armature()==rig]
assert meshes and all(o.data.uv_layers.active for o in meshes)
if rig.animation_data:
    rig.animation_data.action=None
    for t in rig.animation_data.nla_tracks:t.mute=True
rig.data.pose_position='REST';bpy.context.view_layer.update()
for o in meshes:
    o['retained_runtime_sha256']=digest
    o['retained_layered_source']=row['source_path']

def bounds():
    points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
    return [[min(p[i] for p in points),max(p[i] for p in points)] for i in range(3)]

before=bounds();changes=[]
height=before[2][1]-before[2][0]
def weights(o,v):return {o.vertex_groups[g.group].name:g.weight for g in v.groups}
def gauss(v,c,s):return math.exp(-((v-c)/s)**2)

for o in meshes:
    inverse=o.matrix_world.inverted()
    for v in o.data.vertices:
        p=o.matrix_world@v.co;w=weights(o,v)
        head=w.get('Head',0);neck=w.get('neck_01',w.get('Neck',0))
        chest=w.get('spine_03',0)+w.get('spine_02',0);waist=w.get('spine_01',0);pelvis=w.get('pelvis',w.get('Pelvis',0))
        headbone=rig.data.bones.get('Head')
        hp=rig.matrix_world@headbone.head_local if headbone else Vector((0,0,height*.9))
        front=max(0,min(1,(hp.y-p.y+.015)/(.065*height)))
        jaw=gauss(p.z,hp.z-.025*height,.045*height)*head*front
        if key=='M01':
            # Retain connected anatomy; amplify the scavenger's long jaw and
            # sunken flank rather than adding separate teeth/shoulder spheres.
            p.y-=.018*height*jaw;p.x*=1+.08*jaw-.035*waist
            p.z-=.005*height*jaw
            arm=w.get('lowerarm_l',0)+w.get('lowerarm_r',0)
            p.y+=.006*height*arm*math.sin(p.x*21)
        elif key=='M02':
            # The retained licensed creep has its own anatomy and rig.
            fore=w.get('Arm2.L',0)+w.get('Arm2.R',0)
            p.y-=.007*height*fore
            p.x*=1-.025*(w.get('Chest',0)+w.get('Spine',0))
            p.y-=.008*height*jaw
        elif key=='M03':
            belly=gauss(p.z,height*.54,height*.12)*(waist+pelvis)
            p.y-=.018*height*belly;p.z-=.012*height*belly
            p.x*=1+.035*belly+.065*jaw
            p.y-=.012*height*jaw
        elif key=='M04':
            # All plate, shield, sword and linen stay in their weighted source.
            # Only a restrained asymmetry at the visor, not skeleton changes.
            p.y-=.003*height*jaw
        elif key=='M05':
            # Bell load pulls the nape forward. Keep the chest bell's actual
            # bronze/harness vertices untouched by the tissue sculpt.
            # group-based load adjustment applies to shoulder/neck anatomy;
            # the equipment geometry does not use the neck group.
            p.y-=.010*height*neck;p.z-=.006*height*neck
            p.x*=1+.025*chest
        elif key=='M06':
            # Break the cylindrical limb read with shallow irregular bark
            # planes; every existing root, knot and heartwood strip survives.
            arm=sum(value for name,value in w.items() if name.startswith('Arm'))
            body=w.get('Body',0)
            p.x+=.009*height*arm*math.sin(p.z/height*27+.5)
            p.y+=.008*height*(arm+body)*math.sin(p.z/height*31+p.x*3)
        elif key=='M19':
            p.x*=1-.035*waist
            # Uneven shoulder crest and lean fingers differentiate the raider.
            p.z+=.008*height*w.get('clavicle_l',0)
            fingertips=sum(value for name,value in w.items() if name.startswith(('index_03','middle_03','ring_03','pinky_03')))
            p.y-=.012*height*fingertips;p.z-=.005*height*fingertips
            p.y-=.006*height*jaw
        elif key=='M20':
            p.x*=1+.065*jaw+.035*chest
            p.y-=.010*height*jaw
            p.z-=.004*height*head
            arm=w.get('lowerarm_l',0)+w.get('lowerarm_r',0)
            p.y+=.004*height*arm
        v.co=inverse@p
    o.data.update()

def palette(name,color):
    material=bpy.data.materials.new(key+'_'+name);material.use_nodes=True
    image=bpy.data.images.new(key+'_'+name+'_albedo',width=16,height=16,alpha=False)
    image.generated_color=(*color,1)
    image.filepath_raw=str(out/(name+'_albedo.png'));image.file_format='PNG';image.save()
    tex=material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
    material.node_tree.links.new(tex.outputs['Color'],material.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    return material

if key in ['M01','M03','M19','M20']:
    # Fit an actual mouth seam onto the retained connected facial surface.
    # Ray intersections seat the seam and uneven teeth instead of floating
    # decoration or another replacement head.
    body=meshes[0];verts=[body.matrix_world@v.co for v in body.data.vertices]
    polygons=[tuple(p.vertices) for p in body.data.polygons]
    tree=BVHTree.FromPolygons(verts,polygons,all_triangles=False)
    headpoints=[body.matrix_world@v.co for v in body.data.vertices if weights(body,v).get('Head',0)>.7]
    low=min(p.z for p in headpoints);high=max(p.z for p in headpoints)
    width=max(p.x for p in headpoints)-min(p.x for p in headpoints)
    mouthz=low+(high-low)*(.29 if key=='M20' else .33)
    material=palette('Recessed_mouth',(.075,.052,.043))
    teethmat=palette('Uneven_worn_teeth',(.48,.45,.34))
    details=[];points=[]
    for i in range(15):
        x=(i/14-.5)*width*(.54 if key=='M03' else .48)
        z=mouthz+.009*height*(abs(i/14-.5)*2)**1.5
        if key=='M19':z+=x*.08
        hit,normal,_,_=tree.ray_cast(Vector((x,-height*3,z)),Vector((0,1,0)))
        if hit is not None:points.append(hit+normal*.0008*height)
    if len(points)>4:
        radius=height*.0016
        v=[];f=[]
        for p in points:
            for j in range(6):
                angle=j*math.tau/6;v.append(p+Vector((0,math.cos(angle)*radius,math.sin(angle)*radius)))
        for i in range(len(points)-1):
            for j in range(6):f.append((i*6+j,i*6+(j+1)%6,(i+1)*6+(j+1)%6,(i+1)*6+j))
        data=bpy.data.meshes.new(key+'_FittedMouthSeam');data.from_pydata(v,[],f);data.update()
        seam=bpy.data.objects.new(data.name,data);bpy.context.collection.objects.link(seam);data.materials.append(material);details.append(seam)
        for i in [3,5,8,11]:
            point=points[min(i,len(points)-1)]
            bpy.ops.mesh.primitive_cone_add(vertices=5,radius1=height*.0008,radius2=height*.0028,depth=height*.008,location=point+Vector((0,-height*.001,-height*.002)))
            tooth=bpy.context.object;tooth.name=key+'_SeatedTooth';tooth.data.materials.append(teethmat);details.append(tooth)
        for detail in details:
            if not detail.data.uv_layers.active:detail.data.uv_layers.new(name='UVMap')
            group=detail.vertex_groups.new(name='Head');group.add(list(range(len(detail.data.vertices))),1,'REPLACE')
            mod=detail.modifiers.new('Retained head binding','ARMATURE');mod.object=rig
        bpy.ops.object.select_all(action='DESELECT')
        for detail in details+[body]:detail.select_set(True)
        bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
        body.data.update()

NOTES={
'M01':['Connected lower jaw extended and broadened; fitted mouth seam and seated uneven teeth; flank taper and forearm ridge','Dry peat skin with fine irregular pores; moist recessed eyes'],
'M02':['Stalker forearm/head projection refined without changing native Creep joints','Restore muted tangent normal response (the previous normal scale was zero)'],
'M03':['Hanging lower abdomen and broad waterlogged jaw with fitted uneven mouth','Wet hide, drier root ligatures and amber tissue receive separate responses'],
'M04':['Visor projection retained; armor edges receive a small angle-limited bevel','Pitted steel, matte funerary linen and a visibly readable steel reflection'],
'M05':['Load-bearing nape/shoulder asymmetry under the retained bell','Cast-bronze grain, worn iron, dry leather harness and clay skin separate clearly'],
'M06':['Asymmetric shallow bark planes interrupt the round arm/trunk silhouette','Directional bark fissures and roughness, smoother exposed old heartwood'],
'M19':['Lean waist, injured shoulder crest, longer hooked fingertips and an asymmetric mouth','Sparse rough hide with directional microstructure; wet eyes and dry cord'],
'M20':['Broad heavy jaw with fitted mouth and shoulder mound with forearm adjustment','Coarse scarred hide and striated worn tusk; wet eyes remain localized']}
changes=NOTES[key]

def surface_images(material,index):
    """Small tileable maps supplement, and never replace, retained albedo UVs."""
    if not material.use_nodes:return
    nodes=material.node_tree.nodes;links=material.node_tree.links
    bsdf=next((n for n in nodes if n.type=='BSDF_PRINCIPLED'),None)
    if not bsdf:return
    label=material.name.lower()
    if key=='M02':
        for n in nodes:
            if n.type=='NORMAL_MAP':n.inputs['Strength'].default_value=.32
        return
    size=256;x,y=np.meshgrid(np.arange(size,dtype=np.float32)/size,np.arange(size,dtype=np.float32)/size)
    rng=np.random.default_rng(1101+index+int(key[1:])*31)
    # Stochastic filtered grain avoids a repeating sine lattice/moire on skin.
    noise=rng.standard_normal((size,size)).astype(np.float32)
    fx=np.fft.fftfreq(size)[None,:];fy=np.fft.fftfreq(size)[:,None]
    noise=np.fft.ifft2(np.fft.fft2(noise)*np.exp(-((fx*fx+fy*fy)*90))).real
    noise=(noise-noise.mean())/max(noise.std(),.001)*.25
    bark=any(s in label for s in ['bark','root','wood'])
    metal=any(s in label for s in ['iron','bronze','steel'])
    eye='eye' in label
    tusk='tusk' in label
    if bark:noise+=.65*np.sin(math.tau*(x*19+.12*np.sin(y*math.tau*3)))
    if tusk:noise=.35*np.sin(math.tau*x*43)+noise*.1
    if eye:noise*=.025
    amplitude=.07 if bark else .03 if metal else .008 if eye else .012
    dy,dx=np.gradient(noise);nx=-dx*amplitude*8;ny=-dy*amplitude*8
    norm=np.sqrt(nx*nx+ny*ny+1)
    pixels=np.stack(((nx/norm+1)*.5,(ny/norm+1)*.5,(1/norm+1)*.5,np.ones_like(x)),axis=-1)
    image=bpy.data.images.new(key+'_'+material.name+'_normal',width=size,height=size,alpha=False)
    image.colorspace_settings.name='Non-Color';image.pixels.foreach_set(pixels.astype(np.float32).ravel())
    image.filepath_raw=str(out/(material.name+'_normal.png'));image.file_format='PNG';image.save()
    tex=nodes.new('ShaderNodeTexImage');tex.image=image
    normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35 if bark else .18
    links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],bsdf.inputs['Normal'])
    rough=.28 if eye else .52 if metal else .76 if bark else .68 if tusk else .62 if key=='M03' else .80
    if 'linen' in label:rough=.91
    if 'harness' in label or 'cord' in label:rough=.84
    bsdf.inputs['Roughness'].default_value=rough
    if metal:bsdf.inputs['Metallic'].default_value=.74
    # ORM variation is restrained, without tinting any body identity texture.
    green=np.clip(rough+noise*(.05 if metal else .035),.15,.95)
    blue=np.full_like(x,.74 if metal else 0)
    orm=np.stack((np.ones_like(x),green,blue,np.ones_like(x)),axis=-1)
    img=bpy.data.images.new(key+'_'+material.name+'_orm',width=size,height=size,alpha=False)
    img.colorspace_settings.name='Non-Color';img.pixels.foreach_set(orm.astype(np.float32).ravel())
    img.filepath_raw=str(out/(material.name+'_orm.png'));img.file_format='PNG';img.save()
    texture=nodes.new('ShaderNodeTexImage');texture.image=img
    channels=nodes.new('ShaderNodeSeparateColor');links.new(texture.outputs['Color'],channels.inputs[0])
    links.new(channels.outputs[1],bsdf.inputs['Roughness']);links.new(channels.outputs[2],bsdf.inputs['Metallic'])

materials=list(dict.fromkeys(m for o in meshes for m in o.data.materials if m))
for i,m in enumerate(materials):surface_images(m,i)

if key=='M04':
    # Small enough to preserve articulation and external encounter dimensions.
    for o in meshes:
        bevel=o.modifiers.new('Worn plate edge light catch','BEVEL');bevel.width=.0012;bevel.segments=2
        bevel.limit_method='ANGLE';bevel.angle_limit=.72
        bpy.context.view_layer.objects.active=o
        bpy.ops.object.modifier_move_to_index(modifier=bevel.name,index=0)
        bpy.ops.object.modifier_apply(modifier=bevel.name)

after=bounds()
scene=bpy.context.scene;scene['finishing_scope']='Asset-by-asset 2026-11-01; candidate, user visual acceptance pending'
scene['source_runtime']=str(base);scene['source_runtime_sha256']=digest
scene['changes']=json.dumps(changes)
rig.data.pose_position='POSE'
bpy.ops.object.select_all(action='DESELECT')
for o in meshes+[rig]:o.select_set(True)
parent=rig.parent
while parent:
    parent.select_set(True);parent=parent.parent
bpy.context.view_layer.objects.active=rig
# Re-enable imported NLA action ownership for faithful ACTIONS export.
if rig.animation_data:
    for t in rig.animation_data.nla_tracks:t.mute=False
# Keep the import scene's 24 fps: changing it after import retimes every clip.
target=out/(key+'_refined.glb')
bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,
    export_skins=True,export_animations=True,export_animation_mode='ACTIONS',
    export_force_sampling=True,export_yup=True,export_extras=True)

# The export is made before review-stage cameras/lights. Save a clean editable
# master with all images packed, then render consistent front/side/rear views.
for image in bpy.data.images:
    if image.source=='FILE':
        try:image.pack()
        except RuntimeError:pass
bpy.ops.wm.save_as_mainfile(filepath=str(master))
if rig.animation_data:
    rig.animation_data.action=None
    for t in rig.animation_data.nla_tracks:t.mute=True
    idle=next((a for a in bpy.data.actions if a.name=='Idle'),None)
    if idle:
        rig.animation_data.action=idle
        if hasattr(rig.animation_data,'action_slot') and idle.slots:rig.animation_data.action_slot=idle.slots[0]
scene.frame_set(8);bpy.context.view_layer.update()
def actual_bounds():
    deps=bpy.context.evaluated_depsgraph_get();points=[]
    for o in meshes:
        ev=o.evaluated_get(deps);points.extend(ev.matrix_world@Vector(p) for p in ev.bound_box)
    lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)])
    return lo,hi
lo,hi=actual_bounds();center=(lo+hi)*.5;span=max(hi.z-lo.z,hi.x-lo.x)*1.15
scene.render.engine='CYCLES';scene.cycles.samples=8
scene.render.resolution_x=480;scene.render.resolution_y=600;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral overcast art review');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.14,.16,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
for location,power,size in [((-3,-4,6),500,4),((4,1,4),350,3)]:
    light=bpy.data.lights.new('Review softbox','AREA');light.energy=power*height*height;light.shape='DISK';light.size=size*height
    ob=bpy.data.objects.new(light.name,light);scene.collection.objects.link(ob);ob.location=center+Vector(location)*height
    ob.rotation_euler=(center-ob.location).to_track_quat('-Z','Y').to_euler()
camera_data=bpy.data.cameras.new('Review camera');camera=bpy.data.objects.new('Review camera',camera_data);scene.collection.objects.link(camera);scene.camera=camera
camera_data.type='ORTHO';camera_data.ortho_scale=span*1.15
for name,angle in [('front',0),('quarter',.65),('side',math.pi/2),('rear',math.pi)]:
    camera.location=center+Vector((math.sin(angle)*height*4,-math.cos(angle)*height*4,height*.08))
    camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(evidence/(name+'.png'));bpy.ops.render.render(write_still=True)
report={'id':key,'baseline_runtime':str(base),'baseline_sha256':digest,'baseline_layered_master':row['source_path'],
 'source_path':str(master),'runtime_path':str(target),'changes':changes,'before_bounds':before,'after_bounds':after,
 'actions':[a.name for a in bpy.data.actions], 'rendered_views':['front','quarter','side','rear'],
 'limitations':'Retained adapted action library, not a new species-specific performance; final regional/user visual acceptance pending.',
 'user_accepted':False}
(evidence/'candidate.json').write_text(json.dumps(report,indent=2)+'\n')
print('REFINEMENT_COMPLETE',key,flush=True)
