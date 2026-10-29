extends SceneTree

const Fusion = preload("res://scripts/character_animation_fusion.gd")
const Driver = preload("res://scripts/character_animation_driver.gd")

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
	passed = await _lifecycle_contract(source) and passed
	await process_frame
	print("SHARED ANIMATION PLAYBACK: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)

func _lifecycle_contract(library: AnimationLibrary) -> bool:
	var actor := make_rig()
	Fusion.attach_shared_library(actor, library)
	var driver := Driver.new()
	actor.add_child(driver)
	var passed := driver.configure(actor, {"idle":"Walk", "walk":"Walk", "run":"Walk"})
	if not passed:
		push_error("Animation lifecycle fixture could not configure: %s" % driver.get_contract_report())
		actor.free()
		return false
	driver.set_external_tick(true)
	driver.set_locomotion_motion(Vector3(1, 0, 0), true)
	driver.advance_external(0.2)
	var bone: Transform3D = driver.skeleton.get_bone_pose(0)
	driver.advance_external(0.2)
	passed = passed and not bone.is_equal_approx(driver.skeleton.get_bone_pose(0))
	passed = passed and driver.is_evaluation_scheduled() and not driver.is_processing()
	driver.set_update_rate_hz(20.0)
	passed = passed and driver.manual_tick_timer.is_stopped()
	driver.set_external_tick(false)
	var phase: float = driver.animation_graph.gait_phase
	await create_timer(0.18).timeout
	passed = passed and driver.animation_graph.gait_phase > phase and not driver.is_processing()
	var policy: Dictionary = driver.capture_clock()
	driver.set_distance_suspended(true)
	phase = driver.animation_graph.gait_phase
	await create_timer(0.12).timeout
	passed = passed and is_equal_approx(phase, driver.animation_graph.gait_phase) and not driver.is_evaluation_scheduled()
	driver.restore_clock(policy)
	await create_timer(0.12).timeout
	passed = passed and driver.animation_graph.gait_phase > phase and driver.is_evaluation_scheduled()
	var residency := preload("res://scripts/zone_residency_service.gd").new()
	root.add_child(residency)
	Driver.record_configuration(actor, "fixture_actor", driver)
	residency._cache_route_zone("fixture", actor, [], 1)
	passed = passed and not driver.is_evaluation_scheduled()
	residency._activate_cached_zone("fixture")
	phase = driver.animation_graph.gait_phase
	await create_timer(0.12).timeout
	passed = passed and driver.animation_graph.gait_phase > phase and Driver.zone_contract(actor).ok
	var duplicate := Driver.new()
	actor.add_child(duplicate)
	passed = passed and not duplicate.configure(actor, {"idle":"Walk"}) and driver.is_valid()
	passed = passed and duplicate.animation_graph == null and not duplicate.is_processing()
	duplicate.free()
	var missing := Node3D.new()
	root.add_child(missing)
	passed = passed and not driver.configure(missing, {"idle":"Missing"})
	passed = passed and not driver.is_valid() and driver.animation_graph == null and driver.manual_tick_timer.is_stopped()
	passed = passed and driver.configure(actor, {"idle":"Walk", "walk":"Walk", "run":"Walk"})
	var bound_clip := driver.animation_player.get_animation("Walk").duplicate() as Animation
	bound_clip.track_set_path(0, NodePath("Armature/Skeleton3D:NoSuchBone"))
	driver.animation_player.get_animation_library("").add_animation("Broken", bound_clip)
	passed = passed and not driver.configure(actor, {"idle":"Broken"}) and not driver.is_valid()
	driver.set_update_rate_hz(20.0)
	driver.set_external_tick(false)
	passed = passed and driver.manual_tick_timer.is_stopped() and not driver.is_processing()
	passed = passed and not Driver.zone_contract(actor).ok and str(Driver.zone_contract(actor).errors).contains("fixture_actor")
	passed = passed and driver.configure(actor, {"idle":"Walk", "walk":"Walk", "death":"Walk"})
	passed = passed and Driver.zone_contract(actor).ok
	driver.set_dead()
	policy = driver.capture_clock()
	driver.set_distance_suspended(true)
	driver.restore_clock(policy)
	passed = passed and driver.dead and driver.current_state == "death"
	driver.dead = false
	driver.stop_action()
	passed = passed and driver.current_state == "idle" and driver.is_evaluation_scheduled()
	missing.free()
	actor.free()
	residency.free()
	print("ANIMATION LIFECYCLE: %s - bone motion, one clock, distance/cache resume, duplicate owner, failed retry and invalid binding" % ("PASS" if passed else "FAIL"))
	return passed
