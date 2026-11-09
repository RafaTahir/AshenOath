"""Read actual exported triangle winding for closed supported prop surfaces."""
from collections import Counter
import json
import hashlib
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[1]


def inspect(path):
    data=path.read_bytes();size=struct.unpack_from('<I',data,12)[0]
    document=json.loads(data[20:20+size]);binary=data[28+size:]
    def values(index):
        a=document['accessors'][index];v=document['bufferViews'][a['bufferView']]
        width={'SCALAR':1,'VEC3':3}[a['type']]
        kind={5121:'B',5123:'H',5125:'I',5126:'f'}[a['componentType']]
        form='<'+kind*width;stride=v.get('byteStride',struct.calcsize(form))
        start=v.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from(form,binary,start+i*stride) for i in range(a['count'])]
    rows=[]
    for mesh in document['meshes']:
        vertices=[];indices=[];lookup={}
        for primitive in mesh['primitives']:
            mapping={}
            for i,point in enumerate(values(primitive['attributes']['POSITION'])):
                key=tuple(round(x,6) for x in point)
                if key not in lookup:lookup[key]=len(vertices);vertices.append(point)
                mapping[i]=lookup[key]
            raw=[mapping[row[0]] for row in values(primitive['indices'])]
            indices.extend(raw[i:i+3] for i in range(0,len(raw),3))
        edges=Counter(tuple(sorted((face[i],face[(i+1)%3]))) for face in indices for i in range(3))
        volume=0
        for face in indices:
            a,b,c=[vertices[i] for i in face]
            volume+=(a[0]*(b[1]*c[2]-b[2]*c[1])+a[1]*(b[2]*c[0]-b[0]*c[2])+a[2]*(b[0]*c[1]-b[1]*c[0]))/6
        rows.append({'mesh':mesh.get('name',''),'closed_edges':all(n==2 for n in edges.values()),
                     'signed_volume':volume,'outward_closed_winding':volume>0})
    return {'carrier_sha256':hashlib.sha256(data).hexdigest(),'meshes':rows}


if __name__=='__main__':
    report={path.stem:inspect(path) for path in (ROOT/'models/living_cast_stage2_20261107/props').glob('station_*.glb')}
    destination=ROOT/'evidence/living_cast_stage2_20261107/prop_winding.json'
    destination.write_text(json.dumps(report,indent=2)+'\n')
    for name,receipt in report.items():
        for row in receipt['meshes']:
            if row['closed_edges'] and not row['outward_closed_winding']:print('INWARD_CLOSED_PROP',name,row['mesh'],row['signed_volume'])
