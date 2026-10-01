extends SceneTree

var failure := ""
var game: Node
var quality := "balanced"
var crossing_pairs := 1
var lighting_only := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--lighting-only":
			lighting_only = true
		if argument.begins_with("--quality="):
			quality = argument.trim_prefix("--quality=")
		if argument.begins_with("--crossing-pairs="):
			crossing_pairs = int(argument.trim_prefix("--crossing-pairs="))
	if quality not in ["balanced", "potato", "quality"] or crossing_pairs < 1 or crossing_pairs > 10:
		push_error("Invalid detail fixture quality or crossing count")
		quit(1)
		return
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Opening detail evidence requires graphical rendering")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset(quality)
	game.call("_on_launch_accepted")
	var deadline := Time.get_ticks_msec() + 30000
	while not game.route_zone_cache.has("greyfen") and Time.get_ticks_msec() < deadline:
		await process_frame
	if not game.route_zone_cache.has("greyfen"):
		failure = "Boot cache did not become available"
	else:
		var boot_gate_ids := {}
		var cached_root := game.route_zone_cache["greyfen"] as Node3D
		for target in ["wychwood", "deep_wood", "vargan_approach"]:
			var gate := cached_root.find_child("gate_%s" % target, true, false) as Area3D
			if gate == null or not bool(gate.get_meta("opening_boot_gate", false)):
				failure = "Missing prewarmed Greyfen gate: " + target
				break
			boot_gate_ids[target] = gate.get_instance_id()
		game.call("_new_game")
		deadline = Time.get_ticks_msec() + 45000
		while Time.get_ticks_msec() < deadline:
			if game.zone_root != null and game.zone_root.get_meta("opening_detail_complete", false):
				break
			await process_frame
		if game.zone_root == null or not game.zone_root.get_meta("opening_detail_complete", false):
			failure = "Detail did not finish at spawn during active opening quest; stage=%s" % game.opening_detail_stage_index
		elif not game.quests.is_active("main_road_of_crows"):
			failure = "Fixture did not retain the active opening quest"
		else:
			for target in boot_gate_ids:
				var matches: Array = game.zone_root.find_children("gate_%s" % target, "", true, false)
				if matches.size() != 1 or matches[0].get_instance_id() != boot_gate_ids[target]:
					failure = "Prewarmed gate was rebuilt or duplicated: " + target
				elif bool(matches[0].get_meta("opening_boot_gate", false)):
					failure = "Hydrated gate still has boot ownership: " + target
			if game.zone_root.has_meta("opening_visual_index"):
				failure = "Opening visual bucket index remained after the final reveal"
			for visual in game.zone_root.find_children("*", "", true, false):
				if visual is Node3D and visual.has_meta("opening_visual_bucket"):
					failure = "Opening renderable remained hidden after reveal: %s" % visual.get_path()
			for actor_id in ["sister_anwen", "mira", "rook", "widow_elna", "blacksmith_tor", "farmer_toma",
					"common_table", "barrel_board", "village_well", "forge_corner", "tor_forge",
					"mira_apothecary", "shrine_prayer"]:
				var matches: Array = game.zone_root.find_children(actor_id, "", true, false)
				if matches.size() != 1:
					failure = "Expected one %s, found %s" % [actor_id, matches.size()]
			var life = game.zone_root.find_child("GreyfenLifeController", true, false)
			var expected_actors := 13 if quality == "quality" else 7
			if life == null or life.actor_count() != expected_actors:
				failure = "%s must retain %s routines" % [quality, expected_actors]
			else:
				print("OPENING DETAIL POPULATION: %s actors=%s" % [quality, life.actor_count()])
			if not game.zone_root.get_meta("greyfen_architecture_complete", false) or game.zone_root.find_child("GreyfenAuthoredDetailLayer", true, false) == null:
				failure = "Boot profile did not restore village architecture"
			var cemetery: Node = game.zone_root.find_child("GreyfenCemeterySection", true, false)
			if cemetery == null or not bool(cemetery.get_meta("cemetery_build_complete", false)) or bool(cemetery.get_meta("presentation_compact", true)):
				failure = "Cemetery stages did not publish their full presentation: section=%s built=%s compact=%s bell=%s chapel=%s graves=%s roost=%s states=%s" % [
					cemetery != null,
					cemetery.get_meta("cemetery_build_complete", false) if cemetery != null else false,
					cemetery.get_meta("presentation_compact", true) if cemetery != null else true,
					cemetery.get_meta("built_presentation_bell", false) if cemetery != null else false,
					cemetery.get_meta("built_presentation_chapel", false) if cemetery != null else false,
					cemetery.get_meta("built_presentation_graves", false) if cemetery != null else false,
					cemetery.get_meta("built_presentation_roost", false) if cemetery != null else false,
					cemetery.get_meta("built_presentation_states", false) if cemetery != null else false,
				]
			elif game.zone_root.find_children("CemeteryAuthoredPresentation", "", true, false).size() != 1:
				failure = "Cemetery presentation has duplicate or missing authored layers"
			var impression: Node = game.zone_root.find_child("GreyfenFirstImpressionDressing", true, false)
			if impression == null or not bool(impression.get_meta("first_impression_complete", false)):
				failure = "First-impression stages did not finish"
			await RenderingServer.frame_post_draw
			var path := "D:/Temp/AshenOath/opening_detail_%s_spawn.png" % quality
			var result := root.get_texture().get_image().save_png(path)
			if result != OK:
				failure = "Screenshot failed: %s" % result
			else:
				print("OPENING DETAIL RUNTIME: hydration complete at spawn; screenshot=" + path)
			if failure == "" and lighting_only:
				for phase in [[720.0, "day"], [0.0, "night"]]:
					game.day_night.set_time(phase[0])
					for frame in range(12):
						await process_frame
					await RenderingServer.frame_post_draw
					var camera := root.get_camera_3d()
					var director = game.visual_director
					for body in [director.sun_disc, director.moon_disc, director.star_field]:
						var material: StandardMaterial3D = body.material_override
						if material == null and body is MultiMeshInstance3D:
							material = body.multimesh.mesh.material
						var point: Vector3 = body.global_position
						if body is MultiMeshInstance3D:
							point = body.global_transform * body.multimesh.get_instance_transform(0).origin
						print("SKY_CAPTURE_STATE ", JSON.stringify({"phase": phase[1], "body": body.name,
							"visible": body.is_visible_in_tree(), "point": str(point), "screen": str(camera.unproject_position(point)),
							"behind": camera.is_position_behind(point), "alpha": material.albedo_color.a,
							"depth_test": not material.no_depth_test, "fog_density": director.current_environment.fog_density,
							"camera": str(camera.global_transform), "far": camera.far}))
					var lighting_image := root.get_texture().get_image()
					var lighting_path := "D:/Temp/AshenOath/hydrated_%s_%s.png" % [int(Time.get_unix_time_from_system()), phase[1]]
					if lighting_image.get_size() != Vector2i(1280, 720) or lighting_image.save_png(lighting_path) != OK:
						failure = "Lighting capture failed: " + lighting_path
					print("HYDRATED LIGHTING CAPTURE: " + lighting_path)
			if failure == "" and not lighting_only:
				game.camera_rig.yaw = 0.0
				game.input_router.set_gameplay_context()
				for pair in range(crossing_pairs):
					var lane: float = [0.0, 1.6, -1.6][pair % 3]
					if absf(game.player.global_position.x - lane) > 0.15:
						await _walk_to_axis(KEY_D if game.player.global_position.x < lane else KEY_A, lane, 0)
					if failure == "":
						await _walk_to_axis(KEY_W, -9.0 if pair == 0 else 0.0, 2)
					if failure == "":
						await _walk_to_axis(KEY_S, 9.8, 2)
					if failure != "":
						break
	game.prepare_resource_shutdown()
	for index in range(12):
		await process_frame
	game.finalize_resource_shutdown()
	for index in range(4):
		await process_frame
	game.queue_free()
	for index in range(12):
		await process_frame
	if failure != "":
		push_error(failure)
	print("OPENING DETAIL RUNTIME: " + ("PASS" if failure == "" else "FAIL"))
	quit(0 if failure == "" else 1)

func _walk_to_axis(key: Key, destination: float, axis: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	var previous: Vector3 = game.player.global_position
	var reached := false
	for frame in range(600):
		await physics_frame
		var position: Vector3 = game.player.global_position
		if position.distance_to(previous) > 1.0 or str(game.current_zone_id) != "greyfen":
			failure = "Hydrated crossing triggered recovery or changed zone at %s" % position
			break
		previous = position
		if (key in [KEY_W, KEY_A] and position[axis] <= destination) or (key in [KEY_S, KEY_D] and position[axis] >= destination):
			reached = true
			break
	event = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	if not reached and failure == "":
		failure = "Hydrated crossing stopped at %s, expected axis %s=%s" % [game.player.global_position, axis, destination]
	if reached:
		print("OPENING DETAIL ROUTE: keyboard axis=%s reached %s at %s without jump/recovery" % [axis, destination, game.player.global_position])
