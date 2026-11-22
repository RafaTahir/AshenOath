extends SceneTree

var player
var router
var inventory
var stage: Node3D
var camera: Camera3D
var records: Array = []
var shots := 0
var label := "before"
var camera_rig

func _initialize() -> void:
	if not OS.get_cmdline_user_args().is_empty(): label = OS.get_cmdline_user_args()[0]
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	stage = Node3D.new()
	root.add_child(stage)
	router = load("res://scripts/input_router.gd").new()
	stage.add_child(router)
	router.set_context("gameplay")
	inventory = load("res://scripts/inventory_manager.gd").new()
	stage.add_child(inventory)
	inventory.load_items("res://data/items.json")
	player = load("res://scripts/player_controller.gd").new()
	stage.add_child(player)
	player.input_source = router
	player.bind_inventory(inventory)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20, 0.5, 20)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.25
	stage.add_child(floor_body)
	player.arrow_requested.connect(func(_request): shots += 1)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("526575")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	stage.add_child(light)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(2.2, 1.65, -2.4)
	camera.look_at(Vector3(0, 1.15, -0.2))
	camera.current = true
	await _frames(3)
	for mesh in player.bow_presentation.arrow.find_children("*", "MeshInstance3D", true, false):
		print("NOCKED_ARROW_BOUNDS ", player.bow_visual.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb())
	player._request_equipment("bow", "steel", true)
	await _frames(65)
	if label == "original":
		var original = load(player.MODELED_BOW_PATH).instantiate()
		for limb in player.bow_presentation.limbs:
			for mesh in original.find_children("*", "MeshInstance3D", true, false):
				if mesh.name == limb.name:
					print("BOW_GEOMETRY ", mesh.name, " original=", mesh.mesh.get_aabb(), " modified=", limb.mesh.get_aabb(), " format=", mesh.mesh.surface_get_format(0))
					limb.mesh = mesh.mesh
		player.bow_presentation.limbs.clear()
		original.free()
	await _record("equipped")
	_mouse(MOUSE_BUTTON_RIGHT, true)
	await _frames(40)
	await _record("aim")
	_mouse(MOUSE_BUTTON_LEFT, true)
	await _frames(22)
	await _record("partial")
	await _frames(70)
	await _record("full")
	_mouse(MOUSE_BUTTON_LEFT, false)
	await _frames(20)
	await _record("release")
	_mouse(MOUSE_BUTTON_LEFT, true)
	await _frames(30)
	_mouse(MOUSE_BUTTON_RIGHT, false)
	await _frames(2)
	_mouse(MOUSE_BUTTON_LEFT, false)
	await _frames(25)
	await _record("cancel")
	player.set_camera_close_view(true)
	camera_rig = load("res://scripts/camera_controller.gd").new()
	stage.add_child(camera_rig)
	camera_rig.setup(player, router)
	camera_rig.set_enemy_candidates([])
	camera_rig.distance = 0.0
	camera_rig.pitch = 0.0
	player.camera_controller = camera_rig
	camera = camera_rig.camera
	_mouse(MOUSE_BUTTON_RIGHT, true)
	await _frames(40)
	_mouse(MOUSE_BUTTON_LEFT, true)
	await _frames(85)
	await _record("first-person-full")
	_mouse(MOUSE_BUTTON_LEFT, false)
	await _frames(20)
	await _record("first-person-release")
	print("BOW_REPAIR_CHECK ", JSON.stringify({"label":label,"shots":shots,"arrows":inventory.items.standard_arrow,"poses":records}))
	router.clear_virtual_input()
	player.asset_helper.clear_runtime_caches()
	stage.queue_free()
	await process_frame
	await process_frame
	quit()

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame

func _mouse(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _record(phase: String) -> void:
	await RenderingServer.frame_post_draw
	var pose = player.bow_presentation
	var rig: Skeleton3D = pose.get_skeleton()
	var row := {"phase":phase,"draw":player.bow_draw_time,"aim":player.bow_pose_aim,"bow_scale":player.bow_visual.global_basis.get_scale(),"grip":pose.grip,"hands":{}}
	for side: String in ["l", "r"]:
		row.hands[side] = pose._world(rig,rig.find_bone("hand_"+side))
	records.append(row)
	root.get_texture().get_image().save_png("D:/Temp/AshenOath/bow-%s-%s.png" % [label,phase])
