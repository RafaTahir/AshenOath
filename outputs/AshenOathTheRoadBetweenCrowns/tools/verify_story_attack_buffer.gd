extends SceneTree
## Real InputRouter edges and production controller timers, without model/world
## loading. Synthetic device events prove dispatch, not physical hardware.
const InputRouter = preload("res://scripts/input_router.gd")
const Player = preload("res://scripts/player_controller.gd")
const Settings = preload("res://scripts/settings_manager.gd")
const STEP := 1.0 / 60.0

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

class Controller extends Player:
	func _ready() -> void:
		set_physics_process(false)
		set_process(false)
		health_component = HealthComponent.new()
		stamina_component = StaminaComponent.new()
		add_child(health_component)
		add_child(stamina_component)
		stamina_component.process_mode = Node.PROCESS_MODE_DISABLED
		equipment_loadout.set_sword_drawn(true)
	func _handle_movement(_delta: float) -> void:
		pass
	func _update_blade_contact() -> void:
		pass

var failures: Array[String] = []
var checks := 0
var router: Node
var player: Controller
var settings: Node
var error_log := ErrorLog.new()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	OS.add_logger(error_log)
	router = InputRouter.new()
	settings = Settings.new()
	# Read definitions without adding Settings to the tree or reading/writing
	# user preferences. The production difficulty API supplies all three profiles.
	root.add_child(router)
	router.set_physics_process(false)
	player = Controller.new()
	root.add_child(player)
	player.input_source = router
	# Same context cancellation callback owned by session_service in production.
	router.input_context_changed.connect(func(_context: String): player.cancel_buffered_input("context_change"))
	router.set_gameplay_context()
	await _tick()
	for difficulty: String in ["story", "standard", "veteran"]:
		for lead: float in [0.20, 0.14, 0.28]:
			await _verify_sequence(difficulty, lead, false, lead == 0.14 or (difficulty == "story" and lead == 0.20))
	await _verify_sequence("story", 0.20, true, true)
	await _verify_context_cancellation()
	router.clear_virtual_input()
	settings.free()
	player.free()
	router.free()
	OS.remove_logger(error_log)
	_check(error_log.errors.is_empty(), "No engine or script errors during input verification")
	print("STORY ATTACK BUFFER: %s checks=%d real_router_edges=true" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _tick() -> void:
	await physics_frame
	# Own both clocks in one physics frame. A delayed render frame may contain
	# several engine physics ticks; an automatic router would consume the edge
	# before a manually stepped controller could observe that same snapshot.
	router._physics_process(STEP)
	player._physics_process(STEP)

func _mouse(heavy: bool, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT if heavy else MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _reset(difficulty: String, lead: float) -> void:
	player.cancel_buffered_input("fixture_reset")
	settings.settings["difficulty"] = difficulty
	player.apply_difficulty_profile(settings.get_difficulty_profile())
	player.equipment_loadout.set_sword_drawn(true)
	player.stamina_component.stamina = 100.0
	# _physics_process first consumes STEP; the actual input edge is queued with
	# exactly lead seconds of recovery left, rather than manually seeding a buffer.
	player.attack_cooldown = lead + STEP

func _verify_sequence(difficulty: String, lead: float, heavy: bool, expected: bool) -> void:
	_reset(difficulty, lead)
	var label := "%s %.2fs %s" % [difficulty, lead, "heavy" if heavy else "light"]
	var sequence := player.attack_sequence_id
	_mouse(heavy, true)
	await _tick()
	_check(player.buffered_attack == ("heavy" if heavy else "light"), label + ": real press creates the buffer")
	_check(is_equal_approx(player.attack_buffer_time, player.get_attack_buffer_duration()), label + ": timer uses the live difficulty profile")
	_mouse(heavy, false)
	for index in ceili((lead + 0.12) / STEP):
		await _tick()
	_check(player.attack_sequence_id == sequence + (1 if expected else 0), label + ": expected follow-up count")
	_check(is_equal_approx(player.stamina_component.stamina, 78.0 if heavy and expected else 100.0), label + ": stamina charged exactly once at execution")
	# A released edge cannot repeat after a full recovery, including heavy cost.
	if heavy:
		for index in 50:
			await _tick()
		_check(player.attack_sequence_id == sequence + 1 and is_equal_approx(player.stamina_component.stamina, 78.0), label + ": no repeated attack/cost after recovery")

func _verify_context_cancellation() -> void:
	_reset("story", 0.20)
	var sequence := player.attack_sequence_id
	_mouse(true, true)
	await _tick()
	_check(player.buffered_attack == "heavy", "Context fixture queues a real heavy press")
	router.begin_context("pause")
	_check(player.buffered_attack == "" and player.attack_buffer_time == 0.0, "Menu context clears the queued attack")
	_mouse(true, false)
	await _tick()
	router.set_gameplay_context()
	for index in 30:
		await _tick()
	_check(player.attack_sequence_id == sequence and is_equal_approx(player.stamina_component.stamina, 100.0), "Resume does not execute or charge a cancelled press")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
