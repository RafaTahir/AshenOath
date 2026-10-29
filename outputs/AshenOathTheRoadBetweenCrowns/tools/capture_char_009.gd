extends SceneTree

const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterPresentation = preload("res://scripts/character_presentation.gd")

var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("CHAR-009 capture requires a graphical renderer")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--face-isolation="):
			call_deferred("_face_isolation", argument.trim_prefix("--face-isolation="))
			return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Development_Gallery/screenshots"))
	var helper := AssetSpawnHelper.new()
	root.add_child(helper)
	await process_frame
	var stage := _create_stage()
	var specs := [
		["villager_human", "walker_well", -1.85],
		["villager_female_human", "shrine_pilgrim", -0.62],
		["villager_worker_human", "forge_helper", 0.62],
		["villager_hooded_human", "walker_board", 1.85]
	]
	for item in specs:
		var actor := Node3D.new()
		actor.position = Vector3(float(item[2]), 0.0, 0.0)
		stage.add_child(actor)
		var visual: Node3D = helper.spawn_visual_role(str(item[0]), "characters", "%s:%s" % [str(item[1]), str(item[0])])
		if visual == null:
			failures += 1
			continue
		actor.add_child(visual)
		CharacterPresentation.apply_npc(actor, str(item[1]))
		_play_all(visual, "Idle")
	await _frames(18)
	_save("CHAR_009_Greyfen_Crowd_Variation")
	stage.queue_free()
	await _frames(3)
	print("CHAR-009 CAPTURE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _create_stage() -> Node3D:
	var result := Node3D.new()
	root.add_child(result)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("151a1a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bcb4a6")
	environment.ambient_light_energy = 1.20
	world.environment = environment
	result.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -26, 0)
	key.light_color = Color("ffe0bd")
	key.light_energy = 1.95
	result.add_child(key)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 8)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("393229")
	ground_material.roughness = 0.92
	ground.material_override = ground_material
	result.add_child(ground)
	var camera := Camera3D.new()
	# Face the crowd so the evidence shows facial and outfit variation.
	camera.position = Vector3(0, 1.36, -5.15)
	camera.look_at_from_position(camera.position, Vector3(0, 0.98, 0), Vector3.UP)
	camera.fov = 42.0
	camera.current = true
	result.add_child(camera)
	return result

func _play_all(root_node: Node, clip: StringName) -> void:
	for player in root_node.find_children("*", "AnimationPlayer", true, false):
		if player.has_animation(clip):
			player.play(clip)

func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		failures += 1
		return
	image.save_png(ProjectSettings.globalize_path("res://Development_Gallery/screenshots/%s.png" % name))
	print("CAPTURED %s" % name)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _face_isolation(output: String) -> void:
	# The same runtime roles, presentation and playback owner as the care area.
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(90.0).timeout.connect(func(): push_error("Face isolation timed out"); quit(1))
	var stage := _create_stage()
	var camera: Camera3D
	for child in stage.get_children():
		if child is Camera3D:
			camera = child
	var helper := AssetSpawnHelper.new()
	stage.add_child(helper)
	for spec: Array in [["sister_anwen_human", "sister_anwen"], ["villager_worker_human", "shrine_pilgrim"]]:
		var visual := helper.spawn_visual_role(str(spec[0]), "characters", str(spec[1]) + ":2")
		if visual == null:
			failures += 1
			continue
		stage.add_child(visual)
		CharacterPresentation.apply_npc(visual, str(spec[1]), false)
		var driver := preload("res://scripts/character_animation_driver.gd").new()
		visual.add_child(driver)
		if not driver.configure(visual, {"idle":"Idle", "walk":"Walk", "run":"Run"}):
			push_error("Face capture animation failed: " + str(spec[1]))
			failures += 1
			visual.free()
			continue
		var face := visual.find_child("CharacterFaceDriver", true, false)
		if face == null or face.head_modifier == null:
			push_error("Face capture requires the native face driver: " + str(spec[1]))
			failures += 1
			visual.free()
			continue
		var skeleton := driver.skeleton as Skeleton3D
		for retired: String in ["hood", "mantle"]:
			if visual.find_child("SilhouetteEquipment_" + retired, true, false) != null:
				push_error("Retired cleric shape remains: " + str(spec[1]) + "/" + retired)
				failures += 1
			var stale := BoneAttachment3D.new()
			stale.name = "SilhouetteEquipment_" + retired
			stale.set_meta("silhouette_layer", retired)
			skeleton.add_child(stale)
		CharacterPresentation.apply_npc(visual, str(spec[1]), false)
		for retired: String in ["hood", "mantle"]:
			if visual.find_child("SilhouetteEquipment_" + retired, true, false) != null:
				push_error("Stale cleric shape survived reconfiguration: " + retired)
				failures += 1
		if face != null and face.update_timer != null:
			# Explicit samples must not be replaced by a random blink/gaze tick.
			face.update_timer.stop()
		var head := skeleton.find_bone("head")
		if head < 0:
			head = skeleton.find_bone("Head")
		print("FACE_ACTOR ", spec[1], " source=", spec[0], " head=", head)
		for layer: String in ["hood", "mantle"]:
			var node := visual.find_child("RoleShape_" + layer, true, false) as MeshInstance3D
			if node != null:
				print("FACE_LAYER ", spec[1], " ", node.get_path(), " aabb=", node.get_aabb(), " world=", node.global_transform)
		for state: String in ["neutral", "blink", "speech", "gaze", "walk"]:
			driver.set_dialogue_pose(state in ["speech", "gaze"])
			driver.set_locomotion_motion(Vector3(0, 0, 0.72) if state == "walk" else Vector3.ZERO, true, 1.6)
			if face != null:
				face.set_conversation_active(true)
				face.set_speech_amount(0.8 if state == "speech" else 0.0)
				face.set_expression("concerned" if state == "speech" else "neutral")
				face.head_modifier.look_yaw = 0.24 if state == "gaze" else 0.0
				face.head_modifier.blink_closure = 1.0 if state == "blink" else 0.0
			await create_timer(0.35).timeout
			for view: String in ["front", "side", "back", "rear_quarter"]:
				camera.position = {"front":Vector3(0,1.53,-2.2), "side":Vector3(2.2,1.53,0), "back":Vector3(0,1.53,2.2), "rear_quarter":Vector3(1.56,1.53,1.56)}[view]
				camera.look_at(Vector3(0, 1.45, 0))
				camera.fov = 38.0
				await _frames(2)
				await RenderingServer.frame_post_draw
				var path := output.path_join("%s_%s_%s_native.png" % [spec[1],state,view])
				var image := root.get_texture().get_image()
				if image == null or image.save_png(path) != OK:
					failures += 1
			if head >= 0:
				print("FACE_STATE ", spec[1], " ", state, " head_scale=", skeleton.get_bone_pose_scale(head))
		visual.free()
		await _frames(2)
	helper.clear_runtime_caches()
	stage.free()
	print("FACE ISOLATION: ", "PASS" if failures == 0 else "FAIL", " (capture/setup only; inspect appearance)")
	quit(0 if failures == 0 else 1)
