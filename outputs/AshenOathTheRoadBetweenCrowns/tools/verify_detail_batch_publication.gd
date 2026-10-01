extends SceneTree

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("DETAIL BATCH ASSERTION: " + message)

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		print("DETAIL BATCH PUBLICATION: FAIL - graphical renderer required for MultiMesh readback")
		quit(1)
		return
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.current_zone_id = "record_hall"
	game.zone_root = Node3D.new()
	game.add_child(game.zone_root)
	game.environment_batches_flushed = false
	var position := Vector3(2, 1, 3)
	var size := Vector3(0.2, 1.3, 0.4)
	var marker: MeshInstance3D = game._make_visual_box("BatchProbe", position, size, Color(0.2, 0.1, 0.1))
	marker.rotation.y = 0.4
	var expected := Transform3D(marker.basis.scaled(size), position)
	check(marker.mesh == null and marker.material_override == null, "pending marker must not bind render geometry")
	await process_frame
	game._flush_environment_batches()
	var batches: Array[Node] = game.zone_root.find_children("AuthoredDetailBatch*", "MultiMeshInstance3D", true, false)
	check(batches.size() == 1, "expected one published batch, got %d" % batches.size())
	if batches.size() == 1:
		var batch := batches[0] as MultiMeshInstance3D
		check(batch.multimesh.instance_count == 1 and batch.material_override != null, "published mesh/material missing")
		check(batch.multimesh.get_instance_transform(0).is_equal_approx(expected), "published transform changed")
	await process_frame
	await process_frame
	check(not is_instance_valid(marker), "temporary marker was not retired")
	var immediate: MeshInstance3D = game._make_visual_box("ImmediateProbe", position, size, Color(0.2, 0.1, 0.1))
	check(immediate.mesh != null and immediate.material_override != null, "immediate geometry missing")
	check(immediate.scale.is_equal_approx(size), "immediate geometry has wrong size")
	game._clear_environment_batch_buffers()
	game.current_zone_id = "greyfen"
	game.environment_batches_flushed = false
	var colors := [Color(0.1, 0.1, 0.1), Color(0.3, 0.2, 0.2), Color(0.8, 0.2, 0.1)]
	for index in colors.size():
		game._make_visual_box("ColorProbe", Vector3(index, 1, -8), Vector3.ONE, colors[index])
	game._make_fake_light_pool("RoadLanternPool", Vector3(0, 0.035, -8), Vector3(1.55, 0.022, 1.05), Color(0.32, 0.135, 0.045))
	game._flush_environment_batches()
	var pools: Array[Node] = game.zone_root.find_children("AuthoredDetailBatch_night_*", "MultiMeshInstance3D", true, false)
	check(pools.size() == 1, "night pools must not share daytime scenery batches")
	if pools.size() == 1:
		check(pools[0].get_meta("night_only_geometry", false) and pools[0].multimesh.instance_count == 1, "pool state or geometry lost in batching")
	var colored: Array[Node] = game.zone_root.find_children("AuthoredDetailBatch_instance_colors*", "MultiMeshInstance3D", true, false)
	check(colored.size() == 1, "compatible flat colors should share one batch")
	if colored.size() == 1:
		var mesh: MultiMesh = colored[0].multimesh
		check(mesh.instance_count == 3 and mesh.use_colors, "instance colors not enabled")
		for index in colors.size():
			var actual := mesh.get_instance_color(index)
			var expected_color: Color = colors[index]
			var error := maxf(absf(actual.r - expected_color.r), maxf(absf(actual.g - expected_color.g), absf(actual.b - expected_color.b)))
			print("DETAIL COLOR expected=%s stored=%s error=%s" % [expected_color, actual, error])
			check(error <= 1.0 / 255.0 and actual.a == expected_color.a, "authored detail color exceeds storage precision")
	game.prepare_resource_shutdown()
	for frame in 20:
		await process_frame
	game.finalize_resource_shutdown()
	for frame in 4:
		await process_frame
	game.queue_free()
	for frame in 8:
		await process_frame
	print("DETAIL BATCH PUBLICATION: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
