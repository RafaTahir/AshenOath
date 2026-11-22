extends SceneTree

const QuestManager = preload("res://scripts/quest_manager.gd")

var failures := 0

func _initialize() -> void:
	var quests = QuestManager.new()
	root.add_child(quests)
	quests.load_quests("res://data/quests.json")
	check(quests.start_quest("main_road_of_crows"), "Road of Crows did not start")
	check("Sister Anwen" in quests.get_tracker_text(), "Opening tracker does not lead to Anwen")
	check(quests.complete_objective("main_road_of_crows", "speak_anwen"), "Anwen objective did not complete")
	check("(0/3)" in quests.get_tracker_text(), "Road evidence tracker lacks a zero-state count")
	for clue in ["drag_marks", "bram", "vargan_wire"]:
		check(quests.complete_evidence("main_road_of_crows", clue), "%s did not register" % clue)
	check(quests.is_objective_done("main_road_of_crows", "evidence_ready"), "Three out-of-order clues did not unlock the fight")
	check("five creatures" in quests.get_tracker_text(), "Tracker does not advance to the five-enemy fight")
	check(not quests.complete_objective("main_road_of_crows", "drag_marks"), "Repeated clue incorrectly progressed")
	check(quests.complete_objective("main_road_of_crows", "fight_ghoulkin"), "Pack victory did not progress")
	check("report" in quests.get_tracker_text().to_lower(), "Victory does not lead back to reporting")
	check(quests.complete_objective("main_road_of_crows", "return_village"), "Report did not complete Road of Crows")
	check(quests.is_completed("main_road_of_crows"), "Road of Crows did not complete")
	check(quests.is_active("main_bell_beneath_greyfen"), "Cemetery handoff did not start")
	check("cemetery gate" in quests.get_tracker_text().to_lower(), "Cemetery handoff is unclear")
	quests.complete_objective("main_bell_beneath_greyfen", "meet_anwen_gate")
	check("(0/2)" in quests.get_tracker_text(), "Grave evidence tracker lacks a zero-state count")
	quests.complete_evidence("main_bell_beneath_greyfen", "grave_soldier")
	quests.complete_evidence("main_bell_beneath_greyfen", "grave_harl")
	check(quests.is_objective_done("main_bell_beneath_greyfen", "grave_truth"), "Two out-of-order graves did not progress")
	var contract = JSON.parse_string(FileAccess.get_file_as_string("res://first_hour_flow_contract.json"))
	check(typeof(contract) == TYPE_DICTIONARY and contract.route.size() == 10, "First-hour flow contract is incomplete")
	print("GAMEPLAY-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
