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
	func bow_has_arrow() -> bool:
		return true

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
	await _button(JOY_BUTTON_Y, true)
	player._handle_combat_input()
	_check(player.weapon_mode == "bow", "Jump button also changes the active weapon")
	_check(Input.is_action_pressed("jump"), "Y no longer activates jump")
	await _button(JOY_BUTTON_Y, false)
	await process_frame
	player._set_weapon_mode("sword")
	await _button(JOY_BUTTON_X, true)
	player._handle_combat_input()
	await _button(JOY_BUTTON_X, false)
	await process_frame
	player._handle_combat_input()
	_settle_equipment(player)
	_check(player.weapon_mode == "sword" and player.get_selected_blade_id() == "oathblade", "First weapon tap must select Oathblade")
	await _button(JOY_BUTTON_X, true)
	player._handle_combat_input()
	await _button(JOY_BUTTON_X, false)
	await process_frame
	player._handle_combat_input()
	_settle_equipment(player)
	_check(player.weapon_mode == "bow", "Second weapon tap must select bow")
	player._set_weapon_mode("bow")
	await _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	player._handle_combat_input()
	_check(player.weapon_mode == "bow" and player.bow_aiming, "Bow aim switches to sword instead of remaining aimed")
	_check(player.beam_requests == 0, "Bow trigger also requests Oathfire")
	await process_frame
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	for index in range(8):
		player._handle_combat_input()
		await process_frame
	_check(player.arrow_requests == 0 and player.bow_drawing, "Held RT must draw rather than fire immediately")
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	player._handle_combat_input()
	_check(player.arrow_requests == 1 and player.weapon_mode == "bow", "Released RT does not dispatch the drawn bow shot")
	await _axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await process_frame
	await _button(JOY_BUTTON_DPAD_UP, true)
	var distance: float = camera.distance
	camera._apply_keyboard_camera(0.1)
	_check(is_equal_approx(distance, camera.distance), "Arrow selection also changes camera zoom")
	await _button(JOY_BUTTON_DPAD_UP, false)
	await process_frame
	player._set_weapon_mode("sword")
	await _button(JOY_BUTTON_DPAD_UP, true)
	distance = camera.distance
	camera._apply_keyboard_camera(0.1)
	_check(not is_equal_approx(distance, camera.distance), "Sword-mode controller zoom stopped working")
	await _button(JOY_BUTTON_DPAD_UP, false)
	await process_frame
	await _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	player._handle_combat_input()
	_check(player.beam_requests == 1, "Sword-mode Oathfire trigger stopped working")
	await _axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await process_frame
	await _key(KEY_2, true)
	player._handle_combat_input()
	_settle_equipment(player)
	_check(player.weapon_mode == "bow", "Keyboard 2 no longer selects bow")
	await _key(KEY_2, false)
	await process_frame
	await _key(KEY_C, true)
	player._handle_combat_input()
	_check(player.beam_requests == 2, "Separate keyboard Oathfire was not dispatched from bow context")
	await _key(KEY_C, false)
	await process_frame
	await _key(KEY_1, true)
	player._handle_combat_input()
	_settle_equipment(player)
	_check(player.weapon_mode == "sword", "Keyboard 1 no longer selects sword")
	await _key(KEY_1, false)
	print("ACCESS WEAPON CONTEXT: %s - physical devices detected=%d (synthetic events are not hardware certification)" % ["PASS" if failures.is_empty() else "FAIL", Input.get_connected_joypads().size()])
	for failure in failures:
		print("- " + failure)
	camera.free()
	player.free()
	router.free()
	quit(0 if failures.is_empty() else 1)

func _settle_equipment(player: Node) -> void:
	# The probe owns its clock; normal actors advance this from physics.
	for index in range(4):
		player.equipment_loadout.advance_transition(0.7)

func _button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await physics_frame
	await process_frame

func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await physics_frame
	await process_frame

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await physics_frame
	await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
