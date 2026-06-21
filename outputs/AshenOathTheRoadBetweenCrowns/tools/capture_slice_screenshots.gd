extends SceneTree

const CombatFeedback = preload("res://scripts/combat_feedback.gd")

var output_dir = ""
var gallery_dir = ""
var gallery_timestamp = ""
var gallery_phase = "Capture"

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		print("slice screenshot capture skipped: headless/dummy renderer cannot read viewport pixels")
		quit()
		return
	output_dir = ProjectSettings.globalize_path("res://verification_screenshots")
	gallery_dir = ProjectSettings.globalize_path("res://Development_Gallery/screenshots")
	gallery_timestamp = _timestamp_for_file()
	DirAccess.make_dir_recursive_absolute(output_dir)
	DirAccess.make_dir_recursive_absolute(gallery_dir)
	var scene = load("res://scenes/main.tscn")
	if scene == null:
		push_error("main scene failed to load")
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _settle_frames(8)
	await _capture(game, "01_greyfen_spawn", Vector3(0, 1, 7), "greyfen", Vector3(0, 1, 7))
	await _capture(game, "02_village_center", Vector3(-2, 1, 5), "greyfen", Vector3(-2, 1, 5))
	await _capture(game, "03_shrine_sister_anwen", Vector3(3.2, 1, -5.0), "greyfen", Vector3(3.2, 1, -5.0))
	await _capture(game, "04_graveyard_visible_area", Vector3(12.6, 1, 7.4), "greyfen", Vector3(12.6, 1, 7.4))
	await _capture_dialogue(game, "05_sister_anwen_dialogue", Vector3(3.2, 1, -5.0))
	await _capture_post_anwen_objective(game, "06_post_anwen_objective")
	await _capture_gate_guidance(game, "07_wychwood_gate_guidance")
	await _capture(game, "08_forest_gate", Vector3(0, 1, -12), "greyfen", Vector3(0, 1, -12))
	await _capture(game, "09_forest_trail", Vector3(0, 1, 8), "wychwood", Vector3(0, 1, 8))
	await _capture(game, "10_combat_clearing", Vector3(0, 1, -5), "wychwood", Vector3(0, 1, -5))
	await _capture(game, "19_shrine_graveyard_omen", Vector3(7.4, 1, -5.6), "greyfen", Vector3(7.4, 1, -5.6))
	await _capture(game, "20_wychwood_gate_threshold", Vector3(0, 1, -13.2), "greyfen", Vector3(0, 1, -13.2))
	await _capture(game, "21_old_road_clue_story", Vector3(-1.4, 1, 5.9), "wychwood", Vector3(-1.4, 1, 5.9))
	await _capture(game, "22_ghoulkin_clearing_story", Vector3(0, 1, -5.2), "wychwood", Vector3(0, 1, -5.2))
	await _capture_player_motion_state(game, "11_player_idle_pose", "idle")
	await _capture_player_motion_state(game, "12_player_walking_pose", "walk")
	await _capture_player_motion_state(game, "13_player_light_attack_arc", "light")
	await _capture_player_motion_state(game, "14_player_heavy_attack_arc", "heavy")
	await _capture_combat_state(game, "15_ghoulkin_windup_hud", "windup")
	await _capture_combat_state(game, "16_player_block_cue", "block")
	await _capture_combat_state(game, "17_ghoulkin_death_read", "death")
	await _capture_victory_state(game, "18_ghoulkin_victory_objective")
	await _capture_victory_state(game, "23_ghoulkin_aftermath_clue")
	print("slice screenshots saved to %s and mirrored to %s" % [output_dir, gallery_dir])
	game.queue_free()
	await process_frame
	quit()

func _capture(game, file_name: String, player_pos: Vector3, zone_id: String, spawn_pos: Vector3) -> void:
	game.call("_load_zone", zone_id, spawn_pos)
	await _settle_frames(3)
	game.player.global_position = player_pos
	game.player.velocity = Vector3.ZERO
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = -0.2
	await _settle_frames(12)
	_assert_capture_safe(game, player_pos, file_name)
	var image = root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("viewport screenshot capture returned no image")
		quit(1)
		return
	_assert_image_quality(image, file_name)
	_save_image(image, file_name)

