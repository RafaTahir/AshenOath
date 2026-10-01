extends SceneTree

var frame_msec: Array[float] = []
var last_frame_usec := 0
var last_draw_usec := 0
var last_stage := -1
var draw_stage := -1
var slow_frames: Array[Dictionary] = []
var render_times: Dictionary = {}
var first_frames: Array[Dictionary] = []

func sample_draw(game: Node) -> void:
	last_draw_usec = Time.get_ticks_usec()
	draw_stage = int(game.opening_detail_stage_index)
	render_times = {"setup_cpu_ms": RenderingServer.get_frame_setup_time_cpu(),
		"viewport_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),
		"viewport_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),
		"draw_frame": Engine.get_frames_drawn()}

func sample_frame(game: Node) -> void:
	var now := Time.get_ticks_usec()
	if bool(game.game_started) and last_frame_usec != 0:
		var duration := float(now - last_frame_usec) / 1000.0
		frame_msec.append(duration)
		var row := {"frame_ms": duration, "process_to_draw_ms": maxf(0.0, float(last_draw_usec - last_frame_usec) / 1000.0), "stage_before": last_stage, "stage_after": draw_stage, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "render": render_times.duplicate()}
		if first_frames.size() < 12:
			first_frames.append(row)
		if duration > 33.333:
			slow_frames.append(row)
	last_frame_usec = now
	last_stage = int(game.opening_detail_stage_index)

func report_frames() -> void:
	if frame_msec.is_empty():
		return
	var elapsed := 0.0
	for duration in frame_msec:
		elapsed += duration
	frame_msec.sort()
	var low_count := maxi(1, int(ceil(frame_msec.size() * 0.01)))
	var slow_total := 0.0
	for index in range(frame_msec.size() - low_count, frame_msec.size()):
		slow_total += frame_msec[index]
	print("OPENING FULL FRAMES count=%d avg_fps=%.2f low_1pct=%.2f worst_ms=%.2f elapsed_ms=%.2f" % [frame_msec.size(), frame_msec.size() * 1000.0 / elapsed, low_count * 1000.0 / slow_total, frame_msec.back(), elapsed])
	print("OPENING SLOW FRAME TIMELINE " + JSON.stringify(slow_frames))
	print("OPENING FIRST FRAMES " + JSON.stringify(first_frames))

class ProfileAssets extends "res://scripts/asset_spawn_helper.gd":
	var timings: Dictionary = {}
	func _load_cached_resource(path: String):
		var started := Time.get_ticks_usec()
		var result = super._load_cached_resource(path)
		timings["load:" + path.get_file()] = Time.get_ticks_usec() - started
		return result
	func _find_texture_for_obj(path: String) -> String:
		var started := Time.get_ticks_usec()
		var result := super._find_texture_for_obj(path)
		timings["texture_lookup:" + path.get_file()] = Time.get_ticks_usec() - started
		return result
	func _apply_safe_materials(node: Node3D, path: String) -> void:
		var started := Time.get_ticks_usec()
		super._apply_safe_materials(node, path)
		timings["materials:" + path.get_file()] = Time.get_ticks_usec() - started
	func spawn_environment(role_name: String) -> Node3D:
		timings.clear()
		var started := Time.get_ticks_usec()
		var result := super.spawn_environment(role_name)
		if role_name.begins_with("greyfen_"):
			print("FACADE PROFILE %s total_us=%d operations=%s" % [role_name, Time.get_ticks_usec() - started, JSON.stringify(timings)])
		return result

