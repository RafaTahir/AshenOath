extends SceneTree

const PlayerController = preload("res://scripts/player_controller.gd")

var failures := 0

func _initialize() -> void:
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
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
