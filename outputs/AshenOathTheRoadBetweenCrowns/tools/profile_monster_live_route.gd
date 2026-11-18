extends SceneTree
## Live source-level performance route, separate from staged palette captures.
## Native main/player/camera/cast/enemy owners keep running throughout.
const ROUTE_ID := "monster_live_route_v2_south_trail"
const ROUTES := {
	"greyfen":[["move_forward",75],["",30],["move_back",75],["move_left",38],["move_right",38]],
	"wychwood":[["move_forward",30],["block",180],["move_back",30],["move_forward",30],["block",180],["move_back",30]]
}

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file,line,code,rationale])

var game: Variant
var options: Dictionary = {}
var viewport := Vector2i(1280,720)
var touch := false
var held := ""
var held_point := Vector2.ZERO
var sampling := false
var previous_us := 0
var frames: Array = []
var inputs: Array = []
var segments: Array = []
var failures: Array[String] = []
var error_log := ErrorLog.new()
var coordinates: Script

func _initialize() -> void:
	OS.add_logger(error_log)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var pair := arg.trim_prefix("--").split("=",true,1)
			options[pair[0]] = pair[1]
	if options.get("viewport", "desktop") == "touch":
		viewport = Vector2i(960,540)
		touch = true
	coordinates = load(str(options.get("coordinates-helper","")))
	process_frame.connect(_record_frame)
	_run.call_deferred()

func _run() -> void:
	var profile := str(options.get("profile",""))
	if profile.is_empty() or not OS.get_user_data_dir().replace("\\","/").ends_with(profile):
		failures.append("Disposable configuration must be installed before renderer startup")
	if DisplayServer.get_name().to_lower() == "headless" or not OS.get_environment("ASHENOATH_CAPTURE_DESKTOP").begins_with("AshenOathCapture_") or not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS):
		failures.append("Private unfocusable native desktop required")
	if not failures.is_empty():
		await _finish()
		return
	if coordinates==null:
		failures.append("An absolute hash-pinned QA coordinate helper is required")
		await _finish()
		return
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = viewport
	DisplayServer.window_set_size(viewport)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if not await _wait(func() -> bool: return game.opening_startup_metrics.has("menu_ready_ms"),180.0):
		failures.append("Main menu readiness timed out")
		await _finish()
		return
	game.settings.set_quality_preset("balanced")
	game._new_game()
	if not await _wait(_playable,180.0):
		failures.append("Natural new-journey opening did not reach player control")
		await _finish()
		return
	# Existing public environment setup; the clock remains unlocked and advances.
	game.day_night.set_time(600.0,0)
	game.day_night.set_time_lock(false)
	game.mobile_touch.set_force_touch_for_test(touch)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	await _ticks(450)
	if touch and not game.mobile_touch.is_gameplay_visible(): failures.append("Live touch controls unavailable")
	# A normal first strike input draws the retained weapon, with no attack.
	_input_event("light_attack",true)
	await _ticks(2)
	_input_event("light_attack",false)
	if not await _wait(func() -> bool: return not game.player.sword_sheathed and not game.player.equipment_loadout.is_transitioning(),4.0): failures.append("Normal input did not draw the weapon")
	await _ticks(60)
	await _measure_zone("greyfen")
	if failures.is_empty():
		await game._load_zone("wychwood",Vector3(0,1,11))
		if not await _wait(func() -> bool: return _playable() and str(game.current_zone_id)=="wychwood",120.0):
			failures.append("Diagnostic entry did not prepare Wychwood")
		else:
			game.day_night.set_time(600.0,0)
			await _ticks(450)
			await _measure_zone("wychwood")
	await _finish()

func _playable() -> bool:
	return game.game_started and is_instance_valid(game.zone_root) and not bool(game.zone_root.get_meta("opening_scene_active",false)) \
		and (str(game.current_zone_id)!="greyfen" or bool(game.zone_root.get_meta("opening_detail_complete",false))) \
		and is_instance_valid(game.player) and game.player.can_control and not game.opening_scene_pending \
		and not game.zone_transition_pending and not game.zone_load_request_pending and not game.player.transition_locked \
		and not paused and game.input_router.is_gameplay_context()

