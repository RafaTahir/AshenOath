extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var output_dir := OUTPUT_DIR
var failures := 0
var timestamp := ""

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("WORLD-013 capture requires a graphical renderer")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir=res://.release-gate/"):
			output_dir = argument.trim_prefix("--output-dir=")
	timestamp = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		push_error("Main scene unavailable")
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(2)
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	if not await _wait_for_zone(game, "greyfen"):
		await _release_game(game)
		quit(1)
		return
	game.hud.set_toasts_suppressed(true)
	game.quests.start_quest("main_road_of_crows")
	game.quests.complete_objective("main_road_of_crows", "speak_anwen")
	game.hud.set_toasts_suppressed(false)
	game.call("_load_zone", "wychwood", Vector3(0, 1, 12.5))
	if not await _wait_for_zone(game, "wychwood"):
		await _release_game(game)
		quit(1)
		return
	await _frames(18)
	if "--night-combat" in OS.get_cmdline_user_args():
		game.day_night.set_time_lock(true)
		game.day_night.set_time(0.0)
		game.player.global_position = Vector3(0, 0.9, -2.4)
		await _frames(24)
		await _capture(game, "WORLD-013_05_Wychwood_Night_Combat", Vector3(6.0, 3.0, -0.5), Vector3(0, 1.0, -7.0))
		print("WORLD-013 NIGHT SCREENSHOT: %s (staged art fixture, not real-input progression)" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		await _release_game(game)
		quit(0 if failures == 0 else 1)
		return
	if "--bridge-only" in OS.get_cmdline_user_args():
		await _capture(game, "WORLD-013_03_Wychwood_Bridge_Canopy", Vector3(6.2, 3.2, 7.0), Vector3(0, 0.9, 0.0))
		print("WORLD-013 BRIDGE: %s (staged art fixture, not real-input progression)" % ("PASS" if failures == 0 else "FAIL"))
		await _release_game(game)
		quit(0 if failures == 0 else 1)
		return
	if "--arena-review" in OS.get_cmdline_user_args():
		game.player.global_position = Vector3(0, 0.9, -2.4)
		await _frames(3)
		var review_enemy: Node3D = null
		for enemy in game.active_enemies:
			if is_instance_valid(enemy) and not enemy.dead and enemy.enemy_id == "ghoulkin":
				review_enemy = enemy
				break
		if review_enemy == null:
			failures += 1
			push_error("No actual Ghoulkin was available for arena review")
		else:
			review_enemy.set_physics_process(false)
			var floor_ray := PhysicsRayQueryParameters3D.create(Vector3(0, 3, -6.5), Vector3(0, -3, -6.5), 1)
			if review_enemy is CollisionObject3D:
				floor_ray.exclude = [(review_enemy as CollisionObject3D).get_rid()]
			var floor_hit: Dictionary = game.zone_root.get_world_3d().direct_space_state.intersect_ray(floor_ray)
			if floor_hit.is_empty():
				failures += 1
				push_error("Arena review has no physical floor at the established actor location")
			else:
				review_enemy.global_position = floor_hit.position
		await _capture(game, "WORLD-013_06_Wychwood_Arena_Day_Review", Vector3(4.1, 2.7, -1.7), Vector3(0, 0.9, -6.5))
		game.day_night.set_time_lock(true)
		game.day_night.set_time(0.0)
		await _frames(24)
		await _capture(game, "WORLD-013_07_Wychwood_Arena_Night_Review", Vector3(4.1, 2.7, -1.7), Vector3(0, 0.9, -6.5))
		print("WORLD-013 ARENA REVIEW: %s (frozen staged art fixture, not combat or real-input proof)" % ("PASS" if failures == 0 else "FAIL"))
		await _release_game(game)
		quit(0 if failures == 0 else 1)
		return
	# Face back toward the return gate from inside Wychwood. The previous yaw
	# framed the bridge rail behind Kael and falsely read as a blocked gateway.
	await _capture(game, "WORLD-013_01_Wychwood_Gate_Arch", Vector3(0.0, 3.0, 16.5), Vector3(0, 1.25, 12.0))
	if not "--gate-only" in OS.get_cmdline_user_args():
		await _capture(game, "WORLD-013_02_Wychwood_Clue_Route", Vector3(3.8, 2.8, 11.0), Vector3(0, 0.5, 8.4))
		await _capture(game, "WORLD-013_03_Wychwood_Bridge_Canopy", Vector3(6.2, 3.2, 7.0), Vector3(0, 0.9, 0.0))
		game.player.global_position = Vector3(0, 0.9, -2.4)
		await _capture(game, "WORLD-013_04_Wychwood_Combat_Clearing", Vector3(6.0, 3.0, -0.5), Vector3(0, 1.0, -7.0))
	else:
		game.player.global_position = Vector3(0, 1.0, -2.4)
		for _attempt in range(90):
			if bool(game.tutorial_flags.get("combat", false)) and game.hud.hint_label.visible:
				break
			await process_frame
		if not bool(game.tutorial_flags.get("combat", false)) or not game.hud.hint_label.visible:
			failures += 1
			push_error("Wychwood combat guidance missing: zone=%s player_z=%.2f active_enemies=%d flags=%s hint=%s" % [game.current_zone_id, game.player.global_position.z, game.active_enemies.size(), JSON.stringify(game.tutorial_flags), game.hud.hint_label.text])
	if "--day-night" in OS.get_cmdline_user_args():
		game.day_night.set_time_lock(true)
		game.day_night.set_time(0.0)
		await _frames(24)
		await _capture(game, "WORLD-013_05_Wychwood_Night_Combat", Vector3(6.0, 3.0, -0.5), Vector3(0, 1.0, -7.0))
	print("WORLD-013 SCREENSHOTS: %s (staged art fixture, not real-input progression)" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	await _release_game(game)
	quit(0 if failures == 0 else 1)

func _capture(game, stem: String, camera_position: Vector3, focus: Vector3) -> void:
	game.player.velocity = Vector3.ZERO
	game.camera_rig.set_process(false)
	game.camera_rig.camera.look_at_from_position(camera_position, focus, Vector3.UP)
	await _frames(36)
	var tracker: Label = game.hud.tracker_label
	var needed_height := tracker.get_line_count() * tracker.get_line_height()
	if tracker.size.y + 0.5 < needed_height or tracker.get_visible_line_count() < tracker.get_line_count():
		failures += 1
		push_error("WORLD-013 objective tracker clips %d/%d lines: %.1f < %.1f (%s)" % [tracker.get_visible_line_count(), tracker.get_line_count(), tracker.size.y, needed_height, tracker.text.replace("\n", " / ")])
	if stem == "WORLD-013_01_Wychwood_Gate_Arch" and ((game.hud.toast_label.visible and str(game.hud.toast_label.text).contains("Survive the Ghoulkin")) or (game.hud.hint_label.visible and str(game.hud.hint_label.text).contains("strike"))):
		failures += 1
		push_error("Wychwood arrival announced combat before the player reached the clearing")
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		failures += 1
		push_error("Invalid WORLD-013 frame: %s size=%s window=%s zone=%s" % [stem, image.get_size() if image != null else Vector2i.ZERO, DisplayServer.window_get_size(), game.current_zone_id])
		return
	var sample := image.duplicate()
	sample.resize(64, 36, Image.INTERPOLATE_NEAREST)
	var minimum := 1.0
	var maximum := 0.0
	for y in range(sample.get_height()):
		for x in range(sample.get_width()):
			var pixel: Color = sample.get_pixel(x, y)
			var luminance: float = pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
	if maximum - minimum < 0.08:
		failures += 1
		push_error("Blank WORLD-013 frame: %s" % stem)
		return
	var path := "%s/%s_%s.png" % [output_dir, stem, timestamp]
	image.save_png(ProjectSettings.globalize_path(path))
	print("CAPTURED %s" % path)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _wait_for_zone(game: Node, zone_id: String) -> bool:
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		var complete := zone_id != "greyfen" or (game.zone_root != null and bool(game.zone_root.get_meta("opening_detail_complete", false)))
		if game.game_started and not paused and game.player != null and game.zone_root != null and game.current_zone_id == zone_id and not game.zone_transition_pending and not game.zone_load_request_pending and not game.player.transition_locked and complete:
			return true
		await process_frame
	push_error("WORLD-013 never reached playable %s; current=%s player=%s pending=%s frames=%d started=%s paused=%s process_mode=%s player_locked=%s loading=%s" % [zone_id, game.current_zone_id, game.player != null, game.zone_transition_pending, game.zone_transition_frames, game.game_started, paused, game.process_mode, game.player.transition_locked if game.player != null else "missing", game.zone_load_request_pending])
	return false

func _release_game(game: Node) -> void:
	if game != null and is_instance_valid(game):
		if game.has_method("prepare_resource_shutdown"):
			game.prepare_resource_shutdown()
			await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
		if game.has_method("finalize_resource_shutdown"):
			game.finalize_resource_shutdown()
			await _frames(12)
		game.queue_free()
	await _frames(24)
	RenderingServer.force_sync()
