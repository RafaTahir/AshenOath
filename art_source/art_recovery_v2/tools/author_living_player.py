"""Author Kael's two stowed-only idles using the retained actor pipeline."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import author_living_cast_stage2 as retained


def pose(rig, asset, clip, phase):
    hands = {side: rig.pose.bones['hand_'+side].matrix.copy() for side in ('l', 'r')}
    breath = math.sin(math.pi*phase)**2
    if clip == 'Life_Idle_A':
        retained.turn(rig, 'spine_02', (1, 0, 0), .009*breath)
        retained.turn(rig, 'spine_03', (1, 0, 0), -.004*breath)
        retained.turn(rig, 'clavicle_l', (0, 1, 0), .009*breath)
        retained.turn(rig, 'clavicle_r', (0, 1, 0), -.009*breath)
        retained.turn(rig, 'Head', (1, 0, 0), -.006*breath)
    elif clip == 'Life_Idle_B':
        left = retained.pulse(phase, .30, .25)
        right = retained.pulse(phase, .72, .22)
        retained.turn(rig, 'Head', (0, 0, 1), .065*left-.045*right)
        retained.turn(rig, 'spine_03', (0, 0, 1), .013*left-.009*right)
        retained.turn(rig, 'clavicle_l', (0, 1, 0), .015*right)
        retained.turn(rig, 'clavicle_r', (0, 1, 0), -.014*left)
    else:
        raise ValueError('Kael life library is explicitly idle-only')
    # Keep the real stowed-hand positions and wrist frames. Existing clothing
    # and straps move with their retained chest/shoulder skinning; no rigid
    # weapon or equipment socket is independently animated here.
    for side, original in hands.items():
        retained.hand_goal(rig, side, original.translation, 1.0)
        hand = rig.pose.bones['hand_'+side]
        hand.matrix = Matrix.LocRotScale(hand.matrix.translation, original.to_quaternion(), original.to_scale())
        bpy.context.view_layer.update()


def snapshot():
    names = ['author_living_player.py', 'author_living_cast_stage2.py',
             'living_cast_stage2_profiles.py', 'living_cast_stage2_motion.py', 'living_cast_stage2_preview.py']
    source = Path(__file__).resolve().parent
    hashes = {name: retained.sha(source/name) for name in names}
    identity = hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest()
    folder = retained.MODELS/'recipes'/identity[:16]
    folder.mkdir(parents=True, exist_ok=True)
    files = []
    for name in names:
        path = folder/name
        if path.exists() and retained.sha(path) != hashes[name]:
            raise ValueError('Player recipe snapshot collision')
        if not path.exists():
            path.write_bytes((source/name).read_bytes())
        files.append({'name': name, 'path': str(path.relative_to(retained.ROOT)), 'sha256': hashes[name]})
    return {'sha256': identity, 'files': files, 'reproduce': 'Run author_living_player.py with retained --art-root and --source-game.'}


def main(args):
    retained.ROOT = args.art_root
    retained.GAME = args.source_game
    retained.EVIDENCE = args.art_root/'evidence/living_assets_stage3_20261107/player'
    retained.MODELS = args.art_root/'models/living_assets_stage3_20261107/player'
    retained.CLIPS = {'Life_Idle_A': 6, 'Life_Idle_B': 8}
    retained.PROFILES = {'P01': {'identity': 'kael', 'occupation': 'stowed stationary presence',
        'contact_required': False,
        'intent': 'Restrained native chest/garment breathing and a separate searching glance; grounded feet and retained hand grips.',
        'runtime_eligibility': 'Weapons stowed, stationary, controllable, no dialogue/combat/action/transition'}}
    retained.pose = pose
    retained.snapshot_recipe = snapshot
    retained.main('P01', False, calibrate_contacts=False)
    report_path = retained.MODELS/'P01/authoring.json'
    report = json.loads(report_path.read_text())
    report.pop('work_contact_phase', None)
    report['idle_only'] = True
    report['player_author_tool_sha256'] = retained.sha(__file__)
    report['grip_and_garment_status'] = 'pending native stowed-hand and retained garment/strap review'
    report['notes'] = ['Exactly two native stowed idle clips; no work, locomotion or combat replacement.',
        'Retained chest/shoulder skinning supplies garment/strap movement; no separate rigid-prop wobble.',
        'Full mesh carrier is authoring-only; the extracted actor-owned AnimationLibrary ships.']
    report_path.write_text(json.dumps(report, indent=2)+'\n')
    if args.render:
        render_views(retained.MODELS/'P01')


def render_views(folder):
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.render.resolution_x = 720
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.display.shading.color_type = 'MATERIAL'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    camera_data = bpy.data.cameras.new('StowedIdleReview')
    camera = bpy.data.objects.new('StowedIdleReview', camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.location = (3.4, 5.2, 2.4)
    camera.rotation_euler = (Vector((0,0,1))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera_data.type = 'ORTHO'
    camera_data.ortho_scale = 2.35
    rig = next(obj for obj in bpy.data.objects if obj.type == 'ARMATURE')
    for clip,phase in [('Life_Idle_A',.25),('Life_Idle_A',.50),('Life_Idle_B',.30),('Life_Idle_B',.72)]:
        action = bpy.data.actions[clip]
        rig.animation_data.action = action
        rig.animation_data.action_slot = action.slots[0]
        scene.frame_set(round(retained.CLIPS[clip]*retained.FPS*phase))
        bpy.context.view_layer.update()
        scene.render.filepath = str(folder/(clip+'_'+str(round(phase*100))+'.png'))
        bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--art-root', type=Path, default=retained.ROOT)
    parser.add_argument('--source-game', type=Path, default=retained.GAME)
    parser.add_argument('--render', action='store_true')
    main(parser.parse_args(sys.argv[sys.argv.index('--')+1:]))
