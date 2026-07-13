extends CharacterBody3D

signal attack_performed(damage: float, radius: float, heavy: bool)
signal potion_requested
signal bomb_requested
signal beam_requested(charge_ratio: float, direction: Vector3)
signal beam_phase_changed(phase: String)
signal footstep
signal parried
signal blocked(amount: float)
signal hurt(amount: float)
signal stamina_exhausted(action: String)
signal died

const HealthComponent = preload("res://scripts/health_component.gd")
const StaminaComponent = preload("res://scripts/stamina_component.gd")
const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterPresentation = preload("res://scripts/character_presentation.gd")
const CharacterAnimationDriver = preload("res://scripts/character_animation_driver.gd")

var walk_speed = 3.4
var run_speed = 5.3
var dodge_speed = 8.0
var gravity = 24.0
var jump_speed = 8.2
var acceleration = 17.0
var run_acceleration = 13.0
var deceleration = 21.0
var turn_speed = 11.0
var attack_cooldown = 0.0
var dodge_time = 0.0
var dodge_dir = Vector3.ZERO
var can_control = true
var camera_controller
var health_component
var stamina_component
var visual_root: Node3D
var body_visual: MeshInstance3D
var body_base_color := Color(0.24, 0.27, 0.25)
var weapon_root: Node3D
var sword_visual: MeshInstance3D
var sword_hilt_visual: MeshInstance3D
var sword_trail_visual: MeshInstance3D
var rig_sword_visual: Node3D
var slash_arc_root: Node3D
var slash_arc_primary: MeshInstance3D
var slash_arc_secondary: MeshInstance3D
var slash_arc_spark: MeshInstance3D
var left_arm_proxy: MeshInstance3D
var right_arm_proxy: MeshInstance3D
var left_leg_proxy: MeshInstance3D
var right_leg_proxy: MeshInstance3D
var cloak_motion_proxy: MeshInstance3D
var asset_helper
var animation_driver
var move_phase = 0.0
var step_phase = 0.0
var attack_anim_time = 0.0
var attack_anim_heavy = false
var pending_attack_time := 0.0
var pending_attack_damage := 0.0
var pending_attack_radius := 0.0
var pending_attack_heavy := false
var hurt_flash_time = 0.0
var hurt_react_time = 0.0
var parry_window = 0.0
var block_pose_weight = 0.0
var grounded_weight = 0.0
var beam_charging = false
var beam_charge_time = 0.0
var beam_cooldown = 0.0
var beam_charge_visual: MeshInstance3D
var beam_left_hand_glow: MeshInstance3D
var beam_right_hand_glow: MeshInstance3D
var sheathed_sword_visual: Node3D
var beam_cast_state := ""
var beam_state_time := 0.0
var beam_locked_direction := Vector3.ZERO
var movement_state = "idle"
var movement_blend = 0.0
var strafe_blend = 0.0
var backward_blend = 0.0
var jump_pose_weight = 0.0
var landing_compression = 0.0
var smoothed_ground_normal = Vector3.UP
var left_foot_ground_offset = 0.0
var right_foot_ground_offset = 0.0
var contact_shadow: Node3D
var was_on_floor = false
var step_up_cooldown = 0.0

func _ready() -> void:
	add_to_group("player")
	health_component = HealthComponent.new()
	stamina_component = StaminaComponent.new()
	add_child(health_component)
	add_child(stamina_component)
	health_component.configure(125.0)
	health_component.died.connect(_on_died)
	_build_body()
	floor_snap_length = 0.34
	floor_max_angle = deg_to_rad(48.0)
	max_slides = 6
	safe_margin = 0.035
	contact_shadow = find_child("CharacterContactShadow", true, false) as Node3D
	was_on_floor = is_on_floor()

func _physics_process(delta: float) -> void:
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	beam_cooldown = max(beam_cooldown - delta, 0.0)
	attack_anim_time = max(attack_anim_time - delta, 0.0)
	hurt_flash_time = max(hurt_flash_time - delta, 0.0)
	hurt_react_time = max(hurt_react_time - delta, 0.0)
	parry_window = max(parry_window - delta, 0.0)
	step_up_cooldown = max(step_up_cooldown - delta, 0.0)
	_update_beam_sequence(delta)
	_update_pending_attack(delta)
	if not can_control:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		_apply_gravity(delta)
		move_and_slide()
		_animate_visuals(delta, Vector3.ZERO, false)
		return
	_handle_combat_input()
	_handle_movement(delta)

func _handle_movement(delta: float) -> void:
	var input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward = Vector3.FORWARD
	var right = Vector3.RIGHT
	if camera_controller != null:
		forward = camera_controller.get_flat_forward()
		right = camera_controller.get_flat_right()
	var move_dir = (right * input_vec.x + forward * -input_vec.y).normalized()
	if dodge_time > 0.0:
		dodge_time -= delta
		var dodge_ratio = clamp(dodge_time / 0.30, 0.0, 1.0)
		var dodge_velocity = dodge_speed * (0.62 + 0.38 * sin(dodge_ratio * PI))
		velocity.x = dodge_dir.x * dodge_velocity
		velocity.z = dodge_dir.z * dodge_velocity
		movement_state = "dodge"
	else:
		var wants_run = Input.is_action_pressed("run") and input_vec.length() > 0.1
		var is_running = wants_run and stamina_component.spend(10.0 * delta)
		var speed = run_speed if is_running else walk_speed
		if input_vec.y > 0.15:
			speed *= 0.68
		if beam_charging:
			speed *= 0.4
		var target_velocity = move_dir * speed
		var response = run_acceleration if is_running else acceleration
		if move_dir.length() <= 0.1:
			response = deceleration
		velocity.x = move_toward(velocity.x, target_velocity.x, response * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, response * delta)
		if move_dir.length() > 0.1 and beam_cast_state == "":
			var target_yaw = atan2(-move_dir.x, -move_dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
		movement_state = "run" if is_running else ("backward" if input_vec.y > 0.15 else ("strafe" if abs(input_vec.x) > 0.55 else ("walk" if move_dir.length() > 0.1 else "idle")))
		if Input.is_action_just_pressed("jump"):
			try_jump()
		if Input.is_action_just_pressed("dodge") and not beam_charging:
			if stamina_component.spend(28.0):
				dodge_dir = move_dir if move_dir.length() > 0.1 else -global_transform.basis.z
				dodge_time = 0.30
			else:
				stamina_exhausted.emit("dodge")
	_try_step_up(move_dir)
	_apply_gravity(delta)
	move_and_slide()
	_update_ground_adaptation(delta)
	_animate_visuals(delta, move_dir, input_vec.length() > 0.1)

func try_jump() -> bool:
	if not can_control or not is_on_floor() or beam_charging or attack_anim_time > 0.0 or dodge_time > 0.0:
		return false
	velocity.y = jump_speed
	jump_pose_weight = 1.0
	movement_state = "jump"
	if animation_driver != null:
		animation_driver.trigger_action("jump")
	return true

func _try_step_up(move_dir: Vector3) -> void:
	if step_up_cooldown > 0.0 or move_dir.length() < 0.1 or not is_on_floor() or not is_on_wall():
		return
	var probe = global_position + move_dir * 0.46
	var query = PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 0.42, probe - Vector3.UP * 0.08)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var step_height = float(hit.position.y - global_position.y)
	if step_height > 0.04 and step_height <= 0.30 and not test_move(global_transform, Vector3.UP * (step_height + 0.035)):
		global_position.y += step_height + 0.035
		step_up_cooldown = 0.12

