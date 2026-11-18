extends SceneTree
## Absolute-path QA entrypoint. No source-project preload, helper or class cache.
## All game resources are resolved from --main-pack plus declared frozen PCKs.
class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _notify: bool, kind: int, _traces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

const ROLES := {"M01":"ghoulkin", "M02":"wychwood_stalker", "M19":"wychwood_raider", "M20":"wychwood_brute"}
var options: Dictionary = {}
var output := ""
var preparation: Dictionary = {}
var coordinates: Script
var game: Node
var viewport := Vector2i(1280, 720)
var touch := false
var errors := ErrorLog.new()
var failures: Array[String] = []
var report := {"kind":"native_frozen_export_monster_smoke", "frames":[], "materials":[], "inputs":[],
	"browser_acceptance":false, "physical_phone":false, "visual_acceptance":false,
	"user_acceptance":false, "source_fallback":false, "earned_route_acceptance":false}

func _initialize() -> void:
	OS.add_logger(errors)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var pair := arg.trim_prefix("--").split("=", true, 1)
			options[pair[0]] = pair[1]
	output = str(options.get("output", ""))
	if output.is_empty():
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(options.get("preparation", ""))))
	if not parsed is Dictionary:
		_fail("Prepared immutable manifest receipt is unavailable")
		_finish()
		return
	preparation = parsed
	var coordinate_path := str(options.get("coordinates", ""))
	_check(FileAccess.get_sha256(coordinate_path) == str(preparation.get("coordinate_helper_sha256", "")), "Reviewed absolute QA coordinate helper is required")
	coordinates = load(coordinate_path) as Script
	_check(coordinates != null, "QA coordinate helper could not load")
	var profile_root := str(options.get("profile-root", "")).replace("\\", "/").trim_suffix("/") + "/"
	_check(profile_root.length() > 4 and OS.get_user_data_dir().replace("\\", "/").begins_with(profile_root), "OS profile was not isolated before process launch")
	_check(not OS.has_feature("web"), "This receipt describes native frozen-export QA only")
	_check(DisplayServer.get_name().to_lower() != "headless", "A graphical renderer is required")
	if not OS.get_environment("ASHENOATH_CAPTURE_DESKTOP").begins_with("AshenOathCapture_"):
		_fail("Owned private Windows desktop is required")
		_finish()
		return
	# --main-pack restores packed window settings rather than source-capture
	# configuration. Apply the owned window flag before checking its actual state.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	_check(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS), "Unfocusable native window is required")
	_check(FileAccess.get_sha256("res://data/monster_material_profiles.json") == str(preparation.expected_profile_sha256), "Frozen base pack profile differs from the final candidate")
	var pack_root := str(options.get("pack-root", ""))
	for pack: Dictionary in preparation.get("packs", []):
		var path := pack_root.path_join(str(pack.path))
		_check(FileAccess.get_sha256(path) == str(pack.sha256), "Frozen decoded PCK identity: " + str(pack.id))
		if str(pack.id) != "root":
			_check(ProjectSettings.load_resource_pack(path, false), "Cannot mount declared frozen pack: " + str(pack.id))
	touch = str(options.get("viewport", "desktop")) == "touch"
	if touch: viewport = Vector2i(960, 540)
	# Preserve the packed project's production 1280x720 internal canvas. Only
	# the actual native client window changes for the touch-viewport fixture.
	root.size = viewport
	DisplayServer.window_set_size(viewport)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	report["build_id"] = preparation.get("build_id", "")
	report["source"] = preparation.get("source", {})
	report["profile_sha256"] = FileAccess.get_sha256("res://data/monster_material_profiles.json")
	report["user_data_dir"] = OS.get_user_data_dir()
	report["requested_window_size"] = [viewport.x, viewport.y]
	report["production_internal_canvas_policy"] = [1280, 720]
	report["renderer"] = RenderingServer.get_current_rendering_method()
	report["engine_version"] = Engine.get_version_info()
	report["mounted_pack_count"] = preparation.get("packs", []).size() - 1
	if not failures.is_empty():
		_finish()
		return
	_run.call_deferred()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("Frozen Main scene could not load")
		_finish()
		return
	game = packed.instantiate()
	root.add_child(game)
	if not await _wait(func() -> bool: return game.opening_startup_metrics.has("menu_ready_ms"), 180000):
		_fail("Frozen Main menu readiness expired")
		await _shutdown()
		return
	game.settings.set_quality_preset("balanced")
	var button := _button("new_journey")
	if button == null:
		_fail("New Game GUI control is missing")
		await _shutdown()
		return
	await _activate_button(button, "new_game")
	var deadline := Time.get_ticks_msec() + 180000
	var skipped := false
	while Time.get_ticks_msec() < deadline:
		if not skipped:
			var skip := _button("", "OpeningSceneSkip")
			if skip != null:
				await _activate_button(skip, "skip_introduction")
				skipped = true
		if _playable("greyfen"): break
		await process_frame
	if not _playable("greyfen"):
		_fail("GUI New Game did not reach playable Greyfen")
		await _shutdown()
		return
	report["new_game_gui_input"] = true
	report["opening_skipped_by_gui"] = skipped
	await _capture("greyfen_gameplay")
	var lifecycle: Node = game.get_system("zone_lifecycle")
	lifecycle._request_zone_load("wychwood", Vector3(0, 1, 11))
	report["travel_dispatch"] = "zone_lifecycle._request_zone_load(wychwood)"
	await _steps(3)
	var road_pending: bool = game.seamless_world != null and not game.seamless_world.pending_transition.is_empty()
	var gated: bool = str(game.current_zone_id) == "greyfen" and not game.zone_transition_pending and not game.zone_load_request_pending and not road_pending
	report["normal_travel_request"] = {"source":str(game.current_zone_id), "gated_without_pending_request":gated}
	if gated:
		# This smoke inspects shipped resources without granting quest progress.
		# Preserve the legitimate new-journey road gate; explicitly dispatch the
		# destination through the same existing loading owner as source captures.
		lifecycle._load_zone("wychwood", Vector3(0, 1, 11))
		report["destination_fixture"] = {"reason":"normal fresh-journey road request remained gated", "dispatch":"zone_lifecycle._load_zone(wychwood)", "quest_flag_changes":false, "earned_route_acceptance":false}
	if not await _wait(func() -> bool: return _playable("wychwood"), 180000):
		_fail("Wychwood loading owner did not reach a playable frozen destination")
		await _shutdown()
		return
	if touch:
		game.mobile_touch.set_force_touch_for_test(true)
		await _steps(6)
		_check(game.mobile_touch.is_gameplay_visible(), "Actual touch controls are unavailable at 960x540")
	await _input_smoke()
	await _capture("wychwood_gameplay")
	_verify_materials()
	await _capture_monsters()
	await _shutdown()

