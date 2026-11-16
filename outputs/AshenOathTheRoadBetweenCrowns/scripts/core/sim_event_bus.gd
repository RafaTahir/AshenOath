class_name SimEventBus
extends RefCounted

class Event extends RefCounted:
	var tick: int
	var kind: String
	var payload: Dictionary

	func _init(event_tick: int, event_kind: String, event_payload: Dictionary = {}) -> void:
		tick = event_tick
		kind = event_kind
		payload = event_payload.duplicate(true)

	func to_dict() -> Dictionary:
		return {"tick": tick, "kind": kind, "payload": payload.duplicate(true)}

var _events: Array[Event] = []

func push(event: Event) -> void:
	_events.append(Event.new(event.tick, event.kind, event.payload))

func emit_event(tick: int, kind: String, payload: Dictionary = {}) -> void:
	push(Event.new(tick, kind, payload))

func drain_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Event in _events:
		result.append(event.to_dict())
	_events.clear()
	return result
