extends SceneTree

const ROOT := "res://assets_external/environment/village/"
const SOURCES := ["Wall_UnevenBrick_Straight.obj", "Roof_RoundTiles_4x4.obj", "Roof_Front_Brick4.obj", "Prop_Support.obj"]
const COLORS := {"masonry": Color(0.53, 0.52, 0.47), "timber": Color(0.28, 0.19, 0.13), "roof": Color(0.37, 0.24, 0.20), "bronze": Color(0.38, 0.29, 0.16), "earth": Color(0.25, 0.21, 0.16), "cloth": Color(0.57, 0.50, 0.37), "iron": Color(0.25, 0.28, 0.27), "glazing": Color(0.13, 0.23, 0.20)}
var parts: Dictionary = {}
var sources: Dictionary = {}

func _initialize() -> void:
	var selected_role := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			selected_role = argument.trim_prefix("--role=")
	if not selected_role.is_empty() and selected_role not in ["chapel", "bell_frame", "bell", "grave_rows", "boundary", "grave_earth", "memory_window", "grave_harl", "grave_child", "grave_soldier", "disturbed_soil"]:
		push_error("Unknown cemetery bake role: " + selected_role)
		quit(1)
		return
	for id in SOURCES:
		var mesh := load(ROOT + id) as ArrayMesh
		if mesh == null or mesh.get_surface_count() == 0:
			push_error("Missing cemetery kit source: " + id)
			quit(1)
			return
		sources[id] = mesh
	for role in ["chapel", "bell_frame", "bell", "grave_rows", "boundary", "grave_earth", "memory_window", "grave_harl", "grave_child", "grave_soldier", "disturbed_soil"]:
		if not selected_role.is_empty() and role != selected_role:
			continue
		parts.clear()
		match role:
			"chapel": _chapel()
			"bell_frame": _bell_frame()
			"bell": _bell()
			"grave_rows": _grave_rows()
			"boundary": _boundary()
			"grave_earth": _grave_earth()
			"memory_window": _memory_window()
			"disturbed_soil": _mound(Vector3.ZERO, Vector2(0.825, 0.425))
			_: _evidence(role)
		var mesh := ArrayMesh.new()
		for id in COLORS.keys() + ["CemeteryNorthWall", "CemeterySouthWall", "CemeteryEastWallNorth", "CemeteryEastWallSouth"]:
			if not parts.has(id):
				continue
			var surface: SurfaceTool = parts[id]
			surface.index()
			surface.commit(mesh)
			var index := mesh.get_surface_count() - 1
			mesh.surface_set_name(index, id)
			var material := StandardMaterial3D.new()
			material.albedo_color = COLORS.get(id, COLORS.masonry)
			material.roughness = 0.88 if id != "bronze" else 0.54
			material.metallic = 0.65 if id == "bronze" else 0.0
			if id == "glazing":
				material.albedo_color = Color(0.23, 0.34, 0.28)
				material.emission_enabled = true
				material.emission = Color(0.52, 0.66, 0.43)
				material.emission_energy_multiplier = 0.48
			mesh.surface_set_material(index, material)
		mesh.set_meta("role", role)
		mesh.set_meta("source_pack", "Quaternius Medieval Village MegaKit; original Ashen Oath bell and grave assembly")
		mesh.set_meta("license", "CC0 1.0 (kit); project-original assembly")
		var hashes := {}
		for id in SOURCES:
			hashes[id] = FileAccess.get_sha256(ROOT + id)
		mesh.set_meta("source_sha256", hashes)
		var output := ROOT + "Cemetery_%s_Authored.res" % role
		var error := ResourceSaver.save(mesh, output, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			push_error("Cemetery bake failed: " + error_string(error))
			quit(1)
			return
		print("CEMETERY BAKE %s: surfaces=%d triangles=%d bytes=%d bounds=%s" % [role, mesh.get_surface_count(), mesh.get_faces().size() / 3, FileAccess.get_file_as_bytes(output).size(), mesh.get_aabb()])
	print("CEMETERY ARCHITECTURE BAKE: PASS")
	quit(0)

func _surface(id: String) -> SurfaceTool:
	if not parts.has(id):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		parts[id] = tool
	return parts[id]

func _append(id: String, size: Vector3, bottom: Vector3, yaw: float, override_group: String = "") -> void:
	var source: ArrayMesh = sources[id]
	var bounds := source.get_aabb()
	var basis := Basis(Vector3.UP, deg_to_rad(yaw)).scaled_local(size / bounds.size)
	var transform := Transform3D(basis, bottom - basis * Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z))
	var normal_basis := basis.inverse().transposed()
	for part in source.get_surface_count():
		var group := source.surface_get_name(part).to_lower()
		var output := override_group
		if output.is_empty():
			output = "roof" if group.contains("tile") else ("timber" if group.contains("wood") else "masonry")
		var surface := _surface(output)
		var arrays := source.surface_get_arrays(part)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for offset in count:
			var index := indices[offset] if not indices.is_empty() else offset
			surface.set_normal((normal_basis * normals[index]).normalized())
			if arrays[Mesh.ARRAY_TEX_UV] != null:
				surface.set_uv(arrays[Mesh.ARRAY_TEX_UV][index])
			surface.add_vertex(transform * vertices[index])

