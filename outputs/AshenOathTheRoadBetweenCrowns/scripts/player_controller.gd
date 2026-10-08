extends CharacterBody3D

signal blade_contact_requested(contact: Dictionary)
signal potion_requested
signal bomb_requested
signal beam_requested(charge_ratio: float, direction: Vector3)
signal beam_phase_changed(phase: String)
signal arrow_requested(request: Dictionary)
signal arrow_unavailable
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
const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")
const CharacterAnimationDriver = preload("res://scripts/character_animation_driver.gd")
const EquipmentLoadout = preload("res://scripts/equipment_loadout.gd")
const BACKPEDAL_MAX_SPEED := 1.45

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
var transition_locked := false
var difficulty_profile: Dictionary = {"incoming_damage_multiplier": 1.0, "parry_window": 0.30, "dodge_cost_modifier": 0.0, "attack_buffer": 0.18}
var camera_controller
var input_source: Node
var health_component
var stamina_component
var visual_root: Node3D
var _camera_close_view := false
var _camera_body_shadows: Dictionary = {}
var body_visual: MeshInstance3D
var body_base_color := Color(0.24, 0.27, 0.25)
var weapon_root: Node3D
var sword_visual: MeshInstance3D
var sword_hilt_visual: MeshInstance3D
var sword_trail_visual: MeshInstance3D
var rig_sword_visual: Node3D
var sword_attachment: BoneAttachment3D
var sword_equipment_pivot: Node3D
var guard_arm_ik: SkeletonIK3D
var guard_arm_applied := false
var sword_grip_bones: Dictionary = {}
var sword_grip_base_rotations: Dictionary = {}
var sword_grip_applied_rotations: Dictionary = {}
var sword_grip_pose_applied := false
var slash_arc_root: Node3D
var slash_arc_primary: MeshInstance3D
var slash_arc_secondary: MeshInstance3D
var slash_arc_spark: MeshInstance3D
var asset_helper
var animation_driver
var move_phase = 0.0
var footstep_distance = 0.0
var locomotion_velocity := Vector3.ZERO
var animation_step_signal_bound := false
var attack_anim_time = 0.0
var attack_anim_heavy = false
var pending_attack_damage := 0.0
var pending_attack_radius := 0.0
var pending_attack_heavy := false
var attack_sequence_id := 0
var attack_contact_emitted := false
var previous_contact_progress := 0.0
var previous_blade_base := Vector3.ZERO
var previous_blade_tip := Vector3.ZERO
var visual_previous_blade_base := Vector3.ZERO
var visual_previous_blade_tip := Vector3.ZERO
var blade_base_marker: Node3D
var blade_tip_marker: Node3D
var hurt_flash_time = 0.0
var hurt_react_time = 0.0
var parry_window = 0.0
var buffered_attack := ""
var attack_buffer_time := 0.0
var block_pose_weight = 0.0
var grounded_weight = 0.0
var beam_charging = false
var beam_charge_time = 0.0
var beam_cooldown = 0.0
var beam_charge_visual: MeshInstance3D
var beam_left_hand_glow: MeshInstance3D
var beam_right_hand_glow: MeshInstance3D
var beam_left_hand_socket: BoneAttachment3D
var beam_right_hand_socket: BoneAttachment3D
var beam_left_arm_ik: SkeletonIK3D
var beam_right_arm_ik: SkeletonIK3D
var beam_arm_pose_applied := false
var sheathed_sword_visual: Node3D
var blade_hand_visuals: Dictionary = {}
var blade_back_visuals: Dictionary = {}
var blade_scabbards: Dictionary = {}
var beam_cast_state := ""
var beam_state_time := 0.0
var beam_locked_direction := Vector3.ZERO
var beam_pending_ratio := 0.0
var beam_release_elapsed := 0.0
var beam_release_emitted := false
var beam_cancel_reason := ""
var beam_state_sequence := 0
var beam_release_direction := Vector3.ZERO
var beam_restore_equipment: Dictionary = {}
var equipment_loadout: EquipmentLoadout = EquipmentLoadout.new()
var sword_sheathed: bool:
	get:
		return not equipment_loadout.sword_drawn
	set(value):
		equipment_loadout.set_sword_drawn(not value)
var weapon_cycle_armed := false
var weapon_cycle_held := false
var weapon_cycle_elapsed := 0.0
var equipment_pending_attack := ""
var bow_back_visual: Node3D
var equipment_left_arm_ik: SkeletonIK3D
var sword_grip_basis := Basis.IDENTITY
var sword_grip_calibrated := false
var inventory_ref
var weapon_mode: String:
	get:
		return equipment_loadout.active_weapon
	set(value):
		equipment_loadout.set_active_weapon(value)
var bow_aiming := false
var bow_draw_time := 0.0
var bow_recovery := 0.0
var selected_arrow_id := "standard_arrow"
var bow_visual: Node3D
var bow_quiver_visual: Node3D
var bow_attachment: BoneAttachment3D
var bow_quiver_attachment: BoneAttachment3D
const BOW_MAX_DRAW := 1.0
const BOW_RANGE := 24.0
const MODELED_SWORD_PATH := "res://assets_external/characters/Sword.fbx"
const MODELED_BOW_PATH := "res://assets_external/characters/Ranger_Bow.fbx"
const MODELED_ARROW_PATH := "res://assets_external/characters/Ranger_Arrow.fbx"

const BEAM_STATE_IDLE := ""
const BEAM_STATE_SHEATHING := "sheathing"
const BEAM_STATE_CHARGING := "charging"
const BEAM_STATE_RELEASING := "releasing"
const BEAM_STATE_REDRAWING := "redrawing"
var movement_state = "idle"
var movement_blend = 0.0
var strafe_blend = 0.0
var backward_blend = 0.0
var jump_pose_weight = 0.0
var landing_compression = 0.0
var smoothed_ground_normal = Vector3.UP
var left_foot_ground_offset = 0.0
var right_foot_ground_offset = 0.0
var ground_adaptation_accumulator := 0.0
const GROUND_ADAPTATION_INTERVAL := 1.0 / 30.0
var contact_shadow: Node3D
var was_on_floor = false
var step_up_cooldown = 0.0
var progression

func _init() -> void:
	equipment_loadout.name = "EquipmentLoadout"
	add_child(equipment_loadout)
	equipment_loadout.transition_started.connect(_on_equipment_transition_started)
	equipment_loadout.transition_finished.connect(_on_equipment_transition_finished)

func _ready() -> void:
	# Game remains active for menus and loading; gameplay and its children pause.
	process_mode = Node.PROCESS_MODE_PAUSABLE
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
	if input_source != null and input_source.has_method("is_gameplay_context") and not input_source.is_gameplay_context():
		if equipment_loadout.is_transitioning() or weapon_cycle_armed or equipment_pending_attack != "":
			_cancel_equipment_action()
		velocity.x = 0.0
		velocity.z = 0.0
		locomotion_velocity = Vector3.ZERO
		return
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	beam_cooldown = max(beam_cooldown - delta, 0.0)
	attack_anim_time = max(attack_anim_time - delta, 0.0)
	hurt_flash_time = max(hurt_flash_time - delta, 0.0)
	hurt_react_time = max(hurt_react_time - delta, 0.0)
	parry_window = max(parry_window - delta, 0.0)
	attack_buffer_time = max(attack_buffer_time - delta, 0.0)
	if attack_buffer_time <= 0.0:
		buffered_attack = ""
	step_up_cooldown = max(step_up_cooldown - delta, 0.0)
	bow_recovery = max(bow_recovery - delta, 0.0)
	_update_beam_sequence(delta)
	equipment_loadout.advance_transition(delta)
	if transition_locked:
		velocity = Vector3.ZERO
		locomotion_velocity = Vector3.ZERO
		_animate_visuals(delta)
		_update_blade_contact()
		return
	if not can_control:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		_apply_gravity(delta)
		move_and_slide()
		_capture_locomotion_motion()
		_animate_visuals(delta)
		_update_blade_contact()
		return
	_handle_combat_input()
	_handle_movement(delta)
	_update_blade_contact()

func set_transition_locked(locked: bool) -> void:
	if locked:
		_cancel_equipment_action()
	if locked and beam_cast_state != BEAM_STATE_IDLE:
		cancel_beam_charge("transition")
	transition_locked = locked
	if locked:
		can_control = false
		velocity = Vector3.ZERO
		locomotion_velocity = Vector3.ZERO
	elif health_component == null or health_component.health > 0.0:
		can_control = true

func cancel_buffered_input(reason: String = "context") -> void:
	_cancel_equipment_action()
	buffered_attack = ""
	attack_buffer_time = 0.0
	pending_attack_damage = 0.0
	pending_attack_radius = 0.0
	attack_contact_emitted = true
	attack_anim_time = 0.0
	parry_window = 0.0
	bow_aiming = false
	bow_draw_time = 0.0
	dodge_time = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	locomotion_velocity = Vector3.ZERO
	if beam_cast_state != BEAM_STATE_IDLE or beam_charging:
		cancel_beam_charge(reason)
	elif animation_driver != null and animation_driver.has_method("stop_action"):
		animation_driver.stop_action("idle", 0.12)
	if slash_arc_root != null:
		slash_arc_root.visible = false

func bind_inventory(value) -> void:
	inventory_ref = value
	if inventory_ref != null and int(inventory_ref.items.get(selected_arrow_id, 0)) <= 0:
		_cycle_arrow_type()

func get_weapon_mode() -> String:
	return weapon_mode

func get_selected_blade_id() -> String:
	return equipment_loadout.selected_blade_id

func get_selected_weapon_name() -> String:
	return equipment_loadout.selected_weapon_name()

func get_camera_eye_height() -> float:
	return CharacterRoleSpec.target_height("player_human", 1.78) * 0.91

func set_camera_close_view(enabled: bool) -> void:
	if _camera_close_view == enabled:
		return
	_camera_close_view = enabled
	if enabled:
		_cache_camera_body(visual_root)
	for geometry: GeometryInstance3D in _camera_body_shadows:
		if is_instance_valid(geometry):
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if enabled else _camera_body_shadows[geometry]
	if not enabled:
		_camera_body_shadows.clear()

func _cache_camera_body(node: Node) -> void:
	if node == null:
		return
	# Keep hand equipment and effects without drawing the inside of the head,
	# hair, clothing, scabbard or quiver over the camera. Shadows still render.
	if node == rig_sword_visual or node == weapon_root or node == bow_visual or node == slash_arc_root or node == beam_left_hand_glow or node == beam_right_hand_glow:
		return
	if node is GeometryInstance3D:
		_camera_body_shadows[node] = node.cast_shadow
	for child in node.get_children():
		_cache_camera_body(child)

func _uses_first_person_camera() -> bool:
	return camera_controller != null and camera_controller.has_method("is_first_person") and camera_controller.is_first_person()

func get_selected_arrow_id() -> String:
	return selected_arrow_id

func select_arrow(item_id: String) -> bool:
	if inventory_ref == null or inventory_ref.get_item_type(item_id) != "ammo" or int(inventory_ref.items.get(item_id, 0)) <= 0:
		return false
	selected_arrow_id = item_id
	if equipment_loadout != null:
		equipment_loadout.set_selected_arrow(item_id)
	return true

func get_selected_arrow_count() -> int:
	return int(inventory_ref.items.get(selected_arrow_id, 0)) if inventory_ref != null else 0

func _set_weapon_mode(next_mode: String) -> void:
	var normalized := "bow" if next_mode == "bow" else "sword"
	if weapon_mode == normalized:
		return
	bow_aiming = false
	bow_draw_time = 0.0
	weapon_mode = normalized
	_set_sword_sheathed(true)

func _select_blade(blade_id: String) -> void:
	_request_equipment("sword", blade_id, true)

func _request_equipment(mode: String, blade_id: String, drawn: bool) -> void:
	bow_aiming = false
	bow_draw_time = 0.0
	equipment_pending_attack = ""
	buffered_attack = ""
	attack_buffer_time = 0.0
	parry_window = 0.0
	pending_attack_damage = 0.0
	pending_attack_radius = 0.0
	equipment_loadout.request_loadout(mode, blade_id, drawn)
	previous_blade_base = Vector3.ZERO
	previous_blade_tip = Vector3.ZERO
	visual_previous_blade_base = Vector3.ZERO
	visual_previous_blade_tip = Vector3.ZERO

func _cycle_weapon() -> void:
	if weapon_mode == "bow":
		_select_blade("steel")
	elif get_selected_blade_id() == "steel":
		_select_blade("oathblade")
	else:
		_request_equipment("bow", get_selected_blade_id(), true)

func _toggle_weapon_draw() -> void:
	_request_equipment(weapon_mode, get_selected_blade_id(), not equipment_loadout.is_drawn())

func _handle_equipment_input() -> void:
	var available: bool = beam_cast_state == BEAM_STATE_IDLE and attack_anim_time <= 0.0 and dodge_time <= 0.0 and hurt_react_time <= 0.0 and not equipment_loadout.is_transitioning()
	if _action_just_pressed("weapon_cycle"):
		weapon_cycle_armed = available
		weapon_cycle_held = false
		weapon_cycle_elapsed = 0.0
	if weapon_cycle_armed and _action_pressed("weapon_cycle"):
		weapon_cycle_elapsed += get_physics_process_delta_time()
		if weapon_cycle_elapsed >= 0.45 and not weapon_cycle_held:
			weapon_cycle_held = true
			if available:
				_toggle_weapon_draw()
	if weapon_cycle_armed and _action_just_released("weapon_cycle"):
		if not weapon_cycle_held and available:
			_cycle_weapon()
		weapon_cycle_armed = false
	if not available or equipment_loadout.is_transitioning():
		return
	if _action_just_pressed("weapon_sheath"):
		_toggle_weapon_draw()
	elif _action_just_pressed("weapon_bow"):
		_request_equipment("bow", get_selected_blade_id(), true)
	elif _action_just_pressed("weapon_sword"):
		_select_blade("steel")
	elif _action_just_pressed("weapon_oathblade"):
		_select_blade("oathblade")

