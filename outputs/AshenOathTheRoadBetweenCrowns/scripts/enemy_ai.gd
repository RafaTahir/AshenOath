extends CharacterBody3D

signal died(enemy: Node)
signal damaged(enemy: Node, current: float, maximum: float)
signal windup_started(enemy: Node)
signal attack_resolved(enemy: Node, parried: bool, contact_position: Vector3)
signal boss_phase_changed(enemy: Node, phase: int)

const HealthComponent = preload("res://scripts/health_component.gd")
const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterPresentation = preload("res://scripts/character_presentation.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const CharacterAnimationDriver = preload("res://scripts/character_animation_driver.gd")

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
var base_move_speed := 2.0
var base_damage := 10.0

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
	if early_distance > sense_range + 5.0 and pending_attack_time <= 0.0 and stagger_time <= 0.0 and is_on_floor():
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
		var proposed: Vector3 = global_position + dir * move_speed * speed_factor * delta
		if spatial_service != null and not spatial_service.validate_segment(global_position, proposed, 0.50):
			dir = _navigation_direction(engagement_target, true)
		velocity.x = dir.x * move_speed * speed_factor
		velocity.z = dir.z * move_speed * speed_factor
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if can_see_player and attack_cooldown <= 0.0 and player.has_method("take_damage") and _attack_lane_clear() and _claim_attack_token():
			attack_cooldown = _attack_cooldown()
			windup_time = _windup_duration()
			pending_attack_time = windup_time
			if animation_driver != null:
				animation_driver.trigger_action("attack")
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
	var target_changed := navigation_target == Vector3.INF or navigation_target.distance_squared_to(target) > 0.75
	if force_refresh or target_changed or navigation_refresh_time <= 0.0 or navigation_route.is_empty():
		navigation_route = spatial_service.build_route(global_position, target, 0.62)
		navigation_route_index = 1 if navigation_route.size() > 1 else 0
		navigation_target = target
		navigation_refresh_time = 0.22
		if not navigation_route.is_empty():
			navigation_agent.target_position = navigation_route[navigation_route_index]
	if navigation_route.is_empty():
		return Vector3.ZERO
	var route_target := navigation_route[navigation_route_index]
	if global_position.distance_to(route_target) < 0.38 and navigation_route_index + 1 < navigation_route.size():
		navigation_route_index += 1
		route_target = navigation_route[navigation_route_index]
		navigation_agent.target_position = route_target
	var next_position := navigation_agent.get_next_path_position()
	var direction := next_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.002:
		direction = route_target - global_position
		direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.002 else Vector3.ZERO

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
	if player_contact.distance_to(last_attack_contact) > contact_radius or not _has_attack_line():
		return
	var parried = player.take_damage(damage)
	attack_recovery_time = 0.22 if enemy_id == "ghoulkin" else 0.16
	var contact_position := last_attack_contact
	attack_resolved.emit(self, parried, contact_position)
	if parried:
		parry_exposed_time = 1.15
		stagger(1.15)

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
	if enemy_id == "white_hart_avatar":
		return 0.44
	if enemy_id == "wychwood_brute":
		return 0.72
	if enemy_id == "ghoulkin" or enemy_id == "wychwood_stalker" or enemy_id == "wychwood_raider":
		return 0.46
	return 0.34

func _attack_cooldown() -> float:
	if enemy_id == "white_hart_avatar":
		return [1.55, 1.32, 1.16][boss_phase - 1]
	if enemy_id == "wychwood_brute":
		return 1.65
	if enemy_id == "ghoulkin" or enemy_id == "wychwood_stalker" or enemy_id == "wychwood_raider":
		return 1.32
	return 1.16

func _on_health_changed(current: float, maximum: float) -> void:
	damaged.emit(self, current, maximum)
	if enemy_id != "white_hart_avatar" or maximum <= 0.0:
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
	shape.height = 2.0 if enemy_id == "white_hart_avatar" else (1.65 if _is_wychwood_pack() else 1.15)
	shape.radius = 0.58 if enemy_id == "white_hart_avatar" else (0.32 if _is_wychwood_pack() else 0.35)
	collision.shape = shape
	collision.position.y = 1.05 if enemy_id == "white_hart_avatar" else (0.9 if _is_wychwood_pack() else 0.65)
	add_child(collision)
	visual_root = Node3D.new()
	visual_root.name = "visual_root"
	add_child(visual_root)
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

func _try_build_mapped_body() -> bool:
	asset_helper = AssetSpawnHelper.new()
	add_child(asset_helper)
	var mapped = null
	var uses_real_body := false
	var visual_source: String = enemy_id
	if enemy_id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute"]:
		visual_source = {
			"ghoulkin": "ghoul_gaunt_real",
			"wychwood_stalker": "ghoul_stalker_real",
			"wychwood_raider": "ghoul_gaunt_real",
			"wychwood_brute": "ghoul_brute_real",
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
	visual_root.add_child(mapped)
	_ground_mapped_visual(mapped)
	if visual_source == "ghoulkin_skeleton":
		# This source rig's terminal leg bones sit above its mesh bind bounds.
		mapped.position.y -= 0.50
	body_visual = _find_first_mesh(mapped)
	base_body_scale = mapped.scale
	animation_driver = CharacterAnimationDriver.new()
	animation_driver.name = "CharacterAnimationDriver"
	mapped.add_child(animation_driver)
	if uses_real_body:
		animation_driver.configure(mapped, {
			"idle":"Idle", "walk":"Walk", "run":"Run", "attack":"Attack",
			"hit":"Hit", "death":"Death"
		})
	elif visual_source == "ghoulkin_skeleton":
		animation_driver.configure(mapped, {
			"idle": "SkeletonArmature|Skeleton_Idle",
			"walk": "SkeletonArmature|Skeleton_Running",
			"run": "SkeletonArmature|Skeleton_Running",
			"attack": "SkeletonArmature|Skeleton_Attack",
			"hit": "SkeletonArmature|Skeleton_Spawn",
			"death": "SkeletonArmature|Skeleton_Death"
		})
	else:
		animation_driver.configure(mapped, {
			"idle": "Idle", "walk": "Walk", "run": "Run", "jump": "Jump_Idle",
			"attack": "Punch", "hit": "HitReact", "death": "Death"
		})
	_configure_attack_contact_bone()
	return true

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
		if mesh_instance.mesh != null and mesh_instance.skin != null:
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

func _mapped_enemy_scale() -> Vector3:
	if enemy_id == "bog_wretch":
		return Vector3(1.25, 1.25, 1.25)
	if enemy_id == "white_hart_avatar":
		return Vector3(0.65, 0.65, 0.65)
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
	if _is_wychwood_pack():
		return Vector3(0.88, 0.014, 0.62)
	return Vector3(0.82, 0.014, 0.58)

func _is_wychwood_pack() -> bool:
	return enemy_id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute"]

func _add_variant_silhouette() -> void:
	if enemy_id == "wychwood_stalker":
		_add_part(Vector3(0, 1.58, -0.12), Vector3(0.22, 0.30, 0.18), Color(0.12, 0.30, 0.16), "sphere")
	elif enemy_id == "wychwood_raider":
		_add_part(Vector3(-0.46, 1.30, 0), Vector3(0.20, 0.16, 0.30), Color(0.34, 0.40, 0.24), "box")
		_add_part(Vector3(0.46, 1.30, 0), Vector3(0.20, 0.16, 0.30), Color(0.34, 0.40, 0.24), "box")
	elif enemy_id == "wychwood_brute":
		_add_part(Vector3(0, 1.32, 0.08), Vector3(0.82, 0.28, 0.32), Color(0.25, 0.29, 0.20), "box")

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

func _add_part(pos: Vector3, scale_value: Vector3, color: Color, shape_name: String) -> void:
	var part = MeshInstance3D.new()
	if shape_name == "sphere":
		part.mesh = SphereMesh.new()
	else:
		var mesh = BoxMesh.new()
		mesh.size = Vector3.ONE
		part.mesh = mesh
	part.position = pos
	part.scale = scale_value
	part.material_override = _mat(color)
	if visual_root != null:
		visual_root.add_child(part)
	else:
		add_child(part)

func _animate_visuals(delta: float) -> void:
	if body_visual == null:
		return
	var moving_speed = Vector2(velocity.x, velocity.z).length()
	var movement_weight = clamp(moving_speed / max(move_speed, 0.1), 0.0, 1.0)
	if animation_driver != null and animation_driver.is_valid():
		_update_feedback_material()
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
