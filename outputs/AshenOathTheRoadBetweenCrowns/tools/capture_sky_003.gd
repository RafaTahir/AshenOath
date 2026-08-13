extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var failures := 0
var timestamp := ""

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("SKY-003 capture requires a graphical renderer")
		quit(1)
		return
	timestamp = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Main scene unavailable")
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	await _frames(2)
	game.call("_new_game")
	game.settings.set_quality_preset("balanced")
	await _wait_ready(game, "greyfen")
	for view in [
		["greyfen", Vector3(0, 1, 6), 720.0, "SKY-003_01_Greyfen_Day_Sun_Clouds"],
		["greyfen", Vector3(0, 1, 6), 60.0, "SKY-003_02_Greyfen_Night_Moon_Stars"],
		["wychwood", Vector3(0, 1, 4), 720.0, "SKY-003_03_Wychwood_Day_Sun_Clouds"],
		["wychwood", Vector3(0, 1, 4), 60.0, "SKY-003_04_Wychwood_Night_Moon_Stars"],
		["vargan_approach", Vector3(0, 1, 8), 720.0, "SKY-003_05_Castle_Day_Sun_Clouds"],
		["record_hall", Vector3(0, 1, 8), 60.0, "SKY-003_06_RecordHall_Interior_NoSky"],
	]:
		await _capture(game, str(view[0]), view[1], float(view[2]), str(view[3]))
	print("SKY-003 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _capture(game: Node, zone: String, position: Vector3, minutes: float, stem: String) -> void:
	game.call("_load_zone", zone, position)
	await _wait_ready(game, zone)
	game.day_night.set_time(minutes)
	game.player.global_position = position
	game.player.velocity = Vector3.ZERO
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = 0.08
	await _frames(12)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		failures += 1
		push_error("Invalid SKY-003 frame: %s" % stem)
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
		push_error("Blank SKY-003 frame: %s" % stem)
		return
	var output := "%s/%s_%s.png" % [OUTPUT_DIR, stem, timestamp]
	image.save_png(ProjectSettings.globalize_path(output))
	print("CAPTURED %s" % output)

func _wait_ready(game: Node, expected_zone: String) -> void:
	for _index in range(240):
		await process_frame
		if str(game.current_zone_id) == expected_zone and game.zone_root != null and not bool(game.zone_transition_pending):
			return
	push_error("Timed out waiting for playable %s sky capture" % expected_zone)
	failures += 1

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
