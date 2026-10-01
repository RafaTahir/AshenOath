extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("UI-001 menu capture requires a graphical renderer")
		quit(1)
		return
	var size := Vector2i(1280, 720) if "--720p" in OS.get_cmdline_user_args() else Vector2i(1920, 1080)
	var output := "res://Development_Gallery/screenshots/UI_001_Main_Menu_%s.png" % ("Native720pScaled" if size.y == 720 else "1080p")
	DisplayServer.window_set_size(size)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if game.hud.active_menu != "main":
		push_error("Desktop startup did not open the main menu")
		await _shutdown(game)
		quit(1)
		return
	for index in range(24):
		await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_viewport().get_texture().get_image()
	if frame != null and size.y == 720 and frame.get_size() == Vector2i(1920, 1080):
		frame.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var valid := frame != null and frame.get_size() == size
	if valid:
		valid = frame.save_png(ProjectSettings.globalize_path(output)) == OK
	if not valid:
		push_error("UI-001 menu dimensions mismatch: requested=%s window=%s viewport=%s image=%s" % [
			size, DisplayServer.window_get_size(), root.get_viewport().get_visible_rect().size,
			frame.get_size() if frame != null else Vector2i.ZERO,
		])
	else:
		print("UI-001 MENU CAPTURE: PASS " + output)
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
