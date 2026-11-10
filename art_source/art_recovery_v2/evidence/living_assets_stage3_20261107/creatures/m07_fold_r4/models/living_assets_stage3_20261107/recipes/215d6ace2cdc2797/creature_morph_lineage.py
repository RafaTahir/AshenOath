"""Exact retained vertex lineage for newly authored anatomical shape keys.

Blender stores/recomputes split normals and rounds exported normals. A raw
FLOAT_VECTOR attribute carries the retained normal independently. It is not
trusted until every source vertex and ordered triangle corner, UV and named
skin binding has been checked. Existing base buffers are never rewritten.
"""
import numpy as np

VERTEX_ATTRIBUTE = '_AO_RETAINED_VERTEX'
NORMAL_ATTRIBUTE = '_AO_RETAINED_NORMAL'
EPSILON = 1e-5


def bind_source_mesh_nodes(document, imported_names):
    """Require a bijection with named retained mesh nodes, never helper names.

    The importer is configured not to create bone-display geometry. Any extra
    mesh is therefore an error, even if its name resembles a known UI helper.
    """
    names=list(imported_names)
    if len(set(names))!=len(names) or any(not isinstance(name,str) or not name for name in names):
        raise ValueError('Imported anatomical mesh identity is missing or duplicated')
    expected={}
    meshes=document.get('meshes',[])
    for node in document.get('nodes',[]):
        if 'mesh' not in node:
            continue
        name=node.get('name')
        index=node['mesh']
        if not isinstance(name,str) or not name or name in expected:
            raise ValueError('Retained anatomical mesh identity is missing or duplicated')
        if not isinstance(index,int) or isinstance(index,bool) or not 0<=index<len(meshes):
            raise ValueError('Retained anatomical mesh index is invalid')
        expected[name]=node
    if not expected or set(expected)!=set(names):
        missing=sorted(set(expected)-set(names));unexpected=sorted(set(names)-set(expected))
        raise ValueError('Anatomical source/import mesh identity mismatch; missing='+repr(missing)+'; unexpected='+repr(unexpected))
    return expected


def checked_indices(primitive, count, read_values):
    if primitive.get('mode', 4) != 4:
        raise ValueError('Anatomical lineage requires triangle geometry')
    indices = (read_values(primitive['indices']).reshape(-1)
               if 'indices' in primitive else np.arange(count))
    if len(indices) % 3 or not np.isfinite(indices).all():
        raise ValueError('Invalid anatomical triangle indices')
    integer = indices.astype(np.int64)
    if not np.array_equal(integer, indices) or np.any(integer < 0) or np.any(integer >= count):
        raise ValueError('Anatomical triangle index outside actual vertices')
    return integer


def verify_import(source, source_indices, positions, indices, uvs, skin, source_skin):
    """Validate the unmerged Blender mesh before assigning source identities."""
    expected = source['POSITION'][:, [0, 2, 1]].copy()
    expected[:, 1] *= -1
    positions = np.asarray(positions)
    if positions.shape != expected.shape or not np.isfinite(positions).all():
        raise ValueError('Imported anatomical vertex count/coordinates changed')
    error = float(np.max(np.abs(positions - expected)))
    if error > EPSILON or not np.array_equal(indices, source_indices):
        raise ValueError('Imported anatomical vertex order or ordered corners changed')
    for key, original in source.items():
        if not key.startswith('TEXCOORD_'):
            continue
        expected_uv = original[source_indices].copy()
        expected_uv[:, 1] = 1 - expected_uv[:, 1]
        actual = np.asarray(uvs.get(key, []))
        if actual.shape != expected_uv.shape or not np.isfinite(actual).all() or np.max(abs(actual-expected_uv)) > EPSILON:
            raise ValueError('Imported anatomical corner UVs changed: '+key)
    if len(skin) != len(source_skin):
        raise ValueError('Imported anatomical skin count changed')
    for old, new in zip(source_skin, skin):
        if len(old) != len(new) or any(a != b or abs(x-y) > EPSILON for (a,x),(b,y) in zip(old,new)):
            raise ValueError('Imported anatomical named skin binding changed')
    return {'vertices':len(positions), 'ordered_corners':len(indices), 'position_error':error}


