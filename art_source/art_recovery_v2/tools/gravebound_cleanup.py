"""Private M04 armour cleanup, using retained fitted clothes and CC0 helmet."""
import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector, Quaternion

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
GAME = REPO / 'outputs/AshenOathTheRoadBetweenCrowns'
sys.path.insert(0, str(ROOT / 'tools'))
import stylized_bipeds as common
sys.path.insert(0, str(ROOT.parent / 'design_pack_v1/tools'))
import build_anwen as shared
common.bpy, common.Vector, common.Matrix, common.Quaternion = bpy, Vector, Matrix, Quaternion
common.shared = shared

out = GAME / 'art_review/stylized/M04/v002'
out.mkdir(parents=True, exist_ok=False)
source = ROOT / 'models/C07_Captain_Senn_stylized_v002.blend'
bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False)
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
rig.data.pose_position = 'POSE'
rig.animation_data_clear()
for bone in rig.pose.bones:
    bone.matrix_basis = Matrix.Identity(4)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.name.startswith('Library_')
          and o.name.endswith(('_Body', '_Arms', '_Legs', '_Feet'))]
if len(meshes) != 4:
    raise ValueError('Expected four retained fitted garment/body surfaces')
for obj in list(bpy.context.scene.objects):
    if obj != rig and obj not in meshes:
        bpy.data.objects.remove(obj, do_unlink=True)
for action in list(bpy.data.actions):
    bpy.data.actions.remove(action)
for obj in meshes:
    obj.hide_set(False)
    obj.hide_render = False
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if obj.data.shape_keys:
        bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
    obj.select_set(False)

bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for bone in list(rig.data.edit_bones):
    if bone.name.startswith('Face_'):
        rig.data.edit_bones.remove(bone)
bpy.ops.object.mode_set(mode='OBJECT')

iron = common.texture_material('M04', 'PittedIron', (.075, .095, .105), out, .78, .72)
linen = common.texture_material('M04', 'FuneraryLinen', (.30, .29, .24), out)
rust = common.texture_material('M04', 'OldRust', (.16, .10, .055), out, .42, .86)
for obj in meshes:
    obj.data.materials.clear()
    obj.data.materials.append(linen if obj.name.endswith('_Legs') else iron)
    for face in obj.data.polygons:
        face.material_index = 0
        face.use_smooth = True

parts = GAME / 'assets_external/raw/quaternius_lowpoly_animated_knight/Knight Character by @Quaternius/Blends'
def append_part(filename, label, center, dimensions, bone, grip=False):
    with bpy.data.libraries.load(str(parts / filename), link=False) as (available, loaded):
        loaded.objects = list(available.objects)
    objs = []
    for obj in loaded.objects:
        if obj.type != 'MESH':
            continue
        bpy.context.collection.objects.link(obj)
        world = [obj.matrix_world @ v.co for v in obj.data.vertices]
        lo = Vector(tuple(min(p[k] for p in world) for k in range(3)))
        hi = Vector(tuple(max(p[k] for p in world) for k in range(3)))
        pivot = (lo + hi) / 2
        if grip:
            pivot.z = lo.z + (hi.z - lo.z) * .15
        scale = Vector(tuple(dimensions[k] / max(.001, hi[k] - lo[k]) for k in range(3)))
        for vertex, point in zip(obj.data.vertices, world):
            local = Vector(tuple((point[k] - pivot[k]) * scale[k] for k in range(3)))
            vertex.co = (rig.data.bones[bone].matrix_local.to_3x3() @ local + center) if grip else local + center
        obj.parent = rig
        obj.matrix_world = rig.matrix_world.copy()
        obj.data.materials.clear()
        obj.data.materials.append(iron)
        obj.vertex_groups.clear()
        obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
        obj.modifiers.clear()
        obj.modifiers.new('RigidSocket', 'ARMATURE').object = rig
        obj.name = label
        obj.hide_render = False
        obj.hide_set(False)
        for face in obj.data.polygons:
            face.material_index = 0
        if not obj.data.uv_layers:
            layer = obj.data.uv_layers.new(name='UVMap')
            for loop in layer.data:
                loop.uv = (.5, .5)
        objs.append(obj)
    return objs

meshes += append_part('Helmet1.blend', 'M04_ClosedHelm', Vector((0, .005, 1.695)), (.225, .255, .285), 'Head')
meshes += append_part('Sword.blend', 'M04_StraightSword', rig.data.bones['hand_r'].head_local,
                      (.17, .045, 1.06), 'hand_r', True)

# Closed eight-sided shield: intentional accessory topology, not proxy anatomy.
outline = [(-.19, .45), (.18, .45), (.25, .30), (.23, -.20), (.09, -.47), (-.12, -.45), (-.24, -.20), (-.25, .28)]
hand = rig.data.bones['hand_l'].head_local
vertices = [(hand.x + x, hand.y + y, hand.z + z) for y in (-.105, -.055) for x, z in outline]
faces = [tuple(reversed(range(8))), tuple(range(8, 16))] + [(i, (i+1)%8, (i+1)%8+8, i+8) for i in range(8)]
shield = shared.mesh_object('M04_AsymmetricShield', vertices, faces, iron)
shield.parent = rig
shield.vertex_groups.new(name='hand_l').add(list(range(16)), 1, 'REPLACE')
shield.modifiers.new('ShieldSocket', 'ARMATURE').object = rig
shield.data.uv_layers.new(name='UVMap')
meshes.append(shield)

bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
meshes = [bpy.context.object]
meshes[0].name = 'M04_FittedArmourAssembly'
common.RETAINED_BODIES = set(common.RETAINED_BODIES) - {'M04'}
clips = common.embed_clips('M04', rig)
root = bpy.data.objects.new('M04_CandidateRoot', None)
bpy.context.collection.objects.link(root)
lo, hi = common.bounds(meshes)
factor = 1.88 / (1.84 - lo.z)
for obj in [o for o in bpy.context.scene.objects if o != root and o.parent is None]:
    matrix = obj.matrix_world.copy()
    obj.parent = root
    obj.matrix_world = matrix
root.scale = (factor,) * 3
root.location.z = -lo.z * factor
bpy.ops.object.select_all(action='DESELECT')
for obj in [root, rig] + meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
glb = out / 'M04_Gravebound_armour.glb'
bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True, export_skins=True,
                          export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
                          export_yup=True, export_extras=True)
model = ROOT / 'models/M04_Gravebound_armour_v002.blend'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(model), compress=True)
common.render_views('M04', rig, meshes, out)
(out / 'candidate.json').write_text(json.dumps({
    'id': 'M04', 'source_path': str(model), 'runtime_path': str(glb),
    'source': str(source), 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
    'license': 'Retained Quaternius CC0 Ranger components; Animated Knight Helmet1/Sword, CC0',
    'license_reference': 'https://quaternius.com/packs/knightcharacter.html',
    'clips': clips, 'user_accepted': False,
    'limitations': ['Adapted sword and zombie locomotion, not bespoke sentinel performance',
                    'Helmet is a retained low-poly enclosed helm, not exact sallet illustration',
                    'Shield clearance and sword alignment require motion/user review',
                    'No Halvern identity, encounter timing or save changes']
}, indent=2) + '\n')
print('M04_ARMOUR_CLEANUP_COMPLETE', flush=True)
