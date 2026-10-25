extends SkeletonModifier3D

## Small authored work/attention poses on the retained rig. Hands solve to
## bounded goals; sockets and held tools follow the actual hand bones.
var driver: Node
var actor: Node3D
var activity := ""
var elapsed := 0.0
var pose_weight := 0.0
var arms: Array[Dictionary] = []
var spine := -1
var head := -1
var wings: Array[int] = []
var carried_activity := ""
var creature_id := ""
var creature_intent := ""
var creature_amount := 0.0
var creature_weight := 0.0
var tool: Node3D
var tool_kind := ""
var station: Dictionary = {}
var last_contact_cycle := -1
var tool_contact: Node3D
var seated_legs: Array[Dictionary] = []
var pelvis := -1

func configure(body: Node3D, motion: Node) -> void:
	actor = body
	driver = motion
	var skeleton := get_skeleton()
	pelvis = skeleton.find_bone("pelvis")
	for side: String in ["l", "r"]:
		var thigh := skeleton.find_bone("thigh_" + side)
		var calf := skeleton.find_bone("calf_" + side)
		if thigh >= 0 and calf >= 0: seated_legs.append({"thigh":thigh,"calf":calf})
	for alias: String in ["Head", "head", "head_01", "DEF-head"]:
		head = skeleton.find_bone(alias)
		if head >= 0:
			break
	for alias: String in ["Wing1_L", "Wing1_R"]:
		var bone := skeleton.find_bone(alias)
		if bone >= 0:
			wings.append(bone)
	spine = skeleton.find_bone("spine_03")
	if spine < 0:
		for alias: String in ["Chest", "chest", "Spine", "spine_02", "Body"]:
			spine = skeleton.find_bone(alias)
			if spine >= 0:
				break
	for side: String in ["l", "r"]:
		var upper := skeleton.find_bone("upperarm_" + side)
		var lower := skeleton.find_bone("lowerarm_" + side)
		var hand := skeleton.find_bone("hand_" + side)
		if upper >= 0 and lower >= 0 and hand >= 0:
			arms.append({"upper":upper, "lower":lower, "hand":hand, "side":-1.0 if side == "l" else 1.0})
	elapsed = float(absi(str(body.name).hash()) % 41) * 0.1

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not is_instance_valid(driver) or not is_instance_valid(actor):
		return
	if bool(driver.dead) or bool(driver.distance_suspended) or driver.has_active_action():
		pose_weight = 0.0
		if is_instance_valid(tool):
			tool.visible = false
		return
	var delta := minf(get_process_delta_time(), 0.05)
	elapsed += delta
	var near := true
	var viewer: Node3D = actor.get_meta("cast_viewer") if actor.has_meta("cast_viewer") else null
	if is_instance_valid(viewer):
		near = actor.global_position.distance_squared_to(viewer.global_position) < 100.0
	var effective := activity if activity != "" else carried_activity
	var requested := effective != "" and near and not bool(driver.story_dialogue_active)
	_update_tool(effective, requested)
	creature_weight = move_toward(creature_weight, creature_amount if near and not bool(driver.story_dialogue_active) else 0.0, delta*3.0)
	if creature_weight > 0.001:
		_creature_pose(skeleton)
	pose_weight = move_toward(pose_weight, 1.0 if requested else 0.0, delta * 4.5)
	if pose_weight <= 0.001:
		return
	if effective == "sit":
		if pelvis >= 0:
			var parent := skeleton.get_bone_parent(pelvis)
			var frame := skeleton.global_basis * (skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY)
			var offset := frame.inverse() * Vector3(0,-0.45,0)
			skeleton.set_bone_pose_position(pelvis,skeleton.get_bone_pose_position(pelvis)+offset*pose_weight)
		for leg: Dictionary in seated_legs:
			skeleton.set_bone_pose_rotation(leg.thigh,skeleton.get_bone_pose_rotation(leg.thigh)*Quaternion(Vector3.RIGHT,-1.35*pose_weight))
			skeleton.set_bone_pose_rotation(leg.calf,skeleton.get_bone_pose_rotation(leg.calf)*Quaternion(Vector3.RIGHT,1.35*pose_weight))
		return
	if spine >= 0:
		var base := skeleton.get_bone_pose_rotation(spine)
		var bend := 0.12 if effective == "scavenge" else 0.0
		skeleton.set_bone_pose_rotation(spine, base * Quaternion(Vector3.RIGHT, (bend + sin(elapsed * 1.4) * 0.007) * pose_weight))
	if effective in ["watch", "lookout", "idle", "remember", "rest"]:
		return
	var forward: Vector3 = driver.get_visible_forward()
	var right := forward.cross(Vector3.UP).normalized()
	var period := float(station.get("period", 2.0))
	var cycle := floori(elapsed / period)
	var phase := fmod(elapsed, period) / period
	var contact := not station.is_empty() and effective == str(station.get("activity", ""))
	for arm: Dictionary in arms:
		var shoulder := _world(skeleton, int(arm.upper))
		var elbow := _world(skeleton, int(arm.lower))
		var hand := _world(skeleton, int(arm.hand))
		var reach := shoulder.distance_to(elbow) + elbow.distance_to(hand)
		var across := -0.12 * float(arm.side)
		var depth := 0.36
		var drop := 0.58
		match effective:
			"forge", "repair":
				depth = 0.55
				drop = 0.48 - (maxf(0.0, sin(elapsed * 3.1)) * 0.42 if float(arm.side) > 0 else 0.0)
			"read", "notice_board":
				across = -0.25 * float(arm.side)
				depth = 0.48
				drop = 0.26
			"check_rope", "well":
				depth = 0.46
				drop = 0.30 + sin(elapsed * 1.7 + float(arm.side)) * 0.12
			"bake", "kitchen":
				across = -0.24 * float(arm.side)
				depth = 0.58 + sin(elapsed * 2.0) * 0.08
				drop = 0.57
			"tend", "sort_herbs", "herb_stall", "sort_seeds":
				across += sin(elapsed * 1.8 + float(arm.side) * 1.3) * 0.12
				depth = 0.52
				drop = 0.56
			"fear", "warn":
				across = 0.04 * float(arm.side)
				depth = 0.30
				drop = 0.12
			"care":
				depth = 0.42 if float(arm.side) > 0 else 0.15
				drop = 0.42
			"carry", "check_supplies", "sort_supplies":
				across = -0.18*float(arm.side)
				depth = 0.26
				drop = 0.57
		var goal := shoulder + (forward * depth + right * across - Vector3.UP * drop) * reach
		var wrist_target: Variant = null
		if contact:
			goal = station.get("right" if float(arm.side) > 0 else "left", goal)
			var lift := float(station.get("lift", 0.0))
			if float(arm.side) > 0:
				if effective == "forge" and is_instance_valid(tool_contact):
					var tip_offset := tool_contact.global_position - hand
					if tip_offset.length_squared() > 0.0001:
						var hand_basis := (skeleton.global_basis * skeleton.get_bone_global_pose(int(arm.hand)).basis).orthonormalized()
						wrist_target = Basis(Quaternion(tip_offset.normalized(), Vector3.DOWN)) * hand_basis
						goal = (station.point as Vector3) + Vector3.UP * (0.035 + tip_offset.length())
				goal += Vector3.UP * lift * pow(sin(phase * PI), 2.0)
			elif effective in ["bake", "sort_herbs", "sort_seeds", "tend"]:
				goal += right * sin(phase * TAU) * 0.04
		_solve_arm(skeleton, arm, hand.lerp(goal, pose_weight), wrist_target)
	if contact and cycle != last_contact_cycle and phase < 0.15 and pose_weight > 0.95:
		last_contact_cycle = cycle
		var event := str(station.get("sound", ""))
		if event != "":
			driver.activity_contact.emit(event, station.get("point", actor.global_position))

