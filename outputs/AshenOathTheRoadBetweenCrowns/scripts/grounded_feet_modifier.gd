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
			legs.append({"hip":hip, "knee":knee, "foot":foot, "offset":0.0, "wanted":0.0})

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not is_instance_valid(actor): return
	var delta := minf(get_process_delta_time(), 0.05)
	var physical_actor := actor as CharacterBody3D
	if physical_actor == null:
		proximity_clock -= delta
		if proximity_clock <= 0.0:
			proximity_clock = 0.5
			if not is_instance_valid(viewer):
				viewer = get_tree().get_first_node_in_group("player") as Node3D
			nearby = is_instance_valid(viewer) and actor.global_position.distance_squared_to(viewer.global_position) < 144.0
	var supported: bool = physical_actor.is_on_floor() if physical_actor != null else true
	var can_plant: bool = supported and nearby and actor.is_visible_in_tree()
	if is_instance_valid(motion_driver):
		can_plant = can_plant and bool(motion_driver.get("grounded")) and not bool(motion_driver.get("distance_suspended")) and not bool(motion_driver.get("dead")) and not motion_driver.has_active_action()
	sample_clock -= delta
	var sample := sample_clock <= 0.0
	if sample: sample_clock = 1.0 / (30.0 if physical_actor != null else 20.0)
	for leg: Dictionary in legs:
		var foot := world_position(skeleton, int(leg.foot))
		if not can_plant:
			leg.wanted = 0.0
			leg.offset = 0.0
			continue
		elif sample:
			var hit: Dictionary = SpatialSurfaceContract.support_hit(actor.get_world_3d().direct_space_state, foot + Vector3.UP * 0.30, foot - Vector3.UP * 0.48, excluded_bodies)
			leg.wanted = 0.0
			if not hit.is_empty():
				var sole_height := 0.095
				var clearance: float = foot.y - float(hit.position.y) - sole_height
				# Lifted feet retain their swing; planted feet receive small reach
				# correction rather than snapping the entire rig to uneven ground.
				var plant_weight := 1.0 - smoothstep(0.045, 0.17, maxf(clearance, 0.0))
				leg.wanted = clampf(-clearance, -0.10, 0.14) * plant_weight * 0.72
		leg.offset = move_toward(float(leg.offset), float(leg.wanted), delta * 0.70)
		if absf(float(leg.offset)) < 0.001: continue
		var hip := world_position(skeleton, int(leg.hip))
		var knee := world_position(skeleton, int(leg.knee))
		var goal := foot + Vector3.UP * float(leg.offset)
		var upper := hip.distance_to(knee)
		var lower := knee.distance_to(foot)
		if upper < 0.03 or lower < 0.03: continue
		var axis := (goal - hip).normalized()
		var reach := clampf(hip.distance_to(goal), absf(upper - lower) + 0.005, upper + lower - 0.005)
		var along := (upper * upper + reach * reach - lower * lower) / (2.0 * reach)
		var bend := knee - hip - axis * (knee - hip).dot(axis)
		if bend.length_squared() < 0.00001:
			bend = -actor.global_basis.z
			bend -= axis * bend.dot(axis)
		if bend.length_squared() < 0.00001: continue
		var desired_knee := hip + axis * along + bend.normalized() * sqrt(maxf(upper * upper - along * along, 0.0))
		turn_bone(skeleton, int(leg.hip), knee - hip, desired_knee - hip)
		skeleton.force_update_all_bone_transforms()
		knee = world_position(skeleton, int(leg.knee))
		foot = world_position(skeleton, int(leg.foot))
		turn_bone(skeleton, int(leg.knee), foot - knee, goal - knee)
		skeleton.force_update_all_bone_transforms()

func world_position(skeleton: Skeleton3D, bone: int) -> Vector3:
	return (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin

func turn_bone(skeleton: Skeleton3D, bone: int, before: Vector3, after: Vector3) -> void:
	if before.length_squared() < 0.00001 or after.length_squared() < 0.00001: return
	var world_rotation := Basis(Quaternion(before.normalized(), after.normalized()))
	var skeleton_basis := skeleton.global_basis.orthonormalized()
	var pose := skeleton.get_bone_global_pose(bone).basis.orthonormalized()
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	var local := parent_basis.inverse() * skeleton_basis.inverse() * world_rotation * skeleton_basis * pose
	skeleton.set_bone_pose_rotation(bone, local.orthonormalized().get_rotation_quaternion().normalized())
