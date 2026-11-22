extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var failures := 0
var timestamp := ""

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("WORLD-014 capture requires a graphical renderer")
		quit(1)
		return
	timestamp = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
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
	await _frames(50)
	# Stage the cemetery in its real Act I quest context so the objective and
	# prompts in the proof images cannot contradict the location.
	for objective_id in ["speak_anwen", "bram", "sella", "oren", "fight_ghoulkin", "return_village"]:
		game.quests.complete_objective("main_road_of_crows", objective_id)
	if not game.quests.is_active("main_bell_beneath_greyfen"):
		game.quests.start_quest("main_bell_beneath_greyfen")
	game.quests.complete_objective("main_bell_beneath_greyfen", "meet_anwen_gate")
	game.call("_refresh_tracker")
	game.hud.set_guidance_hint("")
	await _capture(game, "WORLD-014_01_Cemetery_Approach", Vector3(10.2, 1, 8.0), -1.35)
	await _capture(game, "WORLD-014_02_Grave_Court_Crows", Vector3(12.4, 1, 9.4), -1.15)
	# The chapel entrance is read from its western path. The old angle placed a
	# cemetery-edge tree between the camera and the entire landmark.
	await _capture(game, "WORLD-014_03_Ruined_Crow_Chapel", Vector3(12.0, 1, 7.45), -PI * 0.5)
	await _capture(game, "WORLD-014_04_Bell_and_Shrine", Vector3(16.5, 1, 11.8), 0.34)
	print("WORLD-014 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	await _release_game(game)
	quit(0 if failures == 0 else 1)

func _capture(game, stem: String, position: Vector3, yaw: float) -> void:
	game.player.global_position = position
	game.player.velocity = Vector3.ZERO
	game.camera_rig.yaw = yaw
	game.camera_rig.pitch = -0.16
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
	var output := "%s/%s_%s.png" % [OUTPUT_DIR, stem, timestamp]
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
		game.queue_free()
	await _frames(8)
	RenderingServer.force_sync()
