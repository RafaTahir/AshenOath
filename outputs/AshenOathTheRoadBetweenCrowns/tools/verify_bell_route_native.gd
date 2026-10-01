extends "res://tools/verify_opening_real_input_native.gd"

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Bell route requires graphical real input")
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
		_fail("Genuine shrine Continue was not focusable")
	else:
		_key(KEY_ENTER, true)
		await _frames(3)
		_key(KEY_ENTER, false)
		await _await_playable_zone(game, "greyfen", "bell_continue")
	if failures.is_empty():
		stabilize_route_bearing = true
		if OS.get_cmdline_user_args().has("--resolved-reload"):
			if not bool(game.story_state.get_flag("bell_eater_defeated", false)):
				_fail("Resolved reload did not preserve actual death")
			for enemy in game.active_enemies:
				if is_instance_valid(enemy) and enemy.enemy_id == "bell_eater" and not enemy.dead:
					_fail("Defeated Bell-Eater respawned after Continue")
			if OS.get_cmdline_user_args().has("--exit-sweep"):
				for start_x in [8.9, 10.3, 13.3, 15.7]:
					await _align_chapel_entrance(game)
					var west: bool = game.player.global_position.x > start_x
					await _move_until(game, KEY_A if west else KEY_D, "bell_exit_start_%.1f" % start_x, func(p: Vector3) -> bool: return p.x <= start_x if west else p.x >= start_x, 5000)
					await _leave_chapel_for_south_road(game)
					if not failures.is_empty():
						break
				if failures.is_empty():
					print("REAL_INPUT bell_exit_sweep=PASS starts=4 no_jump=true no_teleport=true")
			elif OS.get_cmdline_user_args().has("--departure-only"):
				await _leave_chapel_for_south_road(game)
				if failures.is_empty():
					await _move_until(game, KEY_A, "bridge_return_centerline", func(p: Vector3) -> bool: return p.x < 0.4, 10000)
		else:
			await _fight_bell_eater_real_input(game)
			if failures.is_empty():
				await _leave_chapel_for_south_road(game)
		if failures.is_empty():
			var slot := await _save_campaign_checkpoint(game)
			var saved: Dictionary = slot.get("data", {})
			var flags: Dictionary = saved.get("story_state", {}).get("flags", {})
			for flag in ["bell_eater_defeated", "cemetery_bell_silent", "boss_reward_granted_bell_eater", "boss_reward_bell_iron", "boss_reward_chapel_key"]:
				if not bool(slot.get("ok", false)) or not bool(flags.get(flag, false)):
					_fail("Normal Save lost Bell-Eater %s" % flag)
			var boss: Dictionary = saved.get("world_state", {}).get("boss_states", {}).get("bell_eater", {})
			if str(boss.get("outcome", "")) != "defeated" or int(boss.get("checkpoint", 0)) != 3 or not bool(boss.get("resolved", false)):
				_fail("Normal Save lost defeated phase-three checkpoint")
			if failures.is_empty():
				print("REAL_INPUT bell_save=PASS resolved_reload=%s checkpoint=3 rewards=true aftermath=true" % OS.get_cmdline_user_args().has("--resolved-reload"))
	await _shutdown_game(game)
	_finish()
