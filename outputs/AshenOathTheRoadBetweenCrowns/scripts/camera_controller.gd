extends Node3D

var target: Node3D
var input_source: Node
var yaw = 0.0
var pitch = -0.19
var sensitivity = 0.003
var distance = 6.8
const MIN_ZOOM_DISTANCE := 3.2
const MAX_ZOOM_DISTANCE := 9.2
const ZOOM_STEP := 0.65
var height = 2.1
var camera: Camera3D
var shake_amount = 0.0
var shake_decay = 6.0
var keyboard_turn_speed = 2.2
var invert_y = false
var gamepad_look_sensitivity := 1.0
var current_zone_id = "greyfen"

var _initialized = false
var _smoothed_anchor = Vector3.ZERO
var _smoothed_look = Vector3.ZERO
var _previous_dodge_time = 0.0
var _dodge_response = 0.0
var _landing_response = 0.0
var _previous_on_floor = true
var _fov_kick = 0.0
var _idle_time = 0.0
var _combat_focus_refresh := 0.0
var _cached_combat_focus: Node3D
var _collision_refresh := 0.0
var _cached_collision_position := Vector3.ZERO

func setup(follow_target: Node3D, source: Node = null) -> void:
	target = follow_target
	input_source = source
	camera = Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.current = true
	camera.fov = 63.0
	add_child(camera)
	_initialized = false
	_capture_pointer()

func set_zone(zone_id: String) -> void:
	current_zone_id = zone_id
	_initialized = false

func _input(event: InputEvent) -> void:
	if target == null or get_tree().paused:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			adjust_zoom(-ZOOM_STEP)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			adjust_zoom(ZOOM_STEP)
			get_viewport().set_input_as_handled()
			return
		_capture_pointer()
	elif event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_capture_pointer()
		_apply_mouse_motion(event.relative)

func _apply_mouse_motion(relative: Vector2) -> void:
	if relative.length_squared() <= 0.0:
		return
	yaw -= relative.x * sensitivity
	var y_direction = 1.0 if invert_y else -1.0
	pitch = clamp(pitch + relative.y * sensitivity * y_direction, -0.75, 0.45)

func _process(delta: float) -> void:
	if target == null or get_tree().paused:
		return
	_apply_keyboard_camera(delta)
	_update_response_state(delta)
	var velocity = _target_velocity()
	var flat_speed = Vector2(velocity.x, velocity.z).length()
	var sprinting := _action_pressed("run") and flat_speed > 3.5
	_combat_focus_refresh -= delta
	if _combat_focus_refresh <= 0.0 or not is_instance_valid(_cached_combat_focus):
		_combat_focus_refresh = 0.10
		_cached_combat_focus = _nearest_combat_focus()
	var combat_focus = _cached_combat_focus
	var target_distance = maxf(MIN_ZOOM_DISTANCE, distance - 0.75) if combat_focus != null else distance
	var target_height = 2.25 if combat_focus != null else height
	var shoulder = -0.55 if combat_focus != null else -0.82
	var look_ahead = 2.35 if combat_focus != null else 3.45
	var target_fov = 65.0 if combat_focus != null else 63.0
	if current_zone_id == "wychwood":
		if target.global_position.z > 4.5:
			target_distance = minf(target_distance, 6.4)
		elif combat_focus != null:
			target_distance = minf(target_distance, 5.4)
			shoulder = -0.48
	if sprinting:
		target_fov = max(target_fov, 66.5)
	var target_pos = target.global_position + Vector3(0, target_height, 0)
	var orbit = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var desired = target_pos + orbit * Vector3(shoulder + _dodge_response * 0.12, _landing_response * 0.08, target_distance)
	_collision_refresh -= delta
	if _collision_refresh <= 0.0:
		_collision_refresh = 1.0 / 30.0
		_cached_collision_position = _collide_camera(target_pos, desired)
	desired = _cached_collision_position
	var natural_look = target_pos + Basis(Vector3.UP, yaw) * Vector3(0.55, -0.08, -look_ahead)
	var focus = _environment_focus(combat_focus)
	if focus.weight > 0.0:
		natural_look = natural_look.lerp(focus.point, focus.weight)
	var shake = Vector3.ZERO
	if shake_amount > 0.001:
		shake = Vector3(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount), 0.0)
		shake_amount = max(shake_amount - shake_decay * delta, 0.0)
	if not _initialized:
		_smoothed_anchor = target_pos
		_smoothed_look = natural_look
		global_position = target_pos
		camera.global_position = desired
		_initialized = true
	_smoothed_anchor = _smoothed_anchor.lerp(target_pos, _smooth_weight(delta, 8.0))
	_smoothed_look = _smoothed_look.lerp(natural_look, _smooth_weight(delta, 6.6))
	global_position = global_position.lerp(_smoothed_anchor, _smooth_weight(delta, 10.0))
	camera.global_position = camera.global_position.lerp(desired + shake, _smooth_weight(delta, 9.2))
	_idle_time += delta
	var idle_breath = Vector3.ZERO
	if flat_speed < 0.25 and combat_focus == null:
		idle_breath.y = sin(_idle_time * 1.35) * 0.018
	camera.look_at(_smoothed_look + idle_breath, Vector3.UP)
	camera.fov = lerp(camera.fov, target_fov + _fov_kick, _smooth_weight(delta, 5.0))
	_fov_kick = max(_fov_kick - delta * 5.0, 0.0)