func _on_equipment_transition_started(action: String, duration: float) -> void:
	# Keep locomotion clips running while moving; the existing arm IK supplies
	# the reach. Stationary transfers can use the compatible retained clip.
	if animation_driver != null and locomotion_velocity.length_squared() < 0.04:
		animation_driver.trigger_action(action, 1.0, 0.08, false, duration)

func _on_equipment_transition_finished() -> void:
	if animation_driver != null and animation_driver.current_state in ["draw", "sheath"]:
		animation_driver.stop_action("idle", 0.08)

func _cancel_equipment_action() -> void:
	var was_transitioning := equipment_loadout.is_transitioning()
	equipment_loadout.cancel_transition()
	equipment_pending_attack = ""
	weapon_cycle_armed = false
	weapon_cycle_held = false
	weapon_cycle_elapsed = 0.0
	if was_transitioning and guard_arm_ik != null:
		guard_arm_ik.stop()
		guard_arm_applied = false
	if equipment_left_arm_ik != null:
		equipment_left_arm_ik.stop()

func _cycle_arrow_type() -> void:
	var arrow_ids := ["standard_arrow", "bodkin_arrow", "ashfire_arrow"]
	var start := arrow_ids.find(selected_arrow_id)
	for offset in range(1, arrow_ids.size() + 1):
		var candidate: String = arrow_ids[(start + offset) % arrow_ids.size()]
		if inventory_ref != null and int(inventory_ref.items.get(candidate, 0)) > 0:
			selected_arrow_id = candidate
			if equipment_loadout != null:
				equipment_loadout.set_selected_arrow(candidate)
			return
	selected_arrow_id = "standard_arrow"
	if equipment_loadout != null:
		equipment_loadout.set_selected_arrow(selected_arrow_id)

func set_progression(manager) -> void:
	if progression != null and progression.changed.is_connected(_apply_progression_stats):
		progression.changed.disconnect(_apply_progression_stats)
	progression = manager
	if progression != null and not progression.changed.is_connected(_apply_progression_stats):
		progression.changed.connect(_apply_progression_stats)
	_apply_progression_stats()

func _apply_progression_stats() -> void:
	if health_component == null:
		return
	var target_max := 125.0 + _progression_value("max_health_bonus", 0.0)
	var gained := maxf(target_max - health_component.max_health, 0.0)
	health_component.max_health = target_max
	health_component.health = clampf(health_component.health + gained, 1.0, target_max)
	health_component.changed.emit(health_component.health, health_component.max_health)

func _progression_value(effect_id: String, fallback: float) -> float:
	return progression.effect_value(effect_id, fallback) if progression != null else fallback

func get_dodge_stamina_cost() -> float:
	return maxf(1.0, 28.0 + float(difficulty_profile.get("dodge_cost_modifier", 0.0)) - _progression_value("dodge_cost_reduction", 0.0))

func apply_difficulty_profile(profile: Dictionary) -> void:
	difficulty_profile = {
		"incoming_damage_multiplier": clampf(float(profile.get("incoming_damage_multiplier", 1.0)), 0.25, 2.0),
		"parry_window": clampf(float(profile.get("parry_window", 0.30)), 0.15, 0.50),
		"dodge_cost_modifier": clampf(float(profile.get("dodge_cost_modifier", 0.0)), -10.0, 10.0),
		"attack_buffer": clampf(float(profile.get("attack_buffer", 0.18)), 0.10, 0.30),
	}

func get_oathfire_stamina_cost() -> float:
	return maxf(1.0, 40.0 - _progression_value("beam_cost_reduction", 0.0))

func get_oathfire_cooldown_duration() -> float:
	return maxf(0.5, 4.0 - _progression_value("beam_cooldown_reduction", 0.0))

func get_blade_attack_damage(heavy: bool = false) -> float:
	var base_damage := 42.0 if heavy else 24.0
	var multiplier := _progression_value("blade_damage_multiplier", 1.0)
	if heavy:
		multiplier *= _progression_value("heavy_damage_multiplier", 1.0)
	var forge_bonus: float = inventory_ref.blade_upgrade_bonus(get_selected_blade_id()) if inventory_ref != null else 0.0
	return base_damage * multiplier + forge_bonus

func _movement_input() -> Vector2:
	if input_source != null and input_source.has_method("movement_vector"):
		return input_source.movement_vector()
	# Character fixtures and portrait captures can instantiate the controller
	# before InputRouter has installed its actions. Missing actions are neutral
	# input, not an engine error.
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		if not InputMap.has_action(action):
			return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func _action_pressed(action: StringName) -> bool:
	if input_source != null and input_source.has_method("is_action_pressed"):
		return input_source.is_action_pressed(action)
	if not InputMap.has_action(action):
		return false
	return Input.is_action_pressed(action)

func _action_just_pressed(action: StringName) -> bool:
	if input_source != null and input_source.has_method("is_action_just_pressed"):
		return input_source.is_action_just_pressed(action)
	if not InputMap.has_action(action):
		return false
	return Input.is_action_just_pressed(action)

func _action_just_released(action: StringName) -> bool:
	if input_source != null and input_source.has_method("is_action_just_released"):
		return input_source.is_action_just_released(action)
	if not InputMap.has_action(action):
		return false
	return Input.is_action_just_released(action)

func _handle_movement(delta: float) -> void:
	var input_vec: Vector2 = _movement_input()
	var forward: Vector3 = Vector3.FORWARD
	var right: Vector3 = Vector3.RIGHT
	if camera_controller != null:
		forward = camera_controller.get_flat_forward()
		right = camera_controller.get_flat_right()
	var move_dir: Vector3 = (right * input_vec.x + forward * -input_vec.y).normalized()
	if dodge_time > 0.0:
		dodge_time -= delta
		var dodge_ratio: float = clampf(dodge_time / 0.30, 0.0, 1.0)
		var dodge_velocity: float = dodge_speed * (0.62 + 0.38 * sin(dodge_ratio * PI))
		velocity.x = dodge_dir.x * dodge_velocity
		velocity.z = dodge_dir.z * dodge_velocity
		movement_state = "dodge"
	else:
		var wants_run: bool = _action_pressed("run") and input_vec.length() > 0.1
		var is_running: bool = wants_run and stamina_component.spend(10.0 * delta)
		var aim_facing: bool = (bow_aiming or _uses_first_person_camera()) and camera_controller != null
		var backward_input: bool = input_vec.y > 0.15
		# Walking away remains a deliberate, short backward stride. Sprinting
		# away in the free camera turns into a forward run; a held aim or cast
		# retains its facing and can never accelerate the reverse gait.
		var intentional_backpedal: bool = backward_input and (not is_running or aim_facing or beam_cast_state != "")
		var speed: float = run_speed if is_running else walk_speed
		if bow_aiming:
			speed *= 0.42
		if beam_cast_state != "":
			speed *= 0.4
		if intentional_backpedal:
			speed = minf(speed, BACKPEDAL_MAX_SPEED)
		if aim_facing and beam_cast_state == "":
			var aim_forward: Vector3 = camera_controller.get_flat_forward()
			if aim_forward.length_squared() > 0.5:
				var aim_yaw: float = atan2(-aim_forward.x, -aim_forward.z)
				rotation.y = lerp_angle(rotation.y, aim_yaw, 1.0 - exp(-turn_speed * delta))
		elif move_dir.length_squared() > 0.01 and beam_cast_state == "":
			# Facing follows intent; the feet below follow achieved movement. Using
			# old forward inertia here would spin Kael around on the first W-to-S
			# frame. Keeping the old yaw instead made orbiting backpedals sideways.
			var facing_direction: Vector3 = -move_dir if intentional_backpedal else move_dir
			var target_yaw: float = atan2(-facing_direction.x, -facing_direction.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
		var target_velocity: Vector3 = move_dir * speed
		var response: float = run_acceleration if is_running else acceleration
		if move_dir.length_squared() <= 0.01:
			response = deceleration
		elif not aim_facing and not intentional_backpedal and beam_cast_state == "" and is_on_floor():
			# Brake the old stride through a sharp free turn, then build the new
			# stride as the body catches up. The desired speed and input direction
			# remain unchanged, including all stamina and combat speed modifiers.
			var body_forward: Vector3 = -global_basis.z
			body_forward.y = 0.0
			var alignment: float = clampf(body_forward.normalized().dot(move_dir), 0.0, 1.0)
			var planar_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
			if planar_velocity.length_squared() > 0.04 and planar_velocity.normalized().dot(move_dir) < 0.35:
				planar_velocity = planar_velocity.move_toward(Vector3.ZERO, deceleration * delta)
				velocity.x = planar_velocity.x
				velocity.z = planar_velocity.z
			response *= lerpf(0.18, 1.0, smoothstep(0.0, 0.90, alignment))
		velocity.x = move_toward(velocity.x, target_velocity.x, response * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, response * delta)
		if _action_just_pressed("jump"):
			try_jump()
		if _action_just_pressed("dodge") and not beam_charging:
			if stamina_component.spend(get_dodge_stamina_cost()):
				_cancel_equipment_action()
				dodge_dir = move_dir if move_dir.length() > 0.1 else -global_transform.basis.z
				dodge_time = 0.30
			else:
				stamina_exhausted.emit("dodge")
	_try_step_up(move_dir)
	_apply_gravity(delta)
	move_and_slide()
	_capture_locomotion_motion()
	_update_ground_adaptation(delta)
	_animate_visuals(delta)

func _capture_locomotion_motion() -> void:
	# Collision sliding, acceleration, dodges and the final coasting step all
	# have one movement sample. Desired input is never used as a gait direction.
	var achieved_velocity: Vector3 = get_real_velocity()
	locomotion_velocity = Vector3(achieved_velocity.x, 0.0, achieved_velocity.z)

func _update_locomotion_state() -> void:
	if dodge_time > 0.0:
		movement_state = "dodge"
		return
	if not is_on_floor():
		movement_state = "jump"
		return
	var horizontal_speed: float = locomotion_velocity.length()
	if horizontal_speed < 0.15:
		movement_state = "idle"
		return
	var local_velocity: Vector3 = global_basis.orthonormalized().inverse() * locomotion_velocity
	var backwards: bool = local_velocity.z > horizontal_speed * 0.30
	if horizontal_speed > walk_speed * 1.04:
		movement_state = "run_back" if backwards else "run"
	elif absf(local_velocity.x) > absf(local_velocity.z) * 1.15:
		movement_state = "strafe"
	else:
		movement_state = "backward" if backwards else "walk"

func _face_attack_direction() -> void:
	if _uses_first_person_camera():
		var view_forward: Vector3 = camera_controller.get_flat_forward()
		rotation.y = atan2(-view_forward.x, -view_forward.z)
		return
	var input_vec := _movement_input()
	# Backward input preserves established facing at the attack edge. The
	# movement controller owns any free-camera sprint turn on this frame.
	if input_vec.y > 0.15:
		return
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	if camera_controller != null:
		forward = camera_controller.get_flat_forward()
		right = camera_controller.get_flat_right()
	var move_dir := (right * input_vec.x + forward * -input_vec.y).normalized()
	if move_dir.length_squared() <= 0.01:
		if camera_controller != null and camera_controller.has_method("assist_attack_direction"):
			var assisted: Vector3 = camera_controller.assist_attack_direction(global_position, -global_basis.z, 4.0)
			if assisted.length_squared() > 0.01:
				rotation.y = atan2(-assisted.x, -assisted.z)
		# A locked attack has a live combat target even when Kael is standing
		# still. Face that target at the attack edge so the hand-driven blade
		# sweep and the visible lock-on direction agree.
		if camera_controller != null and camera_controller.has_method("get_locked_combat_target"):
			var locked_target: Node3D = camera_controller.get_locked_combat_target()
			if locked_target != null and is_instance_valid(locked_target):
				var target_offset := locked_target.global_position - global_position
				target_offset.y = 0.0
				if target_offset.length_squared() > 0.01:
					rotation.y = atan2(-target_offset.x, -target_offset.z)
		return
	# Combat input is evaluated before movement in the physics tick. Apply the
	# same target yaw immediately at the attack edge so the blade starts from
	# the direction the player is visibly moving toward.
	rotation.y = atan2(-move_dir.x, -move_dir.z)

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
	var query = PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 0.42, probe - Vector3.UP * 0.08, 1)
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
	ground_adaptation_accumulator += delta
	if on_floor and not was_on_floor:
		landing_compression = clamp(abs(velocity.y) / 9.0, 0.45, 1.0)
	jump_pose_weight = move_toward(jump_pose_weight, 0.0 if on_floor else 1.0, delta * (6.0 if on_floor else 3.0))
	landing_compression = move_toward(landing_compression, 0.0, delta * 5.5)
	var normal = get_floor_normal() if on_floor else Vector3.UP
	smoothed_ground_normal = smoothed_ground_normal.lerp(normal, 1.0 - exp(-9.0 * delta)).normalized()
	if on_floor and ground_adaptation_accumulator >= GROUND_ADAPTATION_INTERVAL:
		var probe_delta := ground_adaptation_accumulator
		ground_adaptation_accumulator = 0.0
		left_foot_ground_offset = _sample_foot_offset(-0.18, probe_delta, left_foot_ground_offset)
		right_foot_ground_offset = _sample_foot_offset(0.18, probe_delta, right_foot_ground_offset)
	elif not on_floor:
		ground_adaptation_accumulator = 0.0
		left_foot_ground_offset = move_toward(left_foot_ground_offset, 0.0, delta * 3.0)
		right_foot_ground_offset = move_toward(right_foot_ground_offset, 0.0, delta * 3.0)
	if contact_shadow != null:
		contact_shadow.visible = global_position.y > -4.0
		var shadow_weight = 1.0 - clamp(abs(velocity.y) / 10.0, 0.0, 0.52)
		contact_shadow.scale = Vector3(0.95 * shadow_weight, 0.014, 0.66 * shadow_weight)
	was_on_floor = on_floor

