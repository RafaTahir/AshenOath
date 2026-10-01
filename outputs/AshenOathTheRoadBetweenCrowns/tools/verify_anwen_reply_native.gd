extends "res://tools/verify_opening_real_input_native.gd"

const StoryStateScript = preload("res://scripts/story_state.gd")

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Anwen reply requires actual graphical input")
		_finish()
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(3)
	var slot: Dictionary = game.save_manager._read_slot(game.save_manager.SAVE_PATH)
	var before: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or str(before.get("zone", "")) != "greyfen":
		_fail("Anwen reply requires the genuine Greyfen conversation checkpoint")
	else:
		await _continue_from_menu(game)
		if failures.is_empty():
			await _verify_reply(game, before)
	await _shutdown_game(game)
	_finish()

func _continue_from_menu(game: Node) -> void:
	var found := false
	for _index in range(8):
		var focused := root.gui_get_focus_owner() as Button
		if focused != null and focused.text == "Continue" and not focused.disabled:
			found = true
			break
		_key(KEY_TAB, true)
		await _frames(2)
		_key(KEY_TAB, false)
		await _frames(3)
	if not found:
		_fail("Normal Continue was not keyboard accessible")
		return
	_key(KEY_ENTER, true)
	await _frames(3)
	_key(KEY_ENTER, false)
	var deadline := Time.get_ticks_msec() + DEADLINE_MS
	while Time.get_ticks_msec() < deadline:
		if game.game_started and game.current_zone_id == "greyfen" and not game.zone_transition_pending and game.player.can_control and not game.player.transition_locked:
			return
		await process_frame
	_fail("Continue did not restore playable Greyfen within the existing deadline")

func _verify_reply(game: Node, before: Dictionary) -> void:
	var outcome := "terms" if OS.get_cmdline_user_args().has("--anwen-terms") else "report"
	var reload_choice := OS.get_cmdline_user_args().has("--anwen-reload")
	var expected := StoryStateScript.new()
	expected.load_state(before.get("story_state", {}))
	if reload_choice:
		if str(expected.get_flag("anwen_response", "")) != outcome:
			_fail("Reply reload did not use its genuine preceding manual save")
	elif str(expected.get_flag("anwen_response", "")) != "":
		_fail("Reply fixture has already made Anwen's first choice")
	else:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(wrapf(float(game.camera_rig.yaw), -PI, PI) / float(game.camera_rig.sensitivity), 0.0)
		Input.parse_input_event(motion)
		await _frames(3)
		await _move_until(game, KEY_W, "anwen_reply_approach", func(p: Vector3) -> bool: return p.z < -3.4, 4000)
		await _choose_focused_dialogue_action(game, "sister_anwen", "You can explain when I return." if outcome == "terms" else "If the shrine is involved, I report it.", "anwen_reply_" + outcome)
		expected.set_flag("anwen_response", outcome)
		if outcome == "report":
			expected.adjust_value("greyfen_fear", 1)
	if failures.is_empty():
		_check_reply_state(game, expected, outcome)
	if failures.is_empty():
		var saved := await _save_campaign_checkpoint(game)
		var saved_story := StoryStateScript.new()
		saved_story.load_state(saved.get("data", {}).get("story_state", {}))
		if not bool(saved.get("ok", false)) or saved_story.save_state() != expected.save_state():
			_fail("Normal Pause Save lost the exact Anwen response/consequences")
		saved_story.free()
		await _resume_saved_route(game)
		if failures.is_empty():
			_check_reply_state(game, expected, outcome)
		if failures.is_empty():
			print("REAL_INPUT anwen_reply=PASS response=%s reload=%s exact_state=true ordinary_save_resume=true" % [outcome, reload_choice])
	expected.free()

func _check_reply_state(game: Node, expected: Node, outcome: String) -> void:
	if game.story_state.save_state() != expected.save_state():
		_fail("Anwen %s changed an unrelated flag or clamped consequence" % outcome)
	if not game.quests.is_objective_done("main_road_of_crows", "speak_anwen") or game.quests.is_objective_done("main_road_of_crows", "evidence_ready") or game.quests.is_completed("main_road_of_crows"):
		_fail("Anwen reply fabricated evidence or lost the actual briefing")
	if paused or game.hud.dialogue_layer.visible or not game.player.can_control or game.player.transition_locked:
		_fail("Anwen reply failed to return gameplay input")
