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
var activity_prop := ""
var creature_id := ""
var creature_intent := ""
var creature_amount := 0.0
var creature_weight := 0.0
var authored_creature_ambient := false
var tool: Node3D
var owns_tool := false
var stowed_role_equipment: Dictionary = {}
var tool_kind := ""
var tool_uses_measured_grip := true
var solved_wrist_goal := Vector3.INF
var station: Dictionary = {}
var rest_anchor: Dictionary = {}
var last_contact_cycle := -1
var tool_contact: Node3D
var tool_contact_local := Vector3.ZERO
var tool_contact_points := PackedVector3Array()
var last_contact_samples: Dictionary = {}
var seated_legs: Array[Dictionary] = []
var pelvis := -1
var ambient_weight := 0.0
var shift_rotation := 0.0
var shift_target := 0.0
var next_shift := 0.0
var idle_rng := RandomNumberGenerator.new()
var humanoid := false
var anwen_staff_pose := false
var staff_equipment: Node3D
var staff_weight := 0.0
var staff_tip := Vector3.ZERO
var staff_planted := false
var garment_arm_clearance := 0.0

func configure(body: Node3D, motion: Node) -> void:
	actor = body
	driver = motion
	# configure runs while prepared actors are still outside the SceneTree.
	var skeleton := get_parent() as Skeleton3D
	if skeleton == null:
		return
	# Only the prepared-source verifier marks these native clips as authored.
	# Leave their fin, sac and antenna poses under the animation graph owner.
	var creature_source: Node = skeleton
	while creature_source != null:
		if bool(creature_source.get_meta("authored_creature_ambient", false)):
			authored_creature_ambient = true
			break
		if creature_source == actor: break
		creature_source = creature_source.get_parent()
	var source: Node = skeleton
	while source != null:
		if source.has_meta("garment_arm_clearance_m"):
			garment_arm_clearance = clampf(float(source.get_meta("garment_arm_clearance_m")), 0.0, 0.14)
			break
		if source == actor:
			break
		source = source.get_parent()
	anwen_staff_pose = preload("res://scripts/character_presentation.gd").uses_fitted_anwen_staff(skeleton, actor)
	if anwen_staff_pose:
		staff_equipment = actor.find_child("AnwenStaffEquipment", true, false) as Node3D
		staff_weight = 1.0
	pelvis = skeleton.find_bone("pelvis")
	for side: String in ["l", "r"]:
		var thigh := skeleton.find_bone("thigh_" + side)
		var calf := skeleton.find_bone("calf_" + side)
		var foot := skeleton.find_bone("foot_" + side)
		if thigh >= 0 and calf >= 0: seated_legs.append({"thigh":thigh,"calf":calf,"foot":foot,"side":-1.0 if side == "l" else 1.0})
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
	idle_rng.seed = absi((str(body.name) + str(body.get_instance_id())).hash())
	next_shift = elapsed + idle_rng.randf_range(6.0, 10.0)
	var role := str(body.get_meta("character_visual_role", ""))
	humanoid = not arms.is_empty() and wings.is_empty() and role not in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "bog_wretch", "gravebound_knight", "bell_eater", "rootbound_colossus", "ashwing", "white_hart_avatar"]

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not is_instance_valid(driver) or not is_instance_valid(actor):
		return
	if bool(driver.dead) or bool(driver.distance_suspended) or driver.has_active_action():
		pose_weight = 0.0
		ambient_weight = 0.0
		hide_activity_tool()
		if anwen_staff_pose and not bool(driver.dead) and not bool(driver.distance_suspended) \
				and (bool(driver.story_dialogue_active) or str(driver.current_state) == "greet"):
			# Keep the real support grip while the free arm and body deliver
			# authored dialogue. Combat and terminal poses retain their priority.
			_staff_pose(skeleton, minf(get_process_delta_time(), 0.05), "")
		elif anwen_staff_pose and is_instance_valid(staff_equipment) and not bool(driver.distance_suspended):
			staff_equipment.visible = false
		return
	var delta := minf(get_process_delta_time(), 0.05)
	elapsed += delta
	var near := true
	var viewer: Node3D = actor.get_meta("cast_viewer") if actor.has_meta("cast_viewer") else null
	if is_instance_valid(viewer):
		near = actor.global_position.distance_squared_to(viewer.global_position) < 100.0
	var effective := activity if activity != "" else carried_activity
	var waiting_for_station: bool = bool(driver.get("life_requires_station")) and effective in driver.life_work_kinds \
		and (station.is_empty() or str(station.get("activity", "")) != effective)
	if waiting_for_station:
		# A missing/busy task surface is quiet waiting, never a convincing
		# work clip performed against empty space or a substitute held vessel.
		effective = "idle"
	var native_motion: Dictionary = driver.life_motion_sample()
	var awaiting_native: bool = driver.life_clip != StringName() and native_motion.is_empty()
	var requested := effective != "" and near and not bool(driver.story_dialogue_active)
	_ambient_pose(skeleton, delta, near, effective, awaiting_native or not native_motion.is_empty())
	if humanoid and near and garment_arm_clearance > 0.0 and not bool(driver.story_dialogue_active) and float(driver.current_speed_mps) > 0.08 and effective in ["", "idle", "watch", "lookout", "walk", "travel"]:
		var across := actor.global_basis.x.normalized()
		var clearance := garment_arm_clearance * actor.global_basis.get_scale().y * clampf(float(driver.current_speed_mps) / 0.6, 0.0, 1.0)
		for arm: Dictionary in arms:
			var shoulder := _world(skeleton, int(arm.upper))
			var side := signf((shoulder - actor.global_position).dot(across))
			_solve_arm(skeleton, arm, _world(skeleton, int(arm.hand)) + across * side * clearance)
	if anwen_staff_pose:
		_staff_pose(skeleton, delta, effective)
	var scoped_grip := _update_tool(effective, requested and not waiting_for_station, not waiting_for_station)
	creature_weight = move_toward(creature_weight, creature_amount if near and not bool(driver.story_dialogue_active) else 0.0, delta*3.0)
	if creature_weight > 0.001:
		_creature_pose(skeleton)
	pose_weight = move_toward(pose_weight, 1.0 if requested else 0.0, delta * 4.5)
	if pose_weight <= 0.001 or awaiting_native:
		if not scoped_grip.is_empty() and is_instance_valid(tool):
			tool.visible = false
		return
	if effective == "sleep":
		_pose_supported_sleep(skeleton)
		return
	if effective in ["sit", "seated_eat"]:
		if pelvis >= 0:
			var parent := skeleton.get_bone_parent(pelvis)
			var frame := skeleton.global_basis * (skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY)
			var offset := frame.inverse() * Vector3(0,-0.45,0)
			skeleton.set_bone_pose_position(pelvis,skeleton.get_bone_pose_position(pelvis)+offset*pose_weight)
		for leg: Dictionary in seated_legs:
			skeleton.set_bone_pose_rotation(leg.thigh,skeleton.get_bone_pose_rotation(leg.thigh)*Quaternion(Vector3.RIGHT,-1.35*pose_weight))
			skeleton.set_bone_pose_rotation(leg.calf,skeleton.get_bone_pose_rotation(leg.calf)*Quaternion(Vector3.RIGHT,1.35*pose_weight))
		if effective == "sit": return
	if spine >= 0 and native_motion.is_empty():
		var base := skeleton.get_bone_pose_rotation(spine)
		var bend := 0.12 if effective == "scavenge" else 0.0
		skeleton.set_bone_pose_rotation(spine, base * Quaternion(Vector3.RIGHT, (bend + sin(elapsed * 1.4) * 0.007) * pose_weight))
	if effective in ["watch", "lookout", "idle", "remember", "rest", "sleep"]:
		return
	var forward: Vector3 = driver.get_visible_forward()
	var right := forward.cross(Vector3.UP).normalized()
	var period := float(station.get("period", 2.0))
	var cycle := floori(elapsed / period)
	var phase := fmod(elapsed, period) / period
	var authored_work := str(native_motion.get("clip", "")) == "life/Life_Work"
	var contact_fraction := 0.0
	if authored_work:
		cycle = int(native_motion.cycle)
		phase = float(native_motion.phase)
		contact_fraction = float(native_motion.contact_fraction)
	var contact := not station.is_empty() and effective == str(station.get("activity", ""))
	# Native work owns anticipation, inspection and recovery. IK only corrects
	# final contact against the real station, never replaces the complete clip.
	if authored_work and not contact:
		return
	var reached_contact := not authored_work
	var contact_hands := 0
	var reached_hands := 0
	var hammer_work := effective in ["forge", "repair"] and tool_kind == "hammer" and is_instance_valid(tool_contact)
	var grip_reached := false
	for arm: Dictionary in arms:
		if authored_work and hammer_work and float(arm.side) < 0:
			continue
		# A visible fitted staff retains its right arm through care, meals and
		# supply carrying. The free left hand owns those ambient props.
		if anwen_staff_pose and is_instance_valid(staff_equipment) and staff_equipment.visible and float(arm.side) > 0:
			continue
		var shoulder := _world(skeleton, int(arm.upper))
		var elbow := _world(skeleton, int(arm.lower))
		var hand := _world(skeleton, int(arm.hand))
		var reach := shoulder.distance_to(elbow) + elbow.distance_to(hand)
		var across := -0.12 * float(arm.side)
		var depth := 0.36
		var drop := 0.58
		match effective:
			"fishing":
				across = -0.22 * float(arm.side)
				depth = 0.44
				drop = 0.38
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
			"eat", "seated_eat":
				across = -0.10 * float(arm.side)
				depth = 0.23
				var eating_hand: bool = float(arm.side) < 0 if anwen_staff_pose else float(arm.side) > 0
				drop = 0.12 + (0.08 * sin(elapsed * 0.9) if eating_hand else 0.25)
			"pray":
				across = -0.30 * float(arm.side)
				depth = 0.25
				drop = 0.21
			"carry", "check_supplies", "sort_supplies":
				across = -0.18*float(arm.side)
				depth = 0.26
				drop = 0.57
		var goal := shoulder + (forward * depth + right * across - Vector3.UP * drop) * reach
		var wrist_target: Variant = null
		var probe_local := Vector3.ZERO
		var probe_kind := "wrist"
		if contact:
			var working_right := float(arm.side) > 0
			goal = station.get("right" if working_right else "left", goal)
			var lift := float(station.get("lift", 0.0))
			if working_right:
				if hammer_work:
					# BoneAttachment globals may still contain the preceding frame.
					# The authored socket offset composed with this sampled bone is
					# stable at every animation/update rate.
					var tip_offset := skeleton.global_basis * skeleton.get_bone_global_pose(int(arm.hand)).basis * tool_contact_local
					if tip_offset.length_squared() > 0.0001:
						var hand_basis := (skeleton.global_basis * skeleton.get_bone_global_pose(int(arm.hand)).basis).orthonormalized()
						wrist_target = Basis(Quaternion(tip_offset.normalized(), Vector3.DOWN)) * hand_basis
						goal = (station.point as Vector3) + Vector3.UP * (0.035 + tip_offset.length())
				goal += Vector3.UP * lift * (pow(maxf(0.0, sin(phase * TAU)), 2.0) if authored_work else pow(sin(phase * PI), 2.0))
			elif effective in ["bake", "sort_herbs", "sort_seeds", "tend"]:
				goal += right * sin(phase * TAU) * 0.04
		var contact_target := goal
		if authored_work and contact:
			var hand_frame := skeleton.global_basis * skeleton.get_bone_global_pose(int(arm.hand)).basis
			var probes: Dictionary = native_motion.get("contact_probes", {})
			var side := "left" if float(arm.side) < 0 else "right"
			if probes.has(side):
				probe_local = probes[side]
				probe_kind = "palm"
			elif effective == "care" and tool_kind == "cloth" and not tool_contact_points.is_empty():
				var lowest := INF
				for point: Vector3 in tool_contact_points:
					var height := (hand_frame * point).y
					if height < lowest:
						lowest = height
						probe_local = point
				probe_kind = "cloth"
				contact_target.y = (station.point as Vector3).y
			elif hammer_work:
				probe_kind = "hammer"
				probe_local = tool_contact_local
				contact_target = (station.point as Vector3) + Vector3.UP * 0.035
			if probe_kind in ["palm", "cloth"]:
				# Preserve the authored palm orientation while moving its actual
				# grip/surface onto the target; wrist origins are not contacts.
				wrist_target = hand_frame.orthonormalized()
				goal = contact_target - hand_frame * probe_local
		var contact_weight := smoothstep(0.22, contact_fraction, phase) * (1.0 - smoothstep(contact_fraction + 0.08, 0.80, phase)) if authored_work else 1.0
		var wrist := hand.lerp(goal, pose_weight * contact_weight)
		var owns_grip: bool = not scoped_grip.is_empty() and str(skeleton.get_bone_name(int(arm.hand))) == str(scoped_grip.bone)
		if owns_grip and wrist_target == null:
			var bias: Vector2 = scoped_grip.goal
			wrist += (forward * bias.x + right * bias.y) * pose_weight
		_solve_arm(skeleton, arm, wrist, wrist_target if contact_weight > 0.95 else null)
		if owns_grip and bool(scoped_grip.visible) and wrist_target == null and is_equal_approx(pose_weight, 1.0):
			grip_reached = solved_wrist_goal.is_finite() and _world(skeleton, int(arm.hand)).distance_squared_to(solved_wrist_goal) <= 0.000001
		if authored_work and contact_weight > 0.95 and (not hammer_work or float(arm.side) > 0):
			contact_hands += 1
			var actual: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(int(arm.hand)) * probe_local
			var error := actual.distance_to(contact_target)
			last_contact_samples["left" if float(arm.side) < 0 else "right"] = {"kind":probe_kind, "target":contact_target, "actual":actual, "error":error, "cycle":cycle}
			if error <= 0.06:
				reached_hands += 1
	if not scoped_grip.is_empty() and is_instance_valid(tool):
		tool.visible = bool(scoped_grip.visible) and grip_reached
	if authored_work:
		reached_contact = contact_hands > 0 and reached_hands == contact_hands
	var at_contact := phase >= contact_fraction if authored_work else phase < 0.15
	if contact and cycle != last_contact_cycle and at_contact and pose_weight > 0.95 and reached_contact:
		last_contact_cycle = cycle
		var event := str(station.get("contact_event", station.get("sound", "")))
		if event != "":
			driver.activity_contact.emit(event, station.get("point", actor.global_position))

