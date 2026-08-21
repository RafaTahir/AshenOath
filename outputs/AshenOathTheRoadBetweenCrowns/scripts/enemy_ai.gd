extends CharacterBody3D

signal died(enemy: Node)
signal damaged(enemy: Node, current: float, maximum: float)
signal windup_started(enemy: Node)
signal attack_resolved(enemy: Node, parried: bool, contact_position: Vector3)
signal special_attack_resolved(enemy: Node, attack_id: String, contact_position: Vector3, radius: float, damage: float, parried: bool)
signal special_attack_interrupted(enemy: Node, attack_id: String, reason: String)
signal parry_window_opened(enemy: Node, duration: float)
signal boss_phase_changed(enemy: Node, phase: int)

const HealthComponent = preload("res://scripts/health_component.gd")
const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterPresentation = preload("res://scripts/character_presentation.gd")
const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const CharacterAnimationDriver = preload("res://scripts/character_animation_driver.gd")
# Keep the current Ashwing runtime source reachable to Godot's dependency
# scanner; the role manifest still owns which source is selected at runtime.
const ASHWING_RUNTIME_SOURCE = preload("res://assets_external/enemies/Dragon.fbx")

var enemy_id = "ghoulkin"
var display_name = "Enemy"
var player
var health_component
var damage = 10.0
var move_speed = 2.0
var attack_range = 1.4
var sense_range = 10.0
var tag = "beast"
var weakness = ""
var attack_cooldown = 0.0
var slowed_time = 0.0
var dead = false
var body_visual: MeshInstance3D
var visual_root: Node3D
var boss_visual_root: Node3D
var boss_phase_sigil: MeshInstance3D
var asset_helper
var base_color = Color.WHITE
var base_body_scale = Vector3.ONE
var anim_phase = 0.0
var windup_time = 0.0
var hit_flash_time = 0.0
var pending_attack_time = 0.0
var stagger_time = 0.0
var home_position = Vector3.ZERO
var leash_radius = 14.0
var windup_marker: MeshInstance3D
var attack_recovery_time = 0.0
var death_pose_time = 0.0
var animation_driver
var behavior_profile := "direct"
var flank_sign := 1.0
var parry_exposed_time := 0.0
var far_tick_accumulator := 0.0
var attack_gate: Callable
var owns_attack_token := false
var encounter_active := true
var spatial_service
var navigation_agent: NavigationAgent3D
var navigation_route: Array[Vector3] = []
var navigation_route_index := 0
var navigation_refresh_time := 0.0
var navigation_target := Vector3.INF
var encounter_slot := 0
var preferred_distance := 2.15
var approach_angle_degrees := 0.0
var contact_radius := 0.72
var attack_contact_bone := -1
var attack_trace_start := Vector3.ZERO
var attack_trace_end := Vector3.ZERO
var last_attack_contact := Vector3.ZERO
var attack_trace_uses_skeleton := false
var perception_memory_duration := 2.5
var perception_memory_time := 0.0
var perception_refresh_time := 0.0
var can_see_player := false
var last_known_player_position := Vector3.INF
var boss_phase := 1
var is_boss := false
var base_move_speed := 2.0
var base_damage := 10.0
var boss_visual_time := 0.0
var boss_identity_base_scale := Vector3.ONE

func setup(id: String, definition: Dictionary, target: Node3D) -> void:
	enemy_id = id
	display_name = definition.get("name", id)
	damage = float(definition.get("damage", 10.0))
	move_speed = float(definition.get("speed", 2.0))
	base_damage = damage
	base_move_speed = move_speed
	attack_range = float(definition.get("attack_range", 1.5))
	sense_range = float(definition.get("sense_range", 10.0))
	tag = definition.get("tag", "beast")
	weakness = definition.get("weakness", "")
	is_boss = bool(definition.get("boss", false))
	player = target
	home_position = global_position
	health_component = HealthComponent.new()
	add_child(health_component)
	health_component.configure(float(definition.get("health", 60.0)))
	health_component.changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	base_color = Color(definition.get("color", "#665544"))
	behavior_profile = str(definition.get("behavior_profile", {
		"wychwood_stalker":"flanker", "wychwood_raider":"feinter",
		"wychwood_brute":"brute", "ghoulkin":"skirmisher"
	}.get(enemy_id, "direct")))
	perception_memory_duration = float(definition.get("perception_memory", 2.5))
	preferred_distance = float(definition.get("preferred_distance", {
		"flanker":2.65, "feinter":2.30, "brute":2.05, "skirmisher":2.40
	}.get(behavior_profile, 2.15)))
	approach_angle_degrees = float(definition.get("approach_angle", {
		"flanker":68.0, "feinter":34.0, "brute":0.0, "skirmisher":24.0
	}.get(behavior_profile, 0.0)))
	contact_radius = float(definition.get("contact_radius", 0.78 if behavior_profile == "brute" else 0.68))
	flank_sign = -1.0 if int(get_instance_id()) % 2 == 0 else 1.0
	_build_body(base_color)

func setup_navigation(service) -> void:
	spatial_service = service
	if navigation_agent == null:
		navigation_agent = NavigationAgent3D.new()
		navigation_agent.name = "NavigationAgent3D"
		navigation_agent.path_desired_distance = 0.28
		navigation_agent.target_desired_distance = 0.28
		navigation_agent.radius = 0.44
		navigation_agent.height = 1.75
		add_child(navigation_agent)
	navigation_agent.process_mode = Node.PROCESS_MODE_DISABLED
	var map_rid: RID = spatial_service.get_navigation_map() if spatial_service != null else RID()
	if map_rid.is_valid():
		navigation_agent.set_navigation_map(map_rid)
	navigation_route.clear()
	navigation_route_index = 0
	navigation_refresh_time = 0.0
	navigation_target = Vector3.INF

func _physics_process(delta: float) -> void:
	if dead or player == null:
		return
	var early_distance: float = player.global_position.distance_to(global_position)
	if early_distance > sense_range + 1.0 and pending_attack_time <= 0.0 and stagger_time <= 0.0 and is_on_floor():
		far_tick_accumulator += delta
		if far_tick_accumulator < 0.20:
			return
		delta = far_tick_accumulator
		far_tick_accumulator = 0.0
	else:
		far_tick_accumulator = 0.0
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
	var pursuit_position: Vector3 = player.global_position if can_see_player else last_known_player_position
	var pursuit_distance := global_position.distance_to(pursuit_position) if pursuit_position != Vector3.INF else INF
	var home_distance: float = global_position.distance_to(home_position)
	if pending_attack_time > 0.0:
		pending_attack_time -= delta
		attack_trace_end = _attack_contact_point()
		velocity.x = 0.0
		velocity.z = 0.0
		if pending_attack_time <= 0.0:
			_resolve_attack()
	elif stagger_time > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	elif home_distance > leash_radius:
		var home_dir := _navigation_direction(home_position)
		if home_distance > 0.35 and home_dir.length_squared() > 0.01:
			velocity.x = home_dir.x * move_speed
			velocity.z = home_dir.z * move_speed
			look_at(global_position + home_dir, Vector3.UP)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	elif perception_memory_time <= 0.0 and not can_see_player:
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
	elif attack_recovery_time > 0.0:
		var retreat := -to_player.normalized()
		var tangent := Vector3(-retreat.z, 0.0, retreat.x) * flank_sign
		var recovery_dir := tangent if behavior_profile == "flanker" else (retreat if behavior_profile == "skirmisher" else Vector3.ZERO)
		var recovery_target := global_position + recovery_dir * 1.2
		if spatial_service == null or spatial_service.validate_segment(global_position, recovery_target, 0.55):
			velocity.x = recovery_dir.x * move_speed * 0.65
			velocity.z = recovery_dir.z * move_speed * 0.65
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	elif pursuit_distance > attack_range or not can_see_player:
		var speed_factor = 0.45 if slowed_time > 0.0 else 1.0
		var engagement_target := _engagement_target(pursuit_position)
		var dir := _navigation_direction(engagement_target)
		if dir.length_squared() < 0.01:
			velocity.x = 0.0
			velocity.z = 0.0
			speed_factor = 0.0
		var lateral := Vector3(-dir.z, 0.0, dir.x)
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
		if dir.length_squared() > 0.01:
			# A moving actor faces the route it is actually taking. This keeps
			# flanks and retreats readable instead of producing sideways slides.
			look_at(global_position + dir, Vector3.UP)
		else:
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if can_see_player and attack_cooldown <= 0.0 and player.has_method("take_damage") and _attack_lane_clear() and _claim_attack_token():
			attack_cooldown = _attack_cooldown()
			windup_time = _windup_duration()
			pending_attack_time = windup_time
			if animation_driver != null:
				animation_driver.trigger_action("windup")
			attack_trace_start = _attack_contact_point()
			attack_trace_end = attack_trace_start
			_show_windup_marker()
			windup_started.emit(self)
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.1
	move_and_slide()
	if animation_driver != null:
		animation_driver.set_locomotion(Vector2(velocity.x, velocity.z).length() / max(move_speed, 0.1), velocity, is_on_floor())
	_animate_visuals(delta)

