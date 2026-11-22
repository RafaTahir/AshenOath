extends Node

var base_y = 0.0
var base_yaw = 0.0
var phase = 0.0
var role_id = ""
var focus_target: Node3D
var focus_radius = 5.2
var turn_speed = 4.0
var bob_amount = 0.018
var sway_amount = 2.8
var breathe_amount = 0.006
var attention_hold = 0.0
var planted_yaw_offset = 0.0
var animation_driver
var face_driver
var far_tick_accumulator := 0.0
var focus_refresh_remaining := 0.0
var desired_yaw := 0.0
var previous_position := Vector3.ZERO
var externally_moving := false
var ambient_suspended := false
var animation_update_hz := -1.0

const ATTENTION_ARC := 48.0
const ATTENTION_TURN_RATE := 1.1

func setup(id: String, target: Node3D = null) -> void:
	role_id = id
	focus_target = target
	if role_id == "sister_anwen":
		focus_radius = 8.0
		turn_speed = 3.2
		bob_amount = 0.004
		sway_amount = 0.28
		breathe_amount = 0.004
	elif role_id == "rook":
		focus_radius = 4.3
		turn_speed = 2.7
		bob_amount = 0.010
		sway_amount = 2.2
		breathe_amount = 0.006
	else:
		focus_radius = 4.8
		turn_speed = 2.1
		bob_amount = 0.010
		sway_amount = 1.8
		breathe_amount = 0.006

func _ready() -> void:
	var parent_3d: Node3D = get_parent() as Node3D
	if parent_3d == null:
		set_process(false)
		return
	base_y = parent_3d.position.y
	base_yaw = parent_3d.rotation_degrees.y
	desired_yaw = parent_3d.rotation.y
	previous_position = parent_3d.global_position
	phase = randf() * TAU
	planted_yaw_offset = randf_range(-7.0, 7.0)
	animation_driver = parent_3d.find_child("CharacterAnimationDriver", true, false)
	face_driver = parent_3d.find_child("CharacterFaceDriver", true, false)
	if animation_driver != null:
		animation_driver.set_locomotion(0.0, Vector3.ZERO, true)

func _process(delta: float) -> void:
	var parent_3d: Node3D = get_parent() as Node3D
	if parent_3d == null:
		return
	var displacement: Vector3 = parent_3d.global_position - previous_position
	previous_position = parent_3d.global_position
	var moved: bool = displacement.length_squared() > 0.000001
	# A route, escort or dialogue controller owns its actor's pose completely.
	# Observed translation also protects callers which predate the owner marker.
	if not str(parent_3d.get_meta("locomotion_owner", "")).is_empty() or moved:
		externally_moving = true
		base_yaw = parent_3d.rotation_degrees.y
		desired_yaw = parent_3d.rotation.y
		return
	if externally_moving:
		externally_moving = false
		base_yaw = parent_3d.rotation_degrees.y
		desired_yaw = parent_3d.rotation.y
	if bool(parent_3d.get_meta("dialogue_facing_lock", false)):
		_set_animation_suspended(false)
		_set_animation_update_rate(30.0)
		desired_yaw = parent_3d.rotation.y
		return
	# Keep target lookup and distance decisions sparse, while nearby attention
	# turns are continuous and bounded independently of render frame duration.
	far_tick_accumulator += delta
	if far_tick_accumulator >= 0.10:
		_update_attention(parent_3d, far_tick_accumulator)
		far_tick_accumulator = 0.0
	if ambient_suspended:
		return
	var turn_error: float = wrapf(desired_yaw - parent_3d.rotation.y, -PI, PI)
	var eased_step: float = turn_error * (1.0 - exp(-turn_speed * minf(delta, 0.05)))
	var turn_limit: float = ATTENTION_TURN_RATE * minf(delta, 0.05)
	parent_3d.rotation.y += clampf(eased_step, -turn_limit, turn_limit)
	# Breathing belongs to the skeletal idle clip. Never move the grounded actor
	# root or its collision/interaction anchor up and down for ambient breathing.

func _update_attention(parent_3d: Node3D, delta: float) -> void:
	# Presentation can arrive after the interaction anchor has entered the tree.
	if not is_instance_valid(animation_driver):
		animation_driver = parent_3d.find_child("CharacterAnimationDriver", true, false)
		animation_update_hz = -1.0
	if not is_instance_valid(face_driver):
		face_driver = parent_3d.find_child("CharacterFaceDriver", true, false)
	if animation_driver != null and animation_driver.has_method("set_dialogue_pose"):
		animation_driver.set_dialogue_pose(false)
	if not is_instance_valid(focus_target):
		focus_target = null
		focus_refresh_remaining -= delta
		if focus_refresh_remaining <= 0.0:
			focus_refresh_remaining = 0.75
			focus_target = get_tree().get_first_node_in_group("player") as Node3D
	# Distant actors retain their rendered body; only ambient animation sleeps.
	if focus_target != null and parent_3d.global_position.distance_to(focus_target.global_position) > _animation_distance():
		_set_animation_suspended(true)
		return
	else:
		_set_animation_suspended(false)
	var focus_distance: float = parent_3d.global_position.distance_to(focus_target.global_position) if focus_target != null else INF
	_set_animation_update_rate(30.0 if focus_distance <= focus_radius else 15.0)
	phase += delta * (0.48 if role_id == "sister_anwen" else 0.62)
	var home_yaw: float = deg_to_rad(base_yaw)
	var target_yaw: float = home_yaw + deg_to_rad(planted_yaw_offset)
	if focus_target != null:
		var to_target: Vector3 = focus_target.global_position - parent_3d.global_position
		to_target.y = 0.0
		if to_target.length() <= focus_radius and to_target.length() > 0.2:
			attention_hold = 2.25 if role_id == "sister_anwen" else 0.9
			# Most parents are -Z actor wrappers. Direct imported visuals retain
			# their +Z source convention and the factory's authored half-turn.
			var source_positive_z: bool = bool(parent_3d.get_meta("source_forward_positive_z", false))
			var player_yaw: float = atan2(to_target.x, to_target.z) if source_positive_z else atan2(-to_target.x, -to_target.z)
			var home_offset: float = wrapf(player_yaw - home_yaw, -PI, PI)
			# Someone walking behind a stationary worker must not swivel that
			# worker through a full half-turn. Dialogue has its own facing owner.
			# Small attention shifts belong to the eyes and head. Keep feet at
			# the work station; active dialogue owns deliberate whole-body turns.
			target_yaw = home_yaw + clampf(home_offset * 0.15, -deg_to_rad(8.0), deg_to_rad(8.0))
		elif attention_hold > 0.0:
			target_yaw = desired_yaw
	attention_hold = max(attention_hold - delta, 0.0)
	desired_yaw = target_yaw

func _animation_distance() -> float:
	if role_id == "sister_anwen":
		return 20.0
	return 16.0

func _set_animation_suspended(value: bool) -> void:
	ambient_suspended = value
	for driver in [animation_driver, face_driver]:
		if is_instance_valid(driver) and driver.has_method("set_distance_suspended"):
			driver.set_distance_suspended(value)

func _set_animation_update_rate(hz: float) -> void:
	if is_equal_approx(animation_update_hz, hz):
		return
	if is_instance_valid(animation_driver) and animation_driver.has_method("set_update_rate_hz"):
		animation_driver.set_update_rate_hz(hz)
		animation_update_hz = hz
