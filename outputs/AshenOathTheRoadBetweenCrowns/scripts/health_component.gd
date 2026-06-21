extends Node

signal changed(current: float, maximum: float)
signal died

var max_health: float = 100.0
var health: float = 100.0
var dead = false

func configure(value: float) -> void:
	max_health = value
	health = value
	dead = false
	changed.emit(health, max_health)

func damage(amount: float) -> void:
	if dead:
		return
	health = max(health - amount, 0.0)
	changed.emit(health, max_health)
	if health <= 0.0:
		dead = true
		died.emit()

func heal(amount: float) -> void:
	if dead:
		return
	health = min(health + amount, max_health)
	changed.emit(health, max_health)

func save_state() -> Dictionary:
	return {"health": health, "max_health": max_health, "dead": dead}

func load_state(state: Dictionary) -> void:
	max_health = float(state.get("max_health", max_health))
	health = float(state.get("health", max_health))
	dead = bool(state.get("dead", false))
	changed.emit(health, max_health)
