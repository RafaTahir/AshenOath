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
	wood.index()
	books.index()
	var result := wood.commit()
	books.commit(result)
	for surface in result.get_surface_count():
		result.surface_set_name(surface, "vault_and_ribs" if surface == 0 else "carved_sarcophagi")
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.94
		result.surface_set_material(surface, material)
	result.set_meta("source", "Original Ashen Oath architectural mesh")
	result.set_meta("collision_surface", 0)
	result.set_meta("tomb_count", 4)
	result.set_meta("tomb_collision_footprint", Vector3(4.2, 1.6, 2.1))
	result.set_meta("clearance_height", 3.05)
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
