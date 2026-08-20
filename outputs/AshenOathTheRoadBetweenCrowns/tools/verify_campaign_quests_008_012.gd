extends SceneTree

var failures := 0

func _initialize() -> void:
	var quests = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	var dialogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_dialogue.json"))
	check(typeof(quests) == TYPE_DICTIONARY and typeof(dialogue) == TYPE_DICTIONARY, "Campaign data is not valid JSON")
	for quest_id in ["main_road_of_crows", "main_bell_beneath_greyfen", "main_teeth_in_rain", "main_blood_under_stone", "main_last_witness", "main_hart_remembers"]:
		check(quests.has(quest_id), "Missing main quest: %s" % quest_id)
	for dialogue_id in ["crow_shrine_choice", "captain_senn", "halvern", "edric_campaign", "white_hart"]:
		check(dialogue.has(dialogue_id), "Missing campaign dialogue: %s" % dialogue_id)
	check(int(quests.main_road_of_crows.objectives.size()) >= 8, "Road of Crows evidence route is incomplete")
	check(int(dialogue.white_hart.actions.size()) == 4, "Final covenant does not expose four outcomes")
	check("crow_shrine_state" in JSON.stringify(dialogue.crow_shrine_choice), "Crow Shrine choice state is missing")
	check("halvern_fate" in JSON.stringify(dialogue.halvern), "Halvern consequence state is missing")
	print("QUEST-008..012 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