func _update_tool(kind: String, visible_now: bool, allow_authored_prop: bool = true) -> Dictionary:
	var style := str({"repair":"hammer", "forge":"hammer", "read":"book", "notice_board":"book", "check_rope":"rope", "well":"rope", "bake":"bread", "kitchen":"bread", "care":"cloth", "carry":"supply", "check_supplies":"supply", "sort_supplies":"supply", "sort_herbs":"bowl", "sort_seeds":"bowl", "tend":"bowl", "herb_stall":"bowl"}.get(kind, ""))
	if allow_authored_prop and activity_prop != "":
		style = activity_prop
	var supported_task: bool = station.get("activity", "") == kind and str(station.get("surface_prop", "")) != ""
	_set_role_book_stowed(visible_now and supported_task)
	if supported_task and not bool(station.get("held_tool", false)):
		style = ""
	var scoped_grip := {}
	var use_measured_grip := true
	if style in ["bread", "supply"]:
		visible_now = visible_now and is_instance_valid(driver) and driver.activity_prop_pose_ready()
		var grips: Dictionary = actor.get_meta("activity_prop_grips", {})
		var record: Dictionary = grips.get(style, {})
		var goals: Dictionary = record.get("wrist_goals", {})
		if not goals.is_empty():
			var route := str(record.get("moving_route", ""))
			var mode: String = driver.activity_grip_pose_mode(kind, style, route) if station.is_empty() and is_instance_valid(driver) else ""
			use_measured_grip = goals.has(mode)
			if use_measured_grip:
				scoped_grip = {"bone": record.bone, "goal": goals[mode], "visible": visible_now}
	if style != "" and (style != tool_kind or use_measured_grip != tool_uses_measured_grip or not is_instance_valid(tool)):
		_release_tool()
		tool = preload("res://scripts/character_presentation.gd").attach_activity_tool(actor, style, use_measured_grip)
		tool_uses_measured_grip = use_measured_grip
		if not scoped_grip.is_empty() and is_instance_valid(tool):
			tool.visible = false
		owns_tool = is_instance_valid(tool) and bool(tool.get_meta("life_generated_activity_tool", false))
		tool_kind = style
		tool_contact = tool.find_child("ForgedHead", true, false) as Node3D if is_instance_valid(tool) and style == "hammer" else null
		tool_contact_local = _contact_socket_offset(tool_contact)
		tool_contact_points.clear()
		if style == "cloth" and is_instance_valid(tool):
			var unique := {}
			for mesh: MeshInstance3D in tool.find_children("*", "MeshInstance3D", true, false):
				if mesh.mesh == null: continue
				var frame := _contact_socket_frame(mesh)
				for vertex: Vector3 in mesh.mesh.get_faces():
					var point := frame * vertex
					if not unique.has(point):
						unique[point] = true
						tool_contact_points.append(point)
	if scoped_grip.is_empty() and is_instance_valid(tool):
		tool.visible = visible_now and style == tool_kind
	return scoped_grip