func _navigation_direction(target: Vector3, force_refresh: bool = false) -> Vector3:
	if spatial_service == null or navigation_agent == null:
		return Vector3.ZERO
	var target_changed := navigation_target == Vector3.INF or navigation_target.distance_squared_to(target) > 1.56
	if force_refresh or target_changed or navigation_refresh_time <= 0.0 or navigation_route.is_empty():
		navigation_route = spatial_service.build_route(global_position, target, 0.62)
		navigation_route_index = 1 if navigation_route.size() > 1 else 0
		navigation_target = target
		navigation_refresh_time = 0.35
	if navigation_route.is_empty():
		return Vector3.ZERO
	var route_target := navigation_route[navigation_route_index]
	if global_position.distance_to(route_target) < 0.38 and navigation_route_index + 1 < navigation_route.size():
		navigation_route_index += 1
		route_target = navigation_route[navigation_route_index]
	var direction := route_target - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.002:
		direction = route_target - global_position
		direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.002 else Vector3.ZERO

func _validated_step_direction(direction: Vector3, target: Vector3, step_distance: float) -> Vector3:
	var candidate := direction
	candidate.y = 0.0
	if candidate.length_squared() < 0.002:
		return Vector3.ZERO
	candidate = candidate.normalized()
	if spatial_service == null:
		return candidate
	var proposed := global_position + candidate * maxf(step_distance, 0.02)
	if spatial_service.validate_segment(global_position, proposed, 0.50):
		return candidate
	var rerouted := _navigation_direction(target, true)
	if rerouted.length_squared() < 0.002:
		return Vector3.ZERO
	var reroute_position := global_position + rerouted * maxf(step_distance, 0.02)
	return rerouted if spatial_service.validate_segment(global_position, reroute_position, 0.50) else Vector3.ZERO

func apply_damage(amount: float, source_tag: String = "") -> void:
	if dead or not encounter_active:
		return
	var final_damage = amount
	if parry_exposed_time > 0.0:
		final_damage += 8.0
		parry_exposed_time = 0.0
	if source_tag == weakness or source_tag == tag:
		final_damage += 15.0
	health_component.damage(final_damage)
	hit_flash_time = 0.12
	stagger_time = max(stagger_time, 0.16)
	if animation_driver != null:
		animation_driver.trigger_action("hit")

func slow(seconds: float) -> void:
	if not encounter_active:
		return
	slowed_time = max(slowed_time, seconds)

func set_encounter_active(value: bool) -> void:
	encounter_active = value
	visible = value
	set_physics_process(value)
	if visual_root != null:
		visual_root.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	if navigation_agent != null:
		navigation_agent.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	if animation_driver != null:
		animation_driver.set_distance_suspended(not value)
	for collision in find_children("*", "CollisionShape3D", true, false):
		collision.set_deferred("disabled", not value)
	if value:
		velocity = Vector3.ZERO
		if animation_driver != null:
			animation_driver.set_locomotion(0.0, Vector3.ZERO, true)

func is_encounter_active() -> bool:
	return encounter_active

func stagger(seconds: float = 0.7) -> void:
	stagger_time = max(stagger_time, seconds)
	windup_time = 0.0
	pending_attack_time = 0.0
	_release_attack_token()
	if animation_driver != null:
		animation_driver.trigger_action("hit")

func _resolve_attack() -> void:
	_release_attack_token()
	if dead or player == null or not player.has_method("take_damage"):
		return
	attack_trace_end = _attack_contact_point()
	var player_contact: Vector3 = player.global_position + Vector3(0.0, 1.0, 0.0)
	var sweep_start: Vector3 = attack_trace_start
	var sweep_end: Vector3 = attack_trace_end
	if sweep_start.distance_squared_to(sweep_end) < 0.04:
		var forward := -global_transform.basis.z
		forward.y = 0.0
		sweep_end += forward.normalized() * attack_range
	last_attack_contact = Geometry3D.get_closest_point_to_segment(player_contact, sweep_start, sweep_end)
	var boss_attack := _boss_attack_id()
	var special_radius := _boss_attack_radius(boss_attack)
	var special_contact := is_boss and boss_attack != "" and player_contact.distance_to(global_position) <= special_radius and _has_attack_line()
	var melee_contact := player_contact.distance_to(last_attack_contact) <= contact_radius and _has_attack_line()
	if not melee_contact and not special_contact:
		return
	var applied_damage: float = damage * (0.72 if special_contact and not melee_contact else 1.0)
	var parried: bool = bool(player.take_damage(applied_damage))
	attack_recovery_time = 0.22 if enemy_id == "ghoulkin" else 0.16
	var contact_position := last_attack_contact
	attack_resolved.emit(self, parried, contact_position)
	if is_boss and boss_attack != "":
		special_attack_resolved.emit(self, boss_attack, contact_position, special_radius, applied_damage, parried)
	if parried:
		parry_exposed_time = 1.15
		stagger(1.15)
		if is_boss:
			set_meta("last_parried", true)
			parry_window_opened.emit(self, 1.15)

func _boss_attack_id() -> String:
	if not is_boss:
		return ""
	var controller := get_node_or_null("BossEncounterController")
	if controller != null and controller.has_method("phase_definition"):
		var phase_data: Dictionary = controller.phase_definition()
		return str(phase_data.get("telegraph", ""))
	return ""

func interrupt_boss_windup(reason: String = "interrupt") -> bool:
	if not is_boss or windup_time <= 0.0:
		return false
	var attack_id := _boss_attack_id()
	windup_time = 0.0
	pending_attack_time = 0.0
	attack_recovery_time = 0.18
	stagger(0.90)
	set_meta("last_boss_interrupt", reason)
	special_attack_interrupted.emit(self, attack_id, reason)
	return true

func _boss_attack_radius(attack_id: String) -> float:
	return {
		"bell_shockwave": 4.8,
		"grave_slam": 3.7,
		"ghoulkin_call": 3.2,
		"root_lanes": 4.0,
		"ground_rupture": 4.1,
		"heart_stagger": 2.9,
		"wing_blast": 4.6,
		"ash_breath": 5.6,
		"swoop": 3.6,
		"parry_test": 2.3,
		"counter_lunge": 2.6,
		"memory_echo": 4.4,
		"antler_sweep": 3.8,
		"road_reopening": 4.0,
	}.get(attack_id, attack_range + 0.8)

func _has_attack_line() -> bool:
	var origin := global_position+Vector3(0,0.9,0)
	var target: Vector3 = player.global_position+Vector3(0,0.9,0)
	var query := PhysicsRayQueryParameters3D.create(origin,target)
	query.exclude = [get_rid(),player.get_rid()]
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _crowd_separation() -> Vector3:
	var separation := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other) or bool(other.get("dead")):
			continue
		var offset: Vector3 = global_position-other.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 0.01 and distance < 1.55:
			separation += offset.normalized()*(1.55-distance)/1.55
	return separation.normalized() if separation.length_squared() > 0.01 else Vector3.ZERO

func _engagement_target(target_position: Vector3 = Vector3.INF) -> Vector3:
	var focus: Vector3 = player.global_position if target_position == Vector3.INF else target_position
	var radial: Vector3 = global_position - focus
	radial.y = 0.0
	if radial.length_squared() < 0.01:
		radial = Vector3.FORWARD
	var side := flank_sign
	if encounter_slot > 0:
		side = -1.0 if encounter_slot % 2 == 0 else 1.0
	var angle := deg_to_rad(approach_angle_degrees * side)
	var desired: Vector3 = radial.normalized().rotated(Vector3.UP, angle)
	return focus + desired * preferred_distance

func _update_perception(delta: float, player_distance: float) -> void:
	perception_refresh_time = maxf(perception_refresh_time - delta, 0.0)
	perception_memory_time = maxf(perception_memory_time - delta, 0.0)
	if perception_refresh_time > 0.0:
		return
	perception_refresh_time = 0.18
	can_see_player = player_distance <= sense_range and _has_perception_line()
	if can_see_player:
		last_known_player_position = player.global_position
		perception_memory_time = perception_memory_duration

func _has_perception_line() -> bool:
	if not is_inside_tree() or player == null or not player.is_inside_tree():
		return false
	var origin := global_position + Vector3(0, 1.20, 0)
	var target: Vector3 = player.global_position + Vector3(0, 1.05, 0)
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == player

func _attack_lane_clear() -> bool:
	var start := global_position
	var finish: Vector3 = player.global_position
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other) or bool(other.get("dead")) or not bool(other.get("encounter_active")):
			continue
		var other_pos: Vector3 = other.global_position
		var closest := Geometry3D.get_closest_point_to_segment(other_pos, start, finish)
		if other_pos.distance_to(closest) < 0.72 and start.distance_to(other_pos) < start.distance_to(finish):
			return false
	return true

func _attack_contact_point() -> Vector3:
	if animation_driver != null and animation_driver.is_valid():
		var skeleton: Skeleton3D = animation_driver.get_skeleton()
		if skeleton != null and attack_contact_bone >= 0:
			attack_trace_uses_skeleton = true
			return (skeleton.global_transform * skeleton.get_bone_global_pose(attack_contact_bone)).origin
	attack_trace_uses_skeleton = false
	return global_position + Vector3(0.0, 1.05, 0.0)

func get_attack_trace() -> Dictionary:
	return {"start":attack_trace_start, "end":attack_trace_end, "contact":last_attack_contact, "uses_skeleton":attack_trace_uses_skeleton}

func get_behavior_state() -> Dictionary:
	return {"profile":behavior_profile,"windup":pending_attack_time,"stagger":stagger_time,"recovery":attack_recovery_time,"owns_attack_token":owns_attack_token,"can_see_player":can_see_player,"memory":perception_memory_time,"last_known":last_known_player_position}

