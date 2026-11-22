extends "res://tools/verify_story_combined_native.gd"

func _meet_anwen_and_inspect_graves(game: Node) -> void:
	await super._meet_anwen_and_inspect_graves(game)
	if not failures.is_empty():
		return
	stabilize_route_bearing = true
	await _run_campaign_from(game, 0)
	if failures.is_empty():
		print("REAL_INPUT continuous_campaign=PASS new_game=true single_process=true chapters=10 ending=mercy no_bypass=true")

func _run_campaign_from(game: Node, first_leg: int) -> void:
	var legs: Array[Callable] = [
		_fight_bell_eater_real_input, _continue_teeth_in_rain, _continue_names_they_burned,
		_return_register_to_deep_wood, _fight_rootbound_real_input,
		_return_from_rootbound, _prepare_for_ash_mill, _travel_to_ash_mill,
		_inspect_ash_millstones,
		_fight_ashwing_real_input, _travel_to_bandit_road, _fight_senn_guard,
		_travel_to_castle_approach,
	]
	for leg in legs.slice(first_leg):
		if not failures.is_empty():
			return
		await _resume_saved_route(game)
		print("REAL_INPUT continuous_leg=%s zone=%s" % [leg.get_method(), game.current_zone_id])
		await leg.call(game)
		_check_carried_choices(game)
	if failures.is_empty():
		if not game.quests.is_completed("main_hart_remembers") or str(game.story_state.get_flag("final_covenant", "")) != "mercy" or str(game.quests.world_flags.get("ending", "")) != "free" or not bool(game.story_state.get_flag("final_choice_completed", false)):
			_fail("Continuous New Game campaign did not retain its actual Mercy ending")
