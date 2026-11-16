class_name DeterministicModel
extends RefCounted

const Frame = preload("res://scripts/core/input_frame.gd")
const Rng = preload("res://scripts/core/seeded_rng.gd")
const Events = preload("res://scripts/core/sim_event_bus.gd")

func step(_frame: Frame, _delta: float, _rng: Rng, _events: Events) -> void:
	pass

func save_state() -> Dictionary:
	return {}
