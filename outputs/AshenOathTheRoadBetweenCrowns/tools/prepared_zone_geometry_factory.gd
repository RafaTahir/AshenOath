extends RefCounted

## Pure asset-compilation routines shared with the retained source geometry.
const BridgeSurfaceContract = preload("res://scripts/bridge_surface_contract.gd")

static func greyfen_ground(specs: Array) -> ArrayMesh:
	var combined := SurfaceTool.new()
	combined.begin(Mesh.PRIMITIVE_TRIANGLES)
	for spec in specs:
		var ground_name: String = spec.name
		var origin: Vector3 = spec.origin
		var half_size: Vector3 = spec.size * 0.5
		var top: float = origin.y + half_size.y
		var columns := maxi(2, ceili(half_size.x * 2.0 / 1.5))
		var rows := maxi(2, ceili(half_size.z * 2.0 / 1.5))
		for row in range(rows):
			var z0 := lerpf(origin.z - half_size.z, origin.z + half_size.z, float(row) / float(rows))
			var z1 := lerpf(origin.z - half_size.z, origin.z + half_size.z, float(row + 1) / float(rows))
			# Crop only the visual ground. Its unchanged collision still owns the bank.
			if ground_name in ["GroundNorthWest", "GroundNorthEast"]:
				z1 = minf(z1, 4.5 - 2.02)
			elif ground_name in ["GroundSouthWest", "GroundSouthEast"]:
				z0 = maxf(z0, 4.5 + 2.02)
			if z1 <= z0:
				continue
			for column in range(columns):
				var x0 := lerpf(origin.x - half_size.x, origin.x + half_size.x, float(column) / float(columns))
				var x1 := lerpf(origin.x - half_size.x, origin.x + half_size.x, float(column + 1) / float(columns))
				for point in [Vector3(x0, top, z0), Vector3(x1, top, z0), Vector3(x0, top, z1), Vector3(x1, top, z0), Vector3(x1, top, z1), Vector3(x0, top, z1)]:
					combined.set_normal(Vector3.UP)
					combined.set_uv(Vector2(point.x, point.z))
					combined.set_color(_greyfen_ground_tint(point))
					combined.add_vertex(point)
	_append_greyfen_river_banks(combined)
	return combined.commit()

static func _append_greyfen_river_banks(surface: SurfaceTool) -> void:
	var bridge_half := BridgeSurfaceContract.HALF_WIDTH
	var river: Node3D = load("res://scripts/zones/river_section.gd").new()
	for bank_side in [-1.0, 1.0]:
		var land_z: float = 4.5 + bank_side * 2.02
		for section in [[-21.0, -bridge_half + 0.08], [bridge_half - 0.08, 21.0]]:
			var segments := maxi(12, ceili((float(section[1]) - float(section[0])) / 0.85))
			for index in range(segments):
				var x0 := lerpf(float(section[0]), float(section[1]), float(index) / float(segments))
				var x1 := lerpf(float(section[0]), float(section[1]), float(index + 1) / float(segments))
				var a := Vector3(x0, 0.006, land_z)
				var b := Vector3(x1, 0.006, land_z)
				var edge0: float = river._water_channel_vertex(x0 / 42.0 + 0.5, 0.0 if bank_side < 0 else 1.0, 42.0, 3.4).z + 4.5
				var edge1: float = river._water_channel_vertex(x1 / 42.0 + 0.5, 0.0 if bank_side < 0 else 1.0, 42.0, 3.4).z + 4.5
				# The lower edge stays under the lowest animated wave, not above it.
				var c := Vector3(x0, -0.30, edge0 - bank_side * 0.06)
				var d := Vector3(x1, -0.30, edge1 - bank_side * 0.06)
				var triangles := [a, b, c, b, d, c] if bank_side < 0.0 else [a, c, b, b, c, d]
				for point in triangles:
					var shore_weight := clampf((0.006 - point.y) / 0.306, 0.0, 1.0)
					var tint := _greyfen_ground_tint(point).lerp(Color(0.29, 0.41, 0.35), shore_weight)
					surface.set_normal(Vector3.UP)
					surface.set_uv(Vector2(point.x, point.z))
					surface.set_color(tint)
					surface.add_vertex(point)
	river.free()

static func _greyfen_ground_tint(point: Vector3) -> Color:
	var tint := Color(0.42, 0.62, 0.40)
	for region in [
		[Vector2(-9.5, -4.0), Vector2(6.5, 5.0), Color(0.51, 0.48, 0.35)],
		[Vector2(6.0, -7.0), Vector2(4.6, 3.5), Color(0.40, 0.57, 0.39)],
		[Vector2(9.5, 4.5), Vector2(4.5, 3.7), Color(0.49, 0.44, 0.34)],
		[Vector2(-5.4, 11.5), Vector2(3.4, 2.5), Color(0.52, 0.47, 0.35)],
		[Vector2(7.0, 10.3), Vector2(2.8, 2.4), Color(0.49, 0.46, 0.35)],
	]:
		var offset := Vector2((point.x - region[0].x) / region[1].x, (point.z - region[0].y) / region[1].y)
		tint = tint.lerp(region[2], 1.0 - smoothstep(0.60, 1.0, offset.length()))
	var roadside := 1.0 - smoothstep(0.25, 1.55, absf(absf(point.x) - 3.25))
	var span_weight := 0.0
	for span in [Vector2(-13.5, -2.0), Vector2(2.0, 6.7), Vector2(11.0, 14.0)]:
		span_weight = maxf(span_weight, smoothstep(0.0, 1.2, point.z - span.x) * smoothstep(0.0, 1.2, span.y - point.z))
	return tint.lerp(Color(0.45, 0.58, 0.36), roadside * span_weight * 0.75)

