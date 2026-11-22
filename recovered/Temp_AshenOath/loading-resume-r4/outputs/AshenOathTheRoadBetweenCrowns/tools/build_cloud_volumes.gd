extends SceneTree

const OUTPUT := "res://assets/sky"
const CORNERS := [Vector3(0,0,0), Vector3(1,0,0), Vector3(1,1,0), Vector3(0,1,0), Vector3(0,0,1), Vector3(1,0,1), Vector3(1,1,1), Vector3(0,1,1)]
const TETRAHEDRA := [[0,5,1,6], [0,1,2,6], [0,2,3,6], [0,3,7,6], [0,7,4,6], [0,4,5,6]]
const EDGES := [[0,1], [0,2], [0,3], [1,2], [1,3], [2,3]]
var lobes: Array[Dictionary] = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for variant in range(3):
		lobes = [
			{"center": Vector3(-4.6,-0.55,0.1), "radius": Vector3(2.6,1.25,1.6)},
			{"center": Vector3(-1.9,0.70,float(variant) * 0.25), "radius": Vector3(2.5,2.2,2.0)},
			{"center": Vector3(1.6,0.35,-0.45), "radius": Vector3(3.0,1.65 + variant * 0.20,1.9)},
			{"center": Vector3(4.65,-0.65,0.4), "radius": Vector3(2.0,1.05,1.35)},
			{"center": Vector3(0,-0.75,0), "radius": Vector3(4.2,0.9,2.0)},
		]
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		const STEP := Vector3(0.70, 0.48, 0.55)
		const ORIGIN := Vector3(-8.4, -3.0, -4.4)
		for z in range(16):
			for y in range(16):
				for x in range(24):
					var points: Array[Vector3] = []
					var values: Array[float] = []
					for corner in CORNERS:
						var position: Vector3 = ORIGIN + (Vector3(x,y,z) + corner) * STEP
						points.append(position)
						values.append(_density(position))
					for tetra in TETRAHEDRA:
						_emit_tetra(surface, points, values, tetra)
		surface.index()
		var mesh := surface.commit()
		mesh.resource_name = "AuthoredCloudVolume%d" % variant
		var path := OUTPUT.path_join("cloud_%d.res" % variant)
		if ResourceSaver.save(mesh, path) != OK:
			push_error("Cannot save cloud volume")
			quit(1)
			return
		print("CLOUD BAKE %d: %d vertices / %d triangles / bounds=%s / %s" % [variant, mesh.surface_get_array_len(0), mesh.surface_get_array_index_len(0) / 3, mesh.get_aabb(), FileAccess.get_sha256(path)])
	print("CLOUD VOLUMES: PASS (original authored density fields, no runtime generation)")
	quit()

func _density(point: Vector3) -> float:
	var value := 0.0
	for lobe in lobes:
		var offset: Vector3 = (point - lobe.center) / lobe.radius
		value += exp(-offset.length_squared() * 1.6)
	return value

func _normal(point: Vector3) -> Vector3:
	var gradient := Vector3.ZERO
	for lobe in lobes:
		var delta: Vector3 = point - lobe.center
		var radii: Vector3 = lobe.radius
		gradient += delta / (radii * radii) * exp(-(delta / radii).length_squared() * 1.6)
	return gradient.normalized()

func _emit_tetra(surface: SurfaceTool, points: Array[Vector3], values: Array[float], tetra: Array) -> void:
	var intersections: Array[Vector3] = []
	for edge in EDGES:
		var first := int(tetra[edge[0]])
		var second := int(tetra[edge[1]])
		if (values[first] > 0.48) == (values[second] > 0.48):
			continue
		var t := (0.48 - values[first]) / (values[second] - values[first])
		intersections.append(points[first].lerp(points[second], t))
	if intersections.size() < 3:
		return
	var center := Vector3.ZERO
	for point in intersections:
		center += point
	center /= intersections.size()
	var normal := _normal(center)
	var horizontal := normal.cross(Vector3.UP if absf(normal.y) < 0.95 else Vector3.RIGHT).normalized()
	var vertical := normal.cross(horizontal)
	intersections.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		var da := a - center
		var db := b - center
		return atan2(da.dot(vertical), da.dot(horizontal)) < atan2(db.dot(vertical), db.dot(horizontal)))
	for index in range(1, intersections.size() - 1):
		var triangle: Array[Vector3] = [intersections[0], intersections[index], intersections[index + 1]]
		var cross := (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])
		if cross.length_squared() < 0.00000001:
			continue
		if cross.dot(normal) > 0:
			triangle.reverse()
		for point in triangle:
			var outward := _normal(point)
			var shade := clampf(0.80 + outward.y * 0.18 - outward.x * 0.06, 0.53, 1.0)
			surface.set_normal(outward)
			surface.set_color(Color(shade, shade, shade))
			surface.add_vertex(point * 1.5)
