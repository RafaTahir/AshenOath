extends "res://tools/verify_opening_real_input_native.gd"

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Ritual departure requires graphical real input")
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
		_fail("Genuine ritual-approach Continue was not focusable")
	else:
		_key(KEY_ENTER, true)
		await _frames(3)
		_key(KEY_ENTER, false)
		await _await_playable_zone(game, "wychwood", "ritual_continue")
	if failures.is_empty():
		if not game.quests.is_objective_done("main_teeth_in_rain", "read_chapel_names") or game.quests.is_objective_done("main_teeth_in_rain", "name_the_dead"):
			_fail("Ritual connector requires its genuine pre-interaction save")
		else:
			stabilize_route_bearing = true
			await _continue_wychwood_teeth(game)
			if failures.is_empty():
				var slot := await _save_campaign_checkpoint(game)
				if not bool(slot.get("ok", false)) or str(slot.get("data", {}).get("zone", "")) != "deep_wood" or not game.quests.is_completed("main_teeth_in_rain"):
					_fail("Real ritual/gate/Bog/core route did not persist its chapter completion")
				else:
					print("REAL_INPUT ritual_connector=PASS continue=true physical_bridge=true ritual=true gate=true bog=true core=true saved=true no_bypass=true")
	await _shutdown_game(game)
	_finish()
