"""Integrate inspected asset finishes without replacing history or approval.

Image extraction is lossless. Skin-aware bounds are evaluated from exported
joint matrices and weights, so Blender's raw mesh AABBs cannot resize actors.
Run only after all per-asset candidate records exist.
"""
import argparse, hashlib, io, json, shutil, struct
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT.parents[1]/'outputs/AshenOathTheRoadBetweenCrowns'
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def write(path,value):path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
def identity(path):return {'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
def unpack(path):
    raw=path.read_bytes();length,kind=struct.unpack_from('<II',raw,12)
    assert raw[:4]==b'glTF' and kind==0x4e4f534a
    return json.loads(raw[20:20+length]),bytearray(raw[28+length:])
def pack(path,data,binary):
    data['buffers']=[{'byteLength':len(binary)}]
    encoded=json.dumps(data,separators=(',',':')).encode();encoded+=b' '*(-len(encoded)%4)
    binary+=b'\0'*(-len(binary)%4)
    path.write_bytes(struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)
def matrix(node):
    if 'matrix' in node:return np.array(node['matrix']).reshape(4,4).T
    x,y,z,w=node.get('rotation',[0,0,0,1]);m=np.eye(4)
    m[:3,:3]=np.array([[1-2*y*y-2*z*z,2*x*y-2*z*w,2*x*z+2*y*w],[2*x*y+2*z*w,1-2*x*x-2*z*z,2*y*z-2*x*w],[2*x*z-2*y*w,2*y*z+2*x*w,1-2*x*x-2*y*y]])@np.diag(node.get('scale',[1,1,1]))
    m[:3,3]=node.get('translation',[0,0,0]);return m
def node_worlds(data):
    parents={c:i for i,n in enumerate(data['nodes']) for c in n.get('children',[])};worlds={}
    def world(i):
        if i not in worlds:worlds[i]=(world(parents[i]) if i in parents else np.eye(4))@matrix(data['nodes'][i])
        return worlds[i]
    for i in range(len(data['nodes'])):world(i)
    return parents,worlds
def accessor(data,binary,index):
    a=data['accessors'][index];v=data['bufferViews'][a['bufferView']];assert 'sparse' not in a
    dtype=np.dtype({5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]);width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    value=np.ndarray((a['count'],width),dtype=dtype,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',width*dtype.itemsize),dtype.itemsize)).copy()
    if a.get('normalized'):value=np.maximum(value.astype(float)/np.iinfo(dtype).max,-1)
    return value
def bounds(data,binary):
    _,worlds=node_worlds(data);points=[]
    for i,node in enumerate(data['nodes']):
        if 'mesh' not in node:continue
        transforms=None
        if 'skin' in node:
            skin=data['skins'][node['skin']];inverse=accessor(data,binary,skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
            transforms=np.stack([worlds[j]@m for j,m in zip(skin['joints'],inverse)])
        for primitive in data['meshes'][node['mesh']]['primitives']:
            a=primitive['attributes'];p=accessor(data,binary,a['POSITION']);h=np.column_stack((p,np.ones(len(p))))
            if transforms is None:posed=h@worlds[i].T
            else:
                posed=np.zeros_like(h);total=np.zeros(len(p))
                for stream in (0,1):
                    if 'JOINTS_'+str(stream) not in a:continue
                    joints=accessor(data,binary,a['JOINTS_'+str(stream)]).astype(int);weights=accessor(data,binary,a['WEIGHTS_'+str(stream)])
                    for k in range(joints.shape[1]):posed+=np.einsum('nij,nj->ni',transforms[joints[:,k]],h)*weights[:,k,None]
                    total+=weights.sum(axis=1)
                assert np.all((total>.99)&(total<1.01)),'Invalid skin weights'
                posed/=total[:,None]
            points.append(posed[:,:3])
    p=np.concatenate(points);assert np.isfinite(p).all();lo,hi=p.min(axis=0),p.max(axis=0)
    return {'position':lo.tolist(),'size':(hi-lo).tolist(),'space':'exported world bind pose; evaluated joint globals, inverse binds and normalized weights'}
def externalize(source,target):
    from PIL import Image
    data,binary=unpack(source);parents,worlds=node_worlds(data)
    # Godot skinning consumes joint space, while its raw AABB includes mesh
    # transforms. Keep static mesh world space canonical, as in the prior cast.
    for i,n in enumerate(data['nodes']):
        if 'mesh' not in n or 'skin' not in n:continue
        assert not any(c['target']['node']==i for a in data.get('animations',[]) for c in a['channels']), 'Animated mesh transform needs manual review'
        for k in ['translation','rotation','scale','matrix']:n.pop(k,None)
        n['matrix']=(np.linalg.inv(worlds[parents[i]]) if i in parents else np.eye(4)).T.reshape(-1).tolist()
    removed=set();textures=[];usage={i:set() for i in range(len(data.get('images',[])))}
    def used(slot,kind):
        if slot and 'index' in slot:usage[data['textures'][slot['index']]['source']].add(kind)
    for m in data.get('materials',[]):
        pbr=m.get('pbrMetallicRoughness',{});assert 'baseColorTexture' in pbr, 'Every authored surface needs an albedo atlas: '+m.get('name','')
        used(pbr.get('baseColorTexture'),'color');used(m.get('emissiveTexture'),'color');used(m.get('normalTexture'),'normal');used(pbr.get('metallicRoughnessTexture'),'linear');used(m.get('occlusionTexture'),'linear')
    for index,img in enumerate(data.get('images',[])):
        vi=img.pop('bufferView');view=data['bufferViews'][vi];start=view.get('byteOffset',0);payload=bytes(binary[start:start+view['byteLength']]);mime=img.pop('mimeType')
        ext={'image/png':'.png','image/jpeg':'.jpg'}[mime];sha=hashlib.sha256(payload).hexdigest();name=('_'.join(sorted(usage[index])) or 'linear')+'_'+sha+ext
        dest=target.parent/'textures'/name;dest.parent.mkdir(parents=True,exist_ok=True)
        if dest.exists():assert dest.read_bytes()==payload
        else:dest.write_bytes(payload)
        img['uri']='textures/'+name;removed.add(vi)
        resource='res://assets_external/design_pack_v1/'+target.parent.name+'/textures/'+name
        with Image.open(io.BytesIO(payload)) as image:dimensions=[image.width,image.height]
        textures.append({'source_path':str(dest),'runtime_path':resource,'bytes':len(payload),'sha256':sha,'width':dimensions[0],'height':dimensions[1],'lossless_shared_image':True})
    remap={};views=[];output=bytearray()
    for i,v in enumerate(data['bufferViews']):
        if i in removed:continue
        output+=b'\0'*(-len(output)%4);remap[i]=len(views);copy=dict(v,byteOffset=len(output),buffer=0);start=v.get('byteOffset',0)
        output.extend(binary[start:start+v['byteLength']]);views.append(copy)
    data['bufferViews']=views
    def rewrite(node):
        if isinstance(node,dict):
            for k,v in node.items():
                if k=='bufferView':node[k]=remap[v]
                else:rewrite(v)
        elif isinstance(node,list):
            for v in node:rewrite(v)
    rewrite(data)
    profile=bounds(data,output);target.parent.mkdir(parents=True,exist_ok=True);pack(target,data,output)
    profile['asset_sha256']=identity(target)['sha256']
    return data,profile,textures

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--ids',nargs='*');args=parser.parse_args()
    ledger_path=ROOT/'stylized_roster.json';ledger=read(ledger_path);gate_path=ROOT/'quality_gate.json';gate=read(gate_path)
    design_path=GAME/'data/design_pack_assets.json';design=read(design_path);runtime_path=GAME/'runtime_asset_manifest.json';runtime=read(runtime_path)
    records={}
    candidate_paths=list((ROOT/'evidence/refinement_20261101').rglob('candidate.json'))+list((GAME/'art_review/refinement_20261101').rglob('candidate.json'))
    for path in sorted(candidate_paths,key=lambda p:p.stat().st_mtime):
        candidate=read(path)
        if candidate.get('id') in {r['id'] for r in ledger['assets']}:records[candidate['id']]=(path,candidate)
    selected=set(args.ids or [r['id'] for r in ledger['assets']]);assert selected<=records.keys(), 'Missing candidates: '+str(selected-records.keys())
    backup=ROOT.parents[1]/'.release-gate/asset-refinement-20261101/before-integration';backup.mkdir(parents=True,exist_ok=True)
    for p in [ledger_path,gate_path,design_path,runtime_path]:
        target=backup/p.name
        if not target.exists():shutil.copy2(p,target)
    integrated=[]
    for row in ledger['assets']:
        key=row['id']
        if key not in selected:continue
        record_path,candidate=records[key];source=Path(candidate['source_path']);embedded=Path(candidate['runtime_path'])
        refinement=row.get('refinement_20261101',{})
        assert source.is_file() and embedded.is_file()
        baseline_path=Path(row.get('refinement_history',[{}])[0].get('runtime_path',row['runtime_path']))
        input_sha=candidate.get('input_sha256',candidate.get('baseline_sha256',candidate.get('before',{}).get('sha256')))
        if input_sha and input_sha!=identity(baseline_path)['sha256']:
            assert candidate.get('original_input_sha256')==identity(baseline_path)['sha256'], key+' lacks an original baseline identity'
            parent=read(Path(candidate['parent_candidate_record']))
            assert identity(Path(parent['runtime_path']))['sha256']==input_sha, key+' parent candidate changed'
            assert parent['runtime_path']==candidate['input_path'], key+' parent path mismatch'
        before_doc,before_binary=unpack(baseline_path);new_doc,new_binary=unpack(embedded)
        assert {a.get('name') for a in before_doc.get('animations',[])}=={a.get('name') for a in new_doc.get('animations',[])}, key+' lost clips'
        def bones(d):return {d['nodes'][j].get('name') for s in d.get('skins',[]) for j in s['joints']}
        assert bones(before_doc)==bones(new_doc), key+' changed bone names'
        def durations(d,b):
            return {a.get('name'):max(float(accessor(d,b,s['input']).max()) for s in a['samplers']) for a in d.get('animations',[])}
        previous_lengths=durations(before_doc,before_binary);new_lengths=durations(new_doc,new_binary)
        for clip,length in previous_lengths.items():
            assert abs(length-new_lengths[clip])<.002, f'{key}/{clip} retimed {length} -> {new_lengths[clip]}'
        if refinement.get('embedded_runtime_sha256')==identity(embedded)['sha256'] and row.get('source',{}).get('sha256')==identity(source)['sha256']:
            print('ALREADY_INTEGRATED',key,flush=True)
            continue
        category='humans' if key[0] in 'CP' else 'creatures'
        target=GAME/'art_review/refinement_20261101/runtime_shared'/category/Path(row['destination_resource']).name
        doc,profile,textures=externalize(embedded,target)
        if key in ['C03','C04','C09','C11']:profile['garment_arm_clearance_m']=.10
        old={k:row.get(k) for k in ['source_path','runtime_path','source','runtime','authored_bind_bounds']}
        row.setdefault('refinement_history',[]).append(old)
        row.update(source_path=str(source),source=identity(source),runtime_path=str(target),runtime=identity(target),textures=textures,
          authored_bind_bounds=profile,status='refined_live_candidate_user_review_pending',user_accepted=False,integrated=True,
          refinement_20261101={'record':str(record_path),'embedded_runtime_sha256':identity(embedded)['sha256'],'changes':candidate.get('changes',candidate.get('improvements',[])),'user_accepted':False})
        row['metrics'].update(triangles=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'] if 'indices' in p),meshes=len(doc['meshes']),materials=len(doc['materials']),joints=sum(len(s['joints']) for s in doc['skins']),embedded_animations=[a.get('name') for a in doc.get('animations',[])],embedded_images=[],external_image_resources=textures,decoded_rgba8_image_bytes_no_mips=sum(t['width']*t['height']*4 for t in textures))
        entries=[dict(path=row['destination_resource'],source_path=str(target),**identity(target))]
        entries.extend(dict(path=t['runtime_path'],source_path=t['source_path'],bytes=t['bytes'],sha256=t['sha256']) for t in textures)
        for entry in entries:
            dest=GAME/entry['path'].removeprefix('res://');preserved=backup/'runtime'/dest.relative_to(GAME)
            if dest.exists() and not preserved.exists():preserved.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(dest,preserved)
            dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(entry['source_path'],dest)
        design['assets'][key].update(bytes=row['runtime']['bytes'],sha256=row['runtime']['sha256'],authored_bind_bounds=profile,candidate_source_path=str(source),candidate_runtime_path=str(target),refinement_record=str(record_path))
        for role in runtime['roles'].values():
            if role.get('design_id')==key:role['runtime_files']=[{k:e[k] for k in ['path','bytes','sha256']} for e in entries]
        gate.setdefault(key,{}).update(status='refined_live_candidate_user_review_pending',user_accepted=False,
           active_candidate={'source_path':str(source),'runtime_path':str(target),'runtime_sha256':row['runtime']['sha256'],'record':'stylized_roster.json','inspection_scope':'2026-11-01 Blender finish; current native engine captures recorded separately'})
        integrated.append({'id':key,'runtime':row['runtime'],'bounds':profile})
        print('INTEGRATED',key,row['metrics']['triangles'],flush=True)
    ledger['status']='refined_live_candidates_pending_user_review';ledger['user_accepted_count']=0
    gate['current_slice']='asset_refinement_20261101'
    for path,value in [(ledger_path,ledger),(gate_path,gate),(design_path,design),(runtime_path,runtime)]:write(path,value)
    integrated=[{'id':r['id'],'runtime':r['runtime'],'bounds':r['authored_bind_bounds']} for r in ledger['assets'] if r.get('refinement_20261101')]
    write(ROOT/'evidence/refinement_20261101/integration.json',{'assets':integrated,'scope':'authored derivative integration; not gameplay/performance approval','user_accepted':False})

if __name__=='__main__':main()