func _sample_foot_offset(side: float, delta: float, current: float) -> float:
	var local_probe = global_transform.basis.x * side + global_transform.basis.z * 0.04
	var start = global_position + local_probe + Vector3.UP * 0.42
	var query = PhysicsRayQueryParameters3D.create(start, start - Vector3.UP * 0.72, 1)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	var target = 0.0
	if not hit.is_empty():
		target = clamp(float(hit.position.y - global_position.y), -0.16, 0.16)
	return lerp(current, target, 1.0 - exp(-12.0 * delta))

func _handle_combat_input() -> void:
	_handle_equipment_input()
	if beam_cast_state != BEAM_STATE_IDLE:
		_handle_beam_input()
		return
	if beam_cast_state == BEAM_STATE_IDLE:
		if _action_just_pressed("use_potion"):
			potion_requested.emit()
		if _action_just_pressed("throw_bomb"):
			bomb_requested.emit()
	if weapon_mode == "bow":
		# LT is bow aim in this weapon context, not an Oathfire cast. A separately
		# bound Oathfire press stows the bow until the cast restores its prior intent.
		if _action_just_pressed("oathfire_beam") and not _action_just_pressed("aim_bow"):
			_handle_beam_input()
		elif not equipment_loadout.is_transitioning():
			_handle_bow_input()
		return
	_handle_beam_input()
	if beam_cast_state != "" or equipment_loadout.is_transitioning():
		return
	var light_pressed := _action_just_pressed("light_attack") or equipment_pending_attack == "light"
	var heavy_pressed := _action_just_pressed("heavy_attack") or equipment_pending_attack == "heavy"
	equipment_pending_attack = ""
	if light_pressed or heavy_pressed:
		_face_attack_direction()
	if sword_sheathed and (light_pressed or heavy_pressed or _action_pressed("block")):
		equipment_pending_attack = "heavy" if heavy_pressed else ("light" if light_pressed else "")
		_draw_sword_for_combat()
		return
	if attack_cooldown > 0.0:
		if light_pressed or heavy_pressed:
			buffered_attack = "heavy" if heavy_pressed else "light"
			attack_buffer_time = 0.18
		return
	if buffered_attack != "":
		light_pressed = buffered_attack == "light"
		heavy_pressed = buffered_attack == "heavy"
		buffered_attack = ""
		attack_buffer_time = 0.0
	if light_pressed:
		_face_attack_direction()
		attack_cooldown = 0.38
		attack_anim_time = 0.34
		attack_anim_heavy = false
		if animation_driver != null:
			animation_driver.trigger_action("attack_light", 1.22, 0.06, false, attack_anim_time)
		_begin_blade_attack(get_blade_attack_damage(false), 2.0, false)
	elif heavy_pressed:
		_face_attack_direction()
		if stamina_component.spend(22.0):
			attack_cooldown = 0.7
			attack_anim_time = 0.52
			attack_anim_heavy = true
			if animation_driver != null:
				animation_driver.trigger_action("attack_heavy", 0.76, 0.08, false, attack_anim_time)
			_begin_blade_attack(get_blade_attack_damage(true), 2.25, true)
		else:
			stamina_exhausted.emit("heavy attack")
	if _action_just_pressed("block"):
		parry_window = get_parry_window_duration()
		if animation_driver != null:
			animation_driver.trigger_action("parry")

func _handle_bow_input() -> void:
	if not equipment_loadout.bow_drawn:
		if _action_pressed("aim_bow"):
			equipment_loadout.request_loadout("bow", get_selected_blade_id(), true)
		return
	if _action_just_pressed("cycle_arrow"):
		_cycle_arrow_type()
	if bow_recovery > 0.0:
		return
	var aiming_now := _action_pressed("aim_bow")
	if aiming_now:
		bow_aiming = true
		if equipment_loadout != null:
			equipment_loadout.set_bow_aiming(true)
		bow_draw_time = minf(bow_draw_time + get_physics_process_delta_time(), BOW_MAX_DRAW)
		if animation_driver != null and bow_draw_time <= get_physics_process_delta_time() * 1.5:
			animation_driver.trigger_action("bow_aim", 1.0, 0.10)
		if _action_just_pressed("fire_bow"):
			_release_bow()
		return
	if bow_aiming and _action_just_released("aim_bow"):
		bow_aiming = false
		if equipment_loadout != null:
			equipment_loadout.set_bow_aiming(false)
		bow_draw_time = 0.0
	if bow_aiming and _action_just_pressed("fire_bow"):
		_release_bow()
	elif _action_just_pressed("fire_bow"):
		# A fire press without aim is intentionally ignored. This prevents an
		# accidental sword-style click from consuming an arrow.
		return

func _release_bow() -> void:
	if inventory_ref == null:
		arrow_unavailable.emit()
		return
	if int(inventory_ref.items.get(selected_arrow_id, 0)) <= 0:
		_cycle_arrow_type()
	if int(inventory_ref.items.get(selected_arrow_id, 0)) <= 0:
		arrow_unavailable.emit()
		return
	var direction := -global_transform.basis.z
	if camera_controller != null:
		var locked_target: Node3D = camera_controller.get_locked_combat_target() if camera_controller.has_method("get_locked_combat_target") else null
		if locked_target != null and is_instance_valid(locked_target):
			direction = (locked_target.global_position + Vector3.UP * 0.92 - get_arrow_origin()).normalized()
		else:
			direction = camera_controller.get_flat_forward()
	direction.y = 0.0
	if direction.length_squared() < 0.5:
		direction = -global_transform.basis.z
	direction.y = 0.0
	direction = direction.normalized()
	face_target(global_position + direction * 4.0)
	var arrow_origin := get_arrow_origin()
	inventory_ref.consume(selected_arrow_id)
	arrow_requested.emit({
		"origin": arrow_origin,
		"direction": direction,
		"arrow_id": selected_arrow_id,
		"draw_ratio": clampf(bow_draw_time / BOW_MAX_DRAW, 0.0, 1.0),
		"range": BOW_RANGE,
		"width": 0.34,
	})
	bow_aiming = false
	if equipment_loadout != null:
		equipment_loadout.set_bow_aiming(false)
	bow_draw_time = 0.0
	bow_recovery = 0.24
	if animation_driver != null:
		animation_driver.trigger_action("attack_light", 1.0, 0.08)

func get_arrow_origin() -> Vector3:
	if bow_attachment != null and is_instance_valid(bow_attachment):
		return bow_attachment.global_position + Vector3.UP * 0.04 - global_transform.basis.z.normalized() * 0.18
	var forward := -global_transform.basis.z.normalized()
	return global_position + Vector3.UP * 1.30 + forward * 0.48

func _begin_blade_attack(damage: float, radius: float, heavy: bool) -> void:
	attack_sequence_id += 1
	attack_contact_emitted = false
	previous_contact_progress = 0.0
	pending_attack_damage = damage
	pending_attack_radius = radius
	pending_attack_heavy = heavy
	var segment: Dictionary = get_blade_world_segment()
	previous_blade_base = segment.get("base", global_position + Vector3(0, 1.0, 0))
	previous_blade_tip = segment.get("tip", previous_blade_base)

func _update_blade_contact() -> void:
	if not is_blade_ready():
		pending_attack_damage = 0.0
		pending_attack_radius = 0.0
		return
	if pending_attack_damage <= 0.0:
		return
	var segment: Dictionary = get_blade_world_segment()
	var blade_base: Vector3 = segment.get("base", Vector3.ZERO)
	var blade_tip: Vector3 = segment.get("tip", Vector3.ZERO)
	var duration: float = 0.52 if pending_attack_heavy else 0.34
	var progress: float = clampf(1.0 - attack_anim_time / duration, 0.0, 1.0)
	if progress <= previous_contact_progress:
		return
	var strike_start := 0.30 if pending_attack_heavy else 0.18
	var strike_end := 0.64 if pending_attack_heavy else 0.42
	if progress >= strike_start and previous_contact_progress < strike_end:
		# Clip the measured frame sweep to the damaging part of the animation.
		var span := progress - previous_contact_progress
		var from_weight := clampf((strike_start - previous_contact_progress) / span, 0.0, 1.0)
		var to_weight := clampf((strike_end - previous_contact_progress) / span, 0.0, 1.0)
		var first_sample := not attack_contact_emitted
		attack_contact_emitted = true
		blade_contact_requested.emit({
			"attack_id": attack_sequence_id,
			"blade_id": get_selected_blade_id(),
			"base": previous_blade_base.lerp(blade_base, to_weight),
			"tip": previous_blade_tip.lerp(blade_tip, to_weight),
			"previous_base": previous_blade_base.lerp(blade_base, from_weight),
			"previous_tip": previous_blade_tip.lerp(blade_tip, from_weight),
			"damage": pending_attack_damage,
			"reach": pending_attack_radius,
			"heavy": pending_attack_heavy,
			"contact_phase": progress,
			"sweep_length": maxf(previous_blade_tip.distance_to(blade_tip), previous_blade_base.distance_to(blade_base)),
			"blade_direction": (blade_tip - blade_base).normalized() if blade_tip.distance_to(blade_base) > 0.001 else Vector3.ZERO,
			"first_sample": first_sample,
			"final_sample": progress >= strike_end
		})
	if progress >= strike_end:
		pending_attack_damage = 0.0
		pending_attack_radius = 0.0
	previous_contact_progress = progress
	previous_blade_base = blade_base
	previous_blade_tip = blade_tip

func confirm_blade_contact(attack_id: int, hit: bool) -> void:
	if hit and attack_id == attack_sequence_id:
		pending_attack_damage = 0.0
		pending_attack_radius = 0.0

func get_parry_window_duration() -> float:
	return float(difficulty_profile.get("parry_window", 0.30))

func get_attack_buffer_duration() -> float:
	return float(difficulty_profile.get("attack_buffer", 0.18))

func is_blade_ready() -> bool:
	return can_control and not transition_locked and weapon_mode == "sword" and not sword_sheathed and not equipment_loadout.is_transitioning() and beam_cast_state == BEAM_STATE_IDLE and dodge_time <= 0.0 and hurt_react_time <= 0.0 and is_instance_valid(blade_base_marker) and is_instance_valid(blade_tip_marker)

func get_blade_world_segment() -> Dictionary:
	if blade_base_marker != null and blade_tip_marker != null and is_instance_valid(blade_base_marker) and is_instance_valid(blade_tip_marker):
		return {"base": blade_base_marker.global_position, "tip": blade_tip_marker.global_position}
	var forward := -global_transform.basis.z.normalized()
	var base := global_position + Vector3(0, 1.05, 0) + forward * 0.35
	return {"base": base, "tip": base + forward * 1.25}

func _configure_blade_markers(parent: Node3D, base_position: Vector3, tip_position: Vector3, fit_rendered_bounds: bool = false) -> void:
	if parent == null:
		return
	if fit_rendered_bounds:
		var fitted: Dictionary = _blade_axis_from_rendered_bounds(parent)
		base_position = fitted.get("base", base_position)
		tip_position = fitted.get("tip", tip_position)
	blade_base_marker = Node3D.new()
	blade_base_marker.name = "BladeContactBase"
	blade_base_marker.position = base_position
	parent.add_child(blade_base_marker)
	blade_tip_marker = Node3D.new()
	blade_tip_marker.name = "BladeContactTip"
	blade_tip_marker.position = tip_position
	parent.add_child(blade_tip_marker)

func _blade_axis_from_rendered_bounds(parent: Node3D) -> Dictionary:
	var bounds := AABB()
	var has_bounds := false
	var inverse_parent := parent.global_transform.affine_inverse()
	for child in parent.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var local_transform: Transform3D = inverse_parent * mesh_instance.global_transform
		var local_bounds: AABB = local_transform * mesh_instance.mesh.get_aabb()
		bounds = bounds.merge(local_bounds) if has_bounds else local_bounds
		has_bounds = true
	if not has_bounds:
		return {}
	var axis := 0
	if bounds.size.y > bounds.size.x and bounds.size.y >= bounds.size.z:
		axis = 1
	elif bounds.size.z > bounds.size.x and bounds.size.z > bounds.size.y:
		axis = 2
	var first := bounds.get_center()
	var second := bounds.get_center()
	first[axis] = bounds.position[axis]
	second[axis] = bounds.end[axis]
	var base := first if first.length_squared() <= second.length_squared() else second
	var tip := second if base == first else first
	return {"base": base, "tip": tip}

