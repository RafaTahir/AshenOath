extends "res://tools/verify_opening_real_input_native.gd"

const EXPECTED_ROLES := ["bandit_deserter", "bandit_tracker"]
var output_dir := "D:/Temp/AshenOath/bandit_road_identity"

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Bandit identity requires a graphical viewport")
		_finish()
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.trim_prefix("--output-dir=")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(output_dir)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(3)
	var focused := false
	for _index in range(8):
		var button := root.gui_get_focus_owner() as Button
		if button != null and button.text == "Continue" and not button.disabled:
			focused = true
			break
		_key(KEY_TAB, true)
		await _frames(2)
		_key(KEY_TAB, false)
		await _frames(3)
	if not focused:
		_fail("Genuine pre-fight Continue is not focusable")
	else:
		_key(KEY_ENTER, true)
		await _frames(3)
		_key(KEY_ENTER, false)
		var deadline := Time.get_ticks_msec() + 45000
		while Time.get_ticks_msec() < deadline:
			if game.game_started and game.current_zone_id == "bandit_road" and not game.zone_transition_pending and game.player.can_control:
				break
			await process_frame
		if not game.game_started or game.current_zone_id != "bandit_road" or game.zone_transition_pending:
			_fail("Genuine pre-fight save did not restore Bandit Road")
	if failures.is_empty():
		game.hud.set_toasts_suppressed(true)
		game.day_night.set_time_lock(true)
		game.day_night.set_time(720.0, game.day_night.day_count)
		var report := {"scope": "actual saved-state bandit spawns; staged camera inspection, not route proof", "roles": []}
		var bandits: Array[Node] = []
		for enemy in game.active_enemies:
			if is_instance_valid(enemy) and enemy.enemy_id == "bandit" and enemy.has_meta("senn_guard"):
				bandits.append(enemy)
		_check(bandits.size() == 2, "Expected two actual Senn guards, found %d" % bandits.size())
		for enemy in bandits:
			enemy.set_physics_process(false)
			enemy.set_process(false)
			var role: String = enemy.visual_role_override
			var mapped := enemy.visual_root.find_child("bandit_visual", true, false) as Node3D
			var skeleton := mapped.find_child("Skeleton3D", true, false) as Skeleton3D if mapped != null else null
			var sword := mapped.find_child("BanditAuthoredSword", true, false) as Node3D if mapped != null else null
			var shield := mapped.find_child("BanditAuthoredShield", true, false) as Node3D if mapped != null else null
			var gear_socket := mapped.find_child("BanditSwordSocket", true, false) as BoneAttachment3D if mapped != null else null
			var shield_socket := mapped.find_child("BanditShieldSocket", true, false) as BoneAttachment3D if mapped != null else null
			_check(EXPECTED_ROLES.has(role), "Unexpected bandit role %s" % role)
			_check(mapped != null, "%s has no mapped body" % role)
			_check(skeleton != null and skeleton.get_bone_count() >= 60, "%s has no Universal skeleton" % role)
			_check(enemy.animation_driver != null and enemy.animation_driver.is_valid(), "%s has no active animation" % role)
			_check(sword != null and gear_socket != null and gear_socket.is_ancestor_of(sword), "%s sword is not on hand socket" % role)
			_check(role != "bandit_tracker" or (shield != null and shield_socket != null and shield_socket.is_ancestor_of(shield)), "Tracker shield is not on hand socket")
			var details := {
				"role": role,
				"source": str(mapped.get_meta("runtime_asset_path", "")) if mapped != null else "",
				"policy": str(mapped.get_meta("runtime_role_state", "")) if mapped != null else "",
				"bones": skeleton.get_bone_count() if skeleton != null else 0,
				"sword_socket": gear_socket.bone_name if gear_socket != null else "",
				"shield_socket": shield_socket.bone_name if shield_socket != null else "",
				"position": str(enemy.global_position),
			}
			report.roles.append(details)
			if mapped != null:
				game.player.global_position = enemy.global_position + Vector3(0, 0, 4.0)
				game.player.velocity = Vector3.ZERO
				enemy.look_at(Vector3(game.player.global_position.x, enemy.global_position.y, game.player.global_position.z), Vector3.UP)
				game.camera_rig.yaw = 0.0
				game.camera_rig.pitch = -0.14
				game.camera_rig._initialized = false
				game.camera_rig._process(1.0 / 60.0)
				game.camera_rig.camera.make_current()
				await _frames(4)
				await RenderingServer.frame_post_draw
				var image: Image = root.get_viewport().get_texture().get_image()
				_check(image != null and image.get_size() == Vector2i(1280, 720), "Invalid %s capture" % role)
				if image != null and image.get_size() == Vector2i(1280, 720):
					var path := output_dir.path_join(role + ".png")
					_check(image.save_png(path) == OK, "Could not save %s capture" % role)
					details["capture"] = path
					details["sha256"] = FileAccess.get_sha256(path)
				game.day_night.set_time(60.0, game.day_night.day_count)
				await _frames(5)
				await RenderingServer.frame_post_draw
				var night_path := output_dir.path_join(role + "_night.png")
				var night_image: Image = root.get_viewport().get_texture().get_image()
				_check(night_image != null and night_image.get_size() == Vector2i(1280, 720)
					and night_image.save_png(night_path) == OK, "Could not save %s night capture" % role)
				details["night_capture"] = night_path
				details["night_sha256"] = FileAccess.get_sha256(night_path)
				game.day_night.set_time(720.0, game.day_night.day_count)
				await _frames(3)
				var review_camera := Camera3D.new()
				review_camera.fov = 55.0
				game.add_child(review_camera)
				review_camera.global_position = enemy.global_position + Vector3(0.0, 1.45, 3.2)
				review_camera.look_at(enemy.global_position + Vector3(0.0, 0.9, 0.0))
				review_camera.make_current()
				await _frames(2)
				await RenderingServer.frame_post_draw
				var close_path := output_dir.path_join(role + "_close.png")
				var close_image: Image = root.get_viewport().get_texture().get_image()
				_check(close_image != null and close_image.get_size() == Vector2i(1280, 720) and close_image.save_png(close_path) == OK, "Could not save %s close capture" % role)
				details["close_capture"] = close_path
				game.camera_rig.camera.make_current()
				review_camera.queue_free()
		var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	await _shutdown_game(game)
	print("BANDIT ROAD IDENTITY: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)
