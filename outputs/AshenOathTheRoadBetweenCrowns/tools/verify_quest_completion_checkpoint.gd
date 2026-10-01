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
		manager.complete_objective("main_bell_beneath_greyfen", objective_id)
	var snapshot: Dictionary = observed.get("checkpoint_state", {})
	var passed: bool = not snapshot.is_empty() \
		and bool(snapshot.get("completed", {}).get("main_bell_beneath_greyfen", false)) \
		and snapshot.get("active", {}).has("main_teeth_in_rain") \
		and str(snapshot.get("tracked_quest_id", "")) == "main_teeth_in_rain"
	print("QUEST COMPLETION CHECKPOINT: %s" % ("PASS" if passed else "FAIL"))
	if not passed:
		push_error("Main-quest checkpoint was emitted before the successor became active: %s" % snapshot)
	manager.free()
	quit(0 if passed else 1)
