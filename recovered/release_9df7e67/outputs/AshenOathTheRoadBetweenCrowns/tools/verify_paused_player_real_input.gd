extends "res://tools/verify_opening_real_input_native.gd"

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Pause input proof requires a graphical viewport")
		_finish()
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	var game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(3)
	var menu_label := "Continue" if OS.get_cmdline_user_args().has("--continue") else "New Game"
	var focused := root.gui_get_focus_owner() as Button
	for _index in range(8):
		if focused != null and focused.text == menu_label:
			break
		await _tap(KEY_TAB)
		focused = root.gui_get_focus_owner() as Button
	if focused == null or focused.text != menu_label or focused.disabled:
		_fail("%s is not visibly keyboard-focusable" % menu_label)
	else:
		await _tap(KEY_ENTER)
		var deadline := Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < deadline and not (game.game_started and game.player != null and game.player.can_control and not game.zone_transition_pending):
			await process_frame
		if not game.game_started or game.player == null or not game.player.can_control:
			_fail("Real %s did not grant control within the bounded fixture" % menu_label)
		else:
			await _verify_paused_input(game)
	for key in [KEY_W, KEY_A, KEY_X, KEY_ESCAPE, KEY_ENTER]:
		_key(key, false)
	_mouse_button(MOUSE_BUTTON_LEFT, false)
	game.prepare_resource_shutdown()
	await _frames(3)
	game.free()
	await _frames(3)
	print("ACCESS PAUSED PLAYER REAL INPUT: %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	_finish()

func _verify_paused_input(game: Node) -> void:
	await _frames(8)
	_key(KEY_W, true)
	await _frames(12)
	await _tap(KEY_ESCAPE)
	if not paused or game.hud.active_menu != "pause" or not game.hud.menu_layer.visible:
		_fail("Escape did not open a real visible pause menu")
		return
	var position: Vector3 = game.player.global_position
	var velocity: Vector3 = game.player.velocity
	var attack_time: float = game.player.attack_anim_time
	var cooldown: float = game.player.beam_cooldown
	var stamina: float = game.player.stamina_component.stamina
	var camera_yaw: float = game.camera_rig.yaw
	_key(KEY_A, true)
	_key(KEY_X, true)
	_mouse_button(MOUSE_BUTTON_LEFT, true)
	await _frames(45)
	_key(KEY_W, false)
	_key(KEY_A, false)
	_key(KEY_X, false)
	_mouse_button(MOUSE_BUTTON_LEFT, false)
	_check_frozen(game, position, velocity, attack_time, cooldown, stamina, camera_yaw, "pause")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Temp/AshenOath/access001_pause_input.png")
	await _tap(KEY_ESCAPE)
	if paused or game.hud.menu_layer.visible:
		_fail("Escape did not restore gameplay")
		return
	var resumed_position: Vector3 = game.player.global_position
	_key(KEY_W, true)
	await _frames(18)
	_key(KEY_W, false)
	if game.player.global_position.distance_to(resumed_position) < 0.15:
		_fail("Real forward input failed after menu resume")
	await _frames(8)
	var saved: Dictionary = await _save_campaign_checkpoint(game)
	if not bool(saved.get("ok", false)) or not paused or not game.hud.menu_layer.visible:
		_fail("Real keyboard Save did not retain a visible paused menu and valid slot")
		return
	position = game.player.global_position
	velocity = game.player.velocity
	attack_time = game.player.attack_anim_time
	cooldown = game.player.beam_cooldown
	stamina = game.player.stamina_component.stamina
	camera_yaw = game.camera_rig.yaw
	_key(KEY_A, true)
	await _frames(30)
	_key(KEY_A, false)
	_check_frozen(game, position, velocity, attack_time, cooldown, stamina, camera_yaw, "save")
	await _tap(KEY_ESCAPE)
	if paused or game.hud.menu_layer.visible:
		_fail("Saved menu did not resume via Escape")
	if failures.is_empty():
		print("REAL_INPUT paused_player=PASS held_movement_jump_attack_frozen=true save=true resumed=true")
		await _verify_dialogue_pause(game)

func _verify_dialogue_pause(game: Node) -> void:
	await _turn_camera_north(game)
	if game.player.global_position.z < -4.0:
		await _move_until(game, KEY_S, "pause_dialogue_return_lane", func(p: Vector3) -> bool: return p.z > -3.9, 6000)
	else:
		await _move_until(game, KEY_W, "pause_dialogue_anwen_lane", func(p: Vector3) -> bool: return p.z < -3.4, 8000)
	await _move_until(game, KEY_D, "pause_dialogue_anwen_offset", func(p: Vector3) -> bool: return p.x > 1.55, 5000)
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline and (game.active_interactable == null or game.active_interactable.interaction_id != "sister_anwen"):
		await process_frame
	if game.active_interactable == null or game.active_interactable.interaction_id != "sister_anwen":
		_fail("Anwen did not receive physical interaction focus after pause/resume")
		return
	await _tap(KEY_E)
	if not paused or not game.hud.dialogue_layer.visible:
		_fail("Actual Anwen E did not open paused dialogue")
		return
	var position: Vector3 = game.player.global_position
	var velocity: Vector3 = game.player.velocity
	var attack_time: float = game.player.attack_anim_time
	var cooldown: float = game.player.beam_cooldown
	var stamina: float = game.player.stamina_component.stamina
	var camera_yaw: float = game.camera_rig.yaw
	_key(KEY_W, true)
	await _frames(20)
	_key(KEY_W, false)
	_check_frozen(game, position, velocity, attack_time, cooldown, stamina, camera_yaw, "dialogue")
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280, 720):
		_fail("Dialogue capture is not native 1280x720")
	else:
		image.save_png("D:/Temp/AshenOath/access001_anwen_dialogue.png")
	for _page in range(16):
		if not game.hud.dialogue_layer.visible:
			break
		await _tap(KEY_ENTER)
	if game.hud.dialogue_layer.visible or paused:
		_fail("Actual dialogue pagination did not release gameplay")
	else:
		var before: Vector3 = game.player.global_position
		_key(KEY_A, true)
		await _frames(10)
		_key(KEY_A, false)
		if game.player.global_position.distance_to(before) < 0.1:
			_fail("Physical movement did not resume after dialogue")
		elif failures.is_empty():
			print("REAL_INPUT paused_dialogue=PASS anwen_focus=true world_frozen=true keyboard_pages=true resumed=true")

