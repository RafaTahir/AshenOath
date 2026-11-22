extends SceneTree

const READY_LIMIT_MS := 15000
const NEW_GAME_LIMIT_MS := 750
const WARM_TRANSITION_LIMIT_MS := 350
const COLD_TRANSITION_LIMIT_MS := 900
const AVERAGE_FPS_MINIMUM := 32.0
const LOW_FPS_MINIMUM := 30.0
const MEMORY_LIMIT_MB := 450.0

var failures: Array[String] = []

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("OPENING-QA-001 requires the graphical Compatibility renderer")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var started := Time.get_ticks_msec()
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "main scene failed to load")
	if scene == null:
		_finish(null)
		return
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.settings.settings["vsync"] = false
	game.settings.apply()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game.call("_on_launch_accepted")
	var ready := await _wait_for_greyfen_prewarm(game, READY_LIMIT_MS)
	var engine_ready_ms := Time.get_ticks_msec() - started
	_check(ready, "Greyfen did not prewarm within %d ms" % READY_LIMIT_MS)
	_check(engine_ready_ms <= READY_LIMIT_MS, "cold engine-ready time exceeded %d ms: %d ms" % [READY_LIMIT_MS, engine_ready_ms])
	var click_started := Time.get_ticks_msec()
	game.call("_new_game")
	await _wait_for_playable_zone(game, "greyfen", NEW_GAME_LIMIT_MS)
	var new_game_ms := Time.get_ticks_msec() - click_started
	_check(new_game_ms <= NEW_GAME_LIMIT_MS, "New Game click-to-play exceeded %d ms: %d ms" % [NEW_GAME_LIMIT_MS, new_game_ms])
	await _frames(30)
	var greyfen_perf := await _sample_performance(6000)
	_check_performance("Greyfen", greyfen_perf)

	var transition_started := Time.get_ticks_msec()
	game.call("_load_zone", "wychwood", Vector3(0, 1, 8))
	await _wait_for_playable_zone(game, "wychwood", COLD_TRANSITION_LIMIT_MS)
	var cold_ms := Time.get_ticks_msec() - transition_started
	_check(cold_ms <= COLD_TRANSITION_LIMIT_MS, "cold Wychwood transition exceeded %d ms: %d ms" % [COLD_TRANSITION_LIMIT_MS, cold_ms])
	await _frames(30)
	var wychwood_perf := await _sample_performance(6000)
	_check_performance("Wychwood", wychwood_perf)

	transition_started = Time.get_ticks_msec()
	game.call("_load_zone", "greyfen", Vector3(0, 1, -13))
	await _wait_for_playable_zone(game, "greyfen", WARM_TRANSITION_LIMIT_MS)
	var warm_ms := Time.get_ticks_msec() - transition_started
	_check(warm_ms <= WARM_TRANSITION_LIMIT_MS, "warm Greyfen transition exceeded %d ms: %d ms" % [WARM_TRANSITION_LIMIT_MS, warm_ms])
	var memory_mb := float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
	_check(memory_mb < MEMORY_LIMIT_MB, "static memory %.1f MB exceeds %.0f MB" % [memory_mb, MEMORY_LIMIT_MB])
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("OPENING-QA-001 METRICS: ready=%dms new_game=%dms cold=%dms warm=%dms memory=%.1fMB greyfen=%.1f/%.1f wychwood=%.1f/%.1f draws=%d primitives=%d nodes=%d" % [
		engine_ready_ms, new_game_ms, cold_ms, warm_ms, memory_mb,
		greyfen_perf.average_fps, greyfen_perf.one_percent_low_fps,
		wychwood_perf.average_fps, wychwood_perf.one_percent_low_fps,
		draws, primitives, nodes,
	])
	_finish(game)

func _wait_for_greyfen_prewarm(game: Node, timeout_ms: int) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started <= timeout_ms:
		var cache: Dictionary = game.get("route_zone_cache")
		if cache.has("greyfen"):
			return true
		await process_frame
	return false

func _wait_for_playable_zone(game: Node, zone_id: String, timeout_ms: int) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started <= timeout_ms:
		if str(game.get("current_zone_id")) == zone_id and not bool(game.get("zone_transition_pending")):
			var player: Node = game.get("player")
			if player != null and bool(player.get("can_control")):
				return true
		await process_frame
	_check(false, "%s did not become playable within %d ms" % [zone_id, timeout_ms])
	return false

func _sample_performance(duration_ms: int) -> Dictionary:
	var frame_ms: Array[float] = []
	var spike_samples: Array[String] = []
	var started := Time.get_ticks_usec()
	var previous := started
	while Time.get_ticks_usec() - started < duration_ms * 1000:
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed_ms := float(now - previous) / 1000.0
		frame_ms.append(elapsed_ms)
		if elapsed_ms > 33.34:
			spike_samples.append("%.0fms@%.2fs" % [elapsed_ms, float(now - started) / 1000000.0])
		previous = now
	var total_ms := 0.0
	for value in frame_ms:
		total_ms += value
	var average_fps := float(frame_ms.size()) * 1000.0 / maxf(total_ms, 0.001)
	frame_ms.sort()
	var worst_count := maxi(1, ceili(float(frame_ms.size()) * 0.01))
	var worst_total := 0.0
	for index in range(frame_ms.size() - worst_count, frame_ms.size()):
		worst_total += frame_ms[index]
	var one_percent_low := 1000.0 / maxf(worst_total / float(worst_count), 0.001)
	return {"average_fps": average_fps, "one_percent_low_fps": one_percent_low, "samples": frame_ms.size(), "spikes": spike_samples}

func _check_performance(label: String, metrics: Dictionary) -> void:
	var average := float(metrics.get("average_fps", 0.0))
	var low := float(metrics.get("one_percent_low_fps", 0.0))
	print("OPENING-QA-001 %s SPIKES: %s" % [label, ", ".join(metrics.get("spikes", []))])
	_check(average >= AVERAGE_FPS_MINIMUM, "%s average %.1f FPS is below %.0f" % [label, average, AVERAGE_FPS_MINIMUM])
	_check(low >= LOW_FPS_MINIMUM, "%s 1%% low %.1f FPS is below %.0f" % [label, low, LOW_FPS_MINIMUM])

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _finish(game: Node) -> void:
	if game != null and is_instance_valid(game):
		if game.has_method("prepare_resource_shutdown"):
			game.prepare_resource_shutdown()
		await _frames(12)
		_release_render_resources(game)
		game.queue_free()
	await _frames(12)
	if failures.is_empty():
		print("OPENING-QA-001 VERIFIER: PASS")
	else:
		print("OPENING-QA-001 VERIFIER: FAIL (%d)" % failures.size())
		for failure in failures:
			print("- %s" % failure)
	quit(0 if failures.is_empty() else 1)

func _release_render_resources(scope: Node) -> void:
	for raw_batch in scope.find_children("*", "MultiMeshInstance3D", true, false):
		(raw_batch as MultiMeshInstance3D).multimesh = null
	for raw_mesh in scope.find_children("*", "MeshInstance3D", true, false):
		(raw_mesh as MeshInstance3D).mesh = null
