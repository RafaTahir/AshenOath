extends SceneTree

var failures := 0

func _initialize() -> void:
	var contract = JSON.parse_string(FileAccess.get_file_as_string("res://hart_remembers_contract.json"))
	check(typeof(contract) == TYPE_DICTIONARY, "QUEST-005 contract is invalid")
	check(contract.get("endings", {}).size() == 4, "The Hart Remembers must preserve four endings")
	var scene = load("res://scenes/main.tscn")
	check(scene != null, "Main scene is missing")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await settle(3)

	game.quests.unlocked["main_last_witness"] = true
	game.quests.start_quest("main_last_witness")
	game.call("_load_zone", "undercroft", Vector3(0, 1, 8))
	await settle(3)
	var guardian = game.zone_root.find_child("HalvernGuard", true, false)
	check(guardian != null, "Halvern's threshold encounter is missing")
	if guardian != null:
		guardian.apply_damage(9999.0, "quest_005_verifier")
		await settle(3)
	var halvern = game.dialogue.get_dialogue("halvern")
	game.call("_handle_dialogue_action", halvern["actions"][0])
	await settle(3)
	check(str(game.story_state.get_flag("halvern_fate", "")) == "witness", "Halvern witness choice was not stored")
	check(game.quests.is_active("main_crowns_without_mercy"), "Crowns Without Mercy did not start")

	game.call("_load_zone", "assembly", Vector3(0, 1, 8))
	await settle(3)
	var evidence = game.zone_root.find_child("witnesses_ready", true, false)
	check(evidence != null, "Assembly evidence interaction is missing")
	if evidence != null:
		game.call("_handle_interaction", evidence)
	var assembly = game.dialogue.get_dialogue("assembly_choice")
	game.call("_handle_dialogue_action", assembly["actions"][0])
	await settle(3)
	check(str(game.story_state.get_flag("confession_method", "")) == "witnesses", "Assembly confession method was not stored")
	check(game.quests.is_active("main_hart_remembers"), "The Hart Remembers did not start")

	game.call("_load_zone", "hart_glade", Vector3(0, 1, 9))
	await settle(3)
	var hart = game.dialogue.get_dialogue("white_hart")
	check(hart.get("actions", []).size() == 4, "White Hart does not expose four endings")
	game.call("_handle_dialogue_action", hart["actions"][1])
	await settle(3)
	check(str(game.story_state.get_flag("final_covenant", "")) == "mercy", "Mercy ending was not stored")
	check(game.quests.is_completed("main_hart_remembers"), "Peaceful Hart ending did not complete the campaign")
	var witnesses = game.story_state.get_flag("final_witnesses", [])
	check(typeof(witnesses) == TYPE_ARRAY and "halvern" in witnesses, "Final witness snapshot omitted Halvern")
	print("QUEST-005 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func settle(count: int) -> void:
	for _index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
