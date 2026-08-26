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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Development_Gallery/screenshots"))
	var helper := AssetSpawnHelper.new()
	root.add_child(helper)
	await process_frame
	var stage := _create_stage()
	var specs := [
		["villager_human", "generic_villager_01", -2.3],
		["villager_female_human", "generic_villager_02", -0.8],
		["villager_worker_human", "farmer_toma", 0.8],
		["villager_hooded_human", "widow_elna", 2.3]
	]
	for item in specs:
		var actor := Node3D.new()
		actor.position = Vector3(float(item[2]), 0.0, 0.0)
		stage.add_child(actor)
		var visual: Node3D = helper.spawn_visual_role(str(item[0]), "characters")
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
	environment.ambient_light_energy = 1.05
	world.environment = environment
	result.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -26, 0)
	key.light_color = Color("ffe0bd")
	key.light_energy = 1.70
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
	camera.position = Vector3(0, 1.40, -6.4)
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
