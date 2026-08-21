extends SceneTree

## QA-012 is the player-route candidate gate. It drives the same InputMap
## actions as a player and observes the normal focus/interaction path. It must
## not call private zone loaders, interaction handlers, teleport the player, or
## mutate StoryState to unlock a route.

const MAX_ROUTE_SECONDS := 38.0
const MAX_DIALOGUE_PAGES := 18
const ROUTE_CLEARANCE := 0.55
const RELEASED_ROUTE := [
	{"from": "greyfen", "to": "wychwood"},
	{"from": "wychwood", "to": "greyfen"},
	{"from": "greyfen", "to": "deep_wood"},
	{"from": "deep_wood", "to": "old_mill"},
	{"from": "old_mill", "to": "burned_farmstead"},
	{"from": "burned_farmstead", "to": "marsh_crossing"},
	{"from": "marsh_crossing", "to": "bandit_road"},
	{"from": "bandit_road", "to": "vargan_approach"},
	{"from": "vargan_approach", "to": "vargan_court"},
	{"from": "vargan_court", "to": "record_hall"},
	{"from": "record_hall", "to": "vargan_court"},
	{"from": "vargan_court", "to": "vargan_approach"},
	{"from": "vargan_approach", "to": "bandit_road"},
	{"from": "bandit_road", "to": "marsh_crossing"},
	{"from": "marsh_crossing", "to": "burned_farmstead"},
	{"from": "burned_farmstead", "to": "old_mill"},
	{"from": "old_mill", "to": "deep_wood"},
	{"from": "deep_wood", "to": "wychwood"},
	{"from": "wychwood", "to": "greyfen"},
]

var failures: Array[String] = []
var game: Node
var route_events: Array[Dictionary] = []

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("QA-012 requires the graphical Compatibility renderer; headless startup cannot prove player input")
		_finish()
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "Main scene is missing")
	if scene == null:
		_finish()
		return
	game = scene.instantiate() as Node
	root.add_child(game)
	await process_frame
	# These two calls only dismiss the launch shell and start a new save. From
	# this point onward every movement, focus, interaction, and gate transition
	# is performed through the real InputMap path below.
	game.call("_on_launch_accepted")
	game.call("_new_game")
	_check(await _wait_for_playable_zone("greyfen", 8.0), "New Game did not become playable")
	if failures.is_empty():
		await _run_opening_route()
	if failures.is_empty():
		await _run_released_gate_route()
	_print_summary()
	_finish()

func _run_opening_route() -> void:
	await _use_interaction("sister_anwen", true)
	await _travel_to("wychwood")
	for clue_id in ["corpse", "black_feathers", "claw_marks"]:
		await _use_interaction(clue_id, false)
	_check(_quest_objective_done("main_road_of_crows", "evidence_ready"), "Three real clue interactions did not reach evidence threshold")
	await _fight_active_enemies("Wychwood pack", 60.0)
	_check(_quest_objective_done("main_road_of_crows", "fight_ghoulkin") or bool(_story_flag("wychwood_pack_cleared", false)), "Wychwood pack did not resolve through combat input")
	await _travel_to("greyfen")
	await _use_interaction("sister_anwen", true)
	_check(str(_story_flag("evidence_report", "")) != "", "Real report interaction did not choose an evidence method")
	_check(_quest_active("main_bell_beneath_greyfen"), "Real report did not open Bell Beneath Greyfen")
	route_events.append({"event": "opening_complete", "zone": str(game.get("current_zone_id"))})