func frame_dialogue_target(dialogue_target: Node3D) -> void:
	if target == null or camera == null or dialogue_target == null or not is_instance_valid(dialogue_target):
		return
	var flat_to_target := dialogue_target.global_position - target.global_position
	flat_to_target.y = 0.0
	if flat_to_target.length_squared() < 0.04:
		return
	flat_to_target = flat_to_target.normalized()
	# Place the camera behind Kael relative to the speaker, then aim at the
	# shared chest/face line so the dialogue panel does not hide both actors.
	yaw = atan2(-flat_to_target.x, -flat_to_target.z)
	pitch = -0.12
	var midpoint := (target.global_position + dialogue_target.global_position) * 0.5
	midpoint.y += 1.05
	var anchor := midpoint + Vector3(0.0, 1.35, 0.0)
	var orbit := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var desired := anchor + orbit * Vector3(-0.30, 0.0, 3.15)
	desired = _collide_camera(anchor, desired)
	_smoothed_anchor = anchor
	_smoothed_look = midpoint
	_cached_collision_position = desired
	global_position = anchor
	camera.global_position = desired
	camera.look_at(midpoint, Vector3.UP)
	camera.fov = 58.0
	_initialized = true

func _collide_camera(from_pos: Vector3, desired: Vector3) -> Vector3:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from_pos, desired)
	query.exclude = [target]
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return desired
	var hit_pos: Vector3 = hit.get("position", desired)
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	# The follow camera must not treat the walkable ground, road, bridge deck,
	# or other upward-facing terrain as an occluder. On the bounded campaign
	# sections the orbit ray can end slightly below the support plane; clamping
	# to that hit puts the camera inside the road and fills the frame with blur.
	# Vertical walls and props still shorten the orbit normally.
	if normal.y > 0.65:
		return desired
	return hit_pos + normal * 0.25

func shake(amount: float) -> void:
	shake_amount = max(shake_amount, amount)
	_fov_kick = max(_fov_kick, amount * 4.8)

func get_flat_forward() -> Vector3:
	return -Basis(Vector3.UP, yaw).z.normalized()

func get_flat_right() -> Vector3:
	return Basis(Vector3.UP, yaw).x.normalized()

func _apply_keyboard_camera(delta: float) -> void:
	var look := _look_input()
	var turn := look.x
	var tilt := look.y
	if abs(turn) > 0.01:
		yaw -= turn * keyboard_turn_speed * delta
	if abs(tilt) > 0.01:
		var y_direction = -1.0 if invert_y else 1.0
		pitch = clamp(pitch - tilt * keyboard_turn_speed * 0.55 * delta * y_direction, -0.75, 0.45)
	var zoom_axis: float = input_source.action_axis("camera_zoom_in", "camera_zoom_out") \
		if input_source != null and input_source.has_method("action_axis") \
		else Input.get_axis("camera_zoom_in", "camera_zoom_out")
	if absf(zoom_axis) > 0.01:
		adjust_zoom(zoom_axis * 3.4 * delta)

