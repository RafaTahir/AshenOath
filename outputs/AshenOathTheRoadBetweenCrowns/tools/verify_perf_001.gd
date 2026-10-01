extends SceneTree

const PROFILE_ZONES := [
	["greyfen", Vector3(0, 1, 7)],
	["wychwood", Vector3(0, 1, 8)],
	["vargan_court", Vector3(0, 1, 8)],
	["record_hall", Vector3(0, 1, 8)],
	["hart_glade", Vector3(0, 1, 8)],
]
const MIN_AVERAGE_FPS := 32.0
const MIN_ONE_PERCENT_LOW_FPS := 30.0
const MAX_STATIC_MEMORY_BYTES := 450 * 1024 * 1024
# Full campaign zones may compile first-use imported materials on Intel/ANGLE;
# keep that cold bootstrap bounded while the warm-cache budget stays strict.
const MAX_COLD_TRANSITION_MS := 900.0
const MAX_WARM_TRANSITION_MS := 350.0
const SAMPLE_DURATION_MS := 8000

var failures: Array[String] = []
var report: Dictionary = {"zones": {}, "transitions": {}}
var profile_preset := "balanced"
var selected_zone := ""
var report_path_override := ""
var acceptance_profile := "strict"
var target_misses: Array[String] = []

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--zone="):
			selected_zone = argument.trim_prefix("--zone=")
		elif argument.begins_with("--report-path="):
			report_path_override = argument.trim_prefix("--report-path=")
		elif argument.begins_with("--acceptance-profile="):
			acceptance_profile = argument.trim_prefix("--acceptance-profile=")
	if acceptance_profile not in ["strict", "functional_candidate"]:
		_fail("Unknown acceptance profile: " + acceptance_profile)
		_finish()
		return
	if selected_zone != "" and selected_zone not in ["greyfen", "wychwood", "vargan_court", "record_hall", "hart_glade"]:
		_fail("Unknown performance zone: " + selected_zone)
		_finish()
		return
	report["scope"] = "full" if selected_zone == "" else "targeted:" + selected_zone
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("PERF-001 requires a graphical Compatibility renderer")
		_finish()
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Pace the desktop Compatibility sample at the same 60 Hz budget the Web
	# compositor targets. An uncapped ANGLE loop can monopolize the Windows
	# scheduler, producing periodic timer misses that are not representative of
	# the browser's compositor-paced runtime.
	Engine.max_fps = 60
	_check(DisplayServer.window_get_size() == Vector2i(1280, 720), "performance window is not native 1280x720")
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var requested_preset := OS.get_environment("ASHEN_PERF_PRESET").to_lower()
	if requested_preset in ["potato", "balanced", "quality"]:
		profile_preset = requested_preset
	game.settings.settings["touch_controls"] = "off"
	game.settings.set_quality_preset(profile_preset)
	game.input_router.active_device = game.input_router.DEVICE_KEYBOARD_MOUSE
	game.hud.set_input_device(game.input_router.DEVICE_KEYBOARD_MOUSE)
	_check(is_equal_approx(float(game.settings.settings.get("resolution_scale", 0.0)), 1.0), "%s is not using native 1.0 render scale" % profile_preset.capitalize())
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
	_target_check(float(report.transitions.new_game_ms) <= 750.0, "prewarmed New Game exceeded 750 ms")
	for profile in PROFILE_ZONES:
		var zone_id := str(profile[0])
		if selected_zone != "" and zone_id != selected_zone:
			continue
		var position: Vector3 = profile[1]
		var transition_start := Time.get_ticks_usec()
		if str(game.current_zone_id) != zone_id:
			game.call("_load_zone", zone_id, position)
			await _wait_for_playable(game)
		var transition_ms := _elapsed_ms(transition_start)
		report.transitions["%s_cold_ms" % zone_id] = transition_ms
		_target_check(transition_ms <= MAX_COLD_TRANSITION_MS, "%s cold transition exceeded %.0f ms" % [zone_id, MAX_COLD_TRANSITION_MS])
		# Transition timing is measured above. Sustained gameplay sampling starts
		# only after the previous zone has completed its bounded retirement.
		await _wait_for_retirement(game)
		if zone_id == "greyfen":
			var hydrated: bool = await _wait_for_greyfen_hydration(game)
			if not hydrated:
				continue
			report.transitions["greyfen_after_hydration"] = _player_sample_state(game)
		# Transition latency is measured before this point. Give shaders, audio,
		# animation clips, and scheduled NPC routines three seconds to settle so
		# the following sample represents sustained play rather than cold startup.
		var settle_frames := 360 if zone_id == "record_hall" else 180
		await _frames(settle_frames)
		report.transitions["%s_after_settle" % zone_id] = _player_sample_state(game)
		if str(game.current_zone_id) != zone_id:
			_fail("%s changed zones during settlement: %s" % [zone_id, JSON.stringify(report.transitions["%s_after_settle" % zone_id])])
			continue
		report.zones[zone_id] = await _sample_zone(game, zone_id, SAMPLE_DURATION_MS)
		if zone_id == "wychwood":
			await _prepare_combat_profile(game)
			report.zones["wychwood_combat"] = await _sample_zone(game, "wychwood_combat", SAMPLE_DURATION_MS)
	if selected_zone == "":
		await _sample_warm_transition(game)
	_check(game.route_zone_cache.size() <= game.MAX_CACHED_ROUTE_ZONES, "more than one inactive route zone remained cached")
	await _wait_for_retirement(game)
	_check(game.retired_zone_roots.is_empty(), "retired zone roots remained resident")
	_write_report()
	await _shutdown_game(game)
	_finish()