func _capture_dialogue(game, file_name: String, player_pos: Vector3) -> void:
	game.call("_load_zone", "greyfen", player_pos)
	await _settle_frames(3)
	game.player.global_position = player_pos
	game.player.velocity = Vector3.ZERO
	var sister = _find_child_named(game.zone_root, "sister_anwen")
	if sister == null:
		push_error("dialogue capture could not find Sister Anwen")
		quit(1)
		return
	game.call("_handle_interaction", sister)
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = -0.18
	await _settle_frames(12)
	var image = root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("dialogue viewport screenshot capture returned no image")
		quit(1)
		return
	_assert_image_quality(image, file_name)
	_save_image(image, file_name)
	game.get_tree().paused = false
	game.hud.hide_menus()

func _capture_post_anwen_objective(game, file_name: String) -> void:
	game.call("_load_zone", "greyfen", Vector3(3.2, 1, -5.0))
	await _settle_frames(3)
	game.player.global_position = Vector3(3.2, 1, -5.0)
	var sister = _find_child_named(game.zone_root, "sister_anwen")
	if sister == null:
		push_error("post-Anwen capture could not find Sister Anwen")
		quit(1)
		return
	game.call("_handle_dialogue_action", {"type": "complete_objective", "quest": "main_road_of_crows", "objective": "speak_anwen"})
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = -0.18
	await _settle_frames(12)
	_save_viewport(file_name)

func _capture_gate_guidance(game, file_name: String) -> void:
	game.call("_load_zone", "greyfen", Vector3(0, 1, -11.8))
	await _settle_frames(3)
	game.player.global_position = Vector3(0, 1, -11.8)
	game.hud.set_guidance_hint("Wychwood gate ahead. Stay on the lit road.", 5.0)
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = -0.2
	await _settle_frames(12)
	_save_viewport(file_name)

func _capture_combat_state(game, file_name: String, state: String) -> void:
	game.call("_load_zone", "wychwood", Vector3(0, 1, 8))
	await _settle_frames(4)
	game.player.global_position = Vector3(0, 1, -4.0)
	game.player.velocity = Vector3.ZERO
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = -0.18
	if game.active_enemies.is_empty():
		push_error("%s combat capture found no active enemies" % file_name)
		quit(1)
		return
	var enemy = game.active_enemies[0]
	enemy.global_position = Vector3(-1.4, 0.8, -7.0)
	if enemy.has_method("look_at"):
		enemy.look_at(Vector3(game.player.global_position.x, enemy.global_position.y, game.player.global_position.z), Vector3.UP)
	if state == "windup":
		enemy.windup_time = 0.42
		enemy.pending_attack_time = 0.42
		enemy.call("_show_windup_marker")
		game.call("_on_enemy_windup_started", enemy)
	elif state == "block":
		enemy.windup_time = 0.10
		CombatFeedback.block_flash(game.zone_root, game.player.global_position, false)
		CombatFeedback.ground_ring(game.zone_root, game.player.global_position, Color(0.58, 0.36, 0.12), 0.45, 0.18)
		game.hud.show_status_cue("Blocked", "block")
		game.hud.set_guidance_hint("Q at the lunge to parry. Hold Q to block.", 4.0)
	elif state == "death":
		enemy.call("_on_died")
		CombatFeedback.ground_ring(game.zone_root, enemy.global_position, Color(0.12, 0.08, 0.055), 0.9, 0.24)
		game.hud.show_status_cue("Ghoulkin slain", "victory")
	await _settle_frames(12)
	_save_viewport(file_name)

