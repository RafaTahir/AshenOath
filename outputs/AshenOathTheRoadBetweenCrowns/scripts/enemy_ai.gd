extends "res://scripts/views/enemy_scene_state.gd"
## Fixed-tick combat adapter; scene effects and tactics have separate owners.

const EnemyVisualView = preload("res://scripts/views/enemy_visual_view.gd")
const EnemyBodyView = preload("res://scripts/views/enemy_body_view.gd")
const EnemyIdentityView = preload("res://scripts/views/enemy_identity_view.gd")
const EnemyEquipmentView = preload("res://scripts/views/enemy_equipment_view.gd")
const EnemyNavigationView = preload("res://scripts/views/enemy_navigation_view.gd")
const EnemyPresenceView = preload("res://scripts/views/enemy_presence_view.gd")
const EnemyStrikeView = preload("res://scripts/views/enemy_strike_view.gd")

func _init(build_presentation: bool = true) -> void:
	presentation_enabled = build_presentation
	enemy_visual_view = EnemyVisualView.new(self)
	enemy_body_view = EnemyBodyView.new(self)
	enemy_identity_view = EnemyIdentityView.new(self)
	enemy_equipment_view = EnemyEquipmentView.new(self)
	enemy_navigation_view = EnemyNavigationView.new(self)
	enemy_presence_view = EnemyPresenceView.new(self)
	enemy_strike_view = EnemyStrikeView.new(self)

func listen_to_world(audio: Node) -> void:
	if audio != null and not audio.perception_cue.is_connected(_on_world_sound):
		audio.perception_cue.connect(_on_world_sound)

func _on_world_sound(position: Vector3, radius: float, _danger: bool) -> void:
	var owner_node: Node = get_parent()
	while is_instance_valid(owner_node):
		if owner_node.has_meta("zone_resource_owner"):
			if str(owner_node.get_meta("zone_resource_owner")) != "active": return
			break
		owner_node = owner_node.get_parent()
	if dead or is_boss or not encounter_active or can_see_player or perception_memory_time > 0.0 or pending_attack_time > 0.0 or heard_cue_deadline > 0:
		return
	if global_position.distance_squared_to(position) > radius*radius or position.distance_to(home_position) > leash_radius-1.0 or global_position.distance_squared_to(position) < 0.25:
		return
	if spatial_service == null or not spatial_service.validate_segment(home_position, position, contact_radius):
		return
	heard_cue_deadline = 300
	ambient_state = "investigating"
	ambient_target = position
	ambient_remaining = 4.0
	navigation_target = Vector3.INF
	navigation_refresh_time = 0.0

func setup(id: String, definition: Dictionary, target: Node3D) -> void:
	enemy_body_view.setup(id, definition, target)

func setup_navigation(service: Variant) -> void:
	enemy_navigation_view.setup_navigation(service)

func set_encounter_peers(peers: Array, spatial_index: Variant = null) -> void:
	enemy_navigation_view.set_encounter_peers(peers, spatial_index)

func _physics_process(delta: float) -> void:
	for _step: int in simulation_clock.consume(MotionStep.simulation_delta(delta)):
		_simulate_tick(SimClock.TICK_DT)

