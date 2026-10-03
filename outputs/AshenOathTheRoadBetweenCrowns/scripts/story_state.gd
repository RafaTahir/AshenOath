extends Node

signal changed

const VERSION := 2
const VALUE_LIMITS := {
	"anwen_trust": Vector2i(-3, 3),
	"greyfen_fear": Vector2i(0, 6),
	"hart_debt": Vector2i(-3, 6)
}

var flags: Dictionary = {}
var values: Dictionary = {"anwen_trust": 0, "greyfen_fear": 0, "hart_debt": 0}
var evidence: Dictionary = {}
var decisions: Array = []
var _change_depth := 0
var _change_pending := false

func begin_change() -> void:
	_change_depth += 1

func end_change() -> void:
	_change_depth = maxi(0, _change_depth - 1)
	if _change_depth == 0 and _change_pending:
		_change_pending = false
		changed.emit()

func _notify_change() -> void:
	if _change_depth > 0:
		_change_pending = true
	else:
		changed.emit()

func set_flag(id: String, value: Variant) -> void:
	flags[id] = value
	_notify_change()

func get_flag(id: String, fallback: Variant = null) -> Variant:
	return flags.get(id, fallback)

func adjust_value(id: String, amount: int) -> int:
	var limit: Vector2i = VALUE_LIMITS.get(id, Vector2i(-999, 999))
	values[id] = clampi(int(values.get(id, 0)) + amount, limit.x, limit.y)
	_notify_change()
	return int(values[id])

func record_evidence(id: String, entry: Dictionary = {}) -> void:
	if id == "" or evidence.has(id):
		return
	evidence[id] = entry.duplicate(true)
	_notify_change()

func has_evidence(id: String) -> bool:
	return evidence.has(id)

func record_decision(id: String, action: Dictionary) -> void:
	if id == "":
		return
	for previous in decisions:
		if str(previous.get("id", "")) == id:
			return
	decisions.append({
		"id": id, "label": str(action.get("label", "A promise made")),
		"result": str(action.get("result", "")),
		"flags": action.get("sets_flags", {}).duplicate(true),
		"sequence": decisions.size() + 1
	})
	_notify_change()

func matches(conditions: Dictionary) -> bool:
	for id in conditions:
		var expected: Variant = conditions[id]
		if id in VALUE_LIMITS:
			var actual := int(values.get(id, 0))
			if expected is Dictionary:
				if expected.has("min") and actual < int(expected["min"]): return false
				if expected.has("max") and actual > int(expected["max"]): return false
			elif actual != int(expected): return false
		elif flags.get(id, false if expected is bool else null) != expected:
			return false
	return true

func save_state() -> Dictionary:
	return {"version": VERSION, "flags": flags.duplicate(true), "values": values.duplicate(true), "evidence": evidence.duplicate(true), "decisions": decisions.duplicate(true)}

func load_state(data: Dictionary) -> void:
	_change_depth = 0
	_change_pending = false
	var loaded_evidence: Variant = data.get("evidence", {})
	evidence = loaded_evidence.duplicate(true) if loaded_evidence is Dictionary else {}
	decisions = []
	var loaded_decisions: Variant = data.get("decisions", [])
	if loaded_decisions is Array:
		for decision in loaded_decisions:
			if decision is Dictionary and str(decision.get("id", "")) != "":
				decisions.append(decision.duplicate(true))
	var loaded_flags: Variant = data.get("flags", {})
	flags = loaded_flags.duplicate(true) if typeof(loaded_flags) == TYPE_DICTIONARY else {}
	var loaded_values_raw: Variant = data.get("values", {})
	var loaded: Dictionary = loaded_values_raw if typeof(loaded_values_raw) == TYPE_DICTIONARY else {}
	values = {"anwen_trust": 0, "greyfen_fear": 0, "hart_debt": 0}
	for id in loaded:
		if typeof(loaded[id]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(loaded[id])):
			continue
		var limit: Vector2i = VALUE_LIMITS.get(id, Vector2i(-999, 999))
		values[id] = clampi(int(loaded[id]), limit.x, limit.y)
	changed.emit()
