extends SceneTree

const MANIFEST_PATH := "res://art_audition_manifest.json"
const OUTPUT_DIR := "res://verification_screenshots/art_001"
const GALLERY_DIR := "res://Development_Gallery/screenshots"
const AssetSpawnHelperScript = preload("res://scripts/asset_spawn_helper.gd")

var manifest: Dictionary
var captured: Dictionary = {}
var failures := 0
var asset_helper: Node

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("ART-001 capture requires a graphical Compatibility renderer")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_error("ART-001 manifest is missing")
		quit(1)
		return
	manifest = JSON.parse_string(file.get_as_text())
	asset_helper = AssetSpawnHelperScript.new()
	root.add_child(asset_helper)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GALLERY_DIR))
	await capture_runtime_greyfen("ART_001_01_Greyfen_Baseline")
	await capture_candidate_greyfen("ART_001_02_Greyfen_Modular_Candidate")
	await capture_character_pair("kael", "ART_001_03_Kael_Baseline", "ART_001_04_Kael_Warrior_Candidate")
	await capture_character_pair("sister_anwen", "ART_001_05_Anwen_Baseline", "ART_001_06_Anwen_Cleric_Candidate")
	await capture_character_pair("ghoulkin", "ART_001_07_Ghoulkin_Baseline", "ART_001_08_Ghoulkin_Retained_Source")
	make_contact_sheet("ART_001_09_Greyfen_Comparison", "ART_001_01_Greyfen_Baseline", "ART_001_02_Greyfen_Modular_Candidate")
	make_contact_sheet("ART_001_10_Kael_Comparison", "ART_001_03_Kael_Baseline", "ART_001_04_Kael_Warrior_Candidate")
	make_contact_sheet("ART_001_11_Anwen_Comparison", "ART_001_05_Anwen_Baseline", "ART_001_06_Anwen_Cleric_Candidate")
	make_contact_sheet("ART_001_12_Ghoulkin_Comparison", "ART_001_07_Ghoulkin_Baseline", "ART_001_08_Ghoulkin_Retained_Source")
	var image_count := captured.size()
	await clean_shutdown()
	if failures > 0:
		push_error("ART-001 CAPTURE: FAIL (%d asset or image errors)" % failures)
		quit(1)
		return
	print("ART-001 CAPTURE: PASS (%d images)" % image_count)
	quit(0)

func capture_runtime_greyfen(file_name: String) -> void:
	var scene = load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await frames(8)
	game.hud.visible = false
	if game.camera_rig != null:
		game.camera_rig.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.4, 11.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.25, -3.0), Vector3.UP)
	camera.fov = 50.0
	camera.current = true
	game.add_child(camera)
	await frames(12)
	await save_viewport(file_name)
	release_meshes(game)
	game.queue_free()
	await frames(4)