func _run_released_gate_route() -> void:
	for leg in RELEASED_ROUTE:
		var source := str(leg.get("from", ""))
		var destination := str(leg.get("to", ""))
		_check(str(game.get("current_zone_id")) == source, "Route source mismatch before %s -> %s" % [source, destination])
		if not failures.is_empty():
			return
		await _travel_to(destination)
		_check(await _wait_for_playable_zone(destination, 8.0), "Gate did not reach playable %s" % destination)
		route_events.append({"event": "zone_arrival", "from": source, "zone": destination})
	# Story-gated destinations must remain gated until the real preceding quest
	# beats are completed. This is observed, not bypassed, and prevents QA from
	# falsely claiming a complete campaign by setting flags in the verifier.
	_check(not _has_gate_to("undercroft"), "Undercroft gate appeared without the ledger/haunting story beats")
	_check(not _has_gate_to("assembly"), "Assembly gate appeared without Halvern testimony")
	_check(not _has_gate_to("hart_glade"), "Hart gate appeared without the assembly confession")
	route_events.append({
		"event": "story_gates_observed_locked",
		"zone": str(game.get("current_zone_id")),
		"locked": ["undercroft", "assembly", "hart_glade"],
	})

func _travel_to(destination: String) -> void:
	var gate := _find_gate(destination)
	_check(gate != null, "No player-facing gate to %s in %s" % [destination, str(game.get("current_zone_id"))])
	if gate == null:
		return
	await _drive_to(gate.global_position, "gate_%s" % destination)
	if failures.is_empty():
		_check(await _focus_id("gate_%s" % destination, 2.5), "Gate focus did not resolve for %s" % destination)
	if failures.is_empty():
		await _press_action("interact", 2)
		_check(await _wait_for_playable_zone(destination, 10.0), "Gate interaction did not load %s" % destination)

func _use_interaction(id: String, expects_dialogue: bool) -> void:
	var area := _find_interaction(id)
	_check(area != null, "Interaction missing in %s: %s" % [str(game.get("current_zone_id")), id])
	if area == null:
		return
	await _drive_to(area.global_position, id)
	if failures.is_empty():
		_check(await _focus_id(id, 2.5), "Interaction focus did not resolve: %s" % id)
	if failures.is_empty():
		await _press_action("interact", 2)
		await _frames(8)
	if expects_dialogue:
		await _advance_dialogue(id)

func _drive_to(destination: Vector3, label: String) -> void:
	var player := game.get("player") as CharacterBody3D
	var spatial = game.get("spatial_service")
	_check(player != null and spatial != null, "Route services unavailable for %s" % label)
	if player == null or spatial == null:
		return
	var raw_route: Array = spatial.build_route(player.global_position, destination, ROUTE_CLEARANCE)
	_check(not raw_route.is_empty(), "No safe route to %s" % label)
	if raw_route.is_empty():
		return
	var route_started := Time.get_ticks_msec()
	for raw_point in raw_route:
		var point: Vector3 = raw_point
		var point_started := Time.get_ticks_msec()
		while _flat_distance(player.global_position, point) > 0.78:
			if float(Time.get_ticks_msec() - route_started) / 1000.0 > MAX_ROUTE_SECONDS:
				_fail("Player route timed out at %s" % label)
				return
			if float(Time.get_ticks_msec() - point_started) / 1000.0 > 10.0:
				_fail("Player made no progress toward %s" % label)
				return
			await _turn_camera_toward(player.global_position, point)
			var before := player.global_position
			_set_virtual_axes(Vector2(0.0, -1.0), Vector2.ZERO)
			_set_virtual_action("run", true)
			await _frames(4)
			_clear_virtual_input()
			await _frames(1)
			if before.distance_to(player.global_position) < 0.005 and player.is_on_floor():
				await _frames(3)
	_check(_flat_distance(player.global_position, destination) <= 3.8, "Player did not reach %s" % label)

func _turn_camera_toward(origin: Vector3, destination: Vector3) -> void:
	var camera_rig = game.get("camera_rig")
	if camera_rig == null:
		return
	var offset := destination - origin
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		return
	var desired := atan2(-offset.x, -offset.z)
	# Camera orientation is test framing, not movement or progression. The
	# player still reaches the destination through virtual movement axes and the
	# interaction itself is dispatched through InputMap below. Setting the
	# camera directly avoids depending on platform-specific keyboard-repeat
	# timing while keeping the route collision and focus checks real.
	camera_rig.set("yaw", desired)
	await _frames(1)

