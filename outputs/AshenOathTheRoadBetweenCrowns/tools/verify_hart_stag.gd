extends SceneTree

const Enemy = preload("res://scripts/enemy_ai.gd")
var failures := 0
var step_sides: Array[StringName] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var target := Node3D.new()
	root.add_child(target)
	target.position = Vector3(0, 0, -8)
	var hart := Enemy.new()
	root.add_child(hart)
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	hart.setup("white_hart_avatar", definitions.white_hart_avatar, target)
	hart.set_physics_process(false)
	check(not hart.visual_root.has_meta("enemy_visual_failure"), "Hart role must resolve")
	var driver = hart.animation_driver
	check(driver != null and driver.is_valid(), "Stag must have a valid animation driver")
	if driver != null and driver.is_valid():
		var skeleton: Skeleton3D = driver.get_skeleton()
		check(skeleton.get_bone_count() == 38, "Hart must resolve the native stag skeleton")
		for state in {"idle":"Idle", "walk":"Walk", "run":"Gallop", "attack":"Attack_Headbutt", "hit":"Idle_HitReact1", "death":"Death"}:
			var clip: StringName = driver.get_clip_for_state(state)
			check(clip != StringName(), "Native stag clip must resolve: " + state)
		var delta: Vector3 = skeleton.global_transform.basis * (skeleton.get_bone_global_rest(skeleton.find_bone("Head")).origin - skeleton.get_bone_global_rest(skeleton.find_bone("Body")).origin)
		check(delta.z < -0.1, "Stag head must face gameplay -Z")
		var player: AnimationPlayer = driver.get_animation_player()
		var graph = driver.animation_graph
		driver.set_external_tick(true)
		check(not player.active and graph.tree.active and graph.tree.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, "AnimationTree must be the sole manually scheduled mixer")
		for state in ["walk", "run", "attack", "hit", "death"]:
			var clip: StringName = driver.get_clip_for_state(state)
			if clip == StringName():
				continue
			driver.stop_action()
			if state in ["walk", "run"]:
				driver.set_locomotion(0.5 if state == "walk" else 1.6, Vector3.FORWARD, true)
			else:
				driver.trigger_action(state)
			driver.advance_external(0.15)
			var poses: Array[Transform3D] = []
			for bone in skeleton.get_bone_count():
				poses.append(skeleton.get_bone_pose(bone))
			driver.advance_external(0.15)
			var changed := false
			for bone in skeleton.get_bone_count():
				changed = changed or not poses[bone].is_equal_approx(skeleton.get_bone_pose(bone))
			check(changed, "Native stag clip must move bones: " + state)
		driver.dead = false
		driver.stop_action()
		driver.set_locomotion(0.0, Vector3.ZERO, true)
		driver.set_distance_suspended(true)
		check(not driver.is_evaluation_scheduled(), "Dormant Hart must suspend mixer evaluation")
		driver.set_distance_suspended(false)
		check(driver.is_evaluation_scheduled(), "Resumed Hart must restore mixer evaluation")
		driver.set_external_tick(true)
		driver.set_locomotion(0.5, Vector3(0, 0, -1), true)
		var time_before: float = graph.gait_phase
		await process_frame
		await process_frame
		check(is_equal_approx(graph.gait_phase, time_before), "Manual mixer must not advance on idle frames")
		driver.advance_external(0.04)
		check(graph.gait_phase > time_before, "Externally owned clock must advance exactly when its owner ticks")
		time_before = graph.gait_phase
		driver.advance_external(0.05)
		check(graph.gait_phase > time_before, "Scheduled update must advance animation")
		driver.set_distance_suspended(true)
		time_before = graph.gait_phase
		driver.advance_external(0.2)
		check(is_equal_approx(graph.gait_phase, time_before), "Dormant actor must ignore scheduled ticks")
		driver.set_distance_suspended(false)
		driver.set_locomotion(0.0, Vector3.ZERO, true)
		driver.locomotion_step.connect(func(side: StringName): step_sides.append(side))
		driver.set_locomotion(0.5, Vector3(0, 0, -1), true)
		for tick in 40:
			driver.advance_external(0.1)
		check(step_sides.size() >= 2, "Scheduled locomotion must emit foot contacts")
		for index in range(1, step_sides.size()):
			check(step_sides[index] != step_sides[index - 1], "Foot contacts must alternate")
		var step_count := step_sides.size()
		driver.set_distance_suspended(true)
		for tick in 20:
			driver.advance_external(0.1)
		check(step_sides.size() == step_count, "Dormancy must silence foot contacts")
		driver.set_distance_suspended(false)
		driver.set_locomotion(0.0, Vector3.ZERO, true)
	check(hart.boss_visual_root == null, "Hart must not add the old root-mounted identity pieces")
	check(hart.find_children("*Antler*", "BoneAttachment3D", true, false).is_empty(), "Hart must not add proxy antlers")
	var mapped: Node3D = hart.visual_root.find_child("white_hart_avatar_visual", true, false)
	var bounds := AABB()
	var first := true
	if mapped != null:
		for mesh in mapped.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
			check(mesh.material_override == null, "Native Hart materials must not be overwritten")
			for surface in mesh.mesh.get_surface_count():
				check(mesh.get_surface_override_material(surface) == null, "Hart identity must preserve authored surface materials")
				var material: Material = mesh.mesh.surface_get_material(surface)
				check(material != null and material.resource_name.begins_with("Hart"), "Authored pale surfaces must not become brown fallback material")
	check(not first and absf(bounds.size.y - 3.6) < 0.08, "Composed Hart must retain its normalized full height")
	check(absf(bounds.position.y) < 0.08, "Composed Hart must be grounded without wolf offsets")
	print("HART BOUNDS: ", bounds)
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 720)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.07, 0.10, 0.10)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = 0.6
		root.add_child(env)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-40, -25, 0)
		root.add_child(light)
		var floor_mesh := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(12, 12)
		floor_mesh.mesh = plane
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.12, 0.16, 0.14)
		floor_mesh.material_override = material
		root.add_child(floor_mesh)
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.position = Vector3(4.0, 2.8, -6.0)
		camera.look_at(Vector3(0, 1.7, 0))
		camera.current = true
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Temp/AshenOath/Hart_stag_runtime.png")
		camera.free()
		floor_mesh.free()
		light.free()
		env.free()
	hart.free()
	var factory := preload("res://scripts/asset_spawn_helper.gd").new()
	root.add_child(factory)
	var witness: Node3D = factory.spawn_visual_role("white_hart_boss", "enemies")
	check(witness != null, "Peaceful witness role must resolve")
	if witness != null:
		root.add_child(witness)
		var section := preload("res://scripts/zones/campaign_finale_section.gd").new()
		section.configure_witness_animation(witness)
		var witness_driver = witness.get_node("HartWitnessAnimation")
		check(witness_driver.is_valid(), "Peaceful witness must have native idle")
		witness_driver.set_external_tick(true)
		var playback: AnimationNodeStateMachinePlayback = witness_driver.animation_graph.playback
		var before: float = playback.get_current_play_position()
		witness_driver.advance_external(0.1)
		check(playback.get_current_play_position() > before, "Peaceful witness idle must advance")
		witness.free()
	factory.clear_runtime_caches()
	factory.free()
	target.free()
	await process_frame
	await process_frame
	print("HART STAG RUNTIME: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
