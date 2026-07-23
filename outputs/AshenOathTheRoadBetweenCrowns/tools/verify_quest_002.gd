extends SceneTree

var failures := 0

func _initialize() -> void:
	var scene = load("res://scenes/main.tscn")
	_check(scene != null, "Main scene could not be loaded")
	if scene == null:
		_finish()
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _settle(3)

	game.quests.unlocked["main_teeth_in_rain"] = true
	_check(game.quests.start_quest("main_teeth_in_rain"), "Teeth in the Rain could not start")
	game.story_state.set_flag("teeth_in_rain_available", true)
	game.call("_load_zone", "greyfen", Vector3(0, 1, -13))
	await _settle(3)

	var mooncap_before := int(game.inventory.ingredients.get("mooncap", 0))
	var mira_data: Dictionary = game.dialogue.get_dialogue("mira")
	var supply_action := _find_action(mira_data, "Give me what Moon Oil needs.")
	_check(not supply_action.is_empty(), "Mira's one-time Moon Oil supply action is missing")
	if not supply_action.is_empty():
		game.call("_handle_dialogue_action", supply_action)
		await _settle(2)
	_check(int(game.inventory.ingredients.get("mooncap", 0)) == mooncap_before + 1, "Mira did not grant exactly one mooncap")
	mira_data = game.dialogue.get_dialogue("mira")
	_check(_find_action(mira_data, "Give me what Moon Oil needs.").is_empty(), "Mira can grant the same supplies repeatedly")
	var briefing := _find_action(mira_data, "I will read the chapel register.")
	_check(not briefing.is_empty(), "Mira's investigation briefing is missing")
	if not briefing.is_empty():
		game.call("_handle_dialogue_action", briefing)
		await _settle(2)
	_check(game.quests.is_objective_done("main_teeth_in_rain", "speak_mira"), "Mira briefing did not progress the quest")

	var chapel_names = _find_named(game.zone_root, "chapel_names")
	_check(chapel_names != null, "Erased chapel names did not appear after Mira's briefing")
	if chapel_names != null:
		game.call("_handle_interaction", chapel_names)
		await _settle(1)
	_check(game.quests.is_objective_done("main_teeth_in_rain", "read_chapel_names"), "Chapel evidence did not progress")
	_check(bool(game.story_state.get_flag("chapel_names_read", false)), "Chapel evidence state was not persisted")

	game.call("_load_zone", "deep_wood", Vector3(0, 1, 12))
	await _settle(3)
	_check(_living_enemy_count(game, "bog_wretch") == 0, "Bog Wretch spawned before Oren's name was spoken")

	game.call("_load_zone", "wychwood", Vector3(0, 1, 13))
	await _settle(3)
	var ritual = _find_named(game.zone_root, "ritual_stones")
	_check(ritual != null, "Ritual stones did not appear after reading the chapel names")
	_check(_living_enemy_count(game, "bog_wretch") == 0, "Bog Wretch spawned prematurely in Wychwood")
	if ritual != null:
		game.call("_handle_interaction", ritual)
		await _settle(1)
	_check(game.quests.is_objective_done("main_teeth_in_rain", "name_the_dead"), "Speaking Oren's name did not progress")
	_check(bool(game.story_state.get_flag("oren_name_spoken", false)), "Oren's spoken-name state was not persisted")
	_check(_find_gate_to(game.zone_root, "deep_wood") != null, "Deeper Wychwood gate did not unlock")

	game.call("_load_zone", "deep_wood", Vector3(0, 1, 12))
	await _settle(3)
	_check(_living_enemy_count(game, "bog_wretch") == 1, "Deeper Wychwood must contain exactly one Bog Wretch")
	var bog = _find_living_enemy(game, "bog_wretch")
	if bog != null:
		game.call("_expose_bog_core", bog, "Moon Oil")
		_check(bool(game.story_state.get_flag("bog_core_exposed", false)), "Moon Oil exposure did not reveal the memory core")
		game.call("_on_enemy_died", bog)
		await _settle(1)
	_check(game.quests.is_objective_done("main_teeth_in_rain", "fight_bog_wretch"), "Bog Wretch victory did not progress")
	_check(_find_named(game.zone_root, "bog_core_choice") != null, "Memory-core choice did not appear after victory")

	var core_data: Dictionary = game.dialogue.get_dialogue("bog_core_choice")
	var core_actions: Array = core_data.get("actions", [])
	_check(core_actions.size() == 3, "Memory core does not offer three consequences")
	var oil_before := int(game.inventory.items.get("moon_oil", 0))
	if not core_actions.is_empty():
		game.call("_handle_dialogue_action", core_actions[0])
		await _settle(2)
	_check(game.quests.is_completed("main_teeth_in_rain"), "Memory-core choice did not complete Teeth in the Rain")
	_check(game.quests.is_active("main_names_they_burned"), "Act Two handoff did not start")
	_check(bool(game.story_state.get_flag("moon_oil_mastery", false)), "Refined Moon Oil formula was not learned")
	_check(int(game.inventory.items.get("moon_oil", 0)) == oil_before + 1, "Memory-core consequence did not grant Moon Oil")

	game.inventory.ingredients["mooncap"] = 2
	game.inventory.ingredients["redroot"] = 1
	_check(game.crafting.craft("moon_oil"), "Refined Moon Oil could not be crafted")
	_check(int(game.inventory.ingredients.get("mooncap", -1)) == 1, "Refined formula did not reduce Moon Oil's net mooncap cost")
	_verify_legacy_migration()
	_finish()

func _verify_legacy_migration() -> void:
	var manager = preload("res://scripts/quest_manager.gd").new()
	manager.load_quests("res://data/quests.json")
	manager.unlocked["main_teeth_in_rain"] = true
	manager.start_quest("main_teeth_in_rain")
	manager.complete_objective("main_teeth_in_rain", "name_the_dead")
	var legacy := manager.save_state()
	var filtered: Array = []
	for objective in legacy["active"]["main_teeth_in_rain"]["objectives"]:
		if str(objective.get("id", "")) != "read_chapel_names":
			filtered.append(objective)
	legacy["active"]["main_teeth_in_rain"]["objectives"] = filtered
	var migrated = preload("res://scripts/quest_manager.gd").new()
	migrated.load_quests("res://data/quests.json")
	migrated.load_state(legacy)
	_check(migrated.is_objective_done("main_teeth_in_rain", "read_chapel_names"), "Legacy progress did not migrate the new chapel objective safely")
	manager.free()
	migrated.free()

func _find_action(data: Dictionary, label: String) -> Dictionary:
	for action in data.get("actions", []):
		if str(action.get("label", "")) == label:
			return action
	return {}

func _find_living_enemy(game, enemy_id: String):
	for enemy in game.active_enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.enemy_id == enemy_id:
			return enemy
	return null

func _living_enemy_count(game, enemy_id: String) -> int:
	var count := 0
	for enemy in game.active_enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.enemy_id == enemy_id:
			count += 1
	return count

func _find_gate_to(node: Node, zone_id: String):
	if node == null:
		return null
	if node.get("zone_target") != null and str(node.get("zone_target")) == zone_id:
		return node
	for child in node.get_children():
		var found = _find_gate_to(child, zone_id)
		if found != null:
			return found
	return null

func _find_named(node: Node, wanted: String):
	if node == null:
		return null
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found = _find_named(child, wanted)
		if found != null:
			return found
	return null

func _settle(count: int) -> void:
	for _i in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _finish() -> void:
	print("QUEST-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
