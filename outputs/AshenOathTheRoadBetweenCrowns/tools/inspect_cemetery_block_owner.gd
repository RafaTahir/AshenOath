extends SceneTree

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	for _index in range(16):
		await process_frame
	var camera: Camera3D = game.camera_rig.camera
	game.camera_rig.set_process(false)
	camera.look_at_from_position(Vector3(10.2, 3.0, 13.5), Vector3(14.8, 0.9, 8.2), Vector3.UP)
	for _index in range(3):
		await process_frame
	var space: PhysicsDirectSpaceState3D = game.zone_root.get_world_3d().direct_space_state
	for pixel in [Vector2(120, 290), Vector2(150, 300), Vector2(210, 325), Vector2(260, 350)]:
		var start := camera.project_ray_origin(pixel)
		var query := PhysicsRayQueryParameters3D.create(start, start + camera.project_ray_normal(pixel) * 80.0)
		var exclusions: Array[RID] = []
		for layer in range(6):
			query.exclude = exclusions
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				break
			var owner: Object = hit.get("collider")
			var shape_path := "none"
			if owner is CollisionObject3D:
				var shape_owner_id := (owner as CollisionObject3D).shape_find_owner(int(hit.get("shape", -1)))
				var shape_node: Object = (owner as CollisionObject3D).shape_owner_get_owner(shape_owner_id)
				shape_path = str(shape_node.get_path()) if shape_node is Node else "none"
			print("CEMETERY BLOCK RAY pixel=%s layer=%d position=%s collider=%s shape=%s" % [pixel, layer, hit.get("position"), owner.get_path() if owner is Node else "none", shape_path])
			if owner is CollisionObject3D:
				exclusions.append((owner as CollisionObject3D).get_rid())
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		for _index in range(int(game.ZONE_RETIRE_FRAMES) + 4):
			await process_frame
	game.queue_free()
	for _index in range(8):
		await process_frame
	quit()