func _update_ground_adaptation(delta: float) -> void:
	var on_floor = is_on_floor()
	if on_floor and not was_on_floor:
		landing_compression = clamp(abs(velocity.y) / 9.0, 0.45, 1.0)
	jump_pose_weight = move_toward(jump_pose_weight, 0.0 if on_floor else 1.0, delta * (6.0 if on_floor else 3.0))
	landing_compression = move_toward(landing_compression, 0.0, delta * 5.5)
	var normal = get_floor_normal() if on_floor else Vector3.UP
	smoothed_ground_normal = smoothed_ground_normal.lerp(normal, 1.0 - exp(-9.0 * delta)).normalized()
	left_foot_ground_offset = _sample_foot_offset(-0.18, delta, left_foot_ground_offset) if on_floor else move_toward(left_foot_ground_offset, 0.0, delta * 3.0)
	right_foot_ground_offset = _sample_foot_offset(0.18, delta, right_foot_ground_offset) if on_floor else move_toward(right_foot_ground_offset, 0.0, delta * 3.0)
	if contact_shadow != null:
		contact_shadow.visible = global_position.y > -4.0
		var shadow_weight = 1.0 - clamp(abs(velocity.y) / 10.0, 0.0, 0.52)
		contact_shadow.scale = Vector3(0.95 * shadow_weight, 0.014, 0.66 * shadow_weight)
	was_on_floor = on_floor

func _sample_foot_offset(side: float, delta: float, current: float) -> float:
	var local_probe = global_transform.basis.x * side + global_transform.basis.z * 0.04
	var start = global_position + local_probe + Vector3.UP * 0.42
	var query = PhysicsRayQueryParameters3D.create(start, start - Vector3.UP * 0.72)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	var target = 0.0
	if not hit.is_empty():
		target = clamp(float(hit.position.y - global_position.y), -0.16, 0.16)
	return lerp(current, target, 1.0 - exp(-12.0 * delta))

func _handle_combat_input() -> void:
	_handle_beam_input()
	if beam_cast_state != "":
		return
	if attack_cooldown > 0.0:
		return
	if Input.is_action_just_pressed("light_attack"):
		attack_cooldown = 0.38
		attack_anim_time = 0.34
		attack_anim_heavy = false
		if animation_driver != null:
			animation_driver.trigger_action("attack_light")
		_queue_attack_hit(24.0,2.0,false,0.12)
	elif Input.is_action_just_pressed("heavy_attack"):
		if stamina_component.spend(22.0):
			attack_cooldown = 0.7
			attack_anim_time = 0.52
			attack_anim_heavy = true
			if animation_driver != null:
				animation_driver.trigger_action("attack_heavy")
			_queue_attack_hit(42.0,2.25,true,0.24)
		else:
			stamina_exhausted.emit("heavy attack")
	if Input.is_action_just_pressed("use_potion"):
		potion_requested.emit()
	if Input.is_action_just_pressed("throw_bomb"):
		bomb_requested.emit()
	if Input.is_action_just_pressed("block"):
		parry_window = 0.24
		if animation_driver != null:
			animation_driver.trigger_action("parry")

func _queue_attack_hit(damage: float, radius: float, heavy: bool, delay: float) -> void:
	pending_attack_damage = damage
	pending_attack_radius = radius
	pending_attack_heavy = heavy
	pending_attack_time = delay

func _update_pending_attack(delta: float) -> void:
	if pending_attack_time <= 0.0:
		return
	pending_attack_time -= delta
	if pending_attack_time <= 0.0 and can_control:
		attack_performed.emit(pending_attack_damage,pending_attack_radius,pending_attack_heavy)
		pending_attack_damage = 0.0
		pending_attack_radius = 0.0

func _handle_beam_input() -> void:
	if Input.is_action_just_pressed("oathfire_beam") and beam_cooldown <= 0.0 and beam_cast_state == "" and dodge_time <= 0.0:
		beam_cast_state = "sheathing"
		beam_phase_changed.emit("sheathing")
		beam_state_time = 0.24
		beam_charging = true
		beam_charge_time = 0.0
		_lock_beam_direction()
		_set_sword_sheathed(true)
	if beam_cast_state == "charging" and Input.is_action_pressed("oathfire_beam"):
		beam_charge_time = min(beam_charge_time + get_physics_process_delta_time(), 1.25)
		_update_beam_charge_visual()
	if beam_cast_state == "charging" and Input.is_action_just_released("oathfire_beam"):
		var ratio = clamp((beam_charge_time - 0.35) / 0.90, 0.0, 1.0)
		if beam_charge_time >= 0.35 and stamina_component.spend(40.0):
			var direction = beam_locked_direction
			if direction.length_squared() < 0.5:
				direction = -global_transform.basis.z.normalized()
			face_target(global_position + direction * 4.0)
			beam_requested.emit(ratio, direction)
			beam_cooldown = 4.0
			attack_cooldown = 0.75
			beam_charging = false
			beam_cast_state = "releasing"
			beam_phase_changed.emit("releasing")
			beam_state_time = 0.30
			_hide_beam_charge_visuals()
		elif beam_charge_time >= 0.35:
			stamina_exhausted.emit("Oathfire Beam")
			_begin_beam_redraw()
		else:
			_begin_beam_redraw()
	elif beam_cast_state == "sheathing" and Input.is_action_just_released("oathfire_beam"):
		_begin_beam_redraw()

