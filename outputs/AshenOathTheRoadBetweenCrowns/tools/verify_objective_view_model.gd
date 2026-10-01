extends SceneTree

const QuestManager = preload("res://scripts/quest_manager.gd")
const QuestPresentationState = preload("res://scripts/quest_presentation_state.gd")
const QuestBeatDirector = preload("res://scripts/quest_beat_director.gd")
const StoryState = preload("res://scripts/story_state.gd")
const InteractionFocusService = preload("res://scripts/interaction_focus_service.gd")
const Interactable = preload("res://scripts/interactable.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var quests := QuestManager.new()
	var story := StoryState.new()
	var beats := QuestBeatDirector.new()
	var presentation := QuestPresentationState.new()
	root.add_child(quests)
	root.add_child(story)
	root.add_child(beats)
	root.add_child(presentation)
	quests.load_quests("res://data/quests.json")
	beats.setup(quests, story)
	presentation.setup(quests, beats)
	_check(quests.start_quest("main_road_of_crows"), "Road of Crows could not start")
	presentation.set_zone("greyfen")
	_check(not quests.tracked_quest_is_manual, "Automatic zone fallback was marked as manual")
	_check(quests.get_tracked_quest() == "main_road_of_crows", "Greyfen fallback selected the wrong quest")

	_check(presentation.set_tracked_quest("main_road_of_crows"), "Presentation setter could not select an active quest")
	_check(quests.tracked_quest_is_manual, "Explicit tracking was not marked manual")
	presentation.set_zone("vargan_court")
	_check(quests.get_tracked_quest() == "main_road_of_crows", "Manual tracking was overwritten by a zone change")

	var view: Dictionary = presentation.get_objective_view_model()
	for key in ["zone_id", "zone_name", "quest_id", "quest_title", "objective_id", "objective_text", "next_action", "tracker_text", "contextual_text", "compass_text", "save_summary"]:
		_check(view.has(key), "Objective view is missing %s" % key)
	_check(str(view.get("quest_id", "")) == "main_road_of_crows", "Objective view selected the wrong quest")
	_check(str(view.get("objective_id", "")) == "speak_anwen", "Objective view selected the wrong objective")
	_check(str(view.get("next_action", "")) == "Speak with Sister Anwen", "Objective view lost the authored next action")
	_check(str(view.get("zone_name", "")) == "Castle Vargan Courtyard", "Objective view exposed an incorrect zone label")
	_check(str(view.get("tracker_text", "")).contains("Speak with Sister Anwen"), "Tracker did not use the objective view action")
	_check(str(view.get("contextual_text", "")) == "Speak with Sister Anwen", "Contextual guidance disagrees with the objective view")
	_check(str(view.get("compass_text", "")) == str(view.get("zone_name", "")), "Compass lost the current zone when the beat has no authored destination")
	var save_summary: Dictionary = view.get("save_summary", {})
	_check(str(save_summary.get("quest_id", "")) == str(view.get("quest_id", "")), "Save summary selected a different quest")
	_check(str(save_summary.get("objective_id", "")) == str(view.get("objective_id", "")), "Save summary selected a different objective")
	_check(str(save_summary.get("next_action", "")) == str(view.get("contextual_text", "")), "Save summary selected a different next action")
	var presentation_save: Dictionary = presentation.save_state()
	_check(presentation_save.get("objective_summary", {}) == save_summary, "Persisted save summary differs from the authoritative view")

	var focus := InteractionFocusService.new()
	root.add_child(focus)
	focus.setup(quests, presentation)
	var player := Node3D.new()
	var camera := Camera3D.new()
	root.add_child(player)
	player.add_child(camera)
	camera.current = true
	var anwen := _candidate("sister_anwen", "main_road_of_crows", "speak_anwen", "dialogue", Vector3(0, 0, -2))
	var unrelated := _candidate("widow", "side_widows_bell", "speak_widow", "dialogue", Vector3(0.2, 0, -1.5))
	root.add_child(anwen)
	root.add_child(unrelated)
	await process_frame
	var chosen: Node = focus.choose([unrelated, anwen], player, camera, Callable())
	_check(chosen == anwen, "Interaction focus did not use the authoritative quest/objective selection")

	_check(quests.start_quest("side_widows_bell"), "Second active quest could not be started for tracker isolation")
	_check(quests.complete_objective("main_road_of_crows", "speak_anwen"), "Opening objective could not advance for tracker isolation")
	var evidence_view: Dictionary = presentation.get_objective_view_model()
	_check(str(evidence_view.get("quest_id", "")) == "main_road_of_crows", "Tracker switched away from the selected main quest")
	_check(str(evidence_view.get("objective_id", "")) == "evidence_ready", "Evidence group did not select its authoritative summary objective")
	_check(str(evidence_view.get("tracker_text", "")).contains("(0/3)"), "Grouped objective progress was lost from the authoritative tracker")
	_check(not str(evidence_view.get("tracker_text", "")).contains("Widow's Bell"), "Tracker leaked another active quest title")
	_check(str(evidence_view.get("compass_text", "")) == "Wychwood", "Evidence compass lost the authored Wychwood destination")

	var saved: Dictionary = quests.save_state()
	var restored := QuestManager.new()
	root.add_child(restored)
	restored.load_quests("res://data/quests.json")
	restored.load_state(saved)
	_check(restored.get_tracked_quest() == "main_road_of_crows", "Tracked quest did not survive save/load")
	_check(restored.tracked_quest_is_manual, "Manual tracking intent did not survive save/load")
	restored.set_tracked_quest_for_zone("greyfen")
	_check(restored.get_tracked_quest() == "main_road_of_crows", "Manual tracking did not survive restored zone fallback")

	_print_result()
	quit(0 if failures.is_empty() else 1)

func _candidate(interaction_id: String, quest_id: String, objective_id: String, interaction_type: String, position: Vector3) -> Area3D:
	var area := Interactable.new()
	area.interaction_id = interaction_id
	area.quest_id = quest_id
	area.objective_id = objective_id
	area.interaction_type = interaction_type
	area.position = position
	return area

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)

func _print_result() -> void:
	print("OBJECTIVE VIEW MODEL VERIFIER: %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	for failure in failures:
		print("- %s" % failure)
