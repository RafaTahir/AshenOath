extends SceneTree

const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterPresentation = preload("res://scripts/character_presentation.gd")

const OUTPUT := "res://verification_screenshots/char_facing_ranger_001"
const GALLERY := "res://Development_Gallery/screenshots"
var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("CHAR-FACING-RANGER-001 capture requires a graphical renderer")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GALLERY))
	var helper := AssetSpawnHelper.new()
	root.add_child(helper)
	await process_frame
	await _capture(helper, "CHAR_FACING_RANGER_001_01_Senn_Portrait", Vector3(0, 1.22, -3.45), 34.0, "idle")
	await _capture(helper, "CHAR_FACING_RANGER_001_02_Senn_Walk", Vector3(0, 1.18, -3.85), 36.0, "walk")
	await _capture(helper, "CHAR_FACING_RANGER_001_03_Senn_Gameplay", Vector3(0, 1.34, -5.10), 42.0, "idle")
	print("CHAR-FACING-RANGER-001 CAPTURE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _capture(helper: Node, file_name: String, camera_position: Vector3, fov: float, clip_hint: String) -> void:
	var stage := _create_stage(camera_position, fov)
	var actor := Node3D.new()
	actor.name = "CaptainSenn"
	stage.add_child(actor)
	var visual: Node3D = helper.spawn_visual_role("road_ranger_human", "characters")
	if visual == null:
		failures += 1
		stage.queue_free()
		await _frames(2)
		return
	actor.add_child(visual)
	CharacterPresentation.apply_npc(actor, "captain_senn")
	await _frames(3)
	_play_clip(visual, clip_hint)
	await _frames(18 if clip_hint == "idle" else 12)
	_save(file_name)
	stage.queue_free()
	await _frames(3)

func _create_stage(camera_position: Vector3, fov: float) -> Node3D:
	var stage := Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("11171a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a7aba4")
	environment.ambient_light_energy = 1.0
	world.environment = environment
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34, 28, 0)
	key.light_color = Color("ffe0bd")
	key.light_energy = 1.8
	stage.add_child(key)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 10)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("312b24")
	ground_material.roughness = 0.92
	ground.material_override = ground_material
	stage.add_child(ground)
	var camera := Camera3D.new()
	camera.position = camera_position
	camera.look_at_from_position(camera.position, Vector3(0, 1.02, 0), Vector3.UP)
	camera.fov = fov
	camera.current = true
	stage.add_child(camera)
	return stage

func _play_clip(root_node: Node, hint: String) -> void:
	for player in root_node.find_children("*", "AnimationPlayer", true, false):
		var selected := StringName()
		for animation in player.get_animation_list():
			var lowered := str(animation).to_lower()
			if hint == "walk" and lowered.contains("walk"):
				selected = animation
				break
			if hint == "idle" and lowered.contains("idle"):
				selected = animation
				break
		if selected != StringName():
			player.play(selected)

func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		failures += 1
		return
	image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT, file_name]))
	image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [GALLERY, file_name]))
	print("CAPTURED ", file_name)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
