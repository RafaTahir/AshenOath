extends SceneTree

var failures := 0

func _initialize() -> void:
	var quests = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	var dialogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_dialogue.json"))
	for quest_id in ["side_widows_bell", "side_iron_remembers", "side_bitter_roots", "side_black_dog", "side_empty_grave"]:
		check(quests.has(quest_id), "Missing side quest: %s" % quest_id)
	check(dialogue.has("side_contracts"), "Side contract board dialogue is missing")
	check(int(dialogue.side_contracts.actions.size()) >= 5, "Side contract board does not offer five authored requests")
	for action in dialogue.side_contracts.actions:
		check(str(action.get("quest", "")).begins_with("side_"), "Side board action is not quest-backed")
	print("SIDE-003 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
