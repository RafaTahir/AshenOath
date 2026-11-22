extends SceneTree

const SettingsManager = preload("res://scripts/settings_manager.gd")

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "Main scene failed to load")
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _frames(5)
	_check(not game.zone_transition_pending, "Initial world never reached spawn readiness")
	_check(game.player.can_control and not game.player.transition_locked, "Player control enabled before or never after spawn readiness")
	_check(game.call("_grounded_spawn_position", game.player.global_position) != null, "Greyfen spawn has no supporting collision")
	_check(not game.last_loading_metrics.is_empty(), "Initial load did not record playable readiness")

	for zone_id in ["wychwood", "deep_wood", "old_mill", "burned_farmstead", "marsh_crossing", "bandit_road", "vargan_approach", "vargan_court", "record_hall", "undercroft", "assembly", "hart_glade", "greyfen"]:
		game.player.velocity = Vector3(7.0, -20.0, -6.0)
		game.call("_load_zone", zone_id, Vector3(0, 1, 7))
		await _frames(5)
		_check(not game.zone_transition_pending, "%s did not become ready" % zone_id)
		_check(game.player.can_control and not game.player.transition_locked, "%s left player locked" % zone_id)
		_check(game.call("_grounded_spawn_position", game.player.global_position) != null, "%s spawn has no supporting collision" % zone_id)
		_check(bool(game.last_loading_metrics.get("velocity_reset", false)), "%s did not clear unsafe player velocity before control" % zone_id)

	var audio = game.audio
	for count in range(14):
		audio.play_event("ui", 0.0)
	_check(audio.transient_players.size() <= 10, "Transient audio exceeded its safety cap")
	audio.play_ambient("wychwood")
	_check(
		audio.transient_players.all(func(player): return is_instance_valid(player) and not player.playing),
		"Transition audio was not stopped before new ambience"
	)
	_check(audio.ambient_player != null and audio.ambient_player.stream != null, "Ambient player was not preserved")

	var original: Dictionary = game.settings.settings.duplicate(true)
	game.settings.set_quality_preset("potato")
	game.settings.toggle_invert_y()
	game.settings.cycle_master_volume()
	await process_frame
	var reload_settings := SettingsManager.new()
	root.add_child(reload_settings)
	await process_frame
	_check(str(reload_settings.settings.quality_preset) == str(game.settings.settings.quality_preset), "Quality setting did not persist")
	_check(bool(reload_settings.settings.invert_y) == bool(game.settings.settings.invert_y), "Invert setting did not persist")
	_check(is_equal_approx(float(reload_settings.settings.master_volume), float(game.settings.settings.master_volume)), "Volume setting did not persist")
	reload_settings.queue_free()
	game.settings.settings = original
	game.settings.apply()
	game.hud.show_settings_menu("main", 0)
	await process_frame
	_check(await _settings_menu_matches(game.hud, game.settings.settings), "Settings UI does not match active runtime settings")
	_check(
		game.runtime_services.get_child_count() == game.runtime_services.REQUIRED_SERVICES.size(),
		"Runtime service registry duplicated or omitted managers"
	)
	_check(not game.zone_transition_pending, "Loading completion path is still pending")
	print("DEBUG-001 RUNTIME REGRESSIONS: PASS")
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	await _frames(game.ZONE_RETIRE_FRAMES + 4)
	game.free()
	await _frames(8)
	quit(0)

func _settings_menu_matches(hud: Node, settings: Dictionary) -> bool:
	var required := [
		"Visual Preset" + str(settings.quality_preset).capitalize(),
		"Master Volume" + "%d%%" % int(round(float(settings.master_volume) * 100.0)),
		"Invert Y Axis" + ("On" if bool(settings.invert_y) else "Off")
	]
	for page in range(3):
		hud.show_settings_menu(hud.controls_back_target, page)
		await hud.get_tree().process_frame
		var labels: Array[String] = []
		for control in hud.menu_layer.find_children("*", "Control", true, false):
			if control is Button or control is Label:
				labels.append(str(control.text).replace(" ", ""))
		for index in range(required.size()):
			if labels.any(func(text): return text.contains(required[index].replace(" ", ""))):
				required[index] = ""
	return required.all(func(text): return text == "")

func _frames(count: int) -> void:
	for index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
