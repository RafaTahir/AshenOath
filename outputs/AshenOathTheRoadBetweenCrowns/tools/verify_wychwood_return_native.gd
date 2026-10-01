extends "res://tools/verify_opening_real_input_native.gd"

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Wychwood return requires graphical real input")
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
		_fail("Genuine post-combat Continue was not focusable")
	else:
		_key(KEY_ENTER, true)
		await _frames(3)
		_key(KEY_ENTER, false)
		var deadline := Time.get_ticks_msec() + DEADLINE_MS
		while Time.get_ticks_msec() < deadline:
			if game.game_started and game.current_zone_id == "wychwood" and not game.zone_transition_pending and game.player.can_control and not game.player.transition_locked:
				break
			await process_frame
		if not game.game_started or game.current_zone_id != "wychwood" or game.zone_transition_pending or not game.player.can_control or game.player.transition_locked:
			_fail("Continue did not restore Wychwood within the original readiness limit")
	if failures.is_empty():
		# Exercise the observed non-north combat bearing through normal camera input.
		_key(KEY_LEFT, true)
		await _frames(30)
		_key(KEY_LEFT, false)
		await _frames(3)
		if absf(wrapf(float(game.camera_rig.yaw), -PI, PI)) < 0.2:
			_fail("Non-north return fixture did not receive its camera input")
		else:
			print("REAL_INPUT wychwood_return_bearing=%.3f position=%s" % [game.camera_rig.yaw, game.player.global_position])
			await _return_wychwood_to_greyfen(game)
			if failures.is_empty():
				await _report_to_anwen(game)
			if failures.is_empty():
				await _save_campaign_checkpoint(game)
	await _shutdown_game(game)
	_finish()
