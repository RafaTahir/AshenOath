extends RefCounted

const MESH_PATH := "res://assets_external/environment/forest/HartWoodland_Authored.res"
const X_KNOTS := [-68.0, -44.0, -30.0, -22.5, -12.0, 0.0, 12.0, 22.5, 30.0, 46.0, 70.0]
const Z_KNOTS := [-88.0, -65.0, -44.0, -29.0, -19.5, -8.0, 6.0, 19.5, 30.0, 45.0, 60.0]
const HEIGHTS := [
	[6.0, 8.0, 5.0, 4.0, 2.8, 1.4, 2.6, 4.2, 5.8, 7.0, 5.0],
	[4.0, 6.5, 4.6, 2.8, 1.5, 0.7, 1.4, 2.9, 4.2, 5.5, 4.0],
	[2.8, 4.7, 2.9, 1.4, 0.6, 0.2, 0.4, 1.2, 2.8, 4.3, 3.0],
	[1.8, 3.2, 1.3, 0.6, 0.15, 0.0, 0.2, 0.7, 1.5, 2.7, 3.6],
	[1.4, 2.5, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.6, 1.8, 2.5],
	[1.1, 2.0, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 2.0, 2.7],
	[1.8, 2.8, 0.6, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 1.6, 2.4],
	[1.2, 2.3, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 1.3, 2.0],
	[1.7, 2.7, 1.0, 0.4, 0.1, 0.0, 0.1, 0.3, 0.8, 2.0, 2.8],
	[2.3, 3.6, 1.8, 0.8, 0.3, 0.1, 0.2, 0.6, 1.5, 2.7, 3.8],
	[3.0, 4.2, 2.6, 1.2, 0.6, 0.2, 0.5, 1.1, 2.0, 3.6, 4.5],
]

static func height_at(x: float, z: float) -> float:
	var column := 0
	var row := 0
	while column < X_KNOTS.size() - 2 and x > X_KNOTS[column + 1]:
		column += 1
	while row < Z_KNOTS.size() - 2 and z > Z_KNOTS[row + 1]:
		row += 1
	var u := clampf(inverse_lerp(X_KNOTS[column], X_KNOTS[column + 1], x), 0.0, 1.0)
	var v := clampf(inverse_lerp(Z_KNOTS[row], Z_KNOTS[row + 1], z), 0.0, 1.0)
	return 0.0265 + lerpf(lerpf(HEIGHTS[row][column], HEIGHTS[row][column + 1], u), lerpf(HEIGHTS[row + 1][column], HEIGHTS[row + 1][column + 1], u), v)

static func tree_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	# Interleaved stands frame the witness, not a uniformly spaced tree wall.
	for point in [
		Vector2(-9, -24), Vector2(11, -25), Vector2(-22, -25), Vector2(23, -27),
		Vector2(-4, -32), Vector2(5, -35), Vector2(-16, -36), Vector2(18, -39),
		Vector2(-28, -34), Vector2(30, -36), Vector2(-11, -47), Vector2(14, -50),
		Vector2(-32, -48), Vector2(34, -47), Vector2(-3, -57), Vector2(7, -61),
		Vector2(-29, -14), Vector2(30, -10), Vector2(-37, -22), Vector2(39, -19),
		Vector2(-28, 2), Vector2(29, 7), Vector2(-37, 9), Vector2(39, 12),
		Vector2(-27, 22), Vector2(28, 25), Vector2(-15, 31), Vector2(17, 34),
		Vector2(-40, 29), Vector2(41, 32), Vector2(-9, 44), Vector2(11, 47),
	]:
		result.append(Vector3(point.x, height_at(point.x, point.y), point.y))
	return result

static func build(context: ZoneBuildContext) -> void:
	var mesh := load(MESH_PATH) as ArrayMesh
	var tree := context.forest_tree_mesh("res://assets_external/environment/forest/TwistedTree_2.obj")
	if mesh == null or mesh.get_surface_count() != 2 or tree == null:
		push_error("Hart Glade requires its fitted woodland ground and approved tree source")
		return
	var layer := Node3D.new()
	layer.name = "HartAuthoredWoodland"
	var ground := MeshInstance3D.new()
	ground.name = "HartAdjoiningWoodlandGround"
	ground.mesh = mesh
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.add_child(ground)
	var positions := tree_positions()
	var count := 20 if context.quality_preset() == "potato" else positions.size()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = tree
	multimesh.instance_count = count
	var batch := MultiMeshInstance3D.new()
	batch.name = "HartWoodlandTreeBatch"
	batch.multimesh = multimesh
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.visibility_range_end = 82.0
	batch.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	layer.add_child(batch)
	var bounds := tree.get_aabb()
	var bottom_center := bounds.position + Vector3(bounds.size.x * 0.5, 0, bounds.size.z * 0.5)
	for index in count:
		var height := 8.4 + float(index % 6) * 0.62
		var basis := Basis(Vector3.UP, float(index) * 1.71).scaled(Vector3.ONE * height / maxf(bounds.size.y, 0.01))
		multimesh.set_instance_transform(index, Transform3D(basis, positions[index] - basis * bottom_center))
	context.add_node(layer)