def independent_shape(basis, selected, matrix_world, kind):
    """Each control starts from one frozen neutral mesh, never the active key."""
    basis = np.asarray(basis, dtype=np.float64)
    transform = np.asarray(matrix_world, dtype=np.float64)
    if basis.ndim != 2 or basis.shape[1] != 3 or transform.shape != (4,4) or not np.isfinite(basis).all() or not np.isfinite(transform).all():
        raise ValueError('Invalid frozen anatomical Basis')
    indices = np.asarray(selected, dtype=np.int64)
    if len(indices) < 20 or len(set(indices.tolist())) != len(indices) or np.any(indices<0) or np.any(indices>=len(basis)):
        raise ValueError('Incomplete or ambiguous anatomical selection')
    if kind not in ('AntennaProbe_L','AntennaProbe_R','BrushFeed_L','BrushFeed_R'):
        raise ValueError('Unknown anatomical control')
    result = basis.copy()
    inverse = np.linalg.inv(transform)
    for index in indices:
        point = transform @ np.append(basis[index], 1)
        sign = -1 if point[0] < 0 else 1
        if (kind.endswith('_L') and sign != -1) or (kind.endswith('_R') and sign != 1):
            raise ValueError('Anatomical selection crosses the retained body side')
        if kind.startswith('Antenna'):
            t = min(1.0, max(0.0, (-point[1]-.29)/.48))
            point[0] += sign*.035*t*t
            point[2] += .018*np.sin(np.pi*t)*t
        else:
            t = min(1.0, max(0.0, (-point[1]-.31)/.11))
            point[0] += sign*.008*t
            point[2] += .012*t*t
        result[index] = (inverse @ point)[:3]
    outside = np.ones(len(basis), dtype=bool); outside[indices] = False
    if not np.array_equal(result[outside], basis[outside]):
        raise ValueError('Anatomical control changed unselected Basis vertices')
    return result


def rebase_normal_deltas(retained, exported_base, exported_delta):
    """Apply the authored relative normal rotation to the exact retained normal.

    Replacing the base with an exported normal would lose the retained surface;
    adding the base-normal difference to every delta would make untouched
    vertices move when a key is enabled. Exact zero deltas stay exact zero.
    """
    retained, base, delta = (np.asarray(v,dtype=np.float64) for v in (retained,exported_base,exported_delta))
    if retained.shape != base.shape or base.shape != delta.shape or base.ndim != 2 or base.shape[1] != 3:
        raise ValueError('Invalid anatomical normal arrays')
    if not all(np.isfinite(v).all() for v in (retained,base,delta)):
        raise ValueError('Nonfinite anatomical normals')
    answer = np.zeros_like(delta)
    for index in np.flatnonzero(np.any(delta != 0,axis=1)):
        first, last = base[index], base[index]+delta[index]
        lengths = (np.linalg.norm(first),np.linalg.norm(last),np.linalg.norm(retained[index]))
        if min(lengths) <= 1e-8:
            raise ValueError('Zero anatomical normal cannot define relative rotation')
        first, last = first/lengths[0], last/lengths[1]
        cross = np.cross(first,last); cosine=float(np.clip(np.dot(first,last),-1,1))
        if 1+cosine <= 1e-8:
            raise ValueError('Ambiguous half-turn anatomical normal rotation')
        vector=retained[index]
        answer[index] = np.cross(cross,vector)+np.cross(cross,np.cross(cross,vector))/(1+cosine)
    return answer.astype('<f4')