func capture_candidate_greyfen(file_name: String) -> void:
	var stage := create_stage(Color(0.075, 0.09, 0.095), true)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.4, 11.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.25, -3.0), Vector3.UP)
	camera.fov = 50.0
	camera.current = true
	stage.add_child(camera)
	add_plane(stage, "Ground", Vector2(24, 30), Vector3(0, -0.02, -3), material_from_textures("forest_ground", Color(0.28, 0.31, 0.25)))
	add_plane(stage, "Road", Vector2(4.6, 29), Vector3(0, 0.0, -3), material_from_textures("cobblestone", Color(0.34, 0.31, 0.27)))
	for z in [-8.0, -3.8, 0.4]:
		await add_asset(stage, "res://assets_external/environment/village/Wall_Plaster_Door_Flat.obj", Vector3(-5.1, 0, z), 2.45, Vector3(0, 90, 0))
		await add_asset(stage, "res://assets_external/environment/village/Wall_UnevenBrick_Straight.obj", Vector3(5.1, 0, z), 2.45, Vector3(0, -90, 0))
	for z in [-6.0, -1.8]:
		await add_asset(stage, "res://assets_external/environment/village/Roof_RoundTiles_4x6.obj", Vector3(-5.1, 2.35, z), 0.9, Vector3(0, 90, 0), false)
		await add_asset(stage, "res://assets_external/environment/village/Roof_RoundTiles_4x6.obj", Vector3(5.1, 2.35, z), 0.9, Vector3(0, -90, 0), false)
	await add_asset(stage, "res://assets_external/environment/village/Door_1_Flat.obj", Vector3(-4.35, 0, -1.8), 1.95, Vector3(0, 90, 0))
	await add_asset(stage, "res://assets_external/environment/village/Prop_Chimney.obj", Vector3(-5.2, 3.5, -6.0), 1.15, Vector3.ZERO, false)
	await add_asset(stage, "res://assets_external/environment/props/Stall_Cart_Empty.obj", Vector3(2.7, 0, 1.2), 1.35, Vector3(0, -28, 0))
	await add_asset(stage, "res://assets_external/environment/props/Barrel.obj", Vector3(-2.7, 0, -0.4), 0.8, Vector3.ZERO)
	for item in [[-8.0, -9.0, 5.5], [8.0, -8.0, 5.8], [-8.5, 3.0, 5.0], [8.5, 2.0, 5.3]]:
		await add_asset(stage, "res://assets_external/environment/forest/CommonTree_1.obj", Vector3(item[0], 0, item[1]), item[2], Vector3(0, item[0] * 7.0, 0))
	add_lantern(stage, Vector3(-3.6, 2.0, -1.8))
	add_lantern(stage, Vector3(3.6, 2.0, -5.8))
	await frames(18)
	await save_viewport(file_name)
	release_meshes(stage)
	stage.queue_free()
	await frames(4)

func capture_character_pair(role_id: String, baseline_name: String, candidate_name: String) -> void:
	var role: Dictionary = manifest["roles"][role_id]
	await capture_character(str(role["baseline"]), float(role["required_height"]), baseline_name)
	await capture_character(str(role["candidate"]), float(role["required_height"]), candidate_name)

func capture_character(path: String, target_height: float, file_name: String) -> void:
	var stage := create_stage(Color(0.035, 0.042, 0.045), false)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.22, 3.4)
	camera.look_at_from_position(camera.position, Vector3(0, 1.02, 0), Vector3.UP)
	camera.fov = 34.0
	camera.current = true
	stage.add_child(camera)
	add_plane(stage, "PortraitGround", Vector2(8, 8), Vector3.ZERO, flat_material(Color(0.12, 0.13, 0.13), 0.9))
	var resource = load(path)
	if not resource is PackedScene:
		push_error("ART-001 candidate is not a scene: %s" % path)
		quit(1)
		return
	var character = resource.instantiate()
	stage.add_child(character)
	await process_frame
	normalize_node(character, target_height, true)
	play_idle(character)
	await frames(18)
	await save_viewport(file_name)
	release_meshes(stage)
	stage.queue_free()
	await frames(4)

func create_stage(background: Color, street: bool) -> Node3D:
	var stage := Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = background
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.55, 0.62) if street else Color(0.52, 0.58, 0.65)
	environment.ambient_light_energy = 0.68
	world.environment = environment
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -32, 0)
	key.light_color = Color(1.0, 0.80, 0.64)
	key.light_energy = 1.35
	key.shadow_enabled = false
	stage.add_child(key)
	return stage

func add_asset(parent: Node3D, path: String, position: Vector3, target_height: float, rotation: Vector3, ground: bool = true) -> Node3D:
	var node = asset_helper.call("_instantiate_source_file", path)
	if not node is Node3D:
		push_error("Unable to load audition asset: %s" % path)
		failures += 1
		return null
	asset_helper.call("_prepare_spawned_asset", node, path, "art_audition", "environment")
	parent.add_child(node)
	await process_frame
	normalize_node(node, target_height, ground)
	node.position += position
	node.rotation_degrees = rotation
	return node

func normalize_node(node: Node3D, target_height: float, ground: bool) -> void:
	var bounds := combined_bounds(node)
	if bounds.size.y <= 0.001:
		return
	var scale_factor := target_height / bounds.size.y
	node.scale = Vector3.ONE * scale_factor
	var center := bounds.get_center()
	node.position.x -= center.x * scale_factor
	node.position.z -= center.z * scale_factor
	if ground:
		node.position.y -= bounds.position.y * scale_factor

func combined_bounds(node: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.visible:
			continue
		var bounds: AABB = node.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
		result = result.merge(bounds) if initialized else bounds
		initialized = true
	return result

func play_idle(node: Node) -> void:
	for player in node.find_children("*", "AnimationPlayer", true, false):
		for name in player.get_animation_list():
			if str(name).to_lower().contains("idle"):
				player.play(name)
				return

func add_plane(parent: Node3D, node_name: String, size: Vector2, position: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := PlaneMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)

func add_lantern(parent: Node3D, position: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = Color(1.0, 0.54, 0.24)
	light.light_energy = 1.8
	light.omni_range = 5.0
	light.shadow_enabled = false
	parent.add_child(light)

func material_from_textures(prefix: String, tint: Color) -> StandardMaterial3D:
	var material := flat_material(tint, 0.86)
	var base := "res://assets_external/textures/runtime/%s" % prefix
	var albedo_path := "%s_albedo.jpg" % base
	var normal_path := "%s_normal.jpg" % base
	if ResourceLoader.exists(albedo_path):
		material.albedo_texture = load(albedo_path)
		material.albedo_color = tint.lightened(0.42)
	if ResourceLoader.exists(normal_path):
		material.normal_enabled = true
		material.normal_texture = load(normal_path)
	material.uv1_scale = Vector3(4, 4, 4)
	return material

func flat_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

func save_viewport(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null or image.get_width() != 1280 or image.get_height() != 720:
		push_error("ART-001 produced an invalid image: %s" % file_name)
		failures += 1
		return
	var output_path := "%s/%s.png" % [OUTPUT_DIR, file_name]
	var gallery_path := "%s/%s.png" % [GALLERY_DIR, file_name]
	image.save_png(output_path)
	image.save_png(gallery_path)
	captured[file_name] = image.duplicate()
	print("CAPTURED %s" % gallery_path)

func make_contact_sheet(file_name: String, left_id: String, right_id: String) -> void:
	if not captured.has(left_id) or not captured.has(right_id):
		return
	var left: Image = captured[left_id].duplicate()
	var right: Image = captured[right_id].duplicate()
	left.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	right.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	var sheet := Image.create_empty(1280, 720, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.025, 0.028, 0.03))
	sheet.blit_rect(left, Rect2i(0, 0, 640, 360), Vector2i(0, 180))
	sheet.blit_rect(right, Rect2i(0, 0, 640, 360), Vector2i(640, 180))
	sheet.save_png("%s/%s.png" % [OUTPUT_DIR, file_name])
	sheet.save_png("%s/%s.png" % [GALLERY_DIR, file_name])
	captured[file_name] = sheet

func release_meshes(node: Node) -> void:
	for player in node.find_children("*", "AnimationPlayer", true, false):
		player.stop()
	for multimesh in node.find_children("*", "MultiMeshInstance3D", true, false):
		multimesh.multimesh = null
		multimesh.material_override = null
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		mesh.mesh = null
		mesh.material_override = null

func clean_shutdown() -> void:
	captured.clear()
	for child in root.get_children():
		release_meshes(child)
		child.free()
	if RenderingServer.has_method("force_sync"):
		RenderingServer.call("force_sync")
	await frames(16)

func frames(count: int) -> void:
	for _index in range(count):
		await process_frame
