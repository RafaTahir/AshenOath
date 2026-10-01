extends "res://tools/build_record_archive.gd"

const WorldMaterialLibrary = preload("res://scripts/world_material_library.gd")
const OUTPUT_VAULT := "res://assets_external/environment/village/UndercroftVault_Authored.res"

func _initialize() -> void:
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	wood.set_normal(Vector3.DOWN)
	books.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Elliptical intrados, not a flat low ceiling. Ribs share the same curve.
	for segment in range(24):
		var a := -PI / 2 + segment * PI / 24
		var b := -PI / 2 + (segment + 1) * PI / 24
		var p0 := Vector3(sin(a) * 13.95, 3.25 + cos(a) * 2.60, -15.5)
		var p1 := Vector3(sin(b) * 13.95, 3.25 + cos(b) * 2.60, -15.5)
		var p2 := p1 + Vector3(0, 0, 31)
		var p3 := p0 + Vector3(0, 0, 31)
		for point in [p0, p2, p1, p0, p3, p2]:
			wood.set_uv(Vector2(point.x, point.z))
			wood.set_color(Color(0.64, 0.63, 0.61))
			wood.add_vertex(point)
		for z in [-12.0, -6.0, 0.0, 6.0, 12.0]:
			var start := Vector3(p0.x, p0.y - 0.10, z)
			var end := Vector3(p1.x, p1.y - 0.10, z)
			var direction := end - start
			var rib := BoxMesh.new()
			rib.size = Vector3(direction.length() + 0.04, 0.19, 0.34)
			var source := ArrayMesh.new()
			source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rib.get_mesh_arrays())
			_append(wood, source, Transform3D(Basis(Vector3.BACK, atan2(direction.y, direction.x)), (start + end) / 2), Color(0.82, 0.81, 0.76))
	wood.generate_normals()
	for position in [Vector3(-10, 0, -7), Vector3(10, 0, -7), Vector3(-10, 0, 5), Vector3(10, 0, 5)]:
		_tomb(position)
	_funeral_architecture()
	wood.index()
	books.index()
	var result := wood.commit()
	books.commit(result)
	for surface in result.get_surface_count():
		result.surface_set_name(surface, "vault_and_ribs" if surface == 0 else "carved_sarcophagi_and_wall_dressing")
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.94
		result.surface_set_material(surface, material)
	result.set_meta("source", "Original Ashen Oath architectural mesh")
	result.set_meta("collision_surface", 0)
	result.set_meta("tomb_count", 4)
	result.set_meta("tomb_collision_footprint", Vector3(4.2, 1.6, 2.1))
	result.set_meta("clearance_height", 3.05)
	result.set_meta("wall_pier_count", 10)
	result.set_meta("framed_door_count", 2)
	result.set_meta("memorial_niche_count", 1)
	var error := ResourceSaver.save(result, OUTPUT_VAULT, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Undercroft bake failed: " + error_string(error))
		quit(1)
		return
	print("UNDERCROFT VAULT BAKE: PASS surfaces=%d triangles=%d bytes=%d" % [result.get_surface_count(), result.get_faces().size() / 3, FileAccess.get_file_as_bytes(OUTPUT_VAULT).size()])
	quit(0)

func _tomb(origin: Vector3) -> void:
	_box(origin + Vector3(0, 0.14, 0), Vector3(4.2, 0.28, 2.1), Color(0.57, 0.58, 0.57))
	_box(origin + Vector3(0, 0.73, 0), Vector3(3.92, 0.98, 1.82), Color(0.68, 0.69, 0.66))
	_box(origin + Vector3(0, 1.27, 0), Vector3(4.10, 0.12, 2.00), Color(0.80, 0.79, 0.73))
	# A bevelled pitched lid and recessed name plaques make these tombs, not crates.
	var lid := SurfaceTool.new()
	lid.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(-2.1, 1.33, -1.05), Vector3(2.1, 1.33, -1.05), Vector3(2.1, 1.33, 1.05), Vector3(-2.1, 1.33, 1.05), Vector3(-1.80, 1.6, -0.82), Vector3(1.80, 1.6, -0.82), Vector3(1.80, 1.6, 0.82), Vector3(-1.80, 1.6, 0.82)]
	for indices in [[4, 5, 6, 4, 6, 7], [0, 1, 5, 0, 5, 4], [1, 2, 6, 1, 6, 5], [2, 3, 7, 2, 7, 6], [3, 0, 4, 3, 4, 7]]:
		for index in indices:
			lid.add_vertex(points[index])
	lid.generate_normals()
	lid.index()
	_append(books, lid.commit(), Transform3D(Basis.IDENTITY, origin), Color(0.79, 0.78, 0.73))
	for x in [-1.4, -0.7, 0.0, 0.7, 1.4]:
		_box(origin + Vector3(x, 0.73, 0.93), Vector3(0.45, 0.52, 0.04), Color(0.39, 0.41, 0.40))
	_box(origin + Vector3(0, 1.02, 0.95), Vector3(2.0, 0.075, 0.035), Color(0.65, 0.62, 0.45))

