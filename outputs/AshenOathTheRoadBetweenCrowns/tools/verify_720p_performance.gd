extends SceneTree

var samples: Array[float] = []

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("720p performance verifier requires the graphical Compatibility renderer")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	# Measure renderer throughput rather than Windows compositor cadence. Browser
	# presentation remains VSync-paced in the exported game.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("main scene failed to load")
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	game.settings.set_quality_preset("balanced")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _frames(30)
	var transition_start := Time.get_ticks_msec()
	game.call("_load_zone", "wychwood", Vector3(0, 1, 8))
	var cold_transition_ms := Time.get_ticks_msec() - transition_start
	game.call("_load_zone", "greyfen", Vector3(0, 1, -13))
	transition_start = Time.get_ticks_msec()
	game.call("_load_zone", "wychwood", Vector3(0, 1, 8))
	var warm_transition_ms := Time.get_ticks_msec() - transition_start
	await _frames(30)
	var sample_start := Time.get_ticks_msec()
	var bucket_start := sample_start
	var total_frames := 0
	var bucket_frames := 0
	while Time.get_ticks_msec() - sample_start < 6000:
		await process_frame
		total_frames += 1
		bucket_frames += 1
		var now := Time.get_ticks_msec()
		if now - bucket_start >= 1000:
			samples.append(float(bucket_frames) * 1000.0 / float(now - bucket_start))
			bucket_frames = 0
			bucket_start = now
	var elapsed_seconds := float(Time.get_ticks_msec() - sample_start) / 1000.0
	var average := float(total_frames) / maxf(elapsed_seconds, 0.001)
	var minimum := samples[0] if not samples.is_empty() else average
	for sample in samples:
		minimum = minf(minimum, sample)
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	print("720P PERF: average=%.1f minimum=%.1f cold_transition=%dms warm_transition=%dms draws=%d primitives=%d nodes=%d samples=%s" % [average, minimum, cold_transition_ms, warm_transition_ms, draw_calls, primitives, nodes, str(samples)])
	if average < 28.0 or minimum < 20.0 or warm_transition_ms > 300:
		push_error("native 720p performance gate failed")
		_release_render_resources(game)
		game.queue_free()
		await _frames(4)
		quit(1)
		return
	print("720P PERFORMANCE VERIFIER: PASS")
	_release_render_resources(game)
	game.queue_free()
	await _frames(4)
	quit()

func _frames(count: int) -> void:
	for _i in range(count): await process_frame

func _release_render_resources(game: Node) -> void:
	for node in game.find_children("*", "MultiMeshInstance3D", true, false):
		node.multimesh = null
	for node in game.find_children("*", "MeshInstance3D", true, false):
		node.mesh = null