func _update_beam_sequence(delta: float) -> void:
	if beam_cast_state == "":
		return
	beam_state_time = max(beam_state_time - delta, 0.0)
	if beam_cast_state == "sheathing" and beam_state_time <= 0.0:
		if Input.is_action_pressed("oathfire_beam"):
			beam_cast_state = "charging"
			beam_phase_changed.emit("charging")
			beam_state_time = 0.0
			if animation_driver != null:
				animation_driver.trigger_action("beam_cast")
			_update_beam_charge_visual()
		else:
			_begin_beam_redraw()
	elif beam_cast_state == "releasing" and beam_state_time <= 0.0:
		_begin_beam_redraw()
	elif beam_cast_state == "redrawing" and beam_state_time <= 0.0:
		beam_cast_state = ""
		beam_charging = false
		beam_charge_time = 0.0
		beam_locked_direction = Vector3.ZERO
		_set_sword_sheathed(false)

func _begin_beam_redraw() -> void:
	beam_charging = false
	beam_cast_state = "redrawing"
	beam_phase_changed.emit("redrawing")
	beam_state_time = 0.24
	_hide_beam_charge_visuals()

func cancel_beam_charge() -> void:
	beam_charging = false
	beam_charge_time = 0.0
	beam_cast_state = ""
	beam_phase_changed.emit("cancelled")
	beam_state_time = 0.0
	beam_locked_direction = Vector3.ZERO
	_hide_beam_charge_visuals()
	_set_sword_sheathed(false)

func _lock_beam_direction() -> Vector3:
	beam_locked_direction = -global_transform.basis.z
	beam_locked_direction.y = 0.0
	if beam_locked_direction.length_squared() < 0.5:
		beam_locked_direction = Vector3.FORWARD
	beam_locked_direction = beam_locked_direction.normalized()
	return beam_locked_direction

func get_beam_locked_direction() -> Vector3:
	return beam_locked_direction

func _update_beam_charge_visual() -> void:
	if beam_charge_visual == null:
		return
	beam_charge_visual.visible = true
	var ratio = clamp(beam_charge_time / 1.25, 0.0, 1.0)
	beam_charge_visual.scale = Vector3.ONE * lerp(0.12, 0.42, ratio)
	if beam_left_hand_glow != null:
		beam_left_hand_glow.visible = true
		beam_left_hand_glow.position = Vector3(lerp(-0.40, -0.16, ratio), lerp(1.16, 1.30, ratio), lerp(-0.34, -0.67, ratio))
	if beam_right_hand_glow != null:
		beam_right_hand_glow.visible = true
		beam_right_hand_glow.position = Vector3(lerp(0.40, 0.16, ratio), lerp(1.16, 1.30, ratio), lerp(-0.34, -0.67, ratio))

func _hide_beam_charge_visuals() -> void:
	for glow in [beam_charge_visual, beam_left_hand_glow, beam_right_hand_glow]:
		if glow != null:
			glow.visible = false

func _set_sword_sheathed(sheathed: bool) -> void:
	if weapon_root != null:
		weapon_root.visible = not sheathed
	if rig_sword_visual != null:
		rig_sword_visual.visible = not sheathed
	if sheathed_sword_visual != null:
		sheathed_sword_visual.visible = sheathed

func is_blocking() -> bool:
	return Input.is_action_pressed("block") and stamina_component.stamina > 8.0

func take_damage(amount: float) -> bool:
	if dodge_time > 0.0:
		return false
	if parry_window > 0.0 and stamina_component.spend(10.0):
		parry_window = 0.0
		hurt_flash_time = 0.08
		hurt_react_time = 0.14
		if animation_driver != null:
			animation_driver.trigger_action("hit")
		parried.emit()
		return true
	if is_blocking() and stamina_component.spend(12.0):
		var reduced = amount * 0.25
		health_component.damage(reduced)
		hurt_flash_time = 0.10
		hurt_react_time = 0.13
		if animation_driver != null:
			animation_driver.trigger_action("hit")
		blocked.emit(reduced)
	else:
		health_component.damage(amount)
		hurt_flash_time = 0.18
		hurt_react_time = 0.20
		if animation_driver != null:
			animation_driver.trigger_action("hit")
		hurt.emit(amount)
	return false

func face_target(target_pos: Vector3) -> void:
	var flat = Vector3(target_pos.x, global_position.y, target_pos.z)
	if flat.distance_to(global_position) > 0.1:
		look_at(flat, Vector3.UP)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y <= 0.0:
		velocity.y = -0.1

func _on_died() -> void:
	cancel_beam_charge()
	can_control = false
	if animation_driver != null:
		animation_driver.set_dead()
	died.emit()

