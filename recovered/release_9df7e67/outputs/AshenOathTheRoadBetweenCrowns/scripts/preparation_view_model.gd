extends RefCounted

## Read-only preparation descriptions. Resource restoration uses this same
## resolved_effect API at the action boundary in game.gd.
const CATALOG_PATH := "res://data/preparation_notes.json"
static var _catalog: Dictionary = {}

static func service_text(vendor_id: String, inventory, context: Dictionary) -> String:
	var lines: Array[String] = [("Tor's Forge" if vendor_id == "tor_forge" else "Mira's Apothecary").to_upper(), "Greyfen", "\nKnown offers. Visit the counter for an exchange; your objective and coin remain unchanged."]
	var sources: Dictionary = context.get("supply_sources", {})
	var offers: int = 0
	for id: String in inventory.ordered_item_ids():
		for source: Dictionary in sources.get(id, []):
			if str(source.get("vendor_id", "")) != vendor_id:
				continue
			offers += 1
			lines.append("\n%s - %d coin\n%s %d%s" % [inventory.get_item_name(id), int(source.price), "Fitted" if inventory.get_item_type(id) == "blade_upgrade" else "Carrying", inventory.owned_count(id), "\n" + str(source.reason) if str(source.reason) != "" else ""])
	if offers == 0:
		lines.append("\nUnavailable: no unlocked offers are currently recorded.")
	return "\n".join(lines)

static func knowledge_summary(inventory, quests, state, context: Dictionary) -> String:
	var objective: Dictionary = context.get("objective", {})
	var lines: Array[String] = ["PREPARATION FOR THE ROAD", "\nCURRENT OBJECTIVE", str(objective.get("contextual_text", "The current lead is in On Return."))]
	var destination: String = str(objective.get("destination_name", ""))
	if destination != "":
		lines.append("Where: " + destination)
	lines.append("\nCARRIED SUPPLIES")
	for action: String in ["use_potion", "throw_bomb"]:
		var item_id: String = inventory.quick_item(action)
		lines.append("%s: %s x%d" % ["Remedy" if action == "use_potion" else "Field tool", inventory.get_item_name(item_id), int(inventory.items.get(item_id, 0))])
	var creatures: Array[Dictionary] = StoryJournal.creature_entries(quests, state)
	if creatures.is_empty():
		lines.append("\nUnavailable: no creature account has been discovered. Ordinary equipment is still usable; no purchase is required to investigate.")
	var sources: Dictionary = context.get("supply_sources", {})
	for creature: Dictionary in creatures:
		if bool(creature.get("resolved", false)):
			lines.append("\n%s: a resolution is recorded. No further combat preparation is required for that outcome." % str(creature.title))
			continue
		lines.append("\n" + str(creature.title).to_upper())
		var suggested: Array = creature.get("suggested_items", [])
		if suggested.is_empty():
			lines.append("Known: your carried blades remain usable. Leave stamina for a retreat.")
		for raw_id: Variant in suggested:
			var item_id: String = str(raw_id)
			var owned: int = int(inventory.items.get(item_id, 0))
			var text: String = "%s: %d carried" % [inventory.get_item_name(item_id), owned]
			if str(inventory.active_oil) == item_id:
				text += "; already applied"
			if owned == 0:
				text += "; craftable now" if inventory.can_craft(item_id) else "; unavailable in your pack"
			lines.append(text + ". Optional field preparation, not a required quest purchase.")
			for source: Dictionary in sources.get(item_id, []):
				lines.append("%s in Greyfen: %d coin%s." % [str(source.name), int(source.price), " - " + str(source.reason) if str(source.reason) != "" else " for one"])
			if owned == 0 and sources.get(item_id, []).is_empty():
				lines.append("Unavailable: no unlocked vendor offer is currently known.")
	lines.append("\nSERVICES\nTor's Forge: arrows and field tools. Mira's Apothecary: remedies and prepared oils. Travel to the counter for a purchase; this journal does not reserve stock or change your objective.")
	return "\n".join(lines)

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
	var owned: int = inventory.owned_count(item_id)
	var cap: int = int(inventory.get_ammo_cap(item_id)) if kind in ["ammo", "blade_upgrade"] else 0
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
	var slot: String = inventory.quick_slot_for_item(item_id)
	var assigned: bool = slot != "" and inventory.quick_item(slot) == item_id
	return {"id": item_id, "title": str(inventory.get_item_name(item_id)), "body": str(notes.get("body", definition.get("description", ""))), "type": kind, "owned": owned, "cap": cap, "selected": selected, "effects": effects, "comparison": comparison, "actions": actions, "known_use": _known_uses(item_id, catalog, state, quests), "quick_slot": slot, "quick_assigned": assigned}

