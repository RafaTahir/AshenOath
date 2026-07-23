extends Node

signal changed
signal message(text: String)
signal quest_completed(id: String)

var quest_defs = {}
var active = {}
var completed = {}
var unlocked = {
	"main_road_of_crows": true, "side_widows_bell": true, "side_iron_remembers": true,
	"side_bitter_roots": true, "side_black_dog": true, "side_empty_grave": true,
	"side_childs_charm": true, "side_soldiers_debt": true, "side_millers_measure": true,
	"side_rooks_map": true, "side_three_candles": true
}
var world_flags = {}
var tracked_quest_id := ""
var tracker_context_zone := ""

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
		var runtime_objective: Dictionary = objective.duplicate(true)
		runtime_objective["done"] = false
		objectives.append(runtime_objective)
	active[id] = {"objectives": objectives}
	if tracked_quest_id == "" or str(quest_defs[id].get("type", "")) == "main":
		tracked_quest_id = id
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
			if str(objective.get("completion_flag", "")) != "":
				world_flags[str(objective["completion_flag"])] = true
			message.emit("Objective complete: %s" % objective["text"])
			_update_evidence_groups(quest_id)
			_try_complete_quest(quest_id)
			changed.emit()
			return true
	return false

func complete_evidence(quest_id: String, evidence_id: String) -> bool:
	return complete_objective(quest_id, evidence_id)

func _update_evidence_groups(quest_id: String) -> void:
	if not active.has(quest_id): return
	var objectives: Array = active[quest_id]["objectives"]
	var groups: Dictionary = {}
	for objective in objectives:
		var group := str(objective.get("group", ""))
		if group == "": continue
		if not groups.has(group): groups[group] = {"done": 0, "required": int(objective.get("required_count", 1))}
		if bool(objective.get("done", false)): groups[group]["done"] += 1
	for objective in objectives:
		var group := str(objective.get("group", ""))
		if group == "" or not groups.has(group): continue
		if bool(objective.get("optional", false)):
			objective["optional_satisfied"] = int(groups[group]["done"]) >= int(groups[group]["required"])
		elif int(objective.get("required_count", 0)) > 0 and int(groups[group]["done"]) >= int(objective["required_count"]):
			objective["done"] = true

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
	if tracker_context_zone != "" and tracked_quest_id == "":
		return "No objective in this area\nFollow the road or review the journal."
	var ordered_ids: Array = []
	if tracked_quest_id != "" and active.has(tracked_quest_id):
		ordered_ids.append(tracked_quest_id)
	for id in active.keys():
		if id not in ordered_ids:
			ordered_ids.append(id)
	for id in ordered_ids:
		var title = str(quest_defs[id].get("title", id))
		for objective in active[id]["objectives"]:
			if bool(objective.get("done", false)):
				continue
			if bool(objective.get("optional", false)) and bool(objective.get("optional_satisfied", false)):
				continue
			return "%s\n- %s" % [title, objective["text"]]
	return "All tracked objectives complete."

func set_tracked_quest(id: String) -> bool:
	if not active.has(id):
		return false
	tracked_quest_id = id
	changed.emit()
	return true

func get_tracked_quest() -> String:
	return tracked_quest_id if active.has(tracked_quest_id) else ""

func set_tracked_quest_for_zone(zone_id: String) -> void:
	tracker_context_zone = zone_id
	var preferences := {
		"greyfen":["main_bell_beneath_greyfen","main_road_of_crows"],
		"wychwood":["main_road_of_crows","main_teeth_in_rain"],
		"deep_wood":["main_teeth_in_rain","main_names_they_burned"],
		"old_mill":["main_ash_at_the_mill"],
		"burned_farmstead":["main_names_they_burned"],
		"marsh_crossing":["main_names_they_burned"],
		"bandit_road":["main_soldier_without_banner"],
		"vargan_approach":["main_blood_under_stone"],
		"vargan_court":["main_blood_under_stone"],
		"record_hall":["main_blood_under_stone"],
		"undercroft":["main_last_witness"],
		"assembly":["main_crowns_without_mercy"],
		"hart_glade":["main_hart_remembers"]
	}
	for id in preferences.get(zone_id, []):
		if active.has(id):
			tracked_quest_id = id
			changed.emit()
			return
	tracked_quest_id = ""
	changed.emit()

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
		if not bool(objective.get("done", false)) and not bool(objective.get("optional", false)):
			return
	completed[id] = true
	active.erase(id)
	if tracked_quest_id == id:
		tracked_quest_id = ""
	for next_id in quest_defs[id].get("unlocks", []):
		unlocked[next_id] = true
	message.emit("Quest complete: %s" % quest_defs[id].get("title", id))
	quest_completed.emit(id)
	if str(quest_defs[id].get("type", "")) == "main":
		for next_id in quest_defs[id].get("unlocks", []):
			start_quest(str(next_id))

func save_state() -> Dictionary:
	return {
		"active": active,
		"completed": completed,
		"unlocked": unlocked,
		"world_flags": world_flags,
		"tracked_quest_id": tracked_quest_id,
		"tracker_context_zone": tracker_context_zone
	}

func load_state(state: Dictionary) -> void:
	active = state.get("active", active)
	completed = state.get("completed", completed)
	unlocked = state.get("unlocked", unlocked)
	world_flags = state.get("world_flags", world_flags)
	tracked_quest_id = str(state.get("tracked_quest_id", tracked_quest_id))
	tracker_context_zone = str(state.get("tracker_context_zone", tracker_context_zone))
	changed.emit()

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		push_warning("Missing JSON: %s" % path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed != null else {}
