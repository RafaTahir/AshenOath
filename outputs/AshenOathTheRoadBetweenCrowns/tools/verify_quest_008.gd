extends SceneTree

const QuestManager = preload("res://scripts/quest_manager.gd")
var failures := 0
var evidence_ids := ["bram", "sella", "oren", "vargan_wire", "drag_marks"]

func _initialize() -> void:
	var quests = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	var contract = JSON.parse_string(FileAccess.get_file_as_string("res://narrative_aftermath_contract.json"))
	_check(typeof(quests) == TYPE_DICTIONARY and quests.has("main_road_of_crows"), "Road of Crows quest data is missing")
	_check(typeof(contract) == TYPE_DICTIONARY and contract.has("report_methods"), "Report method contract is missing")
	if typeof(contract) == TYPE_DICTIONARY:
		for method_id in ["private", "public", "retained"]:
			_check(contract.report_methods.has(method_id), "Missing report method: %s" % method_id)
		_check(str(contract.report_methods.private.interaction) == "sister_anwen", "Private report target changed")
		_check(str(contract.report_methods.public.interaction) == "notice_board", "Public report target changed")
		_check(str(contract.report_methods.retained.interaction) == "retain_evidence", "Retained report target changed")

	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	_check('area.interaction_id in ["sister_anwen", "notice_board", "retain_evidence"]' in game_source, "Runtime does not expose all report targets")
	_check('"evidence_report"' in game_source and '"cemetery_bell_rung"' in game_source, "Report consequences are not persisted")

	var permutations: Array = []
	_build_permutations(evidence_ids, [], permutations)
	_check(permutations.size() == 120, "Evidence permutation generator is incomplete")
	for order in permutations:
		var manager := QuestManager.new()
		root.add_child(manager)
		manager.load_quests("res://data/quests.json")
		manager.unlocked["main_road_of_crows"] = true
		_check(manager.start_quest("main_road_of_crows"), "Road of Crows did not start for permutation")
		for index in range(order.size()):
			var evidence_id := str(order[index])
			_check(manager.complete_evidence("main_road_of_crows", evidence_id), "Evidence did not register: %s" % evidence_id)
			if index < 2:
				_check(not manager.is_objective_done("main_road_of_crows", "evidence_ready"), "Evidence threshold deadlocked below three clues")
			elif index == 2:
				_check(manager.is_objective_done("main_road_of_crows", "evidence_ready"), "Three-clue threshold failed for order %s" % str(order))
		_check(manager.is_objective_done("main_road_of_crows", "evidence_ready"), "Evidence threshold regressed after optional clues")
		manager.free()

	print("QUEST-008 VERIFIER: %s (120 evidence orders)" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _build_permutations(remaining: Array, prefix: Array, output: Array) -> void:
	if remaining.is_empty():
		output.append(prefix.duplicate())
		return
	for index in range(remaining.size()):
		var next_remaining := remaining.duplicate()
		var value = next_remaining.pop_at(index)
		var next_prefix := prefix.duplicate()
		next_prefix.append(value)
		_build_permutations(next_remaining, next_prefix, output)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
