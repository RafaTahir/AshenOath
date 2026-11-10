extends "c11_activity_goal_trial_modifier.gd"

## Source-only supply variant. The exact accepted bread branch is inherited.
const FORWARD_WITH_TORSO_CLEARANCE := 0.075

func _solve_arm(skeleton: Skeleton3D, arm: Dictionary, goal: Vector3, wrist_target: Variant = null, elbow_direction: Vector3 = Vector3.ZERO, wrist_weight: float = -1.0) -> void:
	var effective := activity if not activity.is_empty() else carried_activity
	if effective not in ["carry", "check_supplies", "sort_supplies"] or activity_prop not in ["", "supply"] \
			or int(arm.hand) != skeleton.find_bone("hand_r") or not station.is_empty() \
			or wrist_target != null or not driver.activity_prop_pose_ready():
		super._solve_arm(skeleton, arm, goal, wrist_target, elbow_direction, wrist_weight)
		return
	var total_offset := Vector2(FORWARD_WITH_TORSO_CLEARANCE, SUPPLY_OUTWARD) * pose_weight
	if not total_offset.is_finite() or total_offset.length() > 0.15:
		trial_failures.append("Owning hand goal left its measured trial bound")
		return
	var actual_activity := activity
	var actual_style := activity_prop
	# Keep the actual activity in the caller and renderer. Only the existing
	# trial selector sees the canonical supply recipe during this arm solve.
	activity = "carry"
	activity_prop = "supply"
	var forward: Vector3 = driver.get_visible_forward()
	var additional := forward * ((FORWARD_WITH_TORSO_CLEARANCE - SUPPLY_FORWARD) * pose_weight)
	super._solve_arm(skeleton, arm, goal + additional, wrist_target, elbow_direction, wrist_weight)
	activity = actual_activity
	activity_prop = actual_style
