extends SceneTree

## Production animation baker. Converts the local CC0 source into the current
## rig's rest basis; no game scene, playback review or verification is run.
const SOURCE := "res://assets_external/characters/Adventurer_PolyPizza_Quaternius_CC0.glb"
const TARGET := "res://assets_external/characters_universal/Male_Peasant.gltf"
const LIBRARY := "res://assets_external/animations/AnimationLibrary_Godot_Opening.tres"
const BONES := {"pelvis":"Hips", "spine_01":"Abdomen", "spine_02":"Torso", "spine_03":"Chest", "neck_01":"Neck", "Head":"Head", "clavicle_l":"Shoulder.L", "upperarm_l":"UpperArm.L", "lowerarm_l":"LowerArm.L", "hand_l":"Wrist.L", "clavicle_r":"Shoulder.R", "upperarm_r":"UpperArm.R", "lowerarm_r":"LowerArm.R", "hand_r":"Wrist.R", "thigh_l":"UpperLeg.L", "calf_l":"LowerLeg.L", "foot_l":"Foot.L", "thigh_r":"UpperLeg.R", "calf_r":"LowerLeg.R", "foot_r":"Foot.R"}

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var source := (load(SOURCE) as PackedScene).instantiate()
	var target := (load(TARGET) as PackedScene).instantiate()
	root.add_child(source)
	root.add_child(target)
	var source_skeleton := source.find_child("Skeleton3D", true, false) as Skeleton3D
	var target_skeleton := target.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if source_skeleton == null or target_skeleton == null or player == null:
		push_error("Directional asset build needs both source and target skeletons.")
		quit(1)
		return
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library := load(LIBRARY) as AnimationLibrary
	var source_basis := source_skeleton.global_basis.orthonormalized()
	var target_basis := target_skeleton.global_basis.orthonormalized()
	var pairs: Dictionary = {}
	for target_name: String in BONES:
		var target_bone := target_skeleton.find_bone(target_name)
		var source_bone := source_skeleton.find_bone(str(BONES[target_name]))
		if source_bone < 0 or target_bone < 0:
			push_error("Missing required retarget bone: " + target_name)
			quit(1)
			return
		pairs[target_bone] = source_bone
	for clip: Array in [["Run_Back", "Directional_WalkBack", 1.65], ["Run_Left", "Directional_RunLeft", 2.2], ["Run_Right", "Directional_RunRight", 2.2]]:
		var source_name := StringName()
		for candidate: StringName in player.get_animation_list():
			if str(candidate).ends_with("|" + str(clip[0])) or str(candidate) == str(clip[0]):
				source_name = candidate
				break
		if source_name == StringName():
			push_error("Missing directional source: " + str(clip[0]))
			quit(1)
			return
		var animation := Animation.new()
		animation.length = player.get_animation(source_name).length
		animation.loop_mode = Animation.LOOP_LINEAR
		animation.set_meta("universal_rest_baked", true)
		animation.set_meta("cycle_distance_m", float(clip[2]))
		animation.set_meta("source_attribution", "Quaternius / Poly Pizza Adventurer, CC0; rest-pose retarget for Ashen Oath")
		var tracks: Dictionary = {}
		for target_bone: int in pairs:
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, NodePath("Armature/Skeleton3D:" + target_skeleton.get_bone_name(target_bone)))
			tracks[target_bone] = track
		player.play(source_name)
		var frames := int(ceil(animation.length * 30.0))
		for frame: int in range(frames + 1):
			var time := minf(float(frame) / 30.0, animation.length)
			player.seek(time if frame < frames else 0.0, true)
			player.advance(0.0)
			source_skeleton.force_update_all_bone_transforms()
			var world_rotations: Dictionary = {}
			# Parent-first skeleton order retains target lengths and unmapped bones.
			for bone: int in range(target_skeleton.get_bone_count()):
				var parent := target_skeleton.get_bone_parent(bone)
				var parent_basis: Basis = world_rotations.get(parent, Basis.IDENTITY)
				var rest := target_skeleton.get_bone_rest(bone)
				var global_basis: Basis = parent_basis * rest.basis.orthonormalized()
				if pairs.has(bone):
					var source_bone: int = int(pairs[bone])
					var source_rest := source_skeleton.get_bone_global_rest(source_bone).basis.orthonormalized()
					var source_pose := source_skeleton.get_bone_global_pose(source_bone).basis.orthonormalized()
					var world_delta := source_basis * source_pose * source_rest.inverse() * source_basis.inverse()
					global_basis = target_basis.inverse() * world_delta * target_basis * target_skeleton.get_bone_global_rest(bone).basis.orthonormalized()
					var local_rotation := (parent_basis.inverse() * global_basis).orthonormalized().get_rotation_quaternion().normalized()
					animation.rotation_track_insert_key(int(tracks[bone]), time, local_rotation)
				world_rotations[bone] = global_basis
		var output_name := StringName(str(clip[1]))
		if library.has_animation(output_name):
			library.remove_animation(output_name)
		library.add_animation(output_name, animation)
		print("Baked ", output_name, " from ", source_name)
	var result := ResourceSaver.save(library, LIBRARY)
	source.free()
	target.free()
	quit(0 if result == OK else 1)
