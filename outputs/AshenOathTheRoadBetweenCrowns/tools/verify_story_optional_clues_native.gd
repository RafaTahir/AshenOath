extends "res://tools/verify_opening_real_input_native.gd"

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Optional clue route requires graphical real input")
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
		_fail("Genuine post-fight Continue was not focusable")
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
			_fail("Continue did not restore controllable Wychwood within the readiness limit")
	if failures.is_empty() and (not game.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin") or game.quests.is_objective_done("main_road_of_crows", "oren") or game.quests.is_objective_done("main_road_of_crows", "drag_marks")):
		_fail("Source save is not the genuine post-fight three-clue state")
	if failures.is_empty():
		await _turn_camera_north(game)
		stabilize_route_bearing = true
	if failures.is_empty():
		await _move_until(game, KEY_S, "drag_marks_south_layby", func(p: Vector3) -> bool: return p.z > -5.9, 6000)
		await _move_until(game, KEY_A, "drag_marks_west_layby", func(p: Vector3) -> bool: return p.x < -1.25, 4000)
	if failures.is_empty():
		await _inspect_clue(game, "tracks", "drag_marks")
		if game.quests.is_objective_done("main_road_of_crows", "oren") or bool(game.story_state.get_flag("road_evidence_oren", false)) or bool(game.story_state.get_flag("all_road_evidence", false)):
			_fail("Post-fight drag marks credited untouched Oren evidence")
	if failures.is_empty():
		await _move_until(game, KEY_D, "wychwood_bridge_centerline", func(p: Vector3) -> bool: return p.x > -0.25, 4000)
		await _move_until(game, KEY_S, "oren_south_bank", func(p: Vector3) -> bool: return p.z > 3.8, 8000)
		await _move_until(game, KEY_D, "oren_east_layby", func(p: Vector3) -> bool: return p.x > 3.4, 6000)
	if failures.is_empty():
		await _inspect_clue(game, "oren_token", "oren")
		if not bool(game.story_state.get_flag("all_road_evidence", false)):
			_fail("Five physically inspected clues did not award the all-evidence state")
	if failures.is_empty():
		print("REAL_INPUT optional_clues=PASS post_fight=true ghost_credit=false all_five_physically_inspected=true")
		await _return_wychwood_to_greyfen(game)
	if failures.is_empty():
		await _report_to_anwen(game)
	if failures.is_empty():
		var slot := await _save_campaign_checkpoint(game)
		var saved: Dictionary = slot.get("data", {})
		if not bool(slot.get("ok", false)) or not saved.get("quests", {}).get("completed", {}).has("main_road_of_crows") or not bool(saved.get("story_state", {}).get("flags", {}).get("all_road_evidence", false)):
			_fail("Ordinary save lost the physically earned five-clue Road outcome")
		else:
			print("REAL_INPUT all_evidence_report_save=PASS road_complete=true")
	await _shutdown_game(game)
	_finish()

func _inspect_clue(game: Node, clue_id: String, evidence_id: String) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline and (game.active_interactable == null or game.active_interactable.interaction_id != clue_id):
		await process_frame
	if game.active_interactable == null or game.active_interactable.interaction_id != clue_id:
		_fail("%s lacked normal focus at %s; focus=%s" % [clue_id, game.player.global_position, game.active_interactable.interaction_id if game.active_interactable != null else "none"])
		return
	_key(KEY_E, true)
	await _frames(3)
	_key(KEY_E, false)
	await _frames(7)
	if not game.quests.is_objective_done("main_road_of_crows", evidence_id):
		_fail("Real E input did not record %s" % evidence_id)
	else:
		print("REAL_INPUT optional_%s=PASS position=%s" % [evidence_id, game.player.global_position])
