extends Node

signal changed
signal message(text: String)

const DEFINITIONS_PATH := "res://data/upgrades.json"
const BRANCH_ORDER := ["blade", "survival", "oathfire"]

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
	marks += 1
	message.emit("Oath Mark earned. Choose an upgrade in the journal.")
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
		marks += 1
		awarded += 1
	if awarded > 0:
		changed.emit()
	return awarded

func can_unlock(id: String) -> bool:
	if marks <= 0 or not definitions.has(id) or bool(unlocked.get(id, false)):
		return false
	var required := str(definitions[id].get("requires", ""))
	return required == "" or bool(unlocked.get(required, false))

func unlock(id: String) -> bool:
	if not can_unlock(id):
		return false
	unlocked[id] = true
	marks -= 1
	message.emit("%s learned." % definitions[id].get("name", id))
	changed.emit()
	return true

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
	var text := "OATH MARKS: %d\n" % marks
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
	marks = clampi(int(state.get("marks", 0)), 0, 99)
	unlocked.clear()
	var loaded_unlocked: Dictionary = state.get("unlocked", {}) if typeof(state.get("unlocked", {})) == TYPE_DICTIONARY else {}
	for id in ordered_upgrade_ids():
		if not bool(loaded_unlocked.get(id, false)):
			continue
		var required := str(definitions[id].get("requires", ""))
		if required == "" or bool(unlocked.get(required, false)):
			unlocked[id] = true
	rewarded_quests = state.get("rewarded_quests", {}).duplicate(true) if typeof(state.get("rewarded_quests", {})) == TYPE_DICTIONARY else {}
	changed.emit()
