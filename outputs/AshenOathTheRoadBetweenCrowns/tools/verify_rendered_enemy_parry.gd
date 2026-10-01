extends "res://tools/capture_anim_003.gd"

const Enemy = preload("res://scripts/enemy_ai.gd")
var parry_count := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	await _warm_renderer()
	var stage := _create_stage()
	var player := PlayerController.new()
	stage.add_child(player)
	player.set_physics_process(false)
	player.position.z = -1.2
	player.rotation.y = PI
	player.can_control = true
	player.parried.connect(func(): parry_count += 1)
	var enemy := Enemy.new()
	stage.add_child(enemy)
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	enemy.setup("ghoulkin", definitions.ghoulkin, player)
	enemy.set_physics_process(false)
	await _frames(10)
	capture_camera.look_at_from_position(Vector3(3, 2, 3), Vector3(0, 1, -0.5))
	var before: float = player.health_component.health
	enemy.windup_time = enemy._windup_duration()
	enemy.pending_attack_time = enemy.windup_time
	enemy._start_attack_animation()
	enemy.attack_trace_start = enemy._attack_contact_point()
	for frame in range(15):
		player.parry_window = maxf(0.0, player.parry_window - 1.0 / 30.0)
		if frame == 6:
			Input.action_press("block")
			player._handle_combat_input()
		player._animate_visuals(1.0 / 30.0, Vector3.ZERO, false)
		enemy._tick_pending_attack(1.0 / 30.0)
		await process_frame
	var passed: bool = parry_count == 1 and player.health_component.health == before and enemy.stagger_time > 0.0
	passed = passed and not player.sword_sheathed
	passed = passed and player.animation_driver.current_state == "parry" and player.hurt_react_time == 0.0
	var enemy_hit_clip: StringName = enemy.animation_driver.get_clip_for_state("hit")
	var enemy_animation_player := enemy.animation_driver.get_animation_player() as AnimationPlayer
	passed = passed and enemy_hit_clip != StringName() and enemy_animation_player != null and enemy_animation_player.has_animation(enemy_hit_clip)
	print("PARRY ASSERTIONS ", JSON.stringify({
		"count": parry_count,
		"health_unchanged": player.health_component.health == before,
		"stagger": enemy.stagger_time,
		"sword_drawn": not player.sword_sheathed,
		"player_state": player.animation_driver.current_state,
		"hurt_react_time": player.hurt_react_time,
		"enemy_hit_clip": str(enemy_hit_clip),
	}))
	for reaction_frame in range(6):
		player._animate_visuals(1.0 / 30.0, Vector3.ZERO, false)
		await create_timer(1.0 / 30.0).timeout
	await RenderingServer.frame_post_draw
	var guard_segment: Dictionary = player.get_blade_world_segment()
	passed = passed and guard_segment.tip.y > guard_segment.base.y + 0.35
	passed = passed and (guard_segment.base - player.global_position).dot(-player.global_basis.z) > 0.15
	print("HELD GUARD ", guard_segment)
	var skeleton: Skeleton3D = player.sword_attachment.get_parent()
	passed = passed and player.sword_grip_pose_applied and player.sword_grip_applied_rotations.size() == 10
	print("GUARD ASSERTIONS ", JSON.stringify({
		"tip_rise": guard_segment.tip.y - guard_segment.base.y,
		"base_forward": (guard_segment.base - player.global_position).dot(-player.global_basis.z),
		"grip_applied": player.sword_grip_pose_applied,
		"grip_bones": player.sword_grip_applied_rotations.size(),
		"skeleton_present": skeleton != null,
	}))
	for node in enemy.visual_root.find_children("*", "MeshInstance3D", true, false):
		if node.skin != null:
			var baked: ArrayMesh = node.bake_mesh_from_current_skeleton_pose()
			var cpu: AABB = enemy._posed_mesh_bounds(node)
			passed = passed and cpu.position.distance_to(baked.get_aabb().position) < 0.001 and cpu.size.distance_to(baked.get_aabb().size) < 0.001
			passed = passed and absf((node.global_transform * baked.get_aabb()).position.y) < 0.05
			print("GROUND BOUNDS static=", node.global_transform * node.mesh.get_aabb(), " posed=", node.global_transform * baked.get_aabb(), " position_delta=", cpu.position.distance_to(baked.get_aabb().position), " size_delta=", cpu.size.distance_to(baked.get_aabb().size), " floor_y=", (node.global_transform * baked.get_aabb()).position.y)
	var path := "D:/Temp/AshenOath/enemy_parry_%s.png" % int(Time.get_unix_time_from_system())
	root.get_texture().get_image().save_png(path)
	print("PARRY IMAGE ", path)
	print("PARRY RESULT count=", parry_count, " health=", player.health_component.health, " before=", before, " stagger=", enemy.stagger_time)
	Input.action_release("block")
	player._update_sword_equipment_pose(0.0, 0.2, 0.0, false, true)
	passed = passed and not player.guard_arm_applied
	for excluded in ["control", "transition", "sheathed", "casting", "bow"]:
		player.can_control = true
		player.transition_locked = false
		player.sword_sheathed = false
		player.beam_cast_state = ""
		player.weapon_mode = "sword"
		player.parry_window = 0.2
		player._update_sword_equipment_pose(0.0, 0.0, 0.0, false, false)
		passed = passed and player.guard_arm_applied
		match excluded:
			"control": player.can_control = false
			"transition": player.transition_locked = true
			"sheathed": player.sword_sheathed = true
			"casting": player.beam_cast_state = "charging"
			"bow": player.weapon_mode = "bow"
		player._update_sword_equipment_pose(0.0, 0.0, 0.0, false, false)
		passed = passed and not player.guard_arm_applied
		var grip_released := not player.sword_grip_pose_applied and player.sword_grip_applied_rotations.is_empty()
		passed = passed and grip_released
		print("GUARD RELEASE ", excluded, " cleared=", not player.guard_arm_applied)
		print("GRIP RELEASE ", excluded, " cleared=", grip_released)
	player.asset_helper.clear_runtime_caches()
	enemy.asset_helper.clear_runtime_caches()
	stage.queue_free()
	await _frames(6)
	print("RENDERED ENEMY PARRY: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
