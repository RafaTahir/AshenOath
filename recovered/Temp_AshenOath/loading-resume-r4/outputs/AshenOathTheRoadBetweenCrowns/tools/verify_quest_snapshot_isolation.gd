extends SceneTree

func _initialize() -> void:
	var manager := preload("res://scripts/quest_manager.gd").new()
	root.add_child(manager)
	manager.unlocked["main_hart_remembers"] = true
	manager.world_flags["evidence"] = {"count":1}
	var snapshot: Dictionary = manager.save_state()
	manager.world_flags.evidence.count = 2
	manager.unlocked["late"] = true
	var passed: bool = snapshot.world_flags.evidence.count == 1 and not snapshot.unlocked.has("late")
	manager.load_state({})
	passed = passed and manager.unlocked == manager.STARTING_UNLOCKS
	passed = passed and manager.world_flags.is_empty()
	manager.quest_defs = {"fixture":{"type":"main", "objectives":[{"id":"clue"}]}}
	manager.load_state({"completed":{"fixture":"false"}, "active":{"fixture":{"objectives":[{"id":"clue", "done":"false", "optional_satisfied":"yes"}]}}, "tracked_quest_id":"fixture", "tracked_quest_is_manual":"false"})
	passed = passed and manager.completed.is_empty() and not manager.tracked_quest_is_manual
	passed = passed and not manager.active.fixture.objectives[0].done and not manager.active.fixture.objectives[0].optional_satisfied
	manager.load_state({"completed":{"fixture":true}, "active":{"fixture":{"objectives":[]}}})
	passed = passed and manager.completed.has("fixture") and manager.active.is_empty()
	manager.free()
	if not passed:
		push_error("Quest save isolation or prior-session unlock reset failed")
	print("QUEST SNAPSHOT ISOLATION: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
