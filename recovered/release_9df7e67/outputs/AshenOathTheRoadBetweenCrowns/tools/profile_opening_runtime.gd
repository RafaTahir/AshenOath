extends SceneTree

class ProfileGame extends "res://scripts/game.gd":
	var measuring := false
	var samples: Dictionary = {}
	func record(key: String, started: int) -> void:
		if not measuring:
			return
		var row: Dictionary = samples.get(key, {"calls": 0, "total_us": 0, "max_us": 0})
		var elapsed := Time.get_ticks_usec() - started
		row.calls += 1
		row.total_us += elapsed
		row.max_us = maxi(row.max_us, elapsed)
		samples[key] = row
	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super._process(delta)
		record("game_process_inclusive", started)
	func _keep_player_in_world() -> void:
		var started := Time.get_ticks_usec()
		super._keep_player_in_world()
		record("world_safety", started)
	func _update_interaction_focus() -> void:
		var started := Time.get_ticks_usec()
		super._update_interaction_focus()
		record("interaction_focus", started)
	func _update_compass() -> void:
		var started := Time.get_ticks_usec()
		super._update_compass()
		record("compass", started)
	func _update_tutorial_prompts() -> void:
		var started := Time.get_ticks_usec()
		super._update_tutorial_prompts()
		record("tutorial", started)
	func _update_target_lock_hud() -> void:
		var started := Time.get_ticks_usec()
		super._update_target_lock_hud()
		record("target_hud", started)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	Engine.max_fps = 60
	var game := ProfileGame.new()
	root.add_child(game)
	game.settings.set_quality_preset("balanced")
	game._on_launch_accepted()
	var deadline := Time.get_ticks_msec() + 30000
	while not game.route_zone_cache.has("greyfen") and Time.get_ticks_msec() < deadline:
		await process_frame
	game._new_game()
	deadline = Time.get_ticks_msec() + 45000
	while game.zone_root == null or not game.zone_root.get_meta("opening_detail_complete", false):
		if Time.get_ticks_msec() >= deadline:
			push_error("Profile setup timed out")
			game.prepare_resource_shutdown()
			quit(1)
			return
		await process_frame
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	game.measuring = true
	var frames: Array[Dictionary] = []
	deadline = Time.get_ticks_msec() + 8000
	var previous := Time.get_ticks_usec()
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append({"frame_ms": (now - previous) / 1000.0,
			"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),
			"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())})
		previous = now
	game.measuring = false
	var output := {"scope": "diagnostic stationary hydrated Greyfen; not performance or real-route acceptance",
		"render_timing_note": "Renderer samples may be delayed; GPU zero means unavailable, not free rendering.",
		"controller": game.samples, "frames": frames}
	var file := FileAccess.open("D:/Temp/AshenOath/opening_runtime_profile.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	print("OPENING RUNTIME PROFILE: " + JSON.stringify(game.samples))
	game.prepare_resource_shutdown()
	for frame in range(12):
		await process_frame
	game.finalize_resource_shutdown()
	for frame in range(4):
		await process_frame
	game.queue_free()
	await process_frame
	quit()
