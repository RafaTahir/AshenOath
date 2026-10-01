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
	if not is_finite(amount) or amount < 0.0:
		return false
	if amount == 0.0:
		return true
	if stamina < amount:
		return false
	stamina -= amount
	cooldown = regen_delay
	changed.emit(stamina, max_stamina)
	return true

func restore(amount: float) -> void:
	if not is_finite(amount) or amount <= 0.0:
		return
	stamina = min(stamina + amount, max_stamina)
	changed.emit(stamina, max_stamina)

func save_state() -> Dictionary:
	return {"stamina": stamina, "max_stamina": max_stamina}

func load_state(state: Dictionary) -> void:
	var maximum: Variant = state.get("max_stamina", max_stamina)
	if _finite_number(maximum) and float(maximum) > 0.0:
		max_stamina = float(maximum)
	var current: Variant = state.get("stamina", max_stamina)
	stamina = clampf(float(current), 0.0, max_stamina) if _finite_number(current) else max_stamina
	cooldown = 0.0
	changed.emit(stamina, max_stamina)

func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
