"""Correct combined-body export names without touching geometry or animation."""
import hashlib
import json
import shutil
import struct
import sys
import numpy as np
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = Path('D:/Temp/AshenOath/stylized_review/project')
ledger_path = ROOT/'stylized_roster.json'
ledger = json.loads(ledger_path.read_text())
preparation_path = PROJECT/'private_review_preparation.json'
preparation = json.loads(preparation_path.read_text())
assert preparation['publication_authorized'] is False
frozen = PROJECT/'private_candidate_ledger.json'
backup = frozen.with_name('private_candidate_ledger.before-name-repair.json')
if not backup.exists():
    shutil.copy2(frozen, backup)
changed = []
skin_bounds = '--skin-bounds' in sys.argv
canonical_space = '--canonical-mesh-space' in sys.argv

def node_matrix(node):
    if 'matrix' in node:
        return np.array(node['matrix']).reshape((4,4)).T
    x,y,z,w=node.get('rotation',[0,0,0,1])
    result=np.eye(4)
    result[:3,:3]=np.array([
        [1-2*y*y-2*z*z,2*x*y-2*z*w,2*x*z+2*y*w],
        [2*x*y+2*z*w,1-2*x*x-2*z*z,2*y*z-2*x*w],
        [2*x*z-2*y*w,2*y*z+2*x*w,1-2*x*x-2*y*y]]) @ np.diag(node.get('scale',[1,1,1]))
    result[:3,3]=node.get('translation',[0,0,0])
    return result

for row in ledger['assets']:
    path = Path(row['runtime_path'])
    raw = path.read_bytes()
    length = struct.unpack_from('<I', raw, 12)[0]
    document = json.loads(raw[20:20+length])
    count = 0
    if canonical_space:
        nodes=document['nodes']
        parents={child:index for index,node in enumerate(nodes) for child in node.get('children',[])}
        def world(index):
            local=node_matrix(nodes[index])
            return world(parents[index]) @ local if index in parents else local
        for index,node in enumerate(nodes):
            if 'mesh' not in node or 'skin' not in node or np.allclose(world(index),np.eye(4),atol=0.00001):
                continue
            if any(c['target']['node']==index for a in document.get('animations',[]) for c in a['channels']):
                raise ValueError('Animated mesh transform requires explicit authoring: '+row['id'])
            local=np.linalg.inv(world(parents[index])) if index in parents else np.eye(4)
            for key in ('translation','rotation','scale','matrix'):
                node.pop(key,None)
            node['matrix']=local.T.reshape(-1).tolist()
            count+=1
    elif skin_bounds and row['id'] in ('M01','M03','M05','M06','M19','M20'):
        roots=[n for n in document['nodes'] if n.get('name')==row['id']+'_ReviewRoot']
        assert len(roots)==1
        scale=roots[0]['scale']
        assert max(scale)-min(scale)<0.00001 and scale[0]>0
        for node in document['nodes']:
            if 'mesh' not in node or 'skin' not in node:
                continue
            assert not any(k in node for k in ('matrix','translation','rotation','scale')), 'Already transformed mesh; do not repeat'
            # Blender baked vertices and inverse binds already carry the root
            # scale. Skinning ignores the mesh transform; Godot's raw AABB does
            # not. Cancel that scale on the mesh alone, preserving joint-space
            # deformation and the complete source-root rig frame.
            node['scale']=[1/value for value in scale]
            count+=1
    elif not skin_bounds and not canonical_space:
        for node in document.get('nodes', []) + document.get('meshes', []):
            name = node.get('name', '')
            if name.endswith('_Connected_Anatomy_Equipment'):
                node['name'] = name.removesuffix('_Equipment') + '_SkinnedAssembly'
                count += 1
    if not count:
        continue
    baseline=ROOT/'models/runtime_integration_baselines'/(row['id']+('_before_mesh_space.glb' if canonical_space else '_before_bounds.glb' if skin_bounds else '_before_name.glb'))
    baseline.parent.mkdir(parents=True,exist_ok=True)
    if not baseline.exists():
        shutil.copy2(path,baseline)
    encoded = json.dumps(document, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    binary_chunks = raw[20+length:]
    updated = (struct.pack('<4sII', b'glTF', 2, 20+len(encoded)+len(binary_chunks))
               + struct.pack('<II',len(encoded),0x4e4f534a)+encoded+binary_chunks)
    path.write_bytes(updated)
    sha = hashlib.sha256(updated).hexdigest()
    row['runtime'] = {'bytes':len(updated),'sha256':sha}
    key = 'integration_mesh_space_repair' if canonical_space else 'integration_skin_bounds_repair' if skin_bounds else 'integration_name_repair'
    row[key] = ('Canonicalize static skinned-mesh space for correct Godot bounds; skin joint transforms, binary geometry and animation unchanged.' if canonical_space else
                'Cancel redundant mesh-space root scale for correct Godot raw bounds; joint poses, binary geometry and animation unchanged.'
                if skin_bounds else 'Combined body is not an equipment-only node; binary geometry/animation unchanged.')
    target = PROJECT/row['destination_resource'].removeprefix('res://')
    shutil.copy2(path, target)
    for overlay in preparation['overlays']:
        if overlay['path'] == row['destination_resource']:
            overlay.update(bytes=len(updated),sha256=sha)
    changed.append({'id':row['id'],'bytes':len(updated),'sha256':sha})
assert changed, 'No unresolved combined-body names; do not repeat normalization'
for relative in ('data/design_pack_assets.json','runtime_asset_manifest.json'):
    target = PROJECT/relative
    data = json.loads(target.read_text())
    for repair in changed:
        row = next(r for r in ledger['assets'] if r['id']==repair['id'])
        if relative.startswith('data/'):
            data['assets'][row['id']].update(bytes=repair['bytes'],sha256=repair['sha256'])
        else:
            for role in data['roles'].values():
                for item in role.get('runtime_files',[]):
                    if item['path']==row['destination_resource']:
                        item.update(bytes=repair['bytes'],sha256=repair['sha256'])
    target.write_text(json.dumps(data,indent=2)+'\n')
unique = {t['source_path']:t['bytes'] for r in ledger['assets'] for t in r['textures']}
cost = ledger['shared_resource_costs']
cost['compiled_glbs_plus_unique_images_bytes'] = sum(r['runtime']['bytes'] for r in ledger['assets'])+sum(unique.values())
cost['saved_bytes'] = cost['embedded_baseline_bytes']-cost['compiled_glbs_plus_unique_images_bytes']
ledger_path.write_text(json.dumps(ledger,indent=2)+'\n')
shutil.copy2(ledger_path,frozen)
preparation['ledger_sha256']=hashlib.sha256(frozen.read_bytes()).hexdigest()
preparation['canonical_mesh_space_repairs' if canonical_space else 'skin_bounds_repairs' if skin_bounds else 'assembly_name_repairs']=changed
preparation_path.write_text(json.dumps(preparation,indent=2)+'\n')
gate_path=ROOT/'quality_gate.json'
gate=json.loads(gate_path.read_text())
for repair in changed:
    gate[repair['id']]['active_candidate']['runtime_sha256']=repair['sha256']
gate_path.write_text(json.dumps(gate,indent=2)+'\n')
print(json.dumps(changed,indent=2))
