extends "res://scripts/character_life_modifier.gd"

## Isolated C11 authoring trial. The retained activity modifier owns every
## sample and still solves both arms. Only a matched right wrist goal moves.
const BREAD_FORWARD := 0.08
const BREAD_OUTWARD := 0.055
const SUPPLY_FORWARD := 0.035
const SUPPLY_OUTWARD := 0.12
var trial_applications := 0
var trial_failures: Array[String] = []

func _solve_arm(skeleton: Skeleton3D, arm: Dictionary, goal: Vector3, wrist_target: Variant = null, elbow_direction: Vector3 = Vector3.ZERO, wrist_weight: float = -1.0) -> void:
	var effective := activity if not activity.is_empty() else carried_activity
	var offset := Vector2.ZERO
	if int(arm.hand) == skeleton.find_bone("hand_r") and station.is_empty() and wrist_target == null and driver.activity_prop_pose_ready():
		if effective == "eat" and activity_prop == "bread":
			offset = Vector2(BREAD_FORWARD, BREAD_OUTWARD)
		elif effective == "carry" and activity_prop == "supply":
			offset = Vector2(SUPPLY_FORWARD, SUPPLY_OUTWARD)
	if offset.is_zero_approx():
		super._solve_arm(skeleton, arm, goal, wrist_target, elbow_direction, wrist_weight)
		return
	var forward: Vector3 = driver.get_visible_forward()
	var right := forward.cross(Vector3.UP).normalized()
	var bias := (forward * offset.x + right * offset.y) * pose_weight
	if not bias.is_finite() or bias.length() > 0.15:
		trial_failures.append("Owning hand goal left its measured trial bound")
		return
	var left := skeleton.find_bone("hand_l")
	if left < 0:
		trial_failures.append("Retained opposite hand is unavailable")
		return
	var left_pose := skeleton.get_bone_global_pose(left)
	var right_chain: Array[int] = [int(arm.upper), int(arm.lower), int(arm.hand)]
	var positions: Array[Vector3] = []
	var scales: Array[Vector3] = []
	for bone: int in right_chain:
		positions.append(skeleton.get_bone_pose_position(bone))
		scales.append(skeleton.get_bone_pose_scale(bone))
	super._solve_arm(skeleton, arm, goal + bias, wrist_target, elbow_direction, wrist_weight)
	if not skeleton.get_bone_global_pose(left).is_equal_approx(left_pose):
		trial_failures.append("Owning-arm trial moved the other hand")
	for index: int in right_chain.size():
		var bone := right_chain[index]
		if skeleton.get_bone_pose_position(bone) != positions[index] or skeleton.get_bone_pose_scale(bone) != scales[index]:
			trial_failures.append("Owning-arm trial changed a retained translation or scale")
	trial_applications += 1
