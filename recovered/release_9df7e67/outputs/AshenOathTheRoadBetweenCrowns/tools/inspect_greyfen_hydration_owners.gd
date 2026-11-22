extends SceneTree

func _initialize() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Main scene unavailable")
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if game.game_started and game.zone_root != null and game.opening_detail_stage_index >= 1:
			break
		await process_frame
	if not game.game_started or game.zone_root == null or game.opening_detail_stage_index < 1:
		push_error("Greyfen gameplay visuals were not staged within 30 seconds")
		quit(1)
		return
	var buckets: Dictionary = {}
	for raw_node in game.zone_root.find_children("*", "", true, false):
		var bucket := int(raw_node.get_meta("opening_visual_bucket", -1))
		if bucket < 0:
			continue
		if not buckets.has(bucket):
			buckets[bucket] = []
		var entry := {"node": str(raw_node.get_path()), "type": raw_node.get_class()}
		if raw_node is MeshInstance3D:
			var mesh_node := raw_node as MeshInstance3D
			entry["mesh"] = mesh_node.mesh.resource_path if mesh_node.mesh != null else ""
			entry["surfaces"] = mesh_node.mesh.get_surface_count() if mesh_node.mesh != null else 0
			var materials: Array[String] = []
			for index in range(int(entry["surfaces"])):
				var material := mesh_node.get_active_material(index)
				materials.append("%s:%s" % [material.get_class(), material.resource_path] if material != null else "null")
			entry["materials"] = materials
		buckets[bucket].append(entry)
	for bucket in buckets.keys():
		print("OPENING_BUCKET %d %s" % [bucket, JSON.stringify(buckets[bucket])])
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	for _index in range(20):
		await process_frame
	if game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
	for _index in range(12):
		await process_frame
	root.remove_child(game)
	game.free()
	RenderingServer.force_sync()
	print("GREYFEN HYDRATION OWNER INVENTORY: PASS")
	quit(0)