func _update_tool(kind: String, visible_now: bool) -> void:
	var style := str({"repair":"hammer", "forge":"hammer", "read":"book", "notice_board":"book", "check_rope":"rope", "well":"rope", "bake":"bread", "kitchen":"bread", "care":"cloth", "carry":"supply", "check_supplies":"supply", "sort_supplies":"supply", "sort_herbs":"bowl", "sort_seeds":"bowl", "tend":"bowl", "herb_stall":"bowl"}.get(kind, ""))
	if style != "" and style != tool_kind:
		if is_instance_valid(tool):
			tool.queue_free()
		tool = preload("res://scripts/character_presentation.gd").attach_activity_tool(actor, style)
		tool_kind = style
		tool_contact = tool.find_child("ForgedHead", true, false) as Node3D if is_instance_valid(tool) and style == "hammer" else null
	if is_instance_valid(tool):
		tool.visible = visible_now and style == tool_kind

func _creature_pose(skeleton: Skeleton3D) -> void:
	var recovery := creature_intent == "recovery"
	var lean := 0.0
	var tilt := 0.0
	match creature_id:
		"bell_eater":
			tilt = sin(elapsed*0.75)*0.09 if not recovery else 0.05
			lean = 0.04 if recovery else 0.015
		"bog_wretch":
			lean = 0.08 if recovery else 0.035
			tilt = sin(elapsed*0.45)*0.04
		"rootbound_colossus":
			lean = 0.07 if recovery else -0.035
		"ashwing":
			for index in wings.size():
				var bone := wings[index]
				var fold := (0.10 if recovery else 0.025)*(-1.0 if index == 0 else 1.0)*creature_weight
				skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone)*Quaternion(Vector3.FORWARD, fold))
			lean = 0.04 if recovery else 0.0
		"halvern_boss":
			lean = 0.025 if recovery else -0.015
		"white_hart_avatar":
			tilt = sin(elapsed*0.32)*0.025
			lean = 0.035 if recovery else 0.0
	if spine >= 0:
		skeleton.set_bone_pose_rotation(spine, skeleton.get_bone_pose_rotation(spine)*Quaternion(Vector3.RIGHT, lean*creature_weight))
	if head >= 0:
		skeleton.set_bone_pose_rotation(head, skeleton.get_bone_pose_rotation(head)*Quaternion(Vector3.FORWARD, tilt*creature_weight))

