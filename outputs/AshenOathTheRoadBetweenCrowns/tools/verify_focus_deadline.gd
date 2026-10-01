extends "res://tools/verify_opening_real_input_native.gd"

class InteractionFixture extends Node:
	var interaction_id := "deadline_target"

class GameFixture extends Node:
	var player := Node3D.new()
	var active_interactable := InteractionFixture.new()
	var interaction_input_block_until_usec := 0
	var valid := true
	var arm_late_arrival := false
	func _ready() -> void:
		add_child(player)
		add_child(active_interactable)
	func _interaction_target_valid(_target: Node) -> bool:
		return valid
	func _process(_delta: float) -> void:
		if arm_late_arrival:
			arm_late_arrival = false
			OS.delay_msec(25)
			valid = true

func _initialize() -> void:
	call_deferred("_run_focus_deadlines")

func _run_focus_deadlines() -> void:
	var fixture := GameFixture.new()
	root.add_child(fixture)
	await process_frame
	var timely := await _await_focused_interaction(fixture, "deadline_target", "timely", 1000)
	var clean_timely := timely and failures.is_empty()
	var expired := await _await_focused_interaction(fixture, "deadline_target", "expired", 0)
	var expired_rejected := not expired and failures.size() == 1
	failures.clear()
	fixture.valid = false
	fixture.arm_late_arrival = true
	var late := await _await_focused_interaction(fixture, "deadline_target", "late", 10)
	var late_rejected := not late and fixture.valid and failures.size() == 1
	failures.clear()
	var wrong := await _await_focused_interaction(fixture, "different_target", "wrong_target", 10)
	var wrong_rejected := not wrong and failures.size() == 1
	failures.clear()
	fixture.interaction_input_block_until_usec = Time.get_ticks_usec() + 1000000
	var blocked := await _await_focused_interaction(fixture, "deadline_target", "cooldown", 10)
	var cooldown_rejected := not blocked and failures.size() == 1
	failures.clear()
	fixture.queue_free()
	await process_frame
	await process_frame
	var passed := clean_timely and expired_rejected and late_rejected and wrong_rejected and cooldown_rejected
	print("FOCUS DEADLINE: %s timely=%s expired_rejected=%s late_rejected=%s wrong_rejected=%s cooldown_rejected=%s" % ["PASS" if passed else "FAIL", clean_timely, expired_rejected, late_rejected, wrong_rejected, cooldown_rejected])
	quit(0 if passed else 1)

func _fail(message: String) -> void:
	# Negative fixture cases are asserted, not reported as game errors.
	failures.append(message)
