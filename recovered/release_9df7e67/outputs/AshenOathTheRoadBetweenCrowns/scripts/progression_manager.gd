extends Node

signal changed
signal message(text: String)

const DEFINITIONS_PATH := "res://data/upgrades.json"
const BRANCH_ORDER := ["blade", "survival", "oathfire"]
const MASTERY_MARK_LIMIT := 9

var definitions: Dictionary = {}
var marks := 0
var unlocked: Dictionary = {}
var rewarded_quests: Dictionary = {}

func _ready() -> void:
	load_definitions()

func load_definitions() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DEFINITIONS_PATH))
	definitions = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func award_for_quest(quest_id: String, quest_type: String) -> bool:
	if quest_id == "" or quest_type != "main" or bool(rewarded_quests.get(quest_id, false)):
		return false
	rewarded_quests[quest_id] = true
	if _learned_count() + marks < MASTERY_MARK_LIMIT:
		marks += 1
		message.emit("Oath Mark earned. Choose an upgrade in the journal.")
	else:
		message.emit("The road's training is complete. Your final promise is a choice, not another upgrade.")
	changed.emit()
	return true

func reconcile_completed_quests(quest_definitions: Dictionary, completed_quests: Dictionary) -> int:
	var awarded := 0
	for quest_id in completed_quests:
		if not bool(completed_quests[quest_id]) or bool(rewarded_quests.get(quest_id, false)):
			continue
		if str(quest_definitions.get(quest_id, {}).get("type", "")) != "main":
			continue
		rewarded_quests[quest_id] = true
		if _learned_count() + marks < MASTERY_MARK_LIMIT:
			marks += 1
		awarded += 1
	if awarded > 0:
		changed.emit()
	return awarded

func can_unlock(id: String) -> bool:
	return bool(upgrade_status(id).get("available", false))

func upgrade_status(id: String) -> Dictionary:
	var definition: Dictionary = definitions.get(id, {})
	var required: String = str(definition.get("requires", ""))
	var required_name: String = str(definitions.get(required, {}).get("name", required))
	var learned: bool = has_upgrade(id)
	var reason: String = ""
	if definition.is_empty():
		reason = "This practice is unavailable."
	elif learned:
		reason = "You have already learned this practice."
	elif required != "" and not has_upgrade(required):
		reason = "Learn %s first." % required_name
	elif marks < 1:
		reason = "You need one unspent Oath Mark."
	var available: bool = reason == ""
	return {"id": id, "title": str(definition.get("name", id)), "body": str(definition.get("description", "")), "learned": learned, "available": available, "reason": reason, "cost": 1, "marks_after": marks - 1 if available else marks, "prerequisite_id": required, "prerequisite_name": required_name}

func unlock(id: String) -> bool:
	var result: Dictionary = unlock_result(id)
	message.emit(str(result.get("message", "")))
	return bool(result.get("ok", false))

func unlock_result(id: String) -> Dictionary:
	var status: Dictionary = upgrade_status(id)
	if not bool(status.get("available", false)):
		return {"ok": false, "operation": "learn", "item_id": id, "quantity": 0, "spent": {}, "remaining": {"marks": marks}, "reason": str(status.reason), "message": str(status.reason)}
	unlocked[id] = true
	marks -= 1
	changed.emit()
	return {"ok": true, "operation": "learn", "item_id": id, "quantity": 1, "spent": {"marks": 1}, "remaining": {"marks": marks}, "reason": "", "message": "%s learned. %d Oath Marks remain." % [str(status.title), marks]}

func has_upgrade(id: String) -> bool:
	return bool(unlocked.get(id, false))

func effect_value(effect_id: String, fallback: float = 0.0) -> float:
	var result := fallback
	for id in unlocked:
		if not bool(unlocked[id]) or not definitions.has(id):
			continue
		var effects: Dictionary = definitions[id].get("effects", {})
		if effects.has(effect_id):
			result = float(effects[effect_id])
	return result

func ordered_upgrade_ids() -> Array[String]:
	var result: Array[String] = []
	for branch in BRANCH_ORDER:
		for tier in range(1, 4):
			for id in definitions:
				var definition: Dictionary = definitions[id]
				if str(definition.get("branch", "")) == branch and int(definition.get("tier", 0)) == tier:
					result.append(str(id))
	return result

func get_summary_text() -> String:
	var text := "OATH MARKS: %d  |  PRACTICES LEARNED: %d / %d\n" % [marks, _learned_count(), MASTERY_MARK_LIMIT]
	text += "Mastery: the first nine chapter milestones can teach every practice. Choose what helps now; no branch locks out another. The final oath gives no spare mark.\n"
	for branch in BRANCH_ORDER:
		text += "\n%s\n" % branch.capitalize()
		for id in ordered_upgrade_ids():
			var definition: Dictionary = definitions[id]
			if str(definition.get("branch", "")) != branch:
				continue
			var state := "[Learned]" if has_upgrade(id) else ("[Available]" if can_unlock(id) else "[Locked]")
			text += "%s %s — %s\n" % [state, definition.get("name", id), definition.get("description", "")]
	return text

func save_state() -> Dictionary:
	return {
		"marks": marks,
		"unlocked": unlocked.duplicate(true),
		"rewarded_quests": rewarded_quests.duplicate(true)
	}

func load_state(state: Dictionary) -> void:
	var saved_marks: Variant = state.get("marks", 0)
	marks = 0
	if typeof(saved_marks) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(saved_marks)) and float(saved_marks) == floorf(float(saved_marks)):
		marks = int(clampf(float(saved_marks), 0.0, 99.0))
	unlocked.clear()
	var loaded_unlocked: Dictionary = state.get("unlocked", {}) if typeof(state.get("unlocked", {})) == TYPE_DICTIONARY else {}
	for id in ordered_upgrade_ids():
		if not _saved_true(loaded_unlocked.get(id, false)):
			continue
		var required := str(definitions[id].get("requires", ""))
		if required == "" or bool(unlocked.get(required, false)):
			unlocked[id] = true
	rewarded_quests = {}
	var rewards: Variant = state.get("rewarded_quests", {})
	if typeof(rewards) == TYPE_DICTIONARY:
		for id in rewards:
			if typeof(id) == TYPE_STRING and _saved_true(rewards[id]):
				rewarded_quests[id] = true
	# Preserve all legacy practices; retire only marks that have no remaining use.
	marks = mini(marks, maxi(MASTERY_MARK_LIMIT - _learned_count(), 0))
	changed.emit()

func _learned_count() -> int:
	var count := 0
	for id in unlocked:
		if bool(unlocked[id]) and definitions.has(id):
			count += 1
	return count

func _saved_true(value: Variant) -> bool:
	return typeof(value) == TYPE_BOOL and value == true
