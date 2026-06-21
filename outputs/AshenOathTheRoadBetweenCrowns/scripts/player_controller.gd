extends CharacterBody3D

signal attack_performed(damage: float, radius: float, heavy: bool)
signal potion_requested
signal bomb_requested
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

var walk_speed = 3.4
var run_speed = 5.3
var dodge_speed = 8.0
var gravity = 24.0
var attack_cooldown = 0.0
var dodge_time = 0.0
var dodge_dir = Vector3.ZERO
var can_control = true
var camera_controller
var health_component
var stamina_component
var visual_root: Node3D
var body_visual: MeshInstance3D
var weapon_root: Node3D
var sword_visual: MeshInstance3D
var sword_hilt_visual: MeshInstance3D
var sword_trail_visual: MeshInstance3D
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
var move_phase = 0.0
var step_phase = 0.0
var attack_anim_time = 0.0
var attack_anim_heavy = false
var hurt_flash_time = 0.0
var hurt_react_time = 0.0
var parry_window = 0.0
var block_pose_weight = 0.0
var grounded_weight = 0.0

func _ready() -> void:
	add_to_group("player")
	health_component = HealthComponent.new()
	stamina_component = StaminaComponent.new()
	add_child(health_component)
	add_child(stamina_component)
	health_component.configure(125.0)
	health_component.died.connect(_on_died)
	_build_body()

func _physics_process(delta: float) -> void:
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	attack_anim_time = max(attack_anim_time - delta, 0.0)
	hurt_flash_time = max(hurt_flash_time - delta, 0.0)
	hurt_react_time = max(hurt_react_time - delta, 0.0)
	parry_window = max(parry_window - delta, 0.0)
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
		velocity.x = dodge_dir.x * dodge_speed
		velocity.z = dodge_dir.z * dodge_speed
	else:
		var wants_run = Input.is_action_pressed("run") and input_vec.length() > 0.1
		var speed = run_speed if wants_run and stamina_component.spend(10.0 * delta) else walk_speed
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
		if move_dir.length() > 0.1:
			look_at(global_position + move_dir, Vector3.UP)
		if Input.is_action_just_pressed("dodge"):
			if stamina_component.spend(28.0):
				dodge_dir = move_dir if move_dir.length() > 0.1 else -global_transform.basis.z
				dodge_time = 0.22
			else:
				stamina_exhausted.emit("dodge")
	_apply_gravity(delta)
	move_and_slide()
	_animate_visuals(delta, move_dir, input_vec.length() > 0.1)

func _handle_combat_input() -> void:
	if attack_cooldown > 0.0:
		return
	if Input.is_action_just_pressed("light_attack"):
		attack_cooldown = 0.38
		attack_anim_time = 0.34
		attack_anim_heavy = false
		attack_performed.emit(24.0, 2.0, false)
	elif Input.is_action_just_pressed("heavy_attack"):
		if stamina_component.spend(22.0):
			attack_cooldown = 0.7
			attack_anim_time = 0.52
			attack_anim_heavy = true
			attack_performed.emit(42.0, 2.25, true)
		else:
			stamina_exhausted.emit("heavy attack")
	if Input.is_action_just_pressed("use_potion"):
		potion_requested.emit()
	if Input.is_action_just_pressed("throw_bomb"):
		bomb_requested.emit()
	if Input.is_action_just_pressed("block"):
		parry_window = 0.22

func is_blocking() -> bool:
	return Input.is_action_pressed("block") and stamina_component.stamina > 8.0

func take_damage(amount: float) -> bool:
	if dodge_time > 0.0:
		return false
	if parry_window > 0.0 and stamina_component.spend(10.0):
		parry_window = 0.0
		hurt_flash_time = 0.08
		hurt_react_time = 0.14
		parried.emit()
		return true
	if is_blocking() and stamina_component.spend(12.0):
		var reduced = amount * 0.25
		health_component.damage(reduced)
		hurt_flash_time = 0.10
		hurt_react_time = 0.13
		blocked.emit(reduced)
	else:
		health_component.damage(amount)
		hurt_flash_time = 0.18
		hurt_react_time = 0.20
		hurt.emit(amount)
	return false

func face_target(target_pos: Vector3) -> void:
	var flat = Vector3(target_pos.x, global_position.y, target_pos.z)
	if flat.distance_to(global_position) > 0.1:
		look_at(flat, Vector3.UP)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1