func get_tactical_state() -> Dictionary:
	var route_safe := true
	for index in range(navigation_route.size()):
		if spatial_service != null:
			var point: Vector3 = navigation_route[index]
			var validated: Vector3 = spatial_service.validate_position(point, 0.50, spatial_service.bank_for(point))
			if spatial_service.is_river_excluded(point, 0.50) or validated.distance_to(point) > 0.12:
				route_safe = false
				break
		if index > 0 and spatial_service != null and not spatial_service.validate_segment(navigation_route[index - 1], navigation_route[index], 0.50):
			route_safe = false
			break
	return {
		"enemy_id": enemy_id,
		"profile": behavior_profile,
		"preferred_distance": preferred_distance,
		"approach_angle": approach_angle_degrees,
		"flank_sign": flank_sign,
		"encounter_slot": encounter_slot,
		"leash_radius": leash_radius,
		"route_points": navigation_route.size(),
		"route_safe": route_safe,
		"navigation_refresh_time": navigation_refresh_time,
		"owns_attack_token": owns_attack_token,
		"attack_lane_clear": _attack_lane_clear() if player != null else false,
		"perception": can_see_player,
		"memory": perception_memory_time,
		"windup": pending_attack_time,
		"attack_recovery": attack_recovery_time,
	}

func _on_died() -> void:
	dead = true
	death_pose_time = 1.0
	_hide_windup_marker()
	_release_attack_token()
	collision_layer = 0
	collision_mask = 0
	if animation_driver != null and animation_driver.is_valid():
		animation_driver.set_dead()
	elif visual_root != null:
		visual_root.rotation_degrees.x = 84.0
		visual_root.rotation_degrees.y += -28.0 if randf() > 0.5 else 28.0
		visual_root.rotation_degrees.z = -38.0 if randf() > 0.5 else 38.0
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
	if is_boss:
		return {"white_hart_avatar":0.44, "bell_eater":0.78, "rootbound_colossus":0.92, "ashwing":0.64, "halvern_boss":0.48}.get(enemy_id, 0.60)
	if enemy_id == "wychwood_brute":
		return 0.72
	if enemy_id == "ghoulkin" or enemy_id == "wychwood_stalker" or enemy_id == "wychwood_raider":
		return 0.46
	return 0.34

func _attack_cooldown() -> float:
	if is_boss:
		return {"white_hart_avatar":[1.55, 1.32, 1.16], "bell_eater":[1.80,1.48,1.18], "rootbound_colossus":[2.10,1.72,1.35], "ashwing":[1.65,1.28,1.00], "halvern_boss":[1.38,1.05,0.90]}.get(enemy_id, [1.70,1.35,1.10])[boss_phase - 1]
	if enemy_id == "wychwood_brute":
		return 1.65
	if enemy_id == "ghoulkin" or enemy_id == "wychwood_stalker" or enemy_id == "wychwood_raider":
		return 1.32
	return 1.16

func _on_health_changed(current: float, maximum: float) -> void:
	damaged.emit(self, current, maximum)
	if not is_boss or maximum <= 0.0:
		return
	var ratio := current / maximum
	var next_phase := 3 if ratio <= 0.33 else (2 if ratio <= 0.66 else 1)
	if next_phase == boss_phase:
		return
	boss_phase = next_phase
	move_speed = base_move_speed * [1.0, 1.10, 1.18][boss_phase - 1]
	damage = base_damage * [1.0, 1.08, 1.15][boss_phase - 1]
	boss_phase_changed.emit(self, boss_phase)

func _build_body(color: Color) -> void:
	add_to_group("enemies")
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	var role_spec := CharacterRoleSpec.for_role(enemy_id)
	var collision_height := 3.30 if enemy_id == "white_hart_avatar" else float(role_spec.get("collision_height", 1.15))
	var collision_radius := 0.78 if enemy_id == "white_hart_avatar" else float(role_spec.get("collision_radius", 0.35))
	if is_boss:
		collision_height = {
			"bell_eater": 3.60,
			"rootbound_colossus": 4.10,
			"ashwing": 2.45,
			"halvern_boss": 2.20,
		}.get(enemy_id, collision_height)
		collision_radius = {
			"bell_eater": 0.82,
			"rootbound_colossus": 1.05,
			"ashwing": 0.66,
			"halvern_boss": 0.50,
		}.get(enemy_id, collision_radius)
	shape.height = collision_height
	shape.radius = collision_radius
	collision.shape = shape
	collision.position.y = shape.height * 0.5 + shape.radius * 0.18
	add_child(collision)
	visual_root = Node3D.new()
	visual_root.name = "visual_root"
	add_child(visual_root)
	if enemy_id == "white_hart_avatar" and _try_build_mapped_body():
		CharacterPresentation.apply_enemy(self, _enemy_shadow_scale())
		return
	if enemy_id == "white_hart_avatar":
		_build_hart_body()
		CharacterPresentation.apply_enemy(self, _enemy_shadow_scale())
		return
	if _try_build_mapped_body():
		CharacterPresentation.apply_enemy(self, _enemy_shadow_scale())
		return

	var body = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.height = 1.05
	mesh.radius = 0.38
	body.mesh = mesh
	body.position.y = 0.65
	body.material_override = _mat(color)
	visual_root.add_child(body)
	body_visual = body

	if enemy_id == "bog_wretch":
		body.scale = Vector3(1.25, 0.9, 1.25)
		_add_part(Vector3(0, 1.22, 0), Vector3(0.55, 0.16, 0.55), Color(0.18, 0.27, 0.18), "sphere")
		_add_part(Vector3(0.38, 0.52, -0.1), Vector3(0.12, 0.6, 0.12), Color(0.20, 0.32, 0.22), "box")
		_add_part(Vector3(-0.38, 0.52, -0.1), Vector3(0.12, 0.6, 0.12), Color(0.20, 0.32, 0.22), "box")
	elif enemy_id == "gravebound_knight":
		body.scale = Vector3(1.05, 1.2, 1.05)
		_add_part(Vector3(0, 1.35, -0.04), Vector3(0.72, 0.35, 0.22), Color(0.19, 0.20, 0.22), "box")
		_add_part(Vector3(-0.58, 0.88, -0.08), Vector3(0.12, 0.18, 0.95), Color(0.48, 0.45, 0.38), "box")
		_add_part(Vector3(0.55, 0.82, -0.08), Vector3(0.16, 0.8, 0.16), Color(0.38, 0.38, 0.39), "box")
	elif enemy_id == "wychwood_stalker":
		body.scale = Vector3(1.45, 0.55, 0.7)
		_add_part(Vector3(0.0, 0.92, -0.52), Vector3(0.35, 0.2, 0.35), Color(0.10, 0.24, 0.12), "sphere")
		_add_part(Vector3(0.22, 1.08, -0.62), Vector3(0.06, 0.38, 0.06), Color(0.33, 0.26, 0.18), "box")
		_add_part(Vector3(-0.22, 1.08, -0.62), Vector3(0.06, 0.38, 0.06), Color(0.33, 0.26, 0.18), "box")
	elif enemy_id == "white_hart_avatar":
		body.scale = Vector3(1.25, 1.4, 1.0)
		_add_part(Vector3(0, 1.55, -0.35), Vector3(0.35, 0.28, 0.35), Color(0.82, 0.80, 0.70), "sphere")
		_add_part(Vector3(0.28, 1.9, -0.38), Vector3(0.06, 0.65, 0.06), Color(0.48, 0.42, 0.31), "box")
		_add_part(Vector3(-0.28, 1.9, -0.38), Vector3(0.06, 0.65, 0.06), Color(0.48, 0.42, 0.31), "box")
	else:
		_add_part(Vector3(0.22, 0.92, -0.28), Vector3(0.12, 0.5, 0.12), Color(0.36, 0.36, 0.29), "box")
		_add_part(Vector3(-0.22, 0.92, -0.28), Vector3(0.12, 0.5, 0.12), Color(0.36, 0.36, 0.29), "box")
	base_body_scale = body.scale
	CharacterPresentation.apply_enemy(self, _enemy_shadow_scale())

	var marker = MeshInstance3D.new()
	marker.name = "EnemyWeakPointMarker"
	marker.mesh = SphereMesh.new()
	marker.scale = Vector3(0.09, 0.09, 0.09)
	marker.position = Vector3(0, 1.55, -0.35)
	marker.material_override = _mat(Color(0.95, 0.22, 0.12))
	visual_root.add_child(marker)

