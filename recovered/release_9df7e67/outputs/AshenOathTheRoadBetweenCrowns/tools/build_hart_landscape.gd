extends SceneTree

const BASE := "res://assets_external/environment/forest/"
var ground := SurfaceTool.new()
var stone := SurfaceTool.new()

func _initialize() -> void:
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	ground.set_normal(Vector3.UP)
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A worn, irregular approach dissolves into the witness clearing.
	for row in range(17):
		var z0 := -15.0 + row * 2
		var z1 := z0 + 2
		var w0 := 2.6 + sin(z0 * 0.51) * 0.22
		var w1 := 2.6 + sin(z1 * 0.51) * 0.22
		for side in [-1.0, 1.0]:
			var a := Vector3(0, 0.030, z0)
			var b := Vector3(side * w0, 0.030, z0)
			var c := Vector3(side * w1, 0.030, z1)
			var d := Vector3(0, 0.030, z1)
			for point in ([a, b, c, a, c, d] if side > 0 else [a, c, b, a, d, c]):
				_vertex(ground, point, Color(0.66, 0.71, 0.53) if is_zero_approx(point.x) else Color(0.43, 0.61, 0.46))
	for segment in range(40):
		var a := segment * TAU / 40
		var b := (segment + 1) * TAU / 40
		var r0 := 8.5 + sin(a * 5) * 0.34
		var r1 := 8.5 + sin(b * 5) * 0.34
		var origin := Vector3(0, 0.035, -8.6)
		_vertex(ground, origin, Color(0.65, 0.77, 0.58))
		_vertex(ground, origin + Vector3(cos(a) * r0, 0, sin(a) * r0), Color(0.43, 0.61, 0.46))
		_vertex(ground, origin + Vector3(cos(b) * r1, 0, sin(b) * r1), Color(0.43, 0.61, 0.46))
	# Close the exposed world edge outside the unchanged arena and return route.
	for segment in range(16):
		var x0 := -26.0 + segment * 52.0 / 16
		var x1 := -26.0 + (segment + 1) * 52.0 / 16
		var a := Vector3(x0, -0.08, -19.5)
		var b := Vector3(x1, -0.08, -19.5)
		var c := Vector3(x1, 2.3 + sin(x1 * 0.29) * 0.7, -25)
		var d := Vector3(x0, 2.3 + sin(x0 * 0.29) * 0.7, -25)
		for point in [a, d, c, a, c, b]:
			_vertex(ground, point, Color(0.50, 0.64, 0.48))
	for point in [Vector3(-7, 0, -7), Vector3(7, 0, -7), Vector3(-9, 0, -2), Vector3(9, 0, -2)]:
		_monolith(stone, point, 1.6, 0.6, 0.35)
	ground.generate_normals()
	ground.index()
	stone.generate_normals()
	stone.index()
	var mesh := ground.commit()
	stone.commit(mesh)
	if not _save(mesh, "HartLandscape_Authored.res"):
		quit(1)
		return
	var focal := SurfaceTool.new()
	focal.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		_monolith(focal, Vector3(side * 5.6, 0, -10.2), 2.7, 0.55, 0.55)
	focal.generate_normals()
	focal.index()
	if not _save(focal.commit(), "HartWitnessStones_Authored.res"):
		quit(1)
		return
	quit(0)

func _vertex(target: SurfaceTool, point: Vector3, tint: Color) -> void:
	target.set_uv(Vector2(point.x, point.z))
	target.set_color(tint)
	target.add_vertex(point)

func _monolith(target: SurfaceTool, origin: Vector3, height: float, width: float, depth: float) -> void:
	var bottom: Array[Vector3] = []
	var top: Array[Vector3] = []
	for index in range(6):
		var angle := TAU * index / 6
		bottom.append(origin + Vector3(cos(angle) * width / 2, 0.026, sin(angle) * depth / 2))
		top.append(origin + Vector3(cos(angle) * width * 0.35 + 0.03, height - float(index % 3) * 0.09, sin(angle) * depth * 0.34))
	for index in range(6):
		var next := (index + 1) % 6
		for point in [bottom[index], top[next], bottom[next], bottom[index], top[index], top[next]]:
			_vertex(target, point, Color(0.65, 0.69, 0.64))
	for index in range(1, 5):
		for point in [top[0], top[index + 1], top[index]]:
			_vertex(target, point, Color(0.74, 0.77, 0.70))

func _save(mesh: ArrayMesh, file: String) -> bool:
	for surface in mesh.get_surface_count():
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.96
		mesh.surface_set_material(surface, material)
	mesh.set_meta("source", "Original Ashen Oath landscape and witness stone geometry")
	mesh.set_meta("visual_only", true)
	var path := BASE + file
	var error := ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Hart landscape bake failed: " + error_string(error))
		return false
	print("HART LANDSCAPE BAKE: PASS file=%s triangles=%d bytes=%d" % [file, mesh.get_faces().size() / 3, FileAccess.get_file_as_bytes(path).size()])
	return true