func _on_died() -> void:
	can_control = false
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
	mapped.scale = Vector3(0.95, 0.95, 0.95)
	mapped.rotation_degrees.y = 180
	visual_root.add_child(mapped)
	body_visual = _find_first_mesh(mapped)
	_apply_visible_material_fallbacks(mapped, _mat(Color(0.18, 0.20, 0.18)))
	_add_motion_proxy_parts()
	_add_mapped_weapon_visuals()
	return true

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
	var running = Input.is_action_pressed("run")
	if moving:
		move_phase += delta * (8.7 if running else 6.2)
		step_phase += delta * (3.05 if running else 2.15)
		if step_phase >= 1.0:
			step_phase = 0.0
			footstep.emit()
	else:
		move_phase += delta * 1.45
	var speed_factor = clamp(Vector2(velocity.x, velocity.z).length() / max(run_speed, 0.1), 0.0, 1.0)
	grounded_weight = lerp(grounded_weight, speed_factor, 8.0 * delta)
	block_pose_weight = lerp(block_pose_weight, 1.0 if is_blocking() else 0.0, 14.0 * delta)
	var dodge_weight = clamp(dodge_time / 0.22, 0.0, 1.0)
	var hurt_weight = clamp(hurt_react_time / 0.20, 0.0, 1.0)
	var combat_swing_weight = 0.0
	var combat_windup_weight = 0.0
	var bob = 0.030 * sin(move_phase) * grounded_weight if moving else 0.009 * sin(move_phase)
	var idle_breath = sin(move_phase * 0.72) * (1.0 - grounded_weight)
	visual_root.position.y = bob - 0.018 * grounded_weight - 0.030 * hurt_weight
	var lateral_lean = clamp(-velocity.x * 0.85, -4.0, 4.0)
	var forward_lean = -5.2 * grounded_weight if moving else 0.9 * idle_breath
	forward_lean += -7.0 * dodge_weight + 5.0 * hurt_weight - 3.5 * block_pose_weight
	var root_z = lateral_lean + 4.5 * sin(move_phase) * grounded_weight + 7.0 * dodge_weight * sign(dodge_dir.x) - 3.0 * block_pose_weight
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
	_animate_motion_proxies(delta, moving, speed_factor, dodge_weight, hurt_weight, block_pose_weight, combat_windup_weight, combat_swing_weight)
	if body_visual != null:
		var mat = body_visual.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(0.72, 0.22, 0.12) if hurt_flash_time > 0.0 else Color(0.24, 0.27, 0.25)

func _animate_motion_proxies(delta: float, moving: bool, speed_factor: float, dodge_weight: float, hurt_weight: float, block_weight: float, windup_weight: float, swing_weight: float) -> void:
	var gait = sin(move_phase)
	var stride = clamp(speed_factor * 1.25, 0.0, 1.0)
	var idle_weight = 1.0 - stride
	var idle_breath = sin(move_phase * 0.72)
	var arm_amount = 58.0 * stride
	var leg_amount = 54.0 * stride
	if left_arm_proxy != null:
		left_arm_proxy.rotation_degrees.x = lerp(left_arm_proxy.rotation_degrees.x, -gait * arm_amount - 12.0 * block_weight + 10.0 * hurt_weight + idle_breath * 4.0 * idle_weight, 12.0 * delta)
		left_arm_proxy.rotation_degrees.z = lerp(left_arm_proxy.rotation_degrees.z, -10.0 - 12.0 * block_weight - 14.0 * swing_weight, 12.0 * delta)
	if right_arm_proxy != null:
		right_arm_proxy.rotation_degrees.x = lerp(right_arm_proxy.rotation_degrees.x, gait * arm_amount * 0.60 - 34.0 * windup_weight - 54.0 * swing_weight - 20.0 * block_weight, 13.0 * delta)
		right_arm_proxy.rotation_degrees.z = lerp(right_arm_proxy.rotation_degrees.z, 12.0 + 38.0 * swing_weight + 12.0 * block_weight, 13.0 * delta)
	if left_leg_proxy != null:
		left_leg_proxy.rotation_degrees.x = lerp(left_leg_proxy.rotation_degrees.x, gait * leg_amount - 18.0 * dodge_weight, 13.0 * delta)
		left_leg_proxy.position.y = lerp(left_leg_proxy.position.y, 0.52 + max(0.0, -gait) * 0.08 * stride, 14.0 * delta)
	if right_leg_proxy != null:
		right_leg_proxy.rotation_degrees.x = lerp(right_leg_proxy.rotation_degrees.x, -gait * leg_amount - 18.0 * dodge_weight, 13.0 * delta)
		right_leg_proxy.position.y = lerp(right_leg_proxy.position.y, 0.52 + max(0.0, gait) * 0.08 * stride, 14.0 * delta)
	if cloak_motion_proxy != null:
		var cloak_sway = (7.0 * gait * stride) + 9.0 * dodge_weight
		cloak_motion_proxy.rotation_degrees.x = lerp(cloak_motion_proxy.rotation_degrees.x, -5.0 - 6.0 * stride + 11.0 * swing_weight + 2.0 * idle_breath * idle_weight, 9.0 * delta)
		cloak_motion_proxy.rotation_degrees.z = lerp(cloak_motion_proxy.rotation_degrees.z, cloak_sway, 9.0 * delta)

func _animate_slash_arc(strike: float, strike_arc: float, recovery: float, heavy: bool) -> void:
	if slash_arc_root == null:
		return
	var visible = strike > 0.02 and recovery < 0.92
	slash_arc_root.visible = visible
	if not visible:
		return
	var arc_size = 1.0 + strike_arc * (0.55 if heavy else 0.32)
	slash_arc_root.position = Vector3(0.50 + 0.18 * strike_arc, 1.16 + (0.12 if heavy else 0.05), -0.78 - 0.22 * strike_arc)
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
