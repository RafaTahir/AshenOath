extends RefCounted

## Build-only triangle multiset comparison. Whole triangles keep their corner
## attributes and winding together; repeated faces must match repeated faces.
const POSITION_EPS := 0.0001
const ATTRIBUTE_EPS := 0.0002
const CELL := 0.001

static func triangles(mesh: ArrayMesh, frame: Transform3D, roles: Dictionary = {}) -> Dictionary:
	var result: Array[Dictionary] = []
	if mesh == null or not frame.is_finite() or absf(frame.basis.determinant()) < 0.00000001:
		return {"error":"invalid mesh frame", "rows":result}
	for surface: int in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			return {"error":"non-triangle surface", "rows":result}
		if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array or not arrays[Mesh.ARRAY_COLOR] is PackedColorArray or not arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array:
			return {"error":"missing vertex/normal/palette/UV channel", "rows":result}
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		if vertices.size() != normals.size() or vertices.size() != colors.size() or vertices.size() != uv.size():
			return {"error":"attribute channel size mismatch", "rows":result}
		var indices: PackedInt32Array = []
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: indices = arrays[Mesh.ARRAY_INDEX]
		var count := vertices.size() if indices.is_empty() else indices.size()
		if count == 0 or count % 3 != 0: return {"error":"incomplete triangles", "rows":result}
		var role := str(roles.get(surface, mesh.surface_get_name(surface)))
		if role.is_empty(): return {"error":"missing semantic material role", "rows":result}
		for start: int in range(0, count, 3):
			var row := {"role":role, "v":[], "n":[], "c":[], "u":[]}
			for corner: int in range(3):
				var index := start + corner if indices.is_empty() else indices[start + corner]
				if index < 0 or index >= vertices.size(): return {"error":"invalid triangle index", "rows":result}
				var color := colors[index]
				if not vertices[index].is_finite() or not normals[index].is_finite() or not uv[index].is_finite() or not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a):
					return {"error":"nonfinite triangle attribute", "rows":result}
				row.v.append(frame * vertices[index])
				row.n.append((frame.basis.inverse().transposed() * normals[index]).normalized())
				row.c.append(color)
				row.u.append(uv[index])
			result.append(row)
	return {"error":"", "rows":result}

static func _cell(row: Dictionary) -> Vector3i:
	var centre: Vector3 = (row.v[0] + row.v[1] + row.v[2]) / 3.0
	return Vector3i(floori(centre.x / CELL), floori(centre.y / CELL), floori(centre.z / CELL))

static func _key(role: String, cell: Vector3i) -> String:
	return role + ":%d,%d,%d" % [cell.x, cell.y, cell.z]

static func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.role != b.role: return false
	for rotation: int in range(3):
		var matched := true
		for index: int in range(3):
			var other := (index + rotation) % 3
			var ac: Color = a.c[index]
			var bc: Color = b.c[other]
			if (a.v[index] as Vector3).distance_to(b.v[other]) > POSITION_EPS or (a.n[index] as Vector3).distance_to(b.n[other]) > ATTRIBUTE_EPS or (a.u[index] as Vector2).distance_to(b.u[other]) > ATTRIBUTE_EPS or absf(ac.r-bc.r)>ATTRIBUTE_EPS or absf(ac.g-bc.g)>ATTRIBUTE_EPS or absf(ac.b-bc.b)>ATTRIBUTE_EPS or absf(ac.a-bc.a)>ATTRIBUTE_EPS:
				matched = false
				break
		if matched: return true
	return false

static func compare(original: Array, rebuilt: Array) -> Dictionary:
	if original.size() != rebuilt.size():
		return {"passed":false, "error":"triangle multiplicity changed", "original":original.size(), "rebuilt":rebuilt.size()}
	var buckets: Dictionary = {}
	for index: int in range(rebuilt.size()):
		var key := _key(str(rebuilt[index].role), _cell(rebuilt[index]))
		if not buckets.has(key): buckets[key] = []
		buckets[key].append(index)
	for row: Dictionary in original:
		var cell := _cell(row)
		var found := false
		for x: int in range(-1, 2):
			if found: break
			for y: int in range(-1, 2):
				if found: break
				for z: int in range(-1, 2):
					var key := _key(str(row.role), cell + Vector3i(x,y,z))
					var candidates: Array = buckets.get(key, [])
					for offset: int in range(candidates.size()):
						if _same(row, rebuilt[candidates[offset]]):
							candidates.remove_at(offset)
							found = true
							break
					if found: break
		if not found:
			return {"passed":false, "error":"unmatched winding/position/normal/palette/UV/material-role triangle", "role":row.role, "point":row.v[0]}
	return {"passed":true, "triangles":original.size(), "position_tolerance":POSITION_EPS, "attribute_tolerance":ATTRIBUTE_EPS}

static func bounds(rows: Array) -> AABB:
	if rows.is_empty(): return AABB()
	var result := AABB(rows[0].v[0], Vector3.ZERO)
	for row: Dictionary in rows:
		for point: Vector3 in row.v: result = result.expand(point)
	return result
