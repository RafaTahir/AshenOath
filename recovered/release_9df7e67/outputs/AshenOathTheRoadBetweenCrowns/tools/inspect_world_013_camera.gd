extends SceneTree

const CAMERA_POSITION := Vector3(5.6, 3.0, 10.5)
const FOCUS_POSITION := Vector3(0.0, 0.9, 4.0)

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		push_error("Main scene unavailable")
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	game.quests.start_quest("main_road_of_crows")
	game.quests.complete_objective("main_road_of_crows", "speak_anwen")
	game.call("_load_zone", "wychwood", Vector3(0, 1, 12.5))
	await _frames(24)
	var rows: Array[Dictionary] = []
	for node in game.zone_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null or not mesh_node.visible:
			continue
		var bounds: AABB = mesh_node.global_transform * mesh_node.mesh.get_aabb()
		var distance := bounds.get_center().distance_to(CAMERA_POSITION)
		var intersects_view := bounds.intersects_segment(CAMERA_POSITION, FOCUS_POSITION) != null
		if distance <= 9.0 or intersects_view:
			rows.append({
				"path": str(mesh_node.get_path()),
				"distance": distance,
				"intersects": intersects_view,
				"position": mesh_node.global_position,
				"bounds_position": bounds.position,
				"bounds_size": bounds.size,
			})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.intersects) != bool(b.intersects):
			return bool(a.intersects)
		return float(a.distance) < float(b.distance)
	)
	for row in rows:
		print("WORLD-013 CAMERA owner=%s intersects=%s distance=%.2f position=%s bounds=%s size=%s" % [
			row.path, str(row.intersects), row.distance, row.position,
			row.bounds_position, row.bounds_size,
		])
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
	game.queue_free()
	await _frames(8)
	RenderingServer.force_sync()
	quit(0)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
