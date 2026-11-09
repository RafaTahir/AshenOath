"""Author a Stage2 retained actor's native life clips in Blender 5.2.

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
EVIDENCE = ROOT / "evidence/living_cast_stage2_20261107"
MODELS = ROOT / "models/living_cast_stage2_20261107"
FPS = 30
sys.path.insert(0, str(Path(__file__).resolve().parent))
from living_cast_stage2_profiles import CLIPS, PROFILES
from living_cast_stage2_motion import apply as apply_stage2_pose
from living_cast_stage2_motion import relax_work_fingers
from living_cast_stage2_preview import render_views as render_stage2_views
CONTACT_PROBES = {}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def snapshot_recipe():
    """Keep the exact recipe revision that authored each editable source."""
    names = ['author_living_cast_stage2.py', 'living_cast_stage2_motion.py',
             'living_cast_stage2_profiles.py', 'living_cast_stage2_preview.py']
    source = Path(__file__).resolve().parent
    digests = {name: sha(source/name) for name in names}
    identity = hashlib.sha256(json.dumps(digests, sort_keys=True).encode()).hexdigest()
    folder = MODELS/'recipes'/identity[:16]
    folder.mkdir(parents=True, exist_ok=True)
    files = []
    for name in names:
        destination = folder/name
        data = (source/name).read_bytes()
        if destination.exists() and sha(destination) != digests[name]:
            raise ValueError('Recipe snapshot path collision: '+str(destination))
        if not destination.exists():
            destination.write_bytes(data)
        files.append({'name':name, 'path':str(destination.relative_to(ROOT)), 'sha256':digests[name]})
    return {'sha256':identity, 'files':files,
            'reproduce':'Run snapshotted author_living_cast_stage2.py with --art-root <art_source/art_recovery_v2> and the retained --source-game.'}


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
        middle=inverse @ (rig.matrix_world @ rig.pose.bones['middle_01_'+side].head)
        # The longer retained palm blends its heel into the thumb skin group.
        # A .90 hand-weight filter selects only the thin knuckle edge there,
        # not the actual pressure surface. Keep the measured heel and verify
        # its evaluated surface in the exact authored contact finger pose.
        minimum_weight=.60 if middle.y>.10 else .90
        palm_min,palm_max=.025,.085
        for obj in bpy.context.scene.objects:
            if obj.type!='MESH':continue
            group=obj.vertex_groups.get('hand_'+side)
            if group is None:continue
            evaluated=obj.evaluated_get(graph);mesh=evaluated.to_mesh()
            for original,vertex in zip(obj.data.vertices,mesh.vertices):
                weight=sum(g.weight for g in original.groups if g.group==group.index)
                if weight<minimum_weight:continue
                point=inverse @ (evaluated.matrix_world @ vertex.co)
                # Native front-palm vertices include finger skin weights. The
                # only fully rigid vertex in this region is on the back of the
                # hand, so calibrate the real palm in its authored contact pose.
                sign = 1 if side=='l' else -1
                normal=(inverse.to_3x3().inverted().transposed() @ evaluated.matrix_world.to_3x3().inverted().transposed() @ vertex.normal).normalized()
                if palm_min<=point.y<=palm_max and point.x*sign>.003:
                    if minimum_weight<.90 and (normal.x*sign<.90 or abs(point.z)>.025):continue
                    candidates.append((point,original.index,obj.name,weight))
            evaluated.to_mesh_clear()
        if not candidates:raise ValueError('No retained palm surface: '+side)
        if minimum_weight<.90:
            point,index,name,weight=max(candidates,key=lambda item:item[0].x*(1 if side=='l' else -1))
        else:
            point,index,name,weight=min(candidates,key=lambda item:(item[0]-reference).length)
        if (point-reference).length>.04:raise ValueError('Retained palm probe is outside the measured grip region')
        result[side]={'local':list(point),'source_mesh':name,'source_vertex_index':index,'hand_weight':weight,
                      'minimum_hand_weight':minimum_weight,
                      'reference_distance':(point-reference).length}
    return result


def world_palm_goal(rig, asset, side, goal, weight, flat=False, normal_goal=None):
    if weight<=0:return
    hand=rig.pose.bones['hand_'+side]
    point=Vector(CONTACT_PROBES[asset][side]['local'])
    initial=hand.matrix.copy()
    target=(initial @ point).lerp(rig.matrix_world.inverted() @ Vector(goal),weight)
    # Retain the established goal-facing wrist orientation, then shift the
    # wrist so the measured palm surface (rather than its origin) makes contact.
    world_hand_goal(rig,side,goal,weight)
    retained=hand.matrix.copy()
    if flat or normal_goal is not None:
        # Retained palms lie in the hand's YZ plane: +X on the left,
        # -X on the right. Orient that anatomical palm normal downward,
        # with the finger ray forward, instead of treating local -Z as palm.
        normal=Vector((1 if side=='l' else -1,0,0))
        forward=Vector((0,1,0))
        local=Matrix((forward.cross(normal),forward,normal)).transposed()
        down=Vector(normal_goal if normal_goal is not None else (0,0,-1)).normalized()
        forward=(forward-down*forward.dot(down)).normalized()
        world=Matrix((forward.cross(down),forward,down)).transposed()
        desired=(rig.matrix_world.to_3x3().normalized().inverted() @ world @ local.transposed()).to_quaternion()
        rotation=retained.to_quaternion().slerp(desired,weight)
        retained=Matrix.LocRotScale(retained.translation,rotation,retained.to_scale())
    wrist=target-retained.to_3x3() @ point
    hand_goal(rig,side,wrist,1.0)
    position=hand.matrix.translation.copy()
    hand.matrix=Matrix.LocRotScale(position,retained.to_quaternion(),retained.to_scale())
    bpy.context.view_layer.update()


def pose(rig, asset, clip, phase):
    apply_stage2_pose(rig, asset, clip, phase, {
        'turn': turn, 'pulse': pulse, 'palm_goal': world_palm_goal,
        'hand_goal': world_hand_goal, 'models': MODELS})


def main(asset, render, refresh_work=False):
    # External batch coordination on low-memory hosts; never leave a partial bake.
    if (MODELS / (asset + '.hold')).exists():
        print('LIVING_CAST_HELD', asset, flush=True)
        return
    source = EVIDENCE / (asset+'_baseline.glb')
    registry = json.loads((GAME/'data/design_pack_assets.json').read_text())
    production = GAME / registry['assets'][asset]['path'][6:]
    production_sha = sha(production)
    if asset == 'C10':
        cup = json.loads((MODELS/'props/merrow_cup_calibration.json').read_text())
        if cup.get('baseline_sha256') != sha(source) or cup.get('carrier_sha256') != sha(MODELS/'props/merrow_cup_world.glb'):
            raise ValueError('Merrow cup calibration no longer matches this retained actor baseline/geometry')
    prior=None
    if refresh_work:
        prior=json.loads((MODELS/asset/'authoring.json').read_text())
        if prior['production_sha256']!=production_sha or prior['baseline_sha256']!=sha(source):
            raise ValueError('Refusing to refresh a work action against changed inputs')
        bpy.ops.wm.open_mainfile(filepath=prior['blend'])
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(source))
    bpy.context.preferences.filepaths.save_version = 0
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
    if asset in PROFILES:
        if asset not in ('C07','C12'):
            for side in ('l','r'):relax_work_fingers(rig,side,1.0)
            bpy.context.view_layer.update()
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
    # The skeletal root's constant native pose is distinct from object/root
    # locomotion. Keep its two identical endpoint keys; compiler rejects motion.
    body_bones = [b for b in rig.pose.bones if not b.name.startswith('Face_')]
    moving_bones={'spine_01','spine_02','spine_03','Head','clavicle_l','clavicle_r',
                  'upperarm_l','upperarm_r','lowerarm_l','lowerarm_r','hand_l','hand_r'}
    moving_bones.update(b.name for b in body_bones if b.name.startswith(('index_','middle_','ring_','pinky_','thumb_')))
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
        measured[clip] = {'duration_seconds':seconds,'sample_hz':FPS,'loop':not clip in ('Life_Drink','Life_Settle_Ledger'),'sampled_points':values}
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
        'motion_recipe_sha256':sha(Path(__file__).with_name('living_cast_stage2_motion.py')),
        'profile_sha256':sha(Path(__file__).with_name('living_cast_stage2_profiles.py')),
        'recipe_snapshot':snapshot_recipe(),
        'packed_images':[image.name for image in bpy.data.images if image.packed_file],
        'blend':str(blend),'blend_sha256':sha(blend),'review_glb':str(output),'review_glb_sha256':sha(output),
        'rig_bones':len(before_rest),'rest_preserved':True,'geometry_preserved':True,'clips':measured,
        'work_contact_phase':.50,'runtime_library':'res://assets_external/characters_prepared/animations/life_'+asset+'.res',
        'grip_and_garment_status':'pending_native_workstation_review','visual_reviewed':False,'user_accepted':False,
        'notes':['New authored native body actions; no new facial tracks or root motion.',
                 'Exact workstation contact and staff grip remain owned by existing runtime IK.',
                 'Full mesh GLB is an authoring review carrier only; extracted AnimationLibrary ships.']}
    if asset in CONTACT_PROBES:
        report['contact_probe_method']='actual retained front-palm surface vertex, recorded hand/adjacent-joint skin weight, measured with the exact authored contact finger pose; evaluated skin verification required at Work phase .50'
        report['contact_probes_blender']=CONTACT_PROBES[asset]
    (destination/'authoring.json').write_text(json.dumps(report,indent=2)+'\n')
    if render:
        render_views(rig,asset,destination)
    print('LIVING_CAST_AUTHORED',asset,str(output),flush=True)


def render_views(rig, asset, destination):
    render_stage2_views(rig, asset, destination, MODELS, PROFILES, CLIPS, FPS)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--asset',choices=PROFILES,required=True);parser.add_argument('--render',action='store_true');parser.add_argument('--render-existing',action='store_true');parser.add_argument('--refresh-work',action='store_true')
    parser.add_argument('--source-game', type=Path, default=GAME)
    parser.add_argument('--art-root', type=Path, default=ROOT)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    ROOT=args.art_root
    EVIDENCE=ROOT/'evidence/living_cast_stage2_20261107'
    MODELS=ROOT/'models/living_cast_stage2_20261107'
    GAME=args.source_game
    CLIPS={**CLIPS, **PROFILES[args.asset].get('extra_clips', {})}
    if args.render_existing:
        destination=MODELS/args.asset
        bpy.ops.wm.open_mainfile(filepath=str(destination/(args.asset+'_living_cast_v001.blend')))
        render_views(next(o for o in bpy.data.objects if o.type=='ARMATURE'),args.asset,destination)
    else:
        main(args.asset,args.render,args.refresh_work)
