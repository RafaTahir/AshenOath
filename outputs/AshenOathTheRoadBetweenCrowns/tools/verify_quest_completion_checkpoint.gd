extends SceneTree

const QuestManagerScript = preload("res://scripts/quest_manager.gd")

func _initialize() -> void:
	var manager := QuestManagerScript.new()
	root.add_child(manager)
	manager.load_quests("res://data/quests.json")
	var observed := {}
	manager.quest_completed.connect(func(id: String) -> void:
		if id == "main_bell_beneath_greyfen":
			observed["checkpoint_state"] = manager.save_state()
	)
	manager.unlocked["main_bell_beneath_greyfen"] = true
	manager.start_quest("main_bell_beneath_greyfen")
	for objective_id in ["meet_anwen_gate", "grave_harl", "grave_soldier", "cemetery_ambush", "open_chapel", "crow_shrine_choice"]:
		if manager.is_choice_objective("main_bell_beneath_greyfen", objective_id):
			manager.complete_choice("main_bell_beneath_greyfen", objective_id)
		else:
			manager.complete_objective("main_bell_beneath_greyfen", objective_id)
	var snapshot: Dictionary = observed.get("checkpoint_state", {})
	var passed: bool = not snapshot.is_empty() \
		and bool(snapshot.get("completed", {}).get("main_bell_beneath_greyfen", false)) \
		and snapshot.get("active", {}).has("main_teeth_in_rain") \
		and str(snapshot.get("tracked_quest_id", "")) == "main_teeth_in_rain"
	manager.quest_defs["history_fixture"] = {"title":"History", "objectives":[
		{"id":"required", "text":"Required"}, {"id":"early", "text":"Early clue", "optional":true},
		{"id":"skipped", "text":"Skipped clue", "optional":true}]}
	manager.unlocked.history_fixture = true
	manager.complete_evidence("history_fixture", "early")
	passed = passed and not manager.complete_evidence("history_fixture", "unknown") and not manager.evidence_history.has("history_fixture:unknown")
	manager.start_quest("history_fixture")
	passed = passed and manager.is_objective_done("history_fixture", "early")
	manager.complete_objective("history_fixture", "required")
	var saved: Dictionary = manager.save_state()
	manager.load_state(saved)
	passed = passed and manager.is_completed("history_fixture") and manager.is_objective_done("history_fixture", "required") and manager.is_objective_done("history_fixture", "early")
	passed = passed and not manager.is_objective_done("history_fixture", "skipped") and not manager.is_objective_done("history_fixture", "unknown")
	saved.erase("completed_objectives")
	manager.load_state(saved)
	passed = passed and manager.is_objective_done("history_fixture", "required") and manager.is_objective_done("history_fixture", "early") and not manager.is_objective_done("history_fixture", "skipped")
	print("QUEST COMPLETION CHECKPOINT: %s" % ("PASS" if passed else "FAIL"))
	if not passed:
		push_error("Quest completion checkpoint or exact objective history failed: %s" % snapshot)
	manager.free()
	quit(0 if passed else 1)
