extends SceneTree

const PlayerController = preload("res://scripts/player_controller.gd")
const OUTPUT_DIR := "res://Development_Gallery/screenshots"
const STATES := [
	{"state": "idle", "fraction": 0.22, "name": "ANIM_003_01_Kael_Idle"},
	{"state": "walk", "fraction": 0.42, "name": "ANIM_003_02_Kael_Walk"},
	{"state": "run", "fraction": 0.48, "name": "ANIM_003_03_Kael_Run"},
	{"state": "attack_light", "fraction": 0.52, "name": "ANIM_003_04_Kael_Light_Attack"},
	{"state": "parry", "fraction": 0.45, "name": "ANIM_003_05_Kael_Parry"},
	{"state": "beam_cast", "fraction": 0.40, "name": "ANIM_003_06_Kael_Oathfire"},
]

var capture_camera: Camera3D
var captures: Array[Image] = []
var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("ANIM-003 capture requires a graphical renderer")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _warm_renderer()
	for spec in STATES:
		await _capture_state(str(spec.state), float(spec.fraction), str(spec.name))
	_make_contact_sheet()
	print("ANIM-003 CAPTURE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _capture_state(state: String, fraction: float, file_name: String) -> void:
	var stage := _create_stage()
	var player := PlayerController.new()
	stage.add_child(player)
	player.set_physics_process(false)
	await _frames(10)
	var driver = player.animation_driver
	if driver == null or not driver.is_valid():
		failures += 1
		stage.queue_free()
		return
	driver.set_distance_suspended(false)
	if state == "beam_cast":
		player.call("_set_sword_sheathed", true)
		player.rotation_degrees.y = -22.0
	var clip: StringName = driver.get_clip_for_state(state)
	var animation_player := driver.get_animation_player() as AnimationPlayer
	if clip == StringName() or animation_player == null:
		failures += 1
		stage.queue_free()
		return
	animation_player.play(clip)
	var animation := animation_player.get_animation(clip)
	if animation != null:
		animation_player.seek(animation.length * fraction, true)
	await _frames(14)
	_frame_player(player)
	await _frames(8)
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720) or not _is_nonblank(image):
		failures += 1
		stage.queue_free()
		await _frames(5)
		return
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
	environment.ambient_light_color = Color("9aa3a7")
	environment.ambient_light_energy = 0.72
	world.environment = environment
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -28, 0)
	key.light_color = Color("ffd7b0")
	key.light_energy = 1.65
	stage.add_child(key)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("2b2824")
	ground_material.roughness = 0.92
	ground.material_override = ground_material
	stage.add_child(ground)
	capture_camera = Camera3D.new()
	capture_camera.fov = 34.0
	capture_camera.current = true
	stage.add_child(capture_camera)
	return stage

func _frame_player(player: Node) -> void:
	var visual_root = player.get("visual_root")
	if visual_root == null:
		return
	var bounds := AABB()
	var has_bounds := false
	for child in visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		if str(mesh_instance.name).contains("Beam") or str(mesh_instance.name).contains("ContactShadow"):
			continue
		var world_bounds: AABB = mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
		bounds = bounds.merge(world_bounds) if has_bounds else world_bounds
		has_bounds = true
	var center := Vector3(0, 1.0, 0)
	var height := 1.8
	if has_bounds:
		center = bounds.get_center()
		height = clampf(bounds.size.y, 1.4, 2.4)
	capture_camera.look_at_from_position(center + Vector3(0, height * 0.06, maxf(height * 1.85, 3.0)), center + Vector3(0, height * 0.04, 0), Vector3.UP)

func _make_contact_sheet() -> void:
	if captures.size() != STATES.size():
		failures += 1
		return
	var width := 1280
	var height := 720
	var sheet := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("0b1013"))
	var panel_width: int = int(width / captures.size())
	for index in range(captures.size()):
		var panel := captures[index].get_region(Rect2i(420, 0, 440, 720))
		panel.resize(panel_width, 576, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(panel, Rect2i(0, 0, panel_width, 576), Vector2i(index * panel_width, 72))
	sheet.save_png(ProjectSettings.globalize_path("%s/ANIM_003_07_Shared_Presentation_Contact_Sheet.png" % OUTPUT_DIR))

func _warm_renderer() -> void:
	var stage := _create_stage()
	await _frames(18)
	root.get_texture().get_image()
	stage.queue_free()
	await _frames(6)

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
