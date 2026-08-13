extends SceneTree

const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterPresentation = preload("res://scripts/character_presentation.gd")

var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("CHAR-007 capture requires a graphical renderer")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Development_Gallery/screenshots"))
	var helper := AssetSpawnHelper.new()
	root.add_child(helper)
	await process_frame
	var stage := _create_stage()
	var actor := Node3D.new()
	stage.add_child(actor)
	var visual: Node3D = helper.spawn_visual_role("sister_anwen_human", "characters")
	if visual == null:
		failures += 1
	else:
		actor.add_child(visual)
		CharacterPresentation.apply_npc(actor, "sister_anwen")
		await _frames(2)
		_play_all(visual, "Idle_No")
		await _frames(18)
		_save("CHAR_007_Anwen_Shared_Rig")
		actor.rotation_degrees.y = 24.0
		await _frames(8)
		_save("CHAR_007_Anwen_ThreeQuarter")
	stage.queue_free()
	await _frames(3)
	print("CHAR-007 CAPTURE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _create_stage() -> Node3D:
	var result := Node3D.new()
	root.add_child(result)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("151a1a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8b0a1")
	environment.ambient_light_energy = 1.12
	world.environment = environment
	result.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, -28, 0)
	key.light_color = Color("ffe2c3")
	key.light_energy = 1.75
	result.add_child(key)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("3b332a")
	ground_material.roughness = 0.92
	ground.material_override = ground_material
	result.add_child(ground)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.22, -3.35)
	camera.look_at_from_position(camera.position, Vector3(0, 1.02, 0), Vector3.UP)
	camera.fov = 34.0
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
