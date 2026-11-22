extends SceneTree

const InputRouter = preload("res://scripts/input_router.gd")
const Player = preload("res://scripts/player_controller.gd")
const Camera = preload("res://scripts/camera_controller.gd")

# Isolated input-dispatch proof, not physical controller or player-route proof.
class CombatProbe extends Player:
	var beam_requests := 0
	var arrow_requests := 0
	func _ready() -> void:
		set_physics_process(false)
	func _handle_beam_input() -> void:
		if _action_just_pressed("oathfire_beam"):
			beam_requests += 1
	func _release_bow() -> void:
		arrow_requests += 1

class CameraProbe extends Camera:
	func _ready() -> void:
		set_process(false)

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var router := InputRouter.new()
	root.add_child(router)
	router.set_gameplay_context()
	var player := CombatProbe.new()
	root.add_child(player)
	player.input_source = router
	var camera := CameraProbe.new()
	root.add_child(camera)
	camera.input_source = router
	camera.target = player
	await process_frame
	player._set_weapon_mode("bow")
	_button(JOY_BUTTON_Y, true)
	player._handle_combat_input()
	_check(player.weapon_mode == "bow", "Jump button also changes the active weapon")
	_check(Input.is_action_pressed("jump"), "Y no longer activates jump")
	_button(JOY_BUTTON_Y, false)
	await process_frame
	player._set_weapon_mode("sword")
	_button(JOY_BUTTON_X, true)
	player._handle_combat_input()
	_check(player.weapon_mode == "bow", "Weapon button does not select bow")
	_button(JOY_BUTTON_X, false)
	await process_frame
	_button(JOY_BUTTON_X, true)
	player._handle_combat_input()
	_check(player.weapon_mode == "sword", "Weapon button cannot return to sword without keyboard")
	_button(JOY_BUTTON_X, false)
	await process_frame
	player._set_weapon_mode("bow")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	player._handle_combat_input()
	_check(player.weapon_mode == "bow" and player.bow_aiming, "Bow aim switches to sword instead of remaining aimed")
	_check(player.beam_requests == 0, "Bow trigger also requests Oathfire")
	await process_frame
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	player._handle_combat_input()
	_check(player.arrow_requests == 1 and player.weapon_mode == "bow", "RT does not dispatch an aimed bow shot")
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await process_frame
	_button(JOY_BUTTON_DPAD_UP, true)
	var distance: float = camera.distance
	camera._apply_keyboard_camera(0.1)
	_check(is_equal_approx(distance, camera.distance), "Arrow selection also changes camera zoom")
	_button(JOY_BUTTON_DPAD_UP, false)
	await process_frame
	player._set_weapon_mode("sword")
	_button(JOY_BUTTON_DPAD_UP, true)
	distance = camera.distance
	camera._apply_keyboard_camera(0.1)
	_check(not is_equal_approx(distance, camera.distance), "Sword-mode controller zoom stopped working")
	_button(JOY_BUTTON_DPAD_UP, false)
	await process_frame
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	player._handle_combat_input()
	_check(player.beam_requests == 1, "Sword-mode Oathfire trigger stopped working")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await process_frame
	_key(KEY_2, true)
	player._handle_combat_input()
	_check(player.weapon_mode == "bow", "Keyboard 2 no longer selects bow")
	_key(KEY_2, false)
	await process_frame
	_key(KEY_C, true)
	player._handle_combat_input()
	_check(player.weapon_mode == "sword" and player.beam_requests == 2, "Separate keyboard Oathfire cannot cancel bow")
	_key(KEY_C, false)
	await process_frame
	_key(KEY_1, true)
	player._handle_combat_input()
	_check(player.weapon_mode == "sword", "Keyboard 1 no longer selects sword")
	_key(KEY_1, false)
	print("ACCESS WEAPON CONTEXT: %s - physical devices detected=%d (synthetic events are not hardware certification)" % ["PASS" if failures.is_empty() else "FAIL", Input.get_connected_joypads().size()])
	for failure in failures:
		print("- " + failure)
	camera.free()
	player.free()
	router.free()
	quit(0 if failures.is_empty() else 1)

func _button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
