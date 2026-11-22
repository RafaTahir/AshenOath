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
	base["presentation"] = _presentation_contract(base.get("presentation", {}))
	var visible_actions: Array = []
	for action in base.get("actions", []):
		if str(action.get("type", "")) == "start_quest" and quest_manager != null and quest_manager.has_method("is_runtime_content_ready"):
			if not quest_manager.is_runtime_content_ready(str(action.get("quest", ""))):
				continue
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
		pages.append({
			"speaker": default_speaker,
			"speaker_id": _speaker_id(default_speaker),
			"text": greeting,
			"beat": "greeting"
		})
	for raw_line in data.get("lines", []):
		var line := str(raw_line.get("text", "")) if typeof(raw_line) == TYPE_DICTIONARY else str(raw_line)
		line = line.strip_edges()
		if line == "":
			continue
		var speaker := default_speaker
		var speaker_id := _speaker_id(default_speaker)
		var beat := "line"
		var direction := ""
		var pause_after := 0.0
		if typeof(raw_line) == TYPE_DICTIONARY:
			speaker = str(raw_line.get("speaker", default_speaker)).strip_edges()
			speaker_id = str(raw_line.get("speaker_id", _speaker_id(speaker))).strip_edges()
			beat = str(raw_line.get("beat", "line"))
			direction = str(raw_line.get("direction", ""))
			pause_after = maxf(float(raw_line.get("pause_after", 0.0)), 0.0)
		var separator := line.find(": ")
		if separator > 0 and separator < 32:
			speaker = line.left(separator).strip_edges()
			line = line.substr(separator + 2).strip_edges()
			speaker_id = _speaker_id(speaker)
		var page := {
			"speaker": speaker,
			"speaker_id": speaker_id,
			"text": line,
			"beat": beat
		}
		if direction != "":
			page["direction"] = direction
		if pause_after > 0.0:
			page["pause_after"] = pause_after
		pages.append(page)
	return pages

func _speaker_id(value: String) -> String:
	var normalized := value.to_lower().strip_edges()
	if normalized in ["kael", "the hunter"]:
		return "player"
	if normalized in ["anwen", "sister anwen"]:
		return "sister_anwen"
	if normalized in ["the white hart", "white hart"]:
		return "white_hart"
	return normalized.replace("'", "").replace(" ", "_").replace("-", "_")

func _presentation_contract(raw: Variant) -> Dictionary:
	var presentation: Dictionary = raw.duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}
	presentation["framing"] = str(presentation.get("framing", "face_to_face"))
	presentation["speaker_focus"] = str(presentation.get("speaker_focus", "actor"))
	presentation["subtitle_cps"] = clampf(float(presentation.get("subtitle_cps", 18.0)), 8.0, 32.0)
	presentation["reaction_pause"] = clampf(float(presentation.get("reaction_pause", 0.18)), 0.0, 1.2)
	presentation["subtitle_fallback"] = true
	return presentation

func _conditions_match(raw_conditions: Variant) -> bool:
	if typeof(raw_conditions) != TYPE_DICTIONARY:
		return true
	var conditions: Dictionary = raw_conditions
	if conditions.has("flag_unset") and story_state != null:
		var unset_id := str(conditions.get("flag_unset", ""))
		if unset_id != "" and story_state.get_flag(unset_id, null) != null:
			return false
	var story_conditions: Dictionary = {}
	for key in conditions:
		if key not in ["quest_active", "quest_available", "quest_completed", "objectives_done", "objectives_not_done", "flag_unset"]:
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
