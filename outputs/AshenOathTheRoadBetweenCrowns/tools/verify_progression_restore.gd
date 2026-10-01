extends SceneTree

func _initialize() -> void:
	var manager := preload("res://scripts/progression_manager.gd").new()
	root.add_child(manager)
	manager.load_definitions()
	var first: String = manager.ordered_upgrade_ids()[0]
	var passed := true
	for value in [null, "99", {}, true, NAN, INF, 1.5]:
		manager.load_state({"marks":value, "unlocked":{first:"false"}, "rewarded_quests":{"main_fixture":"false"}})
		passed = passed and manager.marks == 0 and manager.unlocked.is_empty() and manager.rewarded_quests.is_empty()
	manager.load_state({"marks":1e30})
	passed = passed and manager.marks == 99
	manager.load_state({"marks":2.0, "unlocked":{first:true}, "rewarded_quests":{"main_fixture":true}})
	passed = passed and manager.marks == 2 and manager.has_upgrade(first)
	passed = passed and not manager.award_for_quest("main_fixture", "main") and manager.marks == 2
	manager.free()
	if not passed:
		push_error("Progression restore accepted malformed values or changed valid rewards")
	print("PROGRESSION RESTORE: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
