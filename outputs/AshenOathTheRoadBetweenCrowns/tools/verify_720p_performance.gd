extends SceneTree

var samples: Array[float] = []

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		print("720p performance verifier skipped: graphical renderer required")
		quit()
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
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
	await _frames(90)
	var transition_start := Time.get_ticks_msec()
	game.call("_load_zone", "wychwood", Vector3(0, 1, 8))
	var cold_transition_ms := Time.get_ticks_msec() - transition_start
	game.call("_load_zone", "greyfen", Vector3(0, 1, -13))
	transition_start = Time.get_ticks_msec()
	game.call("_load_zone", "wychwood", Vector3(0, 1, 8))
	var warm_transition_ms := Time.get_ticks_msec() - transition_start
	await _frames(90)
	for _second in range(8):
		await create_timer(1.0).timeout
		samples.append(float(Engine.get_frames_per_second()))
	var average := 0.0
	var minimum := samples[0] if not samples.is_empty() else 0.0
	for sample in samples:
		average += sample
		minimum = minf(minimum, sample)
	if not samples.is_empty(): average /= float(samples.size())
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	print("720P PERF: average=%.1f minimum=%.1f cold_transition=%dms warm_transition=%dms draws=%d primitives=%d nodes=%d samples=%s" % [average, minimum, cold_transition_ms, warm_transition_ms, draw_calls, primitives, nodes, str(samples)])
	if average < 28.0 or minimum < 20.0 or warm_transition_ms > 250:
		push_error("native 720p performance gate failed")
		quit(1)
		return
	print("720P PERFORMANCE VERIFIER: PASS")
	quit()

func _frames(count: int) -> void:
	for _i in range(count): await process_frame