func _fight_active_enemies(label: String, timeout_seconds: float) -> void:
	var started := Time.get_ticks_msec()
	var player := game.get("player") as CharacterBody3D
	var attack_attempts := 0
	while float(Time.get_ticks_msec() - started) / 1000.0 < timeout_seconds:
		var living: Array[Node] = []
		for enemy in game.get("active_enemies"):
			if enemy == null or not is_instance_valid(enemy):
				continue
			var health = enemy.get("health_component")
			if health != null and float(health.get("health")) > 0.01:
				living.append(enemy)
		if living.is_empty():
			return
		var target: Node3D = living[0] as Node3D
		var offset := target.global_position - player.global_position
		offset.y = 0.0
		# Never route a physics-controlled player to an enemy's center. The
		# enemy capsule is an intentional obstacle, so that request can stall
		# at the exact point where a legal attack approach already exists.
		# Route only a short, same-line step toward the combat body instead.
		# This keeps the player inside the authored clearing even when an enemy
		# is being pushed toward its leash boundary by the encounter AI.
		if offset.length() > 1.75:
			var approach_direction := offset.normalized()
			var step_distance := minf(offset.length() - 1.55, 2.5)
			var approach_point := player.global_position + approach_direction * step_distance
			approach_point.y = player.global_position.y
			await _drive_to(approach_point, "%s attack approach" % label)
		await _turn_camera_toward(player.global_position, target.global_position)
		# Give the controller a brief real forward input so Kael's authored
		# facing follows the target before the contact window begins.
		_set_virtual_axes(Vector2(0.0, -1.0), Vector2.ZERO)
		await _frames(2)
		_clear_virtual_input()
		# Attack immediately after closing distance. Waiting for the moving enemy
		# to remain inside a second distance check caused a chase loop that never
		# delivered the player's mapped mouse attack.
		await _press_action("light_attack", 2)
		attack_attempts += 1
		if attack_attempts % 4 == 0:
			await _press_action("oathfire_beam", 30)
		if int(Time.get_ticks_msec() - started) % 1800 < 60:
			await _press_action("dodge", 2)
		await _frames(5)
	_fail("%s did not resolve before timeout" % label)

func _advance_dialogue(id: String) -> void:
	for _page in range(MAX_DIALOGUE_PAGES):
		var hud = game.get("hud")
		if hud == null or hud.dialogue_layer == null or not bool(hud.dialogue_layer.visible):
			return
		# Focused dialogue buttons are activated by the normal desktop keyboard
		# event. InputEventAction updates polling but does not synthesize the
		# Control-level key event that Button consumes.
		_dispatch_key(KEY_ENTER, true)
		await _frames(6)
		_dispatch_key(KEY_ENTER, false)
		await _frames(2)
	_fail("Dialogue did not close through ui_accept: %s" % id)

func _dispatch_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	event.echo = false
	# A real OS event reaches both the Input singleton and the active viewport.
	# Keep both halves here: gameplay polling sees the former and focused Godot
	# Controls see the latter.
	root.get_viewport().push_input(event)
	Input.parse_input_event(event)

func _dispatch_mouse(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(640.0, 360.0)
	event.button_mask = button if pressed else 0
	root.get_viewport().push_input(event)
	Input.parse_input_event(event)
	var action := &"light_attack" if button == MOUSE_BUTTON_LEFT else &"heavy_attack"
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)

func _wait_for_playable_zone(zone_id: String, timeout_seconds: float) -> bool:
	var started := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started) / 1000.0 <= timeout_seconds:
		var player := game.get("player") as CharacterBody3D
		if str(game.get("current_zone_id")) == zone_id and not bool(game.get("zone_transition_pending")) and player != null and bool(player.get("can_control")):
			return true
		await process_frame
	return false

func _focus_id(id: String, max_distance: float) -> bool:
	for _frame in range(30):
		var focused = game.get("active_interactable")
		if focused != null and is_instance_valid(focused) and str(focused.get("interaction_id")) == id:
			var player := game.get("player") as Node3D
			if player != null and player.global_position.distance_to(focused.global_position) <= max_distance:
				return true
		await process_frame
	return false

