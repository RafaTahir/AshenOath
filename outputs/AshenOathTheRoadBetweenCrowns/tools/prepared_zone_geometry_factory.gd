extends RefCounted

const GROUND_STEP := 0.58
static func wychwood_ground(size: Vector3, origin: Vector3) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := maxi(2, ceili(size.x / GROUND_STEP))
	var rows := maxi(2, ceili(size.z / GROUND_STEP))
	for row in rows:
		var z0 := lerpf(-size.z * 0.5, size.z * 0.5, float(row) / float(rows))
		var z1 := lerpf(-size.z * 0.5, size.z * 0.5, float(row + 1) / float(rows))
		for column in columns:
			var x0 := lerpf(-size.x * 0.5, size.x * 0.5, float(column) / float(columns))
			var x1 := lerpf(-size.x * 0.5, size.x * 0.5, float(column + 1) / float(columns))
			for point in [
				Vector3(x0, size.y * 0.5, z0), Vector3(x1, size.y * 0.5, z0), Vector3(x0, size.y * 0.5, z1),
				Vector3(x1, size.y * 0.5, z0), Vector3(x1, size.y * 0.5, z1), Vector3(x0, size.y * 0.5, z1),
			]:
				var world: Vector3 = point + origin
				surface.set_normal(Vector3.UP)
				surface.set_uv(Vector2(world.x, world.z) * 0.55)
				surface.set_color(_ground_tint(world.x, world.z))
				surface.add_vertex(point)
	# Preserve the short river-bank faces of the original split-ground boxes.
	var half := size * 0.5
	for edge in [
		[Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z), Vector3(half.x, half.y, -half.z), Vector3(-half.x, half.y, -half.z), Vector3(0, 0, -1)],
		[Vector3(half.x, -half.y, half.z), Vector3(-half.x, -half.y, half.z), Vector3(-half.x, half.y, half.z), Vector3(half.x, half.y, half.z), Vector3(0, 0, 1)],
		[Vector3(-half.x, -half.y, half.z), Vector3(-half.x, -half.y, -half.z), Vector3(-half.x, half.y, -half.z), Vector3(-half.x, half.y, half.z), Vector3(-1, 0, 0)],
		[Vector3(half.x, -half.y, -half.z), Vector3(half.x, -half.y, half.z), Vector3(half.x, half.y, half.z), Vector3(half.x, half.y, -half.z), Vector3(1, 0, 0)],
	]:
		for vertex_index in [0, 1, 2, 0, 2, 3]:
			var point: Vector3 = edge[vertex_index]
			surface.set_normal(edge[4])
			surface.set_uv(Vector2(point.x + origin.x, point.y + origin.y))
			surface.set_color(Color(0.86, 0.89, 0.82))
			surface.add_vertex(point)
	return surface.commit()

static func _ground_tint(x: float, z: float) -> Color:
	var base := Color(0.87, 0.94, 0.88)
	var center := sin(z * 0.28) * 0.62 * smoothstep(2.3, 7.0, absf(z))
	var edge_noise := 0.16 * sin(z * 1.37) + 0.08 * sin(z * 2.59)
	var path := 0.0
	if z >= -10.5 and z <= 16.5:
		path = 1.0 - smoothstep(1.05 + edge_noise, 2.75 + edge_noise, absf(x - center))
	var clearing_distance := Vector2(x / 5.4, (z + 6.5) / 3.9).length()
	var clearing := 1.0 - smoothstep(0.58, 1.20, clearing_distance + 0.04 * sin(x * 1.9 + z * 1.4))
	var layby_z := -8.0 + sin(x * 0.48) * 0.33
	var layby := 0.0
	if x >= 0.7 and x <= 11.4:
		layby = (1.0 - smoothstep(0.75, 2.05, absf(z - layby_z))) * smoothstep(0.7, 2.2, x)
	var wear := maxf(path * 0.72, maxf(clearing * 0.78, layby * 0.64))
	# Pale worn earth separates the occupied clearing and clue route from the
	# cooler forest floor without new geometry, lights or collision changes.
	var earth := Color(0.86, 0.71, 0.51)
	return base.lerp(earth, wear)

static func wychwood_layby() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(12):
		var x0 := 0.7 + float(index) * 0.89
		var x1 := 0.7 + float(index + 1) * 0.89
		var z0 := -8.0 + sin(x0 * 0.48) * 0.33
		var z1 := -8.0 + sin(x1 * 0.48) * 0.33
		var width0 := 1.26 + 0.18 * sin(x0 * 1.13)
		var width1 := 1.26 + 0.18 * sin(x1 * 1.13)
		for side in [-1.0, 1.0]:
			var a := Vector3(x0, 0.061, z0)
			var b := Vector3(x1, 0.061, z1)
			var c := Vector3(x0, 0.061, z0 + side * width0)
			var d := Vector3(x1, 0.061, z1 + side * width1)
			var points := [a, b, c, c, b, d] if side < 0.0 else [a, c, b, c, d, b]
			for point in points:
				surface.set_normal(Vector3.UP)
				surface.set_color(Color(0.81, 0.84, 0.76) if point == c or point == d else Color.WHITE)
				surface.set_uv(Vector2(point.x, point.z) * 0.55)
				surface.add_vertex(point)
	return surface.commit()