def verify_export(original_primitive, exported_primitive, original_values, exported_values,
                  original_skin, exported_skin, selections, names):
    """Return source IDs and corrected relative normals only after full proof."""
    old = {key:original_values(index) for key,index in original_primitive['attributes'].items()
           if key in ('POSITION','NORMAL') or key.startswith('TEXCOORD_')}
    attrs = exported_primitive['attributes']
    if VERTEX_ATTRIBUTE not in attrs or NORMAL_ATTRIBUTE not in attrs:
        raise ValueError('Complete anatomical raw-normal/vertex lineage required')
    for key,data in old.items():
        if not np.isfinite(data).all():
            raise ValueError('Nonfinite retained anatomical channel: '+key)
    for key,index in attrs.items():
        if key in ('POSITION','NORMAL',VERTEX_ATTRIBUTE,NORMAL_ATTRIBUTE) or key.startswith('TEXCOORD_'):
            if not np.isfinite(exported_values(index)).all():
                raise ValueError('Nonfinite exported anatomical channel: '+key)
    for rows in (original_skin,exported_skin):
        if any(not np.isfinite(weight) or weight<0 for row in rows for _,weight in row):
            raise ValueError('Nonfinite or negative anatomical skin weight')
    count=len(exported_values(attrs['POSITION']))
    raw_ids=exported_values(attrs[VERTEX_ATTRIBUTE]).reshape(-1)
    ids=raw_ids.astype(np.int64)
    if len(ids)!=count or not np.array_equal(raw_ids,ids) or np.any(ids<0) or np.any(ids>=len(old['POSITION'])) or set(ids)!=set(range(len(old['POSITION']))):
        raise ValueError('Invalid or incomplete anatomical source vertex lineage')
    old_indices=checked_indices(original_primitive,len(old['POSITION']),original_values)
    new_indices=checked_indices(exported_primitive,count,exported_values)
    if not np.array_equal(old_indices,ids[new_indices]):
        raise ValueError('Anatomical ordered triangle corner lineage changed')
    for key, data in old.items():
        attribute=NORMAL_ATTRIBUTE if key=='NORMAL' else key
        if attribute not in attrs:
            raise ValueError('Missing anatomical source channel: '+key)
        actual=exported_values(attrs[attribute])
        if actual.shape!=data[ids].shape or np.max(np.abs(actual-data[ids]))>EPSILON:
            raise ValueError('Anatomical lineage channel changed: '+key)
    for old_skin,new_skin in zip((original_skin[i] for i in ids),exported_skin):
        if len(old_skin)!=len(new_skin) or any(a!=b or abs(x-y)>EPSILON for (a,x),(b,y) in zip(old_skin,new_skin)):
            raise ValueError('Anatomical lineage named skin changed')
    if len(exported_skin)!=count or set(selections)!=set(names):
        raise ValueError('Anatomical lineage skin/selection coverage changed')
    used=set()
    for name in names:
        selected=set(selections[name])
        if len(selected)<20 or used.intersection(selected) or not selected.issubset(set(range(len(old['POSITION'])))):
            raise ValueError('Anatomical selections overlap or are incomplete')
        used.update(selected)
    if len(exported_primitive.get('targets',[]))!=len(names):
        raise ValueError('Anatomical target count differs from the declared controls')
    corrected=[]
    neutral_roundoff={}
    for name,target in zip(names,exported_primitive['targets']):
        if 'POSITION' not in target or any(key not in ('POSITION','NORMAL') for key in target):
            raise ValueError('Unsupported new anatomical target channels')
        delta=exported_values(target['POSITION'])
        outside=np.asarray([int(i) not in selections[name] for i in ids])
        if not np.isfinite(delta).all():
            raise ValueError('Nonfinite anatomical POSITION morph: '+name)
        if delta.shape!=(count,3) or np.any(delta[outside]!=0):
            raise ValueError('Anatomical target moves vertices outside its independent selection: '+name)
        limit=.045 if name.startswith('Antenna') else .015
        if np.max(np.linalg.norm(delta,axis=1))>limit:
            raise ValueError('Anatomical target exceeds authored displacement: '+name)
        normals=None
        if 'NORMAL' in target:
            normal_delta=exported_values(target['NORMAL'])
            if not np.isfinite(normal_delta).all():
                raise ValueError('Nonfinite anatomical NORMAL morph: '+name)
            moving=set(ids[np.any(delta!=0,axis=1)].tolist())
            neighbors=set()
            for triangle in old_indices.reshape(-1,3):
                if any(int(i) in moving for i in triangle):neighbors.update(int(i) for i in triangle)
            unaffected=np.asarray([int(i) not in neighbors for i in ids])
            if normal_delta.shape!=(count,3):
                raise ValueError('Anatomical normal delta count changed')
            roundoff=float(np.max(np.abs(normal_delta[unaffected]))) if np.any(unaffected) else 0.0
            if roundoff>EPSILON:
                raise ValueError('Anatomical normal delta changes an unaffected surface: '+name)
            # These exact source triangles have no moved vertices. Blender's
            # repeated F32 normalization can leave tiny nonzero deltas here;
            # require the unchanged normal gate and restore exact neutrality.
            # A substantive remote normal change still fails, never widens it.
            neutral_roundoff[name]=roundoff
            normal_delta=normal_delta.copy()
            normal_delta[unaffected]=0
            normals=rebase_normal_deltas(old['NORMAL'][ids],exported_values(attrs['NORMAL']),normal_delta)
        corrected.append(normals)
    return ids,corrected,{'source_vertices':len(old['POSITION']),'exported_vertices':count,
        'ordered_triangle_corners':len(old_indices),'raw_normal_lineage_verified':True,
        'independent_position_support_verified':True,'normal_rebase':'relative_rotation_about_exact_retained_normal; exact_zero_preserved',
        'verified_unchanged_surface_normal_roundoff_removed':neutral_roundoff}