func _handle_beam_input() -> void:
	if _action_just_pressed("oathfire_beam") and beam_cooldown <= 0.0 and beam_cast_state == BEAM_STATE_IDLE and dodge_time <= 0.0:
		_begin_oathfire_cast()
	if beam_cast_state == BEAM_STATE_CHARGING and _action_pressed("oathfire_beam"):
		beam_charge_time = min(beam_charge_time + get_physics_process_delta_time(), 1.25)
		_update_beam_charge_visual()
	if beam_cast_state == BEAM_STATE_CHARGING and _action_just_released("oathfire_beam"):
		var ratio: float = clampf((beam_charge_time - 0.35) / 0.90, 0.0, 1.0)
		if beam_charge_time >= 0.35 and stamina_component.spend(get_oathfire_stamina_cost()):
			_commit_oathfire_release(ratio)
		elif beam_charge_time >= 0.35:
			stamina_exhausted.emit("Oathfire Beam")
			_begin_beam_redraw()
		else:
			_begin_beam_redraw()
	elif beam_cast_state == BEAM_STATE_SHEATHING and _action_just_released("oathfire_beam"):
		_begin_beam_redraw()

func _set_beam_state(next_state: String, duration: float = -1.0) -> void:
	if beam_cast_state == next_state:
		if duration >= 0.0:
			beam_state_time = duration
		return
	beam_cast_state = next_state
	beam_state_sequence += 1
	if duration >= 0.0:
		beam_state_time = duration
	if next_state != BEAM_STATE_IDLE:
		beam_phase_changed.emit(next_state)

func _begin_oathfire_cast() -> bool:
	if transition_locked or not can_control or beam_cooldown > 0.0 or dodge_time > 0.0 or beam_cast_state != BEAM_STATE_IDLE:
		return false
	var captured := _lock_beam_direction()
	if captured.length_squared() < 0.5:
		return false
	beam_restore_equipment = equipment_loadout.save_state()
	_cancel_equipment_action()
	bow_aiming = false
	bow_draw_time = 0.0
	parry_window = 0.0
	_set_beam_state(BEAM_STATE_SHEATHING, 0.24)
	beam_charging = true
	beam_charge_time = 0.0
	beam_pending_ratio = 0.0
	beam_release_elapsed = 0.0
	beam_release_emitted = false
	beam_cancel_reason = ""
	beam_release_direction = Vector3.ZERO
	equipment_loadout.stow_all()
	return true

func _commit_oathfire_release(ratio: float) -> void:
	if beam_locked_direction.length_squared() < 0.5:
		_lock_beam_direction()
	beam_locked_direction.y = 0.0
	beam_locked_direction = beam_locked_direction.normalized()
	beam_pending_ratio = clampf(ratio, 0.0, 1.0)
	beam_release_elapsed = 0.0
	beam_release_emitted = false
	beam_release_direction = beam_locked_direction
	beam_cooldown = get_oathfire_cooldown_duration()
	attack_cooldown = 0.75
	beam_charging = false
	_set_beam_state(BEAM_STATE_RELEASING, 0.34)
	_update_beam_charge_visual()

func _update_beam_sequence(delta: float) -> void:
	if beam_cast_state == BEAM_STATE_IDLE:
		return
	if beam_locked_direction.length_squared() > 0.5:
		face_target(global_position + beam_locked_direction * 4.0)
	beam_state_time = max(beam_state_time - delta, 0.0)
	if beam_cast_state == BEAM_STATE_SHEATHING and beam_state_time <= 0.0:
		if _action_pressed("oathfire_beam"):
			_set_beam_state(BEAM_STATE_CHARGING, 0.0)
			if animation_driver != null:
				animation_driver.trigger_action("beam_cast")
			_update_beam_charge_visual()
		else:
			_begin_beam_redraw()
	elif beam_cast_state == BEAM_STATE_RELEASING:
		beam_release_elapsed += delta
		_update_beam_charge_visual()
		if not beam_release_emitted and beam_release_elapsed >= 0.11:
			beam_release_emitted = true
			beam_requested.emit(beam_pending_ratio, beam_release_direction if beam_release_direction.length_squared() > 0.5 else beam_locked_direction)
			_hide_beam_charge_visuals()
		if beam_state_time <= 0.0:
			_begin_beam_redraw()
	elif beam_cast_state == BEAM_STATE_REDRAWING and beam_state_time <= 0.0 and not equipment_loadout.is_transitioning():
		_set_beam_state(BEAM_STATE_IDLE)
		beam_charging = false
		beam_charge_time = 0.0
		beam_locked_direction = Vector3.ZERO
		beam_pending_ratio = 0.0
		beam_release_elapsed = 0.0
		beam_release_emitted = false
		beam_release_direction = Vector3.ZERO
		_restore_oathfire_equipment()

func _begin_beam_redraw() -> void:
	beam_charging = false
	var restored_mode := str(beam_restore_equipment.get("active_weapon", weapon_mode))
	var drawn := bool(beam_restore_equipment.get("bow_drawn" if restored_mode == "bow" else "sword_drawn", false))
	_set_beam_state(BEAM_STATE_REDRAWING, EquipmentLoadout.DRAW_SECONDS if drawn else 0.14)
	_hide_beam_charge_visuals()
	if animation_driver != null and animation_driver.has_method("stop_action"):
		animation_driver.stop_action("idle", 0.12)
	equipment_loadout.request_loadout(restored_mode, str(beam_restore_equipment.get("selected_blade_id", get_selected_blade_id())), drawn)

func _restore_oathfire_equipment() -> void:
	if beam_restore_equipment.is_empty():
		return
	var saved := beam_restore_equipment.duplicate(true)
	beam_restore_equipment.clear()
	equipment_loadout.load_state(saved)
	selected_arrow_id = equipment_loadout.selected_arrow_id

func _draw_sword_for_combat() -> void:
	if sword_sheathed:
		equipment_loadout.request_loadout("sword", get_selected_blade_id(), true)

func cancel_beam_charge(reason: String = "cancelled") -> void:
	var was_active := beam_cast_state != BEAM_STATE_IDLE or beam_charging or beam_locked_direction.length_squared() > 0.5
	beam_charging = false
	beam_charge_time = 0.0
	_set_beam_state(BEAM_STATE_IDLE)
	beam_state_time = 0.0
	beam_locked_direction = Vector3.ZERO
	beam_pending_ratio = 0.0
	beam_release_elapsed = 0.0
	beam_release_emitted = false
	beam_release_direction = Vector3.ZERO
	beam_cancel_reason = reason if was_active else ""
	if was_active:
		beam_phase_changed.emit("cancelled")
	_hide_beam_charge_visuals()
	if animation_driver != null and animation_driver.has_method("stop_action"):
		animation_driver.stop_action("idle", 0.12)
	_restore_oathfire_equipment()

func _lock_beam_direction() -> Vector3:
	beam_locked_direction = -global_transform.basis.z
	beam_locked_direction.y = 0.0
	if beam_locked_direction.length_squared() < 0.5:
		beam_locked_direction = Vector3.FORWARD
	beam_locked_direction = beam_locked_direction.normalized()
	return beam_locked_direction

func get_beam_locked_direction() -> Vector3:
	return beam_locked_direction

func get_oathfire_state() -> Dictionary:
	var charge_ratio := beam_pending_ratio if beam_cast_state == BEAM_STATE_RELEASING else clampf(beam_charge_time / 1.25, 0.0, 1.0)
	return {
		"state": beam_cast_state,
		"state_sequence": beam_state_sequence,
		"charge_ratio": charge_ratio,
		"charge_time": beam_charge_time,
		"cooldown": beam_cooldown,
		"locked_direction": beam_locked_direction,
		"release_direction": beam_release_direction,
		"sword_sheathed": sword_sheathed,
		"charge_visible": beam_charge_visual != null and beam_charge_visual.visible,
		"hands_visible": beam_left_hand_glow != null and beam_left_hand_glow.visible and beam_right_hand_glow != null and beam_right_hand_glow.visible,
		"release_emitted": beam_release_emitted,
		"cancel_reason": beam_cancel_reason,
	}

func get_oathfire_origin() -> Vector3:
	var left := _live_oathfire_hand_origin(beam_left_hand_socket, beam_left_hand_glow, global_position + Vector3(-0.16, 1.28, -0.48))
	var right := _live_oathfire_hand_origin(beam_right_hand_socket, beam_right_hand_glow, global_position + Vector3(0.16, 1.28, -0.48))
	var direction: Vector3 = beam_locked_direction if beam_locked_direction.length_squared() > 0.5 else -global_transform.basis.z.normalized()
	return left.lerp(right, 0.5) + direction * 0.24

func _live_oathfire_hand_origin(socket: BoneAttachment3D, glow: MeshInstance3D, fallback: Vector3) -> Vector3:
	if socket != null:
		var skeleton := socket.get_parent() as Skeleton3D
		if skeleton != null and socket.bone_idx >= 0:
			return (skeleton.global_transform * skeleton.get_bone_global_pose(socket.bone_idx)).origin
	if glow != null:
		return glow.global_position
	return fallback

func _update_beam_charge_visual() -> void:
	if beam_charge_visual == null:
		return
	beam_charge_visual.visible = true
	var ratio: float = beam_pending_ratio if beam_cast_state == "releasing" else clampf(beam_charge_time / 1.25, 0.0, 1.0)
	var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.07
	beam_charge_visual.scale = Vector3.ONE * lerpf(0.08, 0.28, ratio) * pulse
	beam_charge_visual.global_position = get_oathfire_origin()
	if beam_left_hand_glow != null:
		beam_left_hand_glow.visible = true
		beam_left_hand_glow.scale = Vector3.ONE * lerpf(0.55, 0.95, ratio)
	if beam_right_hand_glow != null:
		beam_right_hand_glow.visible = true
		beam_right_hand_glow.scale = Vector3.ONE * lerpf(0.55, 0.95, ratio)

func _hide_beam_charge_visuals() -> void:
	for glow in [beam_charge_visual, beam_left_hand_glow, beam_right_hand_glow]:
		if glow != null:
			glow.visible = false

func _set_sword_sheathed(sheathed: bool) -> void:
	sword_sheathed = sheathed
	if sheathed and slash_arc_root != null:
		slash_arc_root.visible = false

func is_blocking() -> bool:
	return weapon_mode == "sword" and not sword_sheathed and not equipment_loadout.is_transitioning() and _action_pressed("block") and stamina_component.stamina > 8.0

func take_damage(amount: float) -> bool:
	amount *= float(difficulty_profile.get("incoming_damage_multiplier", 1.0))
	if dodge_time > 0.0:
		return false
	if parry_window > 0.0 and stamina_component.spend(10.0):
		parry_window = 0.0
		hurt_flash_time = 0.0
		hurt_react_time = 0.0
		if animation_driver != null:
			animation_driver.trigger_action("parry", 1.0, 0.04, true)
		parried.emit()
		return true
	var guarded := is_blocking()
	_cancel_equipment_action()
	if beam_cast_state != BEAM_STATE_IDLE:
		cancel_beam_charge("hit")
	if guarded and stamina_component.spend(12.0):
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
	_cancel_equipment_action()
	cancel_beam_charge("death")
	equipment_loadout.stow_all()
	can_control = false
	if animation_driver != null:
		animation_driver.set_dead()
	died.emit()

func _build_body() -> void:
	visual_root = Node3D.new()
	add_child(visual_root)
	var collision = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.height = CharacterRoleSpec.collision_height("player_human", 1.65)
	capsule_shape.radius = CharacterRoleSpec.collision_radius("player_human", 0.32)
	collision.shape = capsule_shape
	# CapsuleShape3D.height is the complete capsule height, including its
	# hemispheres. Keep its base on the actor root so low bridge lips and
	# authored ramps are treated as walkable ground instead of a wall.
	collision.position.y = capsule_shape.height * 0.5
	add_child(collision)
	if _try_build_mapped_body():
		CharacterPresentation.apply_player(self, visual_root)
		_add_beam_charge_visual()
		_set_sword_sheathed(true)
		return

	# Required character roles never receive procedural anatomy. Keeping the
	# controller/collision shell alive makes the failure diagnosable without
	# shipping a faceless polygon as the player.
	visual_root.set_meta("character_visual_failure", true)
	push_error("Player visual role could not be built; refusing primitive fallback")

func _add_beam_charge_visual() -> void:
	beam_charge_visual = MeshInstance3D.new()
	beam_charge_visual.name = "OathfireChargeSphere"
	beam_charge_visual.mesh = SphereMesh.new()
	beam_charge_visual.material_override = _beam_material(Color(0.35, 0.88, 1.0, 0.92))
	beam_charge_visual.visible = false
	add_child(beam_charge_visual)
	var skeleton := _find_skeleton(visual_root)
	beam_left_hand_glow = _make_oathfire_hand("OathfireLeftHand", skeleton, ["LeftHand", "Hand.L", "Fist.L", "FistL", "lefthand", "leftwrist"], Vector3(-0.28, 1.22, -0.42))
	beam_right_hand_glow = _make_oathfire_hand("OathfireRightHand", skeleton, ["RightHand", "Hand.R", "Weapon.R", "WeaponR", "Fist.R", "FistR", "righthand", "rightwrist"], Vector3(0.28, 1.22, -0.42))
	if skeleton != null:
		beam_left_arm_ik = _make_arm_pose_ik(skeleton, "OathfireLeftArmPose", &"upperarm_l", &"hand_l")
		beam_right_arm_ik = _make_arm_pose_ik(skeleton, "OathfireRightArmPose", &"upperarm_r", &"hand_r")
	_build_sheathed_sword()
	_build_bow_visual()
	_ensure_equipment_loadout()

