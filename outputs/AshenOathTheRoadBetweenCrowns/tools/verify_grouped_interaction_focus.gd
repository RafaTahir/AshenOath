extends SceneTree

const QuestManager = preload("res://scripts/quest_manager.gd")
const QuestPresentation = preload("res://scripts/quest_presentation_state.gd")
const InteractionFocus = preload("res://scripts/interaction_focus_service.gd")
const Interactable = preload("res://scripts/interactable.gd")

class SagaHost extends Node:
	var player: Node3D
	var combat := true
	var zone_transition_pending := false
	var loading := false
	func _story_has_active_combat() -> bool:
		return combat
	func _journey_load_pending() -> bool:
		return loading

func _initialize() -> void:
	if "--senn-availability-only" in OS.get_cmdline_user_args():
		await _senn_availability()
		return
	var quests := QuestManager.new()
	quests.load_quests("res://data/quests.json")
	root.add_child(quests)
	var objectives: Array = []
	for source in quests.quest_defs["main_bell_beneath_greyfen"]["objectives"]:
		var objective: Dictionary = source.duplicate(true)
		objective["done"] = str(objective.get("id", "")) == "meet_anwen_gate"
		objectives.append(objective)
	quests.active["main_bell_beneath_greyfen"] = {"objectives": objectives}
	quests.tracked_quest_id = "main_bell_beneath_greyfen"
	var presentation := QuestPresentation.new()
	root.add_child(presentation)
	presentation.setup(quests)
	presentation.set_zone("greyfen")
	var focus := InteractionFocus.new()
	root.add_child(focus)
	focus.setup(quests, presentation)
	var player := Node3D.new()
	player.position = Vector3(11.4, 0.0, 8.06)
	root.add_child(player)
	var harl := _candidate("grave_harl", "clue", "main_bell_beneath_greyfen", "grave_harl", Vector3(12.2, 0.0, 7.55))
	var child := _candidate("grave_child", "clue", "main_bell_beneath_greyfen", "grave_child", Vector3(12.4, 0.0, 7.6))
	var widow := _candidate("widow_elna", "dialogue", "", "", Vector3(13.0, 0.0, 7.55))
	await process_frame
	var view: Dictionary = presentation.get_objective_view_model()
	if str(view.get("objective_id", "")) != "grave_truth":
		push_error("Bell quest did not select the grave group summary")
		quit(1)
		return
	if focus.choose([widow, harl], player, null, Callable()) != harl:
		push_error("Unfinished Harl grave lost focus to nearby dialogue")
		quit(1)
		return
	quests.complete_objective("main_bell_beneath_greyfen", "grave_harl")
	if focus.choose([widow, harl, child], player, null, Callable()) != child:
		push_error("Finished Harl grave retained priority over an unfinished grouped clue")
		quit(1)
		return
	print("GROUPED INTERACTION FOCUS: PASS")
	quit(0)

func _senn_availability() -> void:
	var host := SagaHost.new()
	host.player = Node3D.new()
	root.add_child(host)
	host.add_child(host.player)
	var owner := preload("res://scripts/saga_activities.gd").new()
	owner.process_mode = Node.PROCESS_MODE_DISABLED
	owner.host = host
	root.add_child(owner)
	var challenge := Interactable.new()
	challenge.setup("saga_senn_challenge", "story_activity", "Challenge Senn")
	owner.add_child(challenge)
	await process_frame
	var ok: bool = owner._within_reach(challenge)
	challenge.interaction_id = "saga_roa_q01:offer"
	ok = ok and not owner._within_reach(challenge)
	host.combat = false
	ok = ok and owner._within_reach(challenge)
	challenge.interaction_id = "saga_senn_challenge"
	host.combat = true
	host.zone_transition_pending = true
	ok = ok and not owner._within_reach(challenge)
	host.zone_transition_pending = false
	host.loading = true
	ok = ok and not owner._within_reach(challenge)
	host.loading = false
	host.player.position.x = 5.0
	ok = ok and not owner._within_reach(challenge)
	owner.queue_free()
	host.queue_free()
	await process_frame
	print("SENN CHALLENGE AVAILABILITY: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)

func _candidate(id: String, kind: String, quest_id: String, objective_id: String, position: Vector3) -> Area3D:
	var candidate := Interactable.new()
	candidate.setup(id, kind, id)
	candidate.quest_id = quest_id
	candidate.objective_id = objective_id
	candidate.position = position
	root.add_child(candidate)
	return candidate
