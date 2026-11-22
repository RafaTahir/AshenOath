extends SceneTree

const PlayerController = preload("res://scripts/player_controller.gd")
const CombatManager = preload("res://scripts/combat_manager.gd")

class ArrowTarget extends Node3D:
	var dead := false
	var display_name := "Rootbound aim fixture"
	var damage_received := 0.0
	func apply_damage(amount: float, _source: String) -> void:
		damage_received += amount

var failures := 0

func _initialize() -> void:
	if "--locked-bow-only" in OS.get_cmdline_user_args():
		await _check_locked_bow()
		quit(0 if failures == 0 else 1)
		return
	var player = PlayerController.new()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.set_physics_process(false)
	root.add_child(player)
	await process_frame
	check(is_equal_approx(player.get_parry_window_duration(), 0.30), "Parry window is not low-FPS readable")
	check(is_equal_approx(player.get_attack_buffer_duration(), 0.18), "Attack input buffer is missing")
	var state := {"contacts": 0}
	player.blade_contact_requested.connect(func(_contact): state.contacts = int(state.contacts) + 1)
	player.can_control = true
	player.equipment_loadout.set_sword_drawn(true)
	check(player.is_blade_ready(), "Contact fixture requires a drawn, fully bound blade")
	player.attack_anim_time = 0.0
	player.pending_attack_damage = 24.0
	player.pending_attack_radius = 2.0
	player.pending_attack_heavy = false
	player.attack_contact_emitted = false
	player.call("_update_blade_contact")
	check(int(state.contacts) == 1, "A long frame still skips player blade contact")
	player.call("_update_blade_contact")
	check(int(state.contacts) == 1, "One swing emitted duplicate contacts")
	var tuning = JSON.parse_string(FileAccess.get_file_as_string("res://combat_tuning.json"))
	check(typeof(tuning) == TYPE_DICTIONARY, "Combat tuning contract is invalid")
	check(bool(tuning.low_fps_contract.blade_contact_uses_threshold_crossing), "Low-FPS blade contract is disabled")
	check(int(tuning.enemy.maximum_simultaneous_attackers) == 1, "Pack attack-token balance changed")
	print("COMBAT-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	player.free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _check_locked_bow() -> void:
	var target := ArrowTarget.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 4.10
	capsule.radius = 1.05
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5 + capsule.radius * 0.18
	target.add_child(shape)
	root.add_child(target)
	target.position = Vector3(0, 0, -10.5)
	var bounds := preload("res://scripts/character_role_spec.gd").encounter_camera_bounds("rootbound_colossus_boss")
	target.set_meta("camera_subject_bounds", bounds)
	var combat := CombatManager.new()
	root.add_child(combat)
	await process_frame
	var origin := Vector3(7, 1.3, -11)
	var old_direction := (target.global_transform * bounds.get_center() - origin).normalized()
	var old_shot := combat.resolve_arrow_shot([target], {"origin": origin,
		"endpoint": origin + old_direction * 24, "direction": old_direction, "width": 0.34, "damage": 28})
	check(not bool(old_shot.hit), "Observed visual-centre miss was not reproduced")
	var point := PlayerController.locked_bow_aim_point(target)
	check(point.is_equal_approx(shape.global_position), "Lock does not aim at the existing damage capsule")
	for side in [Vector3(7, 1.3, -11), Vector3(-7, 1.3, -11), Vector3(0, 1.3, -3)]:
		var direction: Vector3 = (point - side).normalized()
		var shot := combat.resolve_arrow_shot([target], {"origin": side,
			"endpoint": side + direction * 24, "direction": direction, "width": 0.34, "damage": 28})
		check(bool(shot.hit), "Locked arrow missed Rootbound's capsule from %s" % side)
	check(is_equal_approx(target.damage_received, 84), "Arrow damage or hit count changed")
	target.queue_free()
	combat.queue_free()
	await process_frame
	print("LOCKED BOW CAPSULE VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL"))

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