func _make_arm_pose_ik(skeleton: Skeleton3D, node_name: String, root_bone: StringName, tip_bone: StringName) -> SkeletonIK3D:
	if skeleton.find_bone(root_bone) < 0 or skeleton.find_bone(tip_bone) < 0:
		return null
	var solver := SkeletonIK3D.new()
	solver.name = node_name
	solver.root_bone = root_bone
	solver.tip_bone = tip_bone
	solver.override_tip_basis = false
	solver.max_iterations = 12
	skeleton.add_child(solver)
	return solver

func _update_oathfire_arm_pose() -> void:
	var enabled := beam_cast_state in [BEAM_STATE_CHARGING, BEAM_STATE_RELEASING]
	if enabled and beam_left_arm_ik != null and beam_right_arm_ik != null:
		var forward := -global_basis.z.normalized()
		var right := global_basis.x.normalized()
		var center := global_position + Vector3.UP * 1.18 + forward * 0.43
		beam_left_arm_ik.target = Transform3D(Basis.IDENTITY, center - right * 0.12)
		beam_right_arm_ik.target = Transform3D(Basis.IDENTITY, center + right * 0.12)
		beam_left_arm_ik.influence = 1.0
		beam_right_arm_ik.influence = 1.0
		beam_left_arm_ik.start(true)
		beam_right_arm_ik.start(true)
		beam_arm_pose_applied = true
	elif beam_arm_pose_applied:
		if beam_left_arm_ik != null:
			beam_left_arm_ik.stop()
		if beam_right_arm_ik != null:
			beam_right_arm_ik.stop()
		beam_arm_pose_applied = false

func _make_oathfire_hand(node_name: String, skeleton: Skeleton3D, aliases: Array[String], fallback_position: Vector3) -> MeshInstance3D:
	var glow := MeshInstance3D.new()
	glow.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.10
	mesh.height = 0.20
	glow.mesh = mesh
	glow.material_override = _beam_material(Color(0.38, 0.82, 1.0, 0.58))
	glow.visible = false
	var socket_parent: Node3D = visual_root
	if skeleton != null:
		var hand_index := _find_bone_index(skeleton, aliases)
		if hand_index < 0:
			var wants_left := node_name.contains("Left")
			for bone_index in range(skeleton.get_bone_count()):
				var bone_name := str(skeleton.get_bone_name(bone_index)).to_lower()
				var is_hand := bone_name.contains("hand") or bone_name.contains("wrist")
				var is_side := bone_name.contains("left") or bone_name.contains("_l") or bone_name.ends_with(".l") if wants_left else bone_name.contains("right") or bone_name.contains("_r") or bone_name.ends_with(".r")
				if is_hand and is_side:
					hand_index = bone_index
					break
		if hand_index >= 0:
			var attachment := BoneAttachment3D.new()
			attachment.name = "%sSocket" % node_name
			attachment.bone_idx = hand_index
			attachment.bone_name = skeleton.get_bone_name(hand_index)
			skeleton.add_child(attachment)
			# Imported rigs carry source-scale transforms on their skeleton. Cancel
			# that scale before adding the glow so a 20 cm hand effect cannot become
			# a multi-metre object or corrupt the rendered character bounds.
			socket_parent = _create_equipment_space(attachment, "%sEquipmentSpace" % node_name)
			if node_name.contains("Left"):
				beam_left_hand_socket = attachment
			else:
				beam_right_hand_socket = attachment
	socket_parent.add_child(glow)
	if socket_parent == visual_root:
		glow.position = fallback_position
	return glow

func _build_bow_visual() -> void:
	if bow_visual != null:
		return
	var skeleton := _find_skeleton(visual_root)
	var hand_parent: Node3D = visual_root
	if skeleton != null:
		var hand_index := _find_bone_index(skeleton, ["LeftHand", "Hand.L", "Fist.L", "FistL", "hand_l", "lefthand"])
		if hand_index >= 0:
			bow_attachment = BoneAttachment3D.new()
			bow_attachment.name = "KaelBowHandSocket"
			bow_attachment.bone_idx = hand_index
			bow_attachment.bone_name = skeleton.get_bone_name(hand_index)
			skeleton.add_child(bow_attachment)
			hand_parent = _create_equipment_space(bow_attachment, "KaelBowHandEquipmentSpace")
	bow_visual = Node3D.new()
	bow_visual.name = "KaelBowHandEquipment"
	bow_visual.position = Vector3(0.04, -0.02, 0.04) if hand_parent != visual_root else Vector3(-0.38, 1.20, 0.20)
	bow_visual.rotation_degrees = Vector3(0.0, 8.0, -12.0)
	bow_visual.scale = Vector3.ONE * 0.82
	bow_visual.visible = false
	hand_parent.add_child(bow_visual)
	var modeled_bow := _instantiate_modeled_prop(MODELED_BOW_PATH)
	if modeled_bow != null:
		modeled_bow.name = "KaelBowModeled"
		# The Ranger prop is authored along local Y, like the sword. Normalize the
		# source once inside the existing hand socket; the controller still owns
		# aim, draw, release, and visibility state.
		modeled_bow.scale = Vector3.ONE * 0.30
		modeled_bow.position = Vector3(0.04, -0.01, 0.04)
		_prepare_modeled_prop(modeled_bow, Color(0.24, 0.12, 0.055))
		modeled_bow.set_meta("equipment_visual_source", MODELED_BOW_PATH)
		bow_visual.set_meta("equipment_visual_source", MODELED_BOW_PATH)
		bow_visual.add_child(modeled_bow)
	else:
		bow_visual.set_meta("equipment_visual_failure", MODELED_BOW_PATH)
		push_error("Modeled bow source could not be loaded: %s" % MODELED_BOW_PATH)
	var quiver_parent: Node3D = visual_root
	if skeleton != null:
		var back_index := _find_bone_index(skeleton, ["spine_03", "spine_02", "Spine3", "Spine2", "Chest", "Torso", "Spine", "Body"])
		if back_index >= 0:
			bow_quiver_attachment = BoneAttachment3D.new()
			bow_quiver_attachment.name = "KaelQuiverBackSocket"
			bow_quiver_attachment.bone_idx = back_index
			bow_quiver_attachment.bone_name = skeleton.get_bone_name(back_index)
			skeleton.add_child(bow_quiver_attachment)
			quiver_parent = _create_equipment_space(bow_quiver_attachment, "KaelQuiverBackEquipmentSpace")
	if quiver_parent != visual_root:
		bow_back_visual = Node3D.new()
		bow_back_visual.name = "KaelStowedBow"
		bow_back_visual.position = Vector3(-0.25, 0.16, -0.36)
		bow_back_visual.rotation_degrees = Vector3(0.0, 0.0, 24.0)
		bow_back_visual.scale = Vector3.ONE * 0.82
		quiver_parent.add_child(bow_back_visual)
		var stowed_bow := _instantiate_modeled_prop(MODELED_BOW_PATH)
		if stowed_bow != null:
			stowed_bow.scale = Vector3.ONE * 0.30
			stowed_bow.position = Vector3(0.04, -0.01, 0.04)
			_prepare_modeled_prop(stowed_bow, Color(0.24, 0.12, 0.055))
			bow_back_visual.add_child(stowed_bow)
	if skeleton != null:
		equipment_left_arm_ik = _make_arm_pose_ik(skeleton, "BowEquipmentReach", &"upperarm_l", &"hand_l")
	bow_quiver_visual = Node3D.new()
	bow_quiver_visual.name = "KaelQuiverBackEquipment"
	bow_quiver_visual.position = Vector3(-0.22, -0.12, 0.16) if quiver_parent != visual_root else Vector3(-0.22, 1.05, 0.28)
	bow_quiver_visual.rotation_degrees = Vector3(12.0, 0.0, -18.0)
	quiver_parent.add_child(bow_quiver_visual)
	var quiver := MeshInstance3D.new()
	quiver.name = "KaelArrowQuiver"
	var quiver_mesh := CylinderMesh.new()
	quiver_mesh.top_radius = 0.08
	quiver_mesh.bottom_radius = 0.06
	quiver_mesh.height = 0.60
	quiver_mesh.radial_segments = 8
	quiver.mesh = quiver_mesh
	quiver.material_override = _mat(Color(0.12, 0.07, 0.035))
	bow_quiver_visual.add_child(quiver)
	var modeled_arrow := _instantiate_modeled_prop(MODELED_ARROW_PATH)
	if modeled_arrow != null:
		modeled_arrow.name = "KaelQuiverArrow"
		modeled_arrow.scale = Vector3.ONE * 0.30
		modeled_arrow.position = Vector3(0.0, -0.18, 0.0)
		_prepare_modeled_prop(modeled_arrow, Color(0.58, 0.42, 0.24))
		modeled_arrow.set_meta("equipment_visual_source", MODELED_ARROW_PATH)
		bow_quiver_visual.add_child(modeled_arrow)
	else:
		bow_quiver_visual.set_meta("equipment_visual_failure", MODELED_ARROW_PATH)
		push_error("Modeled arrow source could not be loaded: %s" % MODELED_ARROW_PATH)

func _instantiate_modeled_prop(path: String) -> Node3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if asset_helper != null and asset_helper.has_method("load_runtime_resource") and asset_helper.has_method("instantiate_runtime_resource"):
		var cached_resource = asset_helper.load_runtime_resource(path)
		var cached_instance: Node3D = asset_helper.instantiate_runtime_resource(cached_resource)
		if cached_instance != null:
			return cached_instance
	var resource = ResourceLoader.load(path)
	if resource is PackedScene:
		var instance := (resource as PackedScene).instantiate()
		return instance as Node3D
	if resource is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = resource as Mesh
		return mesh_instance
	return null

func _prepare_modeled_prop(root: Node3D, fallback_color: Color) -> void:
	if root == null:
		return
	for raw_mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_surface_override_material(surface_index)
			if material == null:
				material = mesh_instance.mesh.surface_get_material(surface_index)
			if material == null:
				mesh_instance.set_surface_override_material(surface_index, _mat(fallback_color))

func _build_sheathed_sword() -> void:
	var skeleton := _find_skeleton(visual_root)
	if skeleton == null:
		push_error("Kael's back equipment requires his character skeleton")
		return
	var back_index := _find_bone_index(skeleton, ["spine_03", "spine_02", "Spine3", "Spine2", "Chest", "Torso", "Spine", "Body"])
	if back_index < 0:
		push_error("Kael's back equipment requires a validated spine bone")
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "KaelBackSwordSocket"
	attachment.bone_idx = back_index
	attachment.bone_name = skeleton.get_bone_name(back_index)
	skeleton.add_child(attachment)
	var socket_parent := _create_equipment_space(attachment, "KaelBackSwordEquipmentSpace")
	sheathed_sword_visual = Node3D.new()
	sheathed_sword_visual.name = "KaelBackScabbards"
	socket_parent.add_child(sheathed_sword_visual)
	var scabbard_mesh := _build_scabbard_mesh()
	for blade_id: String in EquipmentLoadout.BLADE_IDS:
		var oath := blade_id == "oathblade"
		var assembly := Node3D.new()
		assembly.name = "OathbladeBackScabbard" if oath else "SteelBackScabbard"
		assembly.position = Vector3(0.12 if oath else -0.08, 0.27, -0.28)
		assembly.rotation_degrees = Vector3(-10.0, 0.0, -32.0)
		sheathed_sword_visual.add_child(assembly)
		blade_scabbards[blade_id] = assembly
		var housed_blade := Node3D.new()
		housed_blade.name = "HousedOathblade" if oath else "HousedSteel"
		assembly.add_child(housed_blade)
		housed_blade.set_meta("blade_id", blade_id)
		if not _attach_modeled_sword(housed_blade, blade_id):
			push_error("Back sword source could not be loaded: " + MODELED_SWORD_PATH)
		blade_back_visuals[blade_id] = housed_blade
		var scabbard := MeshInstance3D.new()
		scabbard.name = "ScabbardBody"
		scabbard.mesh = scabbard_mesh
		scabbard.material_override = _mat(Color(0.045, 0.075, 0.080) if oath else Color(0.075, 0.065, 0.055))
		assembly.add_child(scabbard)
		var trim := _metal_mat(Color(0.46, 0.53, 0.54) if oath else Color(0.42, 0.30, 0.16))
		var throat := MeshInstance3D.new()
		throat.name = "ScabbardThroat"
		var throat_mesh := CylinderMesh.new()
		throat_mesh.top_radius = 1.0
		throat_mesh.bottom_radius = 1.0
		throat_mesh.height = 0.035
		throat_mesh.radial_segments = 8
		throat.mesh = throat_mesh
		throat.scale = Vector3(0.061, 1.0, 0.026)
		throat.position = Vector3(0.0, -0.065, 0.0)
		throat.material_override = trim
		assembly.add_child(throat)
		var cap := MeshInstance3D.new()
		cap.name = "ScabbardCap"
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = 0.025
		cap_mesh.height = 0.05
		cap_mesh.radial_segments = 8
		cap_mesh.rings = 3
		cap.mesh = cap_mesh
		cap.scale.z = 0.65
		cap.position = Vector3(0.0, -0.835, 0.0)
		cap.material_override = trim
		assembly.add_child(cap)

