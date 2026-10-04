extends Node

const StoryChoicePresenter = preload("res://scripts/story_choice_presenter.gd")

var dialogues = {}
var conversation_topics: Array[Dictionary] = []
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

func load_conversation_topics(path: String) -> void:
	conversation_topics.clear()
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("version", 0)) != 1:
		return
	var raw_topics: Variant = parsed.get("topics", [])
	if not raw_topics is Array:
		return
	var loaded_ids: Dictionary = {}
	for raw_topic: Variant in raw_topics:
		if not raw_topic is Dictionary:
			continue
		var topic_id: String = str(raw_topic.get("id", "")).strip_edges()
		if topic_id == "" or loaded_ids.has(topic_id):
			continue
		loaded_ids[topic_id] = true
		conversation_topics.append(raw_topic.duplicate(true))

func get_conversation_topics(actor_id: String, zone_id: String, seen_keys: Array = []) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for topic: Dictionary in conversation_topics:
		var resolved: Dictionary = _resolve_conversation_topic(topic, actor_id, zone_id)
		if resolved.is_empty():
			continue
		var scene: Dictionary = _conversation_topic_scene(resolved)
		if scene.is_empty():
			continue
		var history_key: String = str(scene.get("topic_history_key", ""))
		rows.append({
			"id": str(scene.get("topic_id", "")),
			"title": str(resolved.get("title", "Ask about this")),
			"summary": str(resolved.get("summary", "")),
			"revision_key": str(scene.get("topic_revision", "")),
			"history_key": history_key,
			"visited": seen_keys.has(history_key)
		})
	return rows

func get_conversation_topic(topic_id: String, actor_id: String, zone_id: String, expected_revision: String) -> Dictionary:
	if topic_id == "" or expected_revision == "":
		return {}
	for topic: Dictionary in conversation_topics:
		if str(topic.get("id", "")) != topic_id:
			continue
		var resolved: Dictionary = _resolve_conversation_topic(topic, actor_id, zone_id)
		if resolved.is_empty():
			return {}
		var scene: Dictionary = _conversation_topic_scene(resolved)
		if str(scene.get("topic_revision", "")) != expected_revision:
			return {}
		return scene
	return {}

func _resolve_conversation_topic(topic: Dictionary, actor_id: String, zone_id: String) -> Dictionary:
	# Topic availability uses the actual staged actor, never a dialogue title or
	# an alias inferred from a remote witness, noticeboard, or written record.
	var actor_ids: Variant = topic.get("actor_ids", [])
	if actor_id == "" or not actor_ids is Array or not actor_ids.has(actor_id):
		return {}
	var zones: Variant = topic.get("zones", [])
	if not zones is Array or (not zones.is_empty() and not zones.has(zone_id)):
		return {}
	if not _topic_conditions_match(topic):
		return {}
	var raw_variants: Variant = topic.get("variants", [])
	if not raw_variants is Array:
		return {}
	var selected: Dictionary = {}
	for raw_variant: Variant in raw_variants:
		if not raw_variant is Dictionary:
			continue
		var variant: Dictionary = raw_variant
		if str(variant.get("id", "")).strip_edges() == "" or not _topic_conditions_match(variant):
			continue
		if selected.is_empty() or int(variant.get("priority", 0)) > int(selected.get("priority", 0)):
			selected = variant
	if bool(topic.get("require_variant", false)) and selected.is_empty():
		return {}
	var resolved: Dictionary = topic.duplicate(true)
	# Only reading fields may vary. Authored action/effect payloads cannot flow
	# from this catalog into the story decision coordinator.
	for field: String in ["title", "summary", "lines"]:
		if selected.has(field):
			resolved[field] = selected[field]
	resolved["selected_variant_id"] = str(selected.get("id", "base"))
	return resolved

