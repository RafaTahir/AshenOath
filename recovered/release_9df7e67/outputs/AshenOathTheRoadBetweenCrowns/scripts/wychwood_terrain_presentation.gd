extends RefCounted

const GROUND_STEP := 0.58

static func integrate(root: Node3D) -> bool:
	var ground_visuals: Array[MeshInstance3D] = []
	for candidate in root.find_children("*", "MeshInstance3D", true, false):
		var visual := candidate as MeshInstance3D
		if visual.has_meta("split_ground_size"):
			ground_visuals.append(visual)
	if ground_visuals.size() != 6:
		push_error("Wychwood needs all six split-ground visuals before terrain integration: %d/6" % ground_visuals.size())
		return false
	for index in ground_visuals.size():
		var visual := ground_visuals[index]
		var size: Vector3 = visual.get_meta("split_ground_size")
		var origin: Vector3 = visual.get_meta("split_ground_origin")
		var source_material := visual.material_override as StandardMaterial3D
		if source_material == null or source_material.albedo_texture == null:
			push_error("Wychwood split ground lacks its authored forest material")
			return false
		visual.mesh = _build_patch(size, origin)
		var material := source_material.duplicate() as StandardMaterial3D
		material.resource_name = "WychwoodIntegratedTerrain"
		material.vertex_color_use_as_albedo = true
		visual.material_override = material
		visual.name = "WychwoodIntegratedGround_%d" % index
		visual.set_meta("wychwood_integrated_ground", true)
	return true

static func _build_patch(size: Vector3, origin: Vector3) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := maxi(2, ceili(size.x / GROUND_STEP))
	var rows := maxi(2, ceili(size.z / GROUND_STEP))
	for row in rows:
		var z0 := lerpf(-size.z * 0.5, size.z * 0.5, float(row) / float(rows))
		var z1 := lerpf(-size.z * 0.5, size.z * 0.5, float(row + 1) / float(rows))
		for column in columns:
			var x0 := lerpf(-size.x * 0.5, size.x * 0.5, float(column) / float(columns))
			var x1 := lerpf(-size.x * 0.5, size.x * 0.5, float(column + 1) / float(columns))
			for point in [
				Vector3(x0, size.y * 0.5, z0), Vector3(x1, size.y * 0.5, z0), Vector3(x0, size.y * 0.5, z1),
				Vector3(x1, size.y * 0.5, z0), Vector3(x1, size.y * 0.5, z1), Vector3(x0, size.y * 0.5, z1),
			]:
				var world: Vector3 = point + origin
				surface.set_normal(Vector3.UP)
				surface.set_uv(Vector2(world.x, world.z) * 0.55)
				surface.set_color(_ground_tint(world.x, world.z))
				surface.add_vertex(point)
	# Preserve the short river-bank faces of the original split-ground boxes.
	var half := size * 0.5
	for edge in [
		[Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z), Vector3(half.x, half.y, -half.z), Vector3(-half.x, half.y, -half.z), Vector3(0, 0, -1)],
		[Vector3(half.x, -half.y, half.z), Vector3(-half.x, -half.y, half.z), Vector3(-half.x, half.y, half.z), Vector3(half.x, half.y, half.z), Vector3(0, 0, 1)],
		[Vector3(-half.x, -half.y, half.z), Vector3(-half.x, -half.y, -half.z), Vector3(-half.x, half.y, -half.z), Vector3(-half.x, half.y, half.z), Vector3(-1, 0, 0)],
		[Vector3(half.x, -half.y, -half.z), Vector3(half.x, -half.y, half.z), Vector3(half.x, half.y, half.z), Vector3(half.x, half.y, -half.z), Vector3(1, 0, 0)],
	]:
		for vertex_index in [0, 1, 2, 0, 2, 3]:
			var point: Vector3 = edge[vertex_index]
			surface.set_normal(edge[4])
			surface.set_uv(Vector2(point.x + origin.x, point.y + origin.y))
			surface.set_color(Color(0.86, 0.89, 0.82))
			surface.add_vertex(point)
	return surface.commit()

static func _ground_tint(x: float, z: float) -> Color:
	var base := Color(0.87, 0.94, 0.88)
	var center := sin(z * 0.28) * 0.62 * smoothstep(2.3, 7.0, absf(z))
	var edge_noise := 0.16 * sin(z * 1.37) + 0.08 * sin(z * 2.59)
	var path := 0.0
	if z >= -10.5 and z <= 16.5:
		path = 1.0 - smoothstep(1.05 + edge_noise, 2.75 + edge_noise, absf(x - center))
	var clearing_distance := Vector2(x / 5.4, (z + 6.5) / 3.9).length()
	var clearing := 1.0 - smoothstep(0.58, 1.20, clearing_distance + 0.04 * sin(x * 1.9 + z * 1.4))
	var layby_z := -8.0 + sin(x * 0.48) * 0.33
	var layby := 0.0
	if x >= 0.7 and x <= 11.4:
		layby = (1.0 - smoothstep(0.75, 2.05, absf(z - layby_z))) * smoothstep(0.7, 2.2, x)
	var wear := maxf(path * 0.72, maxf(clearing * 0.78, layby * 0.64))
	# Pale worn earth separates the occupied clearing and clue route from the
	# cooler forest floor without new geometry, lights or collision changes.
	var earth := Color(0.86, 0.71, 0.51)
	return base.lerp(earth, wear)
