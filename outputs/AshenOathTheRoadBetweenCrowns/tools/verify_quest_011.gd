extends SceneTree

const QuestManager = preload("res://scripts/quest_manager.gd")
var failures := 0

func _initialize() -> void:
	var quests_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	var dialogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_dialogue.json"))
	var castle_source := FileAccess.get_file_as_string("res://scripts/zones/castle_vargan_section.gd")
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	_check(typeof(quests_data) == TYPE_DICTIONARY and quests_data.has("main_blood_under_stone"), "Blood Under Stone data is missing")
	var objectives: Array = quests_data.get("main_blood_under_stone", {}).get("objectives", [])
	var evidence_ids := ["evidence_mile_marker", "evidence_supply_cart", "evidence_gate_notice", "evidence_iron_binding", "evidence_ledger_fragment"]
	for evidence_id in evidence_ids:
		var found := false
		for objective in objectives:
			if str(objective.get("id", "")) == evidence_id:
				found = true
				_check(bool(objective.get("optional", false)), "%s must remain optional" % evidence_id)
				_check(int(objective.get("required_count", 0)) == 3, "%s must use the three-evidence threshold" % evidence_id)
		_check(found, "Castle evidence objective is missing: %s" % evidence_id)
	_verify_evidence_permutations(evidence_ids)

	var ledger_actions: Array = dialogue.get("vargan_ledger_choice", {}).get("actions", [])
	_check(ledger_actions.size() == 3, "Ledger must expose exactly three outcomes")
	_check(_distinct_ledger_states(ledger_actions), "Ledger outcomes are not distinct")
	_check("vargan_ledger_choice_made" in game_source and "choice_objective_id" in game_source, "Ledger persistence/one-shot contract is missing")
	for state in ["open", "hidden", "copied"]:
		_check(state in castle_source, "Record Hall aftermath branch is missing: %s" % state)
	_check("RecordHallHaunting" in castle_source, "Record Hall haunting staging is missing")

	await _verify_runtime_route(ledger_actions)
	print("QUEST-011 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _verify_evidence_permutations(evidence_ids: Array) -> void:
	for order in _permutations(evidence_ids):
		var manager = QuestManager.new()
		root.add_child(manager)
		manager.load_quests("res://data/quests.json")
		manager.unlocked["main_blood_under_stone"] = true
		_check(manager.start_quest("main_blood_under_stone"), "Castle quest failed to start for evidence permutation")
		for index in range(order.size()):
			_check(manager.complete_evidence("main_blood_under_stone", str(order[index])), "Evidence failed in order %s" % str(order))
			if index < 2:
				_check(not manager.is_objective_done("main_blood_under_stone", "castle_evidence_ready"), "Castle evidence threshold completed before three points")
		_check(manager.is_objective_done("main_blood_under_stone", "castle_evidence_ready"), "Three Castle evidence points did not complete the threshold")
		manager.free()

func _verify_runtime_route(ledger_actions: Array) -> void:
	var scene = load("res://scenes/main.tscn")
	_check(scene != null, "Main scene could not load for Castle runtime route")
	if scene == null or ledger_actions.is_empty():
		return
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(2)
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(35)
	game.quests.unlocked["main_blood_under_stone"] = true
	if not game.quests.is_active("main_blood_under_stone"):
		_check(game.quests.start_quest("main_blood_under_stone"), "Castle quest did not start in runtime")
	for objective in ["reach_castle", "speak_guard", "enter_courtyard", "castle_evidence_ready", "locate_record_hall", "recover_ledger"]:
		game.quests.complete_objective("main_blood_under_stone", objective)
	var action: Dictionary = ledger_actions[0]
	game.call("_handle_dialogue_action", action)
	await _frames(3)
	_check(bool(game.story_state.get_flag("vargan_ledger_choice_made", false)), "Ledger decision flag did not persist")
	_check(game.quests.is_objective_done("main_blood_under_stone", "ledger_choice"), "Ledger decision did not complete its objective")
	var fear_after := int(game.story_state.values.get("greyfen_fear", 0))
	game.call("_handle_dialogue_action", action)
	await _frames(2)
	_check(int(game.story_state.values.get("greyfen_fear", 0)) == fear_after, "Ledger decision applied twice")
	game.call("_load_zone", "record_hall", Vector3(0, 1, 12))
	await _frames(16)
	var haunting = game.zone_root.find_child("RecordHallHaunting", true, false)
	_check(haunting != null, "Ledger decision did not stage the Record Hall haunting")
	if haunting != null:
		haunting.apply_damage(9999.0, "quest_011_verifier")
		await _frames(5)
	_check(bool(game.story_state.get_flag("castle_haunting_cleared", false)), "Haunting did not persist its cleared state")
	_check(game.quests.is_objective_done("main_blood_under_stone", "survive_haunting"), "Haunting did not complete its objective")
	var edric = game.zone_root.find_child("edric_campaign", true, false)
	_check(edric != null, "Edric handoff did not appear after the haunting")
	if edric != null:
		game.call("_handle_dialogue_action", game.dialogue.get_dialogue("edric_campaign").get("actions", [])[0])
		await _frames(3)
	_check(game.quests.is_completed("main_blood_under_stone"), "Edric testimony did not complete Blood Under Stone")
	_check(game.quests.is_active("main_last_witness") or game.quests.is_unlocked("main_last_witness"), "Last Witness was not unlocked")
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
	game.queue_free()
	await _frames(8)

func _distinct_ledger_states(actions: Array) -> bool:
	var values: Array[String] = []
	for action in actions:
		var flags: Dictionary = action.get("sets_flags", {})
		var state := ""
		for key in ["vargan_ledger_taken_openly", "vargan_ledger_hidden", "vargan_ledger_left_copied"]:
			if bool(flags.get(key, false)):
				state = key
		_check(state != "", "Ledger action has no recognized state")
		if state != "":
			_check(not values.has(state), "Ledger actions duplicate state %s" % state)
			values.append(state)
	return values.size() == 3

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
