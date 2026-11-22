extends SceneTree

var failures := 0

func _initialize() -> void:
	var contract = JSON.parse_string(FileAccess.get_file_as_string("res://side_quest_contract.json"))
	check(typeof(contract) == TYPE_DICTIONARY, "SIDE-001 contract is invalid")
	check(contract.get("quests", {}).size() == 5, "SIDE-001 must contain five authored quests")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await settle(3)
	for id in contract["quests"].keys():
		check(game.quests.is_unlocked(id), "Side quest is not available: %s" % id)
		game.quests.start_quest(id)
	game.call("_load_zone", "greyfen", Vector3(0, 1, 7))
	await settle(3)
	check(game.zone_root.find_child("village_stories", true, false) == null, "Instant side-quest completion shortcut still exists")
	for interaction in ["grave_bell", "massacre_iron", "empty_grave_tracks", "sheepfold"]:
		check(game.zone_root.find_child(interaction, true, false) != null, "Missing Greyfen side interaction: %s" % interaction)
	for interaction in ["grave_bell", "massacre_iron", "empty_grave_tracks", "sheepfold"]:
		var area = game.zone_root.find_child(interaction, true, false)
		if area != null:
			game.call("_handle_interaction", area)
	check(not game.quests.is_objective_done("side_black_dog", "find_dog"), "Sheepfold alone bypassed the Black Dog encounter")
	# This verifier checks quest structure, not player traversal. Suppress the
	# unrelated opening pack so its five slots do not prevent the side bandits.
	game.quests.complete_objective("main_road_of_crows", "fight_ghoulkin")
	game.call("_load_zone", "wychwood", Vector3(0, 1, 10))
	await settle(3)
	var camp = game.zone_root.find_child("bandit_camp", true, false)
	check(camp != null, "Black Dog camp evidence is missing")
	if camp != null:
		game.call("_handle_interaction", camp)
	check(not game.quests.is_objective_done("side_black_dog", "find_dog"), "Camp evidence alone bypassed the Black Dog bandits")
	var bandits := 0
	for enemy in game.active_enemies.duplicate():
		if is_instance_valid(enemy) and enemy.enemy_id == "bandit" and not enemy.dead:
			bandits += 1
			enemy.apply_damage(9999.0, "side_contract_test")
	check(bandits == 2, "Black Dog encounter did not stage two bandits")
	check(game.quests.is_objective_done("side_black_dog", "find_dog"), "Black Dog investigation did not finish after evidence and bandits")
	var roots = game.zone_root.find_child("bitter_roots", true, false)
	check(roots != null, "Bitter Roots world interaction is missing")
	if roots != null:
		game.call("_handle_interaction", roots)
	game.call("_load_zone", "greyfen", Vector3(0, 1, 7))
	await settle(3)
	check(game.zone_root.find_child("returned_soldier", true, false) != null, "Returned soldier did not appear")
	var resolvers := {
		"side_widows_bell": "widow_elna",
		"side_iron_remembers": "blacksmith_tor",
		"side_bitter_roots": "mira",
		"side_black_dog": "farmer_toma",
		"side_empty_grave": "returned_soldier"
	}
	for quest_id in resolvers:
		var dialogue_id: String = resolvers[quest_id]
		var dialogue = game.dialogue.get_dialogue(dialogue_id)
		var resolution: Dictionary = {}
		var objective_id: String = str(game.quests.quest_defs[quest_id]["objectives"][-1]["id"])
		for action in dialogue.get("actions", []):
			if str(action.get("quest", "")) == quest_id and str(action.get("objective", "")) == objective_id:
				resolution = action
				break
		check(not resolution.is_empty(), "Missing side resolution on %s" % dialogue_id)
		if not resolution.is_empty():
			game.call("_handle_dialogue_action", resolution)
			await settle(1)
	for id in contract["quests"].keys():
		check(game.quests.is_completed(id), "Side quest did not complete: %s" % id)
	check(str(game.story_state.get_flag("widow_truth", "")) != "", "Widow consequence missing")
	check(str(game.story_state.get_flag("iron_fate", "")) != "", "Iron consequence missing")
	check(str(game.story_state.get_flag("mira_truth", "")) != "", "Mira consequence missing")
	check(str(game.story_state.get_flag("black_dog_fate", "")) != "", "Black Dog consequence missing")
	check(str(game.story_state.get_flag("returned_soldier_fate", "")) != "", "Returned soldier consequence missing")
	print("SIDE-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	print("VERIFIER_PHASE: SHUTDOWN")
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	for _frame in range(game.ZONE_RETIRE_FRAMES + 4):
		await process_frame
	root.remove_child(game)
	game.free()
	RenderingServer.force_sync()
	for _frame in range(8):
		await process_frame
	quit(0 if failures == 0 else 1)

func settle(count: int) -> void:
	for _index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
