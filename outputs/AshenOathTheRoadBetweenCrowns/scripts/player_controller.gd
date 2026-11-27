extends "res://scripts/views/player_scene_state.gd"
## Fixed-tick scene adapter; public signals and compatibility methods are retained.

const PlayerEquipmentView = preload("res://scripts/views/player_equipment_view.gd")
const PlayerBladeGeometryView = preload("res://scripts/views/player_blade_geometry_view.gd")
const PlayerCharacterView = preload("res://scripts/views/player_character_view.gd")
const PlayerEquipmentPoseView = preload("res://scripts/views/player_equipment_pose_view.gd")
const PlayerAnimationView = preload("res://scripts/views/player_animation_view.gd")
const PlayerCameraOcclusionView = preload("res://scripts/views/player_camera_occlusion_view.gd")
const PlayerLocomotionView = preload("res://scripts/views/player_locomotion_view.gd")
const PlayerActionView = preload("res://scripts/views/player_action_view.gd")
const PlayerBowView = preload("res://scripts/views/player_bow_view.gd")
const PlayerOathfireView = preload("res://scripts/views/player_oathfire_view.gd")
const PlayerBladeContactView = preload("res://scripts/views/player_blade_contact_view.gd")

func _init(build_presentation: bool = true) -> void:
	presentation_enabled = build_presentation
	player_equipment_view = PlayerEquipmentView.new(self)
	player_blade_geometry_view = PlayerBladeGeometryView.new(self)
	player_character_view = PlayerCharacterView.new(self)
	player_equipment_pose_view = PlayerEquipmentPoseView.new(self)
	player_animation_view = PlayerAnimationView.new(self)
	player_camera_occlusion_view = PlayerCameraOcclusionView.new(self)
	player_locomotion_view = PlayerLocomotionView.new(self)
	player_action_view = PlayerActionView.new(self)
	player_bow_view = PlayerBowView.new(self)
	player_oathfire_view = PlayerOathfireView.new(self)
	player_blade_contact_view = PlayerBladeContactView.new(self)
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
	stamina_component.set_process(false)
	health_component.configure(125.0)
	health_component.died.connect(_on_died)
	_build_body()
	floor_snap_length = 0.34
	floor_max_angle = deg_to_rad(48.0)
	floor_stop_on_slope = true
	max_slides = 6
	safe_margin = 0.035
	contact_shadow = find_child("CharacterContactShadow", true, false) as Node3D
	was_on_floor = is_on_floor()

func _physics_process(delta: float) -> void:
	player_locomotion_view.capture_input_edges()
	var steps: int = simulation_clock.consume(MotionStep.simulation_delta(delta))
	for _step: int in steps:
		_first_substep = _step == 0
		_simulation_tick += 1
		_tick_delta = SimClock.TICK_DT
		stamina_component._process(_tick_delta)
		_simulate_tick(_tick_delta)
	if steps > 0:
		_pending_pressed.clear()
		_pending_released.clear()

func _simulate_tick(delta: float) -> void:
	if input_source != null and not input_source.is_gameplay_context():
		_movement_frame_active = false
		_cancel_bow()
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
	if weapon_mode != "bow" or not can_control:
		bow_model.recovery = maxf(0.0, bow_model.recovery - delta)
		bow_recovery = bow_model.recovery
	_update_beam_sequence(delta)
	equipment_loadout.advance_transition(delta)
	if transition_locked:
		_movement_frame_active = false
		velocity = Vector3.ZERO
		locomotion_velocity = Vector3.ZERO
		_animate_visuals(delta)
		_update_blade_contact()
		return
	if not can_control:
		_cancel_bow()
		_movement_frame_active = false
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		_apply_gravity(delta)
		MotionStep.slide(self, delta)
		_capture_locomotion_motion(delta)
		_update_ground_adaptation(delta)
		_animate_visuals(delta)
		_update_blade_contact()
		return
	_handle_combat_input()
	_handle_movement(delta)
	_update_blade_contact()

func set_transition_locked(locked: bool) -> void:
	player_action_view.set_transition_locked(locked)

func cancel_buffered_input(reason: String = "context") -> void:
	player_action_view.cancel_buffered_input(reason)

func bind_inventory(value: Variant, story: Node = null) -> void:
	player_action_view.bind_inventory(value, story)

func get_weapon_mode() -> String:
	return player_action_view.get_weapon_mode()

func get_selected_blade_id() -> String:
	return player_action_view.get_selected_blade_id()

