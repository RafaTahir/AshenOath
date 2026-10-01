extends "res://tools/verify_story_alternative_native.gd"

const StoryStateScript = preload("res://scripts/story_state.gd")

func _report_to_anwen(game: Node) -> void:
	var outcome := "public" if OS.get_cmdline_user_args().has("--report-public") else "retained"
	if _is_reload():
		_check_report_stage(game, outcome)
		if failures.is_empty():
			await _check_reloaded_choice(game, "evidence_report", outcome, "main_road_of_crows", "main_bell_beneath_greyfen")
			await _resume_saved_route(game)
			_check_report_stage(game, outcome)
		return
	var before_slot: Dictionary = game.save_manager._read_slot(game.save_manager.SAVE_PATH)
	var before: Dictionary = before_slot.get("data", {}).get("story_state", {})
	if not bool(before_slot.get("ok", false)) or str(before.get("flags", {}).get("evidence_report", "")) != "" or not game.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
		_fail("Report alternative requires the genuine unresolved post-fight return save")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_S, "report_north_bank", func(p: Vector3) -> bool: return p.z > 1.5, 7000, true)
	await _move_until(game, KEY_S, "report_south_bank", func(p: Vector3) -> bool: return p.z > 8.1, 6000)
	if outcome == "public":
		await _move_until(game, KEY_A, "public_board_approach", func(p: Vector3) -> bool: return p.x < -1.1, 4000)
	else:
		await _move_until(game, KEY_D, "retained_token_approach", func(p: Vector3) -> bool: return p.x > 1.1, 4000)
	await _look_south_with_mouse(game)
	await _use_focused_interaction(game, "notice_board" if outcome == "public" else "retain_evidence", "road_report_" + outcome)
	if not failures.is_empty():
		return
	_check_report_stage(game, outcome)
	var expected := StoryStateScript.new()
	expected.load_state(before)
	expected.adjust_value("anwen_trust", -1 if outcome == "public" else 0)
	expected.adjust_value("greyfen_fear", 1 if outcome == "public" else 0)
	for value_id in expected.values:
		if int(game.story_state.values.get(value_id, 0)) != expected.values[value_id]:
			_fail("Report %s applied the wrong %s consequence" % [outcome, value_id])
	expected.free()
	if not failures.is_empty():
		return
	var slot := await _save_campaign_checkpoint(game)
	if not bool(slot.get("ok", false)) or str(slot.get("data", {}).get("story_state", {}).get("flags", {}).get("evidence_report", "")) != outcome:
		_fail("Pause-menu Save lost the actual report outcome")
	else:
		print("REAL_INPUT report_alternative=PASS report=%s exact_values=true anwen_relocated=true actual_save=true" % outcome)

func _check_report_stage(game: Node, outcome: String) -> void:
	if str(game.story_state.get_flag("evidence_report", "")) != outcome or not bool(game.story_state.get_flag("cemetery_bell_rung", false)) or not game.quests.is_completed("main_road_of_crows") or not game.quests.is_active("main_bell_beneath_greyfen"):
		_fail("Report outcome or cemetery handoff was lost")
	var anwen := game.zone_root.find_child("sister_anwen", true, false) as Node3D
	if anwen == null or anwen.global_position.distance_to(CemeterySection.ANWEN_CEMETERY_STAGE) > 0.3 or game.pending_anwen_relocation:
		_fail("Report did not publish Anwen's actual cemetery relocation")
	if game.hud.dialogue_layer.visible or paused or not game.player.can_control or game.player.transition_locked:
		_fail("Report failed to return player input")

func _meet_anwen_and_inspect_graves(_game: Node) -> void:
	# This bounded branch ends at the real report/save, not a repeated cemetery run.
	pass

func _look_south_with_mouse(game: Node) -> void:
	if not failures.is_empty():
		return
	var sensitivity: float = game.camera_rig.sensitivity
	if sensitivity <= 0.0 or not is_finite(sensitivity):
		_fail("Report camera has invalid mouse sensitivity")
		return
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(wrapf(float(game.camera_rig.yaw) - PI, -PI, PI) / sensitivity, 0.0)
	Input.parse_input_event(motion)
	await _frames(3)
	if absf(wrapf(float(game.camera_rig.yaw) - PI, -PI, PI)) > 0.12:
		_fail("Real mouse look did not face the report object")
