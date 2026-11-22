extends RefCounted

const MESH_PATH := "res://assets_external/environment/forest/GreyfenFrontier_Authored.res"
const X_KNOTS := [-64.0, -43.0, -26.0, -21.0, -12.0, -5.0, 0.0, 5.0, 12.0, 21.0, 29.0, 44.0, 66.0]
const Z_KNOTS := [-94.0, -67.0, -46.0, -31.0, -23.0, -17.0, -10.0, 0.0, 10.0, 17.0, 32.0, 47.0]
# Authored adjoining land: a low north-road valley and uneven wooded shoulders.
# The village's existing physical surface, river, bounds and exits are untouched.
const HEIGHTS := [
	[5.0, 7.0, 6.0, 4.8, 3.2, 1.8, 1.0, 1.5, 2.8, 5.4, 6.0, 7.2, 5.0],
	[3.5, 6.2, 4.0, 2.7, 1.3, 0.8, 0.4, 0.7, 1.8, 3.0, 4.5, 5.5, 4.0],
	[2.0, 4.4, 3.0, 1.5, 0.8, 0.3, 0.1, 0.3, 1.1, 2.4, 3.5, 4.1, 3.0],
	[1.5, 3.0, 1.4, 0.7, 0.25, 0.05, 0.0, 0.05, 0.4, 1.2, 2.1, 2.8, 3.5],
	[1.0, 1.8, 0.6, 0.15, 0.0, 0.0, 0.0, 0.0, 0.2, 0.4, 1.0, 2.0, 2.6],
	[0.6, 1.0, 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 1.4, 2.0],
	[0.4, 0.7, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.6, 1.5, 2.8],
	[0.3, 0.6, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.7, 1.2, 2.0],
	[0.5, 0.8, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 1.5, 2.6],
	[0.8, 1.0, 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.7, 1.8, 2.0],
	[1.4, 2.0, 0.8, 0.3, 0.0, 0.0, 0.0, 0.0, 0.2, 0.7, 1.5, 2.6, 3.4],
	[2.0, 3.3, 1.3, 0.5, 0.2, 0.1, 0.0, 0.2, 0.6, 1.4, 2.0, 3.2, 4.0],
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
	return lerpf(lerpf(HEIGHTS[row][column], HEIGHTS[row][column + 1], u), lerpf(HEIGHTS[row + 1][column], HEIGHTS[row + 1][column + 1], u), v)

static func tree_positions(count: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	# Each quadrant belongs to this surface; the north stands leave the
	# destination corridor open and the east copse frames the cemetery.
	for index in count:
		var position: Vector3
		var north_count := count * 2 / 5
		var east_count := count / 5
		var west_count := count / 5
		if index < north_count:
			var side := -1.0 if index % 2 == 0 else 1.0
			var rank := index / 8
			position = Vector3(side * (7.5 + float(index % 4) * 7.5 + rank * 2.0), 0, -23.5 - float(rank) * 10.0 - float(index % 3) * 2.3)
		elif index < north_count + east_count:
			var local_index := index - north_count
			position = Vector3(28.0 + float(local_index % 2) * 10.0, 0, -20.0 + float(local_index / 2) * 12.0)
		elif index < north_count + east_count + west_count:
			var local_index := index - north_count - east_count
			position = Vector3(-28.0 - float(local_index % 2) * 10.0, 0, -17.0 + float(local_index / 2) * 12.0)
		else:
			var local_index := index - north_count - east_count - west_count
			position = Vector3(-24.0 + float(local_index % 4) * 15.0, 0, 26.0 + float(local_index / 4) * 9.0)
		position.y = height_at(position.x, position.z)
		result.append(position)
	return result

static func build(context: ZoneBuildContext) -> void:
	var mesh := ResourceLoader.load(MESH_PATH) as ArrayMesh
	if mesh == null or mesh.get_surface_count() != 2:
		push_error("Greyfen requires its authored adjoining landscape")
		return
	var layer := Node3D.new()
	layer.name = "GreyfenAuthoredFrontier"
	layer.set_meta("world_visual_role", "authored_adjoining_landscape")
	var ground := MeshInstance3D.new()
	ground.name = "VillageAdjoiningLandscape"
	ground.mesh = mesh
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.add_child(ground)
	context.add_node(layer)
