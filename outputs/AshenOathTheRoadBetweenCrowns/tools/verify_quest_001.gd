extends SceneTree

var failures := 0

func _initialize() -> void:
	var scene = load("res://scenes/main.tscn")
	if scene == null:
		_fail("Main scene could not be loaded")
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _settle_frames(3)

	_check(game.current_zone_id == "greyfen", "New Game did not start in Greyfen")
	_check(game.quests.is_active("main_road_of_crows"), "Road of Crows did not start")
	var sister = _find_named(game.zone_root, "sister_anwen")
	_check(sister != null, "Sister Anwen is missing")
	if sister == null:
		_finish()
		return
	game.call("_handle_interaction", sister)
	await _close_dialogue(game)
	_check(game.quests.is_objective_done("main_road_of_crows", "speak_anwen"), "Anwen did not start the investigation")

	game.call("_load_zone", "wychwood", Vector3(0, 1, 13))
	await _settle_frames(3)
	for clue_id in ["tracks", "oren_token", "black_feathers"]:
		var clue = _find_named(game.zone_root, clue_id)
		_check(clue != null, "Missing Road of Crows clue: %s" % clue_id)
		if clue != null:
			game.call("_handle_interaction", clue)
			await _settle_frames(1)
	_check(game.quests.is_objective_done("main_road_of_crows", "drag_marks"), "Drag marks did not register")
	_check(game.quests.is_objective_done("main_road_of_crows", "oren"), "Oren's token did not register")
	_check(game.quests.is_objective_done("main_road_of_crows", "sella"), "Sella's feathers did not register")
	_check(not game.quests.is_objective_done("main_road_of_crows", "bram"), "Unexpected clue order falsely identified Bram")
	_check(not game.quests.is_objective_done("main_road_of_crows", "vargan_wire"), "Unexpected clue order falsely recovered Vargan wire")
	_check(game.quests.is_objective_done("main_road_of_crows", "evidence_ready"), "Three clues did not satisfy the evidence threshold")

	game.quests.complete_objective("main_road_of_crows", "fight_ghoulkin")
	game.call("_load_zone", "greyfen", Vector3(0, 1, -13))
	await _settle_frames(3)
	var notice = _find_named(game.zone_root, "notice_board")
	_check(notice != null, "Public reporting point is missing")
	if notice != null:
		game.call("_handle_interaction", notice)
		await _close_dialogue(game)
	_check(game.quests.is_completed("main_road_of_crows"), "Road of Crows did not complete after reporting")
	_check(game.quests.is_active("main_bell_beneath_greyfen"), "Bell Beneath Greyfen did not start")
	_check(str(game.story_state.get_flag("evidence_report", "")) == "public", "Report choice was not persisted")
	_check(not game.quests.is_objective_done("main_bell_beneath_greyfen", "meet_anwen_gate"), "Reporting incorrectly skipped the cemetery meeting")

	sister = _find_named(game.zone_root, "sister_anwen")
	_check(sister != null and (sister as Node3D).global_position.distance_to(Vector3(11.0, 0, 4.8)) < 0.25, "Anwen did not relocate to the cemetery gate")
	if sister != null:
		game.call("_handle_interaction", sister)
		await _close_dialogue(game)
	_check(game.quests.is_objective_done("main_bell_beneath_greyfen", "meet_anwen_gate"), "Cemetery gate meeting did not progress")

	for grave_id in ["grave_soldier", "grave_harl"]:
		var grave = _find_named(game.zone_root, grave_id)
		_check(grave != null, "Missing cemetery clue: %s" % grave_id)
		if grave != null:
			game.call("_handle_interaction", grave)
			await _settle_frames(1)
	_check(game.quests.is_objective_done("main_bell_beneath_greyfen", "grave_truth"), "Two graves did not satisfy the cemetery threshold")
	var ambusher = _find_ambusher(game.active_enemies)
	_check(ambusher != null, "Cemetery investigation did not create the Ghoulkin ambush")
	_check(not game.call("_chapel_can_open"), "Chapel opened before the cemetery ambush was defeated")
	if ambusher != null:
		game.call("_on_enemy_died", ambusher)
		await _settle_frames(1)
	_check(game.quests.is_objective_done("main_bell_beneath_greyfen", "cemetery_ambush"), "Cemetery victory did not progress")

	var chapel = _find_named(game.zone_root, "chapel_door")
	_check(chapel != null, "Crow Chapel door is missing")
	if chapel != null:
		game.call("_handle_interaction", chapel)
		await _settle_frames(1)
	_check(game.quests.is_objective_done("main_bell_beneath_greyfen", "open_chapel"), "Crow Chapel did not open")
	_check(_find_named(game.zone_root, "crow_shrine_choice") != null, "Crow Shrine consequence did not appear")

	var shrine_dialogue: Dictionary = game.dialogue.get_dialogue("crow_shrine_choice")
	var shrine_actions: Array = shrine_dialogue.get("actions", [])
	_check(shrine_actions.size() == 3, "Crow Shrine does not offer three consequences")
	if not shrine_actions.is_empty():
		game.call("_handle_dialogue_action", shrine_actions[0])
	_check(game.quests.is_completed("main_bell_beneath_greyfen"), "Crow Shrine choice did not finish Bell Beneath Greyfen")
	_check(game.quests.is_active("main_teeth_in_rain"), "Teeth in the Rain did not start")
	_check(_objective_is_optional(game, "main_teeth_in_rain", "craft_moon_oil"), "Moon Oil remains a progression blocker")

	game.quests.complete_objective("main_teeth_in_rain", "speak_mira")
	game.quests.complete_objective("main_teeth_in_rain", "read_chapel_names")
	game.quests.complete_objective("main_teeth_in_rain", "name_the_dead")
	game.quests.complete_objective("main_teeth_in_rain", "fight_bog_wretch")
	var core_dialogue: Dictionary = game.dialogue.get_dialogue("bog_core_choice")
	var core_actions: Array = core_dialogue.get("actions", [])
	_check(core_actions.size() == 3, "Bog Wretch memory core does not offer three consequences")
	if not core_actions.is_empty():
		game.call("_handle_dialogue_action", core_actions[0])
	_check(game.quests.is_completed("main_teeth_in_rain"), "Memory-core choice did not finish Teeth in the Rain")
	_check(game.quests.is_active("main_names_they_burned"), "Act Two handoff did not unlock")

	_finish()

func _objective_is_optional(game, quest_id: String, objective_id: String) -> bool:
	for objective in game.quests.active.get(quest_id, {}).get("objectives", []):
		if str(objective.get("id", "")) == objective_id:
			return bool(objective.get("optional", false))
	return false

func _find_ambusher(enemies: Array):
	for enemy in enemies:
		if is_instance_valid(enemy) and bool(enemy.get_meta("act_one_cemetery_ambush", false)):
			return enemy
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

func _close_dialogue(game) -> void:
	paused = false
	game.hud.hide_menus()
	await _settle_frames(1)

func _settle_frames(count: int) -> void:
	for _i in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _fail(message: String) -> void:
	failures += 1
	push_error(message)
	_finish()

func _finish() -> void:
	print("QUEST-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