func hide_activity_tool() -> void:
	if is_instance_valid(tool):
		tool.visible = false
	_set_role_book_stowed(false)

func _set_role_book_stowed(stowed: bool) -> void:
	if not stowed:
		var reference: WeakRef = stowed_role_equipment.get("node")
		var borrowed := reference.get_ref() as Node3D if reference != null else null
		if borrowed != null:
			var owner_ref: WeakRef = borrowed.get_meta("book_visibility_owner") if borrowed.has_meta("book_visibility_owner") else null
			if owner_ref != null and owner_ref.get_ref() == self:
				borrowed.visible = bool(stowed_role_equipment.visible)
				borrowed.remove_meta("book_visibility_owner")
		stowed_role_equipment.clear()
		return
	if not stowed_role_equipment.is_empty() or not is_instance_valid(actor): return
	var borrowed := actor.find_child("CastleRoleEquipment", true, false) as Node3D
	if borrowed == null or borrowed.find_child("VarganRecordBook", true, false) == null: return
	var owner_ref: WeakRef = borrowed.get_meta("book_visibility_owner") if borrowed.has_meta("book_visibility_owner") else null
	if owner_ref != null and is_instance_valid(owner_ref.get_ref()): return
	stowed_role_equipment = {"node":weakref(borrowed),"visible":borrowed.visible}
	borrowed.set_meta("book_visibility_owner",weakref(self))
	borrowed.visible = false

