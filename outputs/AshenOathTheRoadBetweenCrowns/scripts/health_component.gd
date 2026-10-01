extends Node

signal changed(current: float, maximum: float)
signal died

var max_health: float = 100.0
var health: float = 100.0
var dead = false

func configure(value: float) -> void:
	if not is_finite(value) or value <= 0.0:
		return
	max_health = value
	health = value
	dead = false
	changed.emit(health, max_health)

func damage(amount: float) -> void:
	if dead or not is_finite(amount) or amount <= 0.0:
		return
	health = max(health - amount, 0.0)
	changed.emit(health, max_health)
	if health <= 0.0:
		dead = true
		died.emit()

func heal(amount: float) -> void:
	if dead or not is_finite(amount) or amount <= 0.0:
		return
	health = min(health + amount, max_health)
	changed.emit(health, max_health)

func save_state() -> Dictionary:
	return {"health": health, "max_health": max_health, "dead": dead}

func load_state(state: Dictionary) -> void:
	var maximum: Variant = state.get("max_health", max_health)
	if _finite_number(maximum) and float(maximum) > 0.0:
		max_health = float(maximum)
	var current: Variant = state.get("health", max_health)
	health = clampf(float(current), 0.0, max_health) if _finite_number(current) else max_health
	dead = state.get("dead", false) == true if typeof(state.get("dead", false)) == TYPE_BOOL else false
	dead = dead or health <= 0.0
	if dead:
		health = 0.0
	changed.emit(health, max_health)

func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
