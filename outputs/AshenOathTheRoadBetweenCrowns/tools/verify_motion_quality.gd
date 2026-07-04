extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var scene = load("res://scenes/main.tscn")
	if scene == null:
		_fail("main scene failed to load")
		_finish()
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _settle_frames(4)
	var player = game.player
	_assert(player != null, "player failed to instantiate")
	if player == null:
		_finish()
		return
	_assert(InputMap.has_action("jump"), "jump input action is missing")
	_assert(player.has_method("_handle_movement"), "movement state handler is missing")
	_assert(player.has_method("try_jump"), "jump controller method is missing")
	_assert(player.has_method("_try_step_up"), "small-obstacle step-up hook is missing")
	_assert(player.has_method("_update_ground_adaptation"), "ground adaptation hook is missing")
	_assert(float(player.acceleration) < 30.0 and float(player.deceleration) < 30.0, "locomotion response is configured to snap")
	_assert(float(player.jump_speed) >= 7.0, "jump impulse is missing or too weak")
	_assert(float(player.floor_snap_length) >= 0.25, "floor snapping is not configured")
	for i in range(30):
		if player.is_on_floor():
			break
		await physics_frame
	_assert(player.is_on_floor(), "player did not settle onto the Greyfen floor before jump test")
	var jump_start = player.global_position
	var jump_started = bool(player.call("try_jump"))
	await physics_frame
	_assert(jump_started and (player.velocity.y > 0.0 or player.global_position.y > jump_start.y + 0.02), "jump controller did not launch the grounded player (started=%s control=%s floor=%s attack=%.2f dodge=%.2f beam=%s)" % [str(jump_started), str(player.can_control), str(player.is_on_floor()), float(player.attack_anim_time), float(player.dodge_time), str(player.beam_charging)])
	player.global_position = jump_start
	player.velocity = Vector3.ZERO
	await physics_frame

	var visual = player.visual_root
	var left_leg = player.left_leg_proxy
	var sword = player.weapon_root
	_assert(visual != null and left_leg != null, "visible locomotion proxies are missing")
	_assert(sword != null, "visible sword root is missing")
	if visual != null and left_leg != null:
		var idle_leg = left_leg.transform
		player.velocity = Vector3(0, 0, -5.0)
		player.movement_state = "run"
		player.move_phase = 0.4
		for i in range(8):
			player.call("_animate_visuals", 0.016, Vector3.FORWARD, true)
		_assert(_transform_delta(idle_leg, left_leg.transform) > 0.02, "run state does not visibly move the leg proxy")

		var run_root = visual.transform
		player.velocity = Vector3(3.0, 0, 0)
		player.movement_state = "strafe"
		for i in range(8):
			player.call("_animate_visuals", 0.016, Vector3.RIGHT, true)
		_assert(_transform_delta(run_root, visual.transform) > 0.01, "strafe state does not visibly alter body pose")

		player.jump_pose_weight = 1.0
		player.movement_state = "jump"
		player.velocity = Vector3(0, 5.0, -2.0)
		var ground_pose = visual.transform
		for i in range(5):
			player.call("_animate_visuals", 0.016, Vector3.FORWARD, true)
		_assert(_transform_delta(ground_pose, visual.transform) > 0.01, "jump pose is not visually distinct")

		player.jump_pose_weight = 0.0
		player.smoothed_ground_normal = Vector3(0.20, 0.96, 0.18).normalized()
		var flat_pose = visual.rotation
		for i in range(8):
			player.call("_animate_visuals", 0.016, Vector3.ZERO, false)
		_assert(flat_pose.distance_to(visual.rotation) > 0.005, "slope normal does not affect visible body grounding")

	if sword != null:
		var sword_before = sword.transform
		player.attack_anim_heavy = true
		player.attack_anim_time = 0.34
		for i in range(8):
			player.attack_anim_time = max(float(player.attack_anim_time) - 0.016, 0.0)
			player.call("_animate_visuals", 0.016, Vector3.ZERO, false)
		_assert(_transform_delta(sword_before, sword.transform) > 0.02, "sword attack animation stopped changing the visible sword")

	player.dodge_dir = Vector3.RIGHT
	player.dodge_time = 0.24
	player.movement_state = "dodge"
	var dodge_before = visual.transform
	for i in range(5):
		player.call("_animate_visuals", 0.016, Vector3.RIGHT, true)
	_assert(_transform_delta(dodge_before, visual.transform) > 0.01, "dodge pose is not visually distinct")

	game.queue_free()
	await process_frame
	_finish()

func _transform_delta(a: Transform3D, b: Transform3D) -> float:
	return a.origin.distance_to(b.origin) + a.basis.x.distance_to(b.basis.x) + a.basis.y.distance_to(b.basis.y) + a.basis.z.distance_to(b.basis.z)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _settle_frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _finish() -> void:
	if not failures.is_empty():
		print("motion quality verification failed:")
		for failure in failures:
			print("- %s" % failure)
		quit(1)
		return
	print("motion quality verification complete")
	quit()