func _build_body() -> void:
	visual_root = Node3D.new()
	add_child(visual_root)
	var collision = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.height = 1.65
	capsule_shape.radius = 0.32
	collision.shape = capsule_shape
	collision.position.y = 0.9
	add_child(collision)
	if _try_build_mapped_body():
		CharacterPresentation.apply_player(self, visual_root)
		_add_beam_charge_visual()
		return

	var cloak = MeshInstance3D.new()
	var cloak_mesh = BoxMesh.new()
	cloak_mesh.size = Vector3(0.74, 1.08, 0.18)
	cloak.mesh = cloak_mesh
	cloak.position = Vector3(0, 1.0, 0.22)
	cloak.rotation_degrees.x = -6
	cloak.material_override = _mat(Color(0.10, 0.11, 0.10))
	visual_root.add_child(cloak)

	var body = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.height = 1.45
	mesh.radius = 0.34
	body.mesh = mesh
	body.position.y = 0.92
	body.material_override = _mat(Color(0.24, 0.27, 0.25))
	visual_root.add_child(body)
	body_visual = body

	var chest = MeshInstance3D.new()
	var chest_mesh = BoxMesh.new()
	chest_mesh.size = Vector3(0.72, 0.42, 0.24)
	chest.mesh = chest_mesh
	chest.position = Vector3(0, 1.25, -0.02)
	chest.material_override = _mat(Color(0.17, 0.18, 0.17))
	visual_root.add_child(chest)

	for side in [-1, 1]:
		var shoulder = MeshInstance3D.new()
		var shoulder_mesh = BoxMesh.new()
		shoulder_mesh.size = Vector3(0.22, 0.18, 0.28)
		shoulder.mesh = shoulder_mesh
		shoulder.position = Vector3(0.42 * side, 1.42, 0)
		shoulder.material_override = _mat(Color(0.42, 0.40, 0.34))
		visual_root.add_child(shoulder)

	var head = MeshInstance3D.new()
	head.mesh = SphereMesh.new()
	head.scale = Vector3(0.34, 0.28, 0.34)
	head.position.y = 1.78
	head.material_override = _mat(Color(0.72, 0.66, 0.57))
	visual_root.add_child(head)

	var scar = MeshInstance3D.new()
	var scar_mesh = BoxMesh.new()
	scar_mesh.size = Vector3(0.03, 0.2, 0.01)
	scar.mesh = scar_mesh
	scar.position = Vector3(0.11, 1.81, -0.31)
	scar.rotation_degrees.z = 18
	scar.material_override = _mat(Color(0.45, 0.09, 0.07))
	visual_root.add_child(scar)

	_add_motion_proxy_parts()
	_add_weapon_visuals(Vector3(0.43, 0.86, -0.38))
	CharacterPresentation.apply_player(self, visual_root)
	_add_beam_charge_visual()

func _add_beam_charge_visual() -> void:
	beam_charge_visual = MeshInstance3D.new()
	beam_charge_visual.name = "OathfireChargeSphere"
	beam_charge_visual.mesh = SphereMesh.new()
	beam_charge_visual.position = Vector3(0, 1.30, -0.72)
	beam_charge_visual.material_override = _beam_material(Color(0.35, 0.88, 1.0, 0.92))
	beam_charge_visual.visible = false
	visual_root.add_child(beam_charge_visual)
	beam_left_hand_glow = _make_oathfire_hand("OathfireLeftHand", Vector3(-0.40, 1.16, -0.34))
	beam_right_hand_glow = _make_oathfire_hand("OathfireRightHand", Vector3(0.40, 1.16, -0.34))
	_build_sheathed_sword()

func _make_oathfire_hand(node_name: String, pos: Vector3) -> MeshInstance3D:
	var glow := MeshInstance3D.new()
	glow.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.10
	mesh.height = 0.20
	glow.mesh = mesh
	glow.position = pos
	glow.material_override = _beam_material(Color(0.38, 0.82, 1.0, 0.58))
	glow.visible = false
	visual_root.add_child(glow)
	return glow

func _build_sheathed_sword() -> void:
	var socket_parent: Node3D = visual_root
	var bone_attached := false
	var skeleton := _find_skeleton(visual_root)
	if skeleton != null:
		var back_index := _find_bone_index(skeleton, ["Spine2", "Chest", "Torso", "Spine"])
		if back_index >= 0:
			var attachment := BoneAttachment3D.new()
			attachment.name = "KaelBackSwordSocket"
			attachment.bone_idx = back_index
			attachment.bone_name = skeleton.get_bone_name(back_index)
			skeleton.add_child(attachment)
			socket_parent = _create_equipment_space(attachment, "KaelBackSwordEquipmentSpace")
			bone_attached = true
	var sword_scene = load("res://assets_external/characters/Warrior_Sword.fbx")
	sheathed_sword_visual = sword_scene.instantiate() if sword_scene is PackedScene else Node3D.new()
	sheathed_sword_visual.name = "OathfireSheathedSword"
	sheathed_sword_visual.position = Vector3(-0.22, 0.08, 0.16) if bone_attached else Vector3(-0.34, 1.18, 0.28)
	sheathed_sword_visual.rotation_degrees = Vector3(72, 4, -24) if bone_attached else Vector3(20, 0, -28)
	sheathed_sword_visual.scale *= 0.72
	socket_parent.add_child(sheathed_sword_visual)
	if sword_scene is PackedScene:
		sheathed_sword_visual.visible = false
		return
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.07, 0.07, 1.45)
	blade.mesh = blade_mesh
	blade.position.z = -0.52
	blade.material_override = _metal_mat(Color(0.62, 0.66, 0.68))
	sheathed_sword_visual.add_child(blade)
	sheathed_sword_visual.visible = false

