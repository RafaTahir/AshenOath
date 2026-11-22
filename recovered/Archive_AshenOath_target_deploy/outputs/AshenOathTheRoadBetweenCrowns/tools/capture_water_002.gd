extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var failures := 0
var timestamp := ""

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("WATER-002 capture requires a graphical renderer")
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
	await _frames(18)
	await _capture(game, "WATER-002_01_Greyfen_Bridge_Current", Vector3(4.8, 1, 6.7), 1.57)
	game.call("_load_zone", "wychwood", Vector3(0, 1, 8))
	await _frames(20)
	await _capture(game, "WATER-002_02_Wychwood_Bridge_Current", Vector3(0, 1, 4.3), 0.0)
	print("WATER-002 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _capture(game, stem: String, position: Vector3, yaw: float) -> void:
	game.player.global_position = position
	game.player.velocity = Vector3.ZERO
	game.camera_rig.yaw = yaw
	game.camera_rig.pitch = -0.18
	await _frames(36)
	var image: Image = await _read_stable_frame()
	if image == null or image.get_size() != Vector2i(1280, 720):
		failures += 1
		push_error("Invalid WATER-002 frame: %s" % stem)
		return
	if not _is_visible(image):
		failures += 1
		push_error("Blank WATER-002 frame: %s" % stem)
		return
	var output := "%s/%s_%s.png" % [OUTPUT_DIR, stem, timestamp]
	image.save_png(ProjectSettings.globalize_path(output))
	print("CAPTURED %s" % output)

func _read_stable_frame() -> Image:
	var image: Image
	for _attempt in range(4):
		await RenderingServer.frame_post_draw
		image = root.get_viewport().get_texture().get_image()
		if image != null:
			return image
		await process_frame
	return image

func _is_visible(image: Image) -> bool:
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
	return maximum - minimum >= 0.08

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
