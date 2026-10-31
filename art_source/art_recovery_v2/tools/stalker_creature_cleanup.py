"""M02's single alternative-foundation cleanup; private, existing licensed data."""
import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
GAME = REPO/'outputs/AshenOathTheRoadBetweenCrowns'
sys.path.insert(0,str(ROOT/'tools'))
import stylized_humans as humans
import stylized_bipeds as common

source = GAME/'assets_external/enemies/ultimate_monsters/Creep.glb'
out = GAME/'art_review/stylized/M02/v002'
out.mkdir(parents=True,exist_ok=False)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
rig = next(o for o in bpy.data.objects if o.type=='ARMATURE')
meshes = [o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
if not meshes: raise ValueError('Creature foundation has no bound anatomical mesh')
for obj in meshes:
    for vertex in obj.data.vertices:
        p = obj.matrix_world@vertex.co
        groups = {obj.vertex_groups[g.group].name:g.weight for g in vertex.groups}
        chest = groups.get('Chest',0)
        waist = groups.get('Torso',0)
        p.x *= 1-.15*chest-.20*waist
        vertex.co = obj.matrix_world.inverted()@p
    obj.data.update()

sources = {}
for track in rig.animation_data.nla_tracks:
    for strip in track.strips:
        sources[track.name] = strip.action
        sources[strip.action.name] = strip.action
    track.mute = True
recipes = {
    'Idle':'Idle1_Action','Walking':'Walk1_Action','Running':'Walk2_Action',
    'Attack':'Bite_Action','AttackHeavy':'Punch_Action','Windup':'Roar_Action',
    'Recovery':'Idle2_Action','Block':'Crouch_Action','HitReact':'Damage_Action',
    'Death':'Death_Action','Investigate':'Sniff_Action','Threaten':'Roar_Action',
    'Feed':'Eating_Action','Sleep':'Sleep_loop_Action','Interact':'Sniff_Action',
}
actions = []
for name, original in recipes.items():
    matches = [a for k,a in sources.items() if k==original or k.endswith('|'+original)]
    if not matches: raise ValueError('Missing native creature action: '+original)
    action = matches[0].copy()
    action.name = name
    action.use_fake_user = True
    actions.append(action)
rig.animation_data.action = None
for track in list(rig.animation_data.nla_tracks): rig.animation_data.nla_tracks.remove(track)
for action in list(bpy.data.actions):
    if action not in actions: bpy.data.actions.remove(action)
for action in actions:
    track = rig.animation_data.nla_tracks.new()
    track.name = action.name
    track.strips.new(action.name,1,action)
    track.mute = True
for bone in rig.pose.bones: bone.matrix_basis = Matrix.Identity(4)

humans.bpy = bpy
humans.private_materials(meshes,out/'textures',{'name':'Wychwood_Stalker','colors':['56634D']})
root = bpy.data.objects.new('M02_Stalker_CreatureRoot',None)
bpy.context.collection.objects.link(root)
points = [o.matrix_world@v.co for o in meshes for v in o.data.vertices]
low = min(p.z for p in points)
height = max(p.z for p in points)-low
for obj in list(bpy.context.scene.objects):
    if obj!=root and obj.parent is None:
        matrix = obj.matrix_world.copy()
        obj.parent = root
        obj.matrix_world = matrix
root.scale = (1.60/height,)*3
root.location.z = -low*root.scale.z
bpy.context.view_layer.update()
rig['asset_design_id'] = 'M02'
rig['art_status'] = 'GROUNDED_STYLIZED_CANDIDATE_AWAITING_USER'
rig['foundation'] = 'Retained CC0 Creep; independent anatomical/animation family, not humanoid recolour'
bpy.ops.object.select_all(action='DESELECT')
for obj in [root,rig]+meshes: obj.select_set(True)
bpy.context.view_layer.objects.active = rig
glb = out/'M02_Stalker_creature.glb'
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,
                          export_skins=True,export_animations=True,export_animation_mode='ACTIONS',
                          export_force_sampling=True,export_yup=True,export_extras=True)
model = ROOT/'models/M02_Stalker_creature_v002.blend'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(model),compress=True)
common.bpy, common.Vector, common.Matrix = bpy, Vector, Matrix
common.render_views('M02',rig,meshes,out)
receipt = {'id':'M02','source':str(source),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
           'source_path':str(model),'runtime_path':str(glb),'native_clips':recipes,
           'joints':len(rig.data.bones),'status':'unaccepted_private_candidate',
           'limitations':['Distinct creature foundation, not exact illustration likeness',
                          'Four-digit hands and three-segment legs retained',
                          'Running adapts Walk2; windup/recovery adapt existing native actions',
                          'Encounter timings, hurtboxes and population unchanged; no gameplay claim']}
(out/'candidate.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('M02_CREATURE_CLEANUP_COMPLETE',flush=True)