static func equipment_text(id: String, inventory, context: Dictionary) -> String:
	var equipment: Dictionary = context.get("equipment", {})
	var active: String = "bow" if str(equipment.get("active_weapon", "sword")) == "bow" else str(equipment.get("selected_blade_id", "steel"))
	var drawn: bool = bool(equipment.get("bow_drawn" if active == "bow" else "sword_drawn", false))
	var names: Dictionary = {"steel": "Steel", "oathblade": "Oathblade", "bow": "Bow"}
	var lines: Array[String] = [str(names.get(id, id)).to_upper(), "Carried: 1", "Equipped: %s (%s)" % [str(names.get(active, active)), "drawn" if drawn else "sheathed"]]
	if id == "bow":
		var arrow_id: String = str(equipment.get("selected_arrow_id", "standard_arrow"))
		var arrow: Dictionary = inventory.item_defs.get(arrow_id, {})
		lines.append("\nA hunting bow for aimed, drawn shots. Arrows determine the impact; drawing fully increases their reach and force.")
		lines.append("Selected bundle: %s\nCarrying %d / %d\nBase impact: %d before draw strength and the target's response." % [inventory.get_item_name(arrow_id), inventory.get_ammo_count(arrow_id), inventory.get_ammo_cap(arrow_id), int(arrow.get("effect", {}).get("damage", 0))])
		lines.append("\nThe bow uses ammunition instead of blade affinity. It is not a direct sword-damage upgrade.")
	else:
		lines.append("\nA grounded hunter's blade for living bodies and armour." if id == "steel" else "\nAn oath-marked blade for spirits and the restless dead.")
		var current_blade: String = str(equipment.get("selected_blade_id", "steel"))
		lines.append("\nCOMPARED WITH %s" % str(names.get(current_blade, "Steel")).to_upper())
		for target: String in ["human", "spirit"]:
			lines.append("%s: %.2fx -> %.2fx" % ["Physical bodies" if target == "human" else "Spiritual bodies", EquipmentLoadout.blade_damage_multiplier(current_blade, target), EquipmentLoadout.blade_damage_multiplier(id, target)])
		lines.append("Forge improvement: +%.0f -> +%.0f strike damage." % [inventory.blade_upgrade_bonus(current_blade), inventory.blade_upgrade_bonus(id)])
		var fittings: Array[String] = []
		for upgrade_id: String in inventory.weapon_upgrades:
			if str(inventory.item_defs.get(upgrade_id, {}).get("blade_id", "")) == id:
				fittings.append(inventory.get_item_name(upgrade_id))
		lines.append("Fitted: " + (", ".join(fittings) if not fittings.is_empty() else "No forge improvement"))
		lines.append("Same unmodified strikes and stamina costs. Forge improvements add once after learned practice, before the target's response. The other blade still deals normal damage; oils and learned openings remain effective.")
	return "\n".join(lines)

static func ingredient_text(id: String, inventory) -> String:
	var uses: Array[String] = []
	for item_id: String in inventory.ordered_item_ids():
		var recipe: Dictionary = inventory.item_defs.get(item_id, {}).get("recipe", {})
		if recipe.has(id):
			uses.append("%s: %d required" % [inventory.get_item_name(item_id), int(recipe[id])])
	return "%s\nCarrying %d\n\n%s" % [id.replace("_", " ").to_upper(), int(inventory.ingredients.get(id, 0)), "FIELD RECIPES\n" + "\n".join(uses) if not uses.is_empty() else "No known field recipe uses this material. It remains in your pack."]

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
	if inventory.get_item_type(item_id) == "blade_upgrade":
		var definition: Dictionary = inventory.item_defs.get(item_id, {})
		var bonus: float = minf(float(definition.get("effect", {}).get("blade_damage_bonus", 0)), inventory.MAX_BLADE_UPGRADE_BONUS)
		rows.append({"id": "forge", "label": "Permanent blade improvement", "text": "+%.0f %s strike damage, added once after learned practice and before target affinity. No effect on the other blade, arrows or Oathfire. One fitting; no upkeep." % [bonus, str(definition.get("blade_id", "steel")).capitalize()]})
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