func _build_hart_body() -> void:
	var body_material := _mat(Color(0.52, 0.72, 0.62))
	body_material.emission_enabled = true
	body_material.emission = Color(0.10, 0.30, 0.22)
	body_material.emission_energy_multiplier = 0.42
	var shadow_material := _mat(Color(0.10, 0.16, 0.15))
	var antler_material := _mat(Color(0.58, 0.48, 0.30))
	# Keep the witness animal-shaped. The earlier upright chest/neck read as a
	# humanoid mannequin from the approach road even though it had antlers.
	body_visual = _hart_mesh("HartBody", CapsuleMesh.new(), Vector3(0, 1.28, 0.08), Vector3(0.88, 1.48, 0.72), body_material, Vector3(90, 0, 0))
	_hart_mesh("HartRump", SphereMesh.new(), Vector3(0, 1.34, 0.66), Vector3(0.72, 0.58, 0.62), body_material)
	_hart_mesh("HartChest", SphereMesh.new(), Vector3(0, 1.42, -0.66), Vector3(0.68, 0.66, 0.56), body_material)
	_hart_mesh("HartNeck", CapsuleMesh.new(), Vector3(0, 1.78, -0.88), Vector3(0.40, 0.60, 0.40), body_material, Vector3(-48, 0, 0))
	_hart_mesh("HartHead", SphereMesh.new(), Vector3(0, 2.08, -1.34), Vector3(0.50, 0.40, 0.60), body_material)
	_hart_mesh("HartMuzzle", SphereMesh.new(), Vector3(0, 1.99, -1.74), Vector3(0.30, 0.18, 0.40), body_material)
	_hart_mesh("HartMane", SphereMesh.new(), Vector3(0, 1.78, -0.70), Vector3(0.38, 0.54, 0.32), shadow_material)
	_hart_mesh("HartEar", SphereMesh.new(), Vector3(-0.30, 2.28, -1.16), Vector3(0.20, 0.10, 0.28), shadow_material, Vector3(0, 0, -18))
	_hart_mesh("HartEar", SphereMesh.new(), Vector3(0.30, 2.28, -1.16), Vector3(0.20, 0.10, 0.28), shadow_material, Vector3(0, 0, 18))
	_hart_mesh("HartTail", CapsuleMesh.new(), Vector3(0, 1.56, 1.10), Vector3(0.16, 0.42, 0.16), shadow_material, Vector3(-34, 0, 0))
	for side in [-1.0, 1.0]:
		for z in [-0.46, 0.52]:
			_hart_mesh("HartLeg", CapsuleMesh.new(), Vector3(side * 0.44, 0.60, z), Vector3(0.15, 0.68, 0.15), shadow_material)
			_hart_mesh("HartHoof", BoxMesh.new(), Vector3(side * 0.44, 0.12, z - 0.08), Vector3(0.22, 0.14, 0.30), antler_material)
		_hart_mesh("HartAntlerMain", CylinderMesh.new(), Vector3(side * 0.25, 2.58, -1.30), Vector3(0.10, 0.74, 0.10), antler_material, Vector3(0, 0, side * -18.0))
		_hart_mesh("HartAntlerBranch", CylinderMesh.new(), Vector3(side * 0.48, 2.88, -1.30), Vector3(0.065, 0.42, 0.065), antler_material, Vector3(0, 0, side * 34.0))
		var eye := _hart_mesh("HartEye", SphereMesh.new(), Vector3(side * 0.18, 2.14, -1.70), Vector3(0.070, 0.070, 0.070), _mat(Color(0.52, 1.0, 0.78)))
		var eye_material := eye.material_override as StandardMaterial3D
		if eye_material != null:
			eye_material.emission_enabled = true
			eye_material.emission = Color(0.52, 1.0, 0.78)
			eye_material.emission_energy_multiplier = 2.0
	_hart_mesh("HartSigilLight", SphereMesh.new(), Vector3(0, 1.42, -0.70), Vector3(0.13, 0.13, 0.13), _mat(Color(0.52, 1.0, 0.78)))

func _hart_mesh(node_name: String, mesh: Mesh, position: Vector3, scale_value: Vector3, material: Material, rotation_degrees := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	node.scale = scale_value
	node.rotation_degrees = rotation_degrees
	node.material_override = material
	visual_root.add_child(node)
	return node

func _try_build_mapped_body() -> bool:
	asset_helper = AssetSpawnHelper.new()
	add_child(asset_helper)
	var mapped = null
	var uses_real_body := false
	var visual_source: String = enemy_id
	if enemy_id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "bog_wretch", "gravebound_knight", "bell_eater", "rootbound_colossus", "ashwing", "halvern_boss", "white_hart_avatar"]:
		visual_source = {
			"ghoulkin": "ghoul_gaunt_real",
			"wychwood_stalker": "ghoul_stalker_real",
			"wychwood_raider": "ghoul_gaunt_real",
			"wychwood_brute": "ghoul_brute_real",
			"bog_wretch": "bog_wretch_creature",
			"gravebound_knight": "gravebound_knight_creature",
			"bell_eater": "bell_eater_boss",
			"rootbound_colossus": "rootbound_colossus_boss",
			"ashwing": "ashwing_boss",
			"halvern_boss": "gravebound_knight_creature",
			"white_hart_avatar": "white_hart_boss",
		}.get(enemy_id, "ghoul_gaunt_real")
		mapped = asset_helper.spawn_visual_role(visual_source, "enemies")
		uses_real_body = mapped != null and not mapped.name.ends_with("_placeholder")
	if mapped == null:
		mapped = asset_helper.spawn_enemy(visual_source)
	if mapped == null or mapped.name.ends_with("_placeholder"):
		if mapped != null:
			mapped.queue_free()
		return false
	mapped.name = "%s_visual" % enemy_id
	mapped.set_meta("monster_family_role", visual_source)
	mapped.set_meta("monster_behavior_profile", behavior_profile)
	asset_helper.apply_normalized_scale(mapped, _mapped_enemy_scale().y)
	if _is_wychwood_pack():
		var profile_scale: Vector3 = {
			"ghoulkin": Vector3(0.82, 1.0, 0.86),
			"wychwood_stalker": Vector3(0.70, 1.0, 0.78),
			"wychwood_raider": Vector3(0.90, 1.0, 0.88),
			"wychwood_brute": Vector3(1.12, 1.0, 1.04)
		}.get(enemy_id, Vector3.ONE)
		mapped.scale *= profile_scale
	if enemy_id == "white_hart_avatar":
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.86, 0.83, 0.70)
		material.emission_enabled = true
		material.emission = Color(0.78, 0.86, 0.92)
		material.emission_energy_multiplier = 0.25
		_apply_material(mapped, material)
	elif _is_wychwood_pack():
		_apply_material(mapped, _horror_material())
	if is_boss:
		_apply_boss_material(mapped)
	visual_root.add_child(mapped)
	if _is_wychwood_pack():
		# Variant identity is carried by the imported skeleton, role material,
		# scale, locomotion profile, and attack spacing. Do not add detached
		# root-mounted anatomy on top of a valid animated body.
		mapped.set_meta("monster_variant_profile", enemy_id)
	_ground_mapped_visual(mapped)
	mapped.position.y += CharacterRoleSpec.ground_offset(visual_source)
	if is_boss:
		_add_boss_silhouette()
	if enemy_id == "white_hart_avatar":
		_add_spectral_antler_crown(mapped)
	body_visual = _find_first_mesh(mapped)
	base_body_scale = mapped.scale
	animation_driver = CharacterAnimationDriver.new()
	animation_driver.name = "CharacterAnimationDriver"
	mapped.add_child(animation_driver)
	if uses_real_body:
		if visual_source in ["ashwing_creature", "ashwing_boss"]:
			animation_driver.configure(mapped, {
				"idle":"DragonArmature|Dragon_Flying", "walk":"DragonArmature|Dragon_Flying",
				"walk_back":"DragonArmature|Dragon_Flying", "strafe":"DragonArmature|Dragon_Flying",
				"run":"DragonArmature|Dragon_Flying", "windup":"DragonArmature|Dragon_Attack",
				"attack":"DragonArmature|Dragon_Attack2", "hit":"DragonArmature|Dragon_Hit",
				"death":"DragonArmature|Dragon_Death"
			})
		elif visual_source in ["white_hart_avatar", "white_hart_boss"]:
			animation_driver.configure(mapped, {
				"idle": "|WolfArmature|Idle", "walk": "|WolfArmature|Walking",
				"walk_back": "|WolfArmature|Walking", "strafe": "|WolfArmature|Walking",
				"run": "|WolfArmature|Walking", "windup": "|WolfArmature|Walking",
				"attack": "|WolfArmature|Walking", "hit": "|WolfArmature|Walking",
				"death": "|WolfArmature|Walking"
			})
		else:
			animation_driver.configure(mapped, {
				"idle": "Idle",
				"walk":"Walk", "walk_back":"Walk", "strafe":"Walk",
				"run":"Run", "windup":"Attack", "attack":"Attack",
				"hit":"RecieveHit", "death":"Death"
			})
	elif visual_source == "ghoulkin_skeleton":
		animation_driver.configure(mapped, {
			"idle": "SkeletonArmature|Skeleton_Idle",
			"windup": "SkeletonArmature|Skeleton_Attack",
			"walk": "SkeletonArmature|Skeleton_Running",
			"run": "SkeletonArmature|Skeleton_Running",
			"attack": "SkeletonArmature|Skeleton_Attack",
			"hit": "SkeletonArmature|Skeleton_Spawn",
			"death": "SkeletonArmature|Skeleton_Death"
		})
	else:
		animation_driver.configure(mapped, {
			"idle": "Idle", "walk": "Walk", "run": "Run", "jump": "Jump_Idle",
			"windup": "Punch",
			"attack": "Punch", "hit": "HitReact", "death": "Death"
		})
	if animation_driver.is_valid():
		animation_driver.set_update_rate_hz(20.0)
	_configure_attack_contact_bone()
	return true

