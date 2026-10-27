extends SkeletonModifier3D

## Bounded visual-only leg reach. Collision, movement and authored airborne
## poses remain authoritative. Supported surfaces use the existing contract.
var actor: Node3D
var motion_driver: Node
var viewer: Node3D
var proximity_clock := 0.0
var nearby := true
var excluded_bodies: Array[RID] = []
var legs: Array[Dictionary] = []
var sample_clock := 0.0
var last_actor_position := Vector3.INF
var seated_idle := false

static func install_npc(body: Node3D, driver: Node) -> void:
	var skeleton: Skeleton3D = driver.get_skeleton()
	if skeleton == null or skeleton.get_node_or_null("GroundedFeet") != null: return
	# Only compatible humanoids receive this solver. Animal and other authored
	# rigs keep their own anatomy; seated actors opt out at their spawn site.
	for bone: String in ["thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r"]:
		if skeleton.find_bone(bone) < 0: return
	var modifier: SkeletonModifier3D = load("res://scripts/grounded_feet_modifier.gd").new()
	modifier.name = "GroundedFeet"
	skeleton.add_child(modifier)
	modifier.call("configure", body, skeleton, driver)

func configure(body: Node3D, skeleton: Skeleton3D, driver: Node = null) -> void:
	actor = body
	motion_driver = driver if driver != null else body.find_child("CharacterAnimationDriver", true, false)
	seated_idle = is_instance_valid(motion_driver) and str(motion_driver.get_clip_for_state("idle")).to_lower().contains("sitting")
	legs.clear()
	excluded_bodies.clear()
	var ancestor: Node = body
	while ancestor != null:
		if ancestor is CollisionObject3D:
			excluded_bodies.append(ancestor.get_rid())
		ancestor = ancestor.get_parent()
	for side: String in ["l", "r"]:
		var hip := skeleton.find_bone("thigh_" + side)
		var knee := skeleton.find_bone("calf_" + side)
		var foot := skeleton.find_bone("foot_" + side)
		if hip >= 0 and knee >= 0 and foot >= 0:
			legs.append({"hip":hip, "knee":knee, "foot":foot, "offset":0.0, "wanted":0.0, "normal":Vector3.UP, "wanted_normal":Vector3.UP, "plant":0.0})

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not is_instance_valid(actor): return
	var delta := minf(get_process_delta_time(), 0.05)
	if last_actor_position == Vector3.INF or actor.global_position.distance_squared_to(last_actor_position) > 2.25:
		sample_clock = 0.0
		for leg: Dictionary in legs:
			leg.offset = 0.0
			leg.wanted = 0.0
			leg.normal = Vector3.UP
			leg.wanted_normal = Vector3.UP
	last_actor_position = actor.global_position
	var physical_actor := actor as CharacterBody3D
	if physical_actor == null:
		proximity_clock -= delta
		if proximity_clock <= 0.0:
			proximity_clock = 0.5
			if not is_instance_valid(viewer):
				viewer = get_tree().get_first_node_in_group("player") as Node3D
			nearby = is_instance_valid(viewer) and actor.global_position.distance_squared_to(viewer.global_position) < 144.0
	var supported: bool = physical_actor.is_on_floor() if physical_actor != null else true
	var can_plant: bool = supported and nearby and actor.is_visible_in_tree() and not seated_idle
	if is_instance_valid(motion_driver):
		can_plant = can_plant and bool(motion_driver.get("grounded")) and not bool(motion_driver.get("distance_suspended")) and not bool(motion_driver.get("dead")) and not motion_driver.has_active_action()
		can_plant = can_plant and str(motion_driver.presentation_state) != "life:sit"
	sample_clock -= delta
	var sample := sample_clock <= 0.0
	if sample: sample_clock = 1.0 / (30.0 if physical_actor != null else 20.0)
	for leg: Dictionary in legs:
		var foot := world_position(skeleton, int(leg.foot))
		if not can_plant:
			leg.wanted = 0.0
			leg.offset = 0.0
			leg.normal = Vector3.UP
			leg.wanted_normal = Vector3.UP
			leg.plant = 0.0
			continue
		elif sample:
			var hit: Dictionary = SpatialSurfaceContract.support_hit(actor.get_world_3d().direct_space_state, foot + Vector3.UP * 0.34, foot - Vector3.UP * 0.50, excluded_bodies)
			leg.wanted = 0.0
			leg.wanted_normal = Vector3.UP
			leg.plant = 0.0
			if not hit.is_empty():
				var sole_height := 0.095
				var clearance: float = foot.y - float(hit.position.y) - sole_height
				# Terrain clearance is not animation lift: using it as the plant
				# test disabled downward reach precisely where the ground fell away.
				var lift: float = maxf(0.0, foot.y - actor.global_position.y - sole_height)
				var moving: bool = is_instance_valid(motion_driver) and float(motion_driver.current_speed_mps) > 0.08
				leg.plant = 1.0 - smoothstep(0.045, 0.18, lift) if moving else 1.0
				leg.wanted = clampf(-clearance, -0.20, 0.20) * float(leg.plant)
				leg.wanted_normal = (hit.normal as Vector3).normalized()
		leg.offset = lerpf(float(leg.offset), float(leg.wanted), 1.0 - exp(-18.0 * delta))
		leg.normal = (leg.normal as Vector3).slerp(leg.wanted_normal, 1.0 - exp(-12.0 * delta)).normalized()
		if absf(float(leg.offset)) < 0.001 and (leg.normal as Vector3).dot(Vector3.UP) > 0.9999: continue
		var hip := world_position(skeleton, int(leg.hip))
		var knee := world_position(skeleton, int(leg.knee))
		var goal := foot + Vector3.UP * float(leg.offset)
		var upper := hip.distance_to(knee)
		var lower := knee.distance_to(foot)
		if upper < 0.03 or lower < 0.03: continue
		var axis := (goal - hip).normalized()
		var reach := clampf(hip.distance_to(goal), absf(upper - lower) + 0.005, upper + lower - 0.005)
		goal = hip + axis * reach
		var along := (upper * upper + reach * reach - lower * lower) / (2.0 * reach)
		var bend := knee - hip - axis * (knee - hip).dot(axis)
		if bend.length_squared() < 0.00001:
			bend = -actor.global_basis.z
			bend -= axis * bend.dot(axis)
		if bend.length_squared() < 0.00001: continue
		var desired_knee := hip + axis * along + bend.normalized() * sqrt(maxf(upper * upper - along * along, 0.0))
		_solve_leg(skeleton, leg, hip, knee, foot, desired_knee, goal)

