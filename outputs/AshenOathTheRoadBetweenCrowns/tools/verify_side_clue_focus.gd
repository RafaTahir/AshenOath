extends SceneTree

const QuestManager = preload("res://scripts/quest_manager.gd")
const InteractionFocusService = preload("res://scripts/interaction_focus_service.gd")
const Interactable = preload("res://scripts/interactable.gd")

func _initialize() -> void:
	var quests := QuestManager.new()
	root.add_child(quests)
	quests.load_quests("res://data/quests.json")
	if not quests.start_quest("main_road_of_crows") or not quests.start_quest("side_widows_bell"):
		_fail("Required main and side quests did not start")
		return
	var focus := InteractionFocusService.new()
	root.add_child(focus)
	focus.setup(quests)
	var player := Node3D.new()
	root.add_child(player)
	var camera := Camera3D.new()
	player.add_child(camera)
	var bell := _candidate("grave_bell", "side_widows_bell", "find_bell", "clue", Vector3(0, 0, -1.4))
	var old_grave := _candidate("grave_child", "main_bell_beneath_greyfen", "grave_child", "clue", Vector3(0.1, 0, -1.8))
	var anwen := _candidate("sister_anwen", "main_road_of_crows", "speak_anwen", "dialogue", Vector3(0, 0, -2.0))
	root.add_child(bell)
	root.add_child(old_grave)
	root.add_child(anwen)
	await process_frame
	if focus.choose([old_grave, bell], player, camera, Callable()) != bell:
		_fail("Inactive grave marker stole focus from the closer active side-quest bell")
		return
	if focus.choose([bell, anwen], player, camera, Callable()) != anwen:
		_fail("The tracked main objective lost focus priority")
		return
	print("SIDE CLUE FOCUS VERIFIER: PASS")
	quit(0)

func _candidate(id: String, quest_id: String, objective_id: String, kind: String, position: Vector3) -> Area3D:
	var area := Interactable.new()
	area.interaction_id = id
	area.quest_id = quest_id
	area.objective_id = objective_id
	area.interaction_type = kind
	area.position = position
	return area

func _fail(message: String) -> void:
	push_error(message)
	print("SIDE CLUE FOCUS VERIFIER: FAIL: %s" % message)
	quit(1)