func _release_tool() -> void:
	_set_role_book_stowed(false)
	if is_instance_valid(tool):
		tool.visible = false
		# Authored occupation equipment belongs to the character. Only the
		# generated sibling socket belongs to this short-lived modifier.
		if owns_tool and not tool.is_queued_for_deletion():
			tool.queue_free()
	tool = null
	tool_contact = null
	tool_contact_local = Vector3.ZERO
	tool_contact_points.clear()
	tool_kind = ""
	tool_uses_measured_grip = true
	owns_tool = false

func _exit_tree() -> void:
	_release_tool()

func _contact_socket_offset(contact: Node3D) -> Vector3:
	return _contact_socket_frame(contact).origin

func _contact_socket_frame(contact: Node3D) -> Transform3D:
	var local := Transform3D.IDENTITY
	var cursor := contact
	while is_instance_valid(cursor) and not cursor is BoneAttachment3D:
		local = cursor.transform * local
		cursor = cursor.get_parent() as Node3D
	return local if cursor is BoneAttachment3D else Transform3D.IDENTITY

func _pose_supported_sleep(skeleton: Skeleton3D) -> void:
	# The routine owner supplies a verified furniture anchor. Offset the pose
	# onto its real seat while the movement root remains at its safe approach.
	# Without that evidence this modifier never invents a seated pose.
	if rest_anchor.is_empty() or pelvis < 0:
		return
	var seat: Vector3 = rest_anchor.get("seat", Vector3.INF)
	var stand: Vector3 = rest_anchor.get("stand", Vector3.INF)
	if not seat.is_finite() or not stand.is_finite() or actor.global_position.distance_squared_to(stand) > 0.16:
		return
	var forward: Vector3 = driver.get_visible_forward()
	var right := forward.cross(Vector3.UP).normalized()
	var parent := skeleton.get_bone_parent(pelvis)
	var frame := skeleton.global_basis * (skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY)
	var offset := seat + Vector3.UP * 0.12 - _world(skeleton, pelvis)
	if offset.length() > 1.0:
		return
	skeleton.set_bone_pose_position(pelvis, skeleton.get_bone_pose_position(pelvis) + frame.inverse() * offset * pose_weight)
	for leg: Dictionary in seated_legs:
		if int(leg.foot) < 0: continue
		var foot_goal := seat + forward * 0.42 + right * float(leg.side) * 0.12
		foot_goal.y = stand.y + 0.095
		var chain := {"upper":leg.thigh, "lower":leg.calf, "hand":leg.foot, "side":leg.side}
		var sole_basis := (skeleton.global_basis * skeleton.get_bone_global_pose(int(leg.foot)).basis).orthonormalized()
		_solve_arm(skeleton, chain, _world(skeleton, int(leg.foot)).lerp(foot_goal, pose_weight), sole_basis, forward)
	if spine >= 0:
		skeleton.set_bone_pose_rotation(spine, skeleton.get_bone_pose_rotation(spine) * Quaternion(Vector3.RIGHT, 0.08 * pose_weight))