func _add_spectral_antler_crown(mapped: Node3D) -> void:
	var skeleton := _find_type(mapped, "Skeleton3D") as Skeleton3D
	var parent: Node3D = mapped
	if skeleton != null:
		var attachment := BoneAttachment3D.new()
		attachment.name = "WhiteHartAntlerHeadAttachment"
		attachment.bone_name = "Bone.003"
		skeleton.add_child(attachment)
		parent = attachment
		# The imported Wolf FBX carries a large head-bone scale. Compensate only
		# that scale so the antlers remain attached without becoming world-sized.
		var mapped_scale := mapped.global_transform.basis.get_scale() if mapped.is_inside_tree() else Vector3.ONE
		var attachment_scale := attachment.global_transform.basis.get_scale() if attachment.is_inside_tree() else Vector3(19.36, 19.36, 19.36)
		var bone_scale := Vector3(
			_safe_scale_ratio(attachment_scale.x, mapped_scale.x),
			_safe_scale_ratio(attachment_scale.y, mapped_scale.y),
			_safe_scale_ratio(attachment_scale.z, mapped_scale.z)
		)
		var crown_root := Node3D.new()
		crown_root.name = "WhiteHartAntlerScaleCompensation"
		crown_root.scale = Vector3(
			_safe_inverse_scale(bone_scale.x),
			_safe_inverse_scale(bone_scale.y),
			_safe_inverse_scale(bone_scale.z)
		)
		parent.add_child(crown_root)
		parent = crown_root
	var antler_material := _mat(Color(0.58, 0.48, 0.30))
	antler_material.emission_enabled = true
	antler_material.emission = Color(0.20, 0.48, 0.34)
	antler_material.emission_energy_multiplier = 0.42
	for side in [-1.0, 1.0]:
		var main := MeshInstance3D.new()
		main.name = "SpectralAntlerMain"
		var main_mesh := CylinderMesh.new()
		main_mesh.top_radius = 0.025
		main_mesh.bottom_radius = 0.055
		main_mesh.height = 0.78
		main_mesh.radial_segments = 8
		main.mesh = main_mesh
		main.position = Vector3(side * 0.16, 0.28, 0.01)
		main.rotation_degrees.z = side * -20.0
		main.material_override = antler_material
		parent.add_child(main)
		for branch_index in range(2):
			var branch := MeshInstance3D.new()
			branch.name = "SpectralAntlerBranch"
			var branch_mesh := CylinderMesh.new()
			branch_mesh.top_radius = 0.014
			branch_mesh.bottom_radius = 0.035
			branch_mesh.height = 0.34 if branch_index == 0 else 0.25
			branch_mesh.radial_segments = 8
			branch.mesh = branch_mesh
			branch.position = Vector3(side * (0.29 + branch_index * 0.06), 0.46 + branch_index * 0.17, 0.01)
			branch.rotation_degrees.z = side * (42.0 if branch_index == 0 else -36.0)
			branch.material_override = antler_material
			parent.add_child(branch)
	var sigil := MeshInstance3D.new()
	sigil.name = "WhiteHartCrownGlow"
	sigil.mesh = SphereMesh.new()
	sigil.scale = Vector3(0.08, 0.08, 0.08)
	sigil.position = Vector3(0, 0.06, -0.12)
	var sigil_material := _mat(Color(0.50, 0.96, 0.72))
	sigil_material.emission_enabled = true
	sigil_material.emission = Color(0.50, 0.96, 0.72)
	sigil_material.emission_energy_multiplier = 1.4
	sigil.material_override = sigil_material
	parent.add_child(sigil)

func _find_type(root: Node, type_name: String) -> Node:
	if root.is_class(type_name):
		return root
	for child in root.get_children():
		var found := _find_type(child, type_name)
		if found != null:
			return found
	return null

func _safe_scale_ratio(value: float, divisor: float) -> float:
	if absf(divisor) < 0.0001:
		return 1.0
	return value / divisor

func _safe_inverse_scale(value: float) -> float:
	if absf(value) < 0.0001:
		return 1.0
	return 1.0 / value

func _configure_attack_contact_bone() -> void:
	attack_contact_bone = -1
	if animation_driver == null or not animation_driver.is_valid():
		return
	var skeleton: Skeleton3D = animation_driver.get_skeleton()
	if skeleton == null:
		return
	var preferred := ["hand.r", "hand_r", "righthand", "right_hand", "mixamorig:righthand", "head", "jaw", "hand.l", "hand_l", "lefthand", "left_hand"]
	for index in range(skeleton.get_bone_count()):
		var compact: String = skeleton.get_bone_name(index).to_lower().replace(" ", "").replace("-", "").replace("_", "").replace(".", "").replace(":", "")
		for candidate in preferred:
			var wanted: String = candidate.replace(".", "").replace(":", "").replace("_", "")
			if compact.contains(wanted):
				attack_contact_bone = index
				return

func _ground_mapped_visual(mapped: Node3D) -> void:
	var state := {"initialized": false, "bounds": AABB()}
	_accumulate_visual_bounds(mapped, Transform3D.IDENTITY, state)
	if bool(state.initialized):
		var bounds: AABB = state.bounds
		mapped.position.y -= bounds.position.y

func _accumulate_visual_bounds(node: Node, parent_transform: Transform3D, state: Dictionary) -> void:
	var current_transform := parent_transform
	if node is Node3D and node != visual_root:
		current_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null and (mesh_instance.skin != null or mesh_instance.skeleton != NodePath("")):
			var mesh_bounds: AABB = current_transform * mesh_instance.mesh.get_aabb()
			state.bounds = (state.bounds as AABB).merge(mesh_bounds) if bool(state.initialized) else mesh_bounds
			state.initialized = true
	for child in node.get_children():
		_accumulate_visual_bounds(child, current_transform, state)

func _horror_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var texture_name := "ghoulkin_skin.jpg"
	if enemy_id == "wychwood_stalker": texture_name = "stalker_skin.jpg"
	elif enemy_id == "wychwood_brute": texture_name = "brute_skin.jpg"
	elif enemy_id == "wychwood_raider": texture_name = "ghoulkin_skin.jpg"
	material.albedo_texture = load("res://assets_external/textures/runtime/" + texture_name) as Texture2D
	material.albedo_color = Color(0.78, 0.80, 0.72)
	material.roughness = 0.76
	material.metallic = 0.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