func _try_build_mapped_body() -> bool:
	asset_helper = AssetSpawnHelper.new()
	add_child(asset_helper)
	var mapped: Node3D = null
	if asset_helper.has_method("has_visual_role") and asset_helper.has_method("spawn_visual_role") and asset_helper.has_visual_role("player_human"):
		mapped = asset_helper.spawn_visual_role("player_human", "characters")
	if mapped == null or mapped.name.ends_with("_placeholder"):
		if mapped != null:
			mapped.queue_free()
		mapped = asset_helper.spawn_character("player_kael")
	if mapped == null or mapped.name.ends_with("_placeholder"):
		if mapped != null:
			mapped.queue_free()
		return false
	mapped.name = "player_kael_visual"
	mapped.rotation_degrees.y = 180
	visual_root.add_child(mapped)
	rig_sword_visual = mapped.find_child("Warrior_Sword", true, false) as Node3D
	if rig_sword_visual == null:
		rig_sword_visual = _attach_rig_sword(mapped)
	body_visual = _find_first_mesh(mapped)
	_apply_visible_material_fallbacks(mapped, _mat(Color(0.18, 0.20, 0.18)))
	if body_visual != null and body_visual.material_override is StandardMaterial3D:
		body_base_color = (body_visual.material_override as StandardMaterial3D).albedo_color
	animation_driver = CharacterAnimationDriver.new()
	animation_driver.name = "CharacterAnimationDriver"
	mapped.add_child(animation_driver)
	var animated: bool = bool(animation_driver.configure(mapped, {
		"idle": "Idle_Sword", "walk": "Walk", "run": "Run",
		"jump": "Run", "attack_light": "Sword_Slash",
		"attack_heavy": "Sword_Slash", "dodge": "Roll",
		"parry": "HitRecieve", "beam_cast": "Interact", "hit": "HitRecieve", "death": "Death"
	}))
	if not animated:
		_add_motion_proxy_parts()
		_add_mapped_weapon_visuals()
	else:
		_add_slash_arc_visuals()
	return true

func _attach_rig_sword(mapped: Node3D) -> Node3D:
	var skeleton := _find_skeleton(mapped)
	if skeleton == null:
		return null
	var hand_index := skeleton.find_bone("RightHand")
	if hand_index < 0:
		hand_index = skeleton.find_bone("Hand.R")
	if hand_index < 0:
		for bone_index in range(skeleton.get_bone_count()):
			var bone_name := str(skeleton.get_bone_name(bone_index)).to_lower()
			if bone_name.contains("right") and (bone_name.contains("hand") or bone_name.contains("wrist")):
				hand_index = bone_index
				break
	if hand_index < 0:
		for bone_index in range(skeleton.get_bone_count()):
			var bone_name := str(skeleton.get_bone_name(bone_index)).to_lower()
			if bone_name.contains("hand") or bone_name.contains("wrist"):
				hand_index = bone_index
				break
	if hand_index < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = "KaelSwordSocket"
	attachment.bone_idx = hand_index
	attachment.bone_name = skeleton.get_bone_name(hand_index)
	skeleton.add_child(attachment)
	var equipment_space := _create_equipment_space(attachment, "KaelSwordEquipmentSpace")
	var sword: Node3D = null
	var sword_scene = load("res://assets_external/characters/Warrior_Sword.fbx")
	if sword_scene is PackedScene:
		sword = sword_scene.instantiate()
	if sword == null:
		sword = Node3D.new()
	sword.name = "Warrior_Sword"
	sword.position = Vector3(0.0, -0.08, -0.20)
	sword.rotation_degrees = Vector3(0.0, 0.0, -8.0)
	sword.scale *= 0.72
	equipment_space.add_child(sword)
	if sword_scene is PackedScene:
		return sword
	var blade := MeshInstance3D.new()
	blade.name = "Warrior_Sword_Blade"
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.055, 0.055, 0.92)
	blade.mesh = blade_mesh
	blade.position.z = -0.42
	blade.material_override = _metal_mat(Color(0.66, 0.70, 0.72))
	sword.add_child(blade)
	var hilt := MeshInstance3D.new()
	hilt.name = "Warrior_Sword_Hilt"
	var hilt_mesh := BoxMesh.new()
	hilt_mesh.size = Vector3(0.30, 0.075, 0.075)
	hilt.mesh = hilt_mesh
	hilt.material_override = _mat(Color(0.20, 0.11, 0.05))
	sword.add_child(hilt)
	return sword

func _create_equipment_space(attachment: BoneAttachment3D, space_name: String) -> Node3D:
	var equipment_space := Node3D.new()
	equipment_space.name = space_name
	attachment.add_child(equipment_space)
	var inherited_scale := attachment.global_basis.get_scale()
	equipment_space.scale = Vector3(
		1.0 / max(abs(inherited_scale.x), 0.0001),
		1.0 / max(abs(inherited_scale.y), 0.0001),
		1.0 / max(abs(inherited_scale.z), 0.0001)
	)
	return equipment_space

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _find_bone_index(skeleton: Skeleton3D, aliases: Array[String]) -> int:
	for alias in aliases:
		var exact := skeleton.find_bone(alias)
		if exact >= 0:
			return exact
	for bone_index in range(skeleton.get_bone_count()):
		var normalized := str(skeleton.get_bone_name(bone_index)).to_lower().replace("_", "").replace(".", "").replace(" ", "")
		for alias in aliases:
			var wanted := alias.to_lower().replace("_", "").replace(".", "").replace(" ", "")
			if normalized.contains(wanted):
				return bone_index
	return -1

