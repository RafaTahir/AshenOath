"""Losslessly externalize identical GLB images into shared private resources.

No pixels, geometry, skins, materials or animations are reauthored here.
Original embedded exports stay intact. Only binary layout/image URIs change.
"""
import hashlib
import json
import struct
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT.parents[1]/'outputs/AshenOathTheRoadBetweenCrowns'
ledger_path=ROOT/'stylized_roster.json'
ledger=json.loads(ledger_path.read_text())
if ledger.get('exported_count')!=33 or ledger.get('pending_cleanup'):
    raise ValueError('Finish individual exports and declared cleanups before final shared compilation')
if any(r['id']!='C01' and r['id'][0] in ('C','P') and not r.get('rig_fitted',False) for r in ledger['assets']):
    raise ValueError('Finish the lower-garment/equipment fitting pass before final shared compilation')
output=GAME/'art_review/stylized/runtime_shared'
selected=set(sys.argv[1:])
if selected and not selected.issubset({r['id'] for r in ledger['assets']}):
    raise ValueError('Unknown partial compilation IDs')
output.mkdir(parents=True,exist_ok=bool(selected))
source_bytes=0
unique_images={}
report=[]
for row in ledger['assets']:
    if selected and row['id'] not in selected:
        continue
    source=Path(row['runtime_path'])
    raw=source.read_bytes()
    source_bytes+=len(raw)
    json_size,kind=struct.unpack_from('<II',raw,12)
    if kind!=0x4e4f534a:
        raise ValueError('Missing GLB JSON: '+str(source))
    document=json.loads(raw[20:20+json_size])
    binary=raw[28+json_size:]
    if len(document['buffers'])!=1 or document['buffers'][0].get('uri'):
        raise ValueError('Require one embedded source buffer')
    destination=row['destination_resource']
    relative=Path(destination.removeprefix('res://assets_external/design_pack_v1/'))
    if relative.parts[0] not in ('humans','creatures') or len(relative.parts)!=2:
        raise ValueError('Unexpected runtime resource location: '+destination)
    target=output/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    removed=set()
    textures=[]
    usage={i:set() for i in range(len(document.get('images',[])))}
    def used(slot,kind):
        if slot and 'index' in slot:
            index=document['textures'][slot['index']]['source']
            usage[index].add(kind)
    for material in document.get('materials',[]):
        pbr=material.get('pbrMetallicRoughness',{})
        used(pbr.get('baseColorTexture'),'color')
        used(material.get('emissiveTexture'),'color')
        used(material.get('normalTexture'),'normal')
        used(pbr.get('metallicRoughnessTexture'),'linear')
        used(material.get('occlusionTexture'),'linear')
    for image_index,image in enumerate(document.get('images',[])):
        if 'bufferView' not in image:
            raise ValueError('Expected embedded image in source export')
        index=image.pop('bufferView')
        view=document['bufferViews'][index]
        offset=view.get('byteOffset',0)
        payload=binary[offset:offset+view['byteLength']]
        mime=image.pop('mimeType')
        extension={ 'image/png':'.png','image/jpeg':'.jpg' }.get(mime)
        if extension is None:
            raise ValueError('Unsupported image format: '+mime)
        digest=hashlib.sha256(payload).hexdigest()
        semantic='_'.join(sorted(usage[image_index])) or 'linear'
        name=semantic+'_'+digest+extension
        texture=target.parent/'textures'/name
        texture.parent.mkdir(exist_ok=True)
        if texture.exists():
            if texture.read_bytes()!=payload:
                raise ValueError('Shared texture identity conflict')
        else:
            texture.write_bytes(payload)
        image['uri']='textures/'+name
        removed.add(index)
        resource='res://assets_external/design_pack_v1/'+relative.parent.as_posix()+'/textures/'+name
        record={'source_path':str(texture),'runtime_path':resource,'sha256':digest,
                'bytes':len(payload),'lossless_shared_image':True}
        if record not in textures:
            textures.append(record)
        unique_images[str(texture)]=len(payload)
    remap={}
    views=[]
    result=bytearray()
    for index,view in enumerate(document['bufferViews']):
        if index in removed:
            continue
        if view.get('buffer',0)!=0:
            raise ValueError('Unexpected buffer index')
        while len(result)%4:
            result.append(0)
        offset=view.get('byteOffset',0)
        payload=binary[offset:offset+view['byteLength']]
        copy=dict(view,buffer=0,byteOffset=len(result))
        result.extend(payload)
        if result[copy['byteOffset']:copy['byteOffset']+copy['byteLength']]!=payload:
            raise ValueError('Non-image payload changed')
        remap[index]=len(views)
        views.append(copy)
    document['bufferViews']=views
    document['buffers']=[{'byteLength':len(result)}]
    def rewrite(node):
        if isinstance(node,dict):
            for key,value in node.items():
                if key=='bufferView':
                    node[key]=remap[value]
                else:
                    rewrite(value)
        elif isinstance(node,list):
            for child in node:
                rewrite(child)
    rewrite(document)
    encoded=json.dumps(document,separators=(',',':')).encode()
    encoded+=b' '*((-len(encoded))%4)
    result+=b'\0'*((-len(result))%4)
    glb=struct.pack('<4sII',b'glTF',2,12+8+len(encoded)+8+len(result))
    glb+=struct.pack('<II',len(encoded),0x4e4f534a)+encoded
    glb+=struct.pack('<II',len(result),0x004e4942)+result
    target.write_bytes(glb)
    row['embedded_runtime_baseline']={'path':str(source),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
    row['runtime_path']=str(target)
    row['runtime']={'bytes':len(glb),'sha256':hashlib.sha256(glb).hexdigest()}
    row['textures']=textures
    row['metrics']['external_image_resources']=row['metrics'].pop('embedded_images',[])
    row['metrics']['embedded_images']=[]
    row['runtime_compilation']='Lossless shared external images; non-image binary payloads preserved byte-for-byte'
    row['integrated']=False
    report.append({'id':row['id'],'embedded_bytes':len(raw),'shared_glb_bytes':len(glb),
                   'referenced_texture_bytes':sum(t['bytes'] for t in textures)})
unique_images={t['runtime_path']:t['bytes'] for r in ledger['assets'] for t in r.get('textures',[])}
source_bytes=sum(r['embedded_runtime_baseline']['bytes'] for r in ledger['assets'])
total=sum(r['runtime']['bytes'] for r in ledger['assets'])+sum(unique_images.values())
ledger['shared_resource_costs']={'embedded_baseline_bytes':source_bytes,'compiled_glbs_plus_unique_images_bytes':total,
                                'saved_bytes':source_bytes-total,'unique_images':len(unique_images),
                                'not_process_memory_or_performance_measurement':True}
temporary=ledger_path.with_suffix('.json.tmp')
temporary.write_text(json.dumps(ledger,indent=2)+'\n')
temporary.replace(ledger_path)
(output/('shared_compilation_patch_'+'_'.join(sorted(selected))+'.json' if selected else 'shared_compilation.json')).write_text(json.dumps({'scope':'private lossless resource compilation',
    'rows':report,'costs':ledger['shared_resource_costs'],'user_accepted':False},indent=2)+'\n')
gate_path=ROOT/'quality_gate.json'
gate=json.loads(gate_path.read_text())
for row in ledger['assets']:
    review=gate.setdefault(row['id'],{})
    review['active_candidate']={'source_path':row['source_path'],'runtime_path':row['runtime_path'],
                              'runtime_sha256':row['runtime']['sha256'],'record':'stylized_roster.json',
                              'inspection_scope':'source views; native art inspection/compilation recorded separately'}
gate['current_slice']='combined_private_review'
gate['active_roster_summary'].update(exported=33,required=33,user_accepted=0,production_published=False,
                                    next_asset=None,pending_shared_cleanup=[],pending_rig_fit=[])
temporary=gate_path.with_suffix('.json.tmp')
temporary.write_text(json.dumps(gate,indent=2)+'\n')
temporary.replace(gate_path)
print(json.dumps(ledger['shared_resource_costs'],indent=2))