func _apply_boss_material(mapped: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = {
		"bell_eater": Color(0.13, 0.075, 0.055),
		"rootbound_colossus": Color(0.22, 0.33, 0.20),
		"ashwing": Color(0.30, 0.18, 0.14),
		"halvern_boss": Color(0.24, 0.26, 0.30),
	}.get(enemy_id, base_color)
	material.roughness = 0.82
	if enemy_id == "bell_eater":
		material.emission_enabled = true
		material.emission = Color(0.045, 0.010, 0.004)
		material.emission_energy_multiplier = 0.22
	elif enemy_id == "halvern_boss":
		material.emission_enabled = true
		material.emission = Color(0.055, 0.075, 0.12)
		material.emission_energy_multiplier = 0.32
	_apply_material(mapped, material)

func _add_boss_silhouette() -> void:
	boss_visual_root = Node3D.new()
	boss_visual_root.name = "BossIdentityLayer"
	boss_visual_root.set_meta("boss_identity", enemy_id)
	boss_identity_base_scale = {
		"bell_eater": Vector3.ONE * 1.55,
		"rootbound_colossus": Vector3(1.45, 1.60, 1.45),
		"ashwing": Vector3(1.35, 1.22, 1.35),
	}.get(enemy_id, Vector3.ONE)
	boss_visual_root.scale = boss_identity_base_scale
	visual_root.add_child(boss_visual_root)
	if enemy_id == "bell_eater":
		# The imported body is the only anatomy. Earlier proxy torso/arm rods
		# floated beside it and made the boss look assembled from primitives.
		_make_bell_eater_identity()
	elif enemy_id == "rootbound_colossus":
		_make_rootbound_identity()
	elif enemy_id == "ashwing":
		_add_part(Vector3(-0.74, 1.24, 0.12), Vector3(0.82, 0.16, 0.46), Color(0.26, 0.16, 0.12), "capsule", Vector3(0, 0, -8))
		_add_part(Vector3(0.74, 1.24, 0.12), Vector3(0.82, 0.16, 0.46), Color(0.26, 0.16, 0.12), "capsule", Vector3(0, 0, 8))
		_add_part(Vector3(0, 1.28, 0.34), Vector3(0.22, 0.20, 0.46), Color(0.44, 0.20, 0.10), "cylinder", Vector3(90, 0, 0))
		_make_ashwing_identity()
	elif enemy_id == "halvern_boss":
		_make_halvern_identity()
	elif enemy_id == "white_hart_avatar":
		_make_white_hart_identity()

func _make_bell_eater_identity() -> void:
	var harness := MeshInstance3D.new()
	harness.name = "BellEaterHarnessBand"
	var harness_mesh := TorusMesh.new()
	harness_mesh.inner_radius = 0.48
	harness_mesh.outer_radius = 0.58
	harness_mesh.rings = 10
	harness_mesh.ring_segments = 20
	harness.mesh = harness_mesh
	harness.position = Vector3(0, 1.47, 0.02)
	harness.scale = Vector3(1.12, 0.78, 0.82)
	harness.rotation.x = PI * 0.5
	harness.material_override = _mat(Color(0.19, 0.12, 0.07))
	boss_visual_root.add_child(harness)

	var bell := MeshInstance3D.new()
	bell.name = "BellEaterChestBell"
	var bell_mesh := CylinderMesh.new()
	bell_mesh.top_radius = 0.20
	bell_mesh.bottom_radius = 0.36
	bell_mesh.height = 0.48
	bell_mesh.radial_segments = 14
	bell.mesh = bell_mesh
	bell.position = Vector3(0, 1.12, -0.38)
	bell.rotation.x = PI
	bell.scale = Vector3(0.78, 0.78, 0.78)
	bell.material_override = _mat(Color(0.42, 0.24, 0.10))
	boss_visual_root.add_child(bell)

	var clapper := MeshInstance3D.new()
	clapper.name = "BellEaterClapper"
	var clapper_mesh := SphereMesh.new()
	clapper_mesh.radius = 0.11
	clapper_mesh.height = 0.22
	clapper.mesh = clapper_mesh
	clapper.position = Vector3(0, 0.92, -0.40)
	clapper.material_override = _mat(Color(0.08, 0.06, 0.045))
	boss_visual_root.add_child(clapper)

	for side in [-1.0, 1.0]:
		var chain := MeshInstance3D.new()
		chain.name = "BellEaterChainLeft" if side < 0.0 else "BellEaterChainRight"
		var chain_mesh := CylinderMesh.new()
		chain_mesh.top_radius = 0.035
		chain_mesh.bottom_radius = 0.055
		chain_mesh.height = 0.92
		chain_mesh.radial_segments = 6
		chain.mesh = chain_mesh
		chain.position = Vector3(side * 0.44, 1.23, -0.22)
		chain.rotation_degrees = Vector3(0, 0, side * 18.0)
		chain.material_override = _mat(Color(0.12, 0.09, 0.06))
		boss_visual_root.add_child(chain)

	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.name = "BellEaterEyeLeft" if side < 0.0 else "BellEaterEyeRight"
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.075
		eye_mesh.height = 0.15
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.18, 1.78, -0.49)
		var eye_material := _mat(Color(0.96, 0.26, 0.08))
		eye_material.emission_enabled = true
		eye_material.emission = Color(0.96, 0.18, 0.04)
		eye_material.emission_energy_multiplier = 1.8
		eye.material_override = eye_material
		boss_visual_root.add_child(eye)

	var jaw := MeshInstance3D.new()
	jaw.name = "BellEaterJaw"
	var jaw_mesh := SphereMesh.new()
	jaw_mesh.radius = 0.28
	jaw_mesh.height = 0.22
	jaw.mesh = jaw_mesh
	jaw.position = Vector3(0, 1.58, -0.54)
	jaw.scale = Vector3(1.0, 0.72, 0.52)
	jaw.material_override = _mat(Color(0.075, 0.045, 0.035))
	boss_visual_root.add_child(jaw)
	for index in range(3):
		var tooth := MeshInstance3D.new()
		tooth.name = "BellEaterTooth_%d" % index
		var tooth_mesh := CylinderMesh.new()
		tooth_mesh.top_radius = 0.0
		tooth_mesh.bottom_radius = 0.038
		tooth_mesh.height = 0.15
		tooth_mesh.radial_segments = 6
		tooth.mesh = tooth_mesh
		tooth.position = Vector3(-0.13 + float(index) * 0.13, 1.53, -0.68)
		tooth.rotation.x = PI
		tooth.material_override = _mat(Color(0.58, 0.50, 0.36))
		boss_visual_root.add_child(tooth)
	for side in [-1.0, 1.0]:
		var horn := MeshInstance3D.new()
		horn.name = "BellEaterHornLeft" if side < 0.0 else "BellEaterHornRight"
		var horn_mesh := CylinderMesh.new()
		horn_mesh.top_radius = 0.018
		horn_mesh.bottom_radius = 0.07
		horn_mesh.height = 0.42
		horn_mesh.radial_segments = 7
		horn.mesh = horn_mesh
		horn.position = Vector3(side * 0.25, 1.94, -0.36)
		horn.rotation_degrees = Vector3(0, 0, side * -22.0)
		horn.material_override = _mat(Color(0.16, 0.12, 0.085))
		boss_visual_root.add_child(horn)

	boss_phase_sigil = MeshInstance3D.new()
	boss_phase_sigil.name = "BossPhaseSigil"
	var sigil_mesh := SphereMesh.new()
	sigil_mesh.radius = 0.12
	sigil_mesh.height = 0.24
	boss_phase_sigil.mesh = sigil_mesh
	boss_phase_sigil.position = Vector3(0, 1.52, -0.64)
	boss_phase_sigil.material_override = _emissive_boss_material(Color(0.62, 0.28, 0.14), 0.72)
	boss_visual_root.add_child(boss_phase_sigil)

func _make_rootbound_identity() -> void:
	# The body source supplies the animated mass; this layer gives Rootbound a
	# readable story silhouette: bark harness, root arms, and an exposed oathwood
	# heart that brightens as the phases open it.
	var harness := MeshInstance3D.new()
	harness.name = "RootboundBarkHarness"
	var harness_mesh := TorusMesh.new()
	harness_mesh.inner_radius = 0.60
	harness_mesh.outer_radius = 0.72
	harness_mesh.rings = 10
	harness_mesh.ring_segments = 18
	harness.mesh = harness_mesh
	harness.position = Vector3(0, 1.38, 0.02)
	harness.scale = Vector3(1.18, 0.74, 0.92)
	harness.rotation.x = PI * 0.5
	harness.material_override = _mat(Color(0.12, 0.20, 0.10))
	boss_visual_root.add_child(harness)

	var mantle := MeshInstance3D.new()
	mantle.name = "RootboundShoulderMantle"
	var mantle_mesh := SphereMesh.new()
	mantle_mesh.radius = 0.72
	mantle_mesh.height = 0.72
	mantle.mesh = mantle_mesh
	mantle.position = Vector3(0, 1.96, 0.02)
	mantle.scale = Vector3(1.48, 0.46, 0.88)
	mantle.material_override = _mat(Color(0.10, 0.16, 0.08))
	boss_visual_root.add_child(mantle)

	for side in [-1.0, 1.0]:
		var root_arm := MeshInstance3D.new()
		root_arm.name = "RootboundRootArmLeft" if side < 0.0 else "RootboundRootArmRight"
		var arm_mesh := CylinderMesh.new()
		arm_mesh.top_radius = 0.055
		arm_mesh.bottom_radius = 0.13
		arm_mesh.height = 1.22
		arm_mesh.radial_segments = 8
		root_arm.mesh = arm_mesh
		root_arm.position = Vector3(side * 0.68, 1.10, -0.10)
		root_arm.rotation_degrees = Vector3(0, 0, side * -25.0)
		root_arm.material_override = _mat(Color(0.18, 0.25, 0.11))
		boss_visual_root.add_child(root_arm)
		for branch_index in range(2):
			var branch := MeshInstance3D.new()
			branch.name = "RootboundBranch"
			var branch_mesh := CylinderMesh.new()
			branch_mesh.top_radius = 0.018
			branch_mesh.bottom_radius = 0.06
			branch_mesh.height = 0.52 if branch_index == 0 else 0.38
			branch_mesh.radial_segments = 7
			branch.mesh = branch_mesh
			branch.position = Vector3(side * (0.86 + branch_index * 0.08), 1.42 + branch_index * 0.25, -0.12)
			branch.rotation_degrees = Vector3(0, 0, side * (42.0 if branch_index == 0 else -34.0))
			branch.material_override = _mat(Color(0.24, 0.31, 0.14))
			boss_visual_root.add_child(branch)

	for side in [-1.0, 1.0]:
		var foot_root := MeshInstance3D.new()
		foot_root.name = "RootboundRootFootLeft" if side < 0.0 else "RootboundRootFootRight"
		var foot_mesh := CylinderMesh.new()
		foot_mesh.top_radius = 0.07
		foot_mesh.bottom_radius = 0.25
		foot_mesh.height = 0.82
		foot_mesh.radial_segments = 8
		foot_root.mesh = foot_mesh
		foot_root.position = Vector3(side * 0.50, 0.34, 0.08)
		foot_root.rotation_degrees = Vector3(0, 0, side * -22.0)
		foot_root.material_override = _mat(Color(0.16, 0.23, 0.10))
		boss_visual_root.add_child(foot_root)

	for crown_index in range(3):
		var crown := MeshInstance3D.new()
		crown.name = "RootboundCrownBranch"
		var crown_mesh := CylinderMesh.new()
		crown_mesh.top_radius = 0.025
		crown_mesh.bottom_radius = 0.11
		crown_mesh.height = 0.92 if crown_index == 1 else 0.68
		crown_mesh.radial_segments = 8
		crown.mesh = crown_mesh
		crown.position = Vector3((float(crown_index) - 1.0) * 0.34, 2.40 + (0.12 if crown_index == 1 else 0.0), 0.10)
		crown.rotation_degrees = Vector3(0, (float(crown_index) - 1.0) * 12.0, (float(crown_index) - 1.0) * -18.0)
		crown.material_override = _mat(Color(0.19, 0.28, 0.12))
		boss_visual_root.add_child(crown)

	var heart := MeshInstance3D.new()
	heart.name = "RootboundHeart"
	var heart_mesh := SphereMesh.new()
	heart_mesh.radius = 0.20
	heart_mesh.height = 0.38
	heart.mesh = heart_mesh
	heart.position = Vector3(0, 1.66, -0.68)
	heart.scale = Vector3(1.05, 1.35, 0.72)
	heart.material_override = _emissive_boss_material(Color(0.36, 0.78, 0.30), 0.90)
	boss_visual_root.add_child(heart)
	boss_phase_sigil = heart

	var bark_plate := MeshInstance3D.new()
	bark_plate.name = "RootboundBarkPlate"
	var plate_mesh := CylinderMesh.new()
	plate_mesh.top_radius = 0.32
	plate_mesh.bottom_radius = 0.42
	plate_mesh.height = 0.18
	plate_mesh.radial_segments = 10
	bark_plate.mesh = plate_mesh
	bark_plate.position = Vector3(0, 1.72, -0.46)
	bark_plate.rotation.x = PI * 0.5
	bark_plate.scale = Vector3(1.0, 0.78, 0.80)
	bark_plate.material_override = _mat(Color(0.12, 0.18, 0.09))
	boss_visual_root.add_child(bark_plate)

