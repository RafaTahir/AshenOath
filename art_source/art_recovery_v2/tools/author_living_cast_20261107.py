"""Author one retained actor's native life clips in Blender 5.2.

Input is the isolated Godot export of the production prepared actor with its
existing Idle attached. No production mesh, rig or source animation is replaced.
The full-mesh GLB is a review carrier; only its AnimationLibrary ships.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
GAME = REPO / "outputs/AshenOathTheRoadBetweenCrowns"
EVIDENCE = ROOT / "evidence/living_cast_20261107"
MODELS = ROOT / "models/living_cast_20261107"
FPS = 30
CLIPS = {"Life_Idle_A": 6, "Life_Idle_B": 8, "Life_Work": 4,
         "Life_Listen": 4, "Life_Speak": 4}
CONTACT_PROBES = {}
PROFILES = {
    "C01": {"name": "Anwen", "activity": "care", "scale": .65,
            "intent": "Settled breath, attentive lean, brief shawl check, deliberate care-table cloth motion."},
    "C04": {"name": "Tor", "activity": "forge", "scale": 1.0,
            "intent": "Heavy chest breath, shoulder release, measured hammer lift and deliberate strike."},
    "C03": {"name": "Mira", "activity": "herbs", "scale": .8,
            "intent": "Quiet breath, sleeve adjustment, alternating herb sort and inspection."},
    "C02": {"name": "Rook", "activity": "check_supplies", "scale": 1.1,
            "intent": "Alert breath, brief cartward glance, two-handed pull-check-release of the supplies satchel strap."},
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def turn(rig, name, axis, amount):
    """Rotate in armature space, preserving the joint origin and scale."""
    bone = rig.pose.bones.get(name)
    if bone is None:
        raise ValueError("Required retained bone missing: " + name)
    position, rotation, scale = bone.matrix.decompose()
    bone.matrix = Matrix.LocRotScale(position, Quaternion(Vector(axis), amount) @ rotation, scale)
    bpy.context.view_layer.update()


def pulse(phase, center=.5, width=.3):
    distance = abs(phase-center)
    if distance >= width:
        return 0.0
    return .5 + .5 * math.cos(math.pi * distance / width)


def hand_goal(rig, side, goal, weight):
    """Bake a bounded two-bone goal, retaining the native elbow bend plane."""
    if weight <= 0:
        return
    upper=rig.pose.bones['upperarm_'+side]
    lower=rig.pose.bones['lowerarm_'+side]
    hand=rig.pose.bones['hand_'+side]
    shoulder=upper.head.copy();elbow=lower.head.copy();wrist=hand.head.copy()
    goal=wrist.lerp(Vector(goal),weight)
    l1=(elbow-shoulder).length;l2=(wrist-elbow).length
    direction=goal-shoulder
    distance=max(.01,min(direction.length,l1+l2-.008))
    direction.normalize();goal=shoulder+direction*distance
    plane=elbow-shoulder-direction*(elbow-shoulder).dot(direction)
    if plane.length < .001:
        plane=Vector((1 if side=='l' else -1,0,0)).cross(direction)
    plane.normalize()
    cosine=max(-1,min(1,(l1*l1+distance*distance-l2*l2)/(2*l1*distance)))
    desired_elbow=shoulder+direction*(l1*cosine)+plane*(l1*math.sqrt(1-cosine*cosine))
    q=(elbow-shoulder).rotation_difference(desired_elbow-shoulder)
    pos,rot,scale=upper.matrix.decompose();upper.matrix=Matrix.LocRotScale(pos,q@rot,scale)
    bpy.context.view_layer.update()
    q=(hand.head-lower.head).rotation_difference(goal-lower.head)
    pos,rot,scale=lower.matrix.decompose();lower.matrix=Matrix.LocRotScale(pos,q@rot,scale)
    bpy.context.view_layer.update()


def world_hand_goal(rig, side, goal, weight):
    """Station-relative XYZ here are lateral, forward and height in metres."""
    hand_goal(rig, side, rig.matrix_world.inverted() @ Vector(goal), weight)


def measure_palm_surfaces(rig):
    """Calibrate a real retained palm vertex in the exact native Idle pose."""
    graph=bpy.context.evaluated_depsgraph_get();result={}
    for side in ['l','r']:
        inverse=(rig.matrix_world @ rig.pose.bones['hand_'+side].matrix).inverted()
        candidates=[];reference=Vector((0,.045,-.012))
        for obj in bpy.context.scene.objects:
            if obj.type!='MESH':continue
            group=obj.vertex_groups.get('hand_'+side)
            if group is None:continue
            evaluated=obj.evaluated_get(graph);mesh=evaluated.to_mesh()
            for original,vertex in zip(obj.data.vertices,mesh.vertices):
                weight=sum(g.weight for g in original.groups if g.group==group.index)
                if weight<.90:continue
                point=inverse @ (evaluated.matrix_world @ vertex.co)
                if .025<=point.y<=.085:candidates.append((point,original.index,obj.name,weight))
            evaluated.to_mesh_clear()
        if not candidates:raise ValueError('No retained palm surface: '+side)
        point,index,name,weight=min(candidates,key=lambda item:(item[0]-reference).length)
        if (point-reference).length>.04:raise ValueError('Retained palm probe is outside the measured grip region')
        result[side]={'local':list(point),'source_mesh':name,'source_vertex_index':index,'hand_weight':weight,
                      'reference_distance':(point-reference).length}
    return result


def world_palm_goal(rig, asset, side, goal, weight):
    if weight<=0:return
    hand=rig.pose.bones['hand_'+side]
    point=Vector(CONTACT_PROBES[asset][side]['local'])
    initial=hand.matrix.copy()
    target=(initial @ point).lerp(rig.matrix_world.inverted() @ Vector(goal),weight)
    # Retain the established goal-facing wrist orientation, then shift the
    # wrist so the measured palm surface (rather than its origin) makes contact.
    world_hand_goal(rig,side,goal,weight)
    retained=hand.matrix.copy()
    wrist=target-retained.to_3x3() @ point
    hand_goal(rig,side,wrist,1.0)
    position=hand.matrix.translation.copy()
    hand.matrix=Matrix.LocRotScale(position,retained.to_quaternion(),retained.to_scale())
    bpy.context.view_layer.update()


def pose(rig, asset, clip, phase):
    profile = PROFILES[asset]
    power = profile['scale']
    breath = math.sin(phase*math.tau)
    # The planted lower body remains the exact retained Idle pose. Motion is
    # deliberately upper-body only; collision/root motion remain authoritative.
    turn(rig, 'spine_02', (1,0,0), .008*breath*power)
    turn(rig, 'spine_03', (1,0,0), -.004*breath*power)
    if clip == 'Life_Idle_A':
        turn(rig, 'clavicle_l', (0,1,0), .009*breath*power)
        turn(rig, 'clavicle_r', (0,1,0), -.009*breath*power)
    elif clip == 'Life_Idle_B':
        beat = pulse(phase, .48, .34)
        turn(rig, 'spine_03', (0,0,1), (.025 if asset != 'C02' else -.055)*beat)
        turn(rig, 'Head', (0,0,1), (.035 if asset != 'C02' else -.11)*beat)
        if asset in ('C01','C03'):
            turn(rig, 'upperarm_l', (1,0,0), -.13*beat)
            turn(rig, 'lowerarm_l', (1,0,0), -.32*beat)
            turn(rig, 'hand_l', (0,0,1), .08*beat)
        else:
            turn(rig, 'clavicle_r', (0,1,0), -.07*beat)
            turn(rig, 'upperarm_r', (0,1,0), -.08*beat)
            turn(rig, 'lowerarm_r', (1,0,0), -.14*beat)
    elif clip == 'Life_Work':
        # All authored work cycles have their principal contact at phase .50.
        # Runtime workstation IK owns exact hand targets, sockets and floor.
        contact = pulse(phase, .50, .29)
        lift = pulse(phase, .24, .22)
        release = pulse(phase, .76, .22)
        if asset == 'C04':
            turn(rig, 'spine_01', (1,0,0), .12*contact)
            turn(rig, 'spine_02', (1,0,0), .08*contact)
            turn(rig, 'upperarm_r', (1,0,0), -.55*lift-.16*contact)
            turn(rig, 'lowerarm_r', (1,0,0), -.62*lift-.28*contact)
            turn(rig, 'upperarm_l', (1,0,0), -.19*contact)
            turn(rig, 'lowerarm_l', (1,0,0), -.30*contact)
            turn(rig, 'hand_r', (0,1,0), .10*contact)
            hand_goal(rig,'r',(-.25,-.28,1.46),lift)
            world_hand_goal(rig,'r',(.18,.35,1.185),contact)
            hand_goal(rig,'l',(.25,-.32,.94),contact)
        elif asset == 'C02':
            turn(rig, 'spine_01', (1,0,0), .32*contact)
            turn(rig, 'spine_02', (1,0,0), .18*contact)
            turn(rig, 'spine_03', (1,0,0), .03*contact)
            turn(rig, 'Head', (1,0,0), -.16*contact)
            for side, sign in [('l',1),('r',-1)]:
                turn(rig, 'upperarm_'+side, (1,0,0), -.27*contact)
                turn(rig, 'lowerarm_'+side, (1,0,0), -.39*contact-.12*release)
                turn(rig, 'hand_'+side, (0,0,1), sign*.17*contact)
                world_palm_goal(rig,asset,side,(-sign*.10,.48,1.11),contact)
        else:
            if asset == 'C03':
                turn(rig, 'spine_01', (1,0,0), .35*contact)
                turn(rig, 'spine_02', (1,0,0), .20*contact)
                turn(rig, 'spine_03', (1,0,0), .06*contact)
                turn(rig, 'Head', (1,0,0), -.22*contact)
            else:
                turn(rig, 'spine_02', (1,0,0), .028*contact)
            turn(rig, 'upperarm_l', (1,0,0), -.30*contact)
            turn(rig, 'lowerarm_l', (1,0,0), -.55*contact)
            if asset=='C01':
                hand_goal(rig,'l',(.25,-.37,1.11),contact)
            else:
                world_palm_goal(rig,asset,'l',(-.12,.44,.9521172),contact)
            if asset != 'C01':
                turn(rig, 'upperarm_r', (1,0,0), -.34*lift-.28*contact)
                turn(rig, 'lowerarm_r', (1,0,0), -.55*lift-.49*contact)
                turn(rig, 'hand_r', (0,0,1), .13*contact-.08*release)
                hand_goal(rig,'r',(-.23,-.34,1.00),lift)
                world_palm_goal(rig,asset,'r',(.12,.44,.9521172),contact)
            turn(rig, 'Head', (1,0,0), .035*contact)
    elif clip == 'Life_Listen':
        beat = pulse(phase, .58, .24)
        turn(rig, 'spine_03', (1,0,0), .018*beat)
        turn(rig, 'Head', (1,0,0), .035*beat)
        turn(rig, 'clavicle_l', (0,1,0), .012*beat)
    elif clip == 'Life_Speak':
        beat = pulse(phase, .44, .31)
        turn(rig, 'spine_03', (0,0,1), .022*beat*power)
        turn(rig, 'upperarm_r', (1,0,0), -.20*beat*power)
        turn(rig, 'lowerarm_r', (1,0,0), -.33*beat*power)
        turn(rig, 'hand_r', (0,0,1), -.16*beat)


def main(asset, render, refresh_work=False):
    # External batch coordination on low-memory hosts; never leave a partial bake.
    if (MODELS / (asset + '.hold')).exists():
        print('LIVING_CAST_HELD', asset, flush=True)
        return
    source = EVIDENCE / (asset+'_baseline.glb')
    registry = json.loads((GAME/'data/design_pack_assets.json').read_text())
    production = GAME / registry['assets'][asset]['path'][6:]
    production_sha = sha(production)
    prior=None
    if refresh_work:
        prior=json.loads((MODELS/asset/'authoring.json').read_text())
        if prior['production_sha256']!=production_sha or prior['baseline_sha256']!=sha(source):
            raise ValueError('Refusing to refresh a work action against changed inputs')
        bpy.ops.wm.open_mainfile(filepath=prior['blend'])
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(source))
    rigs = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
    if len(rigs) != 1:
        raise ValueError('Expected exactly one retained actor skeleton')
    rig = rigs[0]
    before_rest = {b.name: list(map(list,b.matrix_local)) for b in rig.data.bones}
    before_geometry = {o.name: len(o.data.vertices) for o in bpy.data.objects if o.type=='MESH'}
    mesh_visibility={o.name:o.hide_get() for o in bpy.data.objects if o.type=='MESH'}
    # Pose solving needs the skeleton, not repeatedly evaluated skinning of all
    # review meshes. Restore visibility before saving/exporting/rendering.
    rig.animation_data_create()
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    idle = bpy.data.actions.get('Life_Idle_A' if refresh_work else 'Idle')
    if idle is None:
        raise ValueError('The real prepared actor Idle clip is required')
    rig.animation_data.action = idle
    rig.animation_data.action_slot = idle.slots[0]
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    baseline = {b.name: b.matrix_basis.copy() for b in rig.pose.bones}
    baseline_points = {n: list(rig.pose.bones[n].head) for n in ['Head','upperarm_l','upperarm_r','hand_l','hand_r','foot_l','foot_r']}
    if asset in ('C02','C03'):
        CONTACT_PROBES[asset]=measure_palm_surfaces(rig)
    for obj in bpy.data.objects:
        if obj.type=='MESH':obj.hide_set(True)
    rig.animation_data.action = None
    for track in list(rig.animation_data.nla_tracks):
        if not refresh_work or track.name=='Life_Work':rig.animation_data.nla_tracks.remove(track)
    for action in list(bpy.data.actions):
        if not refresh_work or action.name=='Life_Work':bpy.data.actions.remove(action)
    bpy.context.scene.render.fps = FPS
    # Authored clips omit facial joints: the face owner keeps gaze/blinks/speech.
    body_bones = [b for b in rig.pose.bones if not b.name.startswith('Face_') and b.name!='root']
    moving_bones={'spine_01','spine_02','spine_03','Head','clavicle_l','clavicle_r',
                  'upperarm_l','upperarm_r','lowerarm_l','lowerarm_r','hand_l','hand_r'}
    measured = dict(prior['clips']) if refresh_work else {}
    destination = MODELS/asset
    for clip, seconds in CLIPS.items():
        if refresh_work and clip!='Life_Work':continue
        print('LIFE_BAKE',asset,clip,flush=True)
        action = bpy.data.actions.new(clip)
        action.use_fake_user = True
        rig.animation_data.action = action
        values = []
        for frame in range(seconds*FPS+1):
            phase = frame/(seconds*FPS)
            for bone in rig.pose.bones:
                bone.matrix_basis = baseline[bone.name].copy()
                bone.rotation_mode = 'QUATERNION'
            bpy.context.view_layer.update()
            pose(rig,asset,clip,phase)
            for bone in body_bones:
                if frame in (0,seconds*FPS):
                    for prop in ['location','rotation_quaternion','scale']:
                        bone.keyframe_insert(prop,frame=frame,group=bone.name)
                elif bone.name in moving_bones:
                    bone.keyframe_insert('rotation_quaternion',frame=frame,group=bone.name)
            if frame in [0,seconds*FPS//4,seconds*FPS//2,seconds*FPS]:
                values.append({'phase':phase,'points':{n:list(rig.pose.bones[n].head) for n in baseline_points},
                    'world_points':{n:list(rig.matrix_world @ rig.pose.bones[n].head) for n in baseline_points}})
                if asset in CONTACT_PROBES:
                    values[-1]['world_contact_probes']={side:list(rig.matrix_world @ rig.pose.bones['hand_'+side].matrix @ Vector(data['local'])) for side,data in CONTACT_PROBES[asset].items()}
        measured[clip] = {'duration_seconds':seconds,'sample_hz':FPS,'loop':True,'sampled_points':values}
        rig.animation_data.action = None
        track = rig.animation_data.nla_tracks.new()
        track.name = clip
        strip = track.strips.new(clip,0,action)
        strip.action_frame_start = 0
        strip.action_frame_end = seconds*FPS
        track.mute = True
    rig.animation_data.action = bpy.data.actions['Life_Idle_A']
    rig.animation_data.action_slot = rig.animation_data.action.slots[0]
    bpy.context.scene.frame_set(0)
    for name,hidden in mesh_visibility.items():bpy.data.objects[name].hide_set(hidden)
    destination.mkdir(parents=True,exist_ok=True)
    blend = destination/(asset+'_living_cast_v001.blend')
    output = destination/(asset+'_life_review.glb')
    for image in bpy.data.images:
        if image.source=='FILE' and not image.packed_file:
            image.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    rig.animation_data.action = None
    # ACTIONS explicitly exports every authored slot without relying on mute/NLA state.
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.context.scene.objects:
        if obj.type in ['MESH','ARMATURE']:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,
        export_animations=True,export_animation_mode='ACTIONS',export_skins=True,
        export_rest_position_armature=True,export_apply=False,export_yup=True,
        export_force_sampling=True,export_frame_range=False)
    if before_rest != {b.name:list(map(list,b.matrix_local)) for b in rig.data.bones}:
        raise ValueError('Retained rest skeleton changed')
    if before_geometry != {o.name:len(o.data.vertices) for o in bpy.data.objects if o.type=='MESH'}:
        raise ValueError('Retained geometry changed')
    if sha(production) != production_sha:
        raise ValueError('Production input was modified')
    report = {'asset':asset,'profile':PROFILES[asset],'production_source':str(production),
        'production_sha256':production_sha,'baseline_sha256':sha(source),'blender_version':bpy.app.version_string,
        'authoring_tool_sha256':sha(Path(__file__)),
        'packed_images':[image.name for image in bpy.data.images if image.packed_file],
        'blend':str(blend),'blend_sha256':sha(blend),'review_glb':str(output),'review_glb_sha256':sha(output),
        'rig_bones':len(before_rest),'rest_preserved':True,'geometry_preserved':True,'clips':measured,
        'work_contact_phase':.50,'runtime_library':'res://assets_external/characters_prepared/animations/life_'+asset+'.res',
        'grip_and_garment_status':'pending_native_workstation_review','visual_reviewed':False,'user_accepted':False,
        'notes':['New authored native body actions; no new facial tracks or root motion.',
                 'Exact workstation contact and staff grip remain owned by existing runtime IK.',
                 'Full mesh GLB is an authoring review carrier only; extracted AnimationLibrary ships.']}
    if asset in CONTACT_PROBES:
        report['contact_probe_method']='nearest retained palm-surface vertex to curled-palm reference in native Idle; hand weight>=.90; source FK preserves wrist orientation'
        report['contact_probes_blender']=CONTACT_PROBES[asset]
    (destination/'authoring.json').write_text(json.dumps(report,indent=2)+'\n')
    if render:
        render_views(rig,asset,destination)
    print('LIVING_CAST_AUTHORED',asset,str(output),flush=True)


def render_views(rig,asset,destination):
    scene=bpy.context.scene
    scene.render.engine='BLENDER_WORKBENCH'
    scene.render.resolution_x=640;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    scene.display.shading.light='STUDIO'
    scene.display.shading.color_type='MATERIAL'
    scene.display.shading.show_shadows=True
    scene.display.shading.show_cavity=True
    scene.display.shading.background_type='WORLD'
    if scene.world is None:
        scene.world=bpy.data.worlds.new('ReviewWorld')
    scene.world.color=(.055,.055,.055)
    # Review-only contact plane. It is created after the source and carrier
    # were saved, so it cannot become runtime scenery or alter the actor.
    plane_height=1.015 if asset=='C01' else .92 if asset=='C04' else .9271172 if asset=='C03' else .93
    bpy.ops.mesh.primitive_cube_add(size=1,location=(0,.56 if asset=='C02' else .43,plane_height))
    marker=bpy.context.object;marker.name='ReviewOnly_WorkPlane'
    marker.scale=(.78,.32,.025)
    material=bpy.data.materials.new('ReviewOnly_Plane');material.diffuse_color=(.22,.15,.09,1)
    marker.data.materials.append(material)
    camera_data=bpy.data.cameras.new('ReviewCamera');camera=bpy.data.objects.new('ReviewCamera',camera_data)
    scene.collection.objects.link(camera);scene.camera=camera
    camera.location=(3.4,5.5,2.5)
    camera.rotation_euler=(Vector((0,0,1))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera_data.type='ORTHO';camera_data.ortho_scale=2.4
    labels=[]
    for side in ['l','r']:
        text_data=bpy.data.curves.new('ReviewOnly_HandLabel_'+side,'FONT')
        text_data.size=.060;text_data.align_x='CENTER';text_data.body='hand_'+side
        text_obj=bpy.data.objects.new('ReviewOnly_HandLabel_'+side,text_data)
        scene.collection.objects.link(text_obj);text_obj.rotation_euler=camera.rotation_euler
        labels.append((side,text_obj))
    tool_probe=None
    if asset=='C04':
        bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.006,depth=.265)
        tool_probe=bpy.context.object;tool_probe.name='ReviewOnly_HammerTipOffsetProbe'
    review_satchel=[]
    satchel_source=MODELS/'props/rook_station_satchel.glb'
    if asset=='C02' and satchel_source.exists():
        previous=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(satchel_source))
        review_satchel=[obj for obj in bpy.data.objects if obj not in previous]
        for obj in review_satchel:
            if obj.parent is None:
                obj.location=(0,.56,.93);obj.rotation_euler.z=math.pi/2
    for clip,phase in [('Life_Idle_A',.25),('Life_Idle_B',.5),('Life_Work',.25),('Life_Work',.5),('Life_Speak',.44)]:
        marker.hide_render=clip!='Life_Work'
        for obj in review_satchel:obj.hide_render=clip!='Life_Work'
        action=bpy.data.actions[clip];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
        scene.frame_set(round(CLIPS[clip]*FPS*phase))
        bpy.context.view_layer.update()
        for side,label in labels:
            point=rig.matrix_world @ rig.pose.bones['hand_'+side].head
            label.location=point+Vector((-.08 if side=='l' else .10,.08,.12))
        if tool_probe is not None:
            tool_probe.hide_render=clip!='Life_Work'
            tool_probe.location=rig.matrix_world @ rig.pose.bones['hand_r'].head+Vector((0,0,-.1325))
        scene.render.filepath=str(destination/(clip+'_'+str(int(phase*100))+'.png'))
        bpy.ops.render.render(write_still=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--asset',choices=PROFILES,required=True);parser.add_argument('--render',action='store_true');parser.add_argument('--render-existing',action='store_true');parser.add_argument('--refresh-work',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    if args.render_existing:
        destination=MODELS/args.asset
        bpy.ops.wm.open_mainfile(filepath=str(destination/(args.asset+'_living_cast_v001.blend')))
        render_views(next(o for o in bpy.data.objects if o.type=='ARMATURE'),args.asset,destination)
    else:
        main(args.asset,args.render,args.refresh_work)
