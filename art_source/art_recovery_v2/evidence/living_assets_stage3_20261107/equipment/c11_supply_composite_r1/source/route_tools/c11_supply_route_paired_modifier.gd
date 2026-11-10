extends "c11_supply_forward_trial_modifier.gd"

const Mode = preload("c11_supply_route_paired_mode.gd")
var paired_goal_witness: Dictionary = {}

func _solve_arm(skeleton: Skeleton3D, arm: Dictionary, goal: Vector3, wrist_target: Variant = null, elbow_direction: Vector3 = Vector3.ZERO, wrist_weight: float = -1.0) -> void:
	if not activity.is_empty() or carried_activity != "carry" or activity_prop != "supply" \
			or int(arm.hand) != skeleton.find_bone("hand_r") or not station.is_empty() \
			or wrist_target != null or not driver.activity_prop_pose_ready():
		super._solve_arm(skeleton, arm, goal, wrist_target, elbow_direction, wrist_weight)
		return
	var added_forward: float = Mode.EXTRA_FORWARD * pose_weight
	var combined := Vector2(FORWARD_WITH_TORSO_CLEARANCE + Mode.EXTRA_FORWARD, SUPPLY_OUTWARD) * pose_weight
	var placement := actor.get_parent() as Node3D
	if not combined.is_finite() or combined.length() > 0.15 or not is_instance_valid(placement):
		trial_failures.append("Paired route-only wrist goal exceeded the retained bound")
		return
	var forward: Vector3 = driver.get_visible_forward()
	var right := forward.cross(Vector3.UP).normalized()
	var trial_goal := goal + forward * added_forward
	# Observe the same request and reach limit used by the retained arm owner.
	# Only super below applies the pose, with the original arm solution.
	var requested := trial_goal + forward * ((FORWARD_WITH_TORSO_CLEARANCE - SUPPLY_FORWARD) * pose_weight)
	requested += (forward * SUPPLY_FORWARD + right * SUPPLY_OUTWARD) * pose_weight
	var shoulder := _world(skeleton, int(arm.upper))
	var elbow := _world(skeleton, int(arm.lower))
	var hand := _world(skeleton, int(arm.hand))
	var upper := shoulder.distance_to(elbow)
	var lower := elbow.distance_to(hand)
	var minimum := absf(upper - lower) + 0.005
	var maximum := upper + lower - 0.005
	var length := shoulder.distance_to(requested)
	var reachable := shoulder + (requested - shoulder).normalized() * clampf(length, minimum, maximum)
	super._solve_arm(skeleton, arm, trial_goal, wrist_target, elbow_direction, wrist_weight)
	var inverse := placement.global_transform.affine_inverse()
	paired_goal_witness = {"shoulder": _cells(inverse * shoulder), "requested": _cells(inverse * requested),
		"reachable": _cells(inverse * reachable), "actual": _cells(inverse * _world(skeleton, int(arm.hand))),
		"minimum_reach_m": minimum, "maximum_reach_m": maximum, "additional_forward_m": added_forward,
		"clamped": length < minimum or length > maximum}

func _cells(point: Vector3) -> Array:
	return [point.x, point.y, point.z]
