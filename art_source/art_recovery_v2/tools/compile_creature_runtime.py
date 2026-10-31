"""Compile one editable creature into a consolidated private runtime derivative."""
import argparse
import hashlib
import json
import sys
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT.parents[1] / 'outputs/AshenOathTheRoadBetweenCrowns'
parser = argparse.ArgumentParser()
parser.add_argument('--id', required=True, choices=('M07', 'M13'))
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
ledger = json.loads((ROOT/'stylized_roster.json').read_text())
row = next(r for r in ledger['assets'] if r['id'] == args.id)
source = Path(row['source_path'])
digest = hashlib.sha256(source.read_bytes()).hexdigest()
out = GAME / 'art_review/stylized' / args.id / 'runtime_compiled'
out.mkdir(parents=True, exist_ok=False)
bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False)
rigs = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
if len(rigs) != 1:
    raise ValueError('Expected one authoritative native rig')
rig = rigs[0]
originals = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.find_armature() == rig]
copies = []
for obj in originals:
    copy = obj.copy()
    copy.data = obj.data.copy()
    bpy.context.collection.objects.link(copy)
    copies.append(copy)
    obj.hide_render = True
bpy.ops.object.select_all(action='DESELECT')
for obj in copies:
    obj.select_set(True)
bpy.context.view_layer.objects.active = copies[0]
if len(copies) > 1:
    bpy.ops.object.join()
body = bpy.context.object
body.name = args.id + '_CompiledPrivateBody'
triangles = sum(len(f.vertices)-2 for f in body.data.polygons)
target = 34000 if args.id == 'M07' else 20000
if triangles > target and not body.data.shape_keys:
    modifier = body.modifiers.new('UVPreservingBudget', 'DECIMATE')
    modifier.ratio = target / triangles
    modifier.delimit = {'UV','MATERIAL','SEAM'}
    bpy.ops.object.modifier_move_to_index(modifier=modifier.name, index=0)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
rig.select_set(True)
parent = rig.parent
while parent:
    parent.select_set(True)
    parent = parent.parent
bpy.context.view_layer.objects.active = rig
glb = out / (args.id + '_runtime.glb')
bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True, export_skins=True,
                          export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
                          export_yup=True, export_extras=True)
sys.path.insert(0, str(ROOT/'tools'))
import stylized_wildlife as preview
from mathutils import Vector
preview.bpy, preview.Vector = bpy, Vector
preview.render_views([body], out)
if hashlib.sha256(source.read_bytes()).hexdigest() != digest:
    raise ValueError('Editable source unexpectedly changed')
(out/'candidate.json').write_text(json.dumps({
    'id':args.id, 'source_path':str(source), 'runtime_path':str(glb), 'source_sha256':digest,
    'before_triangles':triangles, 'after_triangles':sum(len(f.vertices)-2 for f in body.data.polygons),
    'private_only':True, 'user_accepted':False,
    'limitations':row['limitations']+' Runtime-only consolidation/reduction preserves editable source and UV/material boundaries; final motion remains unaccepted.'
}, indent=2)+'\n')
print('PRIVATE_RUNTIME_COMPILED', args.id, flush=True)