func _capture_player_motion_state(game, file_name: String, state: String) -> void:
	game.call("_load_zone", "greyfen", Vector3(0, 1, 5.5))
	await _settle_frames(4)
	game.player.global_position = Vector3(0, 1, 5.5)
	game.player.velocity = Vector3.ZERO if state == "idle" else Vector3(0, 0, -4.0)
	game.player.move_phase = PI * 0.5 if state == "walk" else 0.0
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = -0.18
	if state == "light":
		game.player.attack_anim_time = 0.25
		game.player.attack_anim_heavy = false
	elif state == "heavy":
		game.player.attack_anim_time = 0.28
		game.player.attack_anim_heavy = true
	var frame_count = 2 if state == "light" or state == "heavy" else 16
	for i in range(frame_count):
		if state == "walk":
			game.player.call("_animate_visuals", 0.016, Vector3(0, 0, -1), true)
		elif state == "idle":
			game.player.call("_animate_visuals", 0.016, Vector3.ZERO, false)
		else:
			game.player.attack_anim_time = max(float(game.player.attack_anim_time) - 0.016, 0.0)
			game.player.call("_animate_visuals", 0.016, Vector3.ZERO, false)
		await process_frame
	_save_viewport(file_name)

func _capture_victory_state(game, file_name: String) -> void:
	for objective_id in ["speak_anwen", "inspect_corpse", "find_claw_marks", "find_black_feathers"]:
		game.quests.complete_objective("main_road_of_crows", objective_id)
	game.call("_load_zone", "wychwood", Vector3(0, 1, -4.0))
	await _settle_frames(4)
	game.player.global_position = Vector3(0, 1, -4.0)
	for enemy in game.active_enemies:
		if enemy != null and not enemy.dead:
			enemy.call("_on_died")
	game.ghoulkin_kills = 2
	game.quests.complete_objective("main_road_of_crows", "fight_ghoulkin")
	game.call("_make_post_ghoulkin_story_clue")
	game.hud.show_status_cue("Ghoulkin slain", "victory")
	game.hud.set_guidance_hint("Inspect the tracks, then return to Greyfen.", 6.0)
	game.call("_refresh_tracker")
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = -0.18
	await _settle_frames(12)
	_save_viewport(file_name)

func _save_viewport(file_name: String) -> void:
	var image = root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("%s viewport screenshot capture returned no image" % file_name)
		quit(1)
		return
	_assert_image_quality(image, file_name)
	_save_image(image, file_name)

func _save_image(image: Image, file_name: String) -> void:
	image.save_png("%s/%s.png" % [output_dir, file_name])
	var gallery_name = "%s_%s_%s.png" % [gallery_phase, file_name, gallery_timestamp]
	image.save_png("%s/%s" % [gallery_dir, gallery_name])

func _timestamp_for_file() -> String:
	var datetime = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d_%02d%02d%02d" % [
		int(datetime.get("year", 0)),
		int(datetime.get("month", 0)),
		int(datetime.get("day", 0)),
		int(datetime.get("hour", 0)),
		int(datetime.get("minute", 0)),
		int(datetime.get("second", 0))
	]

func _find_child_named(root_node: Node, node_name: String) -> Node:
	if root_node == null:
		return null
	if root_node.name == node_name:
		return root_node
	for child in root_node.get_children():
		var found = _find_child_named(child, node_name)
		if found != null:
			return found
	return null

func _settle_frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _assert_capture_safe(game, expected_pos: Vector3, file_name: String) -> void:
	var actual: Vector3 = game.player.global_position
	if actual.y < -0.5:
		push_error("%s capture is below the playable surface: %s" % [file_name, str(actual)])
		quit(1)
	if actual.distance_to(expected_pos) > 1.25:
		push_error("%s capture drifted away from its safe point. Expected %s got %s" % [file_name, str(expected_pos), str(actual)])
		quit(1)

func _assert_image_quality(image: Image, file_name: String) -> void:
	var width = image.get_width()
	var height = image.get_height()
	var samples = 0
	var total = 0.0
	var total_sq = 0.0
	var step_y: int = int(max(1, height / 24))
	var step_x: int = int(max(1, width / 32))
	for y in range(0, height, step_y):
		for x in range(0, width, step_x):
			var color = image.get_pixel(x, y)
			var luminance = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			total += luminance
			total_sq += luminance * luminance
			samples += 1
	if samples <= 0:
		push_error("%s capture produced no sampleable pixels" % file_name)
		quit(1)
	var mean = total / samples
	var variance = max(total_sq / samples - mean * mean, 0.0)
	if mean < 0.03 or variance < 0.0006:
		push_error("%s capture appears blank or visually flat. mean=%f variance=%f" % [file_name, mean, variance])
		quit(1)