func _build_scabbard_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var section := [Vector2(-0.75, -1), Vector2(0.75, -1), Vector2(1, -0.65), Vector2(1, 0.65), Vector2(0.75, 1), Vector2(-0.75, 1), Vector2(-1, 0.65), Vector2(-1, -0.65)]
	var profiles := [Vector3(0.058, -0.065, 0.024), Vector3(0.048, -0.68, 0.021), Vector3(0.020, -0.835, 0.016)]
	for ring in range(profiles.size() - 1):
		for side in range(section.size()):
			var next := (side + 1) % section.size()
			var a: Vector3 = profiles[ring]
			var b: Vector3 = profiles[ring + 1]
			var vertices := [Vector3(section[side].x * a.x, a.y, section[side].y * a.z), Vector3(section[next].x * a.x, a.y, section[next].y * a.z), Vector3(section[next].x * b.x, b.y, section[next].y * b.z), Vector3(section[side].x * b.x, b.y, section[side].y * b.z)]
			for index in [0, 2, 1, 0, 3, 2]:
				surface.add_vertex(vertices[index])
	surface.generate_normals()
	return surface.commit()

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
	visual_root.add_child(mapped)
	var imported_sword := mapped.find_child("Warrior_Sword", true, false) as Node3D
	if imported_sword != null:
		imported_sword.visible = false
	rig_sword_visual = _attach_rig_sword(mapped)
	if rig_sword_visual != null:
		# Oathblade geometry is authored along local -Y. Keep the contact
		# contract on that same axis so the damage sweep and the rendered blade
		# cannot diverge into the old detached-pole presentation.
		_configure_blade_markers(rig_sword_visual, Vector3(0, -0.08, 0), Vector3(0, -1.04, 0), true)
		# Establish the authored ready pose before the first physics tick. Capture
		# tools and dialogue staging can sample the rig before _animate_visuals runs;
		# leaving the imported hand axis untouched makes the sword read as a pole.
		_update_sword_equipment_pose(0.0, 0.0, 0.0, false, false)
	body_visual = _find_first_mesh(mapped)
	_apply_visible_material_fallbacks(mapped, _mat(Color(0.18, 0.20, 0.18)))
	if body_visual != null and body_visual.material_override is StandardMaterial3D:
		body_base_color = (body_visual.material_override as StandardMaterial3D).albedo_color
	animation_driver = CharacterAnimationDriver.new()
	animation_driver.name = "CharacterAnimationDriver"
	mapped.add_child(animation_driver)
	var animated: bool = bool(animation_driver.configure(mapped, _animation_map_for_visual(mapped)))
	if not animated:
		if rig_sword_visual == null:
			_add_mapped_weapon_visuals()
	else:
		animation_driver.set_update_rate_hz(30.0)
		animation_driver.set_external_tick(true)
		var foot_rig: Skeleton3D = animation_driver.get_skeleton()
		if foot_rig != null and foot_rig.get_node_or_null("GroundedFeet") == null:
			var grounding := preload("res://scripts/grounded_feet_modifier.gd").new()
			grounding.name = "GroundedFeet"
			foot_rig.add_child(grounding)
			grounding.configure(self, foot_rig)
		if animation_driver.has_signal("locomotion_step") and not animation_driver.locomotion_step.is_connected(_on_animation_locomotion_step):
			animation_driver.locomotion_step.connect(_on_animation_locomotion_step)
			animation_step_signal_bound = true
		_add_slash_arc_visuals()
	return true

func _animation_map_for_visual(mapped: Node3D) -> Dictionary:
	var family := str(mapped.get_meta("character_animation_family", "")).to_lower()
	if family.contains("warrior"):
		return {
			"idle": "Idle", "walk": "Walk", "walk_back": "Walk_Back", "strafe": "Walk", "run": "Run", "run_back": "Run_Back",
			"jump": "Roll", "attack_light": "Sword_Attack", "attack_heavy": "Sword_Attack2",
			"dodge": "Roll", "parry": "Idle_Weapon", "beam_cast": "Idle_Weapon",
			"hit": "RecieveHit", "death": "Death"
		}
	if family.contains("cleric"):
		return {
			"idle": "Idle", "walk": "Walk", "walk_back": "Walk_Back", "strafe": "Walk", "run": "Run", "run_back": "Run_Back",
			"jump": "Run", "attack_light": "Staff_Attack", "attack_heavy": "Staff_Attack",
			"dodge": "Run", "parry": "Idle_Weapon", "beam_cast": "Spell1",
			"hit": "RecieveHit", "death": "Death"
		}
	if family.contains("rogue"):
		return {
			"idle": "Idle", "walk": "Walk", "walk_back": "Walk_Back", "strafe": "Walk", "run": "Run", "run_back": "Run_Back",
			"jump": "Roll", "attack_light": "Dagger_Attack", "attack_heavy": "Dagger_Attack2",
			"dodge": "Roll", "parry": "Attacking_Idle", "beam_cast": "Attacking_Idle",
			"hit": "RecieveHit", "death": "Death"
		}
	if family.contains("monk"):
		return {
			"idle": "Idle", "walk": "Walk", "walk_back": "Walk_Back", "strafe": "Walk", "run": "Run", "run_back": "Run_Back",
			"jump": "Roll", "attack_light": "Attack", "attack_heavy": "Attack2",
			"dodge": "Roll", "parry": "Idle_Attacking", "beam_cast": "Idle_Attacking",
			"hit": "RecieveHit", "death": "Death"
		}
	return {
		"idle": "Idle", "walk": "Walk", "walk_back": "Walk_Back", "strafe": "Walk", "run": "Sprint", "run_back": "Run_Back",
		"jump": "Jump_Start", "attack_light": "Sword_Attack", "attack_heavy": "Sword_Attack_RM",
		"dodge": "Roll", "parry": "Sword_Idle", "beam_cast": "Spell_Simple_Idle",
		"hit": "Hit_Chest", "death": "Death01"
	}

func _attach_rig_sword(mapped: Node3D) -> Node3D:
	var skeleton := _find_skeleton(mapped)
	if skeleton == null:
		return null
	var hand_index := skeleton.find_bone("RightHand")
	if hand_index < 0:
		hand_index = skeleton.find_bone("Hand.R")
	if hand_index < 0:
		hand_index = skeleton.find_bone("hand_r")
	if hand_index < 0:
		hand_index = skeleton.find_bone("Weapon.R")
	if hand_index < 0:
		hand_index = skeleton.find_bone("Fist.R")
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
	sword_attachment = attachment
	if skeleton.find_bone("upperarm_r") >= 0 and skeleton.get_bone_name(hand_index) == "hand_r":
		guard_arm_ik = SkeletonIK3D.new()
		guard_arm_ik.name = "GuardArmPose"
		guard_arm_ik.root_bone = &"upperarm_r"
		guard_arm_ik.tip_bone = &"hand_r"
		guard_arm_ik.override_tip_basis = false
		guard_arm_ik.max_iterations = 12
		skeleton.add_child(guard_arm_ik)
	var equipment_space := _create_equipment_space(attachment, "KaelSwordEquipmentSpace")
	sword_equipment_pivot = Node3D.new()
	sword_equipment_pivot.name = "KaelSwordGripPivot"
	equipment_space.add_child(sword_equipment_pivot)
	# The pivot remains inside the normalized hand attachment hierarchy. Its
	# grip basis is calibrated from the imported hand once the skeleton is live;
	# subsequent poses preserve that hand frame and add only deliberate combat
	# motion. This prevents the weapon from becoming a detached world object.
	sword_grip_basis = Basis.IDENTITY
	sword_grip_calibrated = false
	# The imported FBX had null Compatibility surfaces and was hidden
	# immediately. Use the validated Web-safe weapon directly.
	var held_blades := Node3D.new()
	held_blades.name = "KaelHeldBlades"
	sword_equipment_pivot.add_child(held_blades)
	for blade_id: String in EquipmentLoadout.BLADE_IDS:
		blade_hand_visuals[blade_id] = _build_oathblade_visual(held_blades, blade_id)
	return held_blades

func _build_oathblade_visual(parent: Node3D, blade_id: String = "steel") -> Node3D:
	var oathblade := Node3D.new()
	oathblade.name = "KaelOathblade" if blade_id == "oathblade" else "KaelSteelSword"
	oathblade.set_meta("blade_id", blade_id)
	# The hand, markers, slash ribbon, and collision all share this normalized
	# weapon root. Prefer the authored Quaternius sword; its FBX importer keeps
	# a 100x source-unit transform, so the child is normalized once here rather
	# than allowing that source scale to leak into the hand socket.
	oathblade.scale = Vector3.ONE
	parent.add_child(oathblade)
	if _attach_modeled_sword(oathblade, blade_id):
		oathblade.set_meta("weapon_visual_source", MODELED_SWORD_PATH)
		return oathblade
	# Keep a local diagnostic fallback for a missing imported source. The runtime
	# asset gate still rejects that state; this branch exists only to keep native
	# tools able to report the missing asset without silently losing the socket.
	push_error("Modeled sword source could not be loaded: %s" % MODELED_SWORD_PATH)
	var steel := _metal_mat(Color(0.84, 0.88, 0.92))
	steel.metallic = 0.72
	steel.roughness = 0.20
	steel.emission_enabled = true
	steel.emission = Color(0.055, 0.065, 0.075)
	steel.emission_energy_multiplier = 0.22
	steel.emission_enabled = false
	steel.cull_mode = BaseMaterial3D.CULL_DISABLED
	var blade := MeshInstance3D.new()
	blade.name = "OathbladeSteel"
	blade.mesh = _build_oathblade_mesh()
	blade.material_override = steel
	oathblade.add_child(blade)
	var guard := MeshInstance3D.new()
	guard.name = "OathbladeGuard"
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.25, 0.055, 0.072)
	guard.mesh = guard_mesh
	guard.position = Vector3(0.0, -0.075, 0.0)
	guard.material_override = _metal_mat(Color(0.64, 0.43, 0.17))
	oathblade.add_child(guard)
	var grip := MeshInstance3D.new()
	grip.name = "OathbladeGrip"
	var grip_mesh := CylinderMesh.new()
	grip_mesh.top_radius = 0.028
	grip_mesh.bottom_radius = 0.032
	grip_mesh.height = 0.19
	grip_mesh.radial_segments = 8
	grip.mesh = grip_mesh
	grip.position = Vector3(0.0, 0.065, 0.0)
	grip.material_override = _mat(Color(0.18, 0.07, 0.035))
	oathblade.add_child(grip)
	var pommel := MeshInstance3D.new()
	pommel.name = "OathbladePommel"
	var pommel_mesh := SphereMesh.new()
	pommel_mesh.radius = 0.045
	pommel_mesh.height = 0.09
	pommel.mesh = pommel_mesh
	pommel.position = Vector3(0.0, 0.18, 0.0)
	pommel.material_override = _metal_mat(Color(0.52, 0.34, 0.15))
	oathblade.add_child(pommel)
	return oathblade

func _attach_modeled_sword(oathblade: Node3D, blade_id: String = "steel") -> bool:
	var modeled: Node3D = null
	if asset_helper != null and asset_helper.has_method("load_runtime_resource") and asset_helper.has_method("instantiate_runtime_resource"):
		var resource = asset_helper.load_runtime_resource(MODELED_SWORD_PATH)
		modeled = asset_helper.instantiate_runtime_resource(resource)
	else:
		var resource = ResourceLoader.load(MODELED_SWORD_PATH)
		if resource is PackedScene:
			var instance := (resource as PackedScene).instantiate()
			if instance is Node3D:
				modeled = instance as Node3D
	if modeled == null:
		return false
	modeled.name = "OathbladeModeledMesh"
	# The imported Sword mesh is authored along its local +Y after the FBX
	# conversion. Flip it so the hilt stays at the hand and the blade extends
	# down local -Y, matching the existing contact-marker contract.
	modeled.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	# Both blades retain the same physical reach; cross-section and finish differ.
	modeled.scale = (Vector3(1.12, 1.0, 0.92) if blade_id == "oathblade" else Vector3.ONE) * 0.22
	modeled.position = Vector3(0.0, 0.045, 0.0)
	oathblade.add_child(modeled)
	var mesh_count := 0
	var canonical_blade: MeshInstance3D = null
	var finish := _metal_mat(Color(0.65, 0.80, 0.82) if blade_id == "oathblade" else Color(0.78, 0.82, 0.88))
	for raw_mesh in modeled.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		mesh_count += 1
		if canonical_blade == null:
			canonical_blade = mesh_instance
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		# The imported FBX carries named materials, but their source values are
		# too dark for the browser lighting profile. Keep the authored mesh and
		# replace only the presentation material with a readable blade finish.
		mesh_instance.material_override = finish
		if mesh_instance.mesh.get_surface_count() == 0:
			mesh_instance.material_override = _metal_mat(Color(0.72, 0.78, 0.82))
		else:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var material := mesh_instance.get_surface_override_material(surface_index)
				if material == null:
					material = mesh_instance.mesh.surface_get_material(surface_index)
				if material == null:
					mesh_instance.set_surface_override_material(surface_index, _metal_mat(Color(0.72, 0.78, 0.82)))
	if canonical_blade != null:
		# Keep the imported geometry as the single source of truth while exposing
		# the stable blade contract used by contact, visuals, and release gates.
		canonical_blade.name = "OathbladeSteel"
		canonical_blade.set_meta("modeled_blade", true)
	return mesh_count > 0 and canonical_blade != null