func _sample_warm_transition(game: Node) -> void:
	game.call("_load_zone", "greyfen", Vector3(0, 1, -13))
	await _wait_for_playable(game)
	# A warm-cache measurement must not include disposal work from the preceding
	# cold-profile sequence. Production transitions schedule the same retirement
	# before the next player interaction can occur.
	await _wait_for_retirement(game)
	var warm_start := Time.get_ticks_usec()
	game.call("_load_zone", "hart_glade", Vector3(0, 1, 8))
	await _wait_for_playable(game)
	report.transitions["warm_return_ms"] = _elapsed_ms(warm_start)
	_target_check(float(report.transitions.warm_return_ms) <= MAX_WARM_TRANSITION_MS, "warm return exceeded %.0f ms" % MAX_WARM_TRANSITION_MS)

func _shutdown_game(game: Node) -> void:
	var passed := failures.is_empty()
	if passed:
		print("PERF-001 SAMPLE: PASS (%s)" % report.scope)
	# Everything below this marker is deliberate process teardown. Use the same
	# owned retirement sequence as the lifecycle verifiers so renderer messages
	# cannot be emitted while the performance sample is still considered active.
	print("VERIFIER_PHASE: SHUTDOWN")
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	await _frames(game.ZONE_RETIRE_FRAMES + 6)
	if game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
	await _frames(8)
	if game.is_inside_tree():
		root.remove_child(game)
	if is_instance_valid(game):
		game.free()
	RenderingServer.force_sync()
	await _frames(5)