func _chapel() -> void:
	# Modules cover the existing physical wall envelopes; the 1.64m west doorway stays open.
	for wall in [
		[Vector3(3.65, 2.76, 0.42), Vector3(1.38, 0, 0), 90.0],
		[Vector3(2.75, 2.76, 0.38), Vector3(0, 0, -1.66), 0.0],
		[Vector3(2.25, 2.24, 0.38), Vector3(0.25, 0, 1.66), 180.0],
		[Vector3(0.82, 2.50, 0.38), Vector3(-1.38, 0, -1.22), -90.0],
		[Vector3(0.82, 2.50, 0.38), Vector3(-1.38, 0, 1.22), -90.0],
	]:
		_append("Wall_UnevenBrick_Straight.obj", wall[0], wall[1], wall[2])
	# A continuous tiled cap replaces the three competing roof silhouettes.
	_append("Roof_RoundTiles_4x4.obj", Vector3(4.05, 1.10, 3.60), Vector3(0.05, 2.63, 0), 90.0)
	_append("Roof_Front_Brick4.obj", Vector3(3.65, 1.10, 0.16), Vector3(-1.48, 2.63, 0), -90.0)
	_append("Roof_Front_Brick4.obj", Vector3(3.65, 1.10, 0.16), Vector3(1.49, 2.63, 0), 90.0)
	# Stone voussoirs frame the passage without placing masonry below the lintel.
	for side in [-1.0, 1.0]:
		for index in 5:
			var a := Vector3(-1.61, 2.27 + float(index) * 0.125, side * (0.90 - float(index) * 0.18))
			var b := Vector3(-1.61, 2.27 + float(index + 1) * 0.125, side * (0.90 - float(index + 1) * 0.18))
			_beam("masonry", a, b, 0.20, 0.20)

func _bell_frame() -> void:
	for side in [-1.0, 1.0]:
		_append("Prop_Support.obj", Vector3(0.24, 2.36, 0.24), Vector3(side * 0.60, 0, 0), 0, "timber")
	_beam("timber", Vector3(-0.78, 2.25, 0), Vector3(0.78, 2.25, 0), 0.18, 0.22)
	for side in [-1.0, 1.0]:
		_beam("timber", Vector3(side * 0.60, 1.70, 0), Vector3(side * 0.22, 2.22, 0), 0.12, 0.16)
	_append("Roof_RoundTiles_4x4.obj", Vector3(1.86, 0.56, 1.26), Vector3(0, 2.33, 0), 0)

func _bell(scale_value: float = 1.0, position: Vector3 = Vector3.ZERO) -> void:
	var profile := [Vector2(0.07, 0.26), Vector2(0.17, 0.23), Vector2(0.19, 0.09), Vector2(0.23, -0.12), Vector2(0.31, -0.25)]
	for ring in profile.size() - 1:
		for segment in 24:
			var a := TAU * float(segment) / 24.0
			var b := TAU * float(segment + 1) / 24.0
			var p: Vector2 = profile[ring]
			var q: Vector2 = profile[ring + 1]
			var outer := [Vector3(p.x * cos(a), p.y, p.x * sin(a)), Vector3(q.x * cos(a), q.y, q.x * sin(a)), Vector3(q.x * cos(b), q.y, q.x * sin(b)), Vector3(p.x * cos(b), p.y, p.x * sin(b))]
			_quad("bronze", outer[0] * scale_value + position, outer[1] * scale_value + position, outer[2] * scale_value + position, outer[3] * scale_value + position)
			var inner: Array[Vector3] = []
			for point: Vector3 in outer:
				inner.append(Vector3(point.x, 0, point.z).normalized() * (Vector2(point.x, point.z).length() - 0.025) + Vector3.UP * point.y)
			_quad("bronze", inner[3] * scale_value + position, inner[2] * scale_value + position, inner[1] * scale_value + position, inner[0] * scale_value + position)
			if ring == profile.size() - 2:
				_quad("bronze", outer[1] * scale_value + position, inner[1] * scale_value + position, inner[2] * scale_value + position, outer[2] * scale_value + position)

