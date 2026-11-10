extends SceneTree

const OUTPUT := "res://assets_external/environment/props/RecordArchive_Authored.res"
const ROOT := "res://assets_external/environment/props/"
const SOURCES := ["Bookcase_2.obj", "Chair_1.obj", "Table_Large.obj", "BookGroup_Small_1.obj", "BookGroup_Small_2.obj", "Book_Stack_1.obj"]
const BOOK_COLORS := [Color(0.35, 0.13, 0.10), Color(0.18, 0.27, 0.25), Color(0.45, 0.31, 0.16), Color(0.26, 0.23, 0.31)]

var imported: Dictionary = {}
var wood := SurfaceTool.new()
var books := SurfaceTool.new()
var cabinet_count := 0
var book_group_count := 0
var cabinet_bounds: Array[AABB] = []

func _initialize() -> void:
	for source in SOURCES:
		var mesh := load(ROOT + source) as ArrayMesh
		if mesh == null or mesh.get_surface_count() == 0:
			push_error("Archive source unavailable: " + source)
			quit(1)
			return
		imported[source] = mesh
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	books.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in [-8.8, -6.4, 6.4, 8.8]:
		for z in [-9.5, -3.2, 3.2, 9.5]:
			_cabinet(Vector3(x, 0.0, z), Vector3(2.15, 2.15, 0.48), 75.0 if x < 0.0 else -75.0)
	for x in [-8.2, -5.0, 5.0, 8.2]:
		_cabinet(Vector3(x, 0.0, -15.6), Vector3(2.15, 2.15, 0.48), 0.0)
	for position in [Vector3(-2.7, 0.0, -7.8), Vector3(2.7, 0.0, -7.8), Vector3(-2.7, 0.0, 5.0), Vector3(2.7, 0.0, 5.0)]:
		_furniture("Chair_1.obj", position, Vector3(0.54, 1.02, 0.54), 180.0)
	_furniture("Table_Large.obj", Vector3(0.0, 0.0, -7.8), Vector3(2.8, 0.82, 1.08), 0.0)
	for position in [Vector3(-4.2, 0.0, 0.5), Vector3(4.2, 0.0, 0.5), Vector3(-4.2, 0.0, 6.4), Vector3(4.2, 0.0, 6.4)]:
		_furniture("Table_Large.obj", position, Vector3(2.35, 0.78, 0.96), 90.0)
		_furniture("Chair_1.obj", position + Vector3(0.0, 0.0, 1.15), Vector3(0.54, 1.02, 0.54), 180.0)
		_append(books, imported["Book_Stack_1.obj"], _fit(imported["Book_Stack_1.obj"], Vector3(0.45, 0.12, 0.30), position + Vector3(0.12, 0.79, -0.12), 25.0), BOOK_COLORS[2], true)
	wood.index()
	books.index()
	var mesh := wood.commit()
	books.commit(mesh)
	for index in mesh.get_surface_count():
		mesh.surface_set_name(index, "timber" if index == 0 else "bound_testimony")
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.88
		mesh.surface_set_material(index, material)
	mesh.set_meta("source_pack", "Quaternius Fantasy Props MegaKit")
	mesh.set_meta("license", "CC0 1.0")
	mesh.set_meta("source_files", SOURCES)
	mesh.set_meta("cabinet_count", cabinet_count)
	mesh.set_meta("book_group_count", book_group_count)
	mesh.set_meta("cabinet_recipe", "wide-inward-75deg-v1")
	mesh.set_meta("cabinet_bounds", cabinet_bounds)
	var source_hashes: Dictionary = {}
	for source in SOURCES:
		source_hashes[source] = FileAccess.get_sha256(ROOT + source)
	mesh.set_meta("source_sha256", source_hashes)
	var error := ResourceSaver.save(mesh, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Archive bake failed: " + error_string(error))
		quit(1)
		return
	print("RECORD ARCHIVE BAKE: PASS cabinets=%d book_groups=%d surfaces=%d triangles=%d" % [cabinet_count, book_group_count, mesh.get_surface_count(), mesh.get_faces().size() / 3])
	quit(0)

func _cabinet(position: Vector3, size: Vector3, yaw: float) -> void:
	var source: ArrayMesh = imported["Bookcase_2.obj"]
	var transform := _fit(source, size, position, yaw)
	cabinet_bounds.append(transform * source.get_aabb())
	_append(wood, source, transform, Color(0.52, 0.33, 0.19))
	# These are the three shelf top planes in the source cabinet, not guessed heights.
	var source_bounds := source.get_aabb()
	for row in range(3):
		var shelf_y: float = [1.151, 1.535, 1.919][row]
		var local_y := (shelf_y - source_bounds.position.y) * size.y / source_bounds.size.y
		for side in [-1.0, 1.0]:
			var source_id := "BookGroup_Small_1.obj" if (cabinet_count + row) % 2 == 0 else "BookGroup_Small_2.obj"
			var book_position := position + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(side * size.x * 0.23, local_y, 0.018)
			var book_size := Vector3(size.x * 0.39, 0.23 if row < 2 else 0.18, 0.22)
			_append(books, imported[source_id], _fit(imported[source_id], book_size, book_position, yaw), BOOK_COLORS[(cabinet_count + row + int(side > 0)) % BOOK_COLORS.size()], true)
			book_group_count += 1
	cabinet_count += 1

func _furniture(source_id: String, position: Vector3, size: Vector3, yaw: float) -> void:
	_append(wood, imported[source_id], _fit(imported[source_id], size, position, yaw), Color(0.48, 0.29, 0.15))

func _fit(mesh: ArrayMesh, size: Vector3, position: Vector3, yaw: float) -> Transform3D:
	var bounds := mesh.get_aabb()
	var basis := Basis(Vector3.UP, deg_to_rad(yaw)).scaled_local(size / bounds.size)
	var bottom_center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	return Transform3D(basis, position - basis * bottom_center)

func _append(surface: SurfaceTool, mesh: ArrayMesh, transform: Transform3D, tint: Color, paper: bool = false) -> void:
	var normal_basis := transform.basis.inverse().transposed()
	for part in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(part)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for offset in range(0, count, 3):
			var a := indices[offset] if not indices.is_empty() else offset
			var b := indices[offset + 1] if not indices.is_empty() else offset + 1
			var c := indices[offset + 2] if not indices.is_empty() else offset + 2
			var face_normal := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).normalized()
			var face_color := Color(0.68, 0.61, 0.44) if paper and absf(face_normal.y) > 0.75 else tint
			for index in [a, b, c]:
				var point: Vector3 = transform * vertices[index]
				var normal: Vector3 = (normal_basis * normals[index]).normalized()
				surface.set_normal(normal)
				surface.set_color(face_color)
				surface.set_uv(Vector2(point.x, -point.y) if absf(normal.z) > 0.5 else Vector2(point.z, -point.y))
				surface.add_vertex(point)