func _build_oathblade_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var vertices := [
		# A restrained single-edged hunter blade: narrow shoulder, shallow
		# fuller, and a centered point. The previous 15 cm shoulder made the
		# weapon read as a pale wedge at gameplay distance.
		Vector3(-0.050, -0.10, 0.026), Vector3(0.050, -0.10, 0.026), Vector3(0.034, -0.72, 0.018),
		Vector3(-0.034, -0.72, 0.018), Vector3(0.0, -1.02, 0.0),
		Vector3(-0.050, -0.10, -0.026), Vector3(0.050, -0.10, -0.026), Vector3(0.034, -0.72, -0.018),
		Vector3(-0.034, -0.72, -0.018), Vector3(0.0, -1.02, 0.0)
	]
	var faces := [
		[0, 1, 2], [0, 2, 3], [5, 7, 6], [5, 8, 7], [3, 2, 4], [8, 9, 4],
		[0, 5, 6], [0, 6, 1], [1, 6, 7], [1, 7, 2], [2, 7, 9], [2, 9, 4],
		[4, 9, 8], [4, 8, 3], [3, 8, 5], [3, 5, 0]
	]
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var a: Vector3 = vertices[face[0]]
		var b: Vector3 = vertices[face[1]]
		var c: Vector3 = vertices[face[2]]
		var normal := (b - a).cross(c - a).normalized()
		mesh.surface_set_normal(normal)
		mesh.surface_add_vertex(a)
		mesh.surface_set_normal(normal)
		mesh.surface_add_vertex(b)
		mesh.surface_set_normal(normal)
		mesh.surface_add_vertex(c)
	mesh.surface_end()
	return mesh

func _update_sword_equipment_pose(windup: float, strike: float, recovery: float, heavy: bool, attacking: bool) -> void:
	if sword_equipment_pivot == null or sword_attachment == null:
		return
	var skeleton := sword_attachment.get_parent() as Skeleton3D
	var native_grip := skeleton != null and sword_attachment.bone_name == &"hand_r"
	var grip_allowed := native_grip and can_control and not transition_locked and not sword_sheathed and beam_cast_state in [BEAM_STATE_IDLE, BEAM_STATE_REDRAWING] and weapon_mode == "sword"
	_update_sword_hand_grip(skeleton, grip_allowed)
	var equipment_pose := _equipment_reach_pose()
	var sword_reach := not equipment_pose.is_empty() and weapon_mode == "sword"
	_update_bow_equipment_reach(equipment_pose)
	if guard_arm_ik != null:
		var guard_allowed := can_control and not transition_locked and not attacking and not sword_sheathed and beam_cast_state == "" and weapon_mode == "sword"
		var weight := clampf(block_pose_weight, 0.0, 1.0) if guard_allowed else 0.0
		if parry_window > 0.0 and guard_allowed:
			weight = 1.0
		if sword_reach:
			weight = float(equipment_pose.weight)
		if weight > 0.01:
			var target := global_position + Vector3.UP * 1.12 + global_basis.x.normalized() * 0.28 - global_basis.z.normalized() * 0.34
			if sword_reach:
				target = equipment_pose.position
			guard_arm_ik.target = Transform3D(Basis.IDENTITY, target)
			guard_arm_ik.influence = weight
			guard_arm_ik.start(true)
			guard_arm_applied = true
		elif guard_arm_applied:
			guard_arm_ik.stop()
			guard_arm_applied = false
	var forward := -global_transform.basis.z.normalized()
	var right := global_transform.basis.x.normalized()
	# BoneAttachment3D publishes its transform after the skeleton update. Reading
	# its global transform here leaves equipment one animation frame behind the
	# hand during fast strikes. Derive the live hand frame from the skeleton pose
	# directly, then express the weapon in the attachment's next local space.
	var hand_world := sword_attachment.global_transform
	if skeleton != null and sword_attachment.bone_idx >= 0:
		hand_world = skeleton.global_transform * skeleton.get_bone_global_pose(sword_attachment.bone_idx)
	var hand_basis := hand_world.basis.orthonormalized()
	if not sword_grip_calibrated and absf(hand_basis.determinant()) > 0.1:
		# Universal characters use different bind-pose hand axes across imported
		# revisions. Record the correction in hand-local space once, then let the
		# live bone animation carry the weapon through every pose.
		var calibration_direction := (Vector3.DOWN * 0.78 + right * 0.54).normalized()
		var local_calibration_direction := (hand_basis.inverse() * calibration_direction).normalized()
		sword_grip_basis = Basis(Quaternion(Vector3.DOWN, local_calibration_direction)).orthonormalized()
		sword_grip_calibrated = true
	# Keep the ready blade down and outside the torso instead of crossing the
	# chest. The attack states still own the full swing arc below.
	var idle_direction := (Vector3.DOWN * 0.78 + right * 0.54).normalized()
	var blade_direction := idle_direction
	if not attacking:
		var guard_weight := 1.0 if parry_window > 0.0 else clampf(block_pose_weight, 0.0, 1.0)
		var guard_direction := (Vector3.UP * 0.90 + forward * 0.42 - right * 0.18).normalized()
		blade_direction = idle_direction.slerp(guard_direction, guard_weight)
	if attacking:
		var windup_direction: Vector3
		var strike_direction: Vector3
		if heavy:
			windup_direction = (Vector3.UP * 0.90 - forward * 0.25 + right * 0.34).normalized()
			strike_direction = (Vector3.DOWN * 0.72 + forward * 0.62 - right * 0.24).normalized()
		else:
			windup_direction = (right * 0.82 + Vector3.UP * 0.40 - forward * 0.24).normalized()
			strike_direction = (-right * 0.62 + Vector3.DOWN * 0.12 + forward * 0.90).normalized()
		blade_direction = idle_direction.slerp(windup_direction, smoothstep(0.0, 1.0, windup))
		if strike > 0.0:
			blade_direction = windup_direction.slerp(strike_direction, smoothstep(0.0, 1.0, strike))
		if recovery > 0.0:
			blade_direction = strike_direction.slerp(idle_direction, smoothstep(0.0, 1.0, recovery))
	# Start from the current hand frame, rather than reconstructing a world
	# rotation from the actor root. The minimal direction correction keeps the
	# calibrated blade readable during the authored attack arc while preserving
	# wrist/elbow motion from the active animation clip.
	var hand_weapon_basis := (hand_basis * sword_grip_basis).orthonormalized()
	var current_blade_direction := (hand_weapon_basis * Vector3.DOWN).normalized()
	var direction_correction := Quaternion(current_blade_direction, blade_direction)
	var blade_basis := (Basis(direction_correction) * hand_weapon_basis).orthonormalized()
	if sword_reach:
		blade_basis = blade_basis.slerp(equipment_pose.basis, float(equipment_pose.weight))
	var hand_offset := hand_basis * Vector3(0.018, 0.012, 0.0)
	var hand_position := hand_world.origin + hand_offset
	if grip_allowed:
		# Anchor the hilt inside the curled native fingers on every axis. Ignoring
		# the blade-axis component preserved nominal reach but left the sword
		# visibly floating away from the hand during attack clips. Contact markers
		# share this pivot, so rendered and physical reach remain identical.
		var grip_center := _sword_grip_center_world(skeleton)
		var provisional := Transform3D(blade_basis, hand_position)
		var local_grip := provisional.affine_inverse() * grip_center
		hand_position += blade_basis * local_grip
	var desired_world := Transform3D(blade_basis, hand_position)
	var equipment_space := sword_equipment_pivot.get_parent() as Node3D
	if equipment_space != null and equipment_space.get_parent() == sword_attachment:
		var expected_parent_world := hand_world * equipment_space.transform
		sword_equipment_pivot.transform = expected_parent_world.affine_inverse() * desired_world
	else:
		sword_equipment_pivot.global_transform = desired_world

func _equipment_anchor_world(node: Node3D) -> Transform3D:
	var local := node.transform
	var ancestor := node.get_parent()
	while ancestor is Node3D:
		if ancestor is BoneAttachment3D and ancestor.get_parent() is Skeleton3D:
			var rig := ancestor.get_parent() as Skeleton3D
			return rig.global_transform * rig.get_bone_global_pose((ancestor as BoneAttachment3D).bone_idx) * local
		local = (ancestor as Node3D).transform * local
		ancestor = ancestor.get_parent()
	return node.global_transform

func _equipment_reach_pose() -> Dictionary:
	if not equipment_loadout.is_transitioning():
		return {}
	var anchor: Node3D = bow_back_visual if weapon_mode == "bow" else blade_scabbards.get(get_selected_blade_id()) as Node3D
	if not is_instance_valid(anchor):
		return {}
	var frame := _equipment_anchor_world(anchor)
	var phase := equipment_loadout.transition_progress()
	var contact := EquipmentLoadout.CONTACT_FRACTION
	var approach := smoothstep(0.0, contact - 0.04, phase)
	var release := 1.0 - smoothstep(contact + 0.08, 1.0, phase)
	var target := frame.origin
	if equipment_loadout.transition == "draw" and phase > contact:
		var withdrawal := sin(clampf((phase - contact) / (1.0 - contact), 0.0, 1.0) * PI)
		target += frame.basis.y.normalized() * 0.24 * withdrawal
	return {"position": target, "basis": frame.basis.orthonormalized(), "weight": approach * release}

func _update_bow_equipment_reach(pose: Dictionary) -> void:
	if equipment_left_arm_ik == null:
		return
	var reaching := weapon_mode == "bow" and not pose.is_empty()
	if not reaching:
		equipment_left_arm_ik.stop()
		if bow_visual != null:
			bow_visual.rotation_degrees = Vector3(0.0, 8.0, -12.0)
		return
	equipment_left_arm_ik.target = Transform3D(Basis.IDENTITY, pose.position)
	equipment_left_arm_ik.influence = float(pose.weight)
	equipment_left_arm_ik.start(true)
	if bow_visual != null:
		var parent_frame := _equipment_anchor_world(bow_visual.get_parent() as Node3D)
		var resting := Basis.from_euler(Vector3(0.0, deg_to_rad(8.0), deg_to_rad(-12.0)))
		var target_basis: Basis = parent_frame.basis.orthonormalized().inverse() * (pose.basis as Basis)
		bow_visual.basis = resting.slerp(target_basis, float(pose.weight)).scaled(Vector3.ONE * 0.82)

func _sword_grip_center_world(skeleton: Skeleton3D) -> Vector3:
	var center := Vector3.ZERO
	var count := 0
	for bone_name in ["index_02_r", "middle_02_r", "ring_02_r", "pinky_02_r"]:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index >= 0:
			center += (skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)).origin
			count += 1
	return center / float(count) if count > 0 else sword_attachment.global_position

func _update_sword_hand_grip(skeleton: Skeleton3D, enabled: bool) -> void:
	if skeleton == null:
		return
	if sword_grip_bones.is_empty():
		for finger in ["index", "middle", "ring", "pinky"]:
			for joint in [2, 3]:
				var bone_name := "%s_0%s_r" % [finger, joint]
				var bone_index := skeleton.find_bone(bone_name)
				if bone_index >= 0:
					sword_grip_bones[bone_index] = Quaternion(Vector3.RIGHT, 0.70)
		for joint in [2, 3]:
			var bone_name := "thumb_0%s_r" % joint
			var bone_index := skeleton.find_bone(bone_name)
			if bone_index >= 0:
				sword_grip_bones[bone_index] = Quaternion(Vector3.FORWARD, -0.35)
	if sword_grip_bones.is_empty():
		return
	var changed := false
	for bone_index in sword_grip_bones:
		var current := skeleton.get_bone_pose_rotation(bone_index)
		var base := current
		if sword_grip_pose_applied and sword_grip_applied_rotations.has(bone_index) and current.is_equal_approx(sword_grip_applied_rotations[bone_index]):
			base = sword_grip_base_rotations.get(bone_index, current)
		if enabled:
			var applied: Quaternion = (base * (sword_grip_bones[bone_index] as Quaternion)).normalized()
			sword_grip_base_rotations[bone_index] = base
			sword_grip_applied_rotations[bone_index] = applied
			skeleton.set_bone_pose_rotation(bone_index, applied)
			changed = true
		elif sword_grip_pose_applied and current.is_equal_approx(sword_grip_applied_rotations.get(bone_index, current)):
			skeleton.set_bone_pose_rotation(bone_index, base)
			changed = true
	sword_grip_pose_applied = enabled
	if not enabled:
		sword_grip_base_rotations.clear()
		sword_grip_applied_rotations.clear()
	if changed:
		skeleton.force_update_all_bone_transforms()

func _make_sword_readable(sword: Node3D) -> void:
	var blade_material := _metal_mat(Color(0.72, 0.78, 0.82))
	blade_material.metallic = 0.72
	blade_material.roughness = 0.30
	var found_mesh := false
	for child in sword.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		found_mesh = true
		mesh_instance.visible = true
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_instance.material_override = blade_material
	if found_mesh:
		return
	var blade := MeshInstance3D.new()
	blade.name = "KaelReadableSwordBlade"
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.065, 1.02, 0.035)
	blade.mesh = blade_mesh
	blade.position = Vector3(0.0, -0.53, 0.0)
	blade.material_override = blade_material
	sword.add_child(blade)
	var guard := MeshInstance3D.new()
	guard.name = "KaelReadableSwordGuard"
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.28, 0.055, 0.055)
	guard.mesh = guard_mesh
	guard.position = Vector3(0.0, -0.02, 0.0)
	guard.material_override = _metal_mat(Color(0.42, 0.32, 0.18))
	sword.add_child(guard)

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