func world_position(skeleton: Skeleton3D, bone: int) -> Vector3:
	return (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin

func _parent_basis(skeleton: Skeleton3D, bone: int) -> Basis:
	var parent := skeleton.get_bone_parent(bone)
	return skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY

func _solve_leg(skeleton: Skeleton3D, leg: Dictionary, hip: Vector3, knee: Vector3, foot: Vector3, desired_knee: Vector3, goal: Vector3) -> void:
	# One pose snapshot and analytic parent propagation avoid four full-rig
	# refreshes per actor. The ankle retains authored yaw and receives slope tilt.
	var frame := skeleton.global_basis.orthonormalized()
	var hip_parent := _parent_basis(skeleton, int(leg.hip))
	var knee_parent := _parent_basis(skeleton, int(leg.knee))
	var foot_parent := _parent_basis(skeleton, int(leg.foot))
	var hip_basis := skeleton.get_bone_global_pose(int(leg.hip)).basis.orthonormalized()
	var knee_basis := skeleton.get_bone_global_pose(int(leg.knee)).basis.orthonormalized()
	var foot_basis := skeleton.get_bone_global_pose(int(leg.foot)).basis.orthonormalized()
	var upper_turn := Basis(Quaternion((knee - hip).normalized(), (desired_knee - hip).normalized()))
	var local_turn := frame.inverse() * upper_turn * frame
	var moved_knee := hip + upper_turn * (knee - hip)
	var moved_foot := hip + upper_turn * (foot - hip)
	if moved_foot.distance_squared_to(moved_knee) < 0.00001 or goal.distance_squared_to(moved_knee) < 0.00001:
		return
	var lower_turn := frame.inverse() * Basis(Quaternion((moved_foot - moved_knee).normalized(), (goal - moved_knee).normalized())) * frame
	var normal: Vector3 = leg.normal
	var slope := acos(clampf(normal.dot(Vector3.UP), -1.0, 1.0))
	var tilt_weight := minf(1.0, deg_to_rad(28.0) / maxf(slope, 0.001)) * float(leg.plant)
	var tilt := Basis(Quaternion.IDENTITY.slerp(Quaternion(Vector3.UP, normal), tilt_weight))
	var ankle := (lower_turn * local_turn * foot_parent).inverse() * frame.inverse() * tilt * frame * foot_basis
	skeleton.set_bone_pose_rotation(int(leg.hip), (hip_parent.inverse() * local_turn * hip_basis).orthonormalized().get_rotation_quaternion())
	skeleton.set_bone_pose_rotation(int(leg.knee), ((local_turn * knee_parent).inverse() * lower_turn * local_turn * knee_basis).orthonormalized().get_rotation_quaternion())
	skeleton.set_bone_pose_rotation(int(leg.foot), ankle.orthonormalized().get_rotation_quaternion())
