extends RefCounted

## A hurt Rook still runs his own errands. The ordinary route owner counts
## completed steps and offers a short standing rest at a safe destination.
const INJURY := &"novel_rook_ribs"
const HEALED := &"novel_rook_healed"
const LAUGH := "story_rook_laugh"
const LAUGH_SECONDS := 1.4
const REST := "rook_catch_breath"
const WALK_SCALE := 0.68
const REST_AFTER_METRES := 2.5
const REST_SECONDS := 2.4

static func injured(entry: Dictionary) -> bool:
	return bool(entry.get("named", false)) and entry.driver.get("novel_injury") == INJURY

static func record_step(entry: Dictionary, start: Vector3) -> void:
	var covered: Vector3 = entry.node.global_position - start
	covered.y = 0.0
	entry.rib_walk_metres = minf(REST_AFTER_METRES, float(entry.get("rib_walk_metres", 0.0)) + covered.length())

static func _next_activity(entry: Dictionary) -> String:
	var tasks: Array = entry.profile.get("activities", [])
	return str(entry.profile.get("activity", "")) if tasks.is_empty() else str(tasks[mini(int(entry.target), tasks.size()-1)])

static func reconcile(owner: Node, entry: Dictionary, active: bool) -> void:
	if not entry.has("rib_breath_left") and not entry.has("rib_walk_metres"):
		return
	var driver = entry.driver
	if not active or driver.dead or driver.distance_suspended:
		cancel(entry)
		return
	if not entry.has("rib_breath_left"):
		return
	var blocked: bool = owner.Presence.protected(entry.node) or not entry.node.is_visible_in_tree() or str(owner.read_tag(entry.node, "locomotion_owner", "")) not in ["", "greyfen_life"]
	if blocked or driver.story_dialogue_active or driver.has_active_action() or not entry.pending_routine.is_empty() or owner.get_tree().paused \
			or float(entry.get("social_time", 0.0)) > 0.0 or float(entry.get("reaction_time", 0.0)) > 0.0 or float(entry.get("greeting_remaining", 0.0)) > 0.0 \
			or driver.presentation_state != "life:" + REST or bool(owner.read_tag(entry.node, "bell_eater_evacuated", false)):
		cancel(entry)

static func cancel(entry: Dictionary) -> void:
	entry.erase("rib_walk_metres")
	entry.erase("rib_breath_left")
	if is_instance_valid(entry.driver) and entry.driver.presentation_state == "life:" + REST and not entry.driver.dead and not entry.driver.story_dialogue_active and not entry.driver.has_active_action():
		entry.driver.clear_life_activity()

static func pause_at_arrival(entry: Dictionary, delta: float) -> bool:
	if entry.has("rib_breath_left"):
		entry.rib_breath_left = float(entry.rib_breath_left) - delta
		if float(entry.rib_breath_left) > 0.0:
			return true
		cancel(entry)
		return false
	if float(entry.get("rib_walk_metres", 0.0)) < REST_AFTER_METRES or int(entry.route_index) + 1 != entry.route.size():
		return false
	var driver = entry.driver
	if _next_activity(entry) in ["sleep", "shelter", "fear"] or driver.has_active_action() or driver.story_dialogue_active or driver.distance_suspended:
		return false
	driver.set_life_activity(REST)
	if driver.presentation_state != "life:" + REST:
		return false
	entry.rib_walk_metres = 0.0
	entry.rib_breath_left = REST_SECONDS
	return true

## EverydayLife supplies a unique scene id for the optional joke. Only Rook's
## reply takes this gesture; the question and ordinary greetings retain theirs.
static func try_laugh(driver: Node, scene_id: String, speaking: bool) -> bool:
	if not speaking or not scene_id.begins_with("everyday:rook:joke:") or driver.novel_injury != HEALED:
		return false
	if not driver.story_dialogue_active or driver.dead or driver.distance_suspended or driver.has_active_action():
		return false
	var base: StringName = driver._clip_for("idle")
	if base == &"": return false
	driver._ensure_life_modifier()
	driver.resolved_clip_map[LAUGH] = base
	if not driver.trigger_action(LAUGH, 1.0, 0.14, false, LAUGH_SECONDS): return false
	driver.story_gesture_remaining = LAUGH_SECONDS
	return true

static func release_obsolete_pose(driver: Node) -> void:
	if driver.dead: return
	if driver.current_state == LAUGH:
		driver.story_gesture_remaining = 0.0
		driver.stop_action()
	elif driver.presentation_state == "life:" + REST and not driver.story_dialogue_active and not driver.has_active_action():
		driver.clear_life_activity()

