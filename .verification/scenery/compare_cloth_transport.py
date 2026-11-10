from pathlib import Path
import json,struct,hashlib
from collections import Counter
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'art_source/art_recovery_v2'
folder=ART/'models/living_assets_stage3_20261107/scenery/checkpoint_cloth'
receipt=json.loads((folder/'authoring.json').read_text())
def read(path):
    data=path.read_bytes();offset=12;doc=None;binary=None
    while offset<len(data):
        size,kind=struct.unpack_from('<II',data,offset);offset+=8;chunk=data[offset:offset+size];offset+=size
        if kind==0x4e4f534a:doc=json.loads(chunk)
        elif kind==0x004e4942:binary=chunk
    return doc,binary
def accessor(doc,binary,index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    codes={5120:'b',5121:'B',5122:'h',5123:'H',5125:'I',5126:'f'}
    counts={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
    form='<'+codes[a['componentType']]*counts[a['type']];size=struct.calcsize(form);start=v.get('byteOffset',0)+a.get('byteOffset',0)
    out=np.array([struct.unpack_from(form,binary,start+i*v.get('byteStride',size)) for i in range(a['count'])],dtype=float)
    if a.get('normalized') and a['componentType']!=5126:
        limits={5120:127,5121:255,5122:32767,5123:65535,5125:4294967295};out=out/limits[a['componentType']]
        if a['componentType'] in (5120,5122):out=np.maximum(out,-1)
    return out
def matrices(doc):
    parents={child:i for i,n in enumerate(doc['nodes']) for child in n.get('children',[])};cache={}
    def world(i):
        if i in cache:return cache[i]
        n=doc['nodes'][i]
        if 'matrix' in n:m=np.array(n['matrix']).reshape((4,4),order='F')
        else:
            x,y,z,w=n.get('rotation',[0,0,0,1]);m=np.eye(4)
            m[:3,:3]=np.array([[1-2*y*y-2*z*z,2*x*y-2*z*w,2*x*z+2*y*w],[2*x*y+2*z*w,1-2*x*x-2*z*z,2*y*z-2*x*w],[2*x*z-2*y*w,2*y*z+2*x*w,1-2*x*x-2*y*y]])@np.diag(n.get('scale',[1,1,1]))
            m[:3,3]=n.get('translation',[0,0,0])
        cache[i]=world(parents[i])@m if i in parents else m
        return cache[i]
    return world
def mesh_rows(path):
    doc,binary=read(path);world=matrices(doc);rows={}
    for i,n in enumerate(doc['nodes']):
        if 'mesh' not in n:continue
        mesh=doc['meshes'][n['mesh']];assert len(mesh['primitives'])==1
        p=mesh['primitives'][0];a=p['attributes'];m=world(i)
        pos=accessor(doc,binary,a['POSITION']);pos=(m[:3,:3]@pos.T).T+m[:3,3]
        normal=accessor(doc,binary,a['NORMAL']);normal=(np.linalg.inv(m[:3,:3]).T@normal.T).T;normal/=np.linalg.norm(normal,axis=1)[:,None]
        color=accessor(doc,binary,a['COLOR_0'])
        if color.shape[1]==3:color=np.column_stack([color,np.ones(len(color))])
        rows[n['name'].removesuffix('_Geometry')]={'position':pos,'normal':normal,'uv':accessor(doc,binary,a['TEXCOORD_0']),'color':color,'indices':accessor(doc,binary,p['indices']).reshape(-1).astype(int),'matrix':m,'material':doc['materials'][p['material']]}
    return rows
a_path=ART/receipt['retained_input'];b_path=ART/receipt['carrier'];a=mesh_rows(a_path);b=mesh_rows(b_path)
report={'retained_sha256':hashlib.sha256(a_path.read_bytes()).hexdigest(),'authored_sha256':hashlib.sha256(b_path.read_bytes()).hexdigest(),'scope':'Independent pure GLB diagnostic; no Blender/native gate or visual acceptance','meshes':{}}
for name,first in a.items():
    second=b[name];mapping=[]
    for index,point in enumerate(first['position']):
        dist=np.linalg.norm(second['position']-point,axis=1)+np.linalg.norm(second['normal']-first['normal'][index],axis=1)+np.linalg.norm(second['uv']-first['uv'][index],axis=1)
        target=int(np.argmin(dist));assert dist[target]<0.001,(name,index,dist[target]);mapping.append(target)
    mapping=np.array(mapping);errors={k:float(np.max(np.abs(first[k]-second[k][mapping]))) for k in ['position','normal','uv','color']}
    # Source and authored materials are printed verbatim for semantic review.
    def triangles(indices):
        rows=[]
        for j in range(0,len(indices),3):
            x=tuple(int(k) for k in indices[j:j+3]);rows.append(min(x,x[1:]+x[:1],x[2:]+x[:2]))
        return Counter(rows)
    topology=triangles(mapping[first['indices']])==triangles(second['indices'])
    report['meshes'][name]={'source_vertices':len(first['position']),'authored_vertices':len(second['position']),'mapped_vertex_bijection':len(set(mapping))==len(mapping),'wound_triangle_multiplicity_equal':topology,'max_component_error':errors,'first_source_color':first['color'][0].tolist(),'first_authored_color':second['color'][mapping[0]].tolist(),'source_material':first['material'],'authored_material':second['material'],'source_world_matrix':first['matrix'].tolist(),'authored_world_matrix':second['matrix'].tolist()}
out=ROOT/'.verification/scenery/cloth_transport_independent_r1.json';out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
