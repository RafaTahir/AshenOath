extends "res://tools/verify_opening_real_input_native.gd"

var output_dir := "D:/Temp/AshenOath/bandit_road_recovery"
var captures: Array[Dictionary] = []
var night_combat_captures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Bandit Road capture requires a graphical viewport")
		_finish()
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(3)
	var focused := false
	for _index in range(8):
		var button := root.gui_get_focus_owner() as Button
		if button != null and button.text == "Continue" and not button.disabled:
			focused = true
			break
		_key(KEY_TAB, true)
		await _frames(2)
		_key(KEY_TAB, false)
		await _frames(3)
	if not focused:
		_fail("Genuine pre-fight Continue is not focusable")
	else:
		_key(KEY_ENTER, true)
		await _frames(3)
		_key(KEY_ENTER, false)
		var deadline := Time.get_ticks_msec() + 45000
		while Time.get_ticks_msec() < deadline:
			if game.game_started and game.current_zone_id == "bandit_road" and not game.zone_transition_pending and game.player.can_control:
				break
			await process_frame
		if not game.game_started or game.current_zone_id != "bandit_road" or game.zone_transition_pending:
			_fail("Genuine pre-fight save did not restore Bandit Road")
	if failures.is_empty():
		game.hud.set_toasts_suppressed(true)
		game.day_night.set_time_lock(true)
		game.day_night.set_time(720.0, game.day_night.day_count)
		await _frames(3)
		await _capture("arrival_day", game)
		game.day_night.set_time(60.0, game.day_night.day_count)
		await _frames(3)
		await _capture("arrival_night", game)
		# The second view is staged art inspection, not player-route evidence.
		game.player.global_position = Vector3(0.0, 0.0, 8.0)
		game.player.velocity = Vector3.ZERO
		game.camera_rig.yaw = -0.28
		game.camera_rig.pitch = -0.18
		game.day_night.set_time(720.0, game.day_night.day_count)
		await _frames(35)
		await _capture("checkpoint_day", game)
		game.day_night.set_time(60.0, game.day_night.day_count)
		await _frames(12)
		await _capture("checkpoint_night", game)
		if "--night-combat" in OS.get_cmdline_user_args():
			game.day_night.set_time(60.0, game.day_night.day_count)
			await _frames(12)
			await _fight_senn_guard(game)
			if night_combat_captures < 2:
				_fail("Night combat did not yield two player-driven strike frames")
		var report := {
			"scope": "genuine-save arrival and staged viewpoint/time captures; optional guard fight uses real movement and attack input, not real-input travel",
			"source_sha256": {
				"scripts/zones/bandit_road_section.gd": FileAccess.get_sha256("res://scripts/zones/bandit_road_section.gd"),
				"scripts/bandit_frontier.gd": FileAccess.get_sha256("res://scripts/bandit_frontier.gd"),
				"scripts/character_role_spec.gd": FileAccess.get_sha256("res://scripts/character_role_spec.gd"),
				"assets_external/environment/forest/BanditFrontier_Authored.res": FileAccess.get_sha256("res://assets_external/environment/forest/BanditFrontier_Authored.res"),
				"scripts/zones/campaign_wilds_presentation.gd": FileAccess.get_sha256("res://scripts/zones/campaign_wilds_presentation.gd"),
				"tools/build_campaign_wilds.gd": FileAccess.get_sha256("res://tools/build_campaign_wilds.gd"),
				"assets_external/environment/village/RoadCheckpoint_Authored.res": FileAccess.get_sha256("res://assets_external/environment/village/RoadCheckpoint_Authored.res"),
			},
			"views": captures,
		}
		var file := FileAccess.open(output_dir.path_join("capture_report.json"), FileAccess.WRITE)
		if file == null:
			_fail("Could not write Bandit Road capture report")
		else:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	await _shutdown_game(game)
	print("BANDIT ROAD VISUAL CAPTURE: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	_finish()

func _drive_contact_strike(game: Node, enemy: Node3D, last_attack: int, interval_ms: int) -> int:
	var strike_at: int = await super._drive_contact_strike(game, enemy, last_attack, interval_ms)
	if strike_at != last_attack and night_combat_captures < 3:
		await _frames(3)
		await _capture("combat_night_%02d" % night_combat_captures, game)
		night_combat_captures += 1
	return strike_at

func _capture(label: String, game: Node) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		_fail("Invalid frame for " + label)
		return
	var path := output_dir.path_join(label + ".png")
	if image.save_png(path) != OK:
		_fail("Could not save " + label)
		return
	var camera := root.get_viewport().get_camera_3d()
	captures.append({
		"label": label, "path": path, "sha256": FileAccess.get_sha256(path),
		"camera_transform": str(camera.global_transform) if camera != null else "none",
		"world_time": game.day_night.world_time_minutes,
	})
	print("BANDIT ROAD CAPTURE %s %s" % [label, path])