static func apply_pose(life: Node, skeleton: Skeleton3D) -> void:
	var driver = life.driver
	if driver.dead or driver.distance_suspended or life.get_tree().paused or life.spine < 0 or life.pelvis < 0:
		return
	var weight: float
	var rise: float
	var laughing: bool = driver.novel_injury == HEALED
	if laughing:
		if not driver.story_dialogue_active or driver.current_state != LAUGH or not driver.has_active_action(): return
		var phase := clampf(float(driver.action_elapsed) / LAUGH_SECONDS, 0.0, 1.0)
		weight = smoothstep(0.02, 0.26, phase) * (1.0 - smoothstep(0.64, 1.0, phase))
		# Short bursts of laughter tip the upper body forward, then subside.
		rise = 0.035 * pow(sin(phase * PI * 3.0), 2)
	else:
		if life.activity != REST or driver.novel_injury != INJURY or driver.story_dialogue_active or driver.has_active_action(): return
		weight = life.pose_weight
		rise = (0.5 + 0.5 * sin(float(life.elapsed) * 4.85)) * 0.014
	if weight <= 0.001: return
	var forward: Vector3 = driver.get_visible_forward().slide(Vector3.UP).normalized()
	if forward.is_zero_approx(): return
	var joint: int = life.spine
	var parent := skeleton.get_bone_parent(joint)
	var frame := skeleton.global_basis.orthonormalized()
	if parent >= 0:
		frame *= skeleton.get_bone_global_pose(parent).basis.orthonormalized()
	var local_axis := (frame.inverse() * Vector3.UP.cross(forward)).normalized()
	var bend := Quaternion(local_axis, deg_to_rad((2.5 + rise * 95.0) * weight))
	skeleton.set_bone_pose_rotation(joint, (bend * skeleton.get_bone_pose_rotation(joint)).normalized())
	var lower_ribs := skeleton.find_bone("spine_02")
	if lower_ribs < 0 or life.arms.size() != 2:
		return
	var lateral: Vector3 = (life._world(skeleton, int(life.arms[1].upper)) - life._world(skeleton, int(life.arms[0].upper))).slide(Vector3.UP).normalized()
	var front := Vector3.UP.cross(lateral)
	if front.dot(forward) < 0:
		front = -front
	var ribs: Vector3 = life._world(skeleton, lower_ribs)
	for arm: Dictionary in life.arms:
		var guarding := float(arm.side) < 0.0
		if laughing and not guarding: continue
		var suffix := "_l" if guarding else "_r"
		var index := skeleton.find_bone("index_01" + suffix)
		var middle := skeleton.find_bone("middle_01" + suffix)
		var little := skeleton.find_bone("pinky_01" + suffix)
		if mini(index, mini(middle, little)) < 0:
			continue
		var shoulder: Vector3 = life._world(skeleton, int(arm.upper))
		var elbow: Vector3 = life._world(skeleton, int(arm.lower))
		var hand: Vector3 = life._world(skeleton, int(arm.hand))
		var knuckle: Vector3 = life._world(skeleton, middle)
		var reach := shoulder.distance_to(elbow) + elbow.distance_to(hand)
		# The index-to-little line controls palm roll as well as the direction
		# of the fingers. Without it the wrist can meet the tunic palm-up.
		var along := hand.direction_to(knuckle)
		var width: Vector3 = (life._world(skeleton, index) - life._world(skeleton, little)).slide(along).normalized()
		var aim := (lateral + front * 0.30 + Vector3.UP * 0.22).normalized() if guarding else (Vector3.DOWN + front * 0.10).normalized()
		var spread := (Vector3.UP if guarding else front).slide(aim).normalized()
		var turn := Basis(aim, spread, aim.cross(spread)) * Basis(along, width, along.cross(width)).transposed()
		var wrist := turn * (skeleton.global_basis * skeleton.get_bone_global_pose(int(arm.hand)).basis).orthonormalized()
		var target: Vector3
		var pole: Vector3
		if guarding:
			# Seat the centre of the palm on the front-left tunic. The depth
			# and slope were sampled from Rook's evaluated lower rib section.
			var palm := ribs + (front * 0.35 - lateral * 0.18 + Vector3.UP * (0.035 + rise)) * reach
			target = palm - turn * (knuckle - hand) * 0.60
			pole = Vector3.DOWN - lateral * 0.42
		else:
			# Ease the free hand out of the underlying two-handed idle.
			target = shoulder + (Vector3.DOWN * 0.91 + lateral * 0.045 - front * 0.035) * reach
			pole = lateral * 0.40 - front
		life._solve_arm(skeleton, arm, hand.lerp(target, weight), wrist, pole, weight)