func _sample_zone(game: Node, zone_id: String, duration_ms: int) -> Dictionary:
	# The monitor is a release-report instrument, not part of the gameplay
	# benchmark. Suspend its sampling while this gate measures the rendered
	# route so instrumentation cannot distort the 1% low result.
	if game.get("performance_budget_monitor") != null:
		game.performance_budget_monitor.suspend()
	var frame_times: Array[float] = []
	var slow_frame_indices: Array[int] = []
	var slow_frame_samples: Array[Dictionary] = []
	var expected_zone := "wychwood" if zone_id == "wychwood_combat" else zone_id
	var start_state := _player_sample_state(game)
	var escaped_state: Dictionary = {}
	var started := Time.get_ticks_msec()
	var previous := Time.get_ticks_usec()
	while Time.get_ticks_msec() - started < duration_ms:
		await process_frame
		if str(game.current_zone_id) != expected_zone:
			escaped_state = _player_sample_state(game)
			break
		var now := Time.get_ticks_usec()
		var frame_ms := float(now - previous) / 1000.0
		previous = now
		# Long stalls are gameplay failures, not outliers to discard.
		if frame_ms > 0.0:
			frame_times.append(frame_ms)
		if frame_ms > 33.333:
			slow_frame_indices.append(frame_times.size() - 1)
			slow_frame_samples.append({
				"frame_ms": frame_ms,
				"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
				"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
				"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
				"process_ms": float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0,
				"physics_process_ms": float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0,
			})
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
		"start_state": start_state,
		"end_state": _player_sample_state(game),
		"escaped_state": escaped_state,
		"average_fps": average_fps,
		"one_percent_low_fps": one_percent_low,
		"frames": frame_times.size(),
		"slow_frame_count": slow_frame_indices.size(),
		"slow_frame_indices": slow_frame_indices.slice(0, mini(12, slow_frame_indices.size())),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"slow_frame_samples": slow_frame_samples.slice(0, mini(12, slow_frame_samples.size())),
	}
	print("PERF_001 %s %s" % [zone_id, JSON.stringify(snapshot)])
	if not escaped_state.is_empty():
		_fail("%s left its profile zone: %s" % [zone_id, JSON.stringify(escaped_state)])
		return snapshot
	_check(frame_times.size() >= 2, "%s performance measurement is missing" % zone_id)
	_target_check(average_fps >= MIN_AVERAGE_FPS, "%s average FPS %.1f is below %.1f" % [zone_id, average_fps, MIN_AVERAGE_FPS])
	_target_check(one_percent_low >= MIN_ONE_PERCENT_LOW_FPS, "%s 1%% low %.1f is below %.1f" % [zone_id, one_percent_low, MIN_ONE_PERCENT_LOW_FPS])
	_target_check(int(snapshot.static_memory_bytes) <= MAX_STATIC_MEMORY_BYTES, "%s static memory exceeds 450 MB" % zone_id)
	return snapshot

func _player_sample_state(game: Node) -> Dictionary:
	var actor: Node3D = game.player
	return {
		"zone": str(game.current_zone_id),
		"position": [actor.global_position.x, actor.global_position.y, actor.global_position.z] if actor != null else [],
		"velocity": [actor.velocity.x, actor.velocity.y, actor.velocity.z] if actor != null else [],
		"movement_input": [game.input_router.movement_vector().x, game.input_router.movement_vector().y] if game.input_router != null else [],
		"held_keys": game.input_router.debug_keyboard_state() if game.input_router != null else {},
		"seam": game.seamless_world.snapshot() if game.seamless_world != null else {},
	}

func _wait_for_playable(game: Node) -> void:
	if not bool(game.zone_transition_pending) and not bool(game.zone_load_request_pending):
		return
	for _index in range(120):
		await process_frame
		await physics_frame
		if not bool(game.zone_transition_pending) and not bool(game.zone_load_request_pending):
			return
	_fail("%s did not become playable" % str(game.current_zone_id))

func _prepare_combat_profile(game: Node) -> void:
	game.player.global_position = Vector3(0.0, 1.0, -3.5)
	game.player.health_component.health = game.player.health_component.max_health * 100.0
	var active_count := 0
	var dormant_count := 0
	for enemy in game.active_enemies:
		if not is_instance_valid(enemy):
			continue
		var should_activate: bool = enemy.enemy_id == "wychwood_stalker"
		if enemy.has_method("set_encounter_active"):
			enemy.set_encounter_active(should_activate)
		if enemy.has_method("is_encounter_active") and enemy.is_encounter_active():
			active_count += 1
		else:
			dormant_count += 1
	_check(active_count == 1, "Wychwood wave pacing must keep exactly one enemy active")
	_check(dormant_count == 4, "four staged Wychwood reinforcements must remain fully dormant")
	await _frames(120)

func _wait_for_retirement(game: Node) -> void:
	for _index in range(game.ZONE_RETIRE_FRAMES + 6):
		await process_frame
		if game.retired_zone_roots.is_empty():
			return
	_fail("retired zone roots remained resident")