func _simulate_tick(delta: float) -> void:
	heard_cue_deadline = maxi(0, heard_cue_deadline - 1)
	var motion_delta: Variant = delta
	if encounter_spatial_index != null:
		encounter_spatial_index.update(self)
	if dead or player == null:
		return
	if surrender_offer or resolved_nonlethal:
		_cancel_pending_strike()
		_release_attack_token()
		velocity=Vector3.ZERO
		if animation_driver!=null:
			animation_driver.set_external_tick(false)
			animation_driver.set_life_activity("fear" if surrender_offer else "sit")
		return
	if bool(get_meta("story_surrender_protected", false)):
		_cancel_pending_strike()
		velocity = Vector3.ZERO
		if animation_driver != null:
			animation_driver.set_locomotion(0.0, Vector3.ZERO, true)
		return
	var early_distance: float = player.global_position.distance_to(global_position)
	if early_distance > sense_range + 1.0 and pending_attack_time <= 0.0 and stagger_time <= 0.0 and is_on_floor():
		far_tick_accumulator += delta
		if far_tick_accumulator < 0.20:
			_step_motion(motion_delta)
			return
		delta = far_tick_accumulator
		far_tick_accumulator = 0.0
	else:
		far_tick_accumulator = 0.0
	# Normal enemies do not need a full physics decision at every rendered
	# frame. A stable 30 Hz decision cadence keeps pursuit, spacing, and attack
	# timing responsive at the native 720p budget while leaving bosses on the
	# full physics cadence for readable phase telegraphs.
	if not is_boss:
		near_tick_accumulator += delta
		if near_tick_accumulator < NEAR_AI_TICK_INTERVAL:
			_step_motion(motion_delta)
			return
		delta = near_tick_accumulator
		near_tick_accumulator = 0.0
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	attack_recovery_time = max(attack_recovery_time - delta, 0.0)
	slowed_time = max(slowed_time - delta, 0.0)
	windup_time = max(windup_time - delta, 0.0)
	hit_flash_time = max(hit_flash_time - delta, 0.0)
	stagger_time = max(stagger_time - delta, 0.0)
	parry_exposed_time = max(parry_exposed_time - delta, 0.0)
	navigation_refresh_time = maxf(navigation_refresh_time - delta, 0.0)
	anim_phase += delta * (3.45 if velocity.length() > 0.15 else 0.95)
	var to_player: Vector3 = player.global_position - global_position
	var distance: float = to_player.length()
	_update_perception(delta, distance)
	if is_boss or enemy_id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "bog_wretch", "gravebound_knight", "bandit"]:
		if not is_instance_valid(native_face) and visual_root != null:
			native_face = visual_root.find_child("CharacterFaceDriver", true, false)
		if is_instance_valid(native_face):
			native_face.set_focus_target(player if can_see_player else null)
	if can_see_player:
		had_player_contact = true
		ambient_state = "engaged"
		ambient_remaining = 0.0
		ambient_target = Vector3.INF
		if animation_driver != null:
			animation_driver.clear_life_activity()
			animation_driver.clear_observation_clip()
	var pursuit_position: Vector3 = player.global_position if can_see_player else last_known_player_position
	var pursuit_distance: Variant = global_position.distance_to(pursuit_position) if pursuit_position != Vector3.INF else INF
	var home_distance: float = global_position.distance_to(home_position)
	var tactical_mode: String = enemy_navigation_view.choose_tactical_mode()
	if tactical_mode == "return" and is_boss and player.global_position.distance_to(home_position) > leash_radius:
		_cancel_pending_strike()
		perception_memory_time = 0.0
		_hide_windup_marker()
		var home_dir: Variant = _navigation_direction(home_position) if home_distance > 0.35 else Vector3.ZERO
		velocity.x = home_dir.x * move_speed
		velocity.z = home_dir.z * move_speed
	elif tactical_mode == "windup":
		_tick_pending_attack(delta)
		velocity.x = 0.0
		velocity.z = 0.0
	elif tactical_mode == "stagger":
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	elif tactical_mode == "return":
		var home_dir: Variant = _navigation_direction(home_position)
		if home_distance > 0.35 and home_dir.length_squared() > 0.01:
			velocity.x = home_dir.x * move_speed
			velocity.z = home_dir.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	elif tactical_mode == "ambient":
		if is_boss and encounter_active:
			_update_boss_presence(delta)
		elif enemy_id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "bog_wretch", "gravebound_knight", "bandit"] and encounter_active:
			_update_ambient_life(delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
	elif tactical_mode == "recover":
		var retreat: Variant = -to_player.normalized()
		var tangent: Variant = Vector3(-retreat.z, 0.0, retreat.x) * flank_sign
		var recovery_dir: Variant = tangent if behavior_profile == "flanker" else (retreat if behavior_profile == "skirmisher" else Vector3.ZERO)
		var recovery_target: Variant = global_position + recovery_dir * 1.2
		if spatial_service == null or spatial_service.validate_segment(global_position, recovery_target, 0.55):
			velocity.x = recovery_dir.x * move_speed * 0.65
			velocity.z = recovery_dir.z * move_speed * 0.65
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	elif tactical_mode == "pursue":
		var speed_factor = 0.45 if slowed_time > 0.0 else 1.0
		var engagement_target: Variant = _engagement_target(pursuit_position)
		var dir: Variant = _navigation_direction(engagement_target)
		if dir.length_squared() < 0.01:
			velocity.x = 0.0
			velocity.z = 0.0
			speed_factor = 0.0
		var lateral: Variant = Vector3(-dir.z, 0.0, dir.x)
		if behavior_profile in ["feinter", "duelist"]:
			dir = (dir + lateral * sin(anim_phase * 0.72) * 0.42).normalized()
		elif behavior_profile == "brute":
			speed_factor *= 0.84
		elif behavior_profile == "lurker" and pursuit_distance > 5.0:
			speed_factor *= 0.62
		dir = (dir+_crowd_separation()*0.72).normalized()
		dir = _validated_step_direction(dir, engagement_target, move_speed * speed_factor * delta)
		velocity.x = dir.x * move_speed * speed_factor
		velocity.z = dir.z * move_speed * speed_factor
		if dir.length_squared() <= 0.01:
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if can_see_player and attack_cooldown <= 0.0 and player.has_method("take_damage") and _strike_presentation_ready() and _attack_lane_clear() and _claim_attack_token():
			var attack_facing: Variant = Vector3(to_player.x, 0.0, to_player.z)
			if attack_facing.length_squared() > 0.01:
				look_at(global_position + attack_facing, Vector3.UP)
			_begin_attack()
	_step_motion(motion_delta)

func _step_motion(delta: float) -> void:
	# Throttling perception/decisions must not throttle capsule movement.
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.1
	_apply_peer_spacing(delta)
	var facing_velocity: Variant = Vector3(velocity.x, 0.0, velocity.z)
	if facing_velocity.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-facing_velocity.x, -facing_velocity.z), 1.0 - exp(-12.0 * delta))
	MotionStep.slide(self, delta)
	if encounter_spatial_index != null:
		encounter_spatial_index.update(self)
	if animation_driver != null:
		var achieved: Variant = get_position_delta() / maxf(delta, 0.000001)
		achieved.y = 0.0
		if achieved.length_squared() > 0.01:
			animation_driver.clear_life_activity()
		animation_driver.set_locomotion_motion(achieved, is_on_floor(), maxf(move_speed, 0.1))
		_update_native_ambient(delta, achieved)
	_animate_visuals(delta)

