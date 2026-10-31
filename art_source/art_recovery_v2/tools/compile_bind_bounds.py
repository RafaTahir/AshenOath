"""Compile skinned bind-pose bounds for private prepared actors; no game run."""
import hashlib
import json
import shutil
import struct
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
PROJECT=Path('D:/Temp/AshenOath/stylized_review/project')

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

def bind_bounds(path):
    raw=path.read_bytes()
    length=struct.unpack_from('<I',raw,12)[0]
    data=json.loads(raw[20:20+length])
    binary=raw[28+length:]
    nodes=data['nodes']
    parents={child:index for index,node in enumerate(nodes) for child in node.get('children',[])}
    worlds={}
    def world(index):
        if index not in worlds:
            local=node_matrix(nodes[index])
            worlds[index]=world(parents[index]) @ local if index in parents else local
        return worlds[index]
    def accessor(index):
        a=data['accessors'][index]
        assert 'sparse' not in a
        view=data['bufferViews'][a['bufferView']]
        dtype=np.dtype({5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']])
        count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        value=np.ndarray((a['count'],count),dtype=dtype,buffer=binary,
                         offset=view.get('byteOffset',0)+a.get('byteOffset',0),
                         strides=(view.get('byteStride',count*dtype.itemsize),dtype.itemsize)).copy()
        if a.get('normalized'):
            value=value.astype(float)/np.iinfo(dtype).max
            if dtype.kind=='i': value=np.maximum(value,-1)
        return value
    positions=[]
    for index,node in enumerate(nodes):
        if 'mesh' not in node:
            continue
        transforms=None
        if 'skin' in node:
            skin=data['skins'][node['skin']]
            inverse=accessor(skin['inverseBindMatrices']).reshape((-1,4,4)).transpose((0,2,1))
            transforms=np.stack([world(joint) @ matrix for joint,matrix in zip(skin['joints'],inverse)])
        for primitive in data['meshes'][node['mesh']]['primitives']:
            attributes=primitive['attributes']
            vertices=accessor(attributes['POSITION'])
            homogeneous=np.column_stack((vertices,np.ones(len(vertices))))
            if transforms is None:
                posed=homogeneous @ world(index).T
            else:
                posed=np.zeros_like(homogeneous)
                total=np.zeros(len(vertices))
                for stream in (0,1):
                    if 'JOINTS_'+str(stream) not in attributes:
                        continue
                    joints=accessor(attributes['JOINTS_'+str(stream)]).astype(int)
                    weights=accessor(attributes['WEIGHTS_'+str(stream)])
                    for influence in range(joints.shape[1]):
                        posed+=np.einsum('nij,nj->ni',transforms[joints[:,influence]],homogeneous)*weights[:,influence,None]
                    total+=weights.sum(axis=1)
                if np.any(total<0.99) or np.any(total>1.01):
                    raise ValueError('Incomplete normalized skin weights: '+str(path))
                posed/=total[:,None]
            positions.append(posed[:,:3])
    points=np.concatenate(positions)
    assert np.isfinite(points).all()
    low,high=points.min(axis=0),points.max(axis=0)
    assert np.all(high-low>0.01), path
    return {'position':low.tolist(),'size':(high-low).tolist(),
            'space':'exported world bind pose; skin-aware, not raw mesh AABB',
            'asset_sha256':hashlib.sha256(raw).hexdigest()}

ledger_path=ROOT/'stylized_roster.json'
ledger=json.loads(ledger_path.read_text())
manifest_path=PROJECT/'data/design_pack_assets.json'
manifest=json.loads(manifest_path.read_text())
runtime_path=PROJECT/'runtime_asset_manifest.json'
runtime=json.loads(runtime_path.read_text())
preparation_path=PROJECT/'private_review_preparation.json'
preparation=json.loads(preparation_path.read_text())
assert preparation['publication_authorized'] is False
for row in ledger['assets']:
    bounds=bind_bounds(Path(row['runtime_path']))
    if row['id'] in ('C03','C04','C09','C11'):
        bounds['garment_arm_clearance_m']=0.10
    assert bounds['asset_sha256']==row['runtime']['sha256']
    row['authored_bind_bounds']=bounds
    preparation['authoring_sources'][row['id']]=row['source_path']
    manifest['assets'][row['id']]['authored_bind_bounds']=bounds
    manifest['assets'][row['id']].update(bytes=row['runtime']['bytes'],sha256=row['runtime']['sha256'],candidate_runtime_path=row['runtime_path'],candidate_source_path=row['source_path'])
    entries=[dict(path=row['destination_resource'],source_path=row['runtime_path'],**row['runtime'])]
    entries.extend(dict(path=t['runtime_path'],source_path=t['source_path'],bytes=t['bytes'],sha256=t['sha256']) for t in row.get('textures',[]))
    for entry in entries:
        target=PROJECT/entry['path'].removeprefix('res://')
        if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest()!=entry['sha256']:
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(entry['source_path'],target)
        overlay=next((o for o in preparation['overlays'] if o['path']==entry['path']),None)
        if overlay is None:
            overlay={'id':row['id'],'asset_ids':[row['id']],'path':entry['path']}
            preparation['overlays'].append(overlay)
        overlay.update(source=entry['source_path'],bytes=entry['bytes'],sha256=entry['sha256'])
        if row['id'] not in overlay['asset_ids']:
            overlay['asset_ids'].append(row['id'])
    for role in runtime['roles'].values():
        if role.get('design_id')==row['id']:
            role['runtime_files']=[{key:e[key] for key in ('path','bytes','sha256')} for e in entries]
    print(row['id'],[round(v,3) for v in bounds['size']],flush=True)
ledger_path.write_text(json.dumps(ledger,indent=2)+'\n')
manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
runtime_path.write_text(json.dumps(runtime,indent=2)+'\n')
frozen=PROJECT/'private_candidate_ledger.json'
shutil.copy2(ledger_path,frozen)
preparation['ledger_sha256']=hashlib.sha256(frozen.read_bytes()).hexdigest()
preparation['bind_bounds_compilation']='CPU evaluation of glTF joint globals, inverse binds and normalized vertex weights; not gameplay/performance evidence'
preparation_path.write_text(json.dumps(preparation,indent=2)+'\n')