func _ambient_pose(skeleton: Skeleton3D, delta: float, near: bool, effective: String, native_pose: bool = false) -> void:
	if native_pose:
		ambient_weight = 0.0
		return
	var resting := humanoid and creature_id == "" and near and float(driver.current_speed_mps) < 0.08 and not bool(driver.story_dialogue_active)
	# Workstation hands and feet retain their anchors; sway is idle-only. Bone
	# modifiers compose over each graph pose, never accumulate on the last pose.
	ambient_weight = move_toward(ambient_weight, 1.0 if resting else 0.0, delta * 3.0)
	if ambient_weight <= 0.001 or spine < 0:
		return
	var amplitude := 0.007 if effective == "sleep" else 0.015
	var breath := sin(elapsed * TAU * 0.22) * amplitude * ambient_weight
	# Scale on the spine propagates into the hand sockets and stretches rigid
	# bowls/books. A restrained rib-cage turn preserves every prop's dimensions.
	skeleton.set_bone_pose_rotation(spine, skeleton.get_bone_pose_rotation(spine) * Quaternion(Vector3.RIGHT, breath * 0.35))
	if elapsed >= next_shift:
		next_shift = elapsed + idle_rng.randf_range(6.0, 10.0)
		shift_target = idle_rng.randf_range(-0.014, 0.014)
	shift_rotation = lerpf(shift_rotation, shift_target, 1.0 - exp(-1.7 * delta))
	if effective in ["", "rest", "idle", "watch", "lookout", "remember"]:
		skeleton.set_bone_pose_rotation(spine, skeleton.get_bone_pose_rotation(spine) * Quaternion(Vector3.FORWARD, shift_rotation * ambient_weight))

