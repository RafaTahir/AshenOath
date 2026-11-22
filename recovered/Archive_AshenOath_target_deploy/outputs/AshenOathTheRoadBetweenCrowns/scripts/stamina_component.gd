extends Node

signal changed(current: float, maximum: float)

var max_stamina: float = 100.0
var stamina: float = 100.0
var regen_rate: float = 24.0
var regen_delay: float = 0.8
var cooldown: float = 0.0

func _process(delta: float) -> void:
	if cooldown > 0.0:
		cooldown -= delta
		return
	if stamina < max_stamina:
		stamina = min(stamina + regen_rate * delta, max_stamina)
		changed.emit(stamina, max_stamina)

func spend(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	cooldown = regen_delay
	changed.emit(stamina, max_stamina)
	return true

func restore(amount: float) -> void:
	stamina = min(stamina + amount, max_stamina)
	changed.emit(stamina, max_stamina)

func save_state() -> Dictionary:
	return {"stamina": stamina, "max_stamina": max_stamina}

func load_state(state: Dictionary) -> void:
	max_stamina = float(state.get("max_stamina", max_stamina))
	stamina = float(state.get("stamina", max_stamina))
	changed.emit(stamina, max_stamina)