func _update_native_ambient(delta: float, achieved: Vector3) -> void:
	enemy_presence_view._update_native_ambient(delta, achieved)

static func native_ambient_clip(identity: String, phase: int, boss: bool, creature_tag: String) -> String:
	if boss or creature_tag in ["human", "undead"]:
		return "Investigate" if phase % 4 == 2 else "Idle"
	if identity in ["hearthscale", "cairn_mother"]:
		return ["Idle", "Sleep", "Investigate", "Idle"][posmod(phase, 4)]
	if identity in ["glassmoth", "inkblind", "silt_maw", "millback", "gallows_weaver", "knell_leech"]:
		return ["Idle", "Feed", "Investigate", "Feed"][posmod(phase, 4)]
	return ["Idle", "Investigate", "Feed", "Idle"][posmod(phase, 4)]

func _navigation_direction(target: Vector3, force_refresh: bool = false) -> Vector3:
	return enemy_navigation_view._navigation_direction(target, force_refresh)

func _validated_step_direction(direction: Vector3, target: Vector3, step_distance: float) -> Vector3:
	return enemy_navigation_view._validated_step_direction(direction, target, step_distance)

func apply_damage(amount: float, source_tag: String = "") -> void:
	if dead or not encounter_active or bool(get_meta("story_surrender_protected", false)):
		return
	if surrender_offer:
		surrender_offer=false
		surrender_declined=true
		if animation_driver!=null:animation_driver.clear_life_activity()
	if bool(get_meta("dormant_arena", false)):
		var controller: Node = get_node_or_null("BossEncounterController")
		if controller != null and is_instance_valid(controller.host):
			controller.host._open_rootbound_encounter()
	var final_damage = amount
	var story_encounter: Variant = get_node_or_null("StoryEncounterPreparation")
	if story_encounter != null and story_encounter.has_method("incoming_damage_multiplier"):
		final_damage *= float(story_encounter.incoming_damage_multiplier(source_tag))
	final_damage = Tactics.incoming_damage(final_damage, source_tag, weakness, tag, parry_exposed_time > 0.0, enemy_id, health_component.health)
	parry_exposed_time = 0.0
	health_component.damage(final_damage)
	if enemy_id == "captain_senn" and health_component.health <= maxf(1.0, health_component.max_health * 0.25):
		var controller: Variant = get_node_or_null("BossEncounterController")
		if controller != null:
			preload("res://scripts/saga_encounters.gd").senn_yields(controller.host, self)
	hit_flash_time = 0.12
	stagger_time = max(stagger_time, 0.16)
	if bool(get_meta("ordinary_surrender_eligible",false)) and not surrender_declined and not dead and health_component.health>0.0 and health_component.health<=health_component.max_health*0.25:
		surrender_offer=true
		_cancel_pending_strike()
		_release_attack_token()
	if animation_driver != null and animation_driver.trigger_action("hit"):
		native_attack_tail_active = false
		_cancel_pending_strike(false)

