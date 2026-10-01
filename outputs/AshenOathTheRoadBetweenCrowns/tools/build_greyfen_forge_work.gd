extends SceneTree

const ROOT := "res://assets_external/environment/props/"
const PATH := ROOT + "GreyfenForgeWork_Authored.res"
const SOURCES := ["Anvil_Log.obj", "Table_Large.obj", "WeaponStand.obj", "Bucket_Metal.obj", "Axe_Bronze.obj"]
var structure := SurfaceTool.new()
var embers := SurfaceTool.new()
var failed := false

func _initialize() -> void:
	structure.begin(Mesh.PRIMITIVE_TRIANGLES)
	embers.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append("Anvil_Log.obj", Vector3(0.92, 0.92, 0.54), Vector3(-1.18, 0.0, -0.35), 90.0, Color(0.25, 0.28, 0.28))
	_append("Table_Large.obj", Vector3(1.32, 0.67, 0.65), Vector3(-0.65, 0.30, 1.30), 0.0, Color(0.38, 0.25, 0.16))
	_append("WeaponStand.obj", Vector3(0.82, 1.30, 0.42), Vector3(0.55, 0.30, 1.86), 0.0, Color(0.38, 0.27, 0.18))
	_append("Bucket_Metal.obj", Vector3(0.34, 0.34, 0.34), Vector3(1.0, 0.30, 0.9), 12.0, Color(0.33, 0.34, 0.32))
	_append("Axe_Bronze.obj", Vector3(0.42, 0.18, 0.26), Vector3(-0.65, 0.99, 1.30), 70.0, Color(0.45, 0.38, 0.27))
	# Individual fuel and inset embers replace the elevated orange rectangle.
	for index in range(12):
		var center := Vector3(1.26 + (index % 4) * 0.15, 0.31, -1.27 + (index / 4) * 0.15)
		var radius := 0.075 + 0.006 * (index % 3)
		var peak := center + Vector3(0.012, 0.11 + 0.015 * (index % 2), -0.008)
		for side in range(5):
			var a := center + Vector3(cos(side * TAU / 5) * radius, 0.0, sin(side * TAU / 5) * radius)
			var b := center + Vector3(cos((side + 1) * TAU / 5) * radius, 0.0, sin((side + 1) * TAU / 5) * radius)
			for point in [a, peak, b]:
				structure.set_color(Color(0.075, 0.065, 0.055).lightened((index % 3) * 0.015))
				structure.add_vertex(point)
		if index % 2 == 0:
			for point in [center + Vector3(-0.026, 0.015, 0), center + Vector3(0, 0.047, 0.030), center + Vector3(0.029, 0.015, 0)]:
				embers.set_color(Color(0.90, 0.29, 0.05))
				embers.add_vertex(point)
	if failed:
		quit(1)
		return
	structure.generate_normals()
	structure.index()
	embers.generate_normals()
	embers.index()
	var mesh := structure.commit()
	embers.commit(mesh)
	for surface in mesh.get_surface_count():
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.88
		if surface == 1:
			material.emission_enabled = true
			material.emission = Color(0.60, 0.12, 0.025)
			material.emission_energy_multiplier = 0.65
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_material(surface, material)
	mesh.set_meta("source_pack", "Quaternius Fantasy Props MegaKit and original fuel geometry")
	mesh.set_meta("license", "CC0 1.0 / project-original fuel")
	mesh.set_meta("visual_only", true)
	var hashes := {}
	for source in SOURCES:
		hashes[source] = FileAccess.get_sha256(ROOT + source)
	mesh.set_meta("source_sha256", hashes)
	var result := ResourceSaver.save(mesh, PATH, ResourceSaver.FLAG_COMPRESS)
	if result != OK:
		push_error("Forge work bake failed: " + error_string(result))
		quit(1)
		return
	print("GREYFEN FORGE WORK BAKE: PASS surfaces=%d triangles=%d bytes=%d sha256=%s" % [mesh.get_surface_count(), mesh.get_faces().size() / 3, FileAccess.get_file_as_bytes(PATH).size(), FileAccess.get_sha256(PATH)])
	quit(0)

func _append(id: String, size: Vector3, position: Vector3, yaw: float, tint: Color) -> void:
	var source := load(ROOT + id) as ArrayMesh
	if source == null or source.get_surface_count() == 0:
		push_error("Required CC0 forge source is missing: " + id)
		failed = true
		return
	var bounds := source.get_aabb()
	var basis := Basis(Vector3.UP, deg_to_rad(yaw)).scaled_local(size / bounds.size)
	var bottom := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var transform := Transform3D(basis, position - basis * bottom)
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var group := source.surface_get_name(surface).to_lower()
		var color := Color(0.35, 0.23, 0.14) if group.contains("wood") else tint
		if group.contains("metal"):
			color = Color(0.28, 0.31, 0.30)
		for offset in range(indices.size() if not indices.is_empty() else vertices.size()):
			var index := indices[offset] if not indices.is_empty() else offset
			structure.set_color(color)
			structure.add_vertex(transform * vertices[index])