func _creature_pose(skeleton: Skeleton3D) -> void:
	var recovery := creature_intent == "recovery"
	if authored_creature_ambient and not recovery and (str(driver.presentation_state) == "ecology" or (str(driver.presentation_state).is_empty() and float(driver.current_speed_mps) <= 0.08)):
		return
	var lean := 0.0
	var tilt := 0.0
	match creature_id:
		"reed_choir":
			lean = 0.0 if creature_intent == "attentive" else sin(elapsed*1.8)*0.045
			tilt = sin(elapsed*0.38)*0.035
		"glassmoth":
			lean = -0.08 if creature_intent == "feeding" else 0.025
			tilt = sin(elapsed*0.7)*0.09
			for index in wings.size():
				var bone := wings[index]
				var fold := sin(elapsed*2.2)*0.08*(-1.0 if index==0 else 1.0)*creature_weight
				skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone)*Quaternion(Vector3.FORWARD,fold))
		"gallows_weaver":
			lean = sin(elapsed*1.4)*0.035 if creature_intent == "feeding" else 0.025
			tilt = sin(elapsed*0.4)*0.04
		"shroud_swimmer":
			lean = sin(elapsed*0.8)*0.04
			tilt = sin(elapsed*0.55)*0.075
		"inkblind":
			lean = 0.08 if creature_intent == "feeding" else 0.02
			tilt = sin(elapsed*1.7)*0.055
		"cairn_mother":
			lean = -0.015
			tilt = sin(elapsed*0.25)*0.045
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

