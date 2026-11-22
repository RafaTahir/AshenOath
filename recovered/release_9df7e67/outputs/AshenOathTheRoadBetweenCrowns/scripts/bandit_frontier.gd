extends RefCounted

const MESH_PATH := "res://assets_external/environment/forest/BanditFrontier_Authored.res"
const X_KNOTS := [-68.0, -44.0, -30.0, -22.0, -12.0, 0.0, 12.0, 22.0, 31.0, 46.0, 70.0]
const Z_KNOTS := [-88.0, -62.0, -44.0, -30.0, -19.0, -8.0, 6.0, 19.0, 31.0, 46.0, 62.0]
# The Vargan road follows a low northeast pass; the southwest returns to marsh.
const HEIGHTS := [
	[7.0, 9.0, 7.0, 5.2, 3.1, 1.7, 0.6, 1.8, 4.3, 6.5, 8.0],
	[5.5, 7.1, 5.5, 3.6, 2.0, 0.8, 0.3, 1.2, 3.0, 4.7, 6.2],
	[3.8, 5.2, 3.7, 2.2, 0.7, 0.2, 0.1, 0.6, 1.5, 3.5, 4.6],
	[2.0, 3.6, 1.9, 0.8, 0.2, 0.0, 0.0, 0.2, 0.9, 2.2, 3.5],
	[1.8, 2.8, 0.6, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 1.6, 3.0],
	[1.4, 2.3, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 2.0, 2.6],
	[1.0, 1.8, 0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 1.7, 2.4],
	[0.9, 1.2, 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 1.3, 2.2],
	[1.0, 1.6, 0.5, 0.1, 0.0, 0.0, 0.1, 0.3, 0.8, 1.8, 2.8],
	[1.5, 2.3, 0.9, 0.3, 0.1, 0.2, 0.6, 1.0, 1.8, 2.7, 3.8],
	[2.0, 3.1, 1.6, 0.7, 0.3, 0.7, 1.2, 1.8, 2.4, 3.7, 4.6],
]

static func height_at(x: float, z: float) -> float:
	var column := 0
	var row := 0
	while column < X_KNOTS.size() - 2 and x > X_KNOTS[column + 1]:
		column += 1
	while row < Z_KNOTS.size() - 2 and z > Z_KNOTS[row + 1]:
		row += 1
	var u := clampf(inverse_lerp(X_KNOTS[column], X_KNOTS[column + 1], x), 0, 1)
	var v := clampf(inverse_lerp(Z_KNOTS[row], Z_KNOTS[row + 1], z), 0, 1)
	return lerpf(lerpf(HEIGHTS[row][column], HEIGHTS[row][column + 1], u), lerpf(HEIGHTS[row + 1][column], HEIGHTS[row + 1][column + 1], u), v)

static func tree_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for point in [
		Vector2(-20, -24), Vector2(-9, -26), Vector2(20, -25), Vector2(31, -27),
		Vector2(-25, -34), Vector2(-13, -39), Vector2(24, -37), Vector2(36, -40),
		Vector2(-32, -49), Vector2(-17, -54), Vector2(18, -51), Vector2(35, -57),
		Vector2(-29, -13), Vector2(-37, -18), Vector2(29, -9), Vector2(38, -17),
		Vector2(-28, 2), Vector2(-37, 9), Vector2(29, 7), Vector2(41, 10),
		Vector2(-29, 24), Vector2(-38, 30), Vector2(28, 25), Vector2(40, 33),
	]:
		result.append(Vector3(point.x, height_at(point.x, point.y), point.y))
	return result

static func build(context: ZoneBuildContext) -> void:
	var mesh := load(MESH_PATH) as ArrayMesh
	var tree := context.forest_tree_mesh("res://assets_external/environment/forest/TwistedTree_2.obj")
	if mesh == null or mesh.get_surface_count() != 2 or tree == null:
		push_error("Bandit Road requires its adjoining ground and accepted forest source")
		return
	var layer := Node3D.new()
	layer.name = "BanditAuthoredFrontier"
	var ground := MeshInstance3D.new()
	ground.name = "BanditAdjoiningGroundAndWorkLanes"
	ground.mesh = mesh
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.add_child(ground)
	var positions := tree_positions()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = tree
	multimesh.instance_count = 16 if context.quality_preset() == "potato" else positions.size()
	var batch := MultiMeshInstance3D.new()
	batch.name = "BanditDistantTreeBatch"
	batch.multimesh = multimesh
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.visibility_range_end = 82.0
	batch.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	layer.add_child(batch)
	var bounds := tree.get_aabb()
	var bottom := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	for index in multimesh.instance_count:
		var height := 7.8 + float(index % 6) * 0.56
		var basis := Basis(Vector3.UP, float(index) * 1.71).scaled(Vector3.ONE * height / maxf(bounds.size.y, 0.01))
		multimesh.set_instance_transform(index, Transform3D(basis, positions[index] - basis * bottom))
	context.add_node(layer)
