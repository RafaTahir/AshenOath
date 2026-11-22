extends RefCounted

## Small shared joinery mesh. Its six supporting planes retain the BoxMesh
## bounds, so fittings, animated pivots and existing collision stay authoritative.
## Forty-four triangles replace twelve; no extra surfaces or material variants.
static var _unit: ArrayMesh
static var _sizes: Dictionary = {}
static var _materials: Dictionary = {}

static func material(color: Color, surface: String = "timber", baseline: StandardMaterial3D = null) -> StandardMaterial3D:
	# Retain the construction owner's interior visibility lift and other flags.
	# Only the surface response changes; shared source materials stay immutable.
	var key := "%s:%s:%s" % [surface, color.to_html(), str(baseline.get_instance_id()) if baseline != null else "neutral"]
	if _materials.has(key):
		return _materials[key]
	var result: StandardMaterial3D = baseline.duplicate() as StandardMaterial3D if baseline != null else StandardMaterial3D.new()
	result.resource_name = "Joinery_%s_%s" % [surface, color.to_html()]
	result.albedo_color = color
	result.roughness = 0.94 if surface == "cloth" else (0.42 if surface == "iron" else 0.84)
	result.metallic = 0.72 if surface == "iron" else 0.0
	_materials[key] = result
	return result

static func box(size: Vector3 = Vector3.ONE) -> ArrayMesh:
	if size == Vector3.ONE and _unit != null:
		return _unit
	var key := str(size)
	if _sizes.has(key):
		return _sizes[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	const HALF := 0.5
	const INSET := 0.465
	# Face panels.
	for axis in range(3):
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for sign_value in [-1.0, 1.0]:
			var points: Array[Vector3] = []
			for pair in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
				var point := Vector3.ZERO
				point[axis] = HALF * sign_value
				point[u] = INSET * pair.x
				point[v] = INSET * pair.y
				points.append(point * size)
			var normal := Vector3.ZERO
			normal[axis] = sign_value
			_quad(tool, points, normal)
	# Twelve narrow edge planes.
	for along in range(3):
		var a := (along + 1) % 3
		var b := (along + 2) % 3
		for sa in [-1.0, 1.0]:
			for sb in [-1.0, 1.0]:
				var points: Array[Vector3] = []
				for endpoint in [-1.0, 1.0]:
					for side in [0, 1]:
						var point := Vector3.ZERO
						point[along] = INSET * endpoint
						point[a] = (HALF if side == 0 else INSET) * sa
						point[b] = (INSET if side == 0 else HALF) * sb
						points.append(point * size)
				var normal := Vector3.ZERO
				normal[a] = sa / maxf(size[a], 0.0001)
				normal[b] = sb / maxf(size[b], 0.0001)
				_quad(tool, [points[0], points[1], points[3], points[2]], normal.normalized())
	# Eight clipped corners close the mesh.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var signs := Vector3(sx,sy,sz)
				var points: Array[Vector3] = []
				for axis in range(3):
					var point := Vector3.ONE * INSET
					point[axis] = HALF
					points.append(point * signs * size)
				_triangle(tool, points[0], points[1], points[2], (signs / size).normalized())
	var mesh := tool.commit()
	mesh.resource_name = "ChamferedJoinery_%s" % key
	_sizes[key] = mesh
	if size == Vector3.ONE:
		_unit = mesh
	return mesh

static func _quad(tool: SurfaceTool, points: Array, normal: Vector3) -> void:
	_triangle(tool, points[0], points[1], points[2], normal)
	_triangle(tool, points[0], points[2], points[3], normal)

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	# Godot fronts are clockwise. Keep outward normals on all signed octants.
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var swap := b
		b = c
		c = swap
	for point: Vector3 in [a,b,c]:
		tool.set_normal(normal)
		tool.set_uv(Vector2(point.x, point.z) if absf(normal.y) > 0.5 else Vector2(point.x if absf(normal.z) > 0.5 else point.z, -point.y))
		tool.add_vertex(point)
