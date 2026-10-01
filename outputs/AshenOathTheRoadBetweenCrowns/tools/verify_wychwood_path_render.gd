extends SceneTree

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Wychwood path render verification requires a graphical renderer")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for index in range(2):
		await process_frame
	game.call("_new_game")
	if not await _wait_for_zone(game, "greyfen"):
		await _release(game)
		quit(1)
		return
	game.call("_load_zone", "wychwood", Vector3(0, 1, 12.5))
	if not await _wait_for_zone(game, "wychwood"):
		await _release(game)
		quit(1)
		return
	var grounds: Array[Node] = game.zone_root.find_children("WychwoodIntegratedGround_*", "MeshInstance3D", true, false)
	if grounds.size() != 6:
		push_error("Wychwood integrated route ground was not visibly published")
		await _release(game)
		quit(1)
		return
	game.player.velocity = Vector3.ZERO
	game.camera_rig.set_process(false)
	game.camera_rig.camera.look_at_from_position(Vector3(0.0, 3.0, 16.5), Vector3(0, 1.25, 12.0), Vector3.UP)
	var visible_frame := await _capture_frame()
	for ground in grounds:
		(ground.material_override as StandardMaterial3D).vertex_color_use_as_albedo = false
	var untinted_frame := await _capture_frame()
	for ground in grounds:
		(ground.material_override as StandardMaterial3D).vertex_color_use_as_albedo = true
	var difference := 0
	for y in range(560, 700, 4):
		for x in range(320, 960, 4):
			var a: Color = visible_frame.get_pixel(x, y)
			var b: Color = untinted_frame.get_pixel(x, y)
			difference += absi(int(a.r8) - int(b.r8)) + absi(int(a.g8) - int(b.g8)) + absi(int(a.b8) - int(b.b8))
	print("WYCHWOOD INTEGRATED PATH RENDER: zone=%s frame=%s road_delta=%d" % [game.current_zone_id, visible_frame.get_size(), difference])
	if visible_frame.get_size() != Vector2i(1280, 720) or difference <= 50000:
		push_error("Wychwood path did not affect the rendered gameplay frame")
	await _release(game)
	quit(0 if visible_frame.get_size() == Vector2i(1280, 720) and difference > 50000 else 1)

func _capture_frame() -> Image:
	for index in range(36):
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()

func _wait_for_zone(game: Node, zone_id: String) -> bool:
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		var detail_ready := zone_id != "greyfen" or (game.zone_root != null and bool(game.zone_root.get_meta("opening_detail_complete", false)))
		if game.game_started and game.player != null and game.zone_root != null and game.current_zone_id == zone_id and not game.zone_transition_pending and not game.zone_load_request_pending and not game.player.transition_locked and detail_ready:
			return true
		await process_frame
	push_error("Wychwood path render verification timed out waiting for playable %s" % zone_id)
	return false

func _release(game: Node) -> void:
	game.prepare_resource_shutdown()
	for index in range(int(game.ZONE_RETIRE_FRAMES) + 4):
		await process_frame
	game.queue_free()
	await process_frame
	RenderingServer.force_sync()
