extends SceneTree

var failures := 0

func _initialize() -> void:
	var dialogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_dialogue.json"))
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var cemetery_source := FileAccess.get_file_as_string("res://scripts/zones/cemetery_section.gd")
	_check(typeof(dialogue) == TYPE_DICTIONARY and dialogue.has("crow_shrine_choice"), "Crow Shrine dialogue is missing")
	var actions: Array = dialogue.get("crow_shrine_choice", {}).get("actions", [])
	_check(actions.size() == 3, "Crow Shrine must expose exactly three choices")
	var states: Array[String] = []
	for action in actions:
		var flag_value := str(action.get("sets_flags", {}).get("crow_shrine_state", ""))
		_check(flag_value in ["cleansed", "disturbed", "bound"], "Invalid Crow Shrine state: %s" % flag_value)
		_check(not states.has(flag_value), "Crow Shrine choices duplicate a state")
		states.append(flag_value)
	_check(states.size() == 3, "Crow Shrine states are not distinct")
	_check('"crow_shrine_state"' in game_source and "already answered" in game_source, "Crow Shrine one-shot guard is missing")
	_check("crow_shrine_choice" in game_source and "complete_objective" in game_source, "Shrine choice does not complete its objective")
	for state in ["cleansed", "disturbed", "bound"]:
		_check(('shrine_state == "%s"' % state) in cemetery_source or ('shrine_state == "%s"' % state) in game_source, "No visual branch for shrine state: %s" % state)
	_check("cemetery_bell_silent" in cemetery_source or "cemetery_bell_silent" in game_source, "Bell aftermath state is not dressed")

	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(2)
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(35)
	game.quests.unlocked["main_bell_beneath_greyfen"] = true
	_check(game.quests.start_quest("main_bell_beneath_greyfen"), "Bell Beneath Greyfen did not start")
	for objective_id in ["meet_anwen_gate", "grave_truth", "cemetery_ambush", "open_chapel"]:
		game.quests.complete_objective("main_bell_beneath_greyfen", objective_id)
	var choice: Dictionary = actions[0] if not actions.is_empty() else {}
	game.call("_handle_dialogue_action", choice)
	await _frames(4)
	var chosen_state := str(choice.get("sets_flags", {}).get("crow_shrine_state", ""))
	_check(str(game.story_state.get_flag("crow_shrine_state", "")) == chosen_state, "Shrine state did not persist through runtime action")
	_check(game.quests.is_objective_done("main_bell_beneath_greyfen", "crow_shrine_choice") or game.quests.is_completed("main_bell_beneath_greyfen"), "Shrine action did not complete its objective")
	var trust_after := int(game.story_state.values.get("anwen_trust", 0))
	var debt_after := int(game.story_state.values.get("hart_debt", 0))
	game.call("_handle_dialogue_action", choice)
	await _frames(2)
	_check(int(game.story_state.values.get("anwen_trust", 0)) == trust_after and int(game.story_state.values.get("hart_debt", 0)) == debt_after, "Shrine choice was applied twice")
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
	game.queue_free()
	await _frames(8)
	print("QUEST-009 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
