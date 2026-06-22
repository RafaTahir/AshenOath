extends SceneTree

var output_dir = ""
var gallery_dir = ""
var timestamp = ""

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		print("main menu screenshot capture skipped: headless/dummy renderer cannot read viewport pixels")
		quit()
		return
	output_dir = ProjectSettings.globalize_path("res://verification_screenshots")
	gallery_dir = ProjectSettings.globalize_path("res://Development_Gallery/screenshots")
	timestamp = _timestamp_for_file()
	DirAccess.make_dir_recursive_absolute(output_dir)
	DirAccess.make_dir_recursive_absolute(gallery_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene = load("res://scenes/main.tscn")
	if scene == null:
		push_error("main scene failed to load")
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await _settle_frames(10)
	game.hud.show_main_menu()
	await _settle_frames(18)
	var image = root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("main menu screenshot capture returned no image")
		quit(1)
		return
	_assert_image_quality(image)
	var file_name = "ui_001_main_menu_prestige_%s.png" % timestamp
	image.save_png("%s/%s" % [output_dir, file_name])
	image.save_png("%s/UI_001_Main_Menu_Prestige_%s.png" % [gallery_dir, timestamp])
	print("main menu screenshot saved: %s/%s" % [output_dir, file_name])
	game.queue_free()
	await process_frame
	quit()

func _settle_frames(count: int) -> void:
	for i in range(count):
		await process_frame

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

func _assert_image_quality(image: Image) -> void:
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
	var mean = total / max(samples, 1)
	var variance = max(total_sq / max(samples, 1) - mean * mean, 0.0)
	if mean < 0.02 or variance < 0.00045:
		push_error("main menu capture appears blank or visually flat. mean=%f variance=%f" % [mean, variance])
		quit(1)
