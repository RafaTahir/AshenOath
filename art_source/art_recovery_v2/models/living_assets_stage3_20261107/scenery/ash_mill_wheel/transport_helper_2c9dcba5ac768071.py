"""Lossless retained scenery attributes around Blender's editable pivot workflow.

This does not repair missing geometry or relax native acceptance. The exported
corner multiset, material and frame must already match the retained input before
NORMAL may reference the explicitly exported full precision source attribute.
"""
from __future__ import annotations

from collections import defaultdict
import hashlib
import itertools
import json
import math
from pathlib import Path
import struct

NORMAL_ATTRIBUTE = '_AO_RETAINED_NORMAL'
TOLERANCES = {'positions':1e-6, 'normals':1e-7, 'uvs':1e-6, 'colors':1e-7}
FRAME_TOLERANCE = 1e-6
_TYPES = {'SCALAR':1, 'VEC2':2, 'VEC3':3, 'VEC4':4}
_COMPONENTS = {5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}

def _sha(data): return hashlib.sha256(data).hexdigest()
def _fail(message): raise ValueError(message)
def _integer(value): return isinstance(value,int) and not isinstance(value,bool) and value>=0
def _finite(values): return all(isinstance(v,(int,float)) and not isinstance(v,bool) and math.isfinite(v) for v in values)

def _read(path):
    raw=Path(path).read_bytes()
    if len(raw)<20 or struct.unpack_from('<III',raw,0)!=(0x46546c67,2,len(raw)):
        _fail('Invalid GLB header/length')
    offset=12;document=None;binary=None;chunks=0
    while offset<len(raw):
        if offset+8>len(raw): _fail('Truncated GLB chunk header')
        length,kind=struct.unpack_from('<II',raw,offset);offset+=8
        if length%4 or offset+length>len(raw): _fail('GLB chunk escapes its declared buffer')
        chunk=raw[offset:offset+length];offset+=length
        if chunks==0 and kind!=0x4e4f534a: _fail('GLB JSON must be first')
        if kind==0x4e4f534a:
            if document is not None: _fail('Duplicate GLB JSON chunk')
            document=json.loads(chunk)
        elif kind==0x004e4942:
            if binary is not None: _fail('Duplicate GLB binary chunk')
            binary=chunk
        else: _fail('Unexpected retained GLB chunk')
        chunks+=1
    if not isinstance(document,dict) or binary is None or document.get('asset',{}).get('version')!='2.0':
        _fail('Incomplete retained GLB')
    buffers=document.get('buffers',[])
    if len(buffers)!=1 or 'uri' in buffers[0] or not _integer(buffers[0].get('byteLength')):
        _fail('Expected one internal GLB buffer')
    if not 0<=len(binary)-buffers[0]['byteLength']<=3: _fail('GLB internal buffer size differs')
    return raw,document,binary

def _accessor(document,binary,index,expected_type=None):
    accessors=document.get('accessors',[])
    if not _integer(index) or index>=len(accessors): _fail('Accessor identity is missing')
    accessor=accessors[index]
    if 'sparse' in accessor: _fail('Sparse retained accessors need an explicit transport contract')
    kind=accessor.get('type');component=accessor.get('componentType');count=accessor.get('count')
    if kind not in _TYPES or component not in _COMPONENTS or not _integer(count) or count==0:
        _fail('Invalid retained accessor format/count')
    if expected_type is not None and kind not in expected_type: _fail('Unexpected retained accessor vector shape')
    views=document.get('bufferViews',[]);view_index=accessor.get('bufferView')
    if not _integer(view_index) or view_index>=len(views): _fail('Accessor buffer view is missing')
    view=views[view_index]
    if view.get('buffer',0)!=0: _fail('Accessor refers to an external buffer')
    code,unit=_COMPONENTS[component];width=unit*_TYPES[kind]
    begin=view.get('byteOffset',0);length=view.get('byteLength');local=accessor.get('byteOffset',0);stride=view.get('byteStride',width)
    if not all(_integer(x) for x in (begin,length,local,stride)) or stride<width or stride%unit or local%unit or begin%unit:
        _fail('Invalid accessor alignment/stride')
    if begin+length>document['buffers'][0]['byteLength'] or local+(count-1)*stride+width>length:
        _fail('Accessor escapes its declared view')
    form='<'+code*_TYPES[kind]
    rows=[list(struct.unpack_from(form,binary,begin+local+i*stride)) for i in range(count)]
    normalized=accessor.get('normalized',False)
    if normalized:
        if component not in (5120,5121,5122,5123): _fail('Invalid normalized accessor component type')
        limit={5120:127,5121:255,5122:32767,5123:65535}[component]
        rows=[[max(-1.0,float(v)/limit) if component in (5120,5122) else float(v)/limit for v in row] for row in rows]
    if any(not _finite(row) for row in rows): _fail('Nonfinite retained accessor data')
    return rows

