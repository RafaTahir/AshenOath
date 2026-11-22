extends "res://tools/verify_opening_real_input_native.gd"

func _is_reload() -> bool:
	return OS.get_cmdline_user_args().has("--story-choice-reload")

func _check_reloaded_choice(game: Node, flag: String, outcome: String, completed: String, active: String) -> void:
	if str(game.story_state.get_flag(flag, "")) != outcome or not game.quests.is_completed(completed) or not game.quests.is_active(active):
		_fail("Normal Continue lost %s=%s or the chapter handoff" % [flag, outcome])
		return
	var slot := await _save_campaign_checkpoint(game)
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or str(saved.get("story_state", {}).get("flags", {}).get(flag, "")) != outcome or not saved.get("quests", {}).get("completed", []).has(completed) or not saved.get("quests", {}).get("active", {}).has(active):
		_fail("Real manual save lost the reloaded %s=%s chapter handoff" % [flag, outcome])
	else:
		print("REAL_INPUT alternative_reload=PASS %s=%s normal_continue_and_manual_save=true" % [flag, outcome])

func _travel_to_bandit_road(game: Node) -> void:
	var outcome := "burned" if OS.get_cmdline_user_args().has("--mill-burned") else "exposed"
	if _is_reload():
		await _check_reloaded_choice(game, "mill_fate", outcome, "main_ash_at_the_mill", "main_soldier_without_banner")
	elif not game.quests.is_objective_done("main_ash_at_the_mill", "mill_encounter") or str(game.story_state.get_flag("mill_fate", "")) != "":
		_fail("Mill alternative requires the genuine resolved-encounter pre-choice checkpoint")
	else:
		await _choose_mill_record(game)

func _fight_senn_guard(game: Node) -> void:
	var outcome := "exile" if OS.get_cmdline_user_args().has("--senn-exile") else "punished"
	if _is_reload():
		await _check_reloaded_choice(game, "senn_fate", outcome, "main_soldier_without_banner", "main_blood_under_stone")
	elif not game.quests.is_objective_done("main_soldier_without_banner", "senn_confrontation") or str(game.story_state.get_flag("senn_fate", "")) != "":
		_fail("Senn alternative requires the genuine surrendered-guard pre-choice checkpoint")
	else:
		await _confront_senn(game)

func _resolve_halvern_witness(game: Node) -> void:
	var outcome := "released" if OS.get_cmdline_user_args().has("--halvern-released") else "destroyed"
	if _is_reload():
		await _check_reloaded_choice(game, "halvern_fate", outcome, "main_last_witness", "main_crowns_without_mercy")
		if not bool(game.story_state.get_flag("boss_reward_sealed_testimony", false)) or not bool(game.story_state.get_flag("halvern_testimony_available", false)) or str(game.story_state.get_flag("boss_halvern_boss_outcome", "")) != outcome:
			_fail("Normal Continue lost Halvern's reward, aftermath or boss outcome")
	else:
		await super._resolve_halvern_witness(game)

func _choose_assembly_testimony(game: Node) -> void:
	var outcome := "kael" if OS.get_cmdline_user_args().has("--assembly-kael") else "edric"
	if _is_reload():
		await _check_reloaded_choice(game, "confession_method", outcome, "main_crowns_without_mercy", "main_hart_remembers")
	else:
		await super._choose_assembly_testimony(game)