func _playable(zone: String) -> bool:
	return is_instance_valid(game) and bool(game.game_started) and str(game.current_zone_id) == zone and not game.zone_transition_pending and not game.zone_load_request_pending and not game.opening_scene_pending and is_instance_valid(game.player) and bool(game.player.can_control)

func _button(key: String, node_name: String = "") -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree() and not button.disabled and ((not key.is_empty() and str(button.get_meta("navigation_key", "")) == key) or (not node_name.is_empty() and str(button.name) == node_name)):
			return button
	return null

func _activate_button(button: Button, label: String) -> void:
	var point := button.get_global_rect().get_center()
	var raw_point := _window_point(point)
	if not raw_point.is_finite(): return
	for pressed: bool in [true, false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = raw_point
			event.pressed = pressed
			Input.parse_input_event(event)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
			event.position = raw_point
			event.pressed = pressed
			Input.parse_input_event(event)
		await process_frame
	(report.inputs as Array).append({"action":label, "path":"InputEventScreenTouch GUI" if touch else "InputEventMouseButton GUI",
		"logical_position":[point.x, point.y], "window_position":[raw_point.x, raw_point.y], "coordinates":_coordinate_contract()})

func _input_smoke() -> void:
	var before: Vector3 = game.player.global_position
	await _gameplay_input("move_left", true)
	await _steps(24)
	await _gameplay_input("move_left", false)
	await _steps(3)
	var distance: float = before.distance_to(game.player.global_position)
	_check(distance > 0.02, "Normal movement InputEvents did not move the player")
	await _gameplay_input("light_attack", true)
	await _steps(2)
	await _gameplay_input("light_attack", false)
	_check(await _wait(func() -> bool: return not game.player.sword_sheathed and not game.player.equipment_loadout.is_transitioning(), 5000), "Strike InputEvent did not finish drawing the sword")
	await _steps(40)
	await _gameplay_input("light_attack", true)
	await _steps(2)
	var attacking := float(game.player.attack_cooldown) > 0.0
	await _gameplay_input("light_attack", false)
	_check(attacking, "Second Strike InputEvent did not start an attack")
	report["input_observation"] = {"movement_metres":distance, "attack_cooldown_observed":attacking,
		"touch_controls_forced_on_desktop":touch, "physical_phone":false,
		"physical_touch_viewport_coverage":touch and failures.is_empty(), "coordinates":_coordinate_contract()}
	await _steps(30)

func _gameplay_input(action: String, pressed: bool) -> void:
	var input_record := {"action":action, "pressed":pressed, "path":"synthetic InputEventScreenTouch through normal InputRouter" if touch else "synthetic InputEventKey/MouseButton through normal InputRouter", "coordinates":_coordinate_contract()}
	if touch:
		var control: Node = game.mobile_touch
		var point: Vector2 = control._layout.move_center if action == "move_left" else control.action_centers.get(action, Vector2(-1, -1))
		if point.x < 0:
			_fail("Touch target missing: " + action)
			return
		var raw_point := _window_point(point)
		if not raw_point.is_finite(): return
		input_record["logical_position"] = [point.x, point.y]
		input_record["window_position"] = [raw_point.x, raw_point.y]
		var event := InputEventScreenTouch.new()
		event.index = 1 if action == "move_left" else 3
		event.position = raw_point
		event.pressed = pressed
		Input.parse_input_event(event)
		if pressed and action == "move_left":
			var drag := InputEventScreenDrag.new()
			drag.index = 1
			var logical_delta := Vector2(-float(control._layout.move_travel), 0)
			var raw_delta: Vector2 = coordinates.logical_delta_to_window(logical_delta, root.get_visible_rect().size, Vector2(DisplayServer.window_get_size()))
			drag.relative = raw_delta
			drag.screen_relative = drag.relative
			drag.position = raw_point + raw_delta
			Input.parse_input_event(drag)
			input_record["logical_delta"] = [logical_delta.x, logical_delta.y]
			input_record["window_delta"] = [raw_delta.x, raw_delta.y]
	elif action == "move_left":
		var event := InputEventKey.new()
		event.keycode = KEY_A
		event.physical_keycode = KEY_A
		event.pressed = pressed
		Input.parse_input_event(event)
	else:
		var point := root.get_visible_rect().get_center()
		var raw_point := _window_point(point)
		if not raw_point.is_finite(): return
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = raw_point
		event.pressed = pressed
		Input.parse_input_event(event)
		input_record["logical_position"] = [point.x, point.y]
		input_record["window_position"] = [raw_point.x, raw_point.y]
	(report.inputs as Array).append(input_record)
	await process_frame

func _coordinate_contract() -> Dictionary:
	return coordinates.contract(root.get_visible_rect().size, Vector2(DisplayServer.window_get_size()))

func _window_point(point: Vector2) -> Vector2:
	var model := _coordinate_contract()
	_check(bool(model.valid), "QA event requires positive finite equal-aspect actual window/logical dimensions")
	var mapped: Vector2 = coordinates.logical_to_window(point, root.get_visible_rect().size, Vector2(DisplayServer.window_get_size()))
	_check(mapped.is_finite(), "QA logical-to-window point mapping failed")
	return mapped

func _verify_materials() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/monster_material_profiles.json"))
	for id: String in ROLES:
		var actor := _enemy(str(ROLES[id]))
		if actor == null:
			_fail("Live Wychwood enemy missing: " + id)
			continue
		var source := str(data.assets[id].source)
		var graded := 0
		var prepared := false
		for node: Node in actor.find_children("*", "Node3D", true, false):
			prepared = prepared or str(node.get_meta("prepared_actor_source", "")) == source
			var mesh := node as MeshInstance3D
			if mesh == null or mesh.mesh == null: continue
			for surface in mesh.mesh.get_surface_count():
				var material: Material = mesh.get_active_material(surface)
				if not material is ShaderMaterial: continue
				var script: Script = material.get_script()
				if script == null or script.resource_path != "res://scripts/views/monster_pigment_material.gd": continue
				_check(str(material.source_path) == source, "Wrong material source: " + id)
				_check(str(material.palette_revision) == str(data.palette_revision), "Wrong material revision: " + id)
				_check(material.native_material != null and material.native_material.albedo_texture != null, "Missing retained native atlas: " + id)
				graded += 1
		_check(prepared, "Actor did not use prepared frozen scene: " + id)
		_check(graded > 0, "Live Wychwood enemy lacks pigment bindings: " + id)
		(report.materials as Array).append({"id":id, "source":source, "prepared":prepared, "pigment_surfaces":graded, "live_actor":str(actor.get_path())})

func _enemy(identity: String) -> Node3D:
	for actor: Node in game.active_enemies:
		if is_instance_valid(actor) and str(actor.enemy_id) == identity: return actor as Node3D
	return null

func _capture_monsters() -> void:
	# Controlled inspection only: freeze owners before activation, retain authored
	# positions, then restore every activation/visibility/process flag explicitly.
	var game_mode: int = game.process_mode
	var daylight_mode: int = game.day_night.process_mode
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.day_night.process_mode = Node.PROCESS_MODE_DISABLED
	var inspections: Array[Dictionary] = []
	var camera := Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.fov = 55
	root.add_child(camera)
	for id: String in ROLES:
		var actor := _enemy(str(ROLES[id]))
		if actor == null: continue
		var original_active: bool = actor.encounter_active
		var original_visible: bool = actor.visible
		var actor_mode: int = actor.process_mode
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		actor.set_encounter_active(true)
		actor.visible = true
		var target: Vector3 = actor.global_position + Vector3.UP * (1.4 if id == "M20" else 0.9)
		var forward: Vector3 = -actor.global_basis.z.normalized()
		var right: Vector3 = actor.global_basis.x.normalized()
		var distance := 4.5 if id == "M20" else 3.0
		var excluded: Array[RID] = []
		var actor_body := actor as CollisionObject3D
		var player_body := game.player as CollisionObject3D
		if actor_body != null: excluded.append(actor_body.get_rid())
		if player_body != null: excluded.append(player_body.get_rid())
		var points: Array[Vector3] = [target, target + Vector3.UP * 0.5, target - Vector3.UP * 0.5, target + right * 0.4, target - right * 0.4]
		var ray_samples: Array[Dictionary] = []
		var clear_angle := false
		var chosen_angle := 0.0
		for angle: float in [0.0, 35.0, -35.0, 55.0, -55.0, 15.0, -15.0, 75.0, -75.0]:
			camera.global_position = target + forward.rotated(Vector3.UP, deg_to_rad(angle)) * distance + Vector3.UP * 0.3
			var rays: Array[Dictionary] = []
			var all_clear := true
			for point: Vector3 in points:
				var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1, excluded)
				query.hit_from_inside = true
				var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
				var ray := {"target":[point.x, point.y, point.z], "clear":hit.is_empty()}
				if not hit.is_empty():
					all_clear = false
					var collider := hit.get("collider") as Node
					var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
					ray["hit_collider"] = str(collider.get_path()) if is_instance_valid(collider) else str(hit.get("collider_id", ""))
					ray["hit_position"] = [hit_position.x, hit_position.y, hit_position.z]
				rays.append(ray)
			ray_samples.append({"angle_degrees":angle, "camera_position":[camera.global_position.x, camera.global_position.y, camera.global_position.z], "all_five_clear":all_clear, "rays":rays})
			if all_clear:
				clear_angle = true
				chosen_angle = angle
				break
		_check(clear_angle, "No unobstructed front inspection angle: " + id)
		camera.look_at(target)
		camera.make_current()
		await _steps(3)
		var visible_mesh := false
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			visible_mesh = visible_mesh or (mesh.mesh != null and mesh.is_visible_in_tree())
		var projected: Vector2 = camera.unproject_position(target)
		var on_screen: bool = projected.is_finite() and root.get_visible_rect().has_point(projected) and camera.is_position_in_frustum(target)
		_check(actor.is_visible_in_tree() and visible_mesh and on_screen, "Inspection subject is not visibly framed: " + id)
		await _capture(id + "_inspection_camera")
		actor.set_encounter_active(original_active)
		actor.visible = original_visible
		actor.process_mode = actor_mode
		inspections.append({"id":id, "fixture":"temporary encounter activation with frozen owners; no earned progression",
			"original_active":original_active, "original_visible":original_visible, "original_process_mode":actor_mode,
			"camera_forward_policy":"negative actor global basis z; front then restrained three-quarter angles; no props/actors/lights changed",
			"selected_angle_degrees":chosen_angle if clear_angle else null, "world_collision_mask":1, "camera_ray_samples":ray_samples,
			"visible_mesh_observed":visible_mesh, "projected_center":[projected.x, projected.y], "center_on_screen":on_screen,
			"restored_active":bool(actor.encounter_active), "restored_visible":bool(actor.visible), "restored_process_mode":int(actor.process_mode)})
		_check(bool(actor.encounter_active) == original_active and bool(actor.visible) == original_visible and int(actor.process_mode) == actor_mode, "Inspection flags failed restoration: " + id)
	game.camera_rig.camera.make_current()
	camera.queue_free()
	game.day_night.process_mode = daylight_mode
	game.process_mode = game_mode
	report["inspection_fixtures"] = inspections
	report["inspection_owner_restoration"] = {"original_game_process_mode":game_mode, "restored_game_process_mode":int(game.process_mode),
		"original_day_night_process_mode":daylight_mode, "restored_day_night_process_mode":int(game.day_night.process_mode),
		"health_or_progression_awards":false}

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var file := label + ".png"
	var physical_size := DisplayServer.window_get_size()
	_check(physical_size == viewport, "Actual native client size differs from requested viewport: " + label)
	var write_status := image.save_png(output.path_join(file))
	_check(image.get_size() == Vector2i(1280, 720) and write_status == OK, "Production internal rendered frame dimensions/write: " + label)
	report["window_client_size"] = [physical_size.x, physical_size.y]
	report["internal_render_size"] = [image.get_width(), image.get_height()]
	(report.frames as Array).append({"file":file, "width":image.get_width(), "height":image.get_height(),
		"window_client_size":[physical_size.x, physical_size.y], "coordinates":_coordinate_contract(),
		"camera":"explicit QA inspection" if label.ends_with("inspection_camera") else "normal gameplay"})

func _wait(predicate: Callable, milliseconds: int) -> bool:
	var deadline := Time.get_ticks_msec() + milliseconds
	while true:
		if predicate.call(): return true
		if Time.get_ticks_msec() >= deadline: return false
		await process_frame
	return false

func _steps(count: int) -> void:
	for _index in count: await physics_frame

func _check(value: bool, message: String) -> void:
	if not value: _fail(message)

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _shutdown() -> void:
	if is_instance_valid(game):
		game.prepare_resource_shutdown()
		for _index in 20: await process_frame
		game.finalize_resource_shutdown()
		for _index in 12: await process_frame
		game.free()
		RenderingServer.force_sync()
		for _index in 8: await process_frame
	_finish()

func _finish() -> void:
	report["failures"] = failures
	report["engine_errors"] = errors.errors
	report["passed"] = failures.is_empty() and errors.errors.is_empty()
	var file := FileAccess.open(output.path_join("smoke.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t") + "\n")
	print(JSON.stringify(report))
	quit(0 if report.passed else 1)
