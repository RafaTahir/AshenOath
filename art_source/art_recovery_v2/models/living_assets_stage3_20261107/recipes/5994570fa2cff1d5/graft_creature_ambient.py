"""Graft authored ambient curves onto exact retained geometry and materials.

The Blender export is an animation/morph carrier. The original GLB remains
the output's base document and buffer, including every combat/locomotion
sample. New morph deltas require actual vertex, UV, normal and skin matches.
"""
import copy
import hashlib
import itertools
import json
from pathlib import Path

import numpy as np

from living_creature_motion_profiles import REPLACED_CLIPS
from preserve_creature_action_bytes import accessor_bytes, action_digest, matrix, read_glb, write_glb
from creature_morph_lineage import VERTEX_ATTRIBUTE, NORMAL_ATTRIBUTE, verify_export

DTYPES = {5120: '<i1', 5121: '<u1', 5122: '<i2', 5123: '<u2', 5125: '<u4', 5126: '<f4'}
WIDTHS = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
EPSILON = 1e-5


def values(document, binary, index):
    item = document['accessors'][index]
    result = np.frombuffer(accessor_bytes(document, binary, index), dtype=DTYPES[item['componentType']])
    result = result.reshape(item['count'], WIDTHS[item['type']])
    if item.get('normalized'):
        dtype = np.dtype(DTYPES[item['componentType']])
        if dtype.kind not in ('i', 'u'):
            raise ValueError('Only integer glTF attributes can be normalized')
        result = result.astype(np.float64) / np.iinfo(dtype).max
        if dtype.kind == 'i':
            result = np.maximum(result, -1.0)
    if not np.isfinite(result).all():
        raise ValueError('Nonfinite retained or authored GLB samples')
    return result


def _skin_rows(document, binary, node, primitive):
    attributes = primitive['attributes']
    if ('JOINTS_0' in attributes) != ('WEIGHTS_0' in attributes):
        raise ValueError('Incomplete skin attributes')
    count = document['accessors'][attributes['POSITION']]['count']
    if 'JOINTS_0' not in attributes:
        return [()] * count
    if 'skin' not in node:
        raise ValueError('Skinned mesh has no retained skin owner')
    joints = document['skins'][node['skin']]['joints']
    joint_names = [document['nodes'][index].get('name', '') for index in joints]
    if any(not name for name in joint_names) or len(set(joint_names)) != len(joint_names):
        raise ValueError('Skin joint identity is absent or ambiguous')
    groups = []
    for suffix in ('0', '1'):
        if 'JOINTS_' + suffix not in attributes:
            if 'WEIGHTS_' + suffix in attributes:
                raise ValueError('Weights have no matching joints')
            continue
        if 'WEIGHTS_' + suffix not in attributes:
            raise ValueError('Joints have no matching weights')
        indices = values(document, binary, attributes['JOINTS_' + suffix])
        weights = values(document, binary, attributes['WEIGHTS_' + suffix])
        if indices.shape != weights.shape or len(indices) != count:
            raise ValueError('Skin attribute counts differ')
        groups.append((indices, weights))
    rows = []
    for vertex in range(count):
        combined = {}
        for indices, weights in groups:
            for raw_index, weight in zip(indices[vertex], weights[vertex]):
                index = int(raw_index)
                if index != raw_index or not 0 <= index < len(joint_names) or weight < 0:
                    raise ValueError('Invalid retained skin influence')
                if weight > EPSILON:
                    name = joint_names[index]
                    combined[name] = combined.get(name, 0.0) + float(weight)
        rows.append(tuple(sorted(combined.items())))
    return rows


def _same_skin(first, second):
    return len(first) == len(second) and all(a == b and abs(x-y) <= EPSILON
                                           for (a, x), (b, y) in zip(first, second))


