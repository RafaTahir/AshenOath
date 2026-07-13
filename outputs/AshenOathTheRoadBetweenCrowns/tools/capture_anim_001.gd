extends SceneTree

const PlayerController = preload("res://scripts/player_controller.gd")
const OUTPUT := "res://verification_screenshots/anim_001"
const GALLERY := "res://Development_Gallery/screenshots"

var player
var capture_camera: Camera3D
var captures: Array[Image] = []
var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("ANIM-001 capture requires a graphical renderer")
		quit(1)
		return
	_register_capture_actions()
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GALLERY))
	await _warm_renderer()
	await _capture_state("idle", 0.30, "ANIM_001_01_Kael_Idle")
	await _capture_state("walk", 0.42, "ANIM_001_02_Kael_Walk")
	await _capture_state("attack_light", 0.48, "ANIM_001_03_Kael_Attack")
	await _capture_state("beam_cast", 0.42, "ANIM_001_04_Kael_Oathfire_Sheathed")
	_make_contact_sheet()
	print("ANIM-001 CAPTURE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _register_capture_actions() -> void:
	for action in [
		"move_left", "move_right", "move_forward", "move_back", "run", "jump",
		"dodge", "light_attack", "heavy_attack", "use_potion", "throw_bomb",
		"block", "oathfire_beam", "pause"
	]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

func _capture_state(state: String, fraction: float, file_name: String) -> void:
	var stage := _create_stage()
	player = PlayerController.new()
	stage.add_child(player)
	player.set_physics_process(false)
	await _frames(10)
	player.animation_driver.set_distance_suspended(false)
	if state == "beam_cast":
		player.call("_set_sword_sheathed", true)
		player.rotation_degrees.y = -22.0
	var clip: StringName = player.animation_driver.get_clip_for_state(state)
	var animation_player := player.animation_driver.get_animation_player() as AnimationPlayer
	if clip == StringName() or animation_player == null:
		failures += 1
		stage.queue_free()
		return
	animation_player.play(clip)
	var animation := animation_player.get_animation(clip)
	animation_player.seek(animation.length * fraction, true)
	await _frames(14)
	_frame_player()
	await _frames(8)
	capture_camera.current = true
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720) or not _is_nonblank(image):
		failures += 1
		stage.queue_free()
		await _frames(6)
		return
	image.save_png("%s/%s.png" % [OUTPUT, file_name])
	image.save_png("%s/%s.png" % [GALLERY, file_name])
	captures.append(image.duplicate())
	stage.queue_free()
	await _frames(6)

func _warm_renderer() -> void:
	var stage := _create_stage()
	await _frames(18)
	root.get_texture().get_image()
	stage.queue_free()
	await _frames(6)

func _is_nonblank(image: Image) -> bool:
	var background := Color("11171a")
	var changed_samples := 0
	for y in range(0, image.get_height(), 12):
		for x in range(0, image.get_width(), 12):
			var pixel := image.get_pixel(x, y)
			if abs(pixel.r - background.r) + abs(pixel.g - background.g) + abs(pixel.b - background.b) > 0.10:
				changed_samples += 1
				if changed_samples >= 24:
					return true
	return false

func _make_contact_sheet() -> void:
	if captures.size() != 4:
		failures += 1
		return
	var sheet := Image.create_empty(1280, 720, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("0b1013"))
	for index in range(captures.size()):
		var panel := captures[index].get_region(Rect2i(440, 0, 400, 720))
		panel.resize(320, 576, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(panel, Rect2i(0, 0, 320, 576), Vector2i(index * 320, 72))
	sheet.save_png("%s/ANIM_001_05_Kael_Motion_Contact_Sheet.png" % OUTPUT)
	sheet.save_png("%s/ANIM_001_05_Kael_Motion_Contact_Sheet.png" % GALLERY)

func _create_stage() -> Node3D:
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
	capture_camera = Camera3D.new()
	capture_camera.fov = 34.0
	capture_camera.current = true
	stage.add_child(capture_camera)
	return stage

func _frame_player() -> void:
	var bounds := AABB()
	var has_bounds := false
	for child in player.visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		if (mesh_instance.name.contains("Beam") or mesh_instance.name.contains("ContactShadow")
			or mesh_instance.name.contains("Warrior_Sword") or mesh_instance.name.begins_with("visible_sword")):
			continue
		var world_bounds: AABB = mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
		bounds = bounds.merge(world_bounds) if has_bounds else world_bounds
		has_bounds = true
	var center := Vector3(0, 1.0, 0)
	var height := 1.8
	if has_bounds:
		center = bounds.get_center()
		height = clamp(bounds.size.y, 1.4, 2.4)
	var camera_position := center + Vector3(0, height * 0.06, max(height * 1.85, 3.0))
	capture_camera.look_at_from_position(camera_position, center + Vector3(0, height * 0.04, 0), Vector3.UP)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