func _make_ashwing_identity() -> void:
	# Ashwing's mapped dragon supplies the animated silhouette. These restrained
	# details establish the burned-mill identity without adding a second body:
	# a charred harness, ember core, and scorched wing roots.
	var harness := MeshInstance3D.new()
	harness.name = "AshwingBurntHarness"
	var harness_mesh := TorusMesh.new()
	harness_mesh.inner_radius = 0.46
	harness_mesh.outer_radius = 0.56
	harness_mesh.rings = 10
	harness_mesh.ring_segments = 18
	harness.mesh = harness_mesh
	harness.position = Vector3(0, 1.28, 0.10)
	harness.scale = Vector3(1.36, 0.52, 0.86)
	harness.rotation.x = PI * 0.5
	harness.material_override = _mat(Color(0.16, 0.08, 0.05))
	boss_visual_root.add_child(harness)

	var core := MeshInstance3D.new()
	core.name = "AshwingAshCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.19
	core_mesh.height = 0.36
	core.mesh = core_mesh
	core.position = Vector3(0, 1.34, -0.48)
	core.scale = Vector3(1.0, 0.82, 0.70)
	core.material_override = _emissive_boss_material(Color(0.96, 0.30, 0.06), 1.15)
	boss_visual_root.add_child(core)
	boss_phase_sigil = core

	for side in [-1.0, 1.0]:
		var scorch := MeshInstance3D.new()
		scorch.name = "AshwingScorchedWingRootLeft" if side < 0.0 else "AshwingScorchedWingRootRight"
		var scorch_mesh := CapsuleMesh.new()
		scorch.mesh = scorch_mesh
		scorch.position = Vector3(side * 0.64, 1.30, 0.10)
		scorch.scale = Vector3(0.48, 0.10, 0.22)
		scorch.rotation_degrees = Vector3(0, 0, side * 12.0)
		scorch.material_override = _mat(Color(0.38, 0.12, 0.055))
		boss_visual_root.add_child(scorch)

func _make_halvern_identity() -> void:
	# Halvern's mapped body is the connected Gravebound family. This layer
	# supplies a readable Vargan cuirass, broken oath seal, and asymmetric
	# shoulder silhouette without introducing a second root-mounted body.
	var cuirass := MeshInstance3D.new()
	cuirass.name = "HalvernVarganCuirass"
	var cuirass_mesh := BoxMesh.new()
	cuirass_mesh.size = Vector3(0.78, 0.72, 0.34)
	cuirass.mesh = cuirass_mesh
	cuirass.position = Vector3(0, 1.30, -0.18)
	cuirass.scale = Vector3(1.0, 1.0, 0.82)
	cuirass.material_override = _mat(Color(0.16, 0.18, 0.22))
	boss_visual_root.add_child(cuirass)

	var seal := MeshInstance3D.new()
	seal.name = "HalvernGraveSeal"
	var seal_mesh := TorusMesh.new()
	seal_mesh.inner_radius = 0.12
	seal_mesh.outer_radius = 0.17
	seal_mesh.rings = 8
	seal_mesh.ring_segments = 14
	seal.mesh = seal_mesh
	seal.position = Vector3(0, 1.37, -0.40)
	seal.rotation.x = PI * 0.5
	seal.material_override = _emissive_boss_material(Color(0.36, 0.48, 0.72), 0.78)
	boss_visual_root.add_child(seal)
	boss_phase_sigil = seal

	for side in [-1.0, 1.0]:
		var shoulder := MeshInstance3D.new()
		shoulder.name = "HalvernShoulderLeft" if side < 0.0 else "HalvernShoulderRight"
		var shoulder_mesh := CapsuleMesh.new()
		shoulder.mesh = shoulder_mesh
		shoulder.position = Vector3(side * 0.52, 1.55, -0.04)
		shoulder.scale = Vector3(0.28, 0.32, 0.42 if side < 0.0 else 0.30)
		shoulder.rotation_degrees = Vector3(0, 0, side * 16.0)
		shoulder.material_override = _mat(Color(0.22, 0.24, 0.29))
		boss_visual_root.add_child(shoulder)

	var banner := MeshInstance3D.new()
	banner.name = "HalvernBrokenBanner"
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(0.08, 0.92, 0.05)
	banner.mesh = banner_mesh
	banner.position = Vector3(-0.42, 1.25, 0.26)
	banner.rotation_degrees = Vector3(0, 0, -12.0)
	banner.material_override = _mat(Color(0.24, 0.10, 0.09))
	boss_visual_root.add_child(banner)

func _make_white_hart_identity() -> void:
	# The Wolf source and bone-attached antlers supply the body. These pieces
	# establish the Hart's memory-covenant identity without duplicating anatomy:
	# a ground halo, chest oath mark, and restrained spectral rings.
	var halo := MeshInstance3D.new()
	halo.name = "WhiteHartMemoryHalo"
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 1.26
	halo_mesh.outer_radius = 1.40
	halo_mesh.rings = 16
	halo_mesh.ring_segments = 24
	halo.mesh = halo_mesh
	halo.position = Vector3(0, 0.12, 0.0)
	halo.rotation.x = PI * 0.5
	halo.material_override = _emissive_boss_material(Color(0.22, 0.68, 0.48), 0.62)
	boss_visual_root.add_child(halo)

	var oath_mark := MeshInstance3D.new()
	oath_mark.name = "WhiteHartOathMark"
	var mark_mesh := SphereMesh.new()
	mark_mesh.radius = 0.16
	mark_mesh.height = 0.32
	oath_mark.mesh = mark_mesh
	oath_mark.position = Vector3(0, 1.55, -0.60)
	oath_mark.scale = Vector3(0.88, 1.42, 0.70)
	oath_mark.material_override = _emissive_boss_material(Color(0.46, 0.82, 0.68), 0.86)
	boss_visual_root.add_child(oath_mark)
	boss_phase_sigil = oath_mark

	for side in [-1.0, 1.0]:
		var ring := MeshInstance3D.new()
		ring.name = "WhiteHartMemoryRingLeft" if side < 0.0 else "WhiteHartMemoryRingRight"
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.30
		ring_mesh.outer_radius = 0.36
		ring_mesh.rings = 10
		ring_mesh.ring_segments = 16
		ring.mesh = ring_mesh
		ring.position = Vector3(side * 0.62, 0.96, -0.12)
		ring.rotation_degrees = Vector3(16.0, 0, side * 28.0)
		ring.material_override = _emissive_boss_material(Color(0.32, 0.56, 0.70), 0.42)
		boss_visual_root.add_child(ring)

