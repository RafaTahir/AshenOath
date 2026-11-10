import copy
import json
from pathlib import Path
import struct
import tempfile
import unittest

import living_world_gltf_transport as transport


def fixture(path,candidate=False,omit_reverse=False,color_delta=0.,normal_delta=0.,frame_delta=0.,winding=False):
    binary=bytearray();views=[];accessors=[]
    def attribute(rows,kind,component=5126):
        while len(binary)%4:binary.append(0)
        offset=len(binary);code='f' if component==5126 else 'I'
        binary.extend(b''.join(struct.pack('<'+code*len(row),*row) for row in rows))
        views.append({'buffer':0,'byteOffset':offset,'byteLength':len(binary)-offset})
        accessors.append({'bufferView':len(views)-1,'componentType':component,'count':len(rows),'type':kind})
        return len(accessors)-1
    source_positions=[[0.,0.,0.],[1.,0.,0.],[0.,1.,0.]]
    indices=[0,1,2] if omit_reverse else [0,1,2,2,1,0]
    if winding:indices=[0,1,2,0,1,2]
    mapping=indices if candidate else [0,1,2]
    positions=[source_positions[i] for i in mapping]
    normals=[[normal_delta,0.,1.] for _ in positions]
    uvs=[[source_positions[i][0],source_positions[i][1]] for i in mapping]
    colors=[[.33725491166114807,.09803921729326248+color_delta,.10980392247438431,1.] for _ in positions]
    attrs={'POSITION':attribute(positions,'VEC3'),'NORMAL':attribute([[.001,0.,1.] for _ in positions] if candidate else normals,'VEC3'),
           'TEXCOORD_0':attribute(uvs,'VEC2'),'COLOR_0':attribute(colors,'VEC4')}
    if candidate:attrs[transport.NORMAL_ATTRIBUTE]=attribute(normals,'VEC3')
    ix=attribute([[i] for i in (range(len(indices)) if candidate else indices)],'SCALAR',5125)
    primitive={'attributes':attrs,'indices':ix,'material':0}
    nodes=[{'name':'Flag','translation':[2.,3.,4.],'mesh':0}]
    if candidate:nodes=[{'name':'Flag','translation':[2.+frame_delta,3.,4.],'children':[1]},{'name':'Flag_Geometry','mesh':0}]
    doc={'asset':{'version':'2.0'},'buffers':[{'byteLength':len(binary)}],'bufferViews':views,'accessors':accessors,'nodes':nodes,
         'meshes':[{'primitives':[primitive]}],'materials':[{'doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':[1.,1.,1.,1.],'metallicFactor':0.,'roughnessFactor':.94}}]}
    write(path,doc,bytes(binary));return doc,bytes(binary)


def write(path,doc,binary):
    encoded=json.dumps(doc).encode();encoded+=b' '*((-len(encoded))%4);binary+=b'\0'*((-len(binary))%4)
    path.write_bytes(struct.pack('<III',0x46546c67,2,12+8+len(encoded)+8+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)


class TransportTests(unittest.TestCase):
    def setUp(self):
        self.directory=tempfile.TemporaryDirectory();self.root=Path(self.directory.name)
        self.source=self.root/'source.glb';fixture(self.source)
        self.parts=transport.read_retained_parts(self.source,['Flag'])
        self.output=self.root/'candidate.glb'
    def tearDown(self):self.directory.cleanup()
    def rejects_unchanged(self,**changes):
        fixture(self.output,candidate=True,**changes);before=self.output.read_bytes()
        with self.assertRaises(ValueError):transport.bind_retained_normals(self.output,self.parts)
        self.assertEqual(before,self.output.read_bytes())
        self.assertFalse(self.output.with_name(self.output.name+'.normals.pending').exists())
    def test_read_preserves_opposite_face_and_float_color(self):
        row=self.parts['Flag'];self.assertEqual(row['indices'],[0,1,2,2,1,0]);self.assertAlmostEqual(row['colors'][0][1],.09803921729326248)
        self.assertEqual(row['world_matrix'][12:15],[2.,3.,4.])
    def test_corner_expansion_rebinds_only_validated_normal(self):
        fixture(self.output,candidate=True);before,doc,blob=transport._read(self.output)
        result=transport.bind_retained_normals(self.output,self.parts);after,rewritten,newblob=transport._read(self.output)
        self.assertTrue(result['verified']);self.assertEqual(blob,newblob);self.assertNotEqual(before,after)
        attrs=rewritten['meshes'][0]['primitives'][0]['attributes'];self.assertEqual(attrs['NORMAL'],attrs[transport.NORMAL_ATTRIBUTE])
        self.assertEqual(result['parts']['Flag']['triangles'],2)
    def test_missing_opposite_face_rejected(self):self.rejects_unchanged(omit_reverse=True)
    def test_duplicate_same_winding_rejected(self):self.rejects_unchanged(winding=True)
    def test_quantized_color_rejected(self):self.rejects_unchanged(color_delta=.0004518)
    def test_normal_changed_rejected(self):self.rejects_unchanged(normal_delta=.0003)
    def test_changed_pivot_frame_rejected(self):self.rejects_unchanged(frame_delta=.001)
    def test_changed_material_role_rejected(self):
        doc,blob=fixture(self.output,candidate=True);doc['materials'][0]['doubleSided']=False;write(self.output,doc,blob);before=self.output.read_bytes()
        with self.assertRaises(ValueError):transport.bind_retained_normals(self.output,self.parts)
        self.assertEqual(before,self.output.read_bytes())
    def test_accessor_bounds_rejected(self):
        doc,blob=fixture(self.source);doc['accessors'][0]['byteOffset']=999999;write(self.source,doc,blob)
        with self.assertRaises(ValueError):transport.read_retained_parts(self.source,['Flag'])
    def test_nonfinite_source_rejected(self):
        doc,blob=fixture(self.source);data=bytearray(blob);struct.pack_into('<f',data,0,float('nan'));write(self.source,doc,bytes(data))
        with self.assertRaises(ValueError):transport.read_retained_parts(self.source,['Flag'])
    def test_ambiguous_mesh_identity_rejected(self):
        doc,blob=fixture(self.source);doc['nodes'].append(copy.deepcopy(doc['nodes'][0]));write(self.source,doc,blob)
        with self.assertRaises(ValueError):transport.read_retained_parts(self.source,['Flag'])
    def test_hierarchy_cycle_rejected(self):
        doc,blob=fixture(self.source);doc['nodes'][0]['children']=[0];write(self.source,doc,blob)
        with self.assertRaises(ValueError):transport.read_retained_parts(self.source,['Flag'])
    def test_implicit_white_material_equivalent(self):
        doc,blob=fixture(self.output,candidate=True);del doc['materials'][0]['pbrMetallicRoughness']['baseColorFactor'];write(self.output,doc,blob)
        self.assertTrue(transport.bind_retained_normals(self.output,self.parts)['verified'])
    def test_pending_file_preserved(self):
        fixture(self.output,candidate=True);pending=self.output.with_name(self.output.name+'.normals.pending');pending.write_bytes(b'previous failed candidate')
        with self.assertRaises(ValueError):transport.bind_retained_normals(self.output,self.parts)
        self.assertEqual(pending.read_bytes(),b'previous failed candidate')


if __name__=='__main__':unittest.main()