func slow(seconds: float) -> void:
	enemy_strike_view.slow(seconds)

func set_encounter_active(value: bool) -> void:
	enemy_strike_view.set_encounter_active(value)

func is_encounter_active() -> bool:
	return encounter_active and not resolved_nonlethal

func accept_ordinary_surrender() -> bool:
	if not surrender_offer or dead or is_boss or not bool(get_meta("ordinary_surrender_eligible",false)):return false
	surrender_offer=false
	resolved_nonlethal=true
	encounter_active=false
	_cancel_pending_strike()
	_release_attack_token()
	set_meta("story_surrender_protected",true)
	if animation_driver!=null:
		animation_driver.stop_action("idle",0.12)
		animation_driver.set_external_tick(false)
		animation_driver.set_life_activity("sit")
	return true

func stagger(seconds: float = 0.7) -> void:
	enemy_strike_view.stagger(seconds)

func _tick_pending_attack(delta: float) -> void:
	enemy_strike_view._tick_pending_attack(delta)

func _resolve_attack() -> void:
	enemy_strike_view._resolve_attack()

func _strike_recovery() -> float:
	return enemy_strike_view._strike_recovery()

func _strike_presentation_ready() -> bool:
	return enemy_strike_view._strike_presentation_ready()

func _begin_attack() -> bool:
	return enemy_strike_view._begin_attack()

func _start_attack_animation() -> bool:
	return enemy_strike_view._start_attack_animation()

func _fit_native_attack_tail() -> void:
	enemy_strike_view._fit_native_attack_tail()

func _cancel_pending_strike(interrupt_animation: bool = true) -> void:
	enemy_strike_view._cancel_pending_strike(interrupt_animation)

func _boss_attack_id() -> String:
	return enemy_strike_view._boss_attack_id()

func interrupt_boss_windup(reason: String = "interrupt") -> bool:
	return enemy_strike_view.interrupt_boss_windup(reason)

func _boss_attack_radius(attack_id: String) -> float:
	return enemy_strike_view._boss_attack_radius(attack_id)

func _special_attack_hits_player(attack_id: String, radius: float) -> bool:
	return enemy_strike_view._special_attack_hits_player(attack_id, radius)

func player_contact_distance() -> float:
	return enemy_navigation_view.player_contact_distance()

func _has_attack_line() -> bool:
	return enemy_navigation_view._has_attack_line()

func _crowd_separation() -> Vector3:
	return enemy_navigation_view._crowd_separation()

func _apply_peer_spacing(delta: float) -> void:
	enemy_navigation_view._apply_peer_spacing(delta)

func _engagement_target(target_position: Vector3 = Vector3.INF) -> Vector3:
	return enemy_navigation_view._engagement_target(target_position)

func _update_perception(delta: float, player_distance: float) -> void:
	enemy_navigation_view._update_perception(delta, player_distance)

func _update_ambient_life(delta: float) -> void:
	enemy_presence_view._update_ambient_life(delta)

func _ambient_landmark_destination() -> Vector3:
	return enemy_presence_view._ambient_landmark_destination()

func _update_boss_presence(delta: float) -> void:
	enemy_presence_view._update_boss_presence(delta)

