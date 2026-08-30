extends SceneTree

const HUD = preload("res://scripts/hud.gd")

var failures: Array[String] = []
var game: Node
var observed_steps := 0
var observed_footsteps := 0

func _initialize() -> void:
	await _verify_menu_layout()
	await _verify_locomotion_contract()
	if failures.is_empty():
		print("WALK/MENU VERIFIER: PASS")
	else:
		print("WALK/MENU VERIFIER: FAIL")
		for failure in failures:
			print("- %s" % failure)
	quit(1 if not failures.is_empty() else 0)

func _verify_menu_layout() -> void:
	var hud := HUD.new()
	root.add_child(hud)
	await _frames(2)
	hud.show_main_menu()
	await _frames(2)
	_assert(_buttons_fit(hud, hud._menu_viewport_size()), "menu buttons exceed the active viewport safe area")
	_assert(hud.menu_layer.find_child("MenuScroll", true, false) != null, "menu content is not scrollable")
	hud.show_settings_menu("main", 0)
	await _frames(2)
	_assert(hud.menu_layer.find_child("MenuScroll", true, false) != null, "settings content has no scroll container")
	hud.show_main_menu()
	await _frames(1)
	hud.queue_free()
	await _frames(2)

func _buttons_fit(hud: HUD, expected_viewport: Vector2) -> bool:
	for node in hud.menu_layer.find_children("*", "Button", true, false):
		var button := node as Button
		var rect := button.get_global_rect()
		if rect.position.x < -0.5 or rect.position.y < -0.5:
			return false
		if rect.end.x > expected_viewport.x + 0.5 or rect.end.y > expected_viewport.y + 0.5:
			return false
	return true

func _verify_locomotion_contract() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_assert(packed != null, "main scene failed to load")
	if packed == null:
		return
	game = packed.instantiate()
	root.add_child(game)
	await _frames(2)
	if game.has_method("_new_game"):
		game.call("_new_game")
	await _frames(90)
	var player: Node = game.get("player")
	_assert(player != null, "player failed to instantiate")
	if player == null:
		return
	var driver: Node = player.get("animation_driver")
	_assert(driver != null and driver.has_method("set_locomotion"), "player animation driver is missing")
	if driver == null:
		return
	var character_root: Node3D = driver.get("character_root") as Node3D
	_assert(character_root != null, "animation driver has no character root")
	if character_root == null:
		return
	if driver.has_signal("locomotion_step"):
		driver.locomotion_step.connect(_on_test_locomotion_step)
	if player.has_signal("footstep"):
		player.footstep.connect(_on_test_player_footstep)
	var start_position: Vector3 = player.global_position
	observed_steps = 0
	observed_footsteps = 0
	Input.action_press("move_forward")
	await _physics_frames(24)
	var forward_state: String = str(driver.get_locomotion_state())
	var forward_distance: float = player.global_position.distance_to(start_position)
	var forward_steps := observed_steps
	Input.action_release("move_forward")
	_assert(forward_state in ["walk", "run"], "forward input did not select a locomotion gait")
	_assert(forward_distance > 0.08, "forward input did not move the player")
	_assert(forward_steps > 0, "forward animation emitted no foot-contact events")
	var backward_start: Vector3 = player.global_position
	Input.action_press("move_back")
	await _physics_frames(18)
	var backward_state: String = str(driver.get_locomotion_state())
	var backward_distance: float = player.global_position.distance_to(backward_start)
	var backward_steps := observed_steps - forward_steps
	Input.action_release("move_back")
	_assert(backward_state == "walk_back", "backward input did not select walk_back")
	_assert(backward_distance > 0.05, "backward input did not move the player")
	_assert(backward_steps <= 2, "reverse animation emitted duplicate foot-contact events")
	_assert(observed_footsteps == observed_steps, "footstep audio events drifted from animation contacts")
	if is_instance_valid(game):
		game.queue_free()
	await _frames(2)

func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame

func _physics_frames(count: int) -> void:
	for _i in range(count):
		await physics_frame

func _on_test_locomotion_step(_side: StringName) -> void:
	observed_steps += 1

func _on_test_player_footstep() -> void:
	observed_footsteps += 1

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