func get_selected_weapon_name() -> String:
	return player_action_view.get_selected_weapon_name()

func get_camera_eye_height() -> float:
	return player_camera_occlusion_view.get_camera_eye_height()

func set_camera_close_view(enabled: bool) -> void:
	player_camera_occlusion_view.set_camera_close_view(enabled)

func _cache_camera_body(node: Node) -> void:
	player_camera_occlusion_view._cache_camera_body(node)

func _uses_first_person_camera() -> bool:
	return player_camera_occlusion_view._uses_first_person_camera()

func get_selected_arrow_id() -> String:
	return player_bow_view.get_selected_arrow_id()

func select_arrow(item_id: String) -> bool:
	return player_bow_view.select_arrow(item_id)

func get_selected_arrow_count() -> int:
	return player_bow_view.get_selected_arrow_count()

func _set_weapon_mode(next_mode: String) -> void:
	player_action_view._set_weapon_mode(next_mode)

func _select_blade(blade_id: String) -> void:
	player_action_view._select_blade(blade_id)

func _request_equipment(mode: String, blade_id: String, drawn: bool) -> void:
	player_action_view._request_equipment(mode, blade_id, drawn)

func _cycle_weapon() -> void:
	player_action_view._cycle_weapon()

func _toggle_weapon_draw() -> void:
	player_action_view._toggle_weapon_draw()

func _handle_equipment_input() -> void:
	player_action_view._handle_equipment_input()

func _on_equipment_transition_started(action: String, duration: float) -> void:
	player_action_view._on_equipment_transition_started(action, duration)

func _on_equipment_transition_finished() -> void:
	player_action_view._on_equipment_transition_finished()

func _cancel_equipment_action() -> void:
	player_action_view._cancel_equipment_action()

func _cycle_arrow_type() -> void:
	player_bow_view._cycle_arrow_type()

func set_progression(manager: Variant) -> void:
	player_action_view.set_progression(manager)

func _apply_progression_stats() -> void:
	player_action_view._apply_progression_stats()

func _progression_value(effect_id: String, fallback: float) -> float:
	return player_action_view._progression_value(effect_id, fallback)

func get_bow_aim_sensitivity() -> float:
	return player_action_view.get_bow_aim_sensitivity()

func _entitlement_value(id: String, fallback: float) -> float:
	return player_action_view._entitlement_value(id, fallback)

func get_bow_draw_duration() -> float:
	return player_action_view.get_bow_draw_duration()

func get_oathfire_charge_multiplier() -> float:
	return player_action_view.get_oathfire_charge_multiplier()

func get_dodge_stamina_cost() -> float:
	return player_action_view.get_dodge_stamina_cost()

func apply_difficulty_profile(profile: Dictionary) -> void:
	player_action_view.apply_difficulty_profile(profile)

func get_oathfire_stamina_cost() -> float:
	return player_action_view.get_oathfire_stamina_cost()

func get_oathfire_cooldown_duration() -> float:
	return player_action_view.get_oathfire_cooldown_duration()

func get_blade_attack_damage(heavy: bool = false) -> float:
	return player_action_view.get_blade_attack_damage(heavy)

func _movement_input() -> Vector2:
	return player_locomotion_view._movement_input()

func _action_pressed(action: StringName) -> bool:
	return player_locomotion_view._action_pressed(action)

func _action_just_pressed(action: StringName) -> bool:
	return player_locomotion_view._action_just_pressed(action)

func _action_just_released(action: StringName) -> bool:
	return player_locomotion_view._action_just_released(action)

func _handle_movement(delta: float) -> void:
	player_locomotion_view._handle_movement(delta)

func _movement_direction(input_vec: Vector2) -> Vector3:
	return player_locomotion_view._movement_direction(input_vec)

func _set_movement_facing(heading: float) -> void:
	player_locomotion_view._set_movement_facing(heading)

func _capture_locomotion_motion(delta: float) -> void:
	player_locomotion_view._capture_locomotion_motion(delta)

func _update_locomotion_state() -> void:
	player_locomotion_view._update_locomotion_state()

func _face_attack_direction() -> void:
	player_locomotion_view._face_attack_direction()

func try_jump() -> bool:
	return player_locomotion_view.try_jump()

func _try_step_up(move_dir: Vector3) -> void:
	player_locomotion_view._try_step_up(move_dir)

func _update_ground_adaptation(delta: float) -> void:
	player_locomotion_view._update_ground_adaptation(delta)

