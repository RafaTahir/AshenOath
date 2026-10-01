extends SceneTree

const Frontier = preload("res://scripts/greyfen_frontier.gd")

func _initialize() -> void:
	var ground := SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(Frontier.Z_KNOTS.size() - 1):
		for column in range(Frontier.X_KNOTS.size() - 1):
			var x0: float = Frontier.X_KNOTS[column]
			var x1: float = Frontier.X_KNOTS[column + 1]
			var z0: float = Frontier.Z_KNOTS[row]
			var z1: float = Frontier.Z_KNOTS[row + 1]
			# All adjoining land shares one owner; the physical core remains open.
			if z0 >= -17.0 and z1 <= 17.0 and x0 >= -21.0 and x1 <= 21.0:
				continue
			for subrow in range(4):
				for subcolumn in range(4):
					var a := _point(lerpf(x0, x1, subcolumn / 4.0), lerpf(z0, z1, subrow / 4.0))
					var b := _point(lerpf(x0, x1, (subcolumn + 1) / 4.0), a.z)
					var c := _point(b.x, lerpf(z0, z1, (subrow + 1) / 4.0))
					var d := _point(a.x, c.z)
					for point in [a, c, d, a, b, c]:
						ground.set_uv(Vector2(point.x, point.z) * 0.18)
						var soil: float = clampf((point.y - 1.2) / 5.0, 0.0, 1.0)
						ground.set_color(Color(0.68, 0.76, 0.57).lerp(Color(0.74, 0.70, 0.57), soil))
						ground.add_vertex(point)
	ground.generate_normals()
	ground.index()
	var mesh := ground.commit()
	var track := SurfaceTool.new()
	track.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centers: Array[Vector2] = [Vector2(0, -17.0), Vector2(0, -23), Vector2(-2.5, -31), Vector2(-5.0, -40), Vector2(-2.0, -51)]
	for segment in range(centers.size() - 1):
		var a: Vector2 = centers[segment]
		var b: Vector2 = centers[segment + 1]
		var side: Vector2 = Vector2(-(b - a).y, (b - a).x).normalized() * (1.55 - segment * 0.12)
		for point in [a - side, b + side, a + side, a - side, b - side, b + side]:
			track.set_uv(point * 0.24)
			track.set_color(Color(0.74, 0.69, 0.58))
			track.add_vertex(_point(point.x, point.y) + Vector3(0, 0.012, 0))
	track.generate_normals()
	track.index()
	track.commit(mesh)
	for surface in mesh.get_surface_count():
		var material := StandardMaterial3D.new()
		material.resource_name = "GreyfenAdjoiningGround" if surface == 0 else "GreyfenDestinationTrack"
		material.albedo_texture = load("res://assets_external/textures/runtime/forest_ground_albedo.jpg" if surface == 0 else "res://assets_external/textures/runtime/wet_mud_albedo.jpg")
		material.vertex_color_use_as_albedo = true
		material.roughness = 1.0
		mesh.surface_set_material(surface, material)
	mesh.set_meta("source", "Original authored Greyfen adjoining landscape with destination valley and cemetery copse")
	mesh.set_meta("visual_only", true)
	var result := ResourceSaver.save(mesh, Frontier.MESH_PATH, ResourceSaver.FLAG_COMPRESS)
	if result != OK:
		push_error("Authored frontier bake failed: " + error_string(result))
		quit(1)
		return
	print("GREYFEN FRONTIER BAKE: PASS surfaces=%d triangles=%d bytes=%d sha256=%s" % [mesh.get_surface_count(), mesh.get_faces().size() / 3, FileAccess.get_file_as_bytes(Frontier.MESH_PATH).size(), FileAccess.get_sha256(Frontier.MESH_PATH)])
	quit(0)

func _point(x: float, z: float) -> Vector3:
	return Vector3(x, Frontier.height_at(x, z), z)