func _staff_pose(skeleton: Skeleton3D, delta: float, effective: String) -> void:
	if not is_instance_valid(staff_equipment):
		staff_equipment = actor.find_child("AnwenStaffEquipment", true, false) as Node3D
	if not is_instance_valid(staff_equipment):
		return
	var holding := effective in ["", "idle", "watch", "lookout", "remember", "rest", "care", "eat", "seated_eat", "carry"]
	staff_weight = move_toward(staff_weight, 1.0 if holding else 0.0, delta * 5.0)
	staff_equipment.visible = holding
	if not holding:
		staff_planted = false
		return
	var forward: Vector3 = driver.get_visible_forward()
	var right := forward.cross(Vector3.UP).normalized()
	var scale := actor.global_basis.get_scale().y
	var moving := float(driver.current_speed_mps) > 0.08
	var phase := fposmod(float(driver.animation_graph.gait_phase), 1.0) if driver.animation_graph != null else 0.0
	var desired_tip := actor.global_position + right * 0.36 * scale + forward * (0.16 if moving else 0.05) * scale
	if not moving:
		staff_tip = desired_tip
		staff_planted = false
	elif phase < 0.55:
		if not staff_planted or staff_tip.distance_to(desired_tip) > scale:
			staff_tip = desired_tip
		staff_planted = true
	else:
		var swing := (phase - 0.55) / 0.45
		staff_tip = staff_tip.lerp(desired_tip, minf(1.0, delta * 12.0))
		staff_planted = false
	var lift := sin((phase - 0.55) / 0.45 * PI) * 0.07 * scale if moving and phase >= 0.55 else 0.0
	# The shaft crosses the curled palm, perpendicular to the finger axes.
	var wrist := Basis(-Vector3.UP, forward, (-Vector3.UP).cross(forward)).orthonormalized()
	var grip := staff_tip + Vector3.UP * (0.93 * scale + lift)
	var goal := grip - wrist * Vector3(0, 0.045, -0.012) * scale
	for arm: Dictionary in arms:
		if float(arm.side) > 0:
			_solve_arm(skeleton, arm, _world(skeleton, int(arm.hand)).lerp(goal, staff_weight), wrist, Vector3.ZERO, staff_weight)
	if not bool(driver.story_dialogue_active):
		for finger: String in ["index", "middle", "ring", "pinky"]:
			for joint: String in ["01", "02", "03"]:
				var bone := skeleton.find_bone("%s_%s_r" % [finger, joint])
				if bone >= 0:
					var relaxed := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, 0.12)
					skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone).slerp(relaxed, staff_weight))

func _solve_arm(skeleton: Skeleton3D, arm: Dictionary, goal: Vector3, wrist_target: Variant = null, elbow_direction: Vector3 = Vector3.ZERO, wrist_weight: float = -1.0) -> void:
	solved_wrist_goal = Vector3.INF
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
		skeleton.set_bone_pose_rotation(int(arm.hand), skeleton.get_bone_pose_rotation(int(arm.hand)).slerp(desired, pose_weight if wrist_weight < 0 else wrist_weight))
	solved_wrist_goal = goal
