extends SceneTree

const PATH := "res://assets_external/environment/village/GreyfenFrontages_Authored.res"
var surfaces: Array[SurfaceTool] = []

func _initialize() -> void:
	for index in range(3):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces.append(surface)
	# Worn access lanes meet the existing street, then widen at actual doors,
	# the counter, well and forge. They never cross the river or move its banks.
	for lane in [
		[Vector2(-1.95, -5.15), Vector2(-3.2, -5.25), Vector2(-5.3, -5.20)],
		[Vector2(-1.95, -0.30), Vector2(-3.35, -0.35), Vector2(-5.5, -0.32)],
		[Vector2(-5.5, -0.32), Vector2(-6.9, 0.4), Vector2(-8.0, 0.5)],
		[Vector2(1.95, -3.30), Vector2(3.2, -3.45), Vector2(5.6, -3.32)],
		[Vector2(-8.0, 9.0), Vector2(-9.5, 9.1), Vector2(-10.8, 9.1)],
		[Vector2(9.9, 0.0), Vector2(10.6, -0.9), Vector2(11.2, -1.9)],
		[Vector2(6.0, -8.9), Vector2(9.4, -10.7), Vector2(12.9, -11.0), Vector2(15.0, -10.1)],
	]:
		_ribbon(lane, 0.74, 0, Color(0.78, 0.74, 0.65))
	for court in [
		[Vector2(-5.4, -1.15), Vector2(1.55, 1.18)],
		[Vector2(-8.0, -0.5), Vector2(1.70, 1.60)],
		[Vector2(10.65, -1.10), Vector2(2.00, 1.65)],
		[Vector2(-6.9, 8.45), Vector2(1.60, 1.0)],
	]:
		_court(court[0], court[1])
	# Paired stone lips and a recessed dark channel connect house runoff to
	# worn ground. No raised physical obstacle is introduced.
	for drain in [
		[Vector2(-5.1, -5.15), 3.2],
		[Vector2(5.6, -3.52), 3.2],
		[Vector2(-10.65, 9.12), 2.8],
	]:
		var center: Vector2 = drain[0]
		var length: float = drain[1]
		_ribbon([center - Vector2(length * 0.5, 0), center + Vector2(length * 0.5, 0)], 0.09, 1, Color(0.20, 0.22, 0.21), 0.078)
		for side in [-1.0, 1.0]:
			for index in range(8):
				var stone_center := center + Vector2(length * (float(index) / 7.0 - 0.5), side * 0.16)
				_stone(stone_center, Vector2(length / 8.5, 0.13), index)
	var mesh := ArrayMesh.new()
	for index in surfaces.size():
		surfaces[index].generate_normals()
		surfaces[index].index()
		surfaces[index].commit(mesh)
		var material := StandardMaterial3D.new()
		material.resource_name = ["FrontagePaving", "WorkCourtEarth", "DrainStone"][index]
		material.albedo_texture = load("res://assets_external/textures/runtime/%s_albedo.jpg" % ["cobblestone", "wet_mud", "medieval_brick"][index])
		if material.albedo_texture == null:
			push_error("Required frontage texture is unavailable: " + material.resource_name)
			quit(1)
			return
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.95
		mesh.surface_set_material(index, material)
	mesh.set_meta("source", "Original fitted Greyfen shop, door, well, forge and drainage surface geometry")
	mesh.set_meta("visual_only", true)
	var result := ResourceSaver.save(mesh, PATH, ResourceSaver.FLAG_COMPRESS)
	if result != OK:
		push_error("Greyfen frontage bake failed: " + error_string(result))
		quit(1)
		return
	print("GREYFEN FRONTAGE BAKE: PASS surfaces=%d triangles=%d bytes=%d sha256=%s" % [mesh.get_surface_count(), mesh.get_faces().size() / 3, FileAccess.get_file_as_bytes(PATH).size(), FileAccess.get_sha256(PATH)])
	quit(0)

func _ribbon(points: Array, half_width: float, surface: int, color: Color, height: float = 0.070) -> void:
	for index in range(points.size() - 1):
		var a: Vector2 = points[index]
		var b: Vector2 = points[index + 1]
		var side := Vector2(-(b - a).y, (b - a).x).normalized() * half_width
		_triangle(surface, _point(a - side, height), _point(b + side, height), _point(a + side, height), color)
		_triangle(surface, _point(a - side, height), _point(b - side, height), _point(b + side, height), color)

func _court(center: Vector2, radius: Vector2) -> void:
	for index in range(9):
		var a := TAU * float(index) / 9.0
		var b := TAU * float(index + 1) / 9.0
		var point_a := center + Vector2(cos(a), sin(a)) * radius * (0.94 + 0.06 * cos(index * 1.7))
		var point_b := center + Vector2(cos(b), sin(b)) * radius * (0.94 + 0.06 * cos((index + 1) * 1.7))
		_triangle(1, _point(center, 0.064), _point(point_a, 0.064), _point(point_b, 0.064), Color(0.72, 0.68, 0.55))

func _stone(center: Vector2, size: Vector2, index: int) -> void:
	var corners: Array[Vector3] = []
	for side in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
		corners.append(_point(center + side * size, 0.089 + 0.005 * float(index % 3)))
	var tint := Color(0.66, 0.65, 0.57).lightened(float(index % 3) * 0.025)
	_triangle(2, corners[0], corners[1], corners[2], tint)
	_triangle(2, corners[0], corners[2], corners[3], tint)

func _point(point: Vector2, height: float) -> Vector3:
	return Vector3(point.x, height, point.y)

func _triangle(surface: int, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var points := [a, b, c] if (b - a).cross(c - a).y < 0.0 else [a, c, b]
	for point in points:
		surfaces[surface].set_uv(Vector2(point.x, point.z) * 0.34)
		surfaces[surface].set_color(color)
		surfaces[surface].add_vertex(point)
