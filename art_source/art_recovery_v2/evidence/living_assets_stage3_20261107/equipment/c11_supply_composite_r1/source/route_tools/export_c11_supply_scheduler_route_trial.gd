extends "export_c11_supply_forward_trial.gd"

## Supplemental authoring carrier. The staged parent awaits this route bake
## so the existing modifier receives the engine's fixed 120 Hz process delta.
const RouteLife = preload("res://scripts/greyfen_life_controller.gd")
const RouteCast = preload("res://scripts/story_cast_profile.gd")
const ROUTE_CLIP := "Authoring_Carry_Scheduler_Route"
const ROUTE_SECONDS := 9.0
const ROUTE_SPEED := 0.62
const ROUTE_MINUTE := 1100.0

class RouteHost extends Node:
	var player: Node3D
	var quests: Node
	var day_night: Node
	var audio: Node
	func validate_walkable_position(point: Vector3) -> Vector3: return point

func _inputs(source: String, prepared: String) -> Dictionary:
	var inputs := super._inputs(source, prepared)
	if inputs.is_empty(): return inputs
	var directory: String = str(get_script().resource_path).get_base_dir()
	for path: String in [directory.path_join("export_c11_supply_forward_trial.gd"),
			"res://scripts/greyfen_life_controller.gd", "res://scripts/systems/npc_routine_director.gd",
			"res://scripts/systems/character_motion_step.gd", "res://data/cast_life.json"]:
		if not FileAccess.file_exists(path): return {}
		inputs[path] = FileAccess.get_sha256(path)
	return inputs

func _bake(recipe: Dictionary, skeleton_path: String, identity: String) -> Animation:
	if str(recipe.name) != ROUTE_CLIP or identity != "C11":
		failures.append("This supplemental carrier must sample only Nessa's authored route")
		return null
	var host := RouteHost.new()
	root.add_child(host)
	host.player = Node3D.new()
	host.add_child(host.player)
	var life := RouteLife.new()
	host.add_child(life)
	life.set_process(false)
	life.set_physics_process(false)
	life.host = host
	life.player = host.player
	var initial := placement.transform
	var clip := await _measure_route(host, life, skeleton_path)
	visual.remove_meta("cast_viewer")
	placement.transform = initial
	host.free()
	return clip

func _measure_route(host: RouteHost, life: Node, skeleton_path: String) -> Animation:
	var profile: Dictionary = RouteCast.routine("saga_nessa", "greyfen", null, null, "dusk", ROUTE_MINUTE)
	var path: Array = profile.get("path", [])
	if path.size() != 2 or not bool(profile.get("carry_in_transit", false)) or str(profile.get("prop", "")) != "supply":
		failures.append("Nessa's current authored work-to-errand Carry route is unavailable")
		return null
	var start: Vector3 = path[0]
	var destination: Vector3 = path[1]
	var authored: Dictionary = RouteCast.life_data()["zones"]["greyfen"]["saga_nessa"]
	var work: Array = authored.work
	var errand: Array = authored.errand
	if str(profile.get("intent_key", "")) != "baker_day:4" or str(profile.get("intent", "")) != "carry" or str(profile.get("activity", "")) != "carry" \
			or start != Vector3(float(work[0]), float(work[1]), float(work[2])) \
			or destination != Vector3(float(errand[0]), float(errand[1]), float(errand[2])):
		failures.append("Expected the original authored Nessa work-to-errand scope")
		return null
	var heading := (destination - start).normalized()
	host.player.global_position = start.lerp(destination, 0.5) + heading.cross(Vector3.UP) * 5.0
	visual.set_meta("cast_viewer", host.player)
	driver.reset_for_journey_restore()
	var skeleton: Skeleton3D = driver.skeleton
	var modifier: Node = driver.life_modifier
	modifier.pose_weight = 0.0
	modifier.ambient_weight = 0.0
	modifier.elapsed = 0.0
	modifier.idle_rng.seed = 11001101
	modifier.next_shift = modifier.idle_rng.randf_range(6.0, 10.0)
	modifier.shift_rotation = 0.0
	modifier.shift_target = 0.0
	modifier.trial_failures.clear()
	modifier.trial_applications = 0
	placement.global_position = start
	var entry: Dictionary = life._make_entry("saga_nessa", placement, path, ROUTE_SPEED, driver, true)
	entry.regional = true
	entry.routine_zone = "greyfen"
	entry.profile = profile
	entry.pause = 0.0
	# A departure follows an approach to the work anchor from the errand.
	life._face(placement, start - heading, TAU, true)
	var hand := skeleton.find_bone("hand_r")
	if hand < 0:
		failures.append("The actual route actor has no right hand")
		return null
	var clip := Animation.new()
	clip.length = ROUTE_SECONDS
	clip.loop_mode = Animation.LOOP_NONE
	for bone: int in skeleton.get_bone_count():
		for type: int in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			var track := clip.add_track(type)
			clip.track_set_path(track, NodePath(skeleton_path + ":" + skeleton.get_bone_name(bone)))
	var frames := ceili(clip.length * HZ) + 1
	var samples: Array[Dictionary] = []
	var maximum_speed := 0.0
	var previous_speed := 0.0
	var reached_cap := false
	var braking := false
	var arrival := false
	var visible_moving := 0
	var visible_standing := 0
	var graph: RefCounted = driver.animation_graph
	for tick: int in 3: await process_frame
	for frame: int in frames:
		await process_frame
		var engine_delta: float = modifier.get_process_delta_time()
		if absf(engine_delta - 1.0 / HZ) > 0.000001:
			failures.append("The route sampler must run with the engine's fixed 120 Hz process delta")
			return null
		var delta := 0.0 if frame == 0 else engine_delta
		life._update_actor(entry, delta)
		skeleton.reset_bone_poses()
		driver.advance_external(delta)
		modifier.scoped_route = int(entry.target) == 1 and str(entry.id) == "saga_nessa" and str(entry.routine_zone) == "greyfen" and str(entry.profile.intent_key) == "baker_day:4"
		modifier.paired_goal_witness = {}
		modifier._process_modification()
		var at := float(frame) / HZ
		var speed: float = driver.current_speed_mps
		maximum_speed = maxf(maximum_speed, speed)
		reached_cap = reached_cap or absf(speed - ROUTE_SPEED) <= 0.001
		braking = braking or reached_cap and speed > 0.05 and speed < previous_speed - 0.001
		arrival = arrival or bool(entry.activity_active) and int(entry.get("arrived_target", -1)) == 1
		previous_speed = speed
		var tool: BoneAttachment3D = modifier.tool
		var prop_visible := is_instance_valid(tool) and tool.is_visible_in_tree()
		if not modifier.trial_failures.is_empty() or not is_finite(speed) or speed > ROUTE_SPEED + 0.001 or (prop_visible and (str(tool.bone_name) != "hand_r" or str(modifier.tool_kind) != "supply")):
			failures.append("Route changed the protected rig, pace or held-prop ownership")
			return null
		var witness: Dictionary = modifier.visible_socket_witness(placement) if prop_visible else {}
		if prop_visible and (witness.is_empty() or float(witness.anchor_error_m) > 0.001 or (speed > 0.05 and not is_equal_approx(float(modifier.pose_weight), 1.0))):
			failures.append("Actual fitted socket became visible without verified ownership and post-solve weight")
			return null
		if prop_visible and speed > 0.05: visible_moving += 1
		if prop_visible and speed <= 0.05: visible_standing += 1
		if frame == 0 or frame == frames - 1:
			var visible := _visible_geometry()
			if retained_visible_meshes.is_empty(): retained_visible_meshes = visible
			if visible.is_empty() or retained_visible_meshes != visible:
				failures.append("Route changed the retained body mesh inventory")
				return null
		var actor_inverse := placement.global_transform.affine_inverse()
		for bone: int in skeleton.get_bone_count():
			var pose := skeleton.get_bone_pose(bone)
			var global_pose := skeleton.global_transform * skeleton.get_bone_global_pose(bone)
			if not RigidEquivalence.finite_pose_sample(pose, global_pose):
				failures.append("Nonfinite retained route bone pose")
				return null
			clip.position_track_insert_key(bone * 3, at, pose.origin)
			clip.rotation_track_insert_key(bone * 3 + 1, at, pose.basis.orthonormalized().get_rotation_quaternion())
			clip.scale_track_insert_key(bone * 3 + 2, at, skeleton.get_bone_pose_scale(bone))
		samples.append({"time":at, "gait_phase":float(graph.gait_phase), "native_position":graph.playback.get_current_play_position(),
			"hand_frame":_frame(actor_inverse * skeleton.global_transform * skeleton.get_bone_global_pose(hand)),
			"route_position":_vector(placement.global_position), "speed_mps":speed, "pose_weight":float(modifier.pose_weight),
			"prop_visible":prop_visible, "current_branch":str(graph.playback.get_current_node()),
			"fading_from":str(graph.playback.get_fading_from_node()), "arrived":arrival, "paired_goal":modifier.paired_goal_witness, "socket_witness":witness, "target_index":int(entry.target)})
	if not reached_cap or not braking or not arrival or visible_moving == 0 or visible_standing == 0:
		failures.append("Route must include actual acceleration, cruise, braking and the visible standing handoff")
		return null
	records.append({"clip":ROUTE_CLIP, "activity":"carry", "prop":"supply", "hand":"hand_r", "moving":true,
		"speed_mps":maximum_speed, "duration":clip.length, "frames":frames, "hand_samples":samples,
		"generic_prop_fit_verified":false, "route":{"schedule":"baker_day", "minute":ROUTE_MINUTE,
			"start":_vector(start), "destination":_vector(destination), "actual_controller":true,
			"disposable_spatial_fixture":true, "braking_observed":true, "arrival_observed":true,
			"visible_moving_frames":visible_moving, "visible_standing_frames":visible_standing,
			"intent_key":"baker_day:4", "outbound_target_index":1, "revealed_after_owning_solve":true}})
	return clip
