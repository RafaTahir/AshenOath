extends SkeletonModifier3D
## Contact correction sampled after the character's ordinary native animation.
## Marker -Z points forwards for standing actors and towards the head of a bed.
const ArmIK = preload("res://scripts/views/character_arm_ik.gd")

var mark: Marker3D
var driver: Node
var kind := ""
var pelvis := -1
var arms: Array[Dictionary] = []
var legs: Array[Dictionary] = []

func bind(point: Marker3D, animation: Node) -> void:
	mark = point
	driver = animation
	kind = str(mark.get_meta("pose", "watch"))
	var rig := get_skeleton()
	pelvis = rig.find_bone("pelvis")
	for side in ["l", "r"]:
		var sign_value := -1.0 if side == "l" else 1.0
		_add_chain(arms, rig, ["upperarm_", "lowerarm_", "hand_"], side, sign_value)
		_add_chain(legs, rig, ["thigh_", "calf_", "foot_"], side, sign_value)

func _add_chain(chains: Array[Dictionary], rig: Skeleton3D, names: Array, suffix: String, side: float) -> void:
	var upper := rig.find_bone(names[0] + suffix)
	var lower := rig.find_bone(names[1] + suffix)
	var tip := rig.find_bone(names[2] + suffix)
	if mini(upper, mini(lower, tip)) >= 0:
		chains.append({"upper":upper, "lower":lower, "hand":tip, "side":side})

func _process_modification() -> void:
	if not is_instance_valid(mark) or not is_instance_valid(driver) or driver.dead or driver.story_dialogue_active or driver.distance_suspended:
		return
	if driver.has_active_action() and not (kind == "front_carry" and driver.current_state == "story_offer"):
		return
	var rig := get_skeleton()
	if rig == null or pelvis < 0 or not mark.is_visible_in_tree():
		return
	var right := mark.global_basis.x.normalized()
	var forward := -mark.global_basis.z.normalized()
	var lowering: bool = kind == "carry" and mark.global_position.y < driver.character_root.global_position.y - 0.18
	if kind in ["supported", "seated", "kneel"] or lowering:
		_support(rig, right, forward)
	var hip := ArmIK.world(rig, pelvis)
	for arm: Dictionary in arms:
		var side: float = arm.side
		var hand := mark.get_node_or_null("LeftHand" if side < 0.0 else "RightHand") as Marker3D
		var target := Vector3.ZERO
		if hand != null:
			target = hand.global_position
		elif kind == "supported":
			target = hip + Vector3.UP * (0.16 if side < 0 else 0.10) + forward * 0.23 + right * side * 0.08
		elif kind == "seated":
			target = hip + Vector3.UP * (0.29 if side < 0 else 0.08) + forward * 0.16 + right * (0.035 if side < 0 else 0.13)
		elif kind in ["brace_load", "indicate", "kneel", "work", "carry"]:
			# Tor's injury view already owns the protected left arm.
			if driver.novel_injury == &"novel_tor_braced" and side < 0:
				continue
			target = hip + right * side * 0.18 + forward * (0.36 if kind != "carry" else 0.22) + Vector3.UP * (0.36 if kind == "brace_load" else 0.14)
		else:
			continue
		ArmIK.solve(rig, arm, target, right, null, Vector3.DOWN + right * side * 0.5, 1.0)

func _support(rig: Skeleton3D, right: Vector3, forward: Vector3) -> void:
	var parent := rig.get_bone_parent(pelvis)
	var frame := rig.global_transform
	if parent >= 0: frame *= rig.get_bone_global_pose(parent)
	var before := rig.global_transform * rig.get_bone_global_pose(pelvis)
	var target := before
	var surface := mark.global_position
	if kind == "carry": surface.y = driver.character_root.global_position.y
	if kind == "supported":
		# Rest on the side with the upper body turned slightly towards the sky.
		target.basis = Basis(forward, deg_to_rad(-58.0)) * Basis(right, -PI * 0.5) * before.basis
		target.origin = surface + Vector3.UP * 0.145
	elif kind == "seated":
		target.origin = surface + Vector3.UP * 0.12
	else:
		var height := float(mark.get_meta("kneel_height", 0.45))
		var lean := deg_to_rad(float(mark.get_meta("lean_degrees", 32.0)))
		target.origin = surface + Vector3.UP * height
		target.basis = Basis(right, -lean) * before.basis
	var local := frame.affine_inverse() * target
	rig.set_bone_pose_position(pelvis, local.origin)
	rig.set_bone_pose_rotation(pelvis, local.basis.orthonormalized().get_rotation_quaternion())
	for leg: Dictionary in legs:
		var side: float = leg.side
		var ankle := surface + right * side * 0.11
		var pole := forward
		match kind:
			"seated":
				ankle += forward * 0.35 - Vector3.UP * 0.31
			"kneel", "carry":
				ankle += forward * (0.24 if side < 0.0 else -0.32) + Vector3.UP * 0.095
			"supported":
				ankle += -forward * (0.70 if side < 0.0 else 0.78) + Vector3.UP * (0.10 if side < 0.0 else 0.14)
				pole = right * 0.6 + Vector3.UP
		ArmIK.solve(rig, leg, ankle, right, null, pole, 1.0)