func adjust_zoom(amount: float) -> void:
	distance = clampf(distance + amount, MIN_ZOOM_DISTANCE, MAX_ZOOM_DISTANCE)

func get_zoom_distance() -> float:
	return distance

func _capture_pointer() -> void:
	if input_source != null and input_source.has_method("capture_pointer"):
		input_source.capture_pointer()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func apply_settings(mouse_sensitivity: float, use_invert_y: bool, controller_sensitivity: float = 1.0) -> void:
	sensitivity = mouse_sensitivity
	invert_y = use_invert_y
	gamepad_look_sensitivity = controller_sensitivity

func _look_input() -> Vector2:
	if input_source != null and input_source.has_method("look_vector"):
		return input_source.look_vector()
	return Vector2(
		Input.get_axis("camera_left", "camera_right"),
		Input.get_axis("camera_up", "camera_down")
	) * gamepad_look_sensitivity

func _action_pressed(action: StringName) -> bool:
	if input_source != null and input_source.has_method("is_action_pressed"):
		return input_source.is_action_pressed(action)
	return Input.is_action_pressed(action)

func _smooth_weight(delta: float, speed: float) -> float:
	return 1.0 - exp(-speed * delta)

func _target_velocity() -> Vector3:
	var raw_velocity = target.get("velocity")
	if typeof(raw_velocity) == TYPE_VECTOR3:
		return raw_velocity
	return Vector3.ZERO

func _update_response_state(delta: float) -> void:
	var dodge_time = 0.0
	var raw_dodge_time = target.get("dodge_time")
	if typeof(raw_dodge_time) == TYPE_FLOAT or typeof(raw_dodge_time) == TYPE_INT:
		dodge_time = float(raw_dodge_time)
	if dodge_time > 0.0 and _previous_dodge_time <= 0.0:
		_dodge_response = 1.0
		_fov_kick = max(_fov_kick, 0.9)
	_previous_dodge_time = dodge_time
	_dodge_response = max(_dodge_response - delta * 4.5, 0.0)
	var on_floor = true
	if target.has_method("is_on_floor"):
		on_floor = target.is_on_floor()
	if on_floor and not _previous_on_floor:
		_landing_response = 1.0
		_fov_kick = max(_fov_kick, 0.45)
	_previous_on_floor = on_floor
	_landing_response = max(_landing_response - delta * 6.0, 0.0)

func _nearest_combat_focus() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist = 10.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if not (node is Node3D):
			continue
		if bool(node.get("dead")):
			continue
		var dist = target.global_position.distance_to(node.global_position)
		if dist < nearest_dist:
			nearest = node
			nearest_dist = dist
	return nearest

func _environment_focus(combat_focus: Node3D) -> Dictionary:
	if combat_focus != null:
		return {
			"point": (target.global_position + combat_focus.global_position) * 0.5 + Vector3(0, 1.05, 0),
			"weight": 0.58,
		}
	var player_pos = target.global_position
	if current_zone_id == "greyfen":
		var shrine = Vector3(4.8, 1.2, -5.4)
		var shrine_distance = player_pos.distance_to(shrine)
		if shrine_distance < 8.0:
			return {"point": shrine, "weight": clamp(1.0 - shrine_distance / 8.0, 0.0, 1.0) * 0.32}
		if player_pos.z < -7.0:
			return {"point": Vector3(0.0, 1.45, -14.3), "weight": 0.24}
	elif current_zone_id == "wychwood":
		if player_pos.z > 2.0:
			return {"point": Vector3(0.0, 1.4, -5.5), "weight": 0.24}
		if player_pos.z <= 2.0:
			return {"point": Vector3(0.0, 1.25, -9.2), "weight": 0.28}
	return {"point": Vector3.ZERO, "weight": 0.0}