func _box(centre: Vector3, size: Vector3, tint: Color) -> void:
	var box := WorldMaterialLibrary.make_tiled_box(size, centre)
	_append(books, box, Transform3D(Basis.IDENTITY, centre), tint)

func _funeral_architecture() -> void:
	# Piers meet the existing rib spring points; all dressing stays outside the
	# collision-owned aisle, tomb footprints and two door openings.
	for x in [-13.50, 13.50]:
		for z in [-12.0, -6.0, 0.0, 6.0, 12.0]:
			_box(Vector3(x, 0.15, z), Vector3(0.74, 0.30, 0.78), Color(0.49, 0.48, 0.44))
			_box(Vector3(x, 1.68, z), Vector3(0.48, 2.76, 0.54), Color(0.60, 0.59, 0.55))
			_box(Vector3(x, 3.17, z), Vector3(0.72, 0.22, 0.74), Color(0.75, 0.72, 0.64))
	for door in [Vector2(6.0, -14.02), Vector2(-6.0, 14.02)]:
		for side in [-1.0, 1.0]:
			var x: float = door.x + side * 2.38
			_box(Vector3(x, 0.14, door.y), Vector3(0.56, 0.28, 0.42), Color(0.51, 0.50, 0.46))
			for course in range(6):
				_box(Vector3(x, 0.28 + (float(course) + 0.5) * 0.52, door.y), Vector3(0.54, 0.50, 0.32), Color(0.72, 0.69, 0.61) if course % 2 == 0 else Color(0.64, 0.62, 0.56))
		for block in range(9):
			_box(Vector3(door.x - 2.12 + float(block) * 0.53, 3.64, door.y), Vector3(0.51, 0.46, 0.38), Color(0.72, 0.69, 0.61))
		_box(Vector3(door.x, 3.96, door.y), Vector3(5.18, 0.18, 0.46), Color(0.49, 0.47, 0.42))
	# The witness memorial occupies the solid rear wall, not the duel floor.
	# A recessed arcade and narrow votive ledge belong to the same stone surface.
	for x in [-3.40, 3.40]:
		_box(Vector3(x, 0.15, -14.02), Vector3(0.42, 0.30, 0.30), Color(0.54, 0.53, 0.48))
		_box(Vector3(x, 1.72, -14.02), Vector3(0.30, 2.84, 0.28), Color(0.74, 0.71, 0.63))
		_box(Vector3(x, 3.23, -14.02), Vector3(0.46, 0.18, 0.32), Color(0.79, 0.75, 0.65))
	for segment in range(16):
		var angle := PI * (float(segment) + 0.5) / 16.0
		var arch := WorldMaterialLibrary.make_tiled_box(Vector3(0.69, 0.26, 0.28), Vector3.ZERO)
		var position := Vector3(cos(angle) * 3.42, 3.28 + sin(angle) * 1.18, -14.02)
		_append(books, arch, Transform3D(Basis(Vector3.BACK, atan2(1.18 * cos(angle), -3.42 * sin(angle))), position), Color(0.77, 0.73, 0.64))
	_box(Vector3(0, 0.67, -14.02), Vector3(6.66, 0.16, 0.30), Color(0.79, 0.75, 0.66))
