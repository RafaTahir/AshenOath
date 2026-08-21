extends Node

var dialogues = {}
var story_state
var quest_manager

func setup(state, quests = null) -> void:
	story_state = state
	quest_manager = quests

func load_dialogue(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("Missing JSON: %s" % path)
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		dialogues.merge(parsed, true)

func get_dialogue(id: String) -> Dictionary:
	var base: Dictionary = dialogues.get(id, {
		"name": "Unknown",
		"greeting": "...",
		"lines": [],
		"actions": []
	}).duplicate(true)
	var candidates: Array = base.get("variants", [])
	candidates.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	for variant in candidates:
		if story_state == null or story_state.matches(variant.get("conditions", {})):
			for key in variant:
				if key not in ["conditions", "priority"]:
					base[key] = variant[key]
			break
	base.erase("variants")
	# Subtitles remain authoritative when a voice clip is absent, muted, or
	# blocked by browser audio policy. Keep the fallback in the resolved entry.
	base["fallback_text"] = str(base.get("fallback_text", base.get("greeting", "...")))
	base["subtitle_fallback"] = true
	var visible_actions: Array = []
	for action in base.get("actions", []):
		if _conditions_match(action.get("conditions", {})):
			visible_actions.append(action)
	base["actions"] = visible_actions
	base["pages"] = _build_pages(base)
	return base

func _build_pages(data: Dictionary) -> Array:
	var pages: Array = []
	var default_speaker := str(data.get("name", "Unknown"))
	var greeting := str(data.get("greeting", "")).strip_edges()
	if greeting != "":
		pages.append({"speaker": default_speaker, "text": greeting})
	for raw_line in data.get("lines", []):
		var line := str(raw_line).strip_edges()
		if line == "":
			continue
		var speaker := default_speaker
		var separator := line.find(": ")
		if separator > 0 and separator < 32:
			speaker = line.left(separator).strip_edges()
			line = line.substr(separator + 2).strip_edges()
		pages.append({"speaker": speaker, "text": line})
	return pages

func _conditions_match(raw_conditions: Variant) -> bool:
	if typeof(raw_conditions) != TYPE_DICTIONARY:
		return true
	var conditions: Dictionary = raw_conditions
	var story_conditions: Dictionary = {}
	for key in conditions:
		if key not in ["quest_active", "quest_available", "quest_completed", "objectives_done", "objectives_not_done"]:
			story_conditions[key] = conditions[key]
	if story_state != null and not story_state.matches(story_conditions):
		return false
	if quest_manager == null:
		return true
	if conditions.has("quest_active") and not quest_manager.is_active(str(conditions["quest_active"])):
		return false
	if conditions.has("quest_available"):
		var available_id := str(conditions["quest_available"])
		if not quest_manager.is_unlocked(available_id) or quest_manager.is_active(available_id) or quest_manager.is_completed(available_id):
			return false
	if conditions.has("quest_completed") and not quest_manager.is_completed(str(conditions["quest_completed"])):
		return false
	if not _objectives_match(conditions.get("objectives_done", []), true):
		return false
	if not _objectives_match(conditions.get("objectives_not_done", []), false):
		return false
	return true

func _objectives_match(raw_objectives: Variant, expected_done: bool) -> bool:
	if raw_objectives == null:
		return true
	var objectives: Array = raw_objectives if raw_objectives is Array else [raw_objectives]
	for raw_objective in objectives:
		if typeof(raw_objective) != TYPE_DICTIONARY:
			continue
		var quest_id := str(raw_objective.get("quest", ""))
		var objective_id := str(raw_objective.get("id", raw_objective.get("objective", "")))
		if quest_id == "" or objective_id == "":
			continue
		var done: bool = bool(quest_manager.is_objective_done(quest_id, objective_id))
		if done != expected_done:
			return false
	return true
