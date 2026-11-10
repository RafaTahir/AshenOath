"""Reject accidental base/material/skin changes during an ambient-only graft."""
import copy
from pathlib import Path
import tempfile
import unittest

import numpy as np

from graft_creature_ambient import graft, values, verify_retained_base
from living_creature_motion_profiles import REPLACED_CLIPS
from preserve_creature_action_bytes import action_digest, read_glb, write_glb


def fixture(authored=False, morph=False, reorder=False):
    doc = {'asset': {'version': '2.0'}, 'buffers': [{'byteLength': 0}], 'bufferViews': [], 'accessors': [],
           'nodes': [{'name': 'Root', 'children': [1, 2]}, {'name': 'Head'}, {'name': 'Body', 'mesh': 0, 'skin': 0}],
           'scenes': [{'nodes': [0]}], 'scene': 0, 'skins': [{'joints': [1]}], 'animations': [],
           'materials': [{'pbrMetallicRoughness': {'baseColorFactor': [1, .2 if authored else .4, .1, 1]},
                          'normalTexture': {'index': 0, 'scale': .6}, 'doubleSided': True}],
           'textures': [{'source': 0}], 'images': [{'uri': 'textures/retained.png'}]}
    data = bytearray()

    def array(rows, kind, component=5126):
        dtype = '<f4' if component == 5126 else '<u2'
        data.extend(b'\0' * ((-len(data)) % 4))
        payload = np.asarray(rows, dtype=dtype).tobytes()
        doc['bufferViews'].append({'buffer': 0, 'byteOffset': len(data), 'byteLength': len(payload)})
        data.extend(payload)
        doc['accessors'].append({'bufferView': len(doc['bufferViews'])-1, 'componentType': component,
                                 'count': len(rows), 'type': kind})
        return len(doc['accessors'])-1

    order = [2, 0, 1] if reorder else [0, 1, 2]
    positions = np.asarray([[0, 0, 0], [1, 0, 0], [0, 1, 0]], dtype=float)[order]
    uvs = np.asarray([[0, 0], [1, 0], [0, 1]], dtype=float)[order]
    primitive = {'attributes': {'POSITION': array(positions, 'VEC3'),
                                'NORMAL': array([[0, 0, 1]]*3, 'VEC3'), 'TEXCOORD_0': array(uvs, 'VEC2'),
                                'JOINTS_0': array([[0, 0, 0, 0]]*3, 'VEC4', 5123),
                                'WEIGHTS_0': array([[1, 0, 0, 0]]*3, 'VEC4')}, 'material': 0}
    mesh = {'name': 'BodyMesh', 'primitives': [primitive]}
    if morph:
        primitive['targets'] = [{'POSITION': array(np.asarray([[0, 0, .01], [0, 0, .02], [0, 0, .03]])[order], 'VEC3')}]
        mesh['extras'] = {'targetNames': ['AntennaProbe_L']}
        mesh['weights'] = [0]
    doc['meshes'] = [mesh]
    times = array([[0], [.5], [1]], 'SCALAR')
    for name in ['Attack', *REPLACED_CLIPS]:
        output = array([[0, 0, 0], [.2 if authored else .1, 0, 0], [0, 0, 0]], 'VEC3')
        clip = {'name': name, 'samplers': [{'input': times, 'output': output}],
                'channels': [{'sampler': 0, 'target': {'node': 1, 'path': 'translation'}}]}
        if morph and name in REPLACED_CLIPS:
            clip['samplers'].append({'input': times, 'output': array([[0], [.5], [0]], 'SCALAR')})
            clip['channels'].append({'sampler': 1, 'target': {'node': 2, 'path': 'weights'}})
        doc['animations'].append(clip)
    return doc, bytes(data)


class AmbientGraftTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='ao-ambient-graft-')
        self.addCleanup(self.directory.cleanup)
        self.old = Path(self.directory.name)/'retained.glb'
        self.carrier = Path(self.directory.name)/'carrier.glb'
        self.output = Path(self.directory.name)/'candidate.glb'
        write_glb(self.old, *fixture())

    def test_retains_literal_base_bytes_materials_skin_and_protected_attack(self):
        write_glb(self.carrier, *fixture(authored=True))
        receipt = graft(self.old, self.carrier, self.output)
        old, old_data = read_glb(self.old)
        new, new_data = read_glb(self.output)
        carrier, carrier_data = read_glb(self.carrier)
        self.assertTrue(receipt['retained_base_bytes_equal'])
        self.assertEqual(old_data, new_data[:len(old_data)])
        for key in ('materials', 'images', 'textures', 'meshes', 'skins', 'nodes'):
            self.assertEqual(old[key], new[key])
        self.assertEqual(action_digest(old, old_data, old['animations'][0]), action_digest(new, new_data, new['animations'][0]))
        self.assertEqual(action_digest(carrier, carrier_data, carrier['animations'][1]), action_digest(new, new_data, new['animations'][1]))

    def test_maps_new_anatomical_morph_by_actual_vertex_uv_and_skin(self):
        write_glb(self.carrier, *fixture(authored=True, morph=True, reorder=True))
        receipt = graft(self.old, self.carrier, self.output)
        new, binary = read_glb(self.output)
        target = new['meshes'][0]['primitives'][0]['targets'][0]['POSITION']
        np.testing.assert_allclose(values(new, binary, target)[:, 2], [.01, .02, .03])
        self.assertTrue(receipt['new_morph_mapping'][0]['vertex_uv_normal_skin_mapping_verified'])

    def reject(self, mutate, pattern, morph=False):
        document, binary = fixture(authored=True, morph=morph)
        mutate(document)
        write_glb(self.carrier, document, binary)
        with self.assertRaisesRegex(ValueError, pattern):
            graft(self.old, self.carrier, self.output)
        self.assertFalse(self.output.exists())

    def test_rejects_changed_ancestor_rest(self):
        self.reject(lambda d: d['nodes'][0].update(scale=[1, 2, 1]), 'rest bases')

    def test_rejects_changed_parent(self):
        def mutate(doc):
            doc['nodes'][0]['children'] = [2]
            doc['nodes'][2]['children'] = [1]
        self.reject(mutate, 'parent')

    def test_rejects_missing_bone(self):
        self.reject(lambda d: d['nodes'][1].update(name='InventedHead'), 'identity')

    def test_rejects_missing_retained_uv_for_morph_mapping(self):
        self.reject(lambda d: d['meshes'][0]['primitives'][0]['attributes'].pop('TEXCOORD_0'), 'vertex/UV/skin', True)

    def test_rejects_changed_skin_joint_for_morph_mapping(self):
        self.reject(lambda d: d['skins'][0].update(joints=[0]), 'vertex/UV/skin', True)

    def test_rejects_truncated_authored_accessor(self):
        self.reject(lambda d: d['bufferViews'][-1].update(byteLength=4), 'exceeds')

    def test_preserves_existing_morphs_instead_of_reexporting_them(self):
        write_glb(self.old, *fixture(morph=True))
        write_glb(self.carrier, *fixture(authored=True, morph=True, reorder=True))
        receipt = graft(self.old, self.carrier, self.output)
        old, data = read_glb(self.old)
        new, updated = read_glb(self.output)
        self.assertEqual(old['meshes'], new['meshes'])
        self.assertEqual(data, updated[:len(data)])
        self.assertEqual([], receipt['new_morph_mapping'])

    def test_retains_inactive_colour_set_omitted_by_blender(self):
        original, binary = fixture()
        # Colour is retained byte-for-byte, not used to infer a new delta.
        original['meshes'][0]['primitives'][0]['attributes']['COLOR_1'] = original['meshes'][0]['primitives'][0]['attributes']['NORMAL']
        write_glb(self.old, original, binary)
        write_glb(self.carrier, *fixture(authored=True, morph=True, reorder=True))
        graft(self.old, self.carrier, self.output)
        new, updated = read_glb(self.output)
        self.assertEqual(original['meshes'][0]['primitives'][0]['attributes'], new['meshes'][0]['primitives'][0]['attributes'])

    def test_independent_proof_rejects_changed_base_uv_assignment(self):
        write_glb(self.carrier, *fixture(authored=True, morph=True))
        graft(self.old, self.carrier, self.output)
        old, data = read_glb(self.old)
        new, updated = read_glb(self.output)
        new['meshes'][0]['primitives'][0]['attributes']['TEXCOORD_0'] = 0
        with self.assertRaisesRegex(ValueError, 'primitive attributes'):
            verify_retained_base(old, data, new, updated)


if __name__ == '__main__':
    unittest.main(verbosity=2)