func _ensure_equipment_loadout() -> void:
	equipment_loadout.bind_node("sword_hand", rig_sword_visual if rig_sword_visual != null else weapon_root)
	for blade_id: String in EquipmentLoadout.BLADE_IDS:
		equipment_loadout.bind_node(blade_id + "_hand", blade_hand_visuals.get(blade_id))
		equipment_loadout.bind_node(blade_id + "_back", blade_back_visuals.get(blade_id))
		equipment_loadout.bind_node(blade_id + "_scabbard", blade_scabbards.get(blade_id))
	equipment_loadout.bind_node("bow", bow_visual)
	equipment_loadout.bind_node("bow_back", bow_back_visual)
	equipment_loadout.bind_node("quiver", bow_quiver_visual)
	equipment_loadout.set_active_weapon(weapon_mode)
	equipment_loadout.set_sword_drawn(not sword_sheathed)
	equipment_loadout.set_selected_arrow(selected_arrow_id)

func save_equipment_state() -> Dictionary:
	if not beam_restore_equipment.is_empty():
		return beam_restore_equipment.duplicate(true)
	return equipment_loadout.save_state()

func load_equipment_state(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	cancel_buffered_input("equipment_restore")
	equipment_loadout.load_state(data)
	selected_arrow_id = equipment_loadout.selected_arrow_id
	_set_sword_sheathed(sword_sheathed)

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
	_configure_blade_markers(weapon_root, Vector3(0.0, 0.25, 0.02), Vector3(0.0, 0.28, -1.56))

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

func _add_slash_arc_visuals() -> void:
	slash_arc_root = Node3D.new()
	slash_arc_root.name = "visible_sword_slash_arc_root"
	slash_arc_root.position = Vector3(0.48, 1.18, -0.78)
	slash_arc_root.visible = false
	visual_root.add_child(slash_arc_root)
	slash_arc_primary = _add_slash_panel("visible_sword_slash_arc_primary", Vector3.ZERO, Vector3(0.045, 0.10, 1.0), Color(1.0, 0.84, 0.52, 0.34))
	slash_arc_secondary = _add_slash_panel("visible_sword_slash_arc_secondary", Vector3(0.07, -0.04, 0.05), Vector3(0.16, 0.08, 0.90), Color(0.70, 0.32, 0.12, 0.58))
	slash_arc_spark = _add_slash_panel("visible_sword_slash_impact_edge", Vector3(0.0, 0.0, -0.48), Vector3(0.20, 0.22, 0.16), Color(1.0, 0.80, 0.34, 0.92))

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

func _animate_visuals(delta: float) -> void:
	if visual_root == null:
		return
	_update_locomotion_state()
	var horizontal_speed: float = locomotion_velocity.length()
	var moving: bool = horizontal_speed > 0.15
	var running: bool = movement_state in ["run", "run_back"]
	var rigged_motion: bool = animation_driver != null and animation_driver.is_valid()
	if rigged_motion:
		if animation_driver.has_method("set_locomotion_motion"):
			animation_driver.set_locomotion_motion(locomotion_velocity, is_on_floor(), run_speed)
		else:
			animation_driver.set_locomotion(horizontal_speed / maxf(run_speed, 0.1), locomotion_velocity.normalized(), is_on_floor())
		if moving and equipment_loadout.is_transitioning() and animation_driver.current_state in ["draw", "sheath"]:
			animation_driver.stop_action("walk", 0.08)
		animation_driver.advance_external(delta)
		if movement_state == "dodge" and animation_driver.current_state != "dodge":
			animation_driver.trigger_action("dodge")
	if moving:
		# The fallback body's small weight shift advances with distance too;
		# imported rigs own their own continuous foot-contact phase.
		move_phase += delta * horizontal_speed * (8.7 / maxf(run_speed, 0.1) if running else 6.2 / maxf(walk_speed, 0.1))
		if not animation_step_signal_bound:
			_update_distance_footsteps(delta, running)
	else:
		move_phase += delta * 1.45
		footstep_distance = 0.0
	var speed_factor: float = clampf(horizontal_speed / maxf(run_speed, 0.1), 0.0, 1.0)
	movement_blend = lerp(movement_blend, speed_factor, 1.0 - exp(-10.0 * delta))
	strafe_blend = lerp(strafe_blend, 1.0 if movement_state == "strafe" else 0.0, 1.0 - exp(-9.0 * delta))
	backward_blend = lerp(backward_blend, 1.0 if movement_state in ["backward", "run_back"] else 0.0, 1.0 - exp(-9.0 * delta))
	grounded_weight = lerp(grounded_weight, movement_blend, 1.0 - exp(-8.0 * delta))
	block_pose_weight = lerp(block_pose_weight, 1.0 if is_blocking() else 0.0, 1.0 - exp(-14.0 * delta))
	var dodge_weight = clamp(dodge_time / 0.30, 0.0, 1.0)
	var hurt_weight = clamp(hurt_react_time / 0.20, 0.0, 1.0)
	var combat_swing_weight = 0.0
	var combat_windup_weight = 0.0
	# Walk/Sprint clips already move the pelvis and shoulders. A second full
	# bob/roll on the entire rig made feet float and the torso rock like a prop.
	var additive_gait_weight: float = 0.16 if rigged_motion else 1.0
	var bob: float = (0.030 * sin(move_phase) * grounded_weight if moving else 0.009 * sin(move_phase)) * additive_gait_weight
	var idle_breath: float = sin(move_phase * 0.72) * (1.0 - grounded_weight) * additive_gait_weight
	var pelvis_offset: float = (left_foot_ground_offset + right_foot_ground_offset) * 0.22
	visual_root.position.y = bob + pelvis_offset - 0.018 * grounded_weight * additive_gait_weight - 0.030 * hurt_weight - 0.10 * landing_compression
	var body_basis: Basis = global_basis.orthonormalized()
	var local_velocity: Vector3 = body_basis.inverse() * locomotion_velocity
	var lateral_lean: float = clampf(-local_velocity.x * (0.10 if rigged_motion else 0.22), -1.5, 1.5)
	var local_normal: Vector3 = body_basis.inverse() * smoothed_ground_normal
	var slope_pitch: float = rad_to_deg(atan2(local_normal.z, maxf(local_normal.y, 0.25)))
	var slope_roll: float = -rad_to_deg(atan2(local_normal.x, maxf(local_normal.y, 0.25)))
	var signed_forward_weight: float = clampf(-local_velocity.z / maxf(horizontal_speed, 0.15), -1.0, 1.0)
	var forward_lean: float = (-3.5 if running else -2.3) * grounded_weight * signed_forward_weight * additive_gait_weight if moving else 0.9 * idle_breath
	forward_lean += slope_pitch * (0.26 if rigged_motion else 0.45) + 8.0 * jump_pose_weight - 11.0 * landing_compression
	forward_lean += -7.0 * dodge_weight + 5.0 * hurt_weight - 3.5 * block_pose_weight
	var local_dodge: Vector3 = body_basis.inverse() * dodge_dir
	var root_z: float = lateral_lean + slope_roll * (0.22 if rigged_motion else 0.35) + 0.65 * sin(move_phase) * grounded_weight * additive_gait_weight + 9.0 * dodge_weight * signf(local_dodge.x) - 3.0 * block_pose_weight
	visual_root.rotation_degrees.z = lerpf(visual_root.rotation_degrees.z, root_z, 1.0 - exp(-9.0 * delta))
	visual_root.rotation_degrees.x = lerpf(visual_root.rotation_degrees.x, forward_lean, 1.0 - exp(-9.0 * delta))
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
		var swing = -188.0 * strike_arc if attack_anim_heavy else -124.0 * strike_arc
		var root_y = lerp(windup_angle, -18.0 if attack_anim_heavy else -10.0, strike)
		root_y = lerp(root_y, 0.0, recovery)
		visual_root.rotation_degrees.y = root_y
		visual_root.rotation_degrees.x = lerp(visual_root.rotation_degrees.x, forward_lean - (15.0 if attack_anim_heavy else 5.5) * strike_arc + (8.0 if attack_anim_heavy else 3.0) * windup, 12.0 * delta)
		if weapon_root != null:
			var weapon_pose = Vector3(38.0 - strike_arc * (68.0 if attack_anim_heavy else 48.0), swing, 20.0 + windup * (68.0 if attack_anim_heavy else 42.0) + strike_arc * (110.0 if attack_anim_heavy else 82.0))
			weapon_root.rotation_degrees = weapon_pose
			weapon_root.position = weapon_root.position.lerp(Vector3(0.42, 0.84, -0.42) + Vector3(0.20 * strike_arc, 0.08 * windup, -0.26 * strike_arc), 14.0 * delta)
			# The old fallback box trail detached from the hand and read as a
			# second oversized sword. The measured blade ribbon below is the only
			# attack trail now.
			if sword_trail_visual != null:
				sword_trail_visual.visible = false
		_update_sword_equipment_pose(windup, strike, recovery, attack_anim_heavy, true)
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
		_update_sword_equipment_pose(0.0, 0.0, 0.0, false, false)
	if beam_cast_state != "":
		var cast_weight := 1.0 if beam_cast_state in ["charging", "releasing"] else 0.55
		visual_root.rotation_degrees.x = lerp(visual_root.rotation_degrees.x, -4.0 * cast_weight, 12.0 * delta)
		visual_root.rotation_degrees.y = lerp(visual_root.rotation_degrees.y, 0.0, 12.0 * delta)
		if slash_arc_root != null:
			slash_arc_root.visible = false
	_update_oathfire_arm_pose()
	# Arm IK changes the hand pose after the regular beam-state tick. Refresh the
	# charge from the live bones now so the sphere, eventual beam origin, and
	# rendered hands cannot diverge by one animation frame.
	if beam_cast_state in [BEAM_STATE_CHARGING, BEAM_STATE_RELEASING]:
		_update_beam_charge_visual()
	if body_visual != null:
		var mat = body_visual.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = body_base_color.lerp(Color(0.72, 0.22, 0.12), 0.72) if hurt_flash_time > 0.0 else body_base_color

func _on_animation_locomotion_step(_side: StringName) -> void:
	# Animation contact is authoritative for rigged bodies. Gate it against
	# actual movement so a blocked actor cannot produce a stream of footsteps
	# while its clip is still blending out.
	if movement_state not in ["walk", "backward", "strafe", "run", "run_back"]:
		return
	if not is_on_floor() or locomotion_velocity.length() < 0.18:
		return
	footstep.emit()

func _update_distance_footsteps(delta: float, running: bool) -> void:
	if not is_on_floor():
		return
	var horizontal_speed: float = locomotion_velocity.length()
	if horizontal_speed < 0.18:
		return
	footstep_distance += horizontal_speed * delta
	var step_distance := 1.52 if running else (1.22 if movement_state == "backward" else 1.34)
	while footstep_distance >= step_distance:
		footstep_distance -= step_distance
		footstep.emit()

func _animate_slash_arc(strike: float, strike_arc: float, recovery: float, heavy: bool) -> void:
	if slash_arc_root == null:
		return
	var visible = is_blade_ready() and strike > 0.08 and strike < 0.94 and recovery < 0.86
	slash_arc_root.visible = visible
	if not visible:
		visual_previous_blade_base = Vector3.ZERO
		visual_previous_blade_tip = Vector3.ZERO
		return
	var segment: Dictionary = get_blade_world_segment()
	var blade_base: Vector3 = segment.get("base", global_position + Vector3(0, 1.0, 0))
	var blade_tip: Vector3 = segment.get("tip", blade_base)
	var old_base: Vector3 = visual_previous_blade_base if visual_previous_blade_base.length_squared() > 0.01 else blade_base
	var old_tip: Vector3 = visual_previous_blade_tip if visual_previous_blade_tip.length_squared() > 0.01 else blade_tip
	if old_tip.distance_to(blade_tip) > 1.10:
		old_base = blade_base
		old_tip = blade_tip
	slash_arc_root.global_transform = Transform3D.IDENTITY
	if slash_arc_primary != null:
		slash_arc_primary.visible = true
		slash_arc_primary.position = Vector3.ZERO
		slash_arc_primary.rotation = Vector3.ZERO
		slash_arc_primary.scale = Vector3.ONE
		slash_arc_primary.mesh = _build_blade_ribbon(old_base, old_tip, blade_base, blade_tip)
	if slash_arc_secondary != null:
		slash_arc_secondary.visible = false
	if slash_arc_spark != null:
		slash_arc_spark.visible = false
	visual_previous_blade_base = blade_base
	visual_previous_blade_tip = blade_tip

func _build_blade_ribbon(old_base: Vector3, old_tip: Vector3, blade_base: Vector3, blade_tip: Vector3) -> ImmediateMesh:
	var ribbon := ImmediateMesh.new()
	var width_axis := Vector3.RIGHT
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		width_axis = camera.global_transform.basis.x.normalized()
	var width := width_axis * 0.012
	# A full base-to-tip sweep renders the previous blade as a second floating
	# sword. Keep the effect on the outer third of the measured blade instead:
	# it still follows both authored base/tip transforms, but reads as a tapered
	# contact arc rather than duplicate weapon geometry.
	var old_inner := old_base.lerp(old_tip, 0.68)
	var current_inner := blade_base.lerp(blade_tip, 0.68)
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# Build two thin screen-facing strips around the measured outer-blade sweep.
	for side in [-1.0, 1.0]:
		var offset: Vector3 = width * side
		ribbon.surface_add_vertex(old_inner + offset)
		ribbon.surface_add_vertex(old_tip + offset)
		ribbon.surface_add_vertex(blade_tip + offset)
		ribbon.surface_add_vertex(old_inner + offset)
		ribbon.surface_add_vertex(blade_tip + offset)
		ribbon.surface_add_vertex(current_inner + offset)
	ribbon.surface_end()
	return ribbon

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
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = Color(1.0, 0.76, 0.42)
	material.emission_energy_multiplier = 0.24
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