func _boundary() -> void:
	for column in 4:
		for side in [-1.0, 1.0]:
			_append("Wall_UnevenBrick_Straight.obj", Vector3(2.0, 0.90, 0.38), Vector3(-2.8 + float(column) * 2.0, 0, -4.05 if side < 0 else 3.15), 0.0 if side < 0 else 180.0, "CemeteryNorthWall" if side < 0 else "CemeterySouthWall")
	for wall in [
		[Vector3(1.45, 0.90, 0.38), Vector3(4.1, 0, -3.15), 90.0, "CemeteryEastWallNorth"],
		[Vector3(1.45, 0.90, 0.38), Vector3(4.1, 0, 2.25), 90.0, "CemeteryEastWallSouth"],
	]:
		_append("Wall_UnevenBrick_Straight.obj", wall[0], wall[1], wall[2], wall[3])

func _mound(position: Vector3, radius: Vector2) -> void:
	var middle := position + Vector3.UP * 0.04
	for index in 16:
		var a := TAU * float(index) / 16.0
		var b := TAU * float(index + 1) / 16.0
		var scale_a := 1.0 + sin(float(index) * 1.9) * 0.06
		var scale_b := 1.0 + sin(float((index + 1) % 16) * 1.9) * 0.06
		_triangle("earth", middle, position + Vector3(cos(a) * radius.x * scale_a, 0, sin(a) * radius.y * scale_a), position + Vector3(cos(b) * radius.x * scale_b, 0, sin(b) * radius.y * scale_b))

func _grave_earth() -> void:
	for offset in [Vector3(-1.8, 0, -2.10), Vector3(0, 0, 2.28), Vector3(2.2, 0, -2.10), Vector3(-1.8, 0, 1.05), Vector3(0.2, 0, -2.55), Vector3(2.0, 0, 1.95)]:
		_mound(offset + Vector3(0, 0.057, 0.52), Vector2(0.36, 0.525))

func _memory_window() -> void:
	var profile := [Vector2(-0.29, -0.41), Vector2(0.29, -0.41), Vector2(0.29, 0.12), Vector2(0.16, 0.31), Vector2(0, 0.41), Vector2(-0.16, 0.31), Vector2(-0.29, 0.12)]
	for index in range(1, profile.size() - 1):
		var a: Vector2 = profile[0]
		var b: Vector2 = profile[index + 1]
		var c: Vector2 = profile[index]
		_triangle("glazing", Vector3(-0.019, a.y, a.x), Vector3(-0.019, b.y, b.x), Vector3(-0.019, c.y, c.x))
		_triangle("glazing", Vector3(0.019, a.y, a.x), Vector3(0.019, c.y, c.x), Vector3(0.019, b.y, b.x))
	for index in profile.size():
		var a: Vector2 = profile[index]
		var b: Vector2 = profile[(index + 1) % profile.size()]
		_beam("timber", Vector3(-0.026, a.y, a.x), Vector3(-0.026, b.y, b.x), 0.045, 0.045)
	_beam("timber", Vector3(-0.03, -0.39, 0), Vector3(-0.03, 0.39, 0), 0.033, 0.033)
	_beam("timber", Vector3(-0.03, -0.06, -0.27), Vector3(-0.03, -0.06, 0.27), 0.033, 0.033)

