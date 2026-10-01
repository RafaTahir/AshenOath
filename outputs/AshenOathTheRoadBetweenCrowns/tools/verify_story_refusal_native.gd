extends "res://tools/verify_opening_real_input_native.gd"

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Request refusal requires graphical real input")
		_finish()
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
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
		_fail("Genuine Greyfen Continue was not focusable")
	else:
		_key(KEY_ENTER, true)
		await _frames(3)
		_key(KEY_ENTER, false)
		var deadline := Time.get_ticks_msec() + DEADLINE_MS
		while Time.get_ticks_msec() < deadline:
			if game.game_started and game.current_zone_id == "greyfen" and not game.zone_transition_pending and game.player.can_control and not game.player.transition_locked:
				break
			await process_frame
		if not game.game_started or game.current_zone_id != "greyfen" or game.zone_transition_pending or not game.player.can_control or game.player.transition_locked:
			_fail("Continue did not restore controllable Greyfen within the readiness limit")
	if failures.is_empty() and (not game.quests.is_unlocked("side_bitter_roots") or game.quests.is_active("side_bitter_roots") or game.quests.is_completed("side_bitter_roots")):
		_fail("Bitter Roots request was not available before refusal")
	if failures.is_empty():
		await _turn_camera_north(game)
		stabilize_route_bearing = true
		if game.player.global_position.x > 0.45:
			await _move_until(game, KEY_A, "request_bridge_centerline", func(p: Vector3) -> bool: return p.x < 0.45, 7000)
		if game.player.global_position.z < 9.2:
			await _move_until(game, KEY_S, "request_south_bank", func(p: Vector3) -> bool: return p.z > 9.2, 9000)
		if game.player.global_position.x > -3.55:
			await _move_until(game, KEY_A, "request_board_west", func(p: Vector3) -> bool: return p.x < -3.55, 6000)
		elif game.player.global_position.x < -4.05:
			await _move_until(game, KEY_D, "request_board_east", func(p: Vector3) -> bool: return p.x > -4.05, 6000)
		await _frames(8)
	if failures.is_empty():
		if OS.get_cmdline_user_args().has("--accept-after-refusal"):
			await _choose_focused_dialogue_action(game, "side_contracts", "Bitter Roots", "request_accept_after_refusal")
			if not game.quests.is_active("side_bitter_roots"):
				_fail("Bitter Roots was unavailable after a saved refusal")
		else:
			if await _await_focused_interaction(game, "side_contracts", "request_refusal"):
				_key(KEY_E, true)
				await _frames(3)
				_key(KEY_E, false)
				await _frames(5)
				if not game.hud.dialogue_layer.visible:
					_fail("Village request board did not open on E")
				else:
					_key(KEY_ESCAPE, true)
					await _frames(2)
					_key(KEY_ESCAPE, false)
					await _frames(5)
					if game.hud.dialogue_layer.visible or paused or not game.player.can_control:
						_fail("Escape refusal did not restore player control")
					elif game.quests.is_active("side_bitter_roots") or not game.quests.is_unlocked("side_bitter_roots"):
						_fail("Escape refusal changed quest availability without choosing a request")
					else:
						print("REAL_INPUT request_refusal=PASS available=true")
	if failures.is_empty():
		var slot := await _save_campaign_checkpoint(game)
		var saved: Dictionary = slot.get("data", {})
		var active: Dictionary = saved.get("quests", {}).get("active", {})
		var unlocked: Dictionary = saved.get("quests", {}).get("unlocked", {})
		var accepting := OS.get_cmdline_user_args().has("--accept-after-refusal")
		if not bool(slot.get("ok", false)) or active.has("side_bitter_roots") != accepting or not bool(unlocked.get("side_bitter_roots", false)):
			_fail("Manual save did not preserve request %s state" % ("acceptance" if accepting else "refusal"))
		else:
			print("REAL_INPUT request_%s_save=PASS" % ("acceptance" if accepting else "refusal"))
	await _shutdown_game(game)
	_finish()