func _has_perception_line() -> bool:
	return enemy_navigation_view._has_perception_line()

func _attack_lane_clear() -> bool:
	return enemy_navigation_view._attack_lane_clear()

func _attack_contact_point() -> Vector3:
	return enemy_navigation_view._attack_contact_point()

func get_attack_trace() -> Dictionary:
	return enemy_presence_view.get_attack_trace()

func get_behavior_state() -> Dictionary:
	return enemy_presence_view.get_behavior_state()

func get_tactical_state() -> Dictionary:
	return enemy_presence_view.get_tactical_state()

func _on_died() -> void:
	dead = true
	native_attack_tail_active = false
	pending_attack_time = 0.0
	windup_time = 0.0
	death_pose_time = 1.0
	_hide_windup_marker()
	_release_attack_token()
	collision_layer = 0
	collision_mask = 0
	if animation_driver != null and animation_driver.is_valid():
		animation_driver.set_external_tick(false)
		animation_driver.set_dead()
	elif visual_root != null:
		visual_root.rotation_degrees.x = 84.0
		visual_root.rotation_degrees.y += -28.0 if combat_rng.next_float() > 0.5 else 28.0
		visual_root.rotation_degrees.z = -38.0 if combat_rng.next_float() > 0.5 else 38.0
		visual_root.position.y = 0.06
		visual_root.position.z -= 0.22
		visual_root.scale = Vector3(1.18, 0.48, 1.38)
	if body_visual != null:
		var material = body_visual.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color = material.albedo_color.darkened(0.45)
	died.emit(self)

func _claim_attack_token() -> bool:
	if owns_attack_token:
		return true
	if attack_gate.is_valid() and not bool(attack_gate.call(self, true)):
		return false
	owns_attack_token = true
	return true

func _release_attack_token() -> void:
	if not owns_attack_token:
		return
	owns_attack_token = false
	if attack_gate.is_valid():
		attack_gate.call(self, false)

func _windup_duration() -> float:
	return enemy_strike_view._windup_duration()

func _attack_cooldown() -> float:
	return enemy_strike_view._attack_cooldown()

func _on_health_changed(current: float, maximum: float) -> void:
	damaged.emit(self, current, maximum)
	if not is_boss or maximum <= 0.0:
		return
	var ratio: Variant = current / maximum
	var next_phase: int = Tactics.phase_for_health(ratio)
	if next_phase == boss_phase:
		return
	boss_phase = next_phase
	move_speed = base_move_speed * [1.0, 1.10, 1.18][boss_phase - 1]
	damage = base_damage * [1.0, 1.08, 1.15][boss_phase - 1]
	boss_phase_changed.emit(self, boss_phase)

func _build_body(color: Color) -> void:
	enemy_body_view._build_body(color)

func _try_build_mapped_body() -> bool:
	return enemy_body_view._try_build_mapped_body()

func _configure_native_attack_profile(mapped: Node3D) -> bool:
	return enemy_body_view._configure_native_attack_profile(mapped)

func _add_spectral_antler_crown(mapped: Node3D) -> void:
	enemy_identity_view._add_spectral_antler_crown(mapped)

func _find_type(root: Node, type_name: String) -> Node:
	return enemy_equipment_view._find_type(root, type_name)

func _safe_scale_ratio(value: float, divisor: float) -> float:
	return enemy_equipment_view._safe_scale_ratio(value, divisor)

func _safe_inverse_scale(value: float) -> float:
	return enemy_equipment_view._safe_inverse_scale(value)

func _add_skeleton_impact_clip(mapped: Node3D) -> void:
	enemy_equipment_view._add_skeleton_impact_clip(mapped)

func _configure_attack_contact_bone() -> void:
	enemy_equipment_view._configure_attack_contact_bone()

func _ground_mapped_visual(mapped: Node3D) -> void:
	enemy_body_view._ground_mapped_visual(mapped)

func _accumulate_visual_bounds(node: Node, parent_transform: Transform3D, state: Dictionary) -> void:
	enemy_body_view._accumulate_visual_bounds(node, parent_transform, state)

func _posed_mesh_bounds(instance: MeshInstance3D) -> AABB:
	return enemy_body_view._posed_mesh_bounds(instance)