func _find_first_mesh(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for child in root.get_children():
		var found = _find_first_mesh(child)
		if found != null:
			return found
	return null

func _add_mapped_weapon_visuals() -> void:
	_add_weapon_visuals(Vector3(0.42, 0.84, -0.42))

func _add_weapon_visuals(local_pos: Vector3) -> void:
	weapon_root = Node3D.new()
	weapon_root.name = "visible_sword_root"
	weapon_root.position = local_pos
	weapon_root.rotation_degrees = _weapon_ready_pose()
	visual_root.add_child(weapon_root)

	var sword = MeshInstance3D.new()
	sword.name = "visible_sword_blade"
	var sword_mesh = BoxMesh.new()
	sword_mesh.size = Vector3(0.105, 0.060, 1.78)
	sword.mesh = sword_mesh
	sword.position = Vector3(0.0, 0.28, -0.66)
	sword.material_override = _metal_mat(Color(0.68, 0.70, 0.68))
	weapon_root.add_child(sword)
	sword_visual = sword

	var hilt = MeshInstance3D.new()
	hilt.name = "visible_sword_hilt"
	var hilt_mesh = BoxMesh.new()
	hilt_mesh.size = Vector3(0.42, 0.080, 0.095)
	hilt.mesh = hilt_mesh
	hilt.position = Vector3(0.0, -0.04, 0.03)
	hilt.material_override = _mat(Color(0.13, 0.08, 0.045))
	weapon_root.add_child(hilt)
	sword_hilt_visual = hilt

	var pommel = MeshInstance3D.new()
	pommel.name = "visible_sword_pommel"
	var pommel_mesh = BoxMesh.new()
	pommel_mesh.size = Vector3(0.13, 0.13, 0.13)
	pommel.mesh = pommel_mesh
	pommel.position = Vector3(0.0, -0.15, 0.14)
	pommel.material_override = _metal_mat(Color(0.37, 0.34, 0.28))
	weapon_root.add_child(pommel)

	var trail = MeshInstance3D.new()
	trail.name = "visible_sword_swing_trail"
	var trail_mesh = BoxMesh.new()
	trail_mesh.size = Vector3(0.24, 0.16, 2.45)
	trail.mesh = trail_mesh
	trail.position = Vector3(0.30, 0.34, -0.92)
	trail.rotation_degrees.z = -24.0
	trail.material_override = _trail_mat(Color(1.0, 0.78, 0.36, 0.88))
	trail.visible = false
	weapon_root.add_child(trail)
	sword_trail_visual = trail
	_add_slash_arc_visuals()

func _weapon_ready_pose() -> Vector3:
	return Vector3(18, 0, 8)

func _add_motion_proxy_parts() -> void:
	left_arm_proxy = _add_proxy_box("left_motion_arm", Vector3(-0.43, 1.16, -0.04), Vector3(0.12, 0.64, 0.13), Color(0.10, 0.11, 0.10))
	right_arm_proxy = _add_proxy_box("right_weapon_arm", Vector3(0.43, 1.13, -0.04), Vector3(0.12, 0.58, 0.13), Color(0.11, 0.10, 0.085))
	left_leg_proxy = _add_proxy_box("left_motion_leg", Vector3(-0.16, 0.52, -0.01), Vector3(0.14, 0.70, 0.14), Color(0.075, 0.070, 0.065))
	right_leg_proxy = _add_proxy_box("right_motion_leg", Vector3(0.16, 0.52, -0.01), Vector3(0.14, 0.70, 0.14), Color(0.075, 0.070, 0.065))
	cloak_motion_proxy = _add_proxy_box("cloak_motion_read", Vector3(0.0, 0.98, 0.26), Vector3(0.68, 0.98, 0.12), Color(0.055, 0.065, 0.055))

func _add_slash_arc_visuals() -> void:
	slash_arc_root = Node3D.new()
	slash_arc_root.name = "visible_sword_slash_arc_root"
	slash_arc_root.position = Vector3(0.48, 1.18, -0.78)
	slash_arc_root.visible = false
	visual_root.add_child(slash_arc_root)
	slash_arc_primary = _add_slash_panel("visible_sword_slash_arc_primary", Vector3(0.06, 0.0, 0), Vector3(2.25, 0.22, 0.34), Color(1.0, 0.62, 0.24, 0.82))
	slash_arc_secondary = _add_slash_panel("visible_sword_slash_arc_secondary", Vector3(-0.16, -0.12, 0.08), Vector3(1.70, 0.16, 0.26), Color(0.70, 0.32, 0.12, 0.58))
	slash_arc_spark = _add_slash_panel("visible_sword_slash_impact_edge", Vector3(0.72, 0.08, -0.03), Vector3(0.62, 0.24, 0.22), Color(1.0, 0.80, 0.34, 0.92))

func _add_slash_panel(node_name: String, local_pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var panel = MeshInstance3D.new()
	panel.name = node_name
	var mesh = BoxMesh.new()
	mesh.size = size
	panel.mesh = mesh
	panel.position = local_pos
	panel.material_override = _trail_mat(color)
	slash_arc_root.add_child(panel)
	return panel

func _add_proxy_box(node_name: String, local_pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var proxy = MeshInstance3D.new()
	proxy.name = node_name
	var mesh = BoxMesh.new()
	mesh.size = size
	proxy.mesh = mesh
	proxy.position = local_pos
	proxy.material_override = _mat(color)
	visual_root.add_child(proxy)
	return proxy

func _animate_visuals(delta: float, move_dir: Vector3, moving: bool) -> void:
	if visual_root == null:
		return
	var running = movement_state == "run" or (Input.is_action_pressed("run") and moving)
	if animation_driver != null and animation_driver.is_valid():
		animation_driver.set_locomotion(Vector2(velocity.x, velocity.z).length() / max(run_speed, 0.1), move_dir, is_on_floor())
		if movement_state == "dodge" and animation_driver.current_state != "dodge":
			animation_driver.trigger_action("dodge")
	if moving:
		move_phase += delta * (8.7 if running else 6.2)
		step_phase += delta * (3.05 if running else 2.15)
		if step_phase >= 1.0:
			step_phase = 0.0
			footstep.emit()
	else:
		move_phase += delta * 1.45
	var speed_factor = clamp(Vector2(velocity.x, velocity.z).length() / max(run_speed, 0.1), 0.0, 1.0)
	movement_blend = lerp(movement_blend, speed_factor, 1.0 - exp(-10.0 * delta))
	strafe_blend = lerp(strafe_blend, 1.0 if movement_state == "strafe" else 0.0, 1.0 - exp(-9.0 * delta))
	backward_blend = lerp(backward_blend, 1.0 if movement_state == "backward" else 0.0, 1.0 - exp(-9.0 * delta))
	grounded_weight = lerp(grounded_weight, movement_blend, 1.0 - exp(-8.0 * delta))
	block_pose_weight = lerp(block_pose_weight, 1.0 if is_blocking() else 0.0, 14.0 * delta)
	var dodge_weight = clamp(dodge_time / 0.30, 0.0, 1.0)
	var hurt_weight = clamp(hurt_react_time / 0.20, 0.0, 1.0)
	var combat_swing_weight = 0.0
	var combat_windup_weight = 0.0
	var bob = 0.030 * sin(move_phase) * grounded_weight if moving else 0.009 * sin(move_phase)
	var idle_breath = sin(move_phase * 0.72) * (1.0 - grounded_weight)
	var pelvis_offset = (left_foot_ground_offset + right_foot_ground_offset) * 0.22
	visual_root.position.y = bob + pelvis_offset - 0.018 * grounded_weight - 0.030 * hurt_weight - 0.10 * landing_compression
	var lateral_lean = clamp(-velocity.x * 0.85, -4.0, 4.0)
	var local_normal = global_transform.basis.inverse() * smoothed_ground_normal
	var slope_pitch = rad_to_deg(atan2(local_normal.z, max(local_normal.y, 0.25)))
	var slope_roll = -rad_to_deg(atan2(local_normal.x, max(local_normal.y, 0.25)))
	var forward_lean = (-6.5 if running else -4.2) * grounded_weight if moving else 0.9 * idle_breath
	forward_lean += slope_pitch * 0.45 + 8.0 * jump_pose_weight - 11.0 * landing_compression
	forward_lean += -7.0 * dodge_weight + 5.0 * hurt_weight - 3.5 * block_pose_weight
	var root_z = lateral_lean + slope_roll * 0.50 + 4.5 * sin(move_phase) * grounded_weight + 9.0 * dodge_weight * sign(dodge_dir.x) - 3.0 * block_pose_weight
	visual_root.rotation_degrees.z = lerp(visual_root.rotation_degrees.z, root_z, 9.0 * delta)
	visual_root.rotation_degrees.x = lerp(visual_root.rotation_degrees.x, forward_lean, 9.0 * delta)
	if attack_anim_time > 0.0:
		var duration = 0.52 if attack_anim_heavy else 0.34
		var t = 1.0 - attack_anim_time / duration
		var windup = clamp(t / (0.38 if attack_anim_heavy else 0.24), 0.0, 1.0)
		var strike = clamp((t - (0.30 if attack_anim_heavy else 0.18)) / (0.34 if attack_anim_heavy else 0.24), 0.0, 1.0)
		var recovery = clamp((t - (0.64 if attack_anim_heavy else 0.52)) / (0.36 if attack_anim_heavy else 0.34), 0.0, 1.0)
		var strike_arc = sin(strike * PI)
		combat_swing_weight = strike_arc
		combat_windup_weight = windup
		var windup_angle = 34.0 if attack_anim_heavy else 18.0
		var swing = -172.0 * strike_arc if attack_anim_heavy else -132.0 * strike_arc
		var root_y = lerp(windup_angle, -18.0 if attack_anim_heavy else -10.0, strike)
		root_y = lerp(root_y, 0.0, recovery)
		visual_root.rotation_degrees.y = root_y
		visual_root.rotation_degrees.x = lerp(visual_root.rotation_degrees.x, forward_lean - (9.0 if attack_anim_heavy else 5.5) * strike_arc + 3.0 * windup, 12.0 * delta)
		if weapon_root != null:
			var weapon_pose = Vector3(38.0 - strike_arc * (68.0 if attack_anim_heavy else 48.0), swing, 20.0 + windup * (68.0 if attack_anim_heavy else 42.0) + strike_arc * (110.0 if attack_anim_heavy else 82.0))
			weapon_root.rotation_degrees = weapon_pose
			weapon_root.position = weapon_root.position.lerp(Vector3(0.42, 0.84, -0.42) + Vector3(0.20 * strike_arc, 0.08 * windup, -0.26 * strike_arc), 14.0 * delta)
			if sword_trail_visual != null:
				sword_trail_visual.visible = strike > 0.04 and recovery < 0.88
				sword_trail_visual.rotation_degrees.z = lerp(-58.0 if attack_anim_heavy else -42.0, 24.0, strike)
				sword_trail_visual.scale = Vector3.ONE * lerp(0.92, 1.42 if attack_anim_heavy else 1.18, strike_arc)
		_animate_slash_arc(strike, strike_arc, recovery, attack_anim_heavy)
	else:
		visual_root.rotation_degrees.y = lerp(visual_root.rotation_degrees.y, 0.0, 10.0 * delta)
		var ready_pose = Vector3(14.0 - block_pose_weight * 20.0, block_pose_weight * -22.0, 8.0 + block_pose_weight * 18.0)
		if weapon_root != null:
			weapon_root.rotation_degrees = weapon_root.rotation_degrees.lerp(ready_pose, 12.0 * delta)
			weapon_root.position = weapon_root.position.lerp(Vector3(0.42, 0.84, -0.42), 10.0 * delta)
		if sword_trail_visual != null:
			sword_trail_visual.visible = false
		if slash_arc_root != null:
			slash_arc_root.visible = false
	if beam_cast_state != "":
		var cast_weight := 1.0 if beam_cast_state in ["charging", "releasing"] else 0.55
		visual_root.rotation_degrees.x = lerp(visual_root.rotation_degrees.x, -4.0 * cast_weight, 12.0 * delta)
		visual_root.rotation_degrees.y = lerp(visual_root.rotation_degrees.y, 0.0, 12.0 * delta)
		if slash_arc_root != null:
			slash_arc_root.visible = false
	_animate_motion_proxies(delta, moving, movement_blend, dodge_weight, hurt_weight, block_pose_weight, combat_windup_weight, combat_swing_weight)
	if body_visual != null:
		var mat = body_visual.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = body_base_color.lerp(Color(0.72, 0.22, 0.12), 0.72) if hurt_flash_time > 0.0 else body_base_color

func _animate_motion_proxies(delta: float, moving: bool, speed_factor: float, dodge_weight: float, hurt_weight: float, block_weight: float, windup_weight: float, swing_weight: float) -> void:
	var gait = sin(move_phase)
	var stride = clamp(speed_factor * 1.25, 0.0, 1.0)
	var idle_weight = 1.0 - stride
	var idle_breath = sin(move_phase * 0.72)
	var arm_amount = (68.0 if movement_state == "run" else 52.0) * stride
	var leg_amount = (62.0 if movement_state == "run" else 48.0) * stride
	var strafe_twist = strafe_blend * sign(velocity.x) * 18.0
	var backward_sign = lerp(1.0, -0.72, backward_blend)
	if left_arm_proxy != null:
		left_arm_proxy.rotation_degrees.x = lerp(left_arm_proxy.rotation_degrees.x, -gait * arm_amount * backward_sign - 12.0 * block_weight + 10.0 * hurt_weight + idle_breath * 4.0 * idle_weight, 12.0 * delta)
		left_arm_proxy.rotation_degrees.z = lerp(left_arm_proxy.rotation_degrees.z, -10.0 - 12.0 * block_weight - 14.0 * swing_weight, 12.0 * delta)
	if right_arm_proxy != null:
		right_arm_proxy.rotation_degrees.x = lerp(right_arm_proxy.rotation_degrees.x, gait * arm_amount * 0.60 * backward_sign - 34.0 * windup_weight - 54.0 * swing_weight - 20.0 * block_weight, 13.0 * delta)
		right_arm_proxy.rotation_degrees.z = lerp(right_arm_proxy.rotation_degrees.z, 12.0 + 38.0 * swing_weight + 12.0 * block_weight, 13.0 * delta)
	if left_leg_proxy != null:
		left_leg_proxy.rotation_degrees.x = lerp(left_leg_proxy.rotation_degrees.x, gait * leg_amount * backward_sign - 24.0 * dodge_weight - 16.0 * jump_pose_weight, 13.0 * delta)
		left_leg_proxy.rotation_degrees.z = lerp(left_leg_proxy.rotation_degrees.z, strafe_twist, 11.0 * delta)
		left_leg_proxy.position.y = lerp(left_leg_proxy.position.y, 0.52 + left_foot_ground_offset + max(0.0, -gait) * 0.10 * stride + 0.08 * jump_pose_weight, 14.0 * delta)
	if right_leg_proxy != null:
		right_leg_proxy.rotation_degrees.x = lerp(right_leg_proxy.rotation_degrees.x, -gait * leg_amount * backward_sign - 24.0 * dodge_weight + 16.0 * jump_pose_weight, 13.0 * delta)
		right_leg_proxy.rotation_degrees.z = lerp(right_leg_proxy.rotation_degrees.z, strafe_twist, 11.0 * delta)
		right_leg_proxy.position.y = lerp(right_leg_proxy.position.y, 0.52 + right_foot_ground_offset + max(0.0, gait) * 0.10 * stride + 0.08 * jump_pose_weight, 14.0 * delta)
	if cloak_motion_proxy != null:
		var cloak_sway = (9.0 * gait * stride) + 15.0 * dodge_weight + strafe_twist * 0.35
		cloak_motion_proxy.rotation_degrees.x = lerp(cloak_motion_proxy.rotation_degrees.x, -5.0 - 10.0 * stride - 10.0 * jump_pose_weight + 15.0 * dodge_weight + 11.0 * swing_weight + 2.0 * idle_breath * idle_weight, 9.0 * delta)
		cloak_motion_proxy.rotation_degrees.z = lerp(cloak_motion_proxy.rotation_degrees.z, cloak_sway, 9.0 * delta)

func _animate_slash_arc(strike: float, strike_arc: float, recovery: float, heavy: bool) -> void:
	if slash_arc_root == null:
		return
	var visible = strike > 0.08 and strike < 0.94 and recovery < 0.86
	slash_arc_root.visible = visible
	if not visible:
		return
	var arc_size = 1.0 + strike_arc * (0.55 if heavy else 0.32)
	var blade_origin := Vector3(0.42, 0.94, -0.42)
	if weapon_root != null:
		blade_origin = weapon_root.position
	elif rig_sword_visual != null:
		blade_origin = visual_root.to_local(rig_sword_visual.global_position)
	slash_arc_root.position = blade_origin + Vector3(0.08 + 0.20 * strike_arc, 0.30 + (0.14 if heavy else 0.07), -0.40 - 0.30 * strike_arc)
	slash_arc_root.rotation_degrees = Vector3(-18.0 if heavy else -10.0, lerp(54.0 if heavy else 40.0, -48.0 if heavy else -34.0, strike), lerp(-52.0 if heavy else -34.0, 38.0 if heavy else 28.0, strike))
	slash_arc_root.scale = Vector3(arc_size, 1.0, arc_size)
	if slash_arc_primary != null:
		slash_arc_primary.visible = true
		slash_arc_primary.scale = Vector3(1.28 if heavy else 1.06, 1.0 + strike_arc * 0.18, 1.24 if heavy else 1.08)
	if slash_arc_secondary != null:
		slash_arc_secondary.visible = strike_arc > 0.20
	if slash_arc_spark != null:
		slash_arc_spark.visible = strike_arc > 0.45

func _mat(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material

func _metal_mat(color: Color) -> StandardMaterial3D:
	var material = _mat(color)
	material.metallic = 0.38
	material.roughness = 0.48
	return material

func _trail_mat(color: Color) -> StandardMaterial3D:
	var material = _mat(color)
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(1.0, 0.76, 0.42)
	material.emission_energy_multiplier = 0.9
	return material

func _beam_material(color: Color) -> StandardMaterial3D:
	var material = _trail_mat(color)
	material.emission = Color(0.25, 0.82, 1.0)
	material.emission_energy_multiplier = 2.2
	return material

func _apply_visible_material_fallbacks(root: Node, fallback: Material) -> void:
	if root is MeshInstance3D:
		var mesh_instance = root as MeshInstance3D
		if _mesh_needs_visible_material(mesh_instance):
			mesh_instance.material_override = fallback
	for child in root.get_children():
		_apply_visible_material_fallbacks(child, fallback)

func _mesh_needs_visible_material(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.material_override != null:
		return _is_bad_white_material(mesh_instance.material_override)
	if mesh_instance.mesh == null:
		return true
	var saw_material = false
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var material = mesh_instance.mesh.surface_get_material(surface_index)
		if material == null:
			continue
		saw_material = true
		if _is_bad_white_material(material):
			return true
	return not saw_material

func _is_bad_white_material(material: Material) -> bool:
	if material == null:
		return true
	if material is StandardMaterial3D:
		var standard = material as StandardMaterial3D
		var color = standard.albedo_color
		return standard.albedo_texture == null and color.r > 0.85 and color.g > 0.85 and color.b > 0.85
	return false
