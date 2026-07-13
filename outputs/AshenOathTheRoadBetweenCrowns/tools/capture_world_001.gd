extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var failures := 0
var timestamp := ""

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("WORLD-001 capture requires a graphical renderer")
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
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(10)
	await _capture(game, "WORLD_001_01_SpawnStreet", Vector3(0, 1, 7), 0.0)
	await _capture(game, "WORLD_001_02_VillageCentre", Vector3(-2, 1, 5), -0.18)
	await _capture(game, "WORLD_001_03_ShrineQuarter", Vector3(2.0, 1, -6.0), 0.55)
	await _capture(game, "WORLD_001_04_ForgeStreet", Vector3(8.0, 1, -4.2), -0.65)
	print("WORLD-001 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _capture(game, stem: String, position: Vector3, yaw: float) -> void:
	game.call("_load_zone", "greyfen", position)
	await _frames(5)
	game.player.global_position = position
	game.player.velocity = Vector3.ZERO
	game.camera_rig.yaw = yaw
	game.camera_rig.pitch = -0.18
	await _frames(18)
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.get_width() != 1280 or image.get_height() != 720:
		failures += 1
		push_error("Invalid WORLD-001 frame: %s" % stem)
		return
	var sample := image.duplicate()
	sample.resize(64, 36, Image.INTERPOLATE_NEAREST)
	var luminance_min := 1.0
	var luminance_max := 0.0
	for y in range(sample.get_height()):
		for x in range(sample.get_width()):
			var color: Color = sample.get_pixel(x, y)
			var luminance: float = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			luminance_min = minf(luminance_min, luminance)
			luminance_max = maxf(luminance_max, luminance)
	if luminance_max - luminance_min < 0.08:
		failures += 1
		push_error("Blank WORLD-001 frame: %s" % stem)
		return
	var path := "%s/%s_%s.png" % [OUTPUT_DIR, stem, timestamp]
	image.save_png(ProjectSettings.globalize_path(path))
	print("CAPTURED %s" % path)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