static func _make_greyfen_road_surface(size: Vector3, origin: Vector3) -> ArrayMesh:
	var along_z := size.z >= size.x
	var length := size.z if along_z else size.x
	var half_width := (size.x if along_z else size.z) * 0.5
	var rows := maxi(4, ceili(length / 0.9))
	var lateral := [-1.0, -0.65, 0.0, 0.65, 1.0]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(rows + 1):
		var forward := length * (float(row) / float(rows) - 0.5)
		var bend := sin(forward * 0.51 + origin.x * 0.17) * 0.08
		var shoulder := half_width - 0.13 + sin(forward * 1.37 + origin.z * 0.29) * 0.12
		for column in range(lateral.size()):
			var side := float(lateral[column])
			var across := bend + side * (shoulder if absf(side) > 0.9 else half_width)
			var point := Vector3(across, size.y * 0.5, forward) if along_z else Vector3(forward, size.y * 0.5, across)
			vertices.append(point)
			normals.append(Vector3.UP)
			uvs.append(Vector2(origin.x + point.x, origin.z + point.z))
			var edge_mix := 1.0 - smoothstep(0.62, 1.0, absf(side))
			colors.append(Color(0.54, 0.58, 0.49).lerp(Color.WHITE, edge_mix))
	for row in range(rows):
		for column in range(lateral.size() - 1):
			var a := row * lateral.size() + column
			var b := a + 1
			var c := a + lateral.size()
			var d := c + 1
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func mill_path(origin: Vector3, width: float, length: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(8):
		var z0 := -length / 2 + length * row / 8
		var z1 := -length / 2 + length * (row + 1) / 8
		var x0 := width / 2 + sin(z0 * 1.1) * 0.15
		var x1 := width / 2 + sin(z1 * 1.1) * 0.15
		for side in [-1.0, 1.0]:
			var a := Vector3(0, 0, z0)
			var b := Vector3(side * x0, 0, z0)
			var c := Vector3(side * x1, 0, z1)
			var d := Vector3(0, 0, z1)
			var faces := [a, b, c, a, c, d] if side > 0 else [a, c, b, a, d, c]
			for point in faces:
				surface.set_normal(Vector3.UP)
				surface.set_uv(Vector2(point.x + origin.x, point.z + origin.z))
				surface.set_color(Color(0.80, 0.78, 0.72) if is_zero_approx(point.x) else Color(0.53, 0.50, 0.42))
				surface.add_vertex(point)
	surface.index()
	return surface.commit()

static func mill_ridge() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(12):
		var x0 := -25.0 + segment * 50.0 / 12
		var x1 := -25.0 + (segment + 1) * 50.0 / 12
		var h0 := 2.2 + sin(x0 * 0.31) * 0.8 + cos(x0 * 0.53) * 0.4
		var h1 := 2.2 + sin(x1 * 0.31) * 0.8 + cos(x1 * 0.53) * 0.4
		for point in [Vector3(x0, -0.08, -16.5), Vector3(x1, h1, -21), Vector3(x1, -0.08, -16.5), Vector3(x0, -0.08, -16.5), Vector3(x0, h0, -21), Vector3(x1, h1, -21)]:
			surface.set_uv(Vector2(point.x, point.z))
			surface.add_vertex(point)
	surface.generate_normals()
	surface.index()
	return surface.commit()

static func ramp(height: float, width: float) -> ArrayMesh:
	var w := width * 0.5
	var points := PackedVector3Array([Vector3(-w, 0, 0.95), Vector3(w, 0, 0.95), Vector3(w, height, -0.95), Vector3(-w, height, -0.95), Vector3(-w, -0.06, 0.95), Vector3(w, -0.06, 0.95), Vector3(w, -0.06, -0.95), Vector3(-w, -0.06, -0.95)])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0, 1, 2, 0, 2, 3, 4, 7, 6, 4, 6, 5, 0, 4, 5, 0, 5, 1, 3, 2, 6, 3, 6, 7, 0, 3, 7, 0, 7, 4, 1, 5, 6, 1, 6, 2]:
		surface.set_uv(Vector2(points[index].x, points[index].z))
		surface.add_vertex(points[index])
	surface.generate_normals()
	return surface.commit()

