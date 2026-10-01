extends "res://tools/verify_opening_real_input_native.gd"

class InputFixture extends Node:
	func movement_vector() -> Vector2:
		return Vector2.ZERO

class CameraFixture extends Node:
	var yaw := 0.0

class HudFixture extends Node:
	var dialogue_layer := Control.new()
	func _ready() -> void:
		add_child(dialogue_layer)
		dialogue_layer.hide()

class PlayerFixture extends CharacterBody3D:
	var can_control := true
	var transition_locked := false

class GameFixture extends Node3D:
	var player := PlayerFixture.new()
	var input_router := InputFixture.new()
	var camera_rig := CameraFixture.new()
	var hud := HudFixture.new()
	var current_zone_id := "deadline_fixture"
	var zone_transition_pending := false
	var active_interactable: Node = null
	func _ready() -> void:
		add_child(player)
		add_child(input_router)
		add_child(camera_rig)
		add_child(hud)

var cleanup_arrival := false

func _initialize() -> void:
	call_deferred("_run_deadline_checks")

func _run_deadline_checks() -> void:
	var fixture := GameFixture.new()
	root.add_child(fixture)
	await physics_frame
	await _move_until(fixture, KEY_W, "expired_even_if_at_target", func(_p: Vector3) -> bool: return true, 0)
	var expired_rejected := failures.size() == 1
	failures.clear()
	cleanup_arrival = false
	await _move_until(fixture, KEY_W, "arrival_only_in_cleanup", func(_p: Vector3) -> bool: return cleanup_arrival, 0)
	var cleanup_rejected := failures.size() == 1 and cleanup_arrival
	failures.clear()
	await _move_until(fixture, KEY_W, "arrival_before_deadline", func(_p: Vector3) -> bool: return true, 1000)
	var timely_accepted := failures.is_empty()
	fixture.queue_free()
	await process_frame
	await process_frame
	var passed := expired_rejected and cleanup_rejected and timely_accepted
	print("ROUTE DEADLINE: %s expired_rejected=%s cleanup_rejected=%s timely_accepted=%s" % ["PASS" if passed else "FAIL", expired_rejected, cleanup_rejected, timely_accepted])
	quit(0 if passed else 1)

func _frames(count: int) -> void:
	# Reproduce the old false-positive window after movement has already ended.
	cleanup_arrival = true
	for _index in range(count):
		await process_frame

func _fail(message: String) -> void:
	# Expected negative cases are asserted above rather than emitted as errors.
	failures.append(message)
