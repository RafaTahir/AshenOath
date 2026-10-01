extends "res://tools/verify_story_alternative_native.gd"

func _save_choice_flag(game: Node, flag: String, outcome: String) -> void:
	if not failures.is_empty():
		return
	var slot := await _save_campaign_checkpoint(game)
	if not bool(slot.get("ok", false)) or str(slot.get("data", {}).get("story_state", {}).get("flags", {}).get(flag, "")) != outcome:
		_fail("Real pause-menu save lost %s=%s" % [flag, outcome])
	else:
		print("REAL_INPUT alternative_manual_save=PASS %s=%s" % [flag, outcome])

func _open_crow_chapel(game: Node) -> void:
	var outcome := "disturbed" if OS.get_cmdline_user_args().has("--shrine-disturbed") else "bound"
	if _is_reload():
		await _check_reloaded_choice(game, "crow_shrine_state", outcome, "main_bell_beneath_greyfen", "main_teeth_in_rain")
	else:
		await super._open_crow_chapel(game)
		if failures.is_empty() and (not game.quests.is_completed("main_bell_beneath_greyfen") or not game.quests.is_active("main_teeth_in_rain")):
			_fail("Crow Shrine did not advance to Teeth in the Rain")
		await _save_choice_flag(game, "crow_shrine_state", outcome)

func _continue_teeth_in_rain(game: Node) -> void:
	await _open_crow_chapel(game)

func _complete_bog_wretch(game: Node) -> void:
	var outcome := "preserved" if OS.get_cmdline_user_args().has("--bog-preserved") else "returned"
	if _is_reload():
		await _check_reloaded_choice(game, "bog_core_fate", outcome, "main_teeth_in_rain", "main_names_they_burned")
		return
	if not game.quests.is_objective_done("main_teeth_in_rain", "fight_bog_wretch") or str(game.story_state.get_flag("bog_core_fate", "")) != "":
		_fail("Memory-core choice requires the genuine defeated-Bog pre-choice save")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_W, "bog_core_saved_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "bog_core_choice", 6000)
	var oil_before := int(game.inventory.items.get("moon_oil", 0))
	var choice := "Preserve it for study" if outcome == "preserved" else "Return it to Oren's grave"
	await _choose_focused_dialogue_action(game, "bog_core_choice", choice, "memory_core_alternative")
	if not failures.is_empty():
		return
	if not game.quests.is_completed("main_teeth_in_rain") or not game.quests.is_active("main_names_they_burned") or str(game.story_state.get_flag("bog_core_fate", "")) != outcome or not bool(game.story_state.get_flag("moon_oil_mastery", false)) or int(game.inventory.items.get("moon_oil", 0)) != oil_before + 1:
		_fail("Memory-core decision lost its fate, preparation reward or chapter handoff")
		return
	print("REAL_INPUT memory_core_alternative=PASS fate=%s moon_oil_reward=true" % outcome)
	await _save_choice_flag(game, "bog_core_fate", outcome)

func _resolve_names_choice(game: Node) -> void:
	if _is_reload():
		await _check_reloaded_choice(game, "names_policy", "withheld", "main_names_they_burned", "main_ash_at_the_mill")
	else:
		await _turn_camera_north(game)
		await super._resolve_names_choice(game)
		await _save_choice_flag(game, "names_policy", "withheld")

func _resolve_record_ledger(game: Node) -> void:
	if not _is_reload():
		await super._resolve_record_ledger(game)
		return
	var selected_flag := "vargan_ledger_hidden" if OS.get_cmdline_user_args().has("--ledger-hidden") else "vargan_ledger_left_copied"
	if not game.quests.is_active("main_blood_under_stone") or not game.quests.is_objective_done("main_blood_under_stone", "ledger_choice") or not game.quests.is_objective_done("main_blood_under_stone", "recover_ledger") or not bool(game.story_state.get_flag("vargan_ledger_choice_made", false)):
		_fail("Normal Continue lost the resolved ledger beat")
		return
	for flag in ["vargan_ledger_hidden", "vargan_ledger_left_copied", "vargan_ledger_taken_openly"]:
		if bool(game.story_state.get_flag(flag, false)) != (flag == selected_flag):
			_fail("Normal Continue lost the exclusive ledger decision")
			return
	var slot := await _save_campaign_checkpoint(game)
	var flags: Dictionary = slot.get("data", {}).get("story_state", {}).get("flags", {})
	if not bool(slot.get("ok", false)) or not bool(flags.get(selected_flag, false)):
		_fail("Real manual save lost the reloaded ledger decision")
	else:
		print("REAL_INPUT ledger_alternative_reload=PASS flag=%s" % selected_flag)
