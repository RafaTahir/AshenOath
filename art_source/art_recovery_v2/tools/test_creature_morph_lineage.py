"""Independent anatomy, exact lineage, and normal-neutral regression fixtures."""
from copy import deepcopy
from pathlib import Path
import tempfile
import unittest
import numpy as np

from creature_morph_lineage import (VERTEX_ATTRIBUTE, NORMAL_ATTRIBUTE, independent_shape,
    rebase_normal_deltas, verify_import, verify_export, bind_source_mesh_nodes)


NAMES=('AntennaProbe_L','AntennaProbe_R','BrushFeed_L','BrushFeed_R')


def carrier():
    count=84
    normal=np.asarray([.01055110339075327,.999943196773529,.001507300534285605],dtype=np.float32)
    source={'POSITION':np.asarray([[i*.01,0,0] for i in range(count)],dtype=np.float32),
            'NORMAL':np.tile(normal,(count,1)),'TEXCOORD_0':np.zeros((count,2),dtype=np.float32)}
    # One legitimate exported seam split retains the original vertex identity.
    ids=np.concatenate((np.arange(count),[count-1]))
    exported={key:array[ids].copy() for key,array in source.items()}
    exported['NORMAL'][:]=[.010600452311336994,.9999427199363708,.0015000641578808427]
    exported[NORMAL_ATTRIBUTE]=source['NORMAL'][ids].copy()
    exported[VERTEX_ATTRIBUTE]=ids.astype(np.float32).reshape(-1,1)
    source['indices']=np.arange(count).reshape(-1,1)
    exported['indices']=np.arange(count).reshape(-1,1);exported['indices'][-1]=count
    old={'attributes':{key:key for key in ('POSITION','NORMAL','TEXCOORD_0')},'indices':'indices'}
    new={'attributes':{key:key for key in exported if key!='indices'},'indices':'indices','targets':[]}
    selections={name:set(range(i*21,(i+1)*21)) for i,name in enumerate(NAMES)}
    for index,name in enumerate(NAMES):
        selected=np.asarray([i in selections[name] for i in ids])
        position=np.zeros((len(ids),3),dtype=np.float32);position[selected,0]=.005
        normals=np.zeros_like(position)
        base=exported['NORMAL'][selected]
        angle=.05
        rotation=np.asarray([[np.cos(angle),-np.sin(angle),0],[np.sin(angle),np.cos(angle),0],[0,0,1]])
        normals[selected]=(base@rotation.T)-base
        exported['position'+str(index)]=position;exported['normal'+str(index)]=normals
        new['targets'].append({'POSITION':'position'+str(index),'NORMAL':'normal'+str(index)})
    return old,new,source,exported,[(('Head',1.0),)]*count,[(('Head',1.0),)]*len(ids),selections


def prove(parts):
    old,new,source,exported,skin,export_skin,selections=parts
    return verify_export(old,new,source.__getitem__,exported.__getitem__,skin,export_skin,selections,NAMES)


