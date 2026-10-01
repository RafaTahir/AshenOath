extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var output_dir := OUTPUT_DIR
var failures := 0
var timestamp := ""

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("WORLD-014 capture requires a graphical renderer")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	timestamp = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir=res://.release-gate/"):
			output_dir = argument.trim_prefix("--output-dir=")
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
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline and (not game.game_started or game.zone_transition_pending or game.zone_root == null or not bool(game.zone_root.get_meta("opening_detail_complete", false))):
		await process_frame
	if not game.game_started or game.zone_transition_pending or game.zone_root == null or not bool(game.zone_root.get_meta("opening_detail_complete", false)):
		push_error("Cemetery capture attempted before playable complete detail")
		await _release_game(game)
		quit(1)
		return
	# Stage the cemetery in its real Act I quest context so the objective and
	# prompts in the proof images cannot contradict the location.
	for objective_id in ["speak_anwen", "bram", "sella", "oren", "fight_ghoulkin", "return_village"]:
		game.quests.complete_objective("main_road_of_crows", objective_id)
	if not game.quests.is_active("main_bell_beneath_greyfen"):
		game.quests.start_quest("main_bell_beneath_greyfen")
	game.quests.complete_objective("main_bell_beneath_greyfen", "meet_anwen_gate")
	game.call("_refresh_tracker")
	game.hud.set_guidance_hint("")
	await _capture(game, "WORLD-014_01_Cemetery_Approach", Vector3(7.8, 3.0, 13.2), Vector3(14.0, 1.0, 8.2))
	await _capture(game, "WORLD-014_02_Grave_Court_Crows", Vector3(10.2, 3.0, 13.5), Vector3(14.8, 0.9, 8.2))
	# The chapel entrance is read from its western path. The old angle placed a
	# cemetery-edge tree between the camera and the entire landmark.
	await _capture(game, "WORLD-014_03_Ruined_Crow_Chapel", Vector3(11.2, 3.0, 8.1), Vector3(17.0, 1.5, 8.0))
	await _capture(game, "WORLD-014_04_Bell_and_Shrine", Vector3(12.0, 3.0, 13.2), Vector3(15.8, 1.45, 9.6))
	print("WORLD-014 SCREENSHOTS: %s (staged visual evidence, not a player-route test)" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	await _release_game(game)
	quit(0 if failures == 0 else 1)

func _capture(game, stem: String, camera_position: Vector3, focus: Vector3) -> void:
	game.player.velocity = Vector3.ZERO
	game.camera_rig.set_process(false)
	game.camera_rig.camera.look_at_from_position(camera_position, focus, Vector3.UP)
	await _frames(36)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		failures += 1
		push_error("Invalid WORLD-014 frame: %s" % stem)
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
		push_error("Blank WORLD-014 frame: %s" % stem)
		return
	var output := "%s/%s_%s.png" % [output_dir, stem, timestamp]
	image.save_png(ProjectSettings.globalize_path(output))
	print("CAPTURED %s" % output)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _release_game(game: Node) -> void:
	if game != null and is_instance_valid(game):
		if game.has_method("prepare_resource_shutdown"):
			game.prepare_resource_shutdown()
			await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
		if game.has_method("finalize_resource_shutdown"):
			game.finalize_resource_shutdown()
			await _frames(12)
		game.queue_free()
	await _frames(8)
	RenderingServer.force_sync()
