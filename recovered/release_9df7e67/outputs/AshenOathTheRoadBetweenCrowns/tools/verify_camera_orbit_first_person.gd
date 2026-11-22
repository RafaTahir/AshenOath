extends SceneTree

const CameraController = preload("res://scripts/camera_controller.gd")
const PlayerController = preload("res://scripts/player_controller.gd")
const InputRouter = preload("res://scripts/input_router.gd")

var failures: Array[String] = []
var stage: Node3D
var controller
var player
var router

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.screen_relative = relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _zoom(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()

func _settle() -> void:
	for frame in range(60):
		controller._process(1.0 / 60.0)
	await process_frame

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var directory := "D:/Temp/AshenOath/camera-orbit-first-person"
	DirAccess.make_dir_recursive_absolute(directory)
	var screenshot := root.get_texture().get_image()
	_check(screenshot.get_size() == Vector2i(1280, 720), "Capture is not 1280x720")
	_check(screenshot.save_png(directory.path_join(label + ".png")) == OK, "Capture failed: " + label)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	stage = Node3D.new()
	root.add_child(stage)
	router = InputRouter.new()
	stage.add_child(router)
	router.set_context("gameplay")
	player = PlayerController.new()
	stage.add_child(player)
	player.set_physics_process(false)
	player.input_source = router
	controller = CameraController.new()
	stage.add_child(controller)
	controller.setup(player, router)
	controller.set_process(false)
	controller.set_enemy_candidates([])
	player.camera_controller = controller
	var environment_node := WorldEnvironment.new()
	environment_node.environment = Environment.new()
	environment_node.environment.background_mode = Environment.BG_COLOR
	environment_node.environment.background_color = Color("687d91")
	environment_node.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_node.environment.ambient_light_color = Color.WHITE
	environment_node.environment.ambient_light_energy = 0.65
	stage.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	stage.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mesh.mesh = plane
	stage.add_child(floor_mesh)
	for index in range(4):
		var landmark := MeshInstance3D.new()
		landmark.mesh = BoxMesh.new()
		landmark.scale = Vector3(1.5, 3, 1.5)
		landmark.position = Basis(Vector3.UP, index * PI * 0.5) * Vector3(0, 1.5, -12)
		var material := StandardMaterial3D.new()
		material.albedo_color = [Color.DARK_RED, Color.DARK_GREEN, Color.GOLDENROD, Color.STEEL_BLUE][index]
		landmark.material_override = material
		stage.add_child(landmark)
	await physics_frame
	router.set_context("menu")
	controller.prepare_view()
	_check(controller.camera.global_position.distance_to(player.global_position) > 4.0, "Covered prewarm camera was left at the origin")
	_check(not router.is_gameplay_context(), "Preparing the view enabled gameplay input")
	router.set_context("gameplay")
	await _settle()
	await _capture("third-person")

	router.show_pointer()
	_key(KEY_W, true)
	_key(KEY_W, false)
	if DisplayServer.get_name() != "headless":
		_check(router.is_pointer_captured(), "Gameplay movement did not recapture the pointer")
	var initial_forward: Vector3 = controller.get_flat_forward()
	for quarter in range(8):
		_motion(Vector2((PI * 0.5) / controller.sensitivity, 0))
		await _settle()
		var expected := Basis(Vector3.UP, -(quarter + 1) * PI * 0.5) * initial_forward
		_check(controller.get_flat_forward().dot(expected) > 0.999, "Manual yaw failed at quarter %d" % quarter)
		var camera_forward: Vector3 = -controller.camera.global_basis.z
		camera_forward.y = 0
		_check(camera_forward.normalized().dot(expected) > 0.95, "Rendered camera failed to orbit at quarter %d" % quarter)

	for click in range(16):
		_zoom(MOUSE_BUTTON_WHEEL_UP)
	await _settle()
	_check(controller.is_first_person(), "Wheel zoom never entered first person")
	var eye: Vector3 = player.global_position + Vector3.UP * player.get_camera_eye_height()
	_check(controller.camera.global_position.distance_to(eye) < 0.01, "First-person camera is not at eye level")
	_check(player._camera_close_view and not player._camera_body_shadows.is_empty(), "Self-occlusion was not applied to the real player body")
	for geometry in player._camera_body_shadows:
		_check(geometry.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "Body/back equipment still occludes first-person camera")
	_check(not player._camera_body_shadows.has(player.rig_sword_visual), "Hand sword was hidden")
	for mesh in player.rig_sword_visual.find_children("*", "GeometryInstance3D", true, false):
		_check(not player._camera_body_shadows.has(mesh), "A hand weapon mesh was hidden with the body")
	controller.pitch = 0
	await _settle()
	await _capture("first-person")
	_motion(Vector2(PI / controller.sensitivity, -100))
	await _settle()
	var expected_look := -(Basis(Vector3.UP, controller.yaw) * Basis(Vector3.RIGHT, controller.pitch)).z
	_check((-controller.camera.global_basis.z).dot(expected_look) > 0.999, "First-person pitch/yaw does not match the rendered view")
	player._face_attack_direction()
	_check((-player.global_basis.z).dot(controller.get_flat_forward()) > 0.999, "First-person melee faces away from the view")
	player.position += Vector3(0.3, 0.5, 0.2)
	controller._process(1.0 / 60.0)
	eye = player.global_position + Vector3.UP * player.get_camera_eye_height()
	_check(controller.camera.global_position.distance_to(eye) < 0.01, "Moving/jumping drags the eye behind the body")
	await _capture("first-person-turned")

	var speaker := Node3D.new()
	speaker.position = Vector3(0, 0, -3)
	stage.add_child(speaker)
	controller.frame_dialogue_target(speaker)
	_check(not player._camera_close_view, "Dialogue did not restore Kael's visible body")
	controller._process(1.0 / 60.0)
	_check(player._camera_close_view, "First-person visibility did not resume after dialogue")
	var yaw_before: float = controller.yaw
	router.set_context("pause")
	_motion(Vector2(500, 0))
	_zoom(MOUSE_BUTTON_WHEEL_DOWN)
	_check(is_equal_approx(controller.yaw, yaw_before) and controller.is_first_person(), "Menu input moved the camera")
	router.set_context("gameplay")
	for click in range(10):
		_zoom(MOUSE_BUTTON_WHEEL_DOWN)
	await _settle()
	_check(not controller.is_first_person() and not player._camera_close_view, "Zooming out did not restore third person")
	await _capture("third-person-restored")
	router.release_pointer()
	controller.free()
	player.asset_helper.clear_runtime_caches()
	stage.queue_free()
	await process_frame
	await process_frame
	for failure in failures:
		push_error(failure)
	print("CAMERA ORBIT / FIRST PERSON: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