func _emissive_boss_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _mat(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _mapped_enemy_scale() -> Vector3:
	if enemy_id == "bog_wretch":
		return Vector3(1.25, 1.25, 1.25)
	if enemy_id == "white_hart_avatar":
		# white_hart_boss is normalized to its 3.60 m focal role. Do not shrink
		# the Wolf source back to a small avatar at the spectacle distance.
		return Vector3.ONE
	if enemy_id == "bell_eater":
		# bell_eater_boss is normalized to its full 3.80 m focal-creature
		# contract; do not apply a second multiplicative scale here.
		return Vector3.ONE
	if enemy_id == "rootbound_colossus":
		# rootbound_colossus_boss is normalized to its full 4.40 m role.
		return Vector3.ONE
	if enemy_id == "ashwing":
		# ashwing_boss is normalized to its full 4.80 m flying-creature role.
		return Vector3.ONE
	if enemy_id == "halvern_boss":
		return Vector3(1.04, 1.04, 1.04)
	if enemy_id == "ghoulkin":
		return Vector3.ONE * 0.95
	if enemy_id == "wychwood_stalker":
		return Vector3(0.92, 0.96, 0.92)
	if enemy_id == "wychwood_raider":
		return Vector3.ONE
	if enemy_id == "wychwood_brute":
		return Vector3(1.08, 1.04, 1.08)
	if enemy_id == "bandit":
		return Vector3(0.95, 0.95, 0.95)
	return Vector3.ONE

func _enemy_shadow_scale() -> Vector3:
	if enemy_id == "bog_wretch":
		return Vector3(1.05, 0.014, 0.72)
	if enemy_id == "white_hart_avatar":
		return Vector3(1.25, 0.014, 0.85)
	if enemy_id == "rootbound_colossus":
		return Vector3(1.42, 0.014, 0.98)
	if enemy_id in ["bell_eater", "ashwing"]:
		return Vector3(1.18, 0.014, 0.88)
	if enemy_id == "halvern_boss":
		return Vector3(0.90, 0.014, 0.62)
	if _is_wychwood_pack():
		return Vector3(0.88, 0.014, 0.62)
	return Vector3(0.82, 0.014, 0.58)

func _is_wychwood_pack() -> bool:
	return enemy_id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute"]

func _find_first_mesh(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for child in root.get_children():
		var found = _find_first_mesh(child)
		if found != null:
			return found
	return null

func _apply_material(root: Node, material: Material) -> void:
	if root is MeshInstance3D:
		root.material_override = material
	for child in root.get_children():
		_apply_material(child, material)

func _apply_bad_material_fallback(root: Node, material: Material) -> void:
	if root is MeshInstance3D:
		var mesh_instance = root as MeshInstance3D
		if _mesh_needs_visible_material(mesh_instance):
			mesh_instance.material_override = material
	for child in root.get_children():
		_apply_bad_material_fallback(child, material)

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

func _add_part(pos: Vector3, scale_value: Vector3, color: Color, shape_name: String, rot_degrees: Vector3 = Vector3.ZERO) -> void:
	var part = MeshInstance3D.new()
	if shape_name == "sphere":
		part.mesh = SphereMesh.new()
	elif shape_name == "capsule":
		part.mesh = CapsuleMesh.new()
	elif shape_name == "cylinder":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.5
		cylinder.bottom_radius = 0.62
		cylinder.height = 1.0
		cylinder.radial_segments = 10
		part.mesh = cylinder
	elif shape_name == "cone":
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.5
		cone.height = 1.0
		cone.radial_segments = 6
		part.mesh = cone
	else:
		var mesh = BoxMesh.new()
		mesh.size = Vector3.ONE
		part.mesh = mesh
	part.position = pos
	part.rotation_degrees = rot_degrees
	part.scale = scale_value
	part.material_override = _mat(color)
	# Boss identity pieces belong to the phase-animated identity layer. Keeping
	# them beside that layer made shoulders and chains lag behind the bell/eyes
	# during phase pulses and made the encounter read as detached geometry.
	var parent: Node3D = boss_visual_root if boss_visual_root != null else visual_root
	if parent != null:
		parent.add_child(part)
	else:
		add_child(part)

func _animate_visuals(delta: float) -> void:
	if body_visual == null:
		return
	var moving_speed = Vector2(velocity.x, velocity.z).length()
	var movement_weight = clamp(moving_speed / max(move_speed, 0.1), 0.0, 1.0)
	if animation_driver != null and animation_driver.is_valid():
		_update_feedback_material()
		_animate_boss_identity(delta)
		if windup_marker != null:
			windup_marker.visible = windup_time > 0.0
		return
	var bob = (0.018 + 0.022 * movement_weight) * sin(anim_phase)
	body_visual.position.y = lerp(body_visual.position.y, 0.62 + bob - 0.04 * movement_weight, 10.0 * delta)
	var target_scale = base_body_scale
	var root_target_x = 0.0
	var root_target_z = 0.0
	var root_target_y = 0.0
	if windup_time > 0.0:
		var windup_ratio = clamp(pending_attack_time / max(_windup_duration(), 0.01), 0.0, 1.0)
		var charge = 1.0 - windup_ratio
		target_scale = Vector3(base_body_scale.x * (1.22 + charge * 0.12), base_body_scale.y * (0.70 - charge * 0.08), base_body_scale.z * (1.42 + charge * 0.16))
		root_target_x = -30.0 + 20.0 * charge
		root_target_y = 12.0 * sin(anim_phase * 1.4)
		root_target_z = 18.0 * sin(anim_phase * 1.8) + 12.0 * charge
	elif stagger_time > 0.0:
		target_scale = Vector3(base_body_scale.x * 0.78, base_body_scale.y * 1.18, base_body_scale.z * 0.82)
		root_target_x = 24.0
		root_target_y = -14.0
		root_target_z = -24.0
	elif attack_recovery_time > 0.0:
		target_scale = Vector3(base_body_scale.x * 1.08, base_body_scale.y * 0.82, base_body_scale.z * 1.26)
		root_target_x = 18.0
		root_target_z = 12.0
	else:
		root_target_x = -3.5 * movement_weight + 2.0 * sin(anim_phase * 0.7) * (1.0 - movement_weight)
		root_target_z = 4.0 * sin(anim_phase) * movement_weight
	body_visual.scale = body_visual.scale.lerp(target_scale, 9.0 * delta)
	if visual_root != null:
		visual_root.rotation_degrees.x = lerp(visual_root.rotation_degrees.x, root_target_x, 8.5 * delta)
		visual_root.rotation_degrees.y = lerp(visual_root.rotation_degrees.y, root_target_y, 7.5 * delta)
		visual_root.rotation_degrees.z = lerp(visual_root.rotation_degrees.z, root_target_z, 8.5 * delta)
	var mat = body_visual.material_override as StandardMaterial3D
	if mat != null:
		if windup_time > 0.0:
			mat.albedo_color = base_color.lerp(Color(0.95, 0.22, 0.10), 0.42 + 0.18 * sin(anim_phase * 8.0))
		elif stagger_time > 0.0:
			mat.albedo_color = base_color.lerp(Color(0.78, 0.78, 0.62), 0.55)
		elif hit_flash_time > 0.0:
			mat.albedo_color = Color(0.95, 0.82, 0.58)
		elif slowed_time > 0.0:
			mat.albedo_color = base_color.lerp(Color(0.45, 0.62, 0.80), 0.45)
		else:
			mat.albedo_color = base_color
	if windup_marker != null:
		windup_marker.visible = windup_time > 0.0
		var pulse = 0.92 + 0.16 * sin(anim_phase * 12.0)
		windup_marker.scale = windup_marker.scale.lerp(Vector3(0.85 * pulse, 0.012, 0.85 * pulse), 12.0 * delta)
	_animate_boss_identity(delta)

func _animate_boss_identity(delta: float) -> void:
	if not is_boss or boss_visual_root == null:
		return
	boss_visual_time += delta
	var pulse := 1.0 + sin(boss_visual_time * 3.4) * 0.035
	if enemy_id == "bell_eater":
		boss_visual_root.rotation.y = sin(boss_visual_time * 1.15) * 0.045
		boss_visual_root.scale = boss_visual_root.scale.lerp(boss_identity_base_scale * pulse, minf(delta * 5.0, 1.0))
		if windup_time > 0.0:
			boss_visual_root.rotation.z = sin(boss_visual_time * 11.0) * 0.035
		else:
			boss_visual_root.rotation.z = lerpf(boss_visual_root.rotation.z, 0.0, minf(delta * 6.0, 1.0))
	elif enemy_id == "rootbound_colossus":
		boss_visual_root.rotation.y = sin(boss_visual_time * 0.72) * 0.035
		boss_visual_root.scale = boss_visual_root.scale.lerp(boss_identity_base_scale * (1.0 + sin(boss_visual_time * 2.2) * 0.025), minf(delta * 5.0, 1.0))
	elif enemy_id == "ashwing":
		boss_visual_root.rotation.z = sin(boss_visual_time * 2.2) * 0.06
	elif enemy_id == "halvern_boss":
		boss_visual_root.rotation.y = sin(boss_visual_time * 0.8) * 0.025
		boss_visual_root.scale = boss_visual_root.scale.lerp(Vector3.ONE * (1.0 + sin(boss_visual_time * 2.0) * 0.012), minf(delta * 5.0, 1.0))
	elif enemy_id == "white_hart_avatar":
		boss_visual_root.rotation.y = sin(boss_visual_time * 0.92) * 0.035
		boss_visual_root.scale = boss_visual_root.scale.lerp(Vector3.ONE * (1.0 + sin(boss_visual_time * 2.6) * 0.022), minf(delta * 5.0, 1.0))

func apply_boss_phase_visual(next_phase: int) -> void:
	if not is_boss:
		return
	set_meta("boss_phase", next_phase)
	if boss_phase_sigil == null:
		return
	var material := boss_phase_sigil.material_override as StandardMaterial3D
	if material == null:
		return
	var color := {
		1: Color(0.62, 0.28, 0.14),
		2: Color(0.92, 0.46, 0.16),
		3: Color(1.0, 0.78, 0.22),
	}.get(next_phase, Color(0.82, 0.24, 0.14)) as Color
	if enemy_id == "rootbound_colossus":
		color = {
			1: Color(0.30, 0.72, 0.26),
			2: Color(0.62, 0.86, 0.26),
			3: Color(0.88, 0.98, 0.54),
		}.get(next_phase, Color(0.50, 0.88, 0.32)) as Color
	if enemy_id == "white_hart_avatar":
		color = {
			1: Color(0.38, 0.78, 0.62),
			2: Color(0.42, 0.72, 0.92),
			3: Color(0.82, 0.92, 0.66),
		}.get(next_phase, Color(0.52, 0.84, 0.72)) as Color
	material.albedo_color = color
	material.emission = color
	material.emission_energy_multiplier = 0.72 + float(next_phase) * 0.28
	boss_phase_sigil.scale = Vector3.ONE * (0.10 + float(next_phase) * 0.025)

func _update_feedback_material() -> void:
	var mat = body_visual.material_override as StandardMaterial3D
	if mat == null:
		return
	if windup_time > 0.0:
		mat.albedo_color = base_color.lerp(Color(0.95, 0.22, 0.10), 0.48)
	elif stagger_time > 0.0 or hit_flash_time > 0.0:
		mat.albedo_color = Color(0.95, 0.82, 0.58)
	else:
		mat.albedo_color = base_color

func _show_windup_marker() -> void:
	if windup_marker == null:
		windup_marker = CombatFeedback.warning_marker(self, self)
	if windup_marker != null:
		windup_marker.visible = true

func _hide_windup_marker() -> void:
	if windup_marker != null:
		windup_marker.visible = false

func _mat(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