def _append_array(document, binary, array, kind):
    array = np.asarray(array, dtype='<f4')
    if array.ndim != 2 or array.shape[1] != WIDTHS[kind] or not np.isfinite(array).all():
        raise ValueError('Invalid authored morph array')
    binary.extend(b'\0' * ((-len(binary)) % 4))
    offset = len(binary)
    payload = array.tobytes()
    binary.extend(payload)
    view = len(document['bufferViews'])
    document['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(payload)})
    index = len(document['accessors'])
    document['accessors'].append({'bufferView': view, 'componentType': 5126, 'count': len(array),
                                  'type': kind, 'min': array.min(axis=0).tolist(), 'max': array.max(axis=0).tolist()})
    return index


def verify_retained_base(original, original_binary, candidate, candidate_binary):
    if candidate_binary[:len(original_binary)] != original_binary:
        raise ValueError('Retained geometry/material/skin buffer prefix changed')
    for field in ('accessors', 'bufferViews'):
        if candidate[field][:len(original[field])] != original[field]:
            raise ValueError('Retained buffer layout changed: ' + field)
    for field in ('materials', 'images', 'textures', 'samplers', 'skins', 'nodes', 'scenes', 'scene'):
        if candidate.get(field) != original.get(field):
            raise ValueError('Retained static document field changed: ' + field)
    if len(candidate.get('meshes', [])) != len(original.get('meshes', [])):
        raise ValueError('Retained mesh identity count changed')
    added = []
    for before, after in zip(original.get('meshes', []), candidate.get('meshes', [])):
        old_names = before.get('extras', {}).get('targetNames', [])
        names = after.get('extras', {}).get('targetNames', [])
        if names[:len(old_names)] != old_names or len(names) < len(old_names):
            raise ValueError('Retained anatomical morph identities changed')
        check = copy.deepcopy(after)
        if len(names) > len(old_names):
            if len(after['primitives']) != len(before['primitives']):
                raise ValueError('Retained primitive count changed')
            if after.get('weights') != before.get('weights', [0.0]*len(old_names)) + [0.0]*(len(names)-len(old_names)):
                raise ValueError('Added anatomical morph neutral weights changed')
            for old, new, cleaned in zip(before['primitives'], after['primitives'], check['primitives']):
                targets = new.get('targets', [])
                if len(targets) != len(names) or targets[:len(old_names)] != old.get('targets', []):
                    raise ValueError('Retained morph target accessors changed')
                vertex_count = original['accessors'][old['attributes']['POSITION']]['count']
                for target in targets[len(old_names):]:
                    for semantic, index in target.items():
                        item = candidate['accessors'][index]
                        if semantic not in ('POSITION', 'NORMAL', 'TANGENT') or item['type'] != 'VEC3' or item['componentType'] != 5126 or item['count'] != vertex_count:
                            raise ValueError('Added anatomical morph does not bind actual retained vertices')
                        values(candidate, candidate_binary, index)
                if 'targets' in old:
                    cleaned['targets'] = copy.deepcopy(old['targets'])
                else:
                    cleaned.pop('targets', None)
            if 'weights' in before:
                check['weights'] = before['weights']
            else:
                check.pop('weights', None)
            if 'targetNames' in before.get('extras', {}):
                check['extras']['targetNames'] = old_names
            else:
                check['extras'].pop('targetNames', None)
                if not check['extras'] and 'extras' not in before:
                    check.pop('extras')
            added.extend(names[len(old_names):])
        if check != before:
            raise ValueError('Retained base primitive attributes/material assignments changed')
    return added


def _transfer_new_morphs(original, original_binary, exported, exported_binary, original_node, exported_node,
                         output, output_binary, morph_selections=None):
    old_mesh = original['meshes'][original_node['mesh']]
    authored_mesh = exported['meshes'][exported_node['mesh']]
    previous_names = old_mesh.get('extras', {}).get('targetNames', [])
    names = authored_mesh.get('extras', {}).get('targetNames', [])
    if names[:len(previous_names)] != previous_names or len(set(names)) != len(names):
        raise ValueError('Existing anatomical morph identities/order changed')
    if len(names) == len(previous_names):
        return []
    if not names:
        raise ValueError('New morph targets require explicit names')
    authored = []
    buckets = {}
    lineage_report = None
    lineage_ids = None
    corrected_normals = None
    lineage_present = any(VERTEX_ATTRIBUTE in p['attributes'] or NORMAL_ATTRIBUTE in p['attributes']
                          for p in authored_mesh['primitives'])
    selections = [row for row in (morph_selections or []) if row['mesh']==original_node['name']]
    if lineage_present or selections:
        if previous_names or len(old_mesh['primitives'])!=1 or len(authored_mesh['primitives'])!=1:
            raise ValueError('Explicit anatomical lineage currently requires one new-target primitive')
        if len(selections)!=len(names) or len({row['shape_key'] for row in selections})!=len(names):
            raise ValueError('Explicit independent anatomical selection receipt required')
        old_primitive,new_primitive=old_mesh['primitives'][0],authored_mesh['primitives'][0]
        lineage_ids,corrected_normals,lineage_report=verify_export(old_primitive,new_primitive,
            lambda index:values(original,original_binary,index),
            lambda index:values(exported,exported_binary,index),
            _skin_rows(original,original_binary,original_node,old_primitive),
            _skin_rows(exported,exported_binary,exported_node,new_primitive),
            {row['shape_key']:set(row['vertices']) for row in selections},names)
    for primitive in authored_mesh['primitives']:
        if primitive.get('mode', 4) != 4 or len(primitive.get('targets', [])) != len(names):
            raise ValueError('Authored morphs require complete triangle-mesh targets')
        attributes = {key: values(exported, exported_binary, index)
                      for key, index in primitive['attributes'].items() if key in ('POSITION', 'NORMAL') or key.startswith('TEXCOORD_')}
        skin = _skin_rows(exported, exported_binary, exported_node, primitive)
        morphs = [{key: values(exported, exported_binary, index) for key, index in target.items()}
                  for target in primitive['targets'][len(previous_names):]]
        if lineage_report:
            attributes['NORMAL']=values(exported,exported_binary,primitive['attributes'][NORMAL_ATTRIBUTE])
            for fields,normal in zip(morphs,corrected_normals):
                if normal is not None:
                    fields['NORMAL']=normal
        for index, point in enumerate(attributes['POSITION']):
            row = (attributes, skin[index], morphs, index, int(lineage_ids[index]) if lineage_report else None)
            record = len(authored)
            authored.append(row)
            cell = tuple(np.rint(point/EPSILON).astype(np.int64))
            buckets.setdefault(cell, []).append(record)
    output_mesh = output['meshes'][original_node['mesh']]
    reports = []
    for primitive_index, primitive in enumerate(old_mesh['primitives']):
        if primitive.get('mode', 4) != 4:
            raise ValueError('Retained morph source is not a triangle mesh')
        attributes = {key: values(original, original_binary, index)
                      for key, index in primitive['attributes'].items() if key in ('POSITION', 'NORMAL') or key.startswith('TEXCOORD_')}
        skin = _skin_rows(original, original_binary, original_node, primitive)
        transferred = [dict() for _ in names[len(previous_names):]]
        for vertex, point in enumerate(attributes['POSITION']):
            cell = tuple(np.rint(point/EPSILON).astype(np.int64))
            options = []
            for delta in itertools.product((-1, 0, 1), repeat=3):
                options.extend(buckets.get(tuple(c+d for c, d in zip(cell, delta)), []))
            matches = []
            for option in options:
                candidate_attributes, candidate_skin, morphs, index, source_vertex = authored[option]
                if source_vertex is not None and source_vertex!=vertex:
                    continue
                # Position/normal/UV/skin identify the actual source surface.
                # Colour sets and tangents are retained directly from the
                # original, even when Blender omits an inactive colour set.
                if any((key not in candidate_attributes or
                       np.max(np.abs(data[vertex]-candidate_attributes[key][index])) > EPSILON)
                       for key, data in attributes.items()):
                    continue
                if _same_skin(skin[vertex], candidate_skin):
                    matches.append((morphs, index))
            if not matches:
                raise ValueError('Authored morph cannot map to the actual retained vertex/UV/skin: ' + str(vertex))
            first, first_index = matches[0]
            for other, other_index in matches[1:]:
                if any(set(a) != set(b) or any(np.max(np.abs(a[key][first_index]-b[key][other_index])) > EPSILON
                       for key in a) for a, b in zip(first, other)):
                    raise ValueError('Ambiguous retained vertex has different authored morph deltas')
            for target, fields in zip(transferred, first):
                for semantic, data in fields.items():
                    if semantic not in ('POSITION', 'NORMAL', 'TANGENT') or data.shape[1] != 3:
                        raise ValueError('Unsupported anatomical morph semantic')
                    target.setdefault(semantic, []).append(data[first_index])
        destination = output_mesh['primitives'][primitive_index]
        if len(destination.get('targets', [])) != len(previous_names):
            raise ValueError('Retained morph names do not match actual targets')
        destination.setdefault('targets', [])
        for fields in transferred:
            destination['targets'].append({key: _append_array(output, output_binary, data, 'VEC3')
                                           for key, data in fields.items()})
        reports.append({'primitive': primitive_index, 'vertices': len(attributes['POSITION']),
                        'new_targets': names[len(previous_names):], 'vertex_uv_normal_skin_mapping_verified': True,
                        **({'explicit_lineage':lineage_report} if lineage_report else {})})
    output_mesh.setdefault('extras', {})['targetNames'] = names
    output_mesh['weights'] = old_mesh.get('weights', [0.0]*len(previous_names)) + [0.0]*(len(names)-len(previous_names))
    if 'weights' in original_node:
        raise ValueError('Node-level retained weights need an explicit morph migration')
    return reports


def graft(original_path, exported_path, destination, morph_selections=None):
    original, original_binary = read_glb(original_path)
    exported, exported_binary = read_glb(exported_path)
    output, output_binary = copy.deepcopy(original), bytearray(original_binary)
    original_parents = {child: parent for parent, node in enumerate(original['nodes']) for child in node.get('children', [])}
    exported_parents = {child: parent for parent, node in enumerate(exported['nodes']) for child in node.get('children', [])}
    names = {}
    for index, node in enumerate(original['nodes']):
        names.setdefault(node.get('name', ''), []).append(index)
    mapped, active = {}, set()
    maximum_rest_error = 0.0

    def map_node(index):
        nonlocal maximum_rest_error
        if index in mapped:
            return mapped[index]
        if index in active:
            raise ValueError('Cyclic authored node hierarchy')
        active.add(index)
        node = exported['nodes'][index]
        options = names.get(node.get('name', ''), [])
        if len(options) != 1:
            raise ValueError('Authored target identity missing or ambiguous: ' + node.get('name', ''))
        target = options[0]
        error = float(np.max(np.abs(matrix(node)-matrix(original['nodes'][target]))))
        if not np.isfinite(error) or error > EPSILON:
            raise ValueError('Authored curves cannot cross changed retained rest bases: ' + node.get('name', ''))
        maximum_rest_error = max(maximum_rest_error, error)
        before, after = original_parents.get(target), exported_parents.get(index)
        if (before is None) != (after is None) or (after is not None and map_node(after) != before):
            raise ValueError('Authored target parent changed')
        active.remove(index)
        mapped[index] = target
        return target

    copies = {}
    def copy_accessor(index):
        if index in copies:
            return copies[index]
        item = copy.deepcopy(exported['accessors'][index])
        if item['componentType'] != 5126 or item.get('normalized', False):
            raise ValueError('Authored animation samples must be finite float32 values')
        values(exported, exported_binary, index)
        payload = accessor_bytes(exported, exported_binary, index)
        output_binary.extend(b'\0' * ((-len(output_binary)) % 4))
        view = len(output['bufferViews'])
        output['bufferViews'].append({'buffer': 0, 'byteOffset': len(output_binary), 'byteLength': len(payload)})
        output_binary.extend(payload)
        item.pop('byteOffset', None)
        item['bufferView'] = view
        copies[index] = len(output['accessors'])
        output['accessors'].append(item)
        return copies[index]

    previous = {clip['name']: clip for clip in original['animations']}
    authored = {clip['name']: clip for clip in exported['animations']}
    if len(previous) != len(original['animations']) or len(authored) != len(exported['animations']) or set(previous) != set(authored):
        raise ValueError('Original/authored clip identities differ or are ambiguous')
    transferred_meshes, morph_reports = set(), []
    for clip in REPLACED_CLIPS:
        animation = copy.deepcopy(authored[clip])
        for channel in animation['channels']:
            old_target = channel['target']['node']
            target = map_node(old_target)
            channel['target']['node'] = target
            if channel['target']['path'] == 'weights':
                old_node, new_node = original['nodes'][target], exported['nodes'][old_target]
                if 'mesh' not in old_node or 'mesh' not in new_node:
                    raise ValueError('Morph curve does not target a retained mesh')
                identity = old_node['mesh']
                if identity not in transferred_meshes:
                    morph_reports.extend(_transfer_new_morphs(original, original_binary, exported, exported_binary,
                                                              old_node, new_node, output, output_binary, morph_selections))
                    transferred_meshes.add(identity)
        for sampler in animation['samplers']:
            for key in ('input', 'output'):
                sampler[key] = copy_accessor(sampler[key])
        previous[clip] = animation
    output['animations'] = [previous[clip['name']] for clip in original['animations']]
    write_glb(destination, output, bytes(output_binary))
    checked, checked_binary = read_glb(destination)
    signatures = {}
    for before, after in zip(original['animations'], checked['animations']):
        if before['name'] not in REPLACED_CLIPS:
            expected = action_digest(original, original_binary, before)
            if action_digest(checked, checked_binary, after) != expected:
                raise ValueError('Protected native action changed during ambient graft')
            signatures[before['name']] = expected
    verify_retained_base(original, original_binary, checked, checked_binary)
    return {'retained_base_buffer_sha256': hashlib.sha256(original_binary).hexdigest(),
            'retained_base_bytes_equal': True, 'retained_materials_skin_hierarchy_equal': True,
            'protected_action_bytes_equal': True, 'protected_action_byte_signatures': signatures,
            'maximum_target_rest_error': maximum_rest_error, 'new_morph_mapping': morph_reports,
            'appended_ambient_buffer_bytes': len(output_binary)-len(original_binary)}
