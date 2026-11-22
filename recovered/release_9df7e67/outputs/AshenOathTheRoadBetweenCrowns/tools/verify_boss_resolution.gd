extends SceneTree

const Controller = preload("res://scripts/boss_encounter.gd")
class Actor extends Node:
	signal died(actor)
	signal boss_phase_changed(actor, phase)
	var dead := false
	var encounter_active := true
	var health_component: Node
	func set_encounter_active(value: bool) -> void:
		encounter_active = value

var failures := 0
var resolutions := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor := Actor.new()
	root.add_child(actor)
	actor.health_component = preload("res://scripts/health_component.gd").new()
	actor.add_child(actor.health_component)
	actor.health_component.configure(200.0)
	var controller := Controller.new()
	actor.add_child(controller)
	controller.configure("fixture", {"peaceful_resolution":true, "phases":[{"health_ratio":1.0},{"health_ratio":0.66}]}, actor, null)
	controller.resolved.connect(func(_id, _outcome): resolutions += 1)
	for value in [null, "two", {}, [], true, NAN, INF, 1.5]:
		controller.load_state({"phase": value, "checkpoint": value, "checkpoint_health_ratio": value})
		check(controller.phase == 1 and controller.checkpoint == 1, "Malformed phase must preserve valid fallback")
		check(is_finite(controller.checkpoint_health_ratio), "Malformed ratio must not propagate nonfinite health")
	controller.load_state({"phase": 1e30, "checkpoint": 1e30})
	check(controller.phase == 2 and controller.checkpoint == 2, "Phase must stay inside authored range")
	controller.load_state({"phase": 1, "checkpoint": 1})
	for invalid in ["", "pending", "defeated"]:
		check(not controller.resolve_peaceful(invalid), "Reserved outcome must be rejected")
	check(actor.encounter_active and resolutions == 0, "Rejected resolution must not mutate combat")
	check(controller.resolve_peaceful("witness"), "Valid peaceful resolution must succeed")
	check(not actor.encounter_active, "Resolution must stop combat without a host callback")
	check(not controller.resolve_peaceful("mercy"), "Resolved encounter must reject second outcome")
	actor.died.emit(actor)
	check(resolutions == 1 and controller.outcome == "witness", "Death must not overwrite or repeat peaceful resolution")
	var saved: Dictionary = controller.save_state()
	actor.encounter_active = true
	controller.load_state(saved)
	check(not actor.encounter_active and resolutions == 1, "Loading resolved state must suspend without re-emitting rewards")
	actor.free()
	await process_frame
	print("BOSS RESOLUTION: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
