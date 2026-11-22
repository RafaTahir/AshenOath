extends SceneTree

const DEADLINE_MS := 45000

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Greyfen hydration repeat profile requires a graphical renderer")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Main scene unavailable")
		quit(1)
		return
	for pass_index in range(2):
		var game := packed.instantiate()
		root.add_child(game)
		await process_frame
		game.settings.settings["touch_controls"] = "off"
		game.settings.set_quality_preset("balanced")
		game.call("_on_launch_accepted")
		var prewarm_deadline := Time.get_ticks_msec() + DEADLINE_MS
		while Time.get_ticks_msec() < prewarm_deadline and not game.route_zone_cache.has("greyfen"):
			await process_frame
		if not game.route_zone_cache.has("greyfen"):
			push_error("Pass %d failed to prewarm Greyfen" % pass_index)
			quit(1)
			return
		game.call("_new_game")
		var playable_deadline := Time.get_ticks_msec() + DEADLINE_MS
		while Time.get_ticks_msec() < playable_deadline and not game.game_started:
			await process_frame
		if not game.game_started:
			push_error("Pass %d did not reach player control" % pass_index)
			quit(1)
			return
		var hydration := await _sample_hydration(game)
		print("GREYFEN HYDRATION DIAGNOSTIC pass=%d %s" % [pass_index, JSON.stringify(hydration)])
		if not bool(hydration.get("complete", false)):
			push_error("Pass %d did not finish Greyfen hydration" % pass_index)
			quit(1)
			return
		await _shutdown_game(game)
	print("GREYFEN HYDRATION REPEAT PROFILE: PASS")
	quit(0)

func _sample_hydration(game: Node) -> Dictionary:
	var started := Time.get_ticks_msec()
	var previous := Time.get_ticks_usec()
	var frame_times: Array[float] = []
	var slow: Array[Dictionary] = []
	var frame_index := 0
	var previous_draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var previous_primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	while Time.get_ticks_msec() - started < DEADLINE_MS:
		if game.zone_root != null and bool(game.zone_root.get_meta("opening_detail_complete", false)):
			frame_times.sort()
			var worst_count := maxi(1, ceili(float(frame_times.size()) * 0.01))
			var worst_total := 0.0
			for index in range(frame_times.size() - worst_count, frame_times.size()):
				worst_total += frame_times[index]
			slow.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.ms) > float(b.ms))
			return {
				"complete": true,
				"elapsed_ms": Time.get_ticks_msec() - started,
				"frames": frame_times.size(),
				"one_percent_low_fps": 1000.0 * float(worst_count) / maxf(worst_total, 0.001),
				"worst_frames": slow.slice(0, mini(10, slow.size())),
			}
		var stage_before := str(game.OPENING_DETAIL_STAGES[game.opening_detail_stage_index]) if game.opening_detail_stage_index < game.OPENING_DETAIL_STAGES.size() else "complete"
		var restore_before := _restore_head(game)
		var restore_count_before: int = game.opening_boot_material_restore_queue.size()
		await process_frame
		var now := Time.get_ticks_usec()
		var frame_ms := float(now - previous) / 1000.0
		previous = now
		frame_index += 1
		var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		if frame_ms > 0.0:
			frame_times.append(frame_ms)
		if frame_ms > 33.333:
			var stage_after := str(game.OPENING_DETAIL_STAGES[game.opening_detail_stage_index]) if game.opening_detail_stage_index < game.OPENING_DETAIL_STAGES.size() else "complete"
			slow.append({
				"frame": frame_index,
				"elapsed_ms": Time.get_ticks_msec() - started,
				"stage_before": stage_before,
				"stage_after": stage_after,
				"ms": frame_ms,
				"draws": draws,
				"draw_delta": draws - previous_draws,
				"primitives": primitives,
				"primitive_delta": primitives - previous_primitives,
				"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
				"process_ms": float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0,
				"physics_ms": float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0,
				"restore_before": restore_before,
				"restore_after": _restore_head(game),
				"restore_count_before": restore_count_before,
				"restore_count_after": game.opening_boot_material_restore_queue.size(),
			})
		previous_draws = draws
		previous_primitives = primitives
	return {"complete": false, "elapsed_ms": Time.get_ticks_msec() - started}

func _restore_head(game: Node) -> String:
	if game.opening_boot_material_restore_queue.is_empty():
		return ""
	var entry: Dictionary = game.opening_boot_material_restore_queue.front()
	var geometry := entry.get("node") as GeometryInstance3D
	if geometry == null or not is_instance_valid(geometry):
		return "invalid"
	var material := entry.get("material_override") as Material
	if material == null and geometry is MeshInstance3D:
		var mesh_node := geometry as MeshInstance3D
		if mesh_node.mesh != null and mesh_node.mesh.get_surface_count() > 0:
			material = mesh_node.mesh.surface_get_material(0)
	return "%s:%s" % [geometry.get_path(), material.resource_name if material != null else "no_material"]

func _shutdown_game(game: Node) -> void:
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	for _index in range(game.ZONE_RETIRE_FRAMES + 6):
		await process_frame
	if game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
	for _index in range(8):
		await process_frame
	root.remove_child(game)
	game.free()
	RenderingServer.force_sync()
	for _index in range(5):
		await process_frame
