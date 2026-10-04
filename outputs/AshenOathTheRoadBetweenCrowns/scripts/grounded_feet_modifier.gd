extends SkeletonModifier3D

## Bounded visual-only leg reach. Collision, movement and authored airborne
## poses remain authoritative. Supported surfaces use the existing contract.
var actor: CharacterBody3D
var legs: Array[Dictionary] = []
var sample_clock := 0.0

func configure(body: CharacterBody3D, skeleton: Skeleton3D) -> void:
	actor = body
	for side: String in ["l", "r"]:
		var hip := skeleton.find_bone("thigh_" + side)
		var knee := skeleton.find_bone("calf_" + side)
		var foot := skeleton.find_bone("foot_" + side)
		if hip >= 0 and knee >= 0 and foot >= 0:
			legs.append({"hip":hip, "knee":knee, "foot":foot, "offset":0.0, "wanted":0.0})

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not is_instance_valid(actor): return
	var driver: Node = actor.get("animation_driver") as Node
	var can_plant: bool = actor.is_on_floor() and (driver == null or not bool(driver.call("has_active_action")))
	var delta := minf(get_process_delta_time(), 0.05)
	sample_clock -= delta
	var sample := sample_clock <= 0.0
	if sample: sample_clock = 1.0 / 30.0
	for leg: Dictionary in legs:
		var foot := world_position(skeleton, int(leg.foot))
		if not can_plant:
			leg.wanted = 0.0
			leg.offset = 0.0
			continue
		elif sample:
			var excluded: Array[RID] = [actor.get_rid()]
			var hit: Dictionary = SpatialSurfaceContract.support_hit(actor.get_world_3d().direct_space_state, foot + Vector3.UP * 0.30, foot - Vector3.UP * 0.48, excluded)
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
