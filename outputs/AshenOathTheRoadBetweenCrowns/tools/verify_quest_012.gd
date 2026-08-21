extends SceneTree

var failures := 0
const ENDINGS := ["expose", "free", "bind", "kill"]
const COVENANTS := {"expose":"witness", "free":"mercy", "bind":"duty", "kill":"ash"}

func _initialize() -> void:
	var quests_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	var dialogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_dialogue.json"))
	var contract = JSON.parse_string(FileAccess.get_file_as_string("res://epilogue_contract.json"))
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var finale_source := FileAccess.get_file_as_string("res://scripts/zones/campaign_finale_section.gd")
	_check(typeof(quests_data) == TYPE_DICTIONARY and quests_data.has("main_crowns_without_mercy"), "Crowns Without Mercy quest data is missing")
	_check(typeof(quests_data) == TYPE_DICTIONARY and quests_data.has("main_hart_remembers"), "The Hart Remembers quest data is missing")
	_check(_has_objectives(quests_data.get("main_crowns_without_mercy", {}).get("objectives", []), ["gather_witnesses", "greyfen_assembly", "confession_choice"]), "Crowns Without Mercy objectives are incomplete")
	_check(_has_objectives(quests_data.get("main_hart_remembers", {}).get("objectives", []), ["enter_glade", "hear_testimony", "final_choice"]), "The Hart Remembers objectives are incomplete")

	var assembly_actions: Array = dialogue.get("assembly_choice", {}).get("actions", [])
	_check(assembly_actions.size() == 3, "Assembly must expose three confession methods")
	_check(_distinct_flag_values(assembly_actions, "confession_method", ["witnesses", "kael", "edric"]), "Assembly confession methods are not distinct")
	var hart_actions: Array = dialogue.get("white_hart", {}).get("actions", [])
	_check(hart_actions.size() == 4, "White Hart must expose exactly four endings")
	_check(_distinct_action_values(hart_actions, "ending", ENDINGS), "White Hart ending actions are incomplete or duplicated")
	_check(typeof(contract) == TYPE_DICTIONARY, "Epilogue contract is invalid")
	if typeof(contract) == TYPE_DICTIONARY:
		for key in ["covenant", "greyfen", "anwen", "vargan"]:
			_check(str(key) in contract.get("required_cards", []), "Epilogue required card is missing: %s" % key)
		for input_id in ["final_covenant", "final_witnesses", "epilogue_cards"]:
			_check(input_id == "epilogue_cards" or input_id in contract.get("inputs", []), "Epilogue input contract is missing: %s" % input_id)
	_check("final_choice_completed" in game_source and "covenant has already been chosen" in game_source, "Ending one-shot guard is missing")
	_check("HartAftermath" in finale_source and "final_covenant" in finale_source, "Hart aftermath dressing is missing")

	var hart_actions_by_id := {}
	for action in hart_actions:
		hart_actions_by_id[str(action.get("ending", ""))] = action
	for ending in ENDINGS:
		await _verify_runtime_ending(hart_actions_by_id.get(ending, {}), ending)

	print("QUEST-012 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _verify_runtime_ending(action: Dictionary, ending: String) -> void:
	_check(not action.is_empty(), "Missing runtime action for ending %s" % ending)
	if action.is_empty():
		return
	var scene = load("res://scenes/main.tscn")
	_check(scene != null, "Main scene could not load for ending %s" % ending)
	if scene == null:
		return
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(2)
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(35)
	game.quests.unlocked["main_hart_remembers"] = true
	_check(game.quests.start_quest("main_hart_remembers"), "Hart quest did not start for ending %s" % ending)
	game.quests.complete_objective("main_hart_remembers", "enter_glade")
	game.story_state.set_flag("confession_method", "witnesses")
	game.story_state.set_flag("halvern_fate", "witness")
	game.story_state.set_flag("edric_stance", "cooperate")
	game.story_state.set_flag("crow_shrine_state", "cleansed")
	game.call("_load_zone", "hart_glade", Vector3(0, 1, 9))
	await _frames(18)
	var hart_prompt = game.zone_root.find_child("white_hart", true, false)
	_check(hart_prompt != null, "Hart interaction is missing before ending %s" % ending)
	game.call("_handle_dialogue_action", action)
	await _frames(8)
	_check(str(game.story_state.get_flag("final_covenant", "")) == str(COVENANTS[ending]), "Ending %s stored the wrong covenant" % ending)
	_check(typeof(game.story_state.get_flag("final_witnesses", [])) == TYPE_ARRAY, "Ending %s did not snapshot final witnesses" % ending)

	if ending in ["bind", "kill"]:
		_check(str(game.pending_ending) == ending, "Ending %s did not retain its pending combat outcome" % ending)
		var boss = game.zone_root.find_child("WhiteHartFinalEncounter", true, false)
		_check(boss != null, "Ending %s did not stage the White Hart combat encounter" % ending)
		if boss != null:
			boss.apply_damage(99999.0, "quest_012_verifier")
		await _frames(8)
	else:
		_check(game.quests.is_completed("main_hart_remembers"), "Peaceful ending %s did not complete The Hart Remembers" % ending)

	_check(bool(game.story_state.get_flag("final_choice_completed", false)), "Ending %s did not complete the final choice" % ending)
	_check(game.quests.is_completed("main_hart_remembers"), "Ending %s did not complete the Hart quest" % ending)
	var cards: Array = game.story_state.get_flag("epilogue_cards", [])
	_check(cards.size() >= 4, "Ending %s did not produce the required epilogue cards" % ending)
	_check(str(game.story_state.get_flag("final_covenant", "")) == str(COVENANTS[ending]), "Ending %s changed covenant after resolution" % ending)
	var saved_story: Dictionary = game.story_state.save_state()
	var saved_world: Dictionary = game.save_world_state()
	var saved_cards: Array = cards.duplicate(true)
	var saved_covenant := str(game.story_state.get_flag("final_covenant", ""))
	game.get_tree().paused = false
	game.call("_handle_dialogue_action", action)
	await _frames(3)
	_check(str(game.story_state.get_flag("final_covenant", "")) == saved_covenant, "Ending %s changed after repeat activation" % ending)
	_check(game.story_state.get_flag("epilogue_cards", []) == saved_cards, "Ending %s changed epilogue cards after repeat activation" % ending)
	game.story_state.load_state(saved_story)
	game.load_world_state(saved_world)
	_check(str(game.story_state.get_flag("final_covenant", "")) == saved_covenant, "Ending %s failed story-state round trip" % ending)
	_check(game.story_state.get_flag("epilogue_cards", []) == saved_cards, "Ending %s failed epilogue-card round trip" % ending)
	game.call("_load_zone", "hart_glade", Vector3(0, 1, 9))
	await _frames(12)
	_check(game.zone_root.find_child("HartAftermathSeal", true, false) != null, "Ending %s did not rebuild visible Hart aftermath" % ending)
	_check(game.zone_root.find_child("white_hart", true, false) == null, "Ending %s left a stale Hart interaction after reload" % ending)
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
	game.queue_free()
	await _frames(8)

func _has_objectives(objectives: Array, ids: Array) -> bool:
	var found := {}
	for objective in objectives:
		found[str(objective.get("id", ""))] = true
	for id in ids:
		if not found.has(id):
			return false
	return true

func _distinct_flag_values(actions: Array, flag_id: String, expected: Array) -> bool:
	var values := []
	for action in actions:
		var value := str(action.get("sets_flags", {}).get(flag_id, ""))
		if value == "" or values.has(value):
			return false
		values.append(value)
	return values.size() == expected.size() and values.all(func(value): return expected.has(value))

func _distinct_action_values(actions: Array, key: String, expected: Array) -> bool:
	var values := []
	for action in actions:
		var value := str(action.get(key, ""))
		if value == "" or values.has(value):
			return false
		values.append(value)
	return values.size() == expected.size() and values.all(func(value): return expected.has(value))

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
