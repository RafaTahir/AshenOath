extends RefCounted
## Fitted travelling clothes share the body skin and skeleton. Alternate motion
## clips are bound before the existing driver builds its blend graph.

const GEAR_ROOT := "res://assets/characters/"
const BODIES := {
	"wychwood_raider": "M19_Connected_Anatomy_SkinnedAssembly",
	"wychwood_brute": "M20_Connected_Anatomy_SkinnedAssembly"
}

class ShieldLift extends SkeletonModifier3D:
	var bearer: CharacterBody3D
	var shoulder := -1
	var elbow := -1
	var shoulder_rest: Basis
	var elbow_rest: Basis
	var raised := 0.0

	func configure(actor: CharacterBody3D, rig: Skeleton3D) -> void:
		bearer = actor
		shoulder = rig.find_bone("upperarm_l")
		elbow = rig.find_bone("lowerarm_l")
		shoulder_rest = rig.get_bone_global_rest(shoulder).basis.orthonormalized()
		elbow_rest = rig.get_bone_global_rest(elbow).basis.orthonormalized()

	func _process_modification_with_delta(delta: float) -> void:
		if not is_instance_valid(bearer):
			return
		var rig := get_skeleton()
		if rig == null or not is_instance_valid(bearer.animation_driver): return
		if bearer.dead or not bearer.encounter_active or bearer.animation_driver.current_state not in ["idle","walk","run","strafe","walk_back","strafe_left","strafe_right","run_back"]:
			raised = 0.0
			return
		var goal := 1.0 if bearer.wood_guard_raised() else 0.0
		raised = move_toward(raised, goal, absf(delta) * 10.0)
		if raised <= .001: return
		# Left arm points along +X in bind space. The gate board faces +Z.
		# Keep the boss-facing plane convex and the wrist above the bent elbow.
		turn_arm(rig,shoulder,shoulder_rest,Vector3(.43,-.68,.59),Vector3(.25,.31,.91))
		turn_arm(rig,elbow,elbow_rest,Vector3(-.47,.76,.44),Vector3(.24,-.11,.96))

	func turn_arm(rig: Skeleton3D, bone: int, rest: Basis, along: Vector3, front: Vector3) -> void:
		var x := along.normalized()
		var z := (front - x * x.dot(front)).normalized()
		var parent := rig.get_bone_global_pose(rig.get_bone_parent(bone)).basis.orthonormalized()
		var desired := (parent.inverse() * Basis(x, z.cross(x), z) * rest).get_rotation_quaternion()
		rig.set_bone_pose_rotation(bone,rig.get_bone_pose_rotation(bone).slerp(desired,raised))

static func install(actor: CharacterBody3D, mapped: Node3D) -> bool:
	var id := str(actor.enemy_id)
	if not BODIES.has(id): return false
	var body := mapped.find_child(BODIES[id],true,false) as MeshInstance3D
	if body == null or body.skin == null or body.has_node("RoadWardrobe"): return false
	var rig := body.get_node_or_null(body.skeleton) as Skeleton3D
	var players := mapped.find_children("*","AnimationPlayer",true,false)
	if rig == null or players.is_empty(): return false
	var player := players[0] as AnimationPlayer
	var wardrobe := ResourceLoader.load(GEAR_ROOT + id + "_regalia.res") as ArrayMesh
	var motions := ResourceLoader.load(GEAR_ROOT + id + "_motion.res") as AnimationLibrary
	if wardrobe == null or motions == null or not player.has_animation_library(""): return false
	var original := player.get_animation_library("")
	var local := AnimationLibrary.new()
	for clip: StringName in original.get_animation_list():
		var animation := motions.get_animation(clip) if motions.has_animation(clip) else original.get_animation(clip)
		local.add_animation(clip,animation)
	player.remove_animation_library("")
	player.add_animation_library("",local)
	var gear := MeshInstance3D.new()
	gear.name = "RoadWardrobe"
	gear.mesh = wardrobe
	gear.skin = body.skin
	body.add_child(gear)
	gear.skeleton = gear.get_path_to(rig)
	if id == "wychwood_raider":
		var guard := ShieldLift.new()
		guard.name = "RoadWardGuardPose"
		guard.configure(actor,rig)
		rig.add_child(guard)
	return true
