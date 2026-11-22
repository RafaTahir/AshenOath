extends SceneTree

var output_dir := ""
var gallery_dir := ""
var timestamp := ""

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		print("SKY-001 screenshots skipped: graphical renderer required")
		quit()
		return
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	output_dir = ProjectSettings.globalize_path("res://verification_screenshots/sky_001")
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
	await _frames(8)
	for view in [
		["greyfen", Vector3(0, 1, 6), 720.0, "01_greyfen_day_sun_clouds"],
		["greyfen", Vector3(0, 1, 6), 0.0, "02_greyfen_midnight_moon_stars"],
		["wychwood", Vector3(0, 1, 4), 720.0, "03_wychwood_day_sun_clouds"],
		["wychwood", Vector3(0, 1, 4), 0.0, "04_wychwood_midnight_readable"],
		["cemetery", Vector3(0, 1, 6), 720.0, "05_cemetery_day_sky"],
		["cemetery", Vector3(0, 1, 6), 0.0, "06_cemetery_midnight_readable"],
		["vargan_approach", Vector3(0, 1, 8), 720.0, "07_castle_day_sky"],
		["vargan_approach", Vector3(0, 1, 8), 0.0, "08_castle_midnight_readable"],
	]:
		await _capture(game, str(view[0]), view[1], float(view[2]), str(view[3]))
	print("SKY-001 screenshots saved to %s" % output_dir)
	game.queue_free()
	await process_frame
	quit()

func _capture(game: Node, zone: String, position: Vector3, minutes: float, file_name: String) -> void:
	game.call("_load_zone", zone, position)
	game.day_night.set_time(minutes)
	game.player.global_position = position
	game.player.velocity = Vector3.ZERO
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = 0.08
	await _frames(14)
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.get_width() != 1920 or image.get_height() != 1080:
		push_error("%s did not capture at 1920x1080" % file_name)
		quit(1)
		return
	if _mean_luminance(image) < 0.035:
		push_error("%s is too dark to be playable" % file_name)
		quit(1)
		return
	var local_path := "%s/%s.png" % [output_dir, file_name]
	var gallery_path := "%s/SKY_001_%s_%s.png" % [gallery_dir, file_name, timestamp]
	image.save_png(local_path)
	image.save_png(gallery_path)

func _mean_luminance(image: Image) -> float:
	var total := 0.0
	var count := 0
	for y in range(0, image.get_height(), 45):
		for x in range(0, image.get_width(), 60):
			var color := image.get_pixel(x, y)
			total += color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			count += 1
	return total / maxf(float(count), 1.0)

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame
