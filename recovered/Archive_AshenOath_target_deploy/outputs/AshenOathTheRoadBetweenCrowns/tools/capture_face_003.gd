extends SceneTree

const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterPresentation = preload("res://scripts/character_presentation.gd")

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var helper: Node
var captures: Array[Image] = []
var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("FACE-003 capture requires a graphical renderer")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	helper = AssetSpawnHelper.new()
	root.add_child(helper)
	await process_frame
	await _capture_role("player_human", "player", "FACE_003_01_Kael_Native_Face")
	await _capture_role("sister_anwen_human", "anwen", "FACE_003_02_Anwen_Native_Face")
	_make_contact_sheet()
	print("FACE-003 CAPTURE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _capture_role(role: String, identity: String, file_name: String) -> void:
	var stage := _create_stage()
	var actor := Node3D.new()
	stage.add_child(actor)
	var visual: Node3D = helper.spawn_visual_role(role, "characters")
	if visual == null:
		failures += 1
		stage.queue_free()
		return
	actor.add_child(visual)
	if identity == "player":
		CharacterPresentation.apply_player(actor, visual)
	else:
		CharacterPresentation.apply_npc(actor, "sister_anwen")
	await _frames(3)
	for animation_player in visual.find_children("*", "AnimationPlayer", true, false):
		if animation_player.has_animation("Idle_No"):
			animation_player.play("Idle_No")
	await _frames(18)
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720) or not _is_nonblank(image):
		failures += 1
	else:
		image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, file_name]))
		captures.append(image.duplicate())
	stage.queue_free()
	await _frames(6)

func _create_stage() -> Node3D:
	var stage := Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("11171a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a9a39a")
	environment.ambient_light_energy = 0.96
	world.environment = environment
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, -28, 0)
	key.light_color = Color("ffe1c0")
	key.light_energy = 1.70
	stage.add_child(key)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("352e27")
	ground_material.roughness = 0.92
	ground.material_override = ground_material
	stage.add_child(ground)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.48, 2.05)
	camera.look_at_from_position(camera.position, Vector3(0, 1.48, 0), Vector3.UP)
	camera.fov = 28.0
	camera.current = true
	stage.add_child(camera)
	return stage

func _make_contact_sheet() -> void:
	if captures.size() != 2:
		failures += 1
		return
	var sheet := Image.create_empty(1280, 720, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("0b1013"))
	for index in range(captures.size()):
		var panel := captures[index].get_region(Rect2i(0, 0, 1280, 720))
		panel.resize(640, 360, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(panel, Rect2i(0, 0, 640, 360), Vector2i(index * 640, 180))
	sheet.save_png(ProjectSettings.globalize_path("%s/FACE_003_03_Native_Face_Contact_Sheet.png" % OUTPUT_DIR))

func _is_nonblank(image: Image) -> bool:
	var changed := 0
	for y in range(0, image.get_height(), 12):
		for x in range(0, image.get_width(), 12):
			var pixel := image.get_pixel(x, y)
			if pixel.r + pixel.g + pixel.b > 0.12:
				changed += 1
				if changed >= 24:
					return true
	return false

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
