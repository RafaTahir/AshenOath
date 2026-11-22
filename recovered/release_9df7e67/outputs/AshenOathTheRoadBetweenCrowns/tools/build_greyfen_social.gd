extends SceneTree

const ROOT := "res://assets_external/environment/props/"
const SOURCES := ["Table_Large.obj", "Chair_1.obj", "Stall_Empty.obj", "Potion_1.obj", "Potion_2.obj", "Bag.obj"]
const WOOD := Color(0.38, 0.25, 0.16)
const RECIPES := {
	"common_table": Vector3(2.8, 0.85, 1.8),
	"barrel_board": Vector3(2.2, 0.85, 1.5),
	"mira_apothecary": Vector3(1.75, 0.78, 1.25),
}
var imported: Dictionary = {}

func _initialize() -> void:
	for source in SOURCES:
		var mesh := load(ROOT + source) as ArrayMesh
		if mesh == null or mesh.get_surface_count() == 0:
			push_error("Required Quaternius furniture source unavailable: " + source)
			quit(1)
			return
		imported[source] = mesh
	for id in RECIPES:
		var size: Vector3 = RECIPES[id]
		var timber := SurfaceTool.new()
		var detail := SurfaceTool.new()
		timber.begin(Mesh.PRIMITIVE_TRIANGLES)
		detail.begin(Mesh.PRIMITIVE_TRIANGLES)
		var counter_y := 0.0
		if id == "mira_apothecary":
			var stall_size := Vector3(size.x + 0.32, 2.45, size.z + 0.28)
			var stall: ArrayMesh = imported["Stall_Empty.obj"]
			counter_y = _counter_height(stall, stall_size.y)
			if counter_y <= 0.0:
				push_error("Stall source has no broad horizontal counter surface")
				quit(1)
				return
			_append(timber, "Stall_Empty.obj", stall_size, Vector3.ZERO, 0.0, WOOD)
			# Stock stays inside the counter footprint, leaving the frontage clear.
			for index in range(5):
				var point := Vector3(-0.56 + float(index) * 0.28, counter_y + 0.003, 0.30)
				_append(detail, "Potion_1.obj" if index % 2 == 0 else "Potion_2.obj", Vector3(0.18, 0.30, 0.18), point, float(index) * 17.0, Color(0.44, 0.58, 0.45) if index % 2 == 0 else Color(0.65, 0.37, 0.24))
			_append(detail, "Bag.obj", Vector3(0.35, 0.29, 0.28), Vector3(0.35, 0.0, 0.45), -20.0, Color(0.42, 0.36, 0.27))
		else:
			_append(timber, "Table_Large.obj", Vector3(size.x, size.y + 0.08, size.z), Vector3.ZERO, 0.0, WOOD)
			for side in [-1.0, 1.0]:
				_append(detail, "Chair_1.obj", Vector3(0.90, 1.40, 0.82), Vector3(0.0, 0.0, side * size.z * 0.90), 180.0 if side > 0.0 else 0.0, WOOD.lightened(0.06))
		timber.index()
		detail.index()
		var mesh := timber.commit()
		detail.commit(mesh)
		for part in mesh.get_surface_count():
			var material := StandardMaterial3D.new()
			material.vertex_color_use_as_albedo = true
			material.roughness = 0.86
			mesh.surface_set_material(part, material)
			mesh.surface_set_name(part, "structure" if part == 0 else "seating_or_stock")
		mesh.set_meta("source_pack", "Quaternius Fantasy Props MegaKit")
		mesh.set_meta("license", "CC0 1.0")
		mesh.set_meta("role", id)
		mesh.set_meta("grounded_origin", true)
		if id == "mira_apothecary":
			mesh.set_meta("counter_height", counter_y)
			mesh.set_meta("stock_count", 5)
			print("STOCK SUPPORT: counter=%.4f bases=%.4f top=%.4f" % [counter_y, counter_y + 0.003, counter_y + 0.303])
		var hashes: Dictionary = {}
		for source in SOURCES:
			hashes[source] = FileAccess.get_sha256(ROOT + source)
		mesh.set_meta("source_sha256", hashes)
		var output := ROOT + "GreyfenSocial_%s.res" % id
		var error := ResourceSaver.save(mesh, output, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			push_error("Social furniture bake failed: " + error_string(error))
			quit(1)
			return
		print("GREYFEN SOCIAL BAKE %s: surfaces=%d triangles=%d bytes=%d" % [id, mesh.get_surface_count(), mesh.get_faces().size() / 3, FileAccess.get_file_as_bytes(output).size()])
	print("GREYFEN SOCIAL BAKE: PASS")
	quit(0)

func _append(target: SurfaceTool, id: String, size: Vector3, position: Vector3, yaw: float, tint: Color) -> void:
	var mesh: ArrayMesh = imported[id]
	var bounds := mesh.get_aabb()
	var basis := Basis(Vector3.UP, deg_to_rad(yaw)).scaled_local(size / bounds.size)
	var bottom := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var transform := Transform3D(basis, position - basis * bottom)
	var normal_basis := basis.inverse().transposed()
	for part in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(part)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for offset in range(count):
			var index := indices[offset] if not indices.is_empty() else offset
			target.set_normal((normal_basis * normals[index]).normalized())
			var cloth := id == "Stall_Empty.obj" and (vertices[index].y - bounds.position.y) / bounds.size.y > 0.72
			target.set_color(Color(0.34, 0.43, 0.32) if cloth else tint)
			if arrays[Mesh.ARRAY_TEX_UV] != null:
				target.set_uv(arrays[Mesh.ARRAY_TEX_UV][index])
			target.add_vertex(transform * vertices[index])

func _counter_height(mesh: ArrayMesh, height: float) -> float:
	var bounds := mesh.get_aabb()
	var planes: Dictionary = {}
	var faces := mesh.get_faces()
	for index in range(0, faces.size(), 3):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		var relative := (a.y - bounds.position.y) / bounds.size.y
		if relative < 0.2 or relative > 0.6 or absf(a.y - b.y) > 0.0001 or absf(a.y - c.y) > 0.0001:
			continue
		var y := snappedf(a.y, 0.0001)
		planes[y] = float(planes.get(y, 0.0)) + (b - a).cross(c - a).length() * 0.5
	var surface_y := 0.0
	var largest := 0.0
	for y in planes:
		var area := float(planes[y])
		if area > largest + 0.0001 or (is_equal_approx(area, largest) and float(y) > surface_y):
			largest = area
			surface_y = float(y)
	return (surface_y - bounds.position.y) * height / bounds.size.y if largest > 0.0 else 0.0