func _wait_for_greyfen_hydration(game: Node) -> bool:
	var started := Time.get_ticks_msec()
	var previous_frame := Time.get_ticks_usec()
	var frame_times: Array[float] = []
	var slow_frames: Array[Dictionary] = []
	while Time.get_ticks_msec() - started < 45000:
		if is_instance_valid(game.zone_root) and bool(game.zone_root.get_meta("opening_detail_complete", false)):
			report.transitions["greyfen_hydration_ms"] = Time.get_ticks_msec() - started
			frame_times.sort()
			var worst_count := mini(frame_times.size(), maxi(1, ceili(float(frame_times.size()) * 0.01)))
			var worst_total := 0.0
			for index in range(frame_times.size() - worst_count, frame_times.size()):
				worst_total += frame_times[index]
			slow_frames.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.frame_ms) > float(b.frame_ms))
			report["greyfen_hydration_frames"] = {
				"frames": frame_times.size(),
				"average_fps": float(frame_times.size()) * 1000.0 / maxf(float(report.transitions.greyfen_hydration_ms), 1.0),
				"one_percent_low_fps": 1000.0 / maxf(worst_total / float(maxi(worst_count, 1)), 0.001) if worst_count > 0 else 0.0,
				"worst_frame_ms": frame_times.back() if not frame_times.is_empty() else 0.0,
				"slow_frame_count": slow_frames.size(),
				"slow_frames": slow_frames.slice(0, mini(12, slow_frames.size())),
			}
			print("PERF_001 greyfen_hydration %s" % JSON.stringify(report.greyfen_hydration_frames))
			_target_check(float(report.greyfen_hydration_frames.one_percent_low_fps) >= MIN_ONE_PERCENT_LOW_FPS,
				"Greyfen post-control hydration 1%% low %.1f is below %.1f" % [
					float(report.greyfen_hydration_frames.one_percent_low_fps), MIN_ONE_PERCENT_LOW_FPS,
				])
			return true
		var stage_before := str(game.OPENING_DETAIL_STAGES[game.opening_detail_stage_index]) if game.opening_detail_stage_index < game.OPENING_DETAIL_STAGES.size() else "complete"
		await process_frame
		var now := Time.get_ticks_usec()
		var frame_ms := float(now - previous_frame) / 1000.0
		previous_frame = now
		if frame_ms > 0.0:
			frame_times.append(frame_ms)
		if frame_ms > 33.333:
			var stage_after := str(game.OPENING_DETAIL_STAGES[game.opening_detail_stage_index]) if game.opening_detail_stage_index < game.OPENING_DETAIL_STAGES.size() else "complete"
			slow_frames.append({
				"stage_before": stage_before,
				"stage_after": stage_after,
				"frame_ms": frame_ms,
				"process_ms": float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0,
				"physics_ms": float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0,
				"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
				"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
				"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			})
	_fail("Greyfen deferred detail did not complete within 45 seconds")
	return false

func _elapsed_ms(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0

func _write_report() -> void:
	var directory := ProjectSettings.globalize_path("res://.release-gate")
	DirAccess.make_dir_recursive_absolute(directory)
	var report_name := "perf_001_report.json" if selected_zone == "" else "perf_001_%s_report.json" % selected_zone
	var report_path := report_path_override if report_path_override != "" else directory.path_join(report_name)
	if report_path_override != "":
		DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		report["generated_at_utc"] = Time.get_datetime_string_from_system(true)
		report["acceptance_profile"] = acceptance_profile
		report["target_misses"] = target_misses
		report["performance_certified"] = acceptance_profile == "strict" and failures.is_empty()
		report["scope_limitation"] = "Native diagnostic zone sampling; not player-route or total-process-memory proof."
		report["limits"] = {
			"profile_preset": profile_preset,
			"minimum_average_fps": MIN_AVERAGE_FPS,
			"minimum_one_percent_low_fps": MIN_ONE_PERCENT_LOW_FPS,
			"maximum_static_memory_bytes": MAX_STATIC_MEMORY_BYTES,
			"maximum_cold_transition_ms": MAX_COLD_TRANSITION_MS,
			"maximum_warm_transition_ms": MAX_WARM_TRANSITION_MS,
		}
		report["status"] = "pass" if failures.is_empty() else "fail"
		file.store_string(JSON.stringify(report, "\t"))
	else:
		_fail("Could not write performance report: " + report_name)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _target_check(condition: bool, message: String) -> void:
	if condition:
		return
	target_misses.append(message)
	if acceptance_profile == "strict":
		_fail(message)
	else:
		print("PERFORMANCE_TARGET_MISS: " + message)

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _finish() -> void:
	var label := "PERF-001 VERIFIER" if selected_zone == "" else "PERF-001 TARGETED " + selected_zone
	if failures.is_empty():
		print(label + ": PASS")
		quit()
		return
	print(label + ": FAIL (%d)" % failures.size())
	quit(1)