func _sample_foot_offset(side: float, delta: float, current: float) -> float:
	return player_locomotion_view._sample_foot_offset(side, delta, current)

func _handle_combat_input() -> void:
	player_action_view._handle_combat_input()

func _handle_bow_input() -> void:
	player_bow_view._handle_bow_input()

func _handle_field_tool() -> bool:
	return player_bow_view._handle_field_tool()

func field_tool_aim() -> Dictionary:
	return player_bow_view.field_tool_aim()

func _cancel_bow() -> void:
	player_bow_view._cancel_bow()

func bow_has_arrow() -> bool:
	return player_bow_view.bow_has_arrow()

func is_bow_training_active() -> bool:
	return player_bow_view.is_bow_training_active()

func is_bow_pose_active() -> bool:
	return player_bow_view.is_bow_pose_active()

func _update_bow_presentation(delta: float) -> void:
	player_bow_view._update_bow_presentation(delta)

func _release_bow() -> void:
	player_bow_view._release_bow()

static func locked_bow_aim_point(actor: Node3D) -> Vector3:
	# Presentation bounds may include limbs behind the actual damage body.
	return CombatBodyQuery.aim_point_for(actor)

func get_arrow_origin() -> Vector3:
	return player_bow_view.get_arrow_origin()

func _begin_blade_attack(damage: float, radius: float, heavy: bool) -> void:
	player_blade_contact_view._begin_blade_attack(damage, radius, heavy)

func _update_blade_contact() -> void:
	player_blade_contact_view._update_blade_contact()

func confirm_blade_contact(attack_id: int, hit: bool) -> void:
	player_blade_contact_view.confirm_blade_contact(attack_id, hit)

func get_parry_window_duration() -> float:
	return player_blade_contact_view.get_parry_window_duration()

func get_attack_buffer_duration() -> float:
	return player_blade_contact_view.get_attack_buffer_duration()

func is_blade_ready() -> bool:
	return player_blade_contact_view.is_blade_ready()

func get_blade_world_segment() -> Dictionary:
	return player_blade_contact_view.get_blade_world_segment()

func _configure_blade_markers(parent: Node3D, base_position: Vector3, tip_position: Vector3, fit_rendered_bounds: bool = false) -> void:
	player_blade_geometry_view._configure_blade_markers(parent, base_position, tip_position, fit_rendered_bounds)

func _blade_axis_from_rendered_bounds(parent: Node3D) -> Dictionary:
	return player_blade_geometry_view._blade_axis_from_rendered_bounds(parent)

func _handle_beam_input() -> void:
	player_oathfire_view._handle_beam_input()

func _set_beam_state(next_state: String, duration: float = -1.0) -> void:
	player_oathfire_view._set_beam_state(next_state, duration)

func _begin_oathfire_cast() -> bool:
	return player_oathfire_view._begin_oathfire_cast()

func _commit_oathfire_release(ratio: float) -> void:
	player_oathfire_view._commit_oathfire_release(ratio)

func _update_beam_sequence(delta: float) -> void:
	player_oathfire_view._update_beam_sequence(delta)

func _begin_beam_redraw() -> void:
	player_oathfire_view._begin_beam_redraw()

func _restore_oathfire_equipment() -> void:
	player_oathfire_view._restore_oathfire_equipment()

func _draw_sword_for_combat() -> void:
	player_oathfire_view._draw_sword_for_combat()

func cancel_beam_charge(reason: String = "cancelled") -> void:
	player_oathfire_view.cancel_beam_charge(reason)

func _lock_beam_direction() -> Vector3:
	return player_oathfire_view._lock_beam_direction()

func get_beam_locked_direction() -> Vector3:
	return player_oathfire_view.get_beam_locked_direction()

func get_oathfire_state() -> Dictionary:
	return player_oathfire_view.get_oathfire_state()

func get_oathfire_origin() -> Vector3:
	return player_oathfire_view.get_oathfire_origin()

func _live_oathfire_hand_origin(socket: BoneAttachment3D, glow: MeshInstance3D, fallback: Vector3) -> Vector3:
	return player_oathfire_view._live_oathfire_hand_origin(socket, glow, fallback)

func _update_beam_charge_visual() -> void:
	player_oathfire_view._update_beam_charge_visual()

func _hide_beam_charge_visuals() -> void:
	player_oathfire_view._hide_beam_charge_visuals()

func _set_sword_sheathed(sheathed: bool) -> void:
	player_oathfire_view._set_sword_sheathed(sheathed)