def _identity(): return [1.,0.,0.,0.,0.,1.,0.,0.,0.,0.,1.,0.,0.,0.,0.,1.]
def _multiply(a,b): return [sum(a[k*4+r]*b[c*4+k] for k in range(4)) for c in range(4) for r in range(4)]

def _world_matrices(document):
    nodes=document.get('nodes',[]);parents={};cache={};active=set()
    for index,node in enumerate(nodes):
        for child in node.get('children',[]):
            if not _integer(child) or child>=len(nodes) or child in parents: _fail('Invalid/ambiguous retained node parent')
            parents[child]=index
    def world(index):
        if index in cache:return cache[index]
        if index in active:_fail('Cyclic retained node hierarchy')
        active.add(index);node=nodes[index]
        if 'matrix' in node:
            if any(k in node for k in ('translation','rotation','scale')):_fail('Node mixes matrix and TRS')
            matrix=node['matrix']
            if len(matrix)!=16 or not _finite(matrix):_fail('Invalid node matrix')
        else:
            t=node.get('translation',[0.,0.,0.]);q=node.get('rotation',[0.,0.,0.,1.]);s=node.get('scale',[1.,1.,1.])
            if len(t)!=3 or len(q)!=4 or len(s)!=3 or not _finite(t+q+s) or abs(sum(v*v for v in q)-1)>1e-5:_fail('Invalid retained node TRS')
            x,y,z,w=q
            matrix=[(1-2*y*y-2*z*z)*s[0],(2*x*y+2*z*w)*s[0],(2*x*z-2*y*w)*s[0],0.,
                    (2*x*y-2*z*w)*s[1],(1-2*x*x-2*z*z)*s[1],(2*y*z+2*x*w)*s[1],0.,
                    (2*x*z+2*y*w)*s[2],(2*y*z-2*x*w)*s[2],(1-2*x*x-2*y*y)*s[2],0.,*t,1.]
        if max(abs(matrix[i]-value) for i,value in ((3,0),(7,0),(11,0),(15,1)))>1e-7:_fail('Node matrix is not affine')
        result=_multiply(world(parents[index]),matrix) if index in parents else list(matrix)
        if not _finite(result):_fail('World node frame is nonfinite')
        active.remove(index);cache[index]=result;return result
    for index in range(len(nodes)):world(index)
    return cache

