extends RefCounted

## A view of the choice, never a second story authority. Only the transaction
## applies effects or records consent. Keys depend on effects, not translated text.
const CONTEXT_PATH := "res://data/decision_contexts.json"
const StoryJournalPresenter = preload("res://scripts/story_journal.gd")
const RouteCatalog = preload("res://scripts/story_route_catalog.gd")
static var _contexts: Dictionary = {}

static func is_commitment(action: Dictionary) -> bool:
	return str(action.get("type", "")) in ["story_choice", "resolve_side_quest", "ending", "final_choice"]

static func decision_id(action: Dictionary) -> String:
	if str(action.get("type", "")) in ["ending", "final_choice"]:
		return "final_covenant"
	if not is_commitment(action):
		return ""
	var explicit_id: String = str(action.get("choice_id", "")).strip_edges()
	if explicit_id != "":
		return explicit_id
	var quest_id: String = str(action.get("quest", ""))
	var objective_id: String = str(action.get("objective", ""))
	if str(action.get("type", "")) == "resolve_side_quest" and quest_id != "" and objective_id == "":
		return quest_id + ":resolution"
	if quest_id != "" or objective_id != "":
		return "%s:%s" % [quest_id, objective_id]
	var flags: Dictionary = action.get("sets_flags", {})
	var keys: Array = flags.keys()
	keys.sort()
	return "promise:%s" % ",".join(keys)

static func option_key(action: Dictionary) -> String:
	var group_id: String = decision_id(action)
	if group_id == "":
		return ""
	var effects := {
		"type":str(action.get("type", "")), "ending":str(action.get("ending", "")), "outcome":str(action.get("outcome", "")),
		"flags":action.get("sets_flags", {}), "values":action.get("adjusts_values", {}),
		"completes":action.get("completes", []), "items":action.get("gives_items", {}),
		"quest":str(action.get("quest", "")), "objective":str(action.get("objective", ""))
	}
	return group_id + ":" + _canonical(effects).sha256_text().left(16)

static func describe(action: Dictionary, state, quests, scene_id: String = "") -> Dictionary:
	if not is_commitment(action):
		return {}
	var context: Dictionary = _context(action, scene_id)
	var option: Dictionary = _option(context, action)
	var label: String = str(action.get("label", "Keep this promise"))
	var commitment: String = str(option.get("commitment", label)).strip_edges()
	var cost: String = str(option.get("cost", context.get("cost", action.get("cost", "")))).strip_edges()
	var follow_through: String = str(option.get("follow_through", context.get("follow_through", ""))).strip_edges()
	var uncertainty: String = str(option.get("uncertainty", context.get("uncertainty", ""))).strip_edges()
	if cost == commitment:
		cost = ""
	if follow_through in [commitment, cost]:
		follow_through = ""
	return {
		"decision_id":decision_id(action), "option_key":option_key(action), "label":label,
		"title":str(context.get("title", "The choice at hand")),
		"commitment":commitment, "cost":cost, "known_facts":_known_facts(context, state, quests),
		"uncertainty":uncertainty, "follow_through":follow_through,
		# DialogueManager attaches this only after its ordinary availability filter.
		# Root rechecks the actual action before committing it.
		"available":true, "reason":""
	}

static func receipt(action: Dictionary, state, quests, zone_id: String = "") -> Dictionary:
	if not is_commitment(action):
		return {}
	var model: Dictionary = describe(action, state, quests)
	var intention: bool = str(action.get("type", "")) in ["ending", "final_choice"] and state != null and not bool(state.get_flag("final_choice_completed", false))
	var body: String = str(model.get("commitment", action.get("label", "A commitment is recorded.")))
	if not intention:
		body = str(action.get("result", body)).strip_edges()
		if body == "":
			body = str(model.get("commitment", "A commitment is recorded."))
	var next_step: Dictionary = _next_step(state, quests, zone_id)
	return {
		"id":option_key(action), "decision_id":decision_id(action),
		"title":"Intention chosen" if intention else "Choice recorded",
		"body":body, "stage":"intention" if intention else "commitment",
		"next_action":str(next_step.get("action", "")),
		"destination_name":str(next_step.get("destination_name", ""))
	}

