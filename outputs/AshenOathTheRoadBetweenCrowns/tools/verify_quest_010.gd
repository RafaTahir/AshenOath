extends SceneTree

const QuestManager = preload("res://scripts/quest_manager.gd")
var failures := 0

func _initialize() -> void:
	var quests_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	var dialogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_dialogue.json"))
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var greyfen_source := FileAccess.get_file_as_string("res://scripts/zones/greyfen_section.gd")
	var wilderness_source := FileAccess.get_file_as_string("res://scripts/zones/campaign_wilderness_section.gd")
	_check(typeof(quests_data) == TYPE_DICTIONARY and quests_data.has("main_names_they_burned"), "Names quest data is missing")
	_check(typeof(quests_data) == TYPE_DICTIONARY and quests_data.has("main_ash_at_the_mill"), "Mill quest data is missing")
	_check(typeof(dialogue) == TYPE_DICTIONARY and dialogue.has("names_decision"), "Names decision dialogue is missing")
	_check(typeof(dialogue) == TYPE_DICTIONARY and dialogue.has("miller_record"), "Miller record dialogue is missing")

	var fragment_ids := ["fragment_anwen", "fragment_rook", "fragment_tor", "fragment_mira"]
	var fragment_locations := [greyfen_source, wilderness_source]
	for fragment_id in fragment_ids:
		var located := false
		for source in fragment_locations:
			if fragment_id in source:
				located = true
				break
		_check(located, "Register fragment has no authored location: %s" % fragment_id)
	_verify_fragment_permutations(fragment_ids)

	var names_actions: Array = dialogue.get("names_decision", {}).get("actions", [])
	_check(names_actions.size() == 2, "Names decision must offer publish and withhold")
	_check(_distinct_flag_values(names_actions, "names_policy", ["published", "withheld"]), "Names policies are incomplete or duplicated")
	var mill_actions: Array = dialogue.get("miller_record", {}).get("actions", [])
	_check(mill_actions.size() == 3, "Mill record must offer preserve, burn, and expose")
	_check(_distinct_flag_values(mill_actions, "mill_fate", ["preserved", "burned", "exposed"]), "Mill fates are incomplete or duplicated")

	_check("choice_objective_id" in game_source and "That decision has already been made." in game_source, "Story choices lack the generic one-shot guard")
	_check("_consume_story_choice_interactable" in game_source, "Story choice interaction cleanup is missing")
	for value in ["published", "withheld"]:
		_check(value in greyfen_source, "Names aftermath presentation is missing: %s" % value)
	for value in ["preserved", "burned", "exposed"]:
		_check(value in wilderness_source, "Mill aftermath presentation is missing: %s" % value)

	await _verify_runtime_choices(names_actions, mill_actions)
	print("QUEST-010 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _verify_fragment_permutations(fragment_ids: Array) -> void:
	for order in _permutations(fragment_ids):
		var manager = QuestManager.new()
		root.add_child(manager)
		manager.load_quests("res://data/quests.json")
		manager.unlocked["main_names_they_burned"] = true
		_check(manager.start_quest("main_names_they_burned"), "Names quest failed to start for fragment permutation")
		for index in range(order.size()):
			_check(manager.complete_evidence("main_names_they_burned", str(order[index])), "Fragment failed in order %s" % str(order))
			if index < 2:
				_check(not manager.is_objective_done("main_names_they_burned", "reconstruct_register"), "Register reconstructed before three fragments")
		_check(manager.is_objective_done("main_names_they_burned", "reconstruct_register"), "Three fragments did not reconstruct the register")
		manager.free()

func _verify_runtime_choices(names_actions: Array, mill_actions: Array) -> void:
	var scene = load("res://scenes/main.tscn")
	_check(scene != null, "Main scene could not be loaded for runtime choices")
	if scene == null:
		return
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(2)
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(35)

	game.quests.unlocked["main_names_they_burned"] = true
	if not game.quests.is_active("main_names_they_burned"):
		_check(game.quests.start_quest("main_names_they_burned"), "Names quest did not start in runtime")
	for fragment in ["fragment_anwen", "fragment_rook", "fragment_tor"]:
		game.quests.complete_evidence("main_names_they_burned", fragment)
	_check(game.quests.is_objective_done("main_names_they_burned", "reconstruct_register"), "Runtime register threshold did not complete")
	if not names_actions.is_empty():
		var names_action: Dictionary = names_actions[0]
		game.call("_handle_dialogue_action", names_action)
		await _frames(3)
		_check(str(game.story_state.get_flag("names_policy", "")) == "published", "Names policy did not persist")
		_check(game.quests.is_objective_done("main_names_they_burned", "names_choice"), "Names choice did not complete its objective")
		var fear_after := int(game.story_state.values.get("greyfen_fear", 0))
		game.call("_handle_dialogue_action", names_action)
		await _frames(2)
		_check(int(game.story_state.values.get("greyfen_fear", 0)) == fear_after, "Names choice applied twice")

	game.quests.unlocked["main_ash_at_the_mill"] = true
	if not game.quests.is_active("main_ash_at_the_mill"):
		_check(game.quests.start_quest("main_ash_at_the_mill"), "Mill quest did not start in runtime")
	for objective in ["reach_mill", "inspect_millstones", "mill_encounter"]:
		game.quests.complete_objective("main_ash_at_the_mill", objective)
	_check(not game.quests.is_objective_done("main_ash_at_the_mill", "mill_choice"), "Mill choice was completed before the record action")
	if not mill_actions.is_empty():
		var mill_action: Dictionary = mill_actions[0]
		game.call("_handle_dialogue_action", mill_action)
		await _frames(3)
		_check(str(game.story_state.get_flag("mill_fate", "")) == "preserved", "Mill fate did not persist")
		_check(game.quests.is_objective_done("main_ash_at_the_mill", "mill_choice"), "Mill choice did not complete its objective")
		var trust_after := int(game.story_state.values.get("greyfen_fear", 0))
		game.call("_handle_dialogue_action", mill_action)
		await _frames(2)
		_check(int(game.story_state.values.get("greyfen_fear", 0)) == trust_after, "Mill choice applied twice")

	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
	game.queue_free()
	await _frames(8)

func _distinct_flag_values(actions: Array, flag_id: String, expected: Array) -> bool:
	var found: Array[String] = []
	for action in actions:
		var value := str(action.get("sets_flags", {}).get(flag_id, ""))
		if value != "":
			found.append(value)
	var unique: Array[String] = []
	for value in found:
		if not unique.has(value):
			unique.append(value)
	return found.size() == expected.size() and unique.size() == expected.size() and found.all(func(value): return value in expected)

func _permutations(values: Array) -> Array:
	if values.size() <= 1:
		return [values.duplicate()]
	var result: Array = []
	for index in range(values.size()):
		var rest := values.duplicate()
		var first = rest.pop_at(index)
		for tail in _permutations(rest):
			result.append([first] + tail)
	return result

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