class ProfileGame extends "res://scripts/game.gd":
	var costs: Dictionary = {}
	var house_flush_pending := false
	func _make_village_house_dressed(pos: Vector3, yaw: float, node_name: String) -> void:
		costs.clear()
		var started := Time.get_ticks_usec()
		super._make_village_house_dressed(pos, yaw, node_name)
		print("HOUSE BUILD %s usec=%d operations=%s" % [node_name, Time.get_ticks_usec() - started, JSON.stringify(costs)])
		house_flush_pending = true
	func _flush_environment_batches() -> void:
		var started := Time.get_ticks_usec()
		super._flush_environment_batches()
		if house_flush_pending:
			print("HOUSE BATCH PUBLISH usec=%d" % [Time.get_ticks_usec() - started])
			house_flush_pending = false
	func _add_house_box(parent: Node3D, node_name: String, local_pos: Vector3, size: Vector3, color: Color, local_rot: Vector3 = Vector3.ZERO) -> Node3D:
		var started := Time.get_ticks_usec()
		var result := super._add_house_box(parent, node_name, local_pos, size, color, local_rot)
		costs[node_name] = Time.get_ticks_usec() - started
		return result
	func _add_house_module(parent: Node3D, role_name: String, scale_value: Vector3, local_pos: Vector3, yaw: float, node_name: String) -> Node3D:
		var started := Time.get_ticks_usec()
		var result := super._add_house_module(parent, role_name, scale_value, local_pos, yaw, node_name)
		costs[role_name] = Time.get_ticks_usec() - started
		return result
	func _add_house_gabled_roof(parent: Node3D, color: Color) -> MeshInstance3D:
		var started := Time.get_ticks_usec()
		var result := super._add_house_gabled_roof(parent, color)
		costs["gable_roof"] = Time.get_ticks_usec() - started
		return result

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if "--diagnostic-no-3d" in OS.get_cmdline_user_args():
		root.disable_3d = true
		print("DIAGNOSTIC ONLY: 3D disabled; never performance or visual acceptance")
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(ProfileGame)
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.asset_helper.set_script(ProfileAssets)
	if "--opening" in OS.get_cmdline_user_args():
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
		var sampler := sample_frame.bind(game)
		var draw_sampler := sample_draw.bind(game)
		process_frame.connect(sampler)
		RenderingServer.frame_post_draw.connect(draw_sampler)
		game._on_launch_accepted()
		var boot_deadline := Time.get_ticks_msec() + 30000
		while not game.route_zone_cache.has("greyfen") and Time.get_ticks_msec() < boot_deadline:
			await process_frame
		var request_usec := Time.get_ticks_usec()
		print("OPENING PRE_REQUEST_PARTIAL_FRAME_MS %.3f (prewarm/menu time, not gameplay)" % (float(request_usec - last_frame_usec) / 1000.0))
		# The menu-prewarm callback can finish within the current render frame.
		# Start the click-to-control window at the request, not that frame's start.
		last_frame_usec = request_usec
		last_draw_usec = 0
		last_stage = int(game.opening_detail_stage_index)
		game._new_game()
		print("OPENING NEW_GAME_CALL_MS %.3f" % (float(Time.get_ticks_usec() - request_usec) / 1000.0))
		var detail_deadline := Time.get_ticks_msec() + 45000
		while game.opening_detail_pending and Time.get_ticks_msec() < detail_deadline:
			await process_frame
		var passed: bool = not game.opening_detail_pending and game.zone_root != null and game.zone_root.get_meta("opening_detail_complete", false)
		process_frame.disconnect(sampler)
		RenderingServer.frame_post_draw.disconnect(draw_sampler)
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), false)
		report_frames()
		await _shutdown(game)
		quit(0 if passed else 1)
		return
	game.world_materials.prewarm_surfaces(["medieval_brick", "plaster", "timber", "roof_tiles"], "balanced")
	var deadline := Time.get_ticks_msec() + 15000
	var material_status: Error = ERR_BUSY
	while material_status == ERR_BUSY and Time.get_ticks_msec() < deadline:
		await process_frame
		var poll_start := Time.get_ticks_usec()
		material_status = game.world_materials.poll_prewarm()
		print("HOUSE TEXTURE POLL usec=%d status=%d" % [Time.get_ticks_usec() - poll_start, material_status])
	game.current_zone_id = "greyfen"
	game.zone_root = Node3D.new()
	game.add_child(game.zone_root)
	for index in 2:
		game.costs.clear()
		var started := Time.get_ticks_usec()
		game._make_village_house_dressed(Vector3(index * 6, 0, 0), 8.0, "HouseCost_%d" % index)
		print("HOUSE COST total_us=%d operations=%s" % [Time.get_ticks_usec() - started, JSON.stringify(game.costs)])
	await _shutdown(game)
	quit(0 if material_status == OK else 1)

func _shutdown(game: Node) -> void:
	game.prepare_resource_shutdown()
	for frame in 20:
		await process_frame
	game.queue_free()
	for frame in 8:
		await process_frame