func is_blocking() -> bool:
	return player_oathfire_view.is_blocking()

func take_damage(amount: float) -> bool:
	return player_action_view.take_damage(amount)

func face_target(target_pos: Vector3) -> void:
	player_locomotion_view.face_target(target_pos)

func _apply_gravity(delta: float) -> void:
	player_locomotion_view._apply_gravity(delta)

func _on_died() -> void:
	player_action_view._on_died()

func _build_body() -> void:
	player_character_view._build_body()

func _add_beam_charge_visual() -> void:
	player_character_view._add_beam_charge_visual()

func _make_arm_pose_ik(skeleton: Skeleton3D, node_name: String, root_bone: StringName, tip_bone: StringName) -> SkeletonIK3D:
	return player_character_view._make_arm_pose_ik(skeleton, node_name, root_bone, tip_bone)

func begin_companion_gesture(companion: Node3D, kind: String, duration: float) -> void:
	player_equipment_pose_view.begin_companion_gesture(companion, kind, duration)

func end_companion_gesture(cancel_activity: bool = false) -> void:
	player_equipment_pose_view.end_companion_gesture(cancel_activity)

func _update_companion_gesture(delta: float) -> void:
	player_equipment_pose_view._update_companion_gesture(delta)

func _update_oathfire_arm_pose() -> void:
	player_equipment_pose_view._update_oathfire_arm_pose()

func _make_oathfire_hand(node_name: String, skeleton: Skeleton3D, aliases: Array[String], fallback_position: Vector3) -> MeshInstance3D:
	return player_character_view._make_oathfire_hand(node_name, skeleton, aliases, fallback_position)

func _build_bow_visual() -> void:
	player_equipment_view._build_bow_visual()

func _instantiate_modeled_prop(path: String) -> Node3D:
	return player_equipment_view._instantiate_modeled_prop(path)

func _prepare_modeled_prop(root: Node3D, fallback_color: Color) -> void:
	player_equipment_view._prepare_modeled_prop(root, fallback_color)

func _build_sheathed_sword() -> void:
	player_equipment_view._build_sheathed_sword()

func _build_scabbard_mesh() -> ArrayMesh:
	return player_equipment_view._build_scabbard_mesh()

func has_required_body() -> bool:
	return is_instance_valid(_mapped_body) and is_instance_valid(body_visual) \
		and body_visual.mesh != null and CharacterMaterialBindings.has_textured_identity(_mapped_body)

func _try_build_mapped_body() -> bool:
	return player_character_view._try_build_mapped_body()

func _animation_map_for_visual(mapped: Node3D) -> Dictionary:
	return player_character_view._animation_map_for_visual(mapped)

func _attach_rig_sword(mapped: Node3D) -> Node3D:
	return player_blade_geometry_view._attach_rig_sword(mapped)

func _build_oathblade_visual(parent: Node3D, blade_id: String = "steel") -> Node3D:
	return player_blade_geometry_view._build_oathblade_visual(parent, blade_id)

func _attach_modeled_sword(oathblade: Node3D, blade_id: String = "steel") -> bool:
	return player_blade_geometry_view._attach_modeled_sword(oathblade, blade_id)

func _build_oathblade_mesh() -> ImmediateMesh:
	return player_blade_geometry_view._build_oathblade_mesh()

func _update_sword_equipment_pose(windup: float, strike: float, recovery: float, heavy: bool, attacking: bool) -> void:
	player_equipment_pose_view._update_sword_equipment_pose(windup, strike, recovery, heavy, attacking)

func _equipment_anchor_world(node: Node3D) -> Transform3D:
	return player_equipment_pose_view._equipment_anchor_world(node)

func _equipment_reach_pose() -> Dictionary:
	return player_equipment_pose_view._equipment_reach_pose()

func _update_bow_equipment_reach(pose: Dictionary) -> void:
	player_equipment_pose_view._update_bow_equipment_reach(pose)

func _sword_grip_center_world(skeleton: Skeleton3D) -> Vector3:
	return player_equipment_pose_view._sword_grip_center_world(skeleton)

func _update_sword_hand_grip(skeleton: Skeleton3D, enabled: bool) -> void:
	player_equipment_pose_view._update_sword_hand_grip(skeleton, enabled)

func _make_sword_readable(sword: Node3D) -> void:
	player_equipment_view._make_sword_readable(sword)

func _create_equipment_space(attachment: BoneAttachment3D, space_name: String) -> Node3D:
	return player_equipment_view._create_equipment_space(attachment, space_name)

