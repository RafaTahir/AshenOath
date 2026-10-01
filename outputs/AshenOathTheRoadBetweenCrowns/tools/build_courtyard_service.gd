extends "res://tools/build_record_archive.gd"

const COURT_OUTPUT := "res://assets_external/environment/village/CourtyardService_Authored.res"
const COURT_PROPS := ["Barrel.obj", "Crate_Wooden.obj", "Bucket_Wooden_1.obj", "Stall_Cart_Empty.obj"]
var prop_bounds: Array[AABB] = []

func _initialize() -> void:
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	books.begin(Mesh.PRIMITIVE_TRIANGLES)
	for source in COURT_PROPS:
		imported[source] = load(ROOT + source) as ArrayMesh
		if imported[source] == null:
			push_error("Missing court service prop: " + source)
			quit(1)
			return
	# Flush service paving joins the central road to stable/forge/cistern bays.
	# Each bay follows its work frontage; no decorative slab covers the road.
	for bay in [[Vector2(-9.4, -4.2), Vector2(-4.03, 6.0)], [Vector2(4.03, -6.8), Vector2(15.8, -2.0)], [Vector2(4.03, 0.0), Vector2(10.6, 8.2)]]:
		var low: Vector2 = bay[0]
		var high: Vector2 = bay[1]
		var rows := ceili((high.y - low.y) / 1.1)
		var columns := ceili((high.x - low.x) / 1.1)
		for row in rows:
			for column in columns:
				var a := Vector3(lerpf(low.x, high.x, float(column) / columns), 0.048, lerpf(low.y, high.y, float(row) / rows))
				var b := Vector3(lerpf(low.x, high.x, float(column + 1) / columns), 0.048, lerpf(low.y, high.y, float(row + 1) / rows))
				var gray := 0.59 + sin(row * 3.2 + column * 2.7) * 0.035
				_quad(a + Vector3(0.008, 0, 0.008), b - Vector3(0.008, 0, 0.008), Color(gray, gray, gray * 0.96))
	# Same two forge barrels replace their box rendering at the exact collision.
	for x in [11.7, 14.3]:
		_prop("Barrel.obj", Vector3(x, 0, 1), Vector3(0.78, 1.1, 0.78), 0)
	_prop("Stall_Cart_Empty.obj", Vector3(-7.2, 0, 2.0), Vector3(1.28, 0.88, 1.95), 0)
	_prop("Crate_Wooden.obj", Vector3(-7.2, 0.50, 2.0), Vector3(0.57, 0.42, 0.67), 8)
	_prop("Crate_Wooden.obj", Vector3(-6.4, 0, -2.8), Vector3(0.72, 0.58, 0.67), -5)
	_prop("Crate_Wooden.obj", Vector3(-6.4, 0.58, -2.8), Vector3(0.55, 0.42, 0.53), 8)
	_prop("Bucket_Wooden_1.obj", Vector3(10.65, 0, 3.8), Vector3(0.44, 0.46, 0.44), 0)
	wood.index()
	books.index()
	var mesh := wood.commit()
	books.commit(mesh)
	for surface in mesh.get_surface_count():
		mesh.surface_set_name(surface, "service_paving" if surface == 0 else "working_supplies")
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.94
		mesh.surface_set_material(surface, material)
	mesh.set_meta("source_pack", "Quaternius Fantasy Props MegaKit / original service paving")
	mesh.set_meta("license", "CC0 1.0 / original project geometry")
	mesh.set_meta("prop_bounds", prop_bounds)
	var hashes := {}
	for source in COURT_PROPS:
		hashes[ROOT + source] = FileAccess.get_sha256(ROOT + source)
	mesh.set_meta("source_sha256", hashes)
	if ResourceSaver.save(mesh, COURT_OUTPUT, ResourceSaver.FLAG_COMPRESS) != OK:
		push_error("Court service bake failed")
		quit(1)
		return
	print("COURTYARD SERVICE BAKE: PASS surfaces=%d triangles=%d bytes=%d" % [mesh.get_surface_count(), mesh.get_faces().size() / 3, FileAccess.get_file_as_bytes(COURT_OUTPUT).size()])
	quit(0)

func _quad(a: Vector3, b: Vector3, color: Color) -> void:
	for vertex in [a, Vector3(b.x, a.y, a.z), b, a, b, Vector3(a.x, a.y, b.z)]:
		wood.set_normal(Vector3.UP)
		wood.set_uv(Vector2(vertex.x, vertex.z))
		wood.set_color(color)
		wood.add_vertex(vertex)

func _prop(file: String, position: Vector3, size: Vector3, yaw: float) -> void:
	var transform := _fit(imported[file], size, position, yaw)
	prop_bounds.append(transform * imported[file].get_aabb())
	_append(books, imported[file], transform, Color(0.42, 0.29, 0.16))