static func low_berm(pos: Vector3, size: Vector3) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := 8
	var rows := 10
	var points: Array[Vector3] = []
	for row in range(rows + 1):
		for column in range(columns + 1):
			var u := float(column) / columns * 2.0 - 1.0
			var v := float(row) / rows * 2.0 - 1.0
			var shoulder := pow(pow(absf(u), 4.0) + pow(absf(v), 4.0), 0.25)
			var rise := 1.0 - smoothstep(0.40, 1.0, shoulder)
			var irregularity := sin(u * 4.1 + pos.z) * sin(v * 3.2 + pos.x) * 0.07 * rise
			var edge_x := 1.0 + 0.10 * sin(v * 3.1 + pos.z)
			var edge_z := 1.0 + 0.09 * sin(u * 4.0 + pos.x)
			points.append(Vector3(u * (size.x * 0.5 + 0.28) * edge_x, -size.y * 0.5 - 0.015 + size.y * (rise + irregularity), v * (size.z * 0.5 + 0.28) * edge_z))
	for row in range(rows):
		for column in range(columns):
			var a := row * (columns + 1) + column
			var b := a + 1
			var c := a + columns + 1
			var d := c + 1
			for index in [a, b, c, b, d, c]:
				var point := points[index]
				surface.set_uv(Vector2(point.x + pos.x, point.z + pos.z))
				surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()

static func wychwood_clearing() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0, 0.059, -6.5)
	var segments := 20
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		var next_angle := TAU * float(index + 1) / float(segments)
		var radius := 0.88 + 0.12 * sin(float(index) * 2.17)
		var next_radius := 0.88 + 0.12 * sin(float(index + 1) * 2.17)
		var inner := center + Vector3(cos(angle) * 3.25 * radius, 0, sin(angle) * 2.35 * radius)
		var inner_next := center + Vector3(cos(next_angle) * 3.25 * next_radius, 0, sin(next_angle) * 2.35 * next_radius)
		var outer := center + Vector3(cos(angle) * 5.25 * radius, 0, sin(angle) * 3.75 * radius)
		var outer_next := center + Vector3(cos(next_angle) * 5.25 * next_radius, 0, sin(next_angle) * 3.75 * next_radius)
		for point in [[center, Color(0.52, 0.53, 0.47)], [inner_next, Color(0.68, 0.68, 0.57)], [inner, Color(0.68, 0.68, 0.57)], [inner, Color(0.68, 0.68, 0.57)], [inner_next, Color(0.68, 0.68, 0.57)], [outer_next, Color(0.91, 0.93, 0.83)], [inner, Color(0.68, 0.68, 0.57)], [outer_next, Color(0.91, 0.93, 0.83)], [outer, Color(0.91, 0.93, 0.83)]]:
			surface.set_normal(Vector3.UP)
			surface.set_color(point[1])
			surface.set_uv(Vector2(point[0].x, point[0].z) * 0.55)
			surface.add_vertex(point[0])
	return surface.commit()

static func wychwood_winding_path() -> ArrayMesh:
	var mud_surface := SurfaceTool.new()
	mud_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shoulder_surface := SurfaceTool.new()
	shoulder_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var river_edge := BridgeSurfaceContract.RIVER_HALF_SPAN
	for span in [Vector2(-10.5, -river_edge), Vector2(river_edge, 16.5)]:
		var rows := ceili((span.y - span.x) / 0.9)
		for row in range(rows):
			var z0 := lerpf(span.x, span.y, float(row) / float(rows))
			var z1 := lerpf(span.x, span.y, float(row + 1) / float(rows))
			var bridge_blend0 := 1.0 - smoothstep(river_edge, river_edge + 3.0, absf(z0))
			var bridge_blend1 := 1.0 - smoothstep(river_edge, river_edge + 3.0, absf(z1))
			var core0 := lerpf(1.26 + 0.16 * sin(z0 * 1.37) + 0.07 * sin(z0 * 2.59), 2.28, bridge_blend0)
			var core1 := lerpf(1.26 + 0.16 * sin(z1 * 1.37) + 0.07 * sin(z1 * 2.59), 2.28, bridge_blend1)
			var outer0 := maxf(3.48, core0 + 0.80) + 0.24 * sin(z0 * 1.41)
			var outer1 := maxf(3.48, core1 + 0.80) + 0.24 * sin(z1 * 1.41)
			var lateral0 := [-outer0, -core0, 0.0, core0, outer0]
			var lateral1 := [-outer1, -core1, 0.0, core1, outer1]
			for band in range(4):
				var x00: float = _wychwood_path_center(z0) + float(lateral0[band])
				var x01: float = _wychwood_path_center(z1) + float(lateral1[band])
				var x10: float = _wychwood_path_center(z0) + float(lateral0[band + 1])
				var x11: float = _wychwood_path_center(z1) + float(lateral1[band + 1])
				var surface := mud_surface if band in [1, 2] else shoulder_surface
				var left_color := Color(0.70, 0.73, 0.66) if band == 0 else Color(0.82, 0.84, 0.78) if band == 1 else Color(0.97, 0.98, 0.94) if band == 2 else Color(0.58, 0.62, 0.55)
				var right_color := Color(0.58, 0.62, 0.55) if band == 0 else Color(0.97, 0.98, 0.94) if band == 1 else Color(0.82, 0.84, 0.78) if band == 2 else Color(0.70, 0.73, 0.66)
				for vertex in [
					[Vector3(x00, 0.057, z0), left_color], [Vector3(x10, 0.057, z0), right_color], [Vector3(x01, 0.057, z1), left_color],
					[Vector3(x10, 0.057, z0), right_color], [Vector3(x11, 0.057, z1), right_color], [Vector3(x01, 0.057, z1), left_color],
				]:
					surface.set_normal(Vector3.UP)
					surface.set_color(vertex[1])
					surface.set_uv(Vector2(vertex[0].x, vertex[0].z) * 0.55)
					surface.add_vertex(vertex[0])
	var mesh := mud_surface.commit()
	shoulder_surface.commit(mesh)
	return mesh

static func _wychwood_path_center(z: float) -> float:
	return sin(z * 0.28) * 0.62 * smoothstep(2.3, 7.0, absf(z))

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
