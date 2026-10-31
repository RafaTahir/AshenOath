"""One bounded retained-root cleanup; old sources and native rig stay intact."""
import json
import math
import sys
from pathlib import Path
import bpy
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT.parents[1] / 'outputs/AshenOathTheRoadBetweenCrowns'
sys.path.insert(0, str(ROOT / 'tools'))
import stylized_bipeds as common
sys.path.insert(0, str(ROOT.parent / 'design_pack_v1/tools'))
import build_anwen as shared
common.bpy, common.Vector, common.Matrix, common.shared = bpy, Vector, Matrix, shared
source = ROOT / 'models/M06_Rootbound_Colossus_stylized.blend'
out = GAME / 'art_review/stylized/M06/v002'
out.mkdir(parents=True, exist_ok=False)
bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False)
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = True
for bone in rig.pose.bones:
    bone.matrix_basis = Matrix.Identity(4)
mesh = next(o for o in bpy.context.scene.objects if o.type == 'MESH' and o.find_armature() == rig)

# The old little pyramid inserts read as a necklace, not bark. Remove only
# those known five-vertex components, leaving the trunk, roots and heartwood.
discard = {i for group in common.components(mesh.data) if len(group) == 5 for i in group}
bm = bmesh.new()
bm.from_mesh(mesh.data)
bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.verts[i] for i in discard], context='VERTS')
bm.to_mesh(mesh.data)
bm.free()
for vertex in mesh.data.vertices:
    p = vertex.co
    values = common.weights(mesh, vertex)
    trunk = values.get('Body', 0) + values.get('Pelvis', 0)
    angle = math.atan2(p.y, p.x)
    ridge = .030 * math.sin(11 * angle + .60 * p.z) + .012 * math.sin(19 * angle - p.z)
    radial = math.hypot(p.x, p.y)
    if radial > .05:
        p.x += ridge * p.x / radial * min(1., trunk + .35)
        p.y += ridge * p.y / radial * min(1., trunk + .35)
    # Broad trunk planes and uneven shoulder heights, not symmetrical armour.
    if trunk > .5:
        p.y *= .82
        p.x *= 1.10
    if values.get('Arm1_0', 0) > .5:
        p.z += .075
mesh.data.update()
bark = common.texture_material('M06', 'WeatheredBark', (.20, .145, .085), out)
core = common.texture_material('M06', 'OldHeartwood', (.24, .12, .045), out)
mesh.data.materials.clear()
mesh.data.materials.append(bark)
mesh.data.materials.append(core)
heart = {i for g in common.components(mesh.data) if len(g) == 39 for i in g}
for face in mesh.data.polygons:
    face.material_index = 1 if all(i in heart for i in face.vertices) else 0
    face.use_smooth = False
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.select_all(action='DESELECT')
mesh.select_set(True)
decimate = mesh.modifiers.new('RuntimeBarkBudget', 'DECIMATE')
decimate.ratio = .57
bpy.ops.object.modifier_move_to_index(modifier=decimate.name, index=0)
bpy.ops.object.modifier_apply(modifier=decimate.name)
rig.select_set(True)
for ancestor in [rig.parent, mesh.parent]:
    if ancestor:
        ancestor.select_set(True)
bpy.context.view_layer.objects.active = rig
glb = out / 'M06_Rootbound_bark.glb'
bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True, export_skins=True,
                          export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
                          export_yup=True, export_extras=True)
model = ROOT / 'models/M06_Rootbound_bark_v002.blend'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(model), compress=True)
common.render_views('M06', rig, [mesh], out)
(out/'candidate.json').write_text(json.dumps({
    'id':'M06', 'source_path':str(model), 'runtime_path':str(glb), 'source':str(source),
    'removed_repetitive_insert_vertices':len(discard), 'user_accepted':False,
    'limitations':['Retained component-based woody anatomy, not complete new retopology',
                   'Native procedural clips retained; root-lane and bark-opening phase motions not authored',
                   'Faceted bark and simplified root fingers need user appearance/motion review']
}, indent=2)+'\n')
print('M06_BARK_CLEANUP_COMPLETE', flush=True)
