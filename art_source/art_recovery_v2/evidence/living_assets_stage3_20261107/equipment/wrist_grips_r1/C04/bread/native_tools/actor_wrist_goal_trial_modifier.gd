extends "res://scripts/character_life_modifier.gd"

## Authoring fixture only. Vector2 entries are forward and outward metres.
const OFFSETS := {"C04": {"bread": Vector2(0.015, 0.065)}}
var trial_asset := ""
var trial_style := ""
var trial_applications := 0
var trial_failures: Array[String] = []
var maximum_goal_error_m := 0.0

func _solve_arm(skeleton: Skeleton3D, arm: Dictionary, goal: Vector3, wrist_target: Variant = null, elbow_direction: Vector3 = Vector3.ZERO, wrist_weight: float = -1.0) -> void:
	var effective := activity if not activity.is_empty() else carried_activity
	var expected_activity := "eat" if trial_style == "bread" else "carry"
	if int(arm.hand) != skeleton.find_bone("hand_r") or not station.is_empty() or wrist_target != null or not driver.activity_prop_pose_ready() or effective != expected_activity or activity_prop != trial_style:
		super._solve_arm(skeleton, arm, goal, wrist_target, elbow_direction, wrist_weight)
		return
	var offset: Vector2 = OFFSETS[trial_asset][trial_style]
	var forward: Vector3 = driver.get_visible_forward()
	var right := forward.cross(Vector3.UP).normalized()
	var bias := (forward * offset.x + right * offset.y) * pose_weight
	var opposite_chain: Array[int] = [skeleton.find_bone("upperarm_l"), skeleton.find_bone("lowerarm_l"), skeleton.find_bone("hand_l")]
	if opposite_chain.has(-1) or not bias.is_finite() or bias.length() > 0.15 or forward.length_squared() < 0.99:
		trial_failures.append("Owning wrist or trial offset left its measured bound")
		return
	var opposite: Array[Transform3D] = []
	for bone: int in opposite_chain:
		opposite.append(skeleton.get_bone_global_pose(bone))
	var chain: Array[int] = [int(arm.upper), int(arm.lower), int(arm.hand)]
	var positions: Array[Vector3] = []
	var scales: Array[Vector3] = []
	for bone: int in chain:
		positions.append(skeleton.get_bone_pose_position(bone))
		scales.append(skeleton.get_bone_pose_scale(bone))
	var adjusted := goal + bias
	super._solve_arm(skeleton, arm, adjusted, wrist_target, elbow_direction, wrist_weight)
	for index: int in opposite_chain.size():
		if not skeleton.get_bone_global_pose(opposite_chain[index]).is_equal_approx(opposite[index]):
			trial_failures.append("Owning wrist trial moved the opposite arm")
	for index: int in chain.size():
		if skeleton.get_bone_pose_position(chain[index]) != positions[index] or skeleton.get_bone_pose_scale(chain[index]) != scales[index]:
			trial_failures.append("Owning wrist trial changed retained local translation or scale")
	var actual: Vector3 = _world(skeleton, int(arm.hand))
	if not actual.is_finite() or not adjusted.is_finite():
		trial_failures.append("Owning wrist trial produced a nonfinite result")
		return
	maximum_goal_error_m = maxf(maximum_goal_error_m, actual.distance_to(adjusted))
	trial_applications += 1
