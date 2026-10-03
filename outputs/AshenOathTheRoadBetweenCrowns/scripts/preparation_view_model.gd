extends RefCounted

## Read-only preparation descriptions. Resource restoration uses this same
## resolved_effect API at the action boundary in game.gd.
const CATALOG_PATH := "res://data/preparation_notes.json"
static var _catalog: Dictionary = {}

static func resolved_effect(item_id: String, inventory, progression = null) -> Dictionary:
	var definition: Dictionary = inventory.item_defs.get(item_id, {})
	var source: Dictionary = definition.get("effect", {})
	var result: Dictionary = {}
	for key: String in ["heal", "stamina", "damage"]:
		if source.has(key):
			result[key] = maxf(float(source[key]), 0.0)
	if item_id == "redroot_potion" and result.has("heal") and progression != null:
		result["heal"] = float(result.heal) + float(progression.effect_value("potion_heal_bonus", 0.0))
	return result

static func item_detail(item_id: String, inventory, progression = null, context: Dictionary = {}, state = null, quests = null) -> Dictionary:
	var definition: Dictionary = inventory.item_defs.get(item_id, {})
	if definition.is_empty():
		return {"id": item_id, "title": "Unavailable item", "body": "This item has no preparation record.", "type": "misc", "owned": 0, "cap": 0, "selected": false, "effects": [], "comparison": [], "actions": [], "known_use": []}
	var catalog: Dictionary = _load_catalog()
	var notes: Dictionary = catalog.get("items", {}).get(item_id, {})
	var kind: String = str(inventory.get_item_type(item_id))
	var owned: int = int(inventory.items.get(item_id, 0))
	var cap: int = int(inventory.get_ammo_cap(item_id)) if kind == "ammo" else 0
	var active_arrow: String = str(context.get("selected_arrow_id", "standard_arrow"))
	var active_oil: String = str(inventory.active_oil)
	var selected: bool = (kind == "ammo" and active_arrow == item_id) or (kind == "oil" and active_oil == item_id)
	var effects: Array[Dictionary] = _effect_rows(item_id, inventory, progression, context)
	for raw: Variant in notes.get("effects", []):
		if typeof(raw) == TYPE_DICTIONARY:
			effects.append({"id": str(raw.get("id", "")), "label": str(raw.get("title", "")), "text": str(raw.get("text", ""))})
	var comparison: Array[Dictionary] = []
	if kind == "ammo":
		comparison = _arrow_comparison(item_id, active_arrow, inventory)
	elif kind == "oil":
		comparison.append({"id": "coating", "label": "Blade coating", "current": str(inventory.get_item_name(active_oil)) if active_oil != "" else "No coating selected", "candidate": str(inventory.get_item_name(item_id)), "delta": "Already selected" if selected else "Replaces the selected coating"})
	var actions: Array[Dictionary] = []
	var action: Dictionary = _item_action(item_id, kind, owned, selected, context)
	if not action.is_empty():
		actions.append(action)
	return {"id": item_id, "title": str(inventory.get_item_name(item_id)), "body": str(notes.get("body", definition.get("description", ""))), "type": kind, "owned": owned, "cap": cap, "selected": selected, "effects": effects, "comparison": comparison, "actions": actions, "known_use": _known_uses(item_id, catalog, state, quests)}

static func _effect_rows(item_id: String, inventory, progression, context: Dictionary) -> Array[Dictionary]:
	var effect: Dictionary = resolved_effect(item_id, inventory, progression)
	var rows: Array[Dictionary] = []
	if effect.has("heal"):
		var text: String = "Restore up to %d health immediately." % int(effect.heal)
		if context.has("health") and context.has("max_health"):
			var recovery: int = int(ceilf(minf(float(effect.heal), maxf(float(context.max_health) - float(context.health), 0.0))))
			text += " At your current health: up to %d." % recovery
		rows.append({"id": "heal", "label": "Recovery", "text": text})
	if effect.has("stamina"):
		var text: String = "Restore up to %d stamina immediately." % int(effect.stamina)
		if context.has("stamina") and context.has("max_stamina"):
			var recovery: int = int(ceilf(minf(float(effect.stamina), maxf(float(context.max_stamina) - float(context.stamina), 0.0))))
			text += " At your current stamina: up to %d." % recovery
		rows.append({"id": "stamina", "label": "Recovery", "text": text})
	if effect.has("damage"):
		rows.append({"id": "damage", "label": "Base damage", "text": "%d before the target's response." % int(effect.damage)})
	return rows

