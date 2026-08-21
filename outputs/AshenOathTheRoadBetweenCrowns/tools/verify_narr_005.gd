extends SceneTree

const QuestBeatDirector = preload("res://scripts/quest_beat_director.gd")
var failures := 0

func _initialize() -> void:
	var director := FileAccess.get_file_as_string("res://scripts/quest_beat_director.gd")
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var quest_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	check("class_name QuestBeatDirector" in director, "QuestBeatDirector class is missing")
	check("decorate_tracker" in director and "get_next_action" in director, "Quest beat presentation contract is incomplete")
	check("quest_beats.refresh()" in game_source and "quest_beats.decorate_tracker" in game_source, "HUD is not using the authoritative quest beat view")
	check("quest_beats" in FileAccess.get_file_as_string("res://scripts/save_manager.gd"), "Quest beat save migration is missing")
	check(director.find("const BEATS") >= 0 and director.find("func refresh") >= 0, "Quest beat source is not readable")
	var beat_director := QuestBeatDirector.new()
	var main_quests := [
		"main_road_of_crows", "main_bell_beneath_greyfen", "main_teeth_in_rain",
		"main_names_they_burned", "main_ash_at_the_mill", "main_soldier_without_banner",
		"main_blood_under_stone", "main_last_witness", "main_crowns_without_mercy",
		"main_hart_remembers"
	]
	check(typeof(quest_data) == TYPE_DICTIONARY, "Quest data is not valid JSON")
	for quest_id in main_quests:
		check(beat_director.BEATS.has(quest_id), "Missing beat coverage: %s" % quest_id)
		if typeof(quest_data) != TYPE_DICTIONARY or not quest_data.has(quest_id):
			continue
		for objective in quest_data[quest_id].get("objectives", []):
			if bool(objective.get("optional", false)):
				continue
			var objective_id := str(objective.get("id", ""))
			check(beat_director.BEATS.get(quest_id, {}).has(objective_id), "Missing authored beat: %s:%s" % [quest_id, objective_id])
	beat_director.set_zone("record_hall")
	var saved := beat_director.save_state()
	var restored := QuestBeatDirector.new()
	restored.load_state(saved)
	check(str(restored.zone_id) == "record_hall", "Quest beat zone did not survive save round-trip")
	beat_director.free()
	restored.free()
	print("NARR-005 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
