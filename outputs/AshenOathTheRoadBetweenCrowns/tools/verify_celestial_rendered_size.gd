extends SceneTree

const Director = preload("res://scripts/visual_director.gd")
var failures: Array[String] = []

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Celestial size requires rendered pixels")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	var camera := Camera3D.new()
	camera.fov = 63.0
	camera.current = true
	root.add_child(camera)
	var director := Director.new()
	root.add_child(director)
	await process_frame
	director.apply_zone("greyfen")
	for state in [[720.0, "sun"], [60.0, "moon"]]:
		director.force_time_update = true
		director.set_time(state[0], "fixture")
		for _frame in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		var disc: MeshInstance3D = director.sun_disc if state[1] == "sun" else director.moon_disc
		var center := camera.unproject_position(disc.global_position)
		var right := camera.unproject_position(disc.global_position + camera.global_basis.x * disc.mesh.size.x * disc.scale.x * 0.5)
		var expected := absf(right.x - center.x) * 2.0
		var frame: Image = root.get_texture().get_image()
		var y := int(round(center.y))
		var bright_width := 0
		for x in range(int(center.x - expected), int(center.x + expected) + 1):
			if x >= 0 and x < frame.get_width() and y >= 0 and y < frame.get_height():
				var color := frame.get_pixel(x, y)
				if color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722 > 0.65:
					bright_width += 1
		if bright_width < expected * 0.60 or bright_width > expected * 1.05:
			failures.append("%s rendered diameter %d does not match projected %.2f" % [state[1], bright_width, expected])
		print("CELESTIAL_SIZE %s expected_px=%.2f bright_px=%d" % [state[1], expected, bright_width])
	director.clear_runtime_caches()
	director.free()
	camera.free()
	await process_frame
	RenderingServer.force_sync()
	for failure in failures:
		push_error(failure)
	print("CELESTIAL RENDERED SIZE: %s (pixels, NOT world/route/performance approval)" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
