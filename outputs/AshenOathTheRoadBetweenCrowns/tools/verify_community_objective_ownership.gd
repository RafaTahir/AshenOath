extends SceneTree

const Quests = preload("res://scripts/quest_manager.gd")
const Revision = preload("res://scripts/campaign_revision.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/community_campaign.json")).chapters
	for id: String in definitions:
		var manager := _manager()
		manager.unlocked[id] = true
		for objective: Dictionary in definitions[id].objectives:
			manager.evidence_history[id + ":" + str(objective.id)] = true
		_check(manager.start_quest(id), id + " can be started when explicitly unlocked")
		for objective: Dictionary in definitions[id].objectives:
			var oid := str(objective.id)
			_check(manager.requires_explicit_completion(id, oid), id + ":" + oid + " is owner-driven")
			_check(not manager.is_objective_done(id, oid), "saved evidence cannot perform " + oid)
			_check(not manager.complete_evidence(id, oid), "observing a clue cannot perform " + oid)
		var restored := _manager()
		restored.load_state(manager.save_state())
		for objective: Dictionary in definitions[id].objectives:
			_check(not restored.is_objective_done(id, str(objective.id)), "reload does not promote evidence into " + str(objective.id))
		for objective: Dictionary in definitions[id].objectives:
			var oid := str(objective.id)
			if restored.is_choice_objective(id, oid):
				_check(not restored.complete_objective(id, oid), "generic objective completion cannot choose " + oid)
				_check(restored.complete_choice(id, oid), "deliberate choice owner completes " + oid)
			else:
				_check(restored.complete_objective(id, oid), "physical activity owner completes " + oid)
			var round_trip := _manager()
			round_trip.load_state(restored.save_state())
			_check(round_trip.is_objective_done(id, oid), "earned work survives reload: " + oid)
			round_trip.free()
		_check(restored.is_completed(id), id + " finishes through its explicit owners")
		manager.free()
		restored.free()
	for failure in failures: printerr(failure)
	print("COMMUNITY OBJECTIVE OWNERSHIP: %s checks=%d storage=in_memory" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _manager() -> Node:
	var result := Quests.new()
	result.load_quests("res://data/quests.json")
	_check(result.configure_campaign_revision(Revision.EXPANDED), "complete authored expansion graph loads")
	return result

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
