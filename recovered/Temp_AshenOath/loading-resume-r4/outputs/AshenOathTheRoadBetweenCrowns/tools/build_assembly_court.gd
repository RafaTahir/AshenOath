extends "res://tools/build_record_archive.gd"

const OUTPUT_COURT := "res://assets_external/environment/village/AssemblyCourt_Authored.res"
const HOUSE := "res://assets_external/environment/village/Vargan_stable_Authored.res"
const COURT_SOURCES: Array[String] = ["Bench.obj", "Table_Large.obj"]

func _initialize() -> void:
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	books.begin(Mesh.PRIMITIVE_TRIANGLES)
	var house := load(HOUSE) as ArrayMesh
	if house == null:
		push_error("Required assembly house source is unavailable")
		quit(1)
		return
	for placement in [Vector3(-14, 0, -24), Vector3(14, 0, -24), Vector3(-4.4, 0, -29), Vector3(4.4, 0, -29)]:
		var yaw := 0.0 if placement.z < -20 else (-90.0 if placement.x < 0 else 90.0)
		var transform := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), placement)
		for part in house.get_surface_count():
			_append_part(wood if part == 0 else books, house, part, transform)
	for file in COURT_SOURCES:
		var source := load("res://assets_external/environment/props/" + file) as ArrayMesh
		if source == null:
			push_error("Required assembly furniture is missing: " + file)
			quit(1)
			return
		imported[file] = source
	for x in [-8.6, -4.0, 4.0, 8.6]:
		_append(books, imported["Bench.obj"], _fit(imported["Bench.obj"], Vector3(3.0, 0.8, 1.2), Vector3(x, 0, 1.5), 0), Color(0.43, 0.29, 0.18))
	for item in [[Vector3(0, 0, -6.5), Vector3(3.4, 1.0, 0.95)], [Vector3(0, 0, -9), Vector3(2.4, 1.0, 1.1)], [Vector3(8, 0, -3.5), Vector3(2.4, 1.0, 1.1)]]:
		_append(books, imported["Table_Large.obj"], _fit(imported["Table_Large.obj"], item[1], item[0], 0), Color(0.48, 0.32, 0.19))
	_brazier(Vector3(0, 0, 4.2))
	wood.index()
	books.index()
	var result := wood.commit()
	books.commit(result)
	for surface in result.get_surface_count():
		result.surface_set_name(surface, "settlement_masonry" if surface == 0 else "timber_roofs_and_furniture")
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.93
		result.surface_set_material(surface, material)
	result.set_meta("source_pack", "Quaternius Medieval Village and Fantasy Props MegaKits")
	result.set_meta("license", "CC0 1.0")
	var hashes := {HOUSE: FileAccess.get_sha256(HOUSE)}
	for file in COURT_SOURCES:
		var path: String = "res://assets_external/environment/props/" + file
		hashes[path] = FileAccess.get_sha256(path)
	result.set_meta("source_sha256", hashes)
	result.set_meta("bench_count", 4)
	result.set_meta("table_count", 3)
	result.set_meta("house_count", 4)
	result.set_meta("brazier_count", 1)
	var error := ResourceSaver.save(result, OUTPUT_COURT, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Assembly bake failed: " + error_string(error))
		quit(1)
		return
	print("ASSEMBLY COURT BAKE: PASS surfaces=%d triangles=%d bytes=%d" % [result.get_surface_count(), result.get_faces().size() / 3, FileAccess.get_file_as_bytes(OUTPUT_COURT).size()])
	quit(0)

func _triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for point in [a, b, c]:
		books.set_normal(normal)
		books.set_color(color)
		books.set_uv(Vector2(point.x, point.z))
		books.add_vertex(point)

func _brazier(origin: Vector3) -> void:
	var iron := Color(0.12, 0.14, 0.15)
	var rim := Color(0.25, 0.23, 0.20)
	for index in 12:
		var a := TAU * float(index) / 12.0
		var b := TAU * float(index + 1) / 12.0
		var low_a := origin + Vector3(cos(a) * 0.22, 0.73, sin(a) * 0.22)
		var low_b := origin + Vector3(cos(b) * 0.22, 0.73, sin(b) * 0.22)
		var top_a := origin + Vector3(cos(a) * 0.43, 1.03, sin(a) * 0.43)
		var top_b := origin + Vector3(cos(b) * 0.43, 1.03, sin(b) * 0.43)
		var inner_a := origin + Vector3(cos(a) * 0.36, 1.01, sin(a) * 0.36)
		var inner_b := origin + Vector3(cos(b) * 0.36, 1.01, sin(b) * 0.36)
		_triangle(low_a, top_a, top_b, iron)
		_triangle(low_a, top_b, low_b, iron)
		_triangle(top_a, inner_b, top_b, rim)
		_triangle(top_a, inner_a, inner_b, rim)
		_triangle(origin + Vector3(0, 0.92, 0), inner_b, inner_a, Color(0.44, 0.12, 0.025) if index % 3 == 0 else Color(0.075, 0.055, 0.035))
	for index in 3:
		var angle := TAU * float(index) / 3.0
		var foot := origin + Vector3(cos(angle) * 0.32, 0, sin(angle) * 0.32)
		var top := origin + Vector3(cos(angle) * 0.18, 0.77, sin(angle) * 0.18)
		var crossbar := Vector3(-sin(angle), 0, cos(angle)) * 0.055
		_triangle(foot - crossbar, top + crossbar, top - crossbar, iron)
		_triangle(foot - crossbar, foot + crossbar, top + crossbar, iron)
		_triangle(foot - crossbar, top - crossbar, top + crossbar, iron)
		_triangle(foot - crossbar, top + crossbar, foot + crossbar, iron)

func _append_part(target: SurfaceTool, source: ArrayMesh, part: int, transform: Transform3D) -> void:
	var arrays := source.surface_get_arrays(part)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		target.set_normal(transform.basis * normals[index])
		target.set_color(colors[index])
		target.set_uv(uvs[index])
		target.add_vertex(transform * vertices[index])
