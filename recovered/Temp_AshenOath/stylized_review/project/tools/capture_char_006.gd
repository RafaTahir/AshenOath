extends SceneTree

const PlayerController = preload("res://scripts/player_controller.gd")

var failures := 0
var stage: Node3D

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("CHAR-006 capture requires a graphical renderer")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Development_Gallery/screenshots"))
	await _warm_renderer()
	stage = _create_stage()
	var player := PlayerController.new()
	stage.add_child(player)
	player.set_physics_process(false)
	await _frames(10)
	var driver = player.get("animation_driver")
	if driver == null or not driver.is_valid():
		failures += 1
		stage.queue_free()
		await _frames(3)
		print("CHAR-006 CAPTURE: FAIL (%d)" % failures)
		quit(1)
		return
	driver.set_distance_suspended(false)
	_set_clip(driver, "Idle", 0.22)
	player.call("_set_sword_sheathed", true)
	_frame_player(player)
	await _frames(18)
	_save("CHAR_006_Kael_Fused_Rig")
	_set_clip(driver, "Sword_Attack", 0.52)
	player.call("_set_sword_sheathed", false)
	player.call("_update_sword_equipment_pose", 0.0, 0.58, 0.0, false, true)
	_frame_player(player)
	await _frames(8)
	if driver.get_animation_player().callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		driver.get_animation_player().advance(0.0)
	player.call("_update_sword_equipment_pose", 0.0, 0.58, 0.0, false, true)
	_save("CHAR_006_Kael_Sword_Attack")
	stage.queue_free()
	await _frames(3)
	print("CHAR-006 CAPTURE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _set_clip(driver: Node, clip_name: StringName, fraction: float) -> void:
	var animation_player := driver.get_animation_player() as AnimationPlayer
	if animation_player == null or not animation_player.has_animation(clip_name):
		failures += 1
		return
	animation_player.play(clip_name)
	var animation := animation_player.get_animation(clip_name)
	if animation != null:
		animation_player.seek(animation.length * fraction, true)
	if animation_player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		animation_player.advance(0.0)

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
	var camera := stage.get_node_or_null("Camera3D") as Camera3D
	if camera != null:
		camera.look_at_from_position(center + Vector3(0, height * 0.06, -maxf(height * 1.85, 3.0)), center + Vector3(0, height * 0.04, 0), Vector3.UP)

func _create_stage() -> Node3D:
	var result := Node3D.new()
	root.add_child(result)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("10171b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a8a39a")
	environment.ambient_light_energy = 0.95
	world.environment = environment
	result.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34, -28, 0)
	key.light_color = Color("ffe0bd")
	key.light_energy = 1.85
	result.add_child(key)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("312b24")
	ground_material.roughness = 0.92
	ground.material_override = ground_material
	result.add_child(ground)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.22, -3.45)
	camera.look_at_from_position(camera.position, Vector3(0, 1.04, 0), Vector3.UP)
	camera.fov = 34.0
	camera.current = true
	result.add_child(camera)
	return result

func _warm_renderer() -> void:
	var warm_stage := _create_stage()
	var warm_player := PlayerController.new()
	warm_stage.add_child(warm_player)
	warm_player.set_physics_process(false)
	await _frames(18)
	root.get_texture().get_image()
	warm_stage.queue_free()
	await _frames(6)

func _play_all(root_node: Node, clip: StringName) -> void:
	for player in root_node.find_children("*", "AnimationPlayer", true, false):
		if player.has_animation(clip):
			player.play(clip)

func _find_named(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var found := _find_named(child, name)
		if found != null:
			return found
	return null

func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720) or not _has_actor_pixels(image):
		failures += 1
		push_error("CHAR-006 capture produced no visible actor pixels for %s" % name)
		return
	image.save_png(ProjectSettings.globalize_path("res://Development_Gallery/screenshots/%s.png" % name))
	print("CAPTURED %s" % name)

func _has_actor_pixels(image: Image) -> bool:
	# The stage background and ground are intentionally nonblank, so inspect the
	# central character envelope rather than accepting a background-only frame.
	var changed := 0
	for y in range(70, 650, 10):
		for x in range(430, 850, 10):
			var pixel := image.get_pixel(x, y)
			if pixel.r + pixel.g + pixel.b > 0.42:
				changed += 1
				if changed >= 18:
					return true
	return false

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
