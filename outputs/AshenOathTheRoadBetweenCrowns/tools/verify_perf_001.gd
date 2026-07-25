extends SceneTree

const PROFILE_ZONES := [
	["greyfen", Vector3(0, 1, 7)],
	["wychwood", Vector3(0, 1, 8)],
	["vargan_court", Vector3(0, 1, 8)],
	["record_hall", Vector3(0, 1, 8)],
	["hart_glade", Vector3(0, 1, 8)],
]
const MIN_AVERAGE_FPS := 28.0
const MIN_ONE_PERCENT_LOW_FPS := 24.0
const MAX_STATIC_MEMORY_BYTES := 450 * 1024 * 1024
const MAX_COLD_TRANSITION_MS := 900.0
const MAX_WARM_TRANSITION_MS := 350.0

var failures: Array[String] = []
var report: Dictionary = {"zones": {}, "transitions": {}}

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("PERF-001 requires a graphical Compatibility renderer")
		_finish()
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_check(DisplayServer.window_get_size() == Vector2i(1280, 720), "performance window is not native 1280x720")
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	_check(is_equal_approx(float(game.settings.settings.get("resolution_scale", 0.0)), 1.0), "Balanced is not using native 1.0 render scale")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game.call("_on_launch_accepted")
	for _index in range(180):
		await process_frame
		if game.route_zone_cache.has("greyfen"):
			break
	var new_game_start := Time.get_ticks_usec()
	game.call("_new_game")
	await _wait_for_playable(game)
	report.transitions["new_game_ms"] = _elapsed_ms(new_game_start)
	_check(float(report.transitions.new_game_ms) <= 750.0, "prewarmed New Game exceeded 750 ms")
	for profile in PROFILE_ZONES:
		var zone_id := str(profile[0])
		var position: Vector3 = profile[1]
		var transition_start := Time.get_ticks_usec()
		if str(game.current_zone_id) != zone_id:
			game.call("_load_zone", zone_id, position)
			await _wait_for_playable(game)
		var transition_ms := _elapsed_ms(transition_start)
		report.transitions["%s_cold_ms" % zone_id] = transition_ms
		_check(transition_ms <= MAX_COLD_TRANSITION_MS, "%s cold transition exceeded %.0f ms" % [zone_id, MAX_COLD_TRANSITION_MS])
		await _frames(90)
		report.zones[zone_id] = await _sample_zone(game, zone_id, 4000)
	game.call("_load_zone", "greyfen", Vector3(0, 1, -13))
	await _wait_for_playable(game)
	var warm_start := Time.get_ticks_usec()
	game.call("_load_zone", "hart_glade", Vector3(0, 1, 8))
	await _wait_for_playable(game)
	report.transitions["warm_return_ms"] = _elapsed_ms(warm_start)
	_check(float(report.transitions.warm_return_ms) <= MAX_WARM_TRANSITION_MS, "warm return exceeded %.0f ms" % MAX_WARM_TRANSITION_MS)
	_check(game.route_zone_cache.size() <= game.MAX_CACHED_ROUTE_ZONES, "more than one inactive route zone remained cached")
	await _frames(4)
	_check(game.retired_zone_roots.is_empty(), "retired zone roots remained resident")
	_write_report()
	game.queue_free()
	await _frames(5)
	_finish()

func _sample_zone(game: Node, zone_id: String, duration_ms: int) -> Dictionary:
	var frame_times: Array[float] = []
	var started := Time.get_ticks_msec()
	var previous := Time.get_ticks_usec()
	while Time.get_ticks_msec() - started < duration_ms:
		await process_frame
		var now := Time.get_ticks_usec()
		var frame_ms := float(now - previous) / 1000.0
		previous = now
		if frame_ms > 0.0 and frame_ms < 250.0:
			frame_times.append(frame_ms)
	var average_ms := 0.0
	for frame_ms in frame_times:
		average_ms += frame_ms
	average_ms /= maxf(float(frame_times.size()), 1.0)
	var sorted := frame_times.duplicate()
	sorted.sort()
	var slow_count := maxi(1, ceili(float(sorted.size()) * 0.01))
	var slow_ms := 0.0
	for index in range(sorted.size() - slow_count, sorted.size()):
		slow_ms += float(sorted[index])
	slow_ms /= float(slow_count)
	var average_fps := 1000.0 / maxf(average_ms, 0.001)
	var one_percent_low := 1000.0 / maxf(slow_ms, 0.001)
	var snapshot := {
		"average_fps": average_fps,
		"one_percent_low_fps": one_percent_low,
		"frames": frame_times.size(),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
	}
	print("PERF_001 %s %s" % [zone_id, JSON.stringify(snapshot)])
	_check(average_fps >= MIN_AVERAGE_FPS, "%s average FPS %.1f is below %.1f" % [zone_id, average_fps, MIN_AVERAGE_FPS])
	_check(one_percent_low >= MIN_ONE_PERCENT_LOW_FPS, "%s 1%% low %.1f is below %.1f" % [zone_id, one_percent_low, MIN_ONE_PERCENT_LOW_FPS])
	_check(int(snapshot.static_memory_bytes) <= MAX_STATIC_MEMORY_BYTES, "%s static memory exceeds 450 MB" % zone_id)
	return snapshot

func _wait_for_playable(game: Node) -> void:
	if not bool(game.zone_transition_pending) and not bool(game.zone_load_request_pending):
		return
	for _index in range(120):
		await process_frame
		await physics_frame
		if not bool(game.zone_transition_pending) and not bool(game.zone_load_request_pending):
			return
	_fail("%s did not become playable" % str(game.current_zone_id))

func _elapsed_ms(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0

func _write_report() -> void:
	var directory := ProjectSettings.globalize_path("res://.release-gate")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("perf_001_report.json"), FileAccess.WRITE)
	if file != null:
		report["generated_at_utc"] = Time.get_datetime_string_from_system(true)
		report["limits"] = {
			"minimum_average_fps": MIN_AVERAGE_FPS,
			"minimum_one_percent_low_fps": MIN_ONE_PERCENT_LOW_FPS,
			"maximum_static_memory_bytes": MAX_STATIC_MEMORY_BYTES,
			"maximum_cold_transition_ms": MAX_COLD_TRANSITION_MS,
			"maximum_warm_transition_ms": MAX_WARM_TRANSITION_MS,
		}
		report["status"] = "pass" if failures.is_empty() else "fail"
		file.store_string(JSON.stringify(report, "\t"))

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _finish() -> void:
	if failures.is_empty():
		print("PERF-001 VERIFIER: PASS")
		quit()
		return
	print("PERF-001 VERIFIER: FAIL (%d)" % failures.size())
	quit(1)