static func _item_action(item_id: String, kind: String, owned: int, selected: bool, context: Dictionary) -> Dictionary:
	var id: String = ""
	var verb: String = ""
	if kind == "ammo":
		id = "select_arrow"
		verb = "Select arrow"
	elif kind == "oil":
		id = "apply_oil"
		verb = "Apply oil"
	elif kind == "potion":
		id = "use"
		verb = "Use remedy"
	elif kind == "bomb":
		id = "throw"
		verb = "Throw bomb"
	elif kind == "trap":
		id = "set"
		verb = "Set trap"
	if id == "":
		return {}
	var reason: String = ""
	if owned <= 0:
		reason = "You do not carry this item."
	elif selected:
		reason = "This arrow is already selected." if kind == "ammo" else "This coating is already selected."
	elif item_id == "redroot_potion" and context.has("health") and context.has("max_health") and float(context.health) >= float(context.max_health):
		reason = "Your health is full; keep the remedy for an injury."
	elif item_id == "bitterleaf_tonic" and context.has("stamina") and context.has("max_stamina") and float(context.stamina) >= float(context.max_stamina):
		reason = "Your stamina is full; keep the tonic for spent breath."
	return {"id": id, "verb": verb, "available": reason == "", "reason": reason}

static func _arrow_comparison(item_id: String, selected_id: String, inventory) -> Array[Dictionary]:
	var current: Dictionary = inventory.item_defs.get(selected_id, {})
	var candidate: Dictionary = inventory.item_defs.get(item_id, {})
	var current_effect: Dictionary = current.get("effect", {})
	var candidate_effect: Dictionary = candidate.get("effect", {})
	var current_damage: int = int(current_effect.get("damage", 0))
	var candidate_damage: int = int(candidate_effect.get("damage", 0))
	var current_cap: int = int(current.get("cap", 0))
	var candidate_cap: int = int(candidate.get("cap", 0))
	var rows: Array[Dictionary] = [
		{"id": "arrow", "label": "Selected bundle", "current": str(inventory.get_item_name(selected_id)), "candidate": str(inventory.get_item_name(item_id)), "delta": "Already selected" if item_id == selected_id else "Select without spending an arrow"},
		{"id": "damage", "label": "Base impact damage", "current": str(current_damage), "candidate": str(candidate_damage), "delta": _difference(candidate_damage - current_damage)},
		{"id": "capacity", "label": "Bundle capacity", "current": str(current_cap), "candidate": str(candidate_cap), "delta": _difference(candidate_cap - current_cap)}
	]
	return rows

static func _difference(value: int) -> String:
	return "+%d" % value if value > 0 else (str(value) if value < 0 else "No change")

static func _known_uses(item_id: String, catalog: Dictionary, state, quests) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw: Variant in catalog.get("known_use", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw
		if item_id not in entry.get("item_ids", []):
			continue
		var known: bool = true
		var required_flag: String = str(entry.get("requires_flag", ""))
		if required_flag != "":
			known = state != null and bool(state.get_flag(required_flag, false))
		for raw_gate: Variant in entry.get("requires_all", []):
			if typeof(raw_gate) != TYPE_DICTIONARY or not _discovered(raw_gate, state, quests):
				known = false
		if known:
			result.append({"id": str(entry.get("id", "")), "title": str(entry.get("title", "")), "body": str(entry.get("body", ""))})
	return result

static func _discovered(gate: Dictionary, state, quests) -> bool:
	var evidence_id: String = str(gate.get("evidence", ""))
	if state != null and evidence_id != "":
		var evidence: Variant = state.get("evidence")
		if typeof(evidence) == TYPE_DICTIONARY and evidence.has(evidence_id):
			return true
	if quests == null:
		return false
	var quest_id: String = str(gate.get("quest", ""))
	var objective_id: String = str(gate.get("objective", ""))
	if quest_id == "" or objective_id == "":
		return false
	var history: Variant = quests.get("evidence_history")
	if typeof(history) == TYPE_DICTIONARY and bool(history.get(quest_id + ":" + objective_id, false)):
		return true
	return bool(quests.is_active(quest_id)) and bool(quests.is_objective_done(quest_id, objective_id))

static func _load_catalog() -> Dictionary:
	if _catalog.is_empty() and FileAccess.file_exists(CATALOG_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_catalog = parsed
	return _catalog
