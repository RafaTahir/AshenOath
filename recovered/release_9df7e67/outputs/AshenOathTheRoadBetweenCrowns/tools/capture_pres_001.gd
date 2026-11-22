extends SceneTree

const VIEWS := [
	["greyfen", Vector3(0, 0.16, 12), 375.0, "Greyfen_Dawn"],
	["greyfen", Vector3(0, 0.16, 12), 720.0, "Greyfen_Day"],
	["greyfen", Vector3(0, 0.16, 12), 1155.0, "Greyfen_Dusk"],
	["greyfen", Vector3(0, 0.16, 12), 60.0, "Greyfen_Night"],
	["wychwood", Vector3(0, 0.16, 4), 720.0, "Wychwood_Day"],
	["wychwood", Vector3(0, 0.16, 4), 60.0, "Wychwood_Night"],
	["deep_wood", Vector3(0, 0.16, 6), 720.0, "DeepWood_Day"],
	["deep_wood", Vector3(0, 0.16, 6), 60.0, "DeepWood_Night"],
	["old_mill", Vector3(0, 0.16, 3), 720.0, "OldMill_Day"],
	["old_mill", Vector3(0, 0.16, 3), 60.0, "OldMill_Night"],
	["old_mill", Vector3(-7, 0.16, -3.5), 720.0, "OldMill_Record_Day"],
	["old_mill", Vector3(-7, 0.16, -3.5), 60.0, "OldMill_Record_Night"],
	["burned_farmstead", Vector3(0, 0.16, 6), 720.0, "Farmstead_Day"],
	["burned_farmstead", Vector3(0, 0.16, 6), 60.0, "Farmstead_Night"],
	["burned_farmstead", Vector3(-4.505554, 0.029421, -5.411111), 720.0, "Farmstead_Register_Day"],
	["burned_farmstead", Vector3(-4.505554, 0.029421, -5.411111), 60.0, "Farmstead_Register_Night"],
	["marsh_crossing", Vector3(0, 0.16, 8), 720.0, "Marsh_Day"],
	["marsh_crossing", Vector3(0, 0.16, 8), 60.0, "Marsh_Night"],
	["marsh_crossing", Vector3(3, 0.16, -4), 720.0, "Marsh_Register_Day"],
	["marsh_crossing", Vector3(3, 0.16, -4), 60.0, "Marsh_Register_Night"],
	["vargan_approach", Vector3(0, 0.16, 8), 720.0, "Castle_Day"],
	["vargan_approach", Vector3(0, 0.16, 8), 60.0, "Castle_Night"],
	["vargan_court", Vector3(0, 0.16, 6), 720.0, "Courtyard_Day"],
	["vargan_court", Vector3(0, 0.16, 6), 60.0, "Courtyard_Night"],
	["record_hall", Vector3(0, 0.16, 6), 720.0, "RecordHall_Day"],
	["record_hall", Vector3(0, 0.16, 6), 60.0, "RecordHall_Night"],
	["undercroft", Vector3(0, 0.16, 6), 720.0, "Undercroft_Day"],
	["undercroft", Vector3(0, 0.16, 6), 60.0, "Undercroft_Night"],
	["assembly", Vector3(0, 0.16, 6), 720.0, "Assembly_Day"],
	["assembly", Vector3(0, 0.16, 6), 60.0, "Assembly_Night"],
	["hart_glade", Vector3(0, 0.16, 8), 720.0, "Hart_Day"],
	["hart_glade", Vector3(0, 0.16, 8), 60.0, "Hart_Night"],
]
var failures: Array[String] = []
var output_dir := ""
var results: Array[Dictionary] = []
var reference_views: Dictionary = {}
var changed_views: PackedStringArray = []
var continue_fixture := false

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("PRES-001 requires actual graphical frames")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument == "--continue-fixture":
			continue_fixture = true
		if argument.begins_with("--views="):
			changed_views = argument.trim_prefix("--views=").split(",", false)
		if argument.begins_with("--output-dir=res://.release-gate/"):
			output_dir = ProjectSettings.globalize_path(argument.trim_prefix("--output-dir="))
		if argument.begins_with("--reference-report=res://.release-gate/"):
			var reference_path := argument.trim_prefix("--reference-report=")
			var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(reference_path))
			for view in reference.get("views", []):
				reference_views[str(view.view)] = str_to_var(str(view.camera_transform))
		if argument.begins_with("--reference-record-report=D:/Temp/AshenOath/"):
			var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--reference-record-report=")))
			for view in reference.get("views", []):
				if str(view.get("interaction", "")) == "register_rook":
					reference_views["Farmstead_Register_Day"] = str_to_var(str(view.camera_transform))
					reference_views["Farmstead_Register_Night"] = str_to_var(str(view.camera_transform))
	if output_dir.is_empty():
		push_error("A unique .release-gate output directory is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	var initial_zone := "greyfen"
	if continue_fixture:
		var save_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://ashen_oath_save.json")) if FileAccess.file_exists("user://ashen_oath_save.json") else null
		if not save_data is Dictionary:
			failures.append("Continue fixture is missing or invalid at " + ProjectSettings.globalize_path("user://ashen_oath_save.json"))
			push_error(failures.back())
			await _shutdown(game)
			quit(1)
			return
		var save: Dictionary = save_data
		initial_zone = str(save.get("zone", ""))
		if initial_zone.is_empty() or not await _click_continue():
			failures.append("A valid copied saved-state Continue fixture is required")
			await _shutdown(game)
			quit(1)
			return
	else:
		game._new_game()
	if not await _ready_zone(game, initial_zone):
		await _shutdown(game)
		quit(1)
		return
	game.day_night.set_time_lock(true)
	game.hud.set_toasts_suppressed(true)
	for view in VIEWS:
		if not _wanted(str(view[3])) and not (str(view[3]) == "Greyfen_Day" and (_wanted("Greyfen_Bridge_Day") or _wanted("Greyfen_Bridge_Side"))):
			continue
		if game.current_zone_id != str(view[0]):
			game._load_zone(str(view[0]), view[1])
			if not await _ready_zone(game, str(view[0])):
				break
		game.player.global_position = game.spatial_service.nearest_safe(view[1], 0)
		game.player.velocity = Vector3.ZERO
		game.camera_rig.set_process(true)
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = -0.2 if str(view[3]).begins_with("Courtyard_") else -0.18
		await _frames(18)
		game.camera_rig.set_process(false)
		if reference_views.has(str(view[3])):
			game.camera_rig.camera.global_transform = reference_views[str(view[3])]
		game.day_night.set_time(float(view[2]))
		await _frames(12)
		await RenderingServer.frame_post_draw
		if _wanted(str(view[3])):
			_capture(str(view[3]), game)
		if str(view[3]) == "Greyfen_Day" and _wanted("Greyfen_Bridge_Day"):
			game.camera_rig.camera.look_at_from_position(Vector3(0, 2.2, 10.2), Vector3(0, 0.35, 4.5), Vector3.UP)
			await _frames(18)
			await RenderingServer.frame_post_draw
			_capture("Greyfen_Bridge_Day", game)
		if str(view[3]) == "Greyfen_Day" and _wanted("Greyfen_Bridge_Side"):
			game.camera_rig.camera.look_at_from_position(Vector3(6, 1.6, 8.2), Vector3(0, -0.10, 4.5), Vector3.UP)
			await _frames(18)
			await RenderingServer.frame_post_draw
			_capture("Greyfen_Bridge_Side", game)
	var inputs: Dictionary = {}
	if _wanted("Courtyard_Day") or _wanted("Courtyard_Night"):
		for path in ["tools/build_courtyard_service.gd", "assets_external/environment/village/CourtyardService_Authored.res"]:
			inputs[path] = FileAccess.get_sha256("res://" + path)
	for input in ["scripts/game.gd", "scripts/visual_director.gd", "scripts/zones/river_section.gd", "scripts/zones/wychwood_section.gd", "scripts/zones/castle_vargan_section.gd", "scripts/zones/campaign_finale_section.gd", "scripts/undercroft_memorial.gd", "scripts/world_landscape_presentation.gd", "tools/capture_pres_001.gd", "tools/build_record_archive.gd", "assets_external/environment/props/RecordArchive_Authored.res", "assets_external/environment/props/record_witness_relief.jpg", "assets_external/environment/village/UndercroftVault_Authored.res", "assets_external/environment/village/Vargan_door_Authored.res", "assets/sky/cloud_0.res", "assets/sky/cloud_1.res", "assets/sky/cloud_2.res", "assets/landscape/far_terrain.res", "assets/landscape/bridge_stone_pier.res"]:
		inputs[input] = FileAccess.get_sha256("res://" + input)
	if _wanted("Hart_Day") or _wanted("Hart_Night"):
		for path in ["scripts/hart_woodland.gd", "tools/build_hart_woodland.gd", "assets_external/environment/forest/HartWoodland_Authored.res", "assets_external/environment/forest/HartLandscape_Authored.res", "assets_external/environment/forest/HartWitnessStones_Authored.res"]:
			inputs[path] = FileAccess.get_sha256("res://" + path)
		for covenant in ["witness", "mercy", "duty", "ash"]:
			var path := "assets_external/environment/forest/HartAftermath_%s_Authored.res" % covenant
			inputs[path] = FileAccess.get_sha256("res://" + path)
	if results.any(func(view: Dictionary) -> bool: return str(view.view).begins_with("DeepWood_") or str(view.view).begins_with("OldMill_") or str(view.view).begins_with("Farmstead_") or str(view.view).begins_with("Marsh_")):
		for path in ["scripts/zones/campaign_wilderness_section.gd", "scripts/zones/campaign_wilds_presentation.gd", "scripts/bandit_frontier.gd", "assets_external/environment/forest/BanditFrontier_Authored.res", "assets_external/environment/forest/Campaign_deep_wood_Landscape.res", "assets_external/environment/forest/Campaign_burned_farmstead_Landscape.res", "assets_external/environment/forest/Campaign_marsh_crossing_Landscape.res", "assets_external/environment/village/AshMill_Authored.res"]:
			inputs[path] = FileAccess.get_sha256("res://" + path)
		inputs["scripts/campaign_record_presentation.gd"] = FileAccess.get_sha256("res://scripts/campaign_record_presentation.gd")
		inputs["tools/build_campaign_records.gd"] = FileAccess.get_sha256("res://tools/build_campaign_records.gd")
		for id in ["register_rook", "register_mira", "mill_pending", "mill_preserved", "mill_burned", "mill_exposed"]:
			var path := "assets_external/environment/props/CampaignRecord_%s_Authored.res" % id
			inputs[path] = FileAccess.get_sha256("res://" + path)
	for requested in changed_views:
		if not results.any(func(view: Dictionary) -> bool: return str(view.view) == requested):
			failures.append("Missing requested view: " + requested)
	var report := {"evidence_scope": "staged visual frames, NOT real-input route or performance", "source_inputs": inputs, "visual_director_sha256": inputs["scripts/visual_director.gd"], "river_section_sha256": inputs["scripts/zones/river_section.gd"], "views": results, "failures": failures}
	var file := FileAccess.open(output_dir.path_join("capture_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	await _shutdown(game)
	print("PRES-001 CAPTURE: %s (%d current graphical views; no route acceptance)" % ["PASS" if failures.is_empty() else "FAIL", results.size()])
	quit(0 if failures.is_empty() else 1)

func _wanted(view: String) -> bool:
	return changed_views.is_empty() or changed_views.has(view)

func _click_continue() -> bool:
	for _index in range(8):
		var focused := root.gui_get_focus_owner() as Button
		if focused != null and focused.text == "Continue" and not focused.disabled:
			_key(KEY_ENTER, true)
			await _frames(3)
			_key(KEY_ENTER, false)
			return true
		_key(KEY_TAB, true)
		await _frames(2)
		_key(KEY_TAB, false)
		await _frames(3)
	return false

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _ready_zone(game: Node, zone: String) -> bool:
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		var playable: bool = game.game_started and not paused and game.current_zone_id == zone and game.player != null and game.zone_root != null and not game.zone_transition_pending and not game.player.transition_locked
		if playable and (zone != "greyfen" or bool(game.zone_root.get_meta("opening_detail_complete", false))):
			return true
		await process_frame
	var message := "PRES-001 did not reach complete playable " + zone
	failures.append(message)
	push_error(message)
	return false

func _capture(stem: String, game: Node) -> void:
	var frame: Image = root.get_texture().get_image()
	if frame == null or frame.get_size() != Vector2i(1280, 720):
		failures.append(stem + ": invalid frame dimensions")
		return
	var minimum := 1.0
	var maximum := 0.0
	var total := 0.0
	var count := 0
	for y in range(0, 720, 8):
		for x in range(0, 1280, 8):
			var pixel := frame.get_pixel(x, y)
			var luminance := pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
			total += luminance
			count += 1
	var mean := total / count
	if maximum - minimum < 0.08 or mean < 0.032 or mean > 0.88:
		failures.append(stem + ": nonblank/exposure acceptance failed")
	var path := output_dir.path_join(stem + ".png")
	if frame.save_png(path) != OK:
		failures.append(stem + ": save failed")
	var camera: Camera3D = game.camera_rig.camera
	var evidence: Dictionary = {}
	for id in ["register_rook", "register_mira", "miller_record"]:
		var area := game.zone_root.find_child(id, true, false) as Node3D
		if area != null:
			evidence[id] = {"position": var_to_str(area.global_position), "visual": str(area.get_meta("external_clue_visual", ""))}
	results.append({"view": stem, "sha256": FileAccess.get_sha256(path), "camera_transform": var_to_str(camera.global_transform), "mean_luminance": mean, "sun_visible": game.visual_director.sun_disc.visible, "moon_visible": game.visual_director.moon_disc.visible, "draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	results.back()["record_interactions"] = evidence
	print("CAPTURED %s luminance=%.4f" % [stem, mean])

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _shutdown(game: Node) -> void:
	game.prepare_resource_shutdown()
	await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
	game.finalize_resource_shutdown()
	await _frames(16)
	root.remove_child(game)
	game.free()
	await _frames(24)
	RenderingServer.force_sync()
