class_name ReplayRunner
extends RefCounted

const Clock = preload("res://scripts/core/sim_clock.gd")
const Frame = preload("res://scripts/core/input_frame.gd")
const Rng = preload("res://scripts/core/seeded_rng.gd")
const Events = preload("res://scripts/core/sim_event_bus.gd")
const Model = preload("res://scripts/core/deterministic_model.gd")
const Canonical = preload("res://scripts/core/canonical_state.gd")

var elapsed_ms: float = 0.0

func run(model: Model, frames: Array[Frame], seed_value: int) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var rng: Rng = Rng.new(seed_value)
	var events: Events = Events.new()
	var emitted: Array[Dictionary] = []
	var previous_tick: int = -1
	for frame: Frame in frames:
		if frame.tick != previous_tick + 1:
			elapsed_ms = (Time.get_ticks_usec() - started) / 1000.0
			return {"ok": false, "error": "Input ticks must be contiguous and start at zero."}
		model.step(frame, Clock.TICK_DT, rng, events)
		emitted.append_array(events.drain_events())
		previous_tick = frame.tick
	var state: Dictionary = {"ruleset_version": Clock.RULESET_VERSION, "tick": previous_tick + 1,
		"rng_seed": rng.get_seed(), "rng_state": rng.get_state(), "model": model.save_state()}
	var digest: String = Canonical.digest(state)
	elapsed_ms = (Time.get_ticks_usec() - started) / 1000.0
	return {"ok": not digest.is_empty(), "state": state, "digest": digest,
		"events": emitted, "elapsed_ms": elapsed_ms}
