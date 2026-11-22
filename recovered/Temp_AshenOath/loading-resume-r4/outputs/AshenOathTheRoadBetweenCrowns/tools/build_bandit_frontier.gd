extends SceneTree

const Frontier = preload("res://scripts/bandit_frontier.gd")

func _initialize() -> void:
	var ground := SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(Frontier.Z_KNOTS.size() - 1):
		for column in range(Frontier.X_KNOTS.size() - 1):
			var x0: float = Frontier.X_KNOTS[column]
			var x1: float = Frontier.X_KNOTS[column + 1]
			var z0: float = Frontier.Z_KNOTS[row]
			var z1: float = Frontier.Z_KNOTS[row + 1]
			if absf((x0 + x1) * 0.5) < 22.0 and absf((z0 + z1) * 0.5) < 19.0:
				continue
			for row_part in range(3):
				for column_part in range(3):
					var a := _point(lerpf(x0, x1, column_part / 3.0), lerpf(z0, z1, row_part / 3.0))
					var b := _point(lerpf(x0, x1, (column_part + 1) / 3.0), a.z)
					var c := _point(b.x, lerpf(z0, z1, (row_part + 1) / 3.0))
					var d := _point(a.x, c.z)
					for point in [a, b, c, a, c, d]:
						ground.set_uv(Vector2(point.x, point.z) * 0.18)
						ground.set_color(Color(0.64, 0.61, 0.44).lerp(Color(0.72, 0.67, 0.51), clampf(point.y / 7.0, 0, 1)))
						ground.add_vertex(point)
	# Continue the perimeter beyond the gameplay-camera horizon. The inner
	# grid still owns every nearby contour; no floating berm masks its edge.
	for row in range(Frontier.Z_KNOTS.size() - 1):
		for side in [-1, 1]:
			var x: float = Frontier.X_KNOTS[0 if side < 0 else -1]
			var a := _point(x, Frontier.Z_KNOTS[row])
			var b := _point(x, Frontier.Z_KNOTS[row + 1])
			_continue_ground(ground, a, b, Vector3(side * 240.0, b.y, b.z), Vector3(side * 240.0, a.y, a.z), side < 0)
	var outer_x: Array[float] = [-240.0]
	outer_x.append_array(Frontier.X_KNOTS)
	outer_x.append(240.0)
	for column in range(outer_x.size() - 1):
		for side in [-1, 1]:
			var z: float = Frontier.Z_KNOTS[0 if side < 0 else -1]
			var a := _point(outer_x[column], z)
			var b := _point(outer_x[column + 1], z)
			_continue_ground(ground, a, b, Vector3(b.x, b.y, side * 240.0), Vector3(a.x, a.y, side * 240.0), side > 0)
	ground.generate_normals()
	ground.index()
	var mesh := ground.commit()
	var work := SurfaceTool.new()
	work.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Grounded use lanes join the cart, guard posts and supply table to the
	# existing diagonal road. They are not a second traversal or river surface.
	for lane in [
		[Vector2(1.0, -2.3), Vector2(8.5, -2.3), 1.05],
		[Vector2(-1.7, 4.0), Vector2(-8.5, 4.0), 1.30],
		[Vector2(2.8, -6.0), Vector2(6.2, -6.0), 0.85],
		[Vector2(-0.8, -4.4), Vector2(-6.3, -4.4), 0.85],
	]:
		var a: Vector2 = lane[0]
		var b: Vector2 = lane[1]
		var side := Vector2(-(b - a).y, (b - a).x).normalized() * float(lane[2])
		var ring: Array[Vector2] = [a - side * 0.65, a + side * 0.75, b + side, b - side * 0.80]
		for index in [0, 2, 1, 0, 3, 2]:
			work.set_uv(ring[index] * 0.30)
			work.set_color(Color(0.58, 0.50, 0.39))
			work.add_vertex(Vector3(ring[index].x, 0.035, ring[index].y))
	work.generate_normals()
	work.index()
	work.commit(mesh)
	for surface in range(2):
		var material := StandardMaterial3D.new()
		material.albedo_texture = load("res://assets_external/textures/runtime/forest_ground_albedo.jpg" if surface == 0 else "res://assets_external/textures/runtime/wet_mud_albedo.jpg")
		material.vertex_color_use_as_albedo = true
		material.roughness = 1.0
		mesh.surface_set_material(surface, material)
	mesh.set_meta("source", "Original authored Bandit Road adjoining woodland, Vargan pass and fitted camp use lanes")
	mesh.set_meta("visual_only", true)
	var result := ResourceSaver.save(mesh, Frontier.MESH_PATH, ResourceSaver.FLAG_COMPRESS)
	if result != OK:
		push_error("Bandit adjoining ground bake failed: " + error_string(result))
		quit(1)
		return
	print("BANDIT FRONTIER BAKE: PASS surfaces=%d triangles=%d bytes=%d sha256=%s" % [mesh.get_surface_count(), mesh.get_faces().size() / 3, FileAccess.get_file_as_bytes(Frontier.MESH_PATH).size(), FileAccess.get_sha256(Frontier.MESH_PATH)])
	quit(0)

func _point(x: float, z: float) -> Vector3:
	return Vector3(x, Frontier.height_at(x, z), z)

func _continue_ground(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, forward: bool) -> void:
	var points := [a, b, c, d]
	for index in ([0, 1, 2, 0, 2, 3] if forward else [0, 2, 1, 0, 3, 2]):
		var point: Vector3 = points[index]
		surface.set_uv(Vector2(point.x, point.z) * 0.18)
		surface.set_color(Color(0.64, 0.61, 0.44).lerp(Color(0.72, 0.67, 0.51), clampf(point.y / 7.0, 0, 1)))
		surface.add_vertex(point)
