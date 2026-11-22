extends SceneTree

const Fusion = preload("res://scripts/character_animation_fusion.gd")

func _initialize() -> void:
	call_deferred("run")

func make_rig(armature_name: String = "Armature") -> Node3D:
	var rig := Node3D.new()
	var armature := Node3D.new()
	armature.name = armature_name
	rig.add_child(armature)
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	skeleton.add_bone("pelvis")
	armature.add_child(skeleton)
	root.add_child(rig)
	return rig

func run() -> void:
	var source := AnimationLibrary.new()
	var clip := Animation.new()
	clip.length = 1.0
	var track := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(track, NodePath("Armature/Skeleton3D:DEF-hips"))
	clip.position_track_insert_key(track, 0.0, Vector3.ZERO)
	clip.position_track_insert_key(track, 1.0, Vector3(0.5, 0.0, 0.0))
	source.add_animation("Walk", clip)
	var cache: Dictionary = {}
	var first := make_rig()
	var second := make_rig()
	var alternate := make_rig("OtherArmature")
	var player_a := Fusion.attach_shared_library(first, source, cache)
	var player_b := Fusion.attach_shared_library(second, source, cache)
	var player_c := Fusion.attach_shared_library(alternate, source, cache)
	var passed := player_a.get_animation_library("") == player_b.get_animation_library("")
	passed = passed and player_a.get_animation_library("") != player_c.get_animation_library("")
	passed = passed and str(clip.track_get_path(0)).ends_with(":DEF-hips")
	for player in [player_a, player_b, player_c]:
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.play("Walk")
		player.advance(0.0)
	player_a.advance(0.6)
	player_b.advance(0.2)
	var skeleton_a := first.get_node("Armature/Skeleton3D") as Skeleton3D
	var skeleton_b := second.get_node("Armature/Skeleton3D") as Skeleton3D
	passed = passed and is_equal_approx(skeleton_a.get_bone_pose_position(0).x, 0.3)
	passed = passed and is_equal_approx(skeleton_b.get_bone_pose_position(0).x, 0.1)
	first.free()
	cache.clear()
	player_b.advance(0.2)
	passed = passed and is_equal_approx(skeleton_b.get_bone_pose_position(0).x, 0.2)
	second.free()
	alternate.free()
	await process_frame
	print("SHARED ANIMATION PLAYBACK: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
