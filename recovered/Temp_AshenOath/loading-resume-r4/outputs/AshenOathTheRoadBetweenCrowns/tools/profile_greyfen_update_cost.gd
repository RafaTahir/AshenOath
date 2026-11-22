extends SceneTree

const OUTPUT := "D:/Temp/AshenOath/greyfen_update_cost.json"
const PHASE_MS := 3200

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Greyfen update-cost probe requires a graphical renderer")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game._on_launch_accepted()
	var deadline := Time.get_ticks_msec() + 30000
	while not game.route_zone_cache.has("greyfen") and Time.get_ticks_msec() < deadline:
		await process_frame
	game._new_game()
	deadline = Time.get_ticks_msec() + 45000
	while (game.zone_root == null or not game.zone_root.get_meta("opening_detail_complete", false)) and Time.get_ticks_msec() < deadline:
		await process_frame
	if game.zone_root == null or not game.zone_root.get_meta("opening_detail_complete", false):
		push_error("Greyfen did not hydrate for update-cost probe")
		await _shutdown(game)
		quit(1)
		return
	var life: Node = game.zone_root.find_child("GreyfenLifeController", true, false)
	var river: Node = game.zone_root.find_child("RiverMotionController", true, false)
	var vfx: Node = game.world_vfx
	if life == null or river == null or vfx == null:
		push_error("Opening update controller is unavailable")
		await _shutdown(game)
		quit(1)
		return
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var rows: Array[Dictionary] = []
	for phase in ["baseline_a", "life_paused", "river_paused", "vfx_paused", "baseline_b"]:
		life.set_process(phase != "life_paused")
		river.set_physics_process(phase != "river_paused")
		vfx.set_physics_process(phase != "vfx_paused")
		for index in range(45):
			await process_frame
		var row := await _sample(phase)
		rows.append(row)
		print("UPDATE COST %s" % JSON.stringify(row))
	life.set_process(true)
	river.set_physics_process(true)
	vfx.set_physics_process(true)
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"scope": "diagnostic only; controllers restored before shutdown", "phases": rows}, "\t"))
		file.close()
	await _shutdown(game)
	quit(0 if file != null else 1)

func _sample(phase: String) -> Dictionary:
	var frame_times: Array[float] = []
	var process_total := 0.0
	var physics_total := 0.0
	var render_total := 0.0
	var draws_total := 0.0
	var primitives_total := 0.0
	var started := Time.get_ticks_msec()
	var previous := Time.get_ticks_usec()
	while Time.get_ticks_msec() - started < PHASE_MS:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times.append(float(now - previous) / 1000.0)
		previous = now
		process_total += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		render_total += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		draws_total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives_total += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	frame_times.sort()
	var count := maxf(float(frame_times.size()), 1.0)
	var elapsed := 0.0
	for frame_ms in frame_times:
		elapsed += frame_ms
	var slow_count := maxi(1, ceili(count * 0.01))
	var slow_elapsed := 0.0
	for index in range(frame_times.size() - slow_count, frame_times.size()):
		slow_elapsed += frame_times[index]
	return {
		"phase": phase,
		"frames": frame_times.size(),
		"average_fps": 1000.0 * count / maxf(elapsed, 0.001),
		"one_percent_low_fps": 1000.0 * float(slow_count) / maxf(slow_elapsed, 0.001),
		"process_ms": process_total / count,
		"physics_ms": physics_total / count,
		"render_cpu_ms": render_total / count,
		"draws": draws_total / count,
		"primitives": primitives_total / count,
	}

func _shutdown(game: Node) -> void:
	game.prepare_resource_shutdown()
	for index in range(20):
		await process_frame
	game.finalize_resource_shutdown()
	for index in range(12):
		await process_frame
	game.queue_free()
	for index in range(8):
		await process_frame
	RenderingServer.force_sync()
