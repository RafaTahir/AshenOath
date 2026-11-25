extends RefCounted

const ROOT := "res://assets/characters/wychwood_hunters/"
const OUTFITS := {
	"ghoulkin": ["M01_Connected_Anatomy_SkinnedAssembly", "m01_shroud.res", "m01_motion.res", "BurialShroud"],
	"wychwood_stalker": ["Body_lod0", "m02_vanes.res", "m02_motion.res", "SplinterMantle"]
}

## The gait and Attack use the actor's existing AnimationPlayer clock. The visual
## shares the fitted body's skeleton, bind transforms, skin and culling bounds.
static func install(mapped: Node3D, enemy_id: String) -> bool:
	if not OUTFITS.has(enemy_id): return true
	var outfit: Array = OUTFITS[enemy_id]
	var body := mapped.find_child(outfit[0], true, false) as MeshInstance3D
	if body == null or body.skin == null: return false
	if body.get_parent().has_node(NodePath(outfit[3])): return true
	var rig := body.get_node_or_null(body.skeleton) as Skeleton3D
	var players := mapped.find_children("*", "AnimationPlayer", true, false)
	if rig == null or players.is_empty(): return false
	var player := players[0] as AnimationPlayer
	var mesh := load(ROOT + str(outfit[1])) as ArrayMesh
	var motion := load(ROOT + str(outfit[2])) as AnimationLibrary
	if mesh == null or motion == null or not player.has_animation_library(&""): return false
	var original := player.get_animation_library(&"")
	var local := AnimationLibrary.new()
	for clip_name: StringName in original.get_animation_list():
		var clip := motion.get_animation(clip_name) if motion.has_animation(clip_name) else original.get_animation(clip_name)
		local.add_animation(clip_name, clip)
	player.remove_animation_library(&"")
	player.add_animation_library(&"", local)
	var garment := MeshInstance3D.new()
	garment.name = outfit[3]
	garment.mesh = mesh
	garment.skin = body.skin
	garment.skeleton = body.skeleton
	garment.transform = body.transform
	body.get_parent().add_child(garment)
	if enemy_id == "wychwood_stalker":
		var modifier := ShoulderLoad.new()
		modifier.name = "HuntingShoulder"
		modifier.configure(mapped.get_parent().get_parent() as CharacterBody3D, body, rig)
		rig.add_child(modifier)
	return true

class ShoulderLoad extends SkeletonModifier3D:
	var actor: CharacterBody3D
	var joints := PackedInt32Array()
	var gathered: Array[Quaternion] = []
	var released: Array[Quaternion] = []
	var gather_weight := 0.0
	var rush_weight := 0.0

	func configure(host: CharacterBody3D, body: MeshInstance3D, skeleton_node: Skeleton3D) -> void:
		actor = host
		# In native model space +Z is the creature's nose. It loads the left foreleg,
		# turns its head into the run and pushes off that same shoulder on release.
		var offsets := {"Chest":[Vector3(13,-17,-14),Vector3(10,4,5)], "Neck":[Vector3(-14,20,7),Vector3(-9,-5,0)],
				"Arm1.L":[Vector3(-17,-12,22),Vector3(19,5,-11)], "Head":[Vector3(-6,8,3),Vector3(4,0,0)]}
		for i in body.skin.get_bind_count():
			var bone := body.skin.get_bind_name(i)
			if not offsets.has(bone): continue
			var basis := body.skin.get_bind_pose(i).basis.inverse().orthonormalized().get_rotation_quaternion()
			joints.append(skeleton_node.find_bone(bone))
			gathered.append(basis.inverse() * Quaternion.from_euler(offsets[bone][0] * PI / 180.0) * basis)
			released.append(basis.inverse() * Quaternion.from_euler(offsets[bone][1] * PI / 180.0) * basis)

	func _process_modification_with_delta(delta: float) -> void:
		if not is_instance_valid(actor) or actor.dead or not actor.encounter_active or actor.pending_attack_time > 0.0 or actor.stagger_time > 0.0:
			gather_weight = 0.0
			rush_weight = 0.0
			return
		var phase: StringName = actor.enemy_navigation_view.rush_phase()
		gather_weight = move_toward(gather_weight, 1.0 if phase == &"gather" else 0.0, maxf(delta, 0) * 16.0)
		rush_weight = move_toward(rush_weight, 1.0 if phase == &"rush" else 0.0, maxf(delta, 0) * 16.0)
		if gather_weight + rush_weight < 0.001: return
		var rig := get_skeleton()
		for i in joints.size():
			var pre := rig.get_bone_pose_rotation(joints[i])
			var load_pose := Quaternion.IDENTITY.slerp(gathered[i], gather_weight)
			var drive_pose := Quaternion.IDENTITY.slerp(released[i], rush_weight)
			rig.set_bone_pose_rotation(joints[i], (pre * load_pose * drive_pose).normalized())