func _find_skeleton(node: Node) -> Skeleton3D:
	return player_character_view._find_skeleton(node)

func _find_bone_index(skeleton: Skeleton3D, aliases: Array[String]) -> int:
	return player_character_view._find_bone_index(skeleton, aliases)

func _ensure_equipment_loadout() -> void:
	player_equipment_view._ensure_equipment_loadout()

func save_equipment_state() -> Dictionary:
	if not beam_restore_equipment.is_empty():
		return beam_restore_equipment.duplicate(true)
	return equipment_loadout.save_state()

func reset_for_journey_restore() -> void:
	cancel_buffered_input("journey_restore")
	combat_model = CombatModel.new()
	bow_model = BowModel.new()
	simulation_clock = SimClock.new()
	_simulation_tick = 0
	velocity = Vector3.ZERO
	movement_state = "idle"
	footstep_distance = 0.0
	attack_cooldown = 0.0
	hurt_flash_time = 0.0
	hurt_react_time = 0.0
	block_pose_weight = 0.0
	jump_pose_weight = 0.0
	landing_compression = 0.0
	if guard_arm_ik != null:
		guard_arm_ik.stop()
	guard_arm_applied = false
	_update_hurt_overlay()
	if visual_root != null:
		visual_root.transform = Transform3D.IDENTITY
	if animation_driver != null:
		animation_driver.reset_for_journey_restore()
	reset_physics_interpolation()

func load_equipment_state(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	cancel_buffered_input("equipment_restore")
	equipment_loadout.load_state(data)
	selected_arrow_id = equipment_loadout.selected_arrow_id
	_set_sword_sheathed(sword_sheathed)

func _find_first_mesh(root: Node) -> MeshInstance3D:
	return player_character_view._find_first_mesh(root)

func _add_mapped_weapon_visuals() -> void:
	player_blade_geometry_view._add_mapped_weapon_visuals()

func _add_weapon_visuals(local_pos: Vector3) -> void:
	player_blade_geometry_view._add_weapon_visuals(local_pos)

func _weapon_ready_pose() -> Vector3:
	return player_blade_geometry_view._weapon_ready_pose()

func _add_slash_arc_visuals() -> void:
	player_animation_view._add_slash_arc_visuals()

func _add_slash_panel(node_name: String, local_pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	return player_animation_view._add_slash_panel(node_name, local_pos, size, color)

func _animate_visuals(delta: float) -> void:
	player_animation_view._animate_visuals(delta)

func _relaxed_idle_eligible() -> bool:
	return player_animation_view._relaxed_idle_eligible()

func _update_hurt_overlay() -> void:
	player_animation_view._update_hurt_overlay()

func _on_animation_locomotion_step(_side: StringName) -> void:
	player_animation_view._on_animation_locomotion_step(_side)

func _update_distance_footsteps(delta: float, running: bool) -> void:
	player_animation_view._update_distance_footsteps(delta, running)

func _animate_slash_arc(strike: float, strike_arc: float, recovery: float, heavy: bool) -> void:
	player_animation_view._animate_slash_arc(strike, strike_arc, recovery, heavy)

func _build_blade_ribbon(old_base: Vector3, old_tip: Vector3, blade_base: Vector3, blade_tip: Vector3) -> ImmediateMesh:
	return player_animation_view._build_blade_ribbon(old_base, old_tip, blade_base, blade_tip)

func _mat(color: Color) -> StandardMaterial3D:
	return player_character_view._mat(color)

func _metal_mat(color: Color) -> StandardMaterial3D:
	return player_character_view._metal_mat(color)

func _trail_mat(color: Color) -> StandardMaterial3D:
	return player_character_view._trail_mat(color)

func _beam_material(color: Color) -> StandardMaterial3D:
	return player_character_view._beam_material(color)

func _apply_visible_material_fallbacks(root: Node, fallback: Material, required: bool = false) -> void:
	player_character_view._apply_visible_material_fallbacks(root, fallback, required)

func _mesh_needs_visible_material(mesh_instance: MeshInstance3D) -> bool:
	return player_character_view._mesh_needs_visible_material(mesh_instance)

func _is_bad_white_material(material: Material) -> bool:
	return player_character_view._is_bad_white_material(material)

func read_presentation_tag(node: Node, key: StringName, fallback: Variant = null) -> Variant:
	return node.get_meta(key, fallback)

func write_presentation_tag(node: Node, key: StringName, value: Variant) -> void:
	node.set_meta(key, value)
