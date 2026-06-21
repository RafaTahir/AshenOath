extends Node

signal changed
signal message(text: String)
signal quest_completed(id: String)

var quest_defs = {}
var active = {}
var completed = {}
var unlocked = {"main_road_of_crows": true, "side_widows_bell": true}
var world_flags = {}

func load_quests(path: String) -> void:
	var parsed = _read_json(path)
	if typeof(parsed) == TYPE_DICTIONARY:
		quest_defs = parsed

func start_quest(id: String) -> bool:
	if not quest_defs.has(id):
		return false
	if completed.has(id) or active.has(id):
		return false
	if not bool(unlocked.get(id, false)):
		message.emit("That path is not open yet.")
		return false
	var objectives: Array = []
	for objective in quest_defs[id].get("objectives", []):
		objectives.append({"id": objective["id"], "text": objective["text"], "done": false})
	active[id] = {"objectives": objectives}
	message.emit("Quest started: %s" % quest_defs[id].get("title", id))
	changed.emit()
	return true

func complete_objective(quest_id: String, objective_id: String) -> bool:
	if not active.has(quest_id):
		return false
	var objectives: Array = active[quest_id]["objectives"]
	for objective in objectives:
		if objective["id"] == objective_id:
			if bool(objective.get("done", false)):
				return false
			objective["done"] = true
			message.emit("Objective complete: %s" % objective["text"])
			_try_complete_quest(quest_id)
			changed.emit()
			return true
	return false

func is_objective_done(quest_id: String, objective_id: String) -> bool:
	if not active.has(quest_id):
		return false
	for objective in active[quest_id]["objectives"]:
		if objective["id"] == objective_id:
			return bool(objective.get("done", false))
	return completed.has(quest_id)

func is_active(id: String) -> bool:
	return active.has(id)

func is_completed(id: String) -> bool:
	return completed.has(id)

func is_unlocked(id: String) -> bool:
	return bool(unlocked.get(id, false))

func get_tracker_text() -> String:
	if active.is_empty():
		return "No active quest\nFind a contract or speak to villagers."
	for id in active.keys():
		var title = str(quest_defs[id].get("title", id))
		for objective in active[id]["objectives"]:
			if not bool(objective.get("done", false)):
				return "%s\n- %s" % [title, objective["text"]]
	return "All tracked objectives complete."

func get_journal_text() -> String:
	var text = "ACTIVE QUESTS\n"
	for id in active.keys():
		text += "\n%s\n" % quest_defs[id].get("title", id)
		for objective in active[id]["objectives"]:
			text += "%s %s\n" % ["[x]" if bool(objective.get("done", false)) else "[ ]", objective["text"]]
	text += "\nCOMPLETED\n"
	for id in completed.keys():
		text += "- %s\n" % quest_defs[id].get("title", id)
	return text

func _try_complete_quest(id: String) -> void:
	for objective in active[id]["objectives"]:
		if not bool(objective.get("done", false)):
			return
	completed[id] = true
	active.erase(id)
	for next_id in quest_defs[id].get("unlocks", []):
		unlocked[next_id] = true
	message.emit("Quest complete: %s" % quest_defs[id].get("title", id))
	quest_completed.emit(id)

func save_state() -> Dictionary:
	return {
		"active": active,
		"completed": completed,
		"unlocked": unlocked,
		"world_flags": world_flags
	}

func load_state(state: Dictionary) -> void:
	active = state.get("active", active)
	completed = state.get("completed", completed)
	unlocked = state.get("unlocked", unlocked)
	world_flags = state.get("world_flags", world_flags)
	changed.emit()

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		push_warning("Missing JSON: %s" % path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed != null else {}