func _check_frozen(game: Node, position: Vector3, velocity: Vector3, attack_time: float, cooldown: float, stamina: float, camera_yaw: float, label: String) -> void:
	if game.zone_root.can_process():
		_fail("%s menu left the active world processing" % label)
	if game.player.can_process() or game.player.stamina_component.can_process():
		_fail("%s menu left the player or child stamina processing" % label)
	for animation_player in game.player.find_children("*", "AnimationPlayer", true, false):
		if animation_player.can_process():
			_fail("%s menu left child animation processing" % label)
	if game.player.global_position.distance_to(position) > 0.001:
		_fail("%s menu allowed player movement: %s -> %s" % [label, position, game.player.global_position])
	if not game.player.velocity.is_equal_approx(velocity):
		_fail("%s menu advanced player velocity" % label)
	if not is_equal_approx(game.player.attack_anim_time, attack_time) or not is_equal_approx(game.player.beam_cooldown, cooldown):
		_fail("%s menu advanced combat state" % label)
	if not is_equal_approx(game.player.stamina_component.stamina, stamina):
		_fail("%s menu advanced child stamina" % label)
	if not is_equal_approx(game.camera_rig.yaw, camera_yaw):
		_fail("%s menu moved the gameplay camera" % label)

func _tap(key: Key) -> void:
	_key(key, true)
	await _frames(2)
	_key(key, false)
	await _frames(4)
