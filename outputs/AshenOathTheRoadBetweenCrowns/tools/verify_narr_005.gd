extends SceneTree

var failures := 0

func _initialize() -> void:
	var director := FileAccess.get_file_as_string("res://scripts/quest_beat_director.gd")
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	check("class_name QuestBeatDirector" in director, "QuestBeatDirector class is missing")
	check("decorate_tracker" in director and "get_next_action" in director, "Quest beat presentation contract is incomplete")
	check("quest_beats.refresh()" in game_source and "quest_beats.decorate_tracker" in game_source, "HUD is not using the authoritative quest beat view")
	check("quest_beats" in FileAccess.get_file_as_string("res://scripts/save_manager.gd"), "Quest beat save migration is missing")
	check(director.find("const BEATS") >= 0 and director.find("func refresh") >= 0, "Quest beat source is not readable")
	for quest_id in ["main_road_of_crows", "main_bell_beneath_greyfen", "main_blood_under_stone", "main_hart_remembers"]:
		check(quest_id in director, "Missing beat coverage: %s" % quest_id)
	print("NARR-005 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