func _evidence(role: String) -> void:
	# Low fitted memorials replace the generic capsule, without changing its Area3D.
	_beam("masonry", Vector3(-0.19, 0.05, 0), Vector3(0.19, 0.05, 0), 0.09, 0.34)
	match role:
		"grave_harl": _bell(0.42, Vector3(0, 0.21, 0))
		"grave_child":
			for fold in 4:
				_beam("cloth", Vector3(-0.13, 0.11 + float(fold) * 0.009, -0.09 + float(fold) * 0.05), Vector3(0.13, 0.11 + float(fold) * 0.009, -0.09 + float(fold) * 0.05), 0.028, 0.06)
		"grave_soldier":
			_beam("iron", Vector3(0, 0.12, -0.13), Vector3(0, 0.12, 0.13), 0.055, 0.025)
			_beam("iron", Vector3(-0.10, 0.12, 0.045), Vector3(0.10, 0.12, 0.045), 0.04, 0.025)

func _grave_rows() -> void:
	var profiles := [
		[Vector2(-0.08, 0), Vector2(0.08, 0), Vector2(0.08, 0.38), Vector2(0.055, 0.46), Vector2(0, 0.50), Vector2(-0.055, 0.46), Vector2(-0.08, 0.38)],
		[Vector2(-0.11, 0), Vector2(0.11, 0), Vector2(0.10, 0.48), Vector2(0.07, 0.57), Vector2(0, 0.61), Vector2(-0.07, 0.57), Vector2(-0.10, 0.48)],
		[Vector2(-0.09, 0), Vector2(0.09, 0), Vector2(0.09, 0.31), Vector2(0.035, 0.40), Vector2(0.01, 0.43), Vector2(-0.07, 0.35), Vector2(-0.09, 0.29)],
	]
	for row in 3:
		for column in 3:
			var profile_index := (row + column * 2) % profiles.size()
			var outline: Array = profiles[profile_index]
			var position := Vector3(-1.25 + float(column) * 0.72 + 0.035 * sin(float(row * 3 + column)), 0.002, -1.3 + float(row) + 0.045 * cos(float(row + column * 2)))
			var lean := float((row * 2 + column) % 3 - 1) * 0.06
			var yaw := deg_to_rad(float((row + column * 3) % 5 - 2) * 4.0)
			for index in range(1, outline.size() - 1):
				for depth in [-0.045, 0.045]:
					var triangle := [outline[0], outline[index], outline[index + 1]] if depth < 0 else [outline[0], outline[index + 1], outline[index]]
					_triangle("masonry", _grave_row_vertex(position, triangle[0], depth, lean, yaw), _grave_row_vertex(position, triangle[1], depth, lean, yaw), _grave_row_vertex(position, triangle[2], depth, lean, yaw))
			for index in outline.size():
				var a: Vector2 = outline[index]
				var b: Vector2 = outline[(index + 1) % outline.size()]
				_quad("masonry", _grave_row_vertex(position, a, -0.045, lean, yaw), _grave_row_vertex(position, a, 0.045, lean, yaw), _grave_row_vertex(position, b, 0.045, lean, yaw), _grave_row_vertex(position, b, -0.045, lean, yaw))

func _grave_row_vertex(position: Vector3, point: Vector2, depth: float, lean: float, yaw: float) -> Vector3:
	return position + Basis(Vector3.UP, yaw) * Vector3(point.x + point.y * lean, point.y, depth)

func _triangle(id: String, a: Vector3, b: Vector3, c: Vector3) -> void:
	var surface := _surface(id)
	var normal := (c - a).cross(b - a).normalized()
	for point in [a, b, c]:
		surface.set_normal(normal)
		# Horizontal soil needs both ground axes; XY collapses its texture into stripes.
		surface.set_uv(Vector2(point.x, point.z) if id == "earth" else Vector2(point.x, point.y))
		surface.add_vertex(point)

func _quad(id: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_triangle(id, a, b, c)
	_triangle(id, a, c, d)

func _beam(id: String, a: Vector3, b: Vector3, width: float, depth: float) -> void:
	var direction := (b - a).normalized()
	var reference := Vector3.UP if absf(direction.dot(Vector3.FORWARD)) > 0.9 else Vector3.FORWARD
	var across := direction.cross(reference).normalized() * width * 0.5
	var outward := direction.cross(across).normalized() * depth * 0.5
	var points := [a - across - outward, a + across - outward, a + across + outward, a - across + outward, b - across - outward, b + across - outward, b + across + outward, b - across + outward]
	for face in [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [0, 3, 2, 1], [4, 5, 6, 7]]:
		_quad(id, points[face[0]], points[face[1]], points[face[2]], points[face[3]])