class LineageTests(unittest.TestCase):
    def test_source_mesh_binding_is_bijective_and_uses_actual_retained_node_identity(self):
        source={'nodes':[{'name':'Rig'},{'name':'M16_RuntimeAssembly','mesh':0}], 'meshes':[{}]}
        bound=bind_source_mesh_nodes(source,['M16_RuntimeAssembly'])
        self.assertIs(bound['M16_RuntimeAssembly'],source['nodes'][1])
        for names in ([],['M16_RuntimeAssembly','Icosphere'],['M16_RuntimeAssembly.001'],['M16_RuntimeAssembly']*2):
            with self.subTest(names=names),self.assertRaisesRegex(ValueError,'identity'):
                bind_source_mesh_nodes(source,names)
        # A real source mesh with this name is valid: there is no name blacklist.
        source['nodes'][1]['name']='Icosphere'
        self.assertIn('Icosphere',bind_source_mesh_nodes(source,['Icosphere']))

    def test_missing_duplicate_and_invalid_retained_mesh_bindings_fail(self):
        bad=[{'nodes':[{'mesh':0}],'meshes':[{}]},
             {'nodes':[{'name':'Body','mesh':0},{'name':'Body','mesh':1}],'meshes':[{},{}]},
             {'nodes':[{'name':'Body','mesh':8}],'meshes':[{}]}]
        for source in bad:
            with self.subTest(source=source),self.assertRaisesRegex(ValueError,'Retained anatomical'):
                bind_source_mesh_nodes(source,['Body'])

    def test_full_graft_preserves_literal_base_and_uses_verified_raw_normal_lineage(self):
        from test_graft_creature_ambient import fixture
        from graft_creature_ambient import graft, values
        from preserve_creature_action_bytes import read_glb, write_glb
        from living_creature_motion_profiles import REPLACED_CLIPS
        parts=carrier()

        def document(authored):
            doc,raw=fixture(authored=authored)
            binary=bytearray(raw)
            primitive=deepcopy(parts[1 if authored else 0]);arrays=parts[3 if authored else 2]
            def append(data,kind,component=5126):
                binary.extend(b'\0'*((-len(binary))%4))
                payload=np.asarray(data,dtype={5126:'<f4',5123:'<u2',5125:'<u4'}[component]).tobytes()
                doc['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':len(payload)})
                binary.extend(payload)
                doc['accessors'].append({'bufferView':len(doc['bufferViews'])-1,'componentType':component,
                    'count':len(data),'type':kind})
                return len(doc['accessors'])-1
            for key,value in list(primitive['attributes'].items()):
                data=arrays[value]
                primitive['attributes'][key]=append(data,{1:'SCALAR',2:'VEC2',3:'VEC3'}[data.shape[1]])
            count=len(arrays['POSITION'])
            primitive['attributes']['JOINTS_0']=append(np.zeros((count,4)),'VEC4',5123)
            primitive['attributes']['WEIGHTS_0']=append(np.tile([1,0,0,0],(count,1)),'VEC4')
            primitive['indices']=append(arrays['indices'],'SCALAR',5125)
            for target in primitive.get('targets',[]):
                for key,value in list(target.items()):target[key]=append(arrays[value],'VEC3')
            mesh=doc['meshes'][0];mesh['primitives']=[primitive]
            if authored:
                mesh['extras']={'targetNames':list(NAMES)};mesh['weights']=[0]*4
                for clip in doc['animations']:
                    if clip['name'] in REPLACED_CLIPS:
                        sampler=len(clip['samplers'])
                        clip['samplers'].append({'input':clip['samplers'][0]['input'],
                            'output':append(np.asarray([0]*4+[.5]*4+[0]*4).reshape(-1,1),'SCALAR')})
                        clip['channels'].append({'sampler':sampler,'target':{'node':2,'path':'weights'}})
            return doc,bytes(binary)

        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);old=root/'old.glb';raw=root/'raw.glb';new=root/'new.glb'
            write_glb(old,*document(False));write_glb(raw,*document(True))
            receipt=graft(old,raw,new,morph_selections=[{'mesh':'Body','shape_key':name,'vertices':sorted(indices)}
                                                     for name,indices in parts[-1].items()])
            before,base=read_glb(old);after,result=read_glb(new)
            self.assertEqual(result[:len(base)],base)
            self.assertEqual(before['meshes'][0]['primitives'][0]['attributes'],after['meshes'][0]['primitives'][0]['attributes'])
            second=after['meshes'][0]['primitives'][0]['targets'][1]
            self.assertTrue(np.array_equal(values(after,result,second['POSITION'])[0],np.zeros(3)))
            self.assertTrue(np.array_equal(values(after,result,second['NORMAL'])[0],np.zeros(3)))
            self.assertTrue(receipt['new_morph_mapping'][0]['explicit_lineage']['raw_normal_lineage_verified'])

    def test_raw_normals_and_split_vertex_identity_preserve_all_ordered_corners(self):
        parts=carrier();ids,normals,report=prove(parts)
        self.assertEqual(report['ordered_triangle_corners'],84)
        self.assertEqual(report['source_vertices'],84)
        self.assertEqual(len(ids),85)
        self.assertTrue(report['independent_position_support_verified'])
        for index,delta in enumerate(normals):
            untouched=np.asarray([i not in parts[-1][NAMES[index]] for i in ids])
            self.assertTrue(np.array_equal(delta[untouched],np.zeros_like(delta[untouched])))
            before=parts[2]['NORMAL'][ids]
            np.testing.assert_allclose(np.linalg.norm(before+delta,axis=1),np.linalg.norm(before,axis=1),atol=1e-7)

    def test_changed_raw_normal_is_rejected_even_when_exported_normal_looks_plausible(self):
        parts=carrier();parts[3][NORMAL_ATTRIBUTE][1,0]+=.001
        with self.assertRaisesRegex(ValueError,'NORMAL'):prove(parts)

    def test_nonfinite_source_and_exported_geometry_channels_fail_before_tolerance(self):
        for side in (2,3):
            keys=('POSITION','NORMAL','TEXCOORD_0')+((NORMAL_ATTRIBUTE,VERTEX_ATTRIBUTE) if side==3 else ())
            for key in keys:
                for value in (np.nan,np.inf,-np.inf):
                    parts=carrier();parts[side][key][1,0]=value
                    with self.subTest(side=side,key=key,value=value),self.assertRaisesRegex(ValueError,'Nonfinite'):
                        prove(parts)

    def test_nonfinite_position_and_normal_morphs_fail_on_selected_and_untouched_vertices(self):
        for key in ('position0','normal0'):
            for index in (0,30):
                for value in (np.nan,np.inf,-np.inf):
                    parts=carrier();parts[3][key][index,0]=value
                    with self.subTest(key=key,index=index,value=value),self.assertRaisesRegex(ValueError,'Nonfinite'):
                        prove(parts)

    def test_nonfinite_named_skin_weights_fail_on_both_sides(self):
        for side in (4,5):
            for value in (np.nan,np.inf,-np.inf):
                parts=carrier();parts[side][1]=(('Head',value),)
                with self.subTest(side=side,value=value),self.assertRaisesRegex(ValueError,'skin weight'):
                    prove(parts)

    def test_changed_uv_and_position_are_not_bypassed_by_valid_lineage(self):
        for key in ('POSITION','TEXCOORD_0'):
            parts=carrier();parts[3][key][1,0]+=.001
            with self.subTest(key=key),self.assertRaisesRegex(ValueError,'channel changed'):prove(parts)

    def test_changed_joint_and_weight_are_rejected(self):
        for bad in ((('Invented',1.0),),(('Head',.9),)):
            parts=carrier();parts[5][1]=bad
            with self.subTest(bad=bad),self.assertRaisesRegex(ValueError,'named skin'):prove(parts)

    def test_reversed_or_omitted_triangle_corners_are_rejected(self):
        for omit in (False,True):
            parts=carrier()
            if omit:parts[3]['indices']=parts[3]['indices'][:-3]
            else:parts[3]['indices'][[0,1]]=parts[3]['indices'][[1,0]]
            with self.subTest(omit=omit),self.assertRaisesRegex(ValueError,'ordered triangle'):prove(parts)

    def test_fractional_and_missing_vertex_identity_are_rejected(self):
        for raw in (1.5,1000):
            parts=carrier();parts[3][VERTEX_ATTRIBUTE][1]=raw
            with self.subTest(raw=raw),self.assertRaisesRegex(ValueError,'vertex lineage'):prove(parts)
        parts=carrier();parts[1]['attributes'].pop(NORMAL_ATTRIBUTE)
        with self.assertRaisesRegex(ValueError,'raw-normal/vertex lineage'):prove(parts)

    def test_accumulated_previous_key_position_is_rejected(self):
        parts=carrier();parts[3]['position1'][0]=parts[3]['position0'][0]
        with self.assertRaisesRegex(ValueError,'outside its independent selection'):prove(parts)

    def test_overlapping_controls_and_excessive_amplitude_are_rejected(self):
        parts=carrier();parts[-1][NAMES[1]].add(0)
        with self.assertRaisesRegex(ValueError,'overlap'):prove(parts)
        parts=carrier();parts[3]['position3'][63,0]=.14
        with self.assertRaisesRegex(ValueError,'exceeds authored displacement'):prove(parts)

    def test_export_normal_rounding_never_enters_unaffected_surface(self):
        parts=carrier();parts[3]['normal1'][0,0]=.00005
        with self.assertRaisesRegex(ValueError,'unaffected surface'):prove(parts)

    def test_f32_normalization_dust_on_proven_unchanged_triangles_is_exactly_neutral(self):
        parts=carrier();parts[3]['normal1'][0,0]=np.finfo(np.float32).eps
        _,normals,report=prove(parts)
        self.assertTrue(np.array_equal(normals[1][0],np.zeros(3)))
        self.assertEqual(report['verified_unchanged_surface_normal_roundoff_removed']['AntennaProbe_R'],np.finfo(np.float32).eps)

    def test_zero_normal_delta_stays_exactly_zero_despite_base_difference(self):
        exact=np.asarray([[.0105511034,.9999431968,.0015073005]])
        exported=np.asarray([[.0106004523,.9999427199,.0015000642]])
        self.assertTrue(np.array_equal(rebase_normal_deltas(exact,exported,np.zeros((1,3))),np.zeros((1,3))))

    def test_half_turn_and_nonfinite_normals_fail_closed(self):
        with self.assertRaisesRegex(ValueError,'half-turn'):
            rebase_normal_deltas([[0,1,0]],[[0,1,0]],[[0,-2,0]])
        with self.assertRaisesRegex(ValueError,'Nonfinite'):
            rebase_normal_deltas([[0,1,0]],[[0,1,0]],[[np.nan,0,0]])

    def test_import_requires_exact_unmerged_vertex_and_corner_identity(self):
        parts=carrier();source=parts[2]
        positions=source['POSITION'][:,[0,2,1]].copy();positions[:,1]*=-1
        indices=source['indices'].reshape(-1)
        uvs=source['TEXCOORD_0'][indices].copy();uvs[:,1]=1-uvs[:,1]
        report=verify_import(source,indices,positions,indices,{'TEXCOORD_0':uvs},parts[4],parts[4])
        self.assertEqual(report['position_error'],0)
        positions[[0,1]]=positions[[1,0]]
        with self.assertRaisesRegex(ValueError,'vertex order'):
            verify_import(source,indices,positions,indices,{'TEXCOORD_0':uvs},parts[4],parts[4])

    def test_each_shape_is_derived_independently_from_one_frozen_basis(self):
        basis=np.asarray([[-.1,-.5,.2]]*21+[[.1,-.5,.2]]*21+[[-.1,-.4,.2]]*21+[[.1,-.4,.2]]*21)
        before=basis.copy()
        for index,name in enumerate(NAMES):
            selected=list(range(index*21,(index+1)*21))
            shape=independent_shape(basis,selected,np.eye(4),name)
            outside=np.ones(len(basis),dtype=bool);outside[selected]=False
            self.assertTrue(np.array_equal(shape[outside],basis[outside]))
            self.assertTrue(np.any(shape[selected]!=basis[selected]))
            self.assertTrue(np.array_equal(basis,before))
        with self.assertRaisesRegex(ValueError,'crosses'):
            independent_shape(basis,list(range(21)),np.eye(4),'AntennaProbe_R')


if __name__=='__main__':unittest.main()