func _horror_material() -> StandardMaterial3D:
	return enemy_visual_view._horror_material()

func _apply_boss_material(mapped: Node3D) -> void:
	enemy_visual_view._apply_boss_material(mapped)

func _tint_authored_materials(root: Node, tint: Color) -> void:
	enemy_visual_view._tint_authored_materials(root, tint)

func _add_boss_silhouette() -> void:
	enemy_visual_view._add_boss_silhouette()

func _make_bell_eater_identity() -> void:
	enemy_identity_view._make_bell_eater_identity()

func _attach_bell_eater_harness(mapped: Node3D) -> void:
	enemy_identity_view._attach_bell_eater_harness(mapped)

func _attach_boss_identity_to_bone(mapped: Node3D, bone_name: String, socket_name: String, anchor: Vector3, relative_to_bone: bool = false) -> void:
	enemy_identity_view._attach_boss_identity_to_bone(mapped, bone_name, socket_name, anchor, relative_to_bone)

func _make_rootbound_identity() -> void:
	enemy_identity_view._make_rootbound_identity()

func _make_ashwing_identity() -> void:
	enemy_identity_view._make_ashwing_identity()

func _make_halvern_identity() -> void:
	enemy_identity_view._make_halvern_identity()

func _attach_humanoid_sword(label: String) -> void:
	enemy_equipment_view._attach_humanoid_sword(label)

func _attach_bandit_shield() -> void:
	enemy_equipment_view._attach_bandit_shield()

func _make_white_hart_identity() -> void:
	enemy_identity_view._make_white_hart_identity()

func _emissive_boss_material(color: Color, energy: float) -> StandardMaterial3D:
	return enemy_identity_view._emissive_boss_material(color, energy)

func _mapped_enemy_scale() -> Vector3:
	return enemy_body_view._mapped_enemy_scale()

func _enemy_shadow_scale() -> Vector3:
	return enemy_body_view._enemy_shadow_scale()

func _is_wychwood_pack() -> bool:
	return enemy_id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute"]

func _find_first_mesh(root: Node) -> MeshInstance3D:
	return enemy_equipment_view._find_first_mesh(root)

func _apply_material(root: Node, material: Material) -> void:
	enemy_equipment_view._apply_material(root, material)

func _apply_bad_material_fallback(root: Node, material: Material) -> void:
	enemy_equipment_view._apply_bad_material_fallback(root, material)

func _mesh_needs_visible_material(mesh_instance: MeshInstance3D) -> bool:
	return enemy_equipment_view._mesh_needs_visible_material(mesh_instance)

func _is_bad_white_material(material: Material) -> bool:
	return enemy_equipment_view._is_bad_white_material(material)

func _add_part(pos: Vector3, scale_value: Vector3, color: Color, shape_name: String, rot_degrees: Vector3 = Vector3.ZERO) -> void:
	enemy_equipment_view._add_part(pos, scale_value, color, shape_name, rot_degrees)

func _animate_visuals(delta: float) -> void:
	enemy_visual_view._animate_visuals(delta)

func _animate_boss_identity(delta: float) -> void:
	enemy_visual_view._animate_boss_identity(delta)

func apply_boss_phase_visual(next_phase: int) -> void:
	enemy_visual_view.apply_boss_phase_visual(next_phase)

func _apply_bell_eater_phase_visual(next_phase: int) -> void:
	enemy_visual_view._apply_bell_eater_phase_visual(next_phase)

func _apply_ashwing_phase_visual(next_phase: int) -> void:
	enemy_visual_view._apply_ashwing_phase_visual(next_phase)

func _update_feedback_material() -> void:
	enemy_visual_view._update_feedback_material()

func _show_windup_marker() -> void:
	enemy_visual_view._show_windup_marker()

func _hide_windup_marker() -> void:
	enemy_visual_view._hide_windup_marker()

func _mat(color: Color) -> StandardMaterial3D:
	return enemy_visual_view._mat(color)

func read_presentation_tag(node: Node, key: StringName, fallback: Variant = null) -> Variant:
	return node.get_meta(key, fallback)

func write_presentation_tag(node: Node, key: StringName, value: Variant) -> void:
	node.set_meta(key, value)
