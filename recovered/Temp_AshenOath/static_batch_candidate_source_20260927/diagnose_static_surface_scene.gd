extends SceneTree

const Candidate = preload("res://tools/static_surface_batch_candidate.gd")
const DEADLINE_MS := 60000
const SAMPLE_MS := 8000
var failures: Array[String] = []
var evidence: Dictionary = {"scope": "diagnostic_not_ticket_acceptance", "samples": []}
var prefix := "D:/Temp/AshenOath/static_surface_scene"
var graphical := false

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--graphical":
			graphical = true
		elif argument.begins_with("--output="):
			prefix = argument.trim_prefix("--output=")
	if not prefix.begins_with("D:/Temp/AshenOath/"):
		push_error("Diagnostic output must remain under D:/Temp/AshenOath")
		quit(1)
		return
	create_timer(170.0).timeout.connect(func(): push_error("Static surface diagnostic timed out"); quit(2))
	call_deferred("_run")

func _run() -> void:
	if graphical and DisplayServer.get_name().to_lower() == "headless":
		push_error("Graphical comparison requires real Compatibility rendering")
		quit(1)
		return
	if graphical:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.settings.settings["touch_controls"] = "off"
	game.call("_new_game")
	var deadline := Time.get_ticks_msec() + DEADLINE_MS
	while Time.get_ticks_msec() < deadline:
		if game.zone_root != null and bool(game.zone_root.get_meta("opening_detail_complete", false)) and not game.zone_transition_pending:
			break
		await process_frame
	if game.zone_root == null or not bool(game.zone_root.get_meta("opening_detail_complete", false)):
		failures.append("Greyfen hydration did not finish")
	else:
		var candidate = Candidate.new()
		var collision_before := _collision_snapshot(game.zone_root)
		evidence["eligibility"] = candidate.prepare(game.zone_root)
		evidence["geometry"] = candidate.build(game.zone_root)
		failures.append_array(evidence.geometry.equivalence_failures)
		if collision_before != _collision_snapshot(game.zone_root):
			failures.append("Physical collision changed")
		if int(evidence.eligibility.saved_surfaces) <= 0:
			failures.append("No merge benefit under exact scene contract")
		print("STATIC_SURFACE_ELIGIBILITY " + JSON.stringify(evidence.eligibility))
		print("STATIC_SURFACE_GEOMETRY " + JSON.stringify(evidence.geometry))
		if graphical and failures.is_empty():
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			game.performance_budget_monitor.suspend()
			await _frames(180)
			# Freeze the world only for the adjacent-frame equivalence images, never
			# for throughput samples. Both images use the actual gameplay camera.
			paused = true
			_toggle(candidate, false)
			await _frames(3)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(prefix + "_before.png")
			_toggle(candidate, true)
			await _frames(3)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(prefix + "_after.png")
			paused = false
			for enabled in [false, true, false, true]:
				_toggle(candidate, enabled)
				await _frames(60)
				var sample := await _sample(game, enabled)
				evidence.samples.append(sample)
				print("STATIC_SURFACE_SAMPLE " + JSON.stringify(sample))
		candidate.restore()
		if collision_before != _collision_snapshot(game.zone_root):
			failures.append("Physical collision changed after restoration")
	evidence["failures"] = failures
	evidence["generated_at_utc"] = Time.get_datetime_string_from_system(true)
	evidence["game_source_sha256"] = FileAccess.get_sha256("res://scripts/game.gd")
	var output := FileAccess.open(prefix + ".json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(evidence, "\t"))
		output.close()
	else:
		failures.append("Could not write evidence")
	print("VERIFIER_PHASE: SHUTDOWN")
	game.prepare_resource_shutdown()
	await _frames(game.ZONE_RETIRE_FRAMES + 6)
	game.finalize_resource_shutdown()
	await _frames(8)
	root.remove_child(game)
	game.free()
	RenderingServer.force_sync()
	await _frames(5)
	print("STATIC SURFACE SCENE: %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	quit(0 if failures.is_empty() else 1)

func _toggle(candidate, enabled: bool) -> void:
	candidate.batch_root.visible = enabled
	for entry in candidate.replacements:
		entry.node.layers = 0 if enabled else entry.layers

func _sample(game, enabled: bool) -> Dictionary:
	var started := Time.get_ticks_msec()
	var previous := Time.get_ticks_usec()
	var frames: Array[float] = []
	var camera := root.get_camera_3d()
	var start_position: Vector3 = game.player.global_position
	while Time.get_ticks_msec() - started < SAMPLE_MS:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now - previous) / 1000.0)
		previous = now
		if game.input_router.movement_vector().length_squared() > 0.0 or game.player.global_position.distance_to(start_position) > 0.1:
			failures.append("Physical input contaminated stationary A/B sample")
			break
	var sum := 0.0
	for frame in frames:
		sum += frame
	var sorted := frames.duplicate()
	sorted.sort()
	var slow_count := maxi(1, ceili(sorted.size() * 0.01))
	var slow_sum := 0.0
	for index in range(maxi(0, sorted.size() - slow_count), sorted.size()):
		slow_sum += sorted[index]
	return {"candidate": enabled, "frames": frames.size(), "average_fps": frames.size() * 1000.0 / maxf(sum, 0.001),
		"one_percent_low_fps": slow_count * 1000.0 / maxf(slow_sum, 0.001), "worst_ms": sorted.back() if not sorted.is_empty() else 0.0,
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"camera": str(camera.global_transform) if camera != null else "missing"}

func _collision_snapshot(zone: Node3D) -> Dictionary:
	var result: Dictionary = {}
	for shape in zone.find_children("*", "CollisionShape3D", true, false):
		# NPC/Area colliders move naturally throughout throughput samples. The
		# static batch may not alter physical scenery; compare that ownership.
		if not shape.get_parent() is StaticBody3D:
			continue
		result[str(shape.get_instance_id())] = [str(shape.global_transform), shape.shape.get_instance_id() if shape.shape != null else 0, shape.disabled]
	return result

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
