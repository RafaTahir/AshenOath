extends CharacterBody3D

signal died(enemy: Node)
signal damaged(enemy: Node, current: float, maximum: float)
signal windup_started(enemy: Node)
signal attack_resolved(enemy: Node, parried: bool)

const HealthComponent = preload("res://scripts/health_component.gd")
const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterPresentation = preload("res://scripts/character_presentation.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")

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

func setup(id: String, definition: Dictionary, target: Node3D) -> void:
	enemy_id = id
	display_name = definition.get("name", id)
	damage = float(definition.get("damage", 10.0))
	move_speed = float(definition.get("speed", 2.0))
	attack_range = float(definition.get("attack_range", 1.5))
	sense_range = float(definition.get("sense_range", 10.0))
	tag = definition.get("tag", "beast")
	weakness = definition.get("weakness", "")
	player = target
	home_position = global_position
	health_component = HealthComponent.new()
	add_child(health_component)
	health_component.configure(float(definition.get("health", 60.0)))
	health_component.changed.connect(func(current: float, maximum: float): damaged.emit(self, current, maximum))
	health_component.died.connect(_on_died)
	base_color = Color(definition.get("color", "#665544"))
	_build_body(base_color)

func _physics_process(delta: float) -> void:
	if dead or player == null:
		return
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	attack_recovery_time = max(attack_recovery_time - delta, 0.0)
	slowed_time = max(slowed_time - delta, 0.0)
	windup_time = max(windup_time - delta, 0.0)
	hit_flash_time = max(hit_flash_time - delta, 0.0)
	stagger_time = max(stagger_time - delta, 0.0)
	anim_phase += delta * (3.45 if velocity.length() > 0.15 else 0.95)
	var to_player: Vector3 = player.global_position - global_position
	var distance: float = to_player.length()
	var home_distance: float = global_position.distance_to(home_position)
	if pending_attack_time > 0.0:
		pending_attack_time -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if pending_attack_time <= 0.0:
			_resolve_attack()
	elif stagger_time > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	elif home_distance > leash_radius:
		var to_home: Vector3 = home_position - global_position
		if to_home.length() > 0.35:
			var home_dir: Vector3 = to_home.normalized()
			velocity.x = home_dir.x * move_speed
			velocity.z = home_dir.z * move_speed
			look_at(Vector3(home_position.x, global_position.y, home_position.z), Vector3.UP)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	elif distance > sense_range:
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
	elif attack_recovery_time > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
	elif distance > attack_range:
		var speed_factor = 0.45 if slowed_time > 0.0 else 1.0
		var dir = to_player.normalized()
		velocity.x = dir.x * move_speed * speed_factor
		velocity.z = dir.z * move_speed * speed_factor
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if attack_cooldown <= 0.0 and player.has_method("take_damage"):
			attack_cooldown = _attack_cooldown()
			windup_time = _windup_duration()
			pending_attack_time = windup_time
			_show_windup_marker()
			windup_started.emit(self)
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.1
	move_and_slide()
	_animate_visuals(delta)

func apply_damage(amount: float, source_tag: String = "") -> void:
	if dead:
		return
	var final_damage = amount
	if source_tag == weakness or source_tag == tag:
		final_damage += 15.0
	health_component.damage(final_damage)
	hit_flash_time = 0.12
	stagger_time = max(stagger_time, 0.16)

func slow(seconds: float) -> void:
	slowed_time = max(slowed_time, seconds)

func stagger(seconds: float = 0.7) -> void:
	stagger_time = max(stagger_time, seconds)
	windup_time = 0.0
	pending_attack_time = 0.0

func _resolve_attack() -> void:
	if dead or player == null or not player.has_method("take_damage"):
		return
	if player.global_position.distance_to(global_position) > attack_range + 0.75:
		return
	var parried = player.take_damage(damage)
	attack_recovery_time = 0.22 if enemy_id == "ghoulkin" else 0.16
	attack_resolved.emit(self, parried)
	if parried:
		stagger(1.15)

func _on_died() -> void:
	dead = true
	death_pose_time = 1.0
	_hide_windup_marker()
	collision_layer = 0
	collision_mask = 0
	if visual_root != null:
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

func _windup_duration() -> float:
	if enemy_id == "white_hart_avatar":
		return 0.44
	if enemy_id == "ghoulkin":
		return 0.46
	return 0.34

func _attack_cooldown() -> float:
	if enemy_id == "white_hart_avatar":
		return 1.55
	if enemy_id == "ghoulkin":
		return 1.32
	return 1.16

func _build_body(color: Color) -> void:
	add_to_group("enemies")
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.height = 1.15
	shape.radius = 0.35
	collision.shape = shape
	collision.position.y = 0.65
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
	var mapped = asset_helper.spawn_enemy(enemy_id)
	if mapped == null or mapped.name.ends_with("_placeholder"):
		if mapped != null:
			mapped.queue_free()
		return false
	mapped.name = "%s_visual" % enemy_id
	mapped.scale = _mapped_enemy_scale()
	if enemy_id == "white_hart_avatar":
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.86, 0.83, 0.70)
		material.emission_enabled = true
		material.emission = Color(0.78, 0.86, 0.92)
		material.emission_energy_multiplier = 0.25
		_apply_material(mapped, material)
	elif enemy_id == "ghoulkin":
		_apply_bad_material_fallback(mapped, _mat(Color(0.14, 0.20, 0.13)))
	visual_root.add_child(mapped)
	body_visual = _find_first_mesh(mapped)
	base_body_scale = mapped.scale
	return true

func _mapped_enemy_scale() -> Vector3:
	if enemy_id == "bog_wretch":
		return Vector3(1.25, 1.25, 1.25)
	if enemy_id == "white_hart_avatar":
		return Vector3(1.35, 1.35, 1.35)
	if enemy_id == "ghoulkin":
		return Vector3(0.78, 0.78, 0.78)
	if enemy_id == "bandit":
		return Vector3(0.95, 0.95, 0.95)
	return Vector3.ONE

func _enemy_shadow_scale() -> Vector3:
	if enemy_id == "bog_wretch":
		return Vector3(1.05, 0.014, 0.72)
	if enemy_id == "white_hart_avatar":
		return Vector3(1.25, 0.014, 0.85)
	if enemy_id == "ghoulkin":
		return Vector3(0.78, 0.014, 0.56)
	return Vector3(0.82, 0.014, 0.58)

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
