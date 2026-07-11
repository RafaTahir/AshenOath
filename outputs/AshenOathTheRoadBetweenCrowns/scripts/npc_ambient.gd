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
var far_tick_accumulator := 0.0
var distance_hidden := false

func setup(id: String, target: Node3D = null) -> void:
	role_id = id
	focus_target = target
	if role_id == "sister_anwen":
		focus_radius = 6.4
		turn_speed = 2.4
		bob_amount = 0.004
		sway_amount = 0.75
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
	var parent_3d = get_parent() as Node3D
	if parent_3d != null:
		base_y = parent_3d.position.y
		base_yaw = parent_3d.rotation_degrees.y
	phase = randf() * TAU
	planted_yaw_offset = randf_range(-7.0, 7.0)
	animation_driver = parent_3d.find_child("CharacterAnimationDriver", true, false)
	if animation_driver != null:
		animation_driver.set_locomotion(0.0, Vector3.ZERO, true)

func _process(delta: float) -> void:
	var parent_3d = get_parent() as Node3D
	if parent_3d == null:
		return
	if role_id == "sister_anwen" and bool(parent_3d.get_meta("dialogue_facing_lock", false)):
		return
	if focus_target == null:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty() and players[0] is Node3D:
			focus_target = players[0]
	if focus_target != null and parent_3d.global_position.distance_to(focus_target.global_position) > 12.0:
		var distance: float = parent_3d.global_position.distance_to(focus_target.global_position)
		_set_distance_visible(parent_3d, distance <= 17.0)
		if animation_driver != null and animation_driver.has_method("set_distance_suspended"):
			animation_driver.set_distance_suspended(true)
		far_tick_accumulator += delta
		if far_tick_accumulator < 0.20:
			return
		delta = far_tick_accumulator
		far_tick_accumulator = 0.0
	else:
		_set_distance_visible(parent_3d, true)
		if animation_driver != null and animation_driver.has_method("set_distance_suspended"):
			animation_driver.set_distance_suspended(false)
		far_tick_accumulator = 0.0
	phase += delta * (0.48 if role_id == "sister_anwen" else 0.62)
	var target_yaw = base_yaw + planted_yaw_offset + sin(phase * 0.38) * sway_amount
	if focus_target != null:
		var to_target = focus_target.global_position - parent_3d.global_position
		to_target.y = 0.0
		if to_target.length() <= focus_radius and to_target.length() > 0.2:
			attention_hold = 0.9
			target_yaw = rad_to_deg(atan2(-to_target.x, -to_target.z))
		elif role_id == "sister_anwen":
			target_yaw = base_yaw + sin(phase * 0.22) * 0.45
	attention_hold = max(attention_hold - delta, 0.0)
	var turn_weight = turn_speed * (1.2 if attention_hold > 0.0 else 0.65)
	parent_3d.rotation_degrees.y = lerp_angle(deg_to_rad(parent_3d.rotation_degrees.y), deg_to_rad(target_yaw), turn_weight * delta) * 180.0 / PI
	parent_3d.position.y = base_y + sin(phase) * bob_amount + sin(phase * 0.37) * breathe_amount

func _set_distance_visible(parent_3d: Node3D, value: bool) -> void:
	if distance_hidden == not value:
		return
	distance_hidden = not value
	for geometry in parent_3d.find_children("*", "GeometryInstance3D", true, false):
		if not str(geometry.name).contains("InteractionWorldLabel"):
			geometry.visible = value
