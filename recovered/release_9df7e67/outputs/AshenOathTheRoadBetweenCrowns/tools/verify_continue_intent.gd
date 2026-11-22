extends "res://tools/verify_opening_real_input_native.gd"

func _initialize() -> void:
	call_deferred("_run_continue")

func _run_continue() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Continue verification requires graphical rendering and an earned save")
		_finish()
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	var earn_save := "--earn-save" in OS.get_cmdline_user_args()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(6)
	var saved: Dictionary = {}
	for path in [game.save_manager.SAVE_PATH, game.save_manager.AUTOSAVE_PATH, game.save_manager.CHECKPOINT_PATH]:
		var slot: Dictionary = game.save_manager._read_slot(path)
		if bool(slot.get("ok", false)):
			saved = slot.data
			break
	if saved.is_empty() and not earn_save:
		_fail("This check needs a save earned by a previous player-input run")
	elif not earn_save and (game.greyfen_prewarm_started or not game.route_zone_cache.is_empty()):
		_fail("Continue menu built an unused New Game world")
	if failures.is_empty():
		var new_game_test := earn_save or "--new-game-from-save" in OS.get_cmdline_user_args()
		var label := "New Game" if new_game_test else "Continue"
		var button: Button
		for node in game.hud.menu_layer.find_children("*", "Button", true, false):
			if node.text == label:
				button = node
				break
		if button == null or button.disabled or not button.is_visible_in_tree():
			_fail(label + " is unavailable")
		else:
			var started := Time.get_ticks_msec()
			for pressed in [true, false]:
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = pressed
				click.position = button.get_global_rect().get_center()
				root.push_input(click)
				await _frames(2)
			var expected_zone := "greyfen" if new_game_test else str(saved.zone)
			var deadline := started + 60000
			while Time.get_ticks_msec() < deadline:
				if game.game_started and game.current_zone_id == expected_zone and game.player != null and game.player.can_control and not game.player.transition_locked and not game.zone_transition_pending and not game.zone_load_request_pending:
					break
				await process_frame
			if not game.game_started or game.player == null or game.current_zone_id != expected_zone or not game.player.can_control or game.player.transition_locked or game.zone_transition_pending or game.zone_load_request_pending:
				_fail(label + " did not reach playable state within the functional watchdog")
			elif new_game_test:
				if not game.quests.is_active("main_road_of_crows") or game.quests.is_completed("main_road_of_crows"):
					_fail("Explicit New Game did not start a fresh journey")
			else:
				# JSON numbers are floats on read; managers restore integer counters.
				# Compare in the same serialization domain without ignoring any fields.
				var story: Dictionary = JSON.parse_string(JSON.stringify(game.story_state.save_state()))
				var inventory: Dictionary = JSON.parse_string(JSON.stringify(game.inventory.save_state()))
				if story != saved.story_state:
					_fail("Continue changed earned story choices: saved=%s actual=%s" % [JSON.stringify(saved.story_state), JSON.stringify(story)])
				if inventory != saved.inventory:
					_fail("Continue changed earned inventory: saved=%s actual=%s" % [JSON.stringify(saved.inventory), JSON.stringify(inventory)])
				var expected := Vector2(saved.player_position[0], saved.player_position[2])
				if Vector2(game.player.position.x, game.player.position.z).distance_to(expected) > 0.8:
					_fail("Continue did not restore the saved location")
			print("CONTINUE INTENT label=%s click_to_control_ms=%d failures=%d" % [label, Time.get_ticks_msec() - started, failures.size()])
			if "--audio-sync" in OS.get_cmdline_user_args() and failures.is_empty():
				await _verify_audio_input_sync(game)
			if earn_save and failures.is_empty():
				var start_position: Vector3 = game.player.global_position
				await _move_until(game, KEY_S, "earned_save_movement", func(p: Vector3) -> bool: return p.z > start_position.z + 1.0, 10000)
				if failures.is_empty():
					var earned: Dictionary = await _save_campaign_checkpoint(game)
					if not bool(earned.get("ok", false)):
						_fail("Pause/Save did not create a valid earned manual slot")
					else:
						print("CONTINUE INTENT earned_save=PASS path=%s position=%s" % [ProjectSettings.globalize_path(game.save_manager.SAVE_PATH), earned.data.player_position])
	await _shutdown_game(game)
	_finish()