static func record_vault() -> Dictionary:
	var ceiling_surface := SurfaceTool.new()
	ceiling_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall_surface := SurfaceTool.new()
	wall_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_width: float = 16.0
	var south: float = 18.0
	var north: float = -18.0
	for index in range(16):
		var x0 := lerpf(-half_width, half_width, float(index) / 16.0)
		var x1 := lerpf(-half_width, half_width, float(index + 1) / 16.0)
		var y0 := 5.55 + 1.65 * (1.0 - pow(x0 / half_width, 2.0))
		var y1 := 5.55 + 1.65 * (1.0 - pow(x1 / half_width, 2.0))
		_add_record_hall_triangle(ceiling_surface, Vector3(x0, y0, north), Vector3(x1, y1, north), Vector3(x0, y0, south))
		_add_record_hall_triangle(ceiling_surface, Vector3(x1, y1, north), Vector3(x1, y1, south), Vector3(x0, y0, south))
	for side in [-1.0, 1.0]:
		var x: float = float(side) * half_width
		var a := Vector3(x, 0.0, north)
		var b := Vector3(x, 5.55, north)
		var c := Vector3(x, 0.0, south)
		var d := Vector3(x, 5.55, south)
		if side < 0.0:
			_add_record_hall_triangle(wall_surface, a, b, c)
			_add_record_hall_triangle(wall_surface, b, d, c)
		else:
			_add_record_hall_triangle(wall_surface, a, c, b)
			_add_record_hall_triangle(wall_surface, b, c, d)
	for index in range(16):
		var x0 := lerpf(-half_width, half_width, float(index) / 16.0)
		var x1 := lerpf(-half_width, half_width, float(index + 1) / 16.0)
		var y0 := 5.55 + 1.65 * (1.0 - pow(x0 / half_width, 2.0))
		var y1 := 5.55 + 1.65 * (1.0 - pow(x1 / half_width, 2.0))
		_add_record_hall_triangle(wall_surface, Vector3(x0, 0.0, north), Vector3(x1, 0.0, north), Vector3(x0, y0, north))
		_add_record_hall_triangle(wall_surface, Vector3(x1, 0.0, north), Vector3(x1, y1, north), Vector3(x0, y0, north))
	var floor_surface := SurfaceTool.new()
	floor_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_record_hall_triangle(floor_surface, Vector3(-16.0, 0.014, -18.0), Vector3(-16.0, 0.014, 18.0), Vector3(16.0, 0.014, -18.0))
	_add_record_hall_triangle(floor_surface, Vector3(16.0, 0.014, -18.0), Vector3(-16.0, 0.014, 18.0), Vector3(16.0, 0.014, 18.0))
	return {"record_ceiling": ceiling_surface.commit(), "record_walls": wall_surface.commit(), "record_floor": floor_surface.commit()}

static func record_ribs() -> ArrayMesh:
	var rib_surface := SurfaceTool.new()
	rib_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_width := 16.0
	for z in [-15.0, -9.0, -3.0, 3.0, 9.0]:
		for index in range(16):
			var x0 := lerpf(-half_width, half_width, float(index) / 16.0)
			var x1 := lerpf(-half_width, half_width, float(index + 1) / 16.0)
			var y0 := 5.55 + 1.65 * (1.0 - pow(x0 / half_width, 2.0))
			var y1 := 5.55 + 1.65 * (1.0 - pow(x1 / half_width, 2.0))
			var a := Vector3(x0, y0 - 0.20, z - 0.18)
			var b := Vector3(x1, y1 - 0.20, z - 0.18)
			var c := Vector3(x0, y0 - 0.20, z + 0.18)
			var d := Vector3(x1, y1 - 0.20, z + 0.18)
			_add_record_hall_triangle(rib_surface, a, b, c)
			_add_record_hall_triangle(rib_surface, b, d, c)
			_add_record_hall_triangle(rib_surface, a, Vector3(x0, y0 + 0.03, z - 0.18), b)
			_add_record_hall_triangle(rib_surface, b, Vector3(x0, y0 + 0.03, z - 0.18), Vector3(x1, y1 + 0.03, z - 0.18))
		for side in [-1.0, 1.0]:
			var x: float = float(side) * 15.82
			_add_record_hall_triangle(rib_surface, Vector3(x, 0.0, z - 0.18), Vector3(x, 5.50, z - 0.18), Vector3(x, 0.0, z + 0.18))
			_add_record_hall_triangle(rib_surface, Vector3(x, 5.50, z - 0.18), Vector3(x, 5.50, z + 0.18), Vector3(x, 0.0, z + 0.18))
	return rib_surface.commit()

static func _add_record_hall_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for point in [a, b, c]:
		surface.set_normal(normal)
		if absf(normal.x) > 0.5:
			surface.set_uv(Vector2(point.z, point.y))
		elif absf(normal.y) > 0.5:
			surface.set_uv(Vector2(point.x, point.z))
		else:
			surface.set_uv(Vector2(point.x, point.y))
		surface.add_vertex(point)
