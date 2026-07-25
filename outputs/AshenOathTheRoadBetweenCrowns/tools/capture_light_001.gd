extends SceneTree

var output_dir := ""
var gallery_dir := ""
var timestamp := ""
var failures: Array[String] = []

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("LIGHT-001 capture requires a graphical Compatibility renderer")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	output_dir = ProjectSettings.globalize_path("res://verification_screenshots/light_001")
	gallery_dir = ProjectSettings.globalize_path("res://Development_Gallery/screenshots")
	timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	DirAccess.make_dir_recursive_absolute(output_dir)
	DirAccess.make_dir_recursive_absolute(gallery_dir)
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	game.settings.set_quality_preset("balanced")
	await _frames(6)
	for view in [
		["greyfen", Vector3(0, 1, 6), 720.0, "01_greyfen_day"],
		["greyfen", Vector3(0, 1, 6), 60.0, "02_greyfen_night"],
		["wychwood", Vector3(0, 1, 4), 720.0, "03_wychwood_day"],
		["wychwood", Vector3(0, 1, 4), 60.0, "04_wychwood_night"],
		["vargan_approach", Vector3(0, 1, 8), 1155.0, "05_castle_dusk"],
		["vargan_approach", Vector3(0, 1, 8), 60.0, "06_castle_night"],
		["record_hall", Vector3(0, 1, 6), 720.0, "07_record_hall_day"],
		["record_hall", Vector3(0, 1, 6), 60.0, "08_record_hall_night"],
	]:
		await _capture(game, str(view[0]), view[1], float(view[2]), str(view[3]))
	game.queue_free()
	await process_frame
	if not failures.is_empty():
		print("LIGHT-001 CAPTURE: FAIL (%d)" % failures.size())
		quit(1)
		return
	print("LIGHT-001 CAPTURE: PASS (8 native-720p views)")
	quit()

func _capture(game: Node, zone: String, position: Vector3, minutes: float, file_name: String) -> void:
	game.call("_load_zone", zone, position)
	game.day_night.set_time(minutes)
	game.player.global_position = position
	game.player.velocity = Vector3.ZERO
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = -0.19
	await _frames(12)
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.get_width() != 1280 or image.get_height() != 720:
		_fail("%s did not capture at native 1280x720" % file_name)
		return
	var luminance := _mean_luminance(image)
	if luminance < 0.032:
		_fail("%s is too dark to navigate (%.3f)" % [file_name, luminance])
		return
	if luminance > 0.88:
		_fail("%s is overexposed (%.3f)" % [file_name, luminance])
		return
	image.save_png("%s/%s.png" % [output_dir, file_name])
	image.save_png("%s/LIGHT_001_%s_%s.png" % [gallery_dir, file_name, timestamp])

func _mean_luminance(image: Image) -> float:
	var total := 0.0
	var count := 0
	for y in range(0, image.get_height(), 30):
		for x in range(0, image.get_width(), 40):
			var color := image.get_pixel(x, y)
			total += color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			count += 1
	return total / maxf(float(count), 1.0)

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame
