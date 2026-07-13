extends SceneTree

const AssetSpawnHelperScript = preload("res://scripts/asset_spawn_helper.gd")
const CharacterPresentation = preload("res://scripts/character_presentation.gd")
const EnemyAI = preload("res://scripts/enemy_ai.gd")
const OUTPUT := "res://verification_screenshots/char_001"
const GALLERY := "res://Development_Gallery/screenshots"

var helper
var images: Dictionary = {}
var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("CHAR-001 capture requires a graphical renderer")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GALLERY))
	helper = AssetSpawnHelperScript.new()
	root.add_child(helper)
	await process_frame
	await capture_human("player_human", "player_kael", "CHAR_001_01_Kael_Identity")
	await capture_human("sister_anwen_human", "sister_anwen", "CHAR_001_02_Anwen_Identity")
	await capture_human("villager_female_human", "walker_board", "CHAR_001_03_Villager_Identity")
	await capture_ghoul("CHAR_001_04_Ghoulkin_Identity")
	make_comparison("CHAR_001_05_Kael_Before_After", "ART_001_03_Kael_Baseline.png", "CHAR_001_01_Kael_Identity")
	make_comparison("CHAR_001_06_Anwen_Before_After", "ART_001_05_Anwen_Baseline.png", "CHAR_001_02_Anwen_Identity")
	make_comparison("CHAR_001_07_Ghoulkin_Before_After", "ART_001_07_Ghoulkin_Baseline.png", "CHAR_001_04_Ghoulkin_Identity")
	print("CHAR-001 CAPTURE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func capture_human(visual_role: String, identity_role: String, file_name: String) -> void:
	var stage := create_stage()
	var actor := Node3D.new()
	stage.add_child(actor)
	var visual = helper.spawn_visual_role(visual_role, "characters")
	actor.add_child(visual)
	if identity_role == "player_kael":
		CharacterPresentation.apply_player(actor, actor)
	else:
		CharacterPresentation.apply_npc(actor, identity_role)
	await process_frame
	play_idle(actor)
	await _frames(18)
	await save_image(file_name)
	stage.queue_free()
	await _frames(4)

func capture_ghoul(file_name: String) -> void:
	var stage := create_stage()
	var target := Node3D.new()
	target.position = Vector3(0, 0, 10)
	stage.add_child(target)
	var enemy = EnemyAI.new()
	stage.add_child(enemy)
	enemy.setup("ghoulkin", {"name":"Ghoulkin", "health":60, "damage":10, "speed":2.0, "attack_range":1.5, "sense_range":1.0, "color":"#655f52"}, target)
	enemy.set_physics_process(false)
	await _frames(18)
	await save_image(file_name)
	stage.queue_free()
	await _frames(4)

func create_stage() -> Node3D:
	var stage := Node3D.new()
	root.add_child(stage)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("11171a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8996a0")
	environment.ambient_light_energy = 0.62
	environment_node.environment = environment
	stage.add_child(environment_node)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -28, 0)
	key.light_color = Color("ffd2aa")
	key.light_energy = 1.55
	stage.add_child(key)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("282620")
	ground_material.roughness = 0.92
	ground.material_override = ground_material
	stage.add_child(ground)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.20, 3.35)
	camera.look_at_from_position(camera.position, Vector3(0, 1.02, 0), Vector3.UP)
	camera.fov = 34.0
	camera.current = true
	stage.add_child(camera)
	return stage

func play_idle(node: Node) -> void:
	for player in node.find_children("*", "AnimationPlayer", true, false):
		for animation in player.get_animation_list():
			if str(animation).to_lower().contains("idle"):
				player.play(animation)
				return

func save_image(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		failures += 1
		return
	image.save_png("%s/%s.png" % [OUTPUT, file_name])
	image.save_png("%s/%s.png" % [GALLERY, file_name])
	images[file_name] = image.duplicate()
	print("CAPTURED ", file_name)

func make_comparison(file_name: String, before_file: String, after_id: String) -> void:
	if not images.has(after_id):
		failures += 1
		return
	var before := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [GALLERY, before_file]))
	var after: Image = images[after_id].duplicate()
	if before == null or before.is_empty():
		failures += 1
		return
	before.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	after.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	var sheet := Image.create_empty(1280, 720, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("0a0d0f"))
	sheet.blit_rect(before, Rect2i(0, 0, 640, 360), Vector2i(0, 180))
	sheet.blit_rect(after, Rect2i(0, 0, 640, 360), Vector2i(640, 180))
	sheet.save_png("%s/%s.png" % [OUTPUT, file_name])
	sheet.save_png("%s/%s.png" % [GALLERY, file_name])

func _frames(count: int) -> void:
	for index in range(count):
		await process_frame