static func _context(action: Dictionary, scene_id: String) -> Dictionary:
	_ensure_loaded()
	var contexts: Dictionary = _contexts.get("contexts", {})
	var key: String = "final_covenant" if str(action.get("type", "")) in ["ending", "final_choice"] else "%s:%s" % [str(action.get("quest", "")), str(action.get("objective", ""))]
	if contexts.has(key):
		return contexts[key]
	var explicit: String = decision_id(action)
	if contexts.has(explicit):
		return contexts[explicit]
	var scenes: Dictionary = _contexts.get("scenes", {})
	return contexts.get(str(scenes.get(scene_id, "")), {})

static func _option(context: Dictionary, action: Dictionary) -> Dictionary:
	var flags: Dictionary = action.get("sets_flags", {})
	for raw_option in context.get("options", []):
		if not raw_option is Dictionary:
			continue
		var option: Dictionary = raw_option
		var matches := true
		var selectors: Dictionary = option.get("when_flags", {})
		for flag in selectors:
			if not flags.has(flag) or flags[flag] != selectors[flag]:
				matches = false
				break
		if option.has("ending") and str(option.get("ending", "")) != str(action.get("ending", "")):
			matches = false
		if matches and (not selectors.is_empty() or option.has("ending")):
			return option
	return {}

static func _known_facts(context: Dictionary, state, quests) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var requested: Array = context.get("evidence", [])
	var available: Dictionary = {}
	for raw_fact in StoryJournalPresenter.campaign().get("evidence", []):
		if raw_fact is Dictionary:
			available[str(raw_fact.get("id", ""))] = raw_fact
	for raw_fact in context.get("facts", []):
		if raw_fact is Dictionary:
			available[str(raw_fact.get("id", ""))] = raw_fact
	for raw_id in requested:
		var id: String = str(raw_id)
		var fact: Dictionary = available.get(id, {})
		if fact.is_empty() or not StoryJournalPresenter._discovered(fact, quests, state):
			continue
		var kind: String = str(fact.get("kind", "observed"))
		if kind not in ["observed", "testimony", "inference"]:
			kind = "observed"
		result.append({"id":id, "title":str(fact.get("title", "Known account")), "text":str(fact.get("text", "")), "kind":kind, "source":str(fact.get("source", "Recorded evidence"))})
		if result.size() >= 3:
			break
	return result

static func _next_step(state, quests, zone_id: String) -> Dictionary:
	var continuation: Dictionary = RouteCatalog.ending_continuation(state, zone_id)
	if not continuation.is_empty():
		return continuation
	if quests == null:
		return {}
	var quest_id: String = str(quests.get_tracked_quest())
	if quest_id == "":
		for raw_id in quests.active:
			if str(quests.quest_defs.get(raw_id, {}).get("type", "")) == "main":
				quest_id = str(raw_id)
				break
	if quest_id == "" or not quests.active.has(quest_id):
		return {}
	var objective_id: String = str(quests.get_active_objective_id(quest_id))
	if objective_id == "":
		return {}
	var route: Dictionary = RouteCatalog.for_objective(quest_id, objective_id, state, quests, zone_id)
	var action: String = str(route.get("next_action", ""))
	if action == "":
		for objective in quests.active[quest_id].get("objectives", []):
			if str(objective.get("id", "")) == objective_id:
				action = str(objective.get("text", "")).trim_suffix(".")
				break
	return {"action":action, "destination_name":str(route.get("destination_name", ""))}

static func _canonical(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var parts: Array[String] = []
		for key in keys:
			parts.append(JSON.stringify(str(key)) + ":" + _canonical(value[key]))
		return "{" + ",".join(parts) + "}"
	if value is Array:
		var members: Array[String] = []
		for member in value:
			members.append(_canonical(member))
		return "[" + ",".join(members) + "]"
	return JSON.stringify(value)

static func _ensure_loaded() -> void:
	if not _contexts.is_empty():
		return
	if not FileAccess.file_exists(CONTEXT_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTEXT_PATH))
	if parsed is Dictionary:
		_contexts = parsed