func _world(skeleton: Skeleton3D, bone: int) -> Vector3:
	return (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin

func _solve_arm(skeleton: Skeleton3D, arm: Dictionary, goal: Vector3, wrist_target: Variant = null, elbow_direction: Vector3 = Vector3.ZERO) -> void:
	var shoulder := _world(skeleton, int(arm.upper))
	var elbow := _world(skeleton, int(arm.lower))
	var hand := _world(skeleton, int(arm.hand))
	var upper := shoulder.distance_to(elbow)
	var lower := elbow.distance_to(hand)
	if upper < 0.02 or lower < 0.02 or shoulder.distance_squared_to(goal) < 0.0001:
		return
	var axis := (goal - shoulder).normalized()
	var distance := clampf(shoulder.distance_to(goal), absf(upper - lower) + 0.005, upper + lower - 0.005)
	goal = shoulder + axis * distance
	var along := (upper * upper + distance * distance - lower * lower) / (2.0 * distance)
	var bend := elbow - shoulder - axis * (elbow - shoulder).dot(axis)
	if elbow_direction.length_squared() > 0.0001:
		bend = elbow_direction - axis * elbow_direction.dot(axis)
	if bend.length_squared() < 0.0001:
		bend = actor.global_basis.x * float(arm.side)
		bend -= axis * bend.dot(axis)
	if bend.length_squared() < 0.0001:
		return
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
		return
	var lower_turn := frame.inverse() * Basis(Quaternion((moved_hand - moved_elbow).normalized(), (goal - moved_elbow).normalized())) * frame
	skeleton.set_bone_pose_rotation(int(arm.lower), ((local_turn * lower_parent_basis).inverse() * lower_turn * local_turn * lower_basis).orthonormalized().get_rotation_quaternion())
	if wrist_target is Basis:
		var desired := ((lower_turn * local_turn * hand_parent_basis).inverse() * frame.inverse() * (wrist_target as Basis)).orthonormalized().get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(int(arm.hand), skeleton.get_bone_pose_rotation(int(arm.hand)).slerp(desired, pose_weight))
