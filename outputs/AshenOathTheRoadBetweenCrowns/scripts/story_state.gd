extends Node

signal changed

const VERSION := 1
const VALUE_LIMITS := {
	"anwen_trust": Vector2i(-3, 3),
	"greyfen_fear": Vector2i(0, 6),
	"hart_debt": Vector2i(-3, 6)
}

var flags: Dictionary = {}
var values: Dictionary = {"anwen_trust": 0, "greyfen_fear": 0, "hart_debt": 0}

func set_flag(id: String, value: Variant) -> void:
	flags[id] = value
	changed.emit()

func get_flag(id: String, fallback: Variant = null) -> Variant:
	return flags.get(id, fallback)

func adjust_value(id: String, amount: int) -> int:
	var limit: Vector2i = VALUE_LIMITS.get(id, Vector2i(-999, 999))
	values[id] = clampi(int(values.get(id, 0)) + amount, limit.x, limit.y)
	changed.emit()
	return int(values[id])

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
	return {"version": VERSION, "flags": flags.duplicate(true), "values": values.duplicate(true)}

func load_state(data: Dictionary) -> void:
	flags = data.get("flags", {}).duplicate(true)
	var loaded: Dictionary = data.get("values", {})
	values = {"anwen_trust": 0, "greyfen_fear": 0, "hart_debt": 0}
	for id in loaded:
		var limit: Vector2i = VALUE_LIMITS.get(id, Vector2i(-999, 999))
		values[id] = clampi(int(loaded[id]), limit.x, limit.y)
	changed.emit()
