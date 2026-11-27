extends RefCounted
## Two-joint arm solve shared by workstation grips, supporting poses and injuries.
## The returned world-space wrist goal is used by contact verification.

static func world(skeleton: Skeleton3D, bone: int) -> Vector3:
	return (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin

static func solve(skeleton: Skeleton3D, arm: Dictionary, goal: Vector3, actor_right: Vector3, wrist_target: Variant, elbow_direction: Vector3, wrist_weight: float) -> Vector3:
	var shoulder := world(skeleton, int(arm.upper))
	var elbow := world(skeleton, int(arm.lower))
	var hand := world(skeleton, int(arm.hand))
	var upper := shoulder.distance_to(elbow)
	var lower := elbow.distance_to(hand)
	if upper < 0.02 or lower < 0.02 or shoulder.distance_squared_to(goal) < 0.0001:
		return Vector3.INF
	var axis := (goal - shoulder).normalized()
	var distance := clampf(shoulder.distance_to(goal), absf(upper - lower) + 0.005, upper + lower - 0.005)
	goal = shoulder + axis * distance
	var along := (upper * upper + distance * distance - lower * lower) / (2.0 * distance)
	var bend := elbow - shoulder - axis * (elbow - shoulder).dot(axis)
	if elbow_direction.length_squared() > 0.0001:
		bend = elbow_direction - axis * elbow_direction.dot(axis)
	if bend.length_squared() < 0.0001:
		bend = actor_right * float(arm.side)
		bend -= axis * bend.dot(axis)
	if bend.length_squared() < 0.0001:
		return Vector3.INF
	var desired_elbow := shoulder + axis * along + bend.normalized() * sqrt(maxf(upper * upper - along * along, 0.0))
	# Propagate the upper-arm rotation analytically into the lower arm. Both
	# joints use one pose snapshot rather than forcing four whole-rig refreshes.
	var frame := skeleton.global_basis.orthonormalized()
	var upper_parent := skeleton.get_bone_parent(int(arm.upper))
	var lower_parent := skeleton.get_bone_parent(int(arm.lower))
	var upper_parent_basis := skeleton.get_bone_global_pose(upper_parent).basis.orthonormalized() if upper_parent >= 0 else Basis.IDENTITY
	var lower_parent_basis := skeleton.get_bone_global_pose(lower_parent).basis.orthonormalized() if lower_parent >= 0 else Basis.IDENTITY
	var hand_parent := skeleton.get_bone_parent(int(arm.hand))
	var hand_parent_basis := skeleton.get_bone_global_pose(hand_parent).basis.orthonormalized() if hand_parent >= 0 else Basis.IDENTITY
	var upper_basis := skeleton.get_bone_global_pose(int(arm.upper)).basis.orthonormalized()
	var lower_basis := skeleton.get_bone_global_pose(int(arm.lower)).basis.orthonormalized()
	var upper_turn := Basis(Quaternion((elbow - shoulder).normalized(), (desired_elbow - shoulder).normalized()))
	var local_turn := frame.inverse() * upper_turn * frame
	skeleton.set_bone_pose_rotation(int(arm.upper), (upper_parent_basis.inverse() * local_turn * upper_basis).orthonormalized().get_rotation_quaternion())
	var moved_elbow := shoulder + upper_turn * (elbow - shoulder)
	var moved_hand := shoulder + upper_turn * (hand - shoulder)
	if moved_hand.distance_squared_to(moved_elbow) < 0.00001 or goal.distance_squared_to(moved_elbow) < 0.00001:
		return Vector3.INF
	var lower_turn := frame.inverse() * Basis(Quaternion((moved_hand - moved_elbow).normalized(), (goal - moved_elbow).normalized())) * frame
	skeleton.set_bone_pose_rotation(int(arm.lower), ((local_turn * lower_parent_basis).inverse() * lower_turn * local_turn * lower_basis).orthonormalized().get_rotation_quaternion())
	if wrist_target is Basis:
		var desired := ((lower_turn * local_turn * hand_parent_basis).inverse() * frame.inverse() * (wrist_target as Basis)).orthonormalized().get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(int(arm.hand), skeleton.get_bone_pose_rotation(int(arm.hand)).slerp(desired, wrist_weight))
	return goal