def _material(document,primitive):
    materials=document.get('materials',[]);index=primitive.get('material')
    if index is None:material={}
    elif not _integer(index) or index>=len(materials):_fail('Invalid material identity')
    else:material=materials[index]
    allowed={'name','pbrMetallicRoughness','doubleSided','alphaMode','alphaCutoff','emissiveFactor','extensions','extras'}
    if set(material)-allowed:_fail('Textured/unknown material needs a separate retained role contract')
    pbr=material.get('pbrMetallicRoughness',{})
    if set(pbr)-{'baseColorFactor','metallicFactor','roughnessFactor'}:_fail('Textured PBR material is outside this palette transport')
    extensions=material.get('extensions',{})
    if set(extensions)-{'KHR_materials_unlit'}:_fail('Unsupported retained material extension')
    result={'base_color':pbr.get('baseColorFactor',[1.,1.,1.,1.]),'metallic':pbr.get('metallicFactor',1.),'roughness':pbr.get('roughnessFactor',1.),
            'double_sided':material.get('doubleSided',False),'alpha_mode':material.get('alphaMode','OPAQUE'),'alpha_cutoff':material.get('alphaCutoff',.5),
            'emissive':material.get('emissiveFactor',[0.,0.,0.]),'unlit':'KHR_materials_unlit' in extensions}
    if len(result['base_color'])!=4 or len(result['emissive'])!=3 or not _finite(result['base_color']+result['emissive']+[result['metallic'],result['roughness'],result['alpha_cutoff']]):_fail('Nonfinite material role')
    return result

def _parts(document,binary,names,normal_attribute):
    matrices=_world_matrices(document);found={};meshes=document.get('meshes',[])
    for index,node in enumerate(document.get('nodes',[])):
        if 'mesh' not in node:continue
        name=node.get('name')
        if name not in names:_fail('Unexpected retained/exported mesh node: '+str(name))
        if name in found:_fail('Ambiguous retained/exported mesh node: '+name)
        mesh_index=node['mesh']
        if not _integer(mesh_index) or mesh_index>=len(meshes):_fail('Mesh identity is missing')
        primitives=meshes[mesh_index].get('primitives',[])
        if len(primitives)!=1 or primitives[0].get('mode',4)!=4 or 'skin' in node or 'targets' in primitives[0]:_fail('Expected one rigid retained triangle primitive: '+name)
        primitive=primitives[0];attributes=primitive.get('attributes',{})
        if not {'POSITION',normal_attribute,'TEXCOORD_0','COLOR_0'}<=set(attributes):_fail('Missing retained corner attribute: '+name)
        row={'positions':_accessor(document,binary,attributes['POSITION'],{'VEC3'}),'normals':_accessor(document,binary,attributes[normal_attribute],{'VEC3'}),
             'uvs':_accessor(document,binary,attributes['TEXCOORD_0'],{'VEC2'}),'colors':_accessor(document,binary,attributes['COLOR_0'],{'VEC3','VEC4'})}
        count=len(row['positions'])
        if any(len(row[k])!=count for k in ('normals','uvs','colors')):_fail('Corner attribute counts differ: '+name)
        row['colors']=[v+[1.] if len(v)==3 else v for v in row['colors']]
        if 'indices' in primitive:
            decoded=_accessor(document,binary,primitive['indices'],{'SCALAR'})
            accessor=document['accessors'][primitive['indices']]
            if accessor.get('componentType') not in (5121,5123,5125) or accessor.get('normalized',False):_fail('Triangle indices must be unsigned integers')
            indices=[v[0] for v in decoded]
        else:indices=list(range(count))
        if not indices or len(indices)%3 or any(not _integer(v) or v>=count for v in indices):_fail('Invalid retained triangle indices: '+name)
        row.update(indices=indices,world_matrix=matrices[index],material_role=_material(document,primitive),source_node=name,source_mesh=mesh_index,normal_accessor=attributes[normal_attribute])
        found[name]=row
    if set(found)!=set(names):_fail('Retained/exported part inventory is incomplete')
    return found

def read_retained_parts(path,expected_names):
    names=list(expected_names)
    if not names or len(set(names))!=len(names) or any(not isinstance(n,str) or not n for n in names):_fail('Invalid expected retained part identities')
    raw,document,binary=_read(path);parts=_parts(document,binary,names,'NORMAL')
    for row in parts.values():row['source_glb_sha256']=_sha(raw)
    return parts

def _centroid(row,triangle):return [sum(row['positions'][v][axis] for v in triangle)/3 for axis in range(3)]
def _cell(point):return tuple(math.floor(v/.001) for v in point)

