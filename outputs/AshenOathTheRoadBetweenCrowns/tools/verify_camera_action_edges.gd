extends SceneTree

## Actual Router/Camera discrete actions across mismatched clocks. Only view
## framing is stubbed; input snapshots, lock acquisition, LOS and zoom are real.
## --legacy-source <old camera .gd> runs the same checks on preserved old source.
const Router = preload("res://scripts/input_router.gd")
const STEP := 1.0 / 60.0

class FixtureCamera extends "res://scripts/camera_controller.gd":
	func _update_response_state(_delta: float) -> void:
		pass
	func _update_view(_delta: float) -> void:
		pass

class Actor extends Node3D:
	var dead := false
	func is_encounter_active() -> bool:
		return true

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

var checks := 0
var failures: Array[String] = []
var router: Node
var rig: Node3D
var first: Actor
var second: Actor
var transitions := 0
var legacy_source := ""
var error_log := ErrorLog.new()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	OS.add_logger(error_log)
	var args := OS.get_cmdline_user_args()
	if "--legacy-source" in args:
		legacy_source = args[args.find("--legacy-source") + 1]
	router = Router.new()
	root.add_child(router)
	router.set_physics_process(false)
	var player := Node3D.new()
	root.add_child(player)
	first = Actor.new()
	first.position = Vector3(0, 0, -2)
	root.add_child(first)
	second = Actor.new()
	second.position = Vector3(2, 0, -2)
	root.add_child(second)
	if legacy_source.is_empty():
		rig = FixtureCamera.new()
	else:
		# Load the exact preserved old implementation, overriding only the same
		# nonessential view/framing operations as the current-source fixture.
		var wrapper := GDScript.new()
		wrapper.source_code = "extends %s\nfunc _update_response_state(_delta: float) -> void:\n\tpass\nfunc _update_view(_delta: float) -> void:\n\tpass\n" % JSON.stringify(legacy_source.replace("\\", "/"))
		if wrapper.reload() != OK:
			quit(2)
			return
		rig = wrapper.new()
	root.add_child(rig)
	rig.setup(player, router)
	rig.set_process(false)
	rig.set_physics_process(false)
	rig.set_enemy_candidates([first, second])
	rig.target_lock_changed.connect(func(_actor: Node3D, _locked: bool): transitions += 1)
	_check(router.process_physics_priority < rig.process_physics_priority, "Router must publish snapshots before Camera's physics callback")
	for touch: bool in [false, true]:
		for steps: int in [1, 2, 4]:
			for renders: int in [1, 3]:
				await _cadence_case(touch, steps, renders)
		await _guard_case(touch, true)
		await _guard_case(touch, false)
	await _continuous_look_case()
	await _los_case()
	router.clear_virtual_input()
	rig.free()
	first.free()
	second.free()
	player.free()
	router.free()
	OS.remove_logger(error_log)
	_check(error_log.errors.is_empty(), "No engine/script errors: " + str(error_log.errors))
	for failure: String in failures:
		printerr(failure)
	print("CAMERA ACTION EDGES: %s checks=%d legacy_source=%s (actual Router/Camera; 1/2/4 physics steps per render, 1/3 renders per snapshot; keyboard/touch; hold/release/cycle/zoom/pause/context/LOS)" % ["PASS" if failures.is_empty() else "FAIL", checks, legacy_source])
	quit(0 if failures.is_empty() else 1)

func _frames(steps: int = 1, renders: int = 1) -> void:
	for _index in steps:
		await physics_frame
		router._physics_process(STEP)
		if rig.has_method("_physics_process"):
			rig._physics_process(STEP)
	for _index in renders:
		rig._process(STEP * float(steps) / float(renders))

func _input(action: StringName, pressed: bool, touch: bool) -> void:
	if touch:
		# This is the production MobileTouchControls -> Router ownership API;
		# synthetic dispatch verifies code behavior, not physical touch hardware.
		router.set_virtual_action(action, pressed)
	else:
		var event := InputEventKey.new()
		event.keycode = Router.KEYBOARD_BINDINGS[str(action)]
		event.physical_keycode = event.keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func _reset() -> void:
	rig.clear_target_lock()
	router.clear_virtual_input()
	router.reset_transient_input("fixture_reset")
	router.set_gameplay_context()
	rig.yaw = 0.0
	rig.distance = 6.8
	await _frames(2)
	transitions = 0

func _cadence_case(touch: bool, steps: int, renders: int) -> void:
	await _reset()
	var label := "%s physics%d/render%d" % ["touch" if touch else "keyboard", steps, renders]
	_input(&"target_lock", true, touch)
	await _frames(steps, renders)
	_check(transitions == 1 and rig.get_locked_combat_target() == first, label + ": one press must acquire the nearest visible target")
	for _group in 4:
		await _frames(steps, renders)
	_check(transitions == 1 and rig.get_locked_combat_target() == first, label + ": holding must not toggle a second time")
	_input(&"target_lock", false, touch)
	await _frames(steps, renders)
	_check(transitions == 1, label + ": release must not toggle")
	_input(&"target_next", true, touch)
	await _frames(steps, renders)
	_check(transitions == 2 and rig.get_locked_combat_target() == second, label + ": next-target edge must survive catch-up ticks exactly once")
	_input(&"target_next", false, touch)
	await _frames(steps, renders)
	_input(&"target_previous", true, touch)
	await _frames(steps, renders)
	_check(transitions == 3 and rig.get_locked_combat_target() == first, label + ": previous-target edge must survive catch-up ticks exactly once")
	_input(&"target_previous", false, touch)
	await _frames(steps, renders)
	_input(&"target_lock", true, touch)
	await _frames(steps, renders)
	_check(transitions == 4 and rig.get_locked_combat_target() == null, label + ": second lock press must unlock exactly once")
	_input(&"target_lock", false, touch)
	await _frames(steps, renders)
	if touch:
		var before: float = rig.distance
		_input(&"camera_zoom_in", true, true)
		await _frames(steps, renders)
		_check(is_equal_approx(rig.distance, before - rig.ZOOM_STEP), label + ": one touch zoom edge must apply one authored step")
		for _group in 3:
			await _frames(steps, renders)
		_check(is_equal_approx(rig.distance, before - rig.ZOOM_STEP), label + ": held touch zoom must not add steps")
		_input(&"camera_zoom_in", false, true)
		await _frames(steps, renders)

func _guard_case(touch: bool, paused: bool) -> void:
	await _reset()
	if paused:
		self.paused = true
	else:
		router.set_ui_context(Router.CONTEXT_DIALOGUE)
	_input(&"target_lock", true, touch)
	await _frames(4, 3)
	_check(transitions == 0 and rig.get_locked_combat_target() == null, "Pause/UI context must block discrete camera actions")
	_input(&"target_lock", false, touch)
	await _frames(2)
	self.paused = false
	router.set_gameplay_context()
	await _frames(2, 3)
	_check(transitions == 0, "Resume must not replay a guarded camera edge")

func _continuous_look_case() -> void:
	await _reset()
	_input(&"camera_right", true, false)
	await physics_frame
	router._physics_process(STEP)
	if rig.has_method("_physics_process"):
		rig._physics_process(STEP)
	_check(is_equal_approx(rig.yaw, 0.0), "Physics action dispatch must not move continuous camera look")
	rig._process(STEP)
	_check(rig.yaw < 0.0, "Continuous keyboard look must remain render-driven")
	_input(&"camera_right", false, false)
	await _frames(2)

func _los_case() -> void:
	await _reset()
	rig.set_enemy_candidates([first])
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 3, 0.2)
	collision.shape = box
	wall.add_child(collision)
	wall.position = Vector3(0, 1.0, -1)
	root.add_child(wall)
	await _frames(2)
	_input(&"target_lock", true, false)
	await _frames(4)
	_check(transitions == 0 and rig.get_locked_combat_target() == null, "Actual world LOS must still reject an obstructed target")
	_input(&"target_lock", false, false)
	await _frames(2)
	wall.free()
	await _frames(2)
	_input(&"target_lock", true, false)
	await _frames(4)
	_check(transitions == 1 and rig.get_locked_combat_target() == first, "The same real target must lock after the world obstruction is removed")
	_input(&"target_lock", false, false)
	await _frames(2)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