func _find_interaction(id: String) -> Area3D:
	var zone_root: Node = game.get("zone_root") as Node
	if zone_root == null:
		return null
	for node in zone_root.find_children("*", "Area3D", true, false):
		if str(node.get("interaction_id")) == id:
			return node as Area3D
	return null

func _find_gate(destination: String) -> Area3D:
	var zone_root: Node = game.get("zone_root") as Node
	if zone_root == null:
		return null
	for node in zone_root.find_children("*", "Area3D", true, false):
		if str(node.get("interaction_type")) == "zone" and str(node.get("zone_target")) == destination:
			return node as Area3D
	return null


func _has_gate_to(destination: String) -> bool:
	return _find_gate(destination) != null

func _press_action(action: StringName, frame_count: int) -> void:
	_dispatch_physical_action(action, true)
	await _frames(frame_count)
	_dispatch_physical_action(action, false)
	_clear_virtual_input()

func _dispatch_physical_action(action: StringName, pressed: bool) -> void:
	match action:
		&"light_attack":
			_dispatch_mouse(MOUSE_BUTTON_LEFT, pressed)
		&"heavy_attack":
			_dispatch_mouse(MOUSE_BUTTON_RIGHT, pressed)
		&"dodge":
			_dispatch_key(KEY_SPACE, pressed)
		&"block":
			_dispatch_key(KEY_Q, pressed)
		&"oathfire_beam":
			_dispatch_key(KEY_C, pressed)
			_dispatch_action(action, pressed)
		_:
			_dispatch_action(action, pressed)

func _dispatch_action(action: StringName, pressed: bool) -> void:
	# Input.action_press changes polling state but does not deliver the
	# InputEvent consumed by game.gd/HUD. Dispatch both so gameplay polling and
	# normal unhandled-input activation are exercised.
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)

func _set_virtual_axes(move_axis: Vector2, look_axis: Vector2) -> void:
	var router = game.get("input_router")
	if router != null and router.has_method("set_virtual_axes"):
		router.set_virtual_axes(move_axis, look_axis)
	else:
		Input.action_press("move_forward" if move_axis.y < -0.5 else "camera_right" if look_axis.x > 0.5 else "camera_left" if look_axis.x < -0.5 else "move_back" if move_axis.y > 0.5 else "move_forward")

func _set_virtual_action(action: StringName, pressed: bool) -> void:
	var router = game.get("input_router")
	if router != null and router.has_method("set_virtual_action"):
		router.set_virtual_action(action, pressed)
	elif pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)

func _clear_virtual_input() -> void:
	var router = game.get("input_router")
	if router != null and router.has_method("clear_virtual_input"):
		router.clear_virtual_input()

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _quest_active(id: String) -> bool:
	var quests = game.get("quests")
	return quests != null and bool(quests.is_active(id))

func _quest_objective_done(quest_id: String, objective_id: String) -> bool:
	var quests = game.get("quests")
	return quests != null and bool(quests.is_objective_done(quest_id, objective_id))

func _story_flag(id: String, fallback: Variant) -> Variant:
	var state = game.get("story_state")
	return state.get_flag(id, fallback) if state != null else fallback

func _angle_delta(from: float, to: float) -> float:
	return fmod(to - from + PI, TAU) - PI

func _flat_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if message in failures:
		return
	failures.append(message)
	push_error(message)

func _print_summary() -> void:
	print("QA-012 ROUTE EVENTS: %s" % JSON.stringify(route_events))
	if failures.is_empty():
		print("QA-012 VERIFIER: PASS")
	else:
		print("QA-012 VERIFIER: FAIL (%d)" % failures.size())
		for failure in failures:
			print("- %s" % failure)

func _finish() -> void:
	_clear_virtual_input()
	Input.action_release("move_forward")
	Input.action_release("move_back")
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("run")
	Input.action_release("interact")
	Input.action_release("ui_accept")
	if game != null and is_instance_valid(game):
		if game.has_method("prepare_resource_shutdown"):
			game.prepare_resource_shutdown()
		await _frames(8)
		game.queue_free()
	await _frames(8)
	quit(0 if failures.is_empty() else 1)