def _compare_corners(expected,actual):
    first=[expected['indices'][i:i+3] for i in range(0,len(expected['indices']),3)]
    second=[actual['indices'][i:i+3] for i in range(0,len(actual['indices']),3)]
    if len(first)!=len(second):_fail('Triangle multiplicity changed: '+str((len(first),len(second))))
    bins=defaultdict(list)
    for index,triangle in enumerate(second):bins[_cell(_centroid(actual,triangle))].append(index)
    consumed=set();maximum={key:0. for key in TOLERANCES}
    for original_index,triangle in enumerate(first):
        cell=_cell(_centroid(expected,triangle));best=None
        for delta in itertools.product((-1,0,1),repeat=3):
            for target in bins.get(tuple(cell[k]+delta[k] for k in range(3)),[]):
                if target in consumed:continue
                for rotation in range(3):
                    candidate=second[target][rotation:]+second[target][:rotation]
                    errors={key:max(abs(expected[key][a][channel]-actual[key][b][channel]) for a,b in zip(triangle,candidate) for channel in range(len(expected[key][a]))) for key in TOLERANCES}
                    score=max(errors[k]/TOLERANCES[k] for k in errors)
                    if best is None or score<best[0]:best=(score,target,errors)
        if best is None or best[0]>1:
            _fail('Retained wound corner differs: '+json.dumps({'triangle':original_index,'best':best,'tolerances':TOLERANCES}))
        consumed.add(best[1])
        for key in maximum:maximum[key]=max(maximum[key],best[2][key])
    return {'wound_triangle_multiplicity_equal':True,'triangles':len(first),'corners':len(first)*3,'maximum_component_errors':maximum}

def bind_retained_normals(export_path,expected_parts):
    path=Path(export_path);before,document,binary=_read(path)
    names={name:name+'_Geometry' for name in expected_parts}
    actual=_parts(document,binary,names.values(),NORMAL_ATTRIBUTE);proof={};assignments=[]
    for name,expected in expected_parts.items():
        candidate=actual[names[name]]
        frame_error=max(abs(a-b) for a,b in zip(expected['world_matrix'],candidate['world_matrix']))
        if frame_error>FRAME_TOLERANCE:_fail('Retained node frame changed: '+name+' error='+str(frame_error))
        if expected['material_role']!=candidate['material_role']:_fail('Retained palette material role changed: '+name)
        proof[name]={**_compare_corners(expected,candidate),'world_frame_error':frame_error,'material_role_equal':True,'normal_accessor':candidate['normal_accessor']}
        accessor=document['accessors'][candidate['normal_accessor']]
        if accessor.get('componentType')!=5126 or accessor.get('normalized',False):_fail('Raw retained normals must remain FLOAT vectors')
        assignments.append((candidate['source_mesh'],candidate['normal_accessor']))
    for mesh,index in assignments:document['meshes'][mesh]['primitives'][0]['attributes']['NORMAL']=index
    encoded=json.dumps(document,separators=(',',':'),ensure_ascii=False,allow_nan=False).encode('utf-8');encoded+=b' '*((-len(encoded))%4)
    after=struct.pack('<III',0x46546c67,2,12+8+len(encoded)+8+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary
    pending=path.with_name(path.name+'.normals.pending')
    if pending.exists():_fail('Preserve the pending normal transport output before retrying')
    if path.read_bytes()!=before:_fail('Export carrier changed during normal validation')
    with pending.open('xb') as stream:stream.write(after)
    pending.replace(path)
    return {'verified':True,'before_sha256':_sha(before),'after_sha256':_sha(after),'binary_payload_unchanged':True,'normal_source_attribute':NORMAL_ATTRIBUTE,
            'source_glb_sha256':sorted({row['source_glb_sha256'] for row in expected_parts.values()}),'parts':proof,'native_verified':False,'visual_accepted':False}
