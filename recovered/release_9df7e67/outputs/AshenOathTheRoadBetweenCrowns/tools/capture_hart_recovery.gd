extends SceneTree

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func():
		push_error("Hart capture timed out")
		quit(1))
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.settings.set_quality_preset("balanced")
	# Controlled scene setup, deliberately not player-route acceptance.
	game._load_zone("hart_glade", Vector3(0, 1, 1))
	for frame in 90:
		await process_frame
	var witness: Node3D = game.zone_root.find_child("WhiteHartWitnessDisplay", true, false)
	var passed := witness != null
	var tree_batches: Array = game.zone_root.find_children("AuthoredTreeBatch_*", "MultiMeshInstance3D", true, false)
	if tree_batches.is_empty():
		passed = false
		push_error("Balanced glade did not use its authored tree meshes")
	for batch in tree_batches:
		for index in batch.multimesh.instance_count:
			var bounds: AABB = batch.multimesh.get_instance_transform(index) * batch.multimesh.mesh.get_aabb()
			if bounds.size.y < 4.0 or bounds.size.y > 6.5 or absf(bounds.position.y) > 0.01:
				passed = false
				push_error("Authored tree batch is ungrounded or outside its height range")
	var plinth: MeshInstance3D = game.zone_root.find_child("WhiteHartMemoryPlinth", true, false)
	if plinth == null or absf(plinth.position.y + plinth.mesh.height * 0.5) > 0.001:
		passed = false
		push_error("Hart inlay must be flush with arena floor")
	if game.zone_root.find_child("HartGladeMoonlitMarker", true, false) != null:
		passed = false
		push_error("Decorative pole intersects Hart presentation")
	if witness == null:
		push_error("Hart witness missing from full scene")
	else:
		var skeleton: Skeleton3D = witness.get_node("HartWitnessAnimation").get_skeleton()
		var forward: Vector3 = skeleton.global_transform.basis * (skeleton.get_bone_global_rest(skeleton.find_bone("Head")).origin - skeleton.get_bone_global_rest(skeleton.find_bone("Body")).origin)
		if forward.z <= 0.0:
			passed = false
			push_error("Hart witness faces away from the southern arrival")
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.position = witness.global_position + Vector3(6, 3.2, 6)
		camera.look_at(witness.global_position + Vector3(0, 1.9, 0))
		camera.current = true
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1280, 720)
		game.hud.hide()
		game.set_process(false)
		for frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var captured := root.get_texture().get_image()
		if captured.get_size() != Vector2i(1280, 720):
			passed = false
			push_error("Hart capture must render at native 1280x720")
		var error := captured.save_png("D:/Temp/AshenOath/Hart_glade_diagnostic.png")
		if error != OK:
			passed = false
			push_error("Hart screenshot write failed: %s" % error_string(error))
		print("HART GLADE DIAGNOSTIC CAPTURE: ", error)
		camera.free()
	game.prepare_resource_shutdown()
	for frame in int(game.ZONE_RETIRE_FRAMES) + 4:
		await process_frame
	game.queue_free()
	for frame in 8:
		await process_frame
	quit(0 if passed else 1)