func _topic_conditions_match(entry: Dictionary) -> bool:
	var conditions: Variant = entry.get("conditions", {})
	var known_evidence: Variant = entry.get("known_evidence", [])
	if not conditions is Dictionary or not known_evidence is Array:
		return false
	# Unlike legacy dialogue fallbacks, optional topics fail closed before
	# story services exist. Missing knowledge must never unlock a later topic.
	if story_state == null:
		return false
	for key: Variant in conditions:
		if str(key) in ["quest_active", "quest_available", "quest_completed", "objectives_done", "objectives_not_done"] and quest_manager == null:
			return false
	if not _conditions_match(conditions):
		return false
	for raw_id: Variant in known_evidence:
		if not raw_id is String or str(raw_id).strip_edges() == "" or not story_state.has_evidence(str(raw_id)):
			return false
	return true

func _conversation_topic_scene(resolved: Dictionary) -> Dictionary:
	var topic_id: String = str(resolved.get("id", "")).strip_edges()
	var revision: String = str(resolved.get("revision", "")).strip_edges()
	var speaker_id: String = str(resolved.get("speaker_id", "")).strip_edges()
	var speaker_name: String = str(resolved.get("name", "")).strip_edges()
	var raw_lines: Variant = resolved.get("lines", [])
	if topic_id == "" or revision == "" or speaker_id == "" or speaker_id == "player" or speaker_name == "" or not raw_lines is Array:
		return {}
	var revision_key: String = "%s:%s:%s" % [topic_id, revision, str(resolved.get("selected_variant_id", "base"))]
	var history_key: String = "conversation_topic:" + revision_key
	var pages: Array[Dictionary] = []
	for raw_line: Variant in raw_lines:
		if not raw_line is Dictionary:
			return {}
		var line: Dictionary = raw_line
		var line_speaker_id: String = str(line.get("speaker_id", "")).strip_edges()
		var line_text: String = str(line.get("text", "")).strip_edges()
		if line_speaker_id not in ["player", speaker_id]:
			return {}
		if line_text == "":
			continue
		var page: Dictionary = {
			"speaker": "Kael" if line_speaker_id == "player" else speaker_name,
			"speaker_id": line_speaker_id,
			"text": line_text,
			"text_id": "%s:page:%d" % [history_key, pages.size()],
			"beat": str(line.get("beat", "line")),
			"read_only": true,
			"topic_id": topic_id,
			"topic_revision": revision_key,
			"topic_history_key": history_key
		}
		var direction: String = str(line.get("direction", "")).strip_edges()
		if direction != "":
			page["direction"] = direction
		var pause_after: float = maxf(float(line.get("pause_after", 0.0)), 0.0)
		if pause_after > 0.0:
			page["pause_after"] = pause_after
		pages.append(page)
	if pages.is_empty():
		return {}
	return {
		"topic_id": topic_id,
		"topic_revision": revision_key,
		"topic_history_key": history_key,
		"read_only": true,
		"name": speaker_name,
		"scene_id": "conversation_topic/" + revision_key,
		"presentation": _presentation_contract(resolved.get("presentation", {})),
		"subtitle_fallback": true,
		"fallback_text": str(pages[0].get("text", "")),
		"pages": pages,
		"actions": []
	}

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
		if _conditions_match(variant.get("conditions", {})):
			for key in variant:
				if key not in ["conditions", "priority"]:
					base[key] = variant[key]
			break
	base.erase("variants")
	base["scene_id"] = id
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
			if StoryChoicePresenter.is_commitment(action):
				action["decision_model"] = StoryChoicePresenter.describe(action, story_state, quest_manager, id)
			visible_actions.append(action)
	base["actions"] = visible_actions
	base["pages"] = _build_pages(base)
	for page_index: int in range(base["pages"].size()):
		var page: Dictionary = base["pages"][page_index]
		page["scene_id"] = id
		page["performance"] = preload("res://scripts/story_scene_direction.gd").for_page(id, page, page_index)
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
