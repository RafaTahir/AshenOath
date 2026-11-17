class_name BowAimReleaseModel
extends RefCounted

const Frame = preload("res://scripts/core/input_frame.gd")
const Ammo = preload("res://scripts/models/ammo_loadout_model.gd")
const Events = preload("res://scripts/core/sim_event_bus.gd")
const AIM: int = 1 << 8
const FIRE: int = 1 << 9
const CANCEL: int = 1 << 10
const DODGE: int = 1 << 3
const MIN_DRAW: float = 0.08
var state: String = "idle"
var draw_time: float = 0.0
var recovery: float = 0.0
var draw_duration: float = 1.0
var recovery_duration: float = 0.24
var hold_drain: float = 0.0
var stamina: float = 100.0
var training: bool = false
var clearance: bool = true
var release_allowed: bool = true
var previous_buttons: int = 0
var active_family: String = "standard_arrow"
var requires_release: bool = false

func cancel(require_release: bool = true) -> void:
	state = "idle"
	draw_time = 0.0
	requires_release = require_release

func tension() -> float:
	return clampf(draw_time / maxf(draw_duration, MIN_DRAW), 0.0, 1.0)

func movement_multiplier() -> float:
	return 0.42 if state in ["aiming", "drawing"] else 1.0

static func release_values(ratio: float, effect: Dictionary = {}) -> Dictionary:
	var charge: float = clampf(ratio, 0.0, 1.0)
	return {"charge_ratio": charge, "spread": lerpf(0.035, 0.002, charge),
		"speed": maxf(1.0, float(effect.get("velocity", 28.0))) * lerpf(0.65, 1.0, charge),
		"damage_mult": lerpf(0.65, 1.0, charge)}

func step(frame: Frame, delta: float, ammo: Ammo, events: Events, effect: Dictionary = {}) -> void:
	var buttons: int = frame.buttons
	var pressed: int = buttons & ~previous_buttons
	var released: int = previous_buttons & ~buttons
	previous_buttons = buttons
	recovery = maxf(0.0, recovery - delta)
	if buttons & FIRE == 0:
		requires_release = false
	var family: String = Ammo.FAMILY_IDS[clampi(frame.selected_slot, 0, Ammo.FAMILY_IDS.size() - 1)]
	if family != active_family:
		var was_drawing: bool = state == "drawing"
		active_family = family
		ammo.selected_family = family
		cancel(was_drawing and buttons & FIRE != 0)
	if buttons & (CANCEL | DODGE) != 0:
		cancel(buttons & FIRE != 0)
		return
	if not release_allowed or recovery > 0.0 or requires_release:
		return
	if pressed & FIRE != 0 and not training and ammo.count(active_family) == 0:
		events.emit_event(frame.tick, "arrow_unavailable", {"arrow_family_id": active_family})
		cancel(true)
		return
	if buttons & FIRE != 0:
		state = "drawing"
		draw_time = minf(draw_time + delta, maxf(MIN_DRAW, draw_duration))
		if hold_drain > 0.0 and draw_time >= draw_duration:
			var cost: float = hold_drain * delta
			if stamina < cost:
				events.emit_event(frame.tick, "stamina_exhausted", {"action": "bow"})
				cancel(true)
				return
			stamina -= cost
	elif released & FIRE != 0 and state == "drawing":
		if clearance:
			var ratio: float = tension() if buttons & AIM != 0 else maxf(0.0, tension())
			release(frame.tick, ammo, events, effect, ratio)
		else:
			events.emit_event(frame.tick, "bow_obstructed")
		cancel(false)
	elif buttons & AIM != 0:
		state = "aiming"
	else:
		cancel(false)

func release(tick: int, ammo: Ammo, events: Events, effect: Dictionary, ratio: float) -> bool:
	if not clearance or not release_allowed:
		return false
	if not training and not ammo.consume(active_family):
		events.emit_event(tick, "arrow_unavailable", {"arrow_family_id": active_family})
		return false
	var payload: Dictionary = release_values(ratio, effect)
	payload["arrow_family_id"] = active_family
	payload["training"] = training
	events.emit_event(tick, "arrow_released", payload)
	recovery = recovery_duration
	return true

func save_state() -> Dictionary:
	return {"state": state, "draw_time": draw_time, "recovery": recovery,
		"stamina": stamina, "previous_buttons": previous_buttons, "active_family": active_family,
		"requires_release": requires_release}
