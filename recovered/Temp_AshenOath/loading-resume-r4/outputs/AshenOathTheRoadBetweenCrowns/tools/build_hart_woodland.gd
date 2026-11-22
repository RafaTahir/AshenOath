extends SceneTree

const Woodland = preload("res://scripts/hart_woodland.gd")
const FERN_PATH := "res://assets_external/environment/forest/Fern_1.obj"

func _initialize() -> void:
	var ground := SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(Woodland.Z_KNOTS.size() - 1):
		for column in range(Woodland.X_KNOTS.size() - 1):
			var x0: float = Woodland.X_KNOTS[column]
			var x1: float = Woodland.X_KNOTS[column + 1]
			var z0: float = Woodland.Z_KNOTS[row]
			var z1: float = Woodland.Z_KNOTS[row + 1]
			if x0 >= -22.5 and x1 <= 22.5 and z0 >= -19.5 and z1 <= 19.5:
				continue
			for row_part in range(2):
				for column_part in range(2):
					var a := _point(lerpf(x0, x1, column_part / 2.0), lerpf(z0, z1, row_part / 2.0))
					var b := _point(lerpf(x0, x1, (column_part + 1) / 2.0), a.z)
					var c := _point(b.x, lerpf(z0, z1, (row_part + 1) / 2.0))
					var d := _point(a.x, c.z)
					for point in [a, b, c, a, c, d]:
						ground.set_uv(Vector2(point.x, point.z) * 0.18)
						ground.set_color(Color(0.57, 0.67, 0.48).lerp(Color(0.61, 0.57, 0.42), clampf(point.y / 6.0, 0, 1)))
						ground.add_vertex(point)
	ground.generate_normals()
	ground.index()
	var mesh := ground.commit()
	var foliage := SurfaceTool.new()
	foliage.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fern := load(FERN_PATH) as ArrayMesh
	if fern == null:
		push_error("Required licensed Hart understory mesh is missing")
		quit(1)
		return
	var bounds := fern.get_aabb()
	var bottom := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var positions: Array[Vector3] = [Vector3(-12.8, 0.027, -7), Vector3(-14.6, 0.027, 3), Vector3(-12, 0.027, 10), Vector3(13.6, 0.027, -8), Vector3(14.8, 0.027, 4), Vector3(12.5, 0.027, 12)]
	# Native leaves, fitted to the existing tree flanks, never the battle lanes.
	for index in positions.size():
		var size := Vector3(1.7, 0.68 + float(index % 3) * 0.10, 1.6)
		var basis := Basis(Vector3.UP, float(index) * 1.73).scaled_local(size / bounds.size)
		var transform := Transform3D(basis, positions[index] - basis * bottom)
		for surface in fern.get_surface_count():
			var arrays := fern.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for offset in range(indices.size() if not indices.is_empty() else vertices.size()):
				var vertex: Vector3 = vertices[indices[offset] if not indices.is_empty() else offset]
				foliage.set_uv(Vector2(vertex.x, vertex.z))
				foliage.set_color(Color(0.20, 0.38, 0.16).lerp(Color(0.40, 0.53, 0.23), clampf((vertex.y - bounds.position.y) / bounds.size.y, 0, 1)))
				foliage.add_vertex(transform * vertex)
	foliage.generate_normals()
	foliage.index()
	foliage.commit(mesh)
	for surface in mesh.get_surface_count():
		var material := StandardMaterial3D.new()
		if surface == 0:
			material.albedo_texture = load("res://assets_external/textures/runtime/forest_ground_albedo.jpg")
		material.vertex_color_use_as_albedo = true
		material.roughness = 1.0
		if surface == 1:
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_material(surface, material)
	mesh.set_meta("source", "Original authored Hart woodland terrain, fitted Quaternius CC0 Fern_1; retained Quaternius tree stands are separate instances")
	mesh.set_meta("source_sha256", {FERN_PATH: FileAccess.get_sha256(FERN_PATH)})
	mesh.set_meta("visual_only", true)
	var result := ResourceSaver.save(mesh, Woodland.MESH_PATH, ResourceSaver.FLAG_COMPRESS)
	if result != OK:
		push_error("Hart woodland bake failed: " + error_string(result))
		quit(1)
		return
	print("HART WOODLAND BAKE: PASS surfaces=%d triangles=%d bytes=%d sha256=%s" % [mesh.get_surface_count(), mesh.get_faces().size() / 3, FileAccess.get_file_as_bytes(Woodland.MESH_PATH).size(), FileAccess.get_sha256(Woodland.MESH_PATH)])
	quit(0)

func _point(x: float, z: float) -> Vector3:
	return Vector3(x, Woodland.height_at(x, z), z)