func _measure_zone(zone: String) -> void:
	if not failures.is_empty(): return
	# A normal settings application during streaming can restore its FPS cap.
	# Pace only the measurement, after all runtime setup has finished.
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _ticks(2)
	if not _playable() or Engine.time_scale != 1.0 or game.day_night.time_locked:
		failures.append("Live owner/clock preflight failed: " + zone)
		return
	var roster := _roster()
	if zone == "wychwood" and roster.filter(func(row: Dictionary) -> bool: return row.active and not row.dead).is_empty():
		failures.append("Wychwood has no naturally active retained enemy; route is not representative")
		return
	var row := {"zone":zone,"checkpoints":[_checkpoint("start")],"roster_start":roster,
		"configuration":_configuration(),"frame_schema":["wall_ms","process_ms","physics_ms","render_cpu_ms","render_gpu_ms","draw_calls"]}
	frames = []
	previous_us = 0
	var started := Time.get_ticks_usec()
	sampling = true
	for item: Array in ROUTES[zone]:
		var action := str(item[0])
		if action != "": _input_event(action,true)
		await _ticks(int(item[1]))
		if action != "": _input_event(action,false)
		row.checkpoints.append(_checkpoint(action if action!="" else "idle"))
		if not _playable() or float(game.player.health_component.health)<=25.0:
			failures.append("Route lost normal input/player safety: " + zone)
			break
	sampling = false
	row.elapsed_ms = (Time.get_ticks_usec()-started)/1000.0
	row.frames = frames
	row.roster_end = _roster()
	row.configuration_end = _configuration()
	segments.append(row)
	if frames.size()<30: failures.append("Insufficient live frame samples: " + zone)

