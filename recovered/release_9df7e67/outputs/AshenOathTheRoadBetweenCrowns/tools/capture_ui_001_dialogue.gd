extends SceneTree

const OUTPUT := "res://Development_Gallery/screenshots/UI_001_Anwen_Dialogue_720p.png"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("UI-001 dialogue capture requires a graphical renderer")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._new_game()
	var deadline := Time.get_ticks_msec() + 30000
	while (game.zone_root == null or game.current_zone_id != "greyfen") and Time.get_ticks_msec() < deadline:
		await process_frame
	if game.zone_root == null:
		push_error("Greyfen did not load for UI-001 dialogue capture")
		await _shutdown(game)
		quit(1)
		return
	var anwen: Node3D = game.zone_root.find_child("sister_anwen", true, false)
	if anwen == null:
		push_error("Sister Anwen is unavailable for dialogue capture")
		await _shutdown(game)
		quit(1)
		return
	game.player.global_position = anwen.global_position + Vector3(0, 0.16, 2.2)
	game.player.velocity = Vector3.ZERO
	for index in range(30):
		await process_frame
	game._handle_interaction(anwen)
	for index in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_viewport().get_texture().get_image()
	var valid: bool = game.hud.dialogue_layer.visible and frame != null and frame.get_size() == Vector2i(1280, 720)
	if valid:
		valid = frame.save_png(ProjectSettings.globalize_path(OUTPUT)) == OK
	if not valid:
		push_error("UI-001 dialogue frame is missing or incorrectly sized")
	else:
		print("UI-001 DIALOGUE CAPTURE: PASS " + OUTPUT)
	game.get_tree().paused = false
	await _shutdown(game)
	quit(0 if valid else 1)

func _shutdown(game: Node) -> void:
	game.prepare_resource_shutdown()
	for index in range(20):
		await process_frame
	game.finalize_resource_shutdown()
	for index in range(12):
		await process_frame
	game.queue_free()
	await process_frame
	RenderingServer.force_sync()