func _record_frame() -> void:
	if not sampling: return
	var now := Time.get_ticks_usec()
	if previous_us>0:
		frames.append([(now-previous_us)/1000.0,Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),
			RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	previous_us = now

func _checkpoint(label: String) -> Dictionary:
	var camera := root.get_camera_3d()
	return {"label":label,"player":_v(game.player.global_position),"camera":_v(camera.global_position),
		"camera_rotation":_v(camera.global_rotation),"health":game.player.health_component.health,
		"world_minutes":game.day_night.get_time(),"weather":game.day_night.current_weather,
		"input_context":str(game.input_router.input_context),"player_physics":game.player.is_physics_processing()}

func _configuration() -> Dictionary:
	var logical: Vector2 = root.get_visible_rect().size
	var physical := Vector2(DisplayServer.window_get_size())
	var raw_render := Vector2i(root.get_texture().get_size())
	var mapping: Dictionary = coordinates.contract(logical,physical)
	return {"viewport":[viewport.x,viewport.y],"renderer":RenderingServer.get_current_rendering_method(),
		"internal_viewport":[logical.x,logical.y],"window_client_size":[physical.x,physical.y],
		"raw_render_size":[raw_render.x,raw_render.y],"coordinate_policy":mapping.policy,
		"coordinate_contract_valid":bool(mapping.valid) and Vector2i(physical)==viewport and Vector2i(logical)==Vector2i(1280,720) and raw_render==Vector2i(1280,720),
		"adapter":RenderingServer.get_video_adapter_name(),"frame_limit":Engine.max_fps,
		"vsync":DisplayServer.window_get_vsync_mode(),"physics_hz":Engine.physics_ticks_per_second,
		"time_scale":Engine.time_scale,"paused":paused,"game_process_mode":game.process_mode,
		"day_locked":game.day_night.time_locked,"quality":str(game.settings.settings.quality_preset),
		"resolution_scale":game.settings.settings.resolution_scale,"shadow_quality":game.settings.settings.shadow_quality,
		"foliage_density":game.settings.settings.foliage_density,"visual_density":game.settings.settings.visual_density}

func _roster() -> Array:
	var result: Array = []
	for actor: Node3D in game.active_enemies:
		if is_instance_valid(actor): result.append({"identity":str(actor.enemy_id),"active":actor.encounter_active,
			"dead":actor.dead,"physics":actor.is_physics_processing()})
	return result

func _input_event(action: String, pressed: bool) -> void:
	var coordinate_record: Dictionary = {}
	if touch:
		var control: Variant = game.mobile_touch
		var moving := action.begins_with("move_")
		var logical_point: Vector2 = held_point if not pressed else control._layout.move_center if moving else control.action_centers.get(action,Vector2.INF)
		var logical_size: Vector2 = root.get_visible_rect().size
		var physical_size := Vector2(DisplayServer.window_get_size())
		var point: Vector2 = coordinates.logical_to_window(logical_point,logical_size,physical_size)
		if not point.is_finite() or not bool(_configuration().coordinate_contract_valid):
			failures.append("Missing touch target: " + action)
			return
		coordinate_record = {"logical_position":[logical_point.x,logical_point.y],"window_client_position":[point.x,point.y],
			"logical_size":[logical_size.x,logical_size.y],"window_client_size":[physical_size.x,physical_size.y]}
		var event := InputEventScreenTouch.new()
		event.index = 1 if moving else 3
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		if pressed:
			held_point = logical_point
			if moving:
				var direction: Vector2 = {"move_forward":Vector2.UP,"move_back":Vector2.DOWN,"move_left":Vector2.LEFT,"move_right":Vector2.RIGHT}[action]
				var drag := InputEventScreenDrag.new()
				drag.index = 1
				# Stay below the router's authored .82 auto-sprint threshold so
				# both viewport routes use ordinary walking without stamina drift.
				var logical_delta: Vector2 = direction*float(control._layout.move_travel)*0.70
				drag.relative = coordinates.logical_delta_to_window(logical_delta,logical_size,physical_size)
				drag.screen_relative = drag.relative
				drag.position = point+drag.relative
				Input.parse_input_event(drag)
				coordinate_record["logical_drag_delta"] = [logical_delta.x,logical_delta.y]
				coordinate_record["window_client_drag_delta"] = [drag.relative.x,drag.relative.y]
	elif action=="light_attack":
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = Vector2(viewport)*0.5
		event.pressed = pressed
		Input.parse_input_event(event)
	else:
		var event := InputEventKey.new()
		event.keycode = {"move_forward":KEY_W,"move_back":KEY_S,"move_left":KEY_A,"move_right":KEY_D,"block":KEY_Q}[action]
		event.physical_keycode = event.keycode
		event.pressed = pressed
		Input.parse_input_event(event)
	held = action if pressed else ""
	var input_record := {"action":action,"pressed":pressed,"tick":Engine.get_physics_frames(),"touch":touch}
	input_record.merge(coordinate_record)
	inputs.append(input_record)

func _ticks(count: int) -> void:
	for _index in count: await physics_frame

func _wait(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000.0)
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await process_frame
	return bool(predicate.call())

func _finish() -> void:
	sampling = false
	if is_instance_valid(game):
		if not held.is_empty(): _input_event(held,false)
		game.prepare_resource_shutdown()
		await _ticks(14)
		game.finalize_resource_shutdown()
		await _ticks(8)
		game.free()
		await _ticks(3)
	if not error_log.errors.is_empty(): failures.append("Engine errors observed, including startup/retirement")
	var report := {"kind":"live_route_performance","route_id":ROUTE_ID,"passed":failures.is_empty(),
		"failures":failures,"engine_errors":error_log.errors,"viewport":[viewport.x,viewport.y],
		"segments":segments,"inputs":inputs,"user_data_dir":OS.get_user_data_dir(),
		"sampling_overhead":"Same lightweight six-number sample per process frame; no screenshots/readback during sampling",
		"setup":"Actual new journey; natural opening; public advancing day setup; diagnostic Wychwood entry through existing load owner. Two bounded south-trail excursions avoid the encounter clearing while all natural actors remain active. No actors frozen/repositioned, health refills, quest grants, camera override or simulation-rate change.",
		"physical_device_coverage":false,"frozen_export_acceptance":false,
		"input_method":"synthetic ScreenTouch/ScreenDrag via live UI" if touch else "synthetic Key/MouseButton via normal InputRouter"}
	var file := FileAccess.open(str(options.get("output","")),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report)+"\n")
	else: failures.append("Could not write live route report")
	print("LIVE ROUTE: %s segments=%d errors=%d" % ["PASS" if failures.is_empty() else "FAIL",segments.size(),error_log.errors.size()])
	quit(0 if failures.is_empty() else 1)

func _v(point: Vector3) -> Array:
	return [point.x,point.y,point.z]
