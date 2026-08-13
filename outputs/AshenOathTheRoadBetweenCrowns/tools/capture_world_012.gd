extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("WORLD-012 capture requires a graphical renderer")
		quit(1)
		return
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
	await _frames(12)
	await _capture(game, "WORLD_012_01_Greyfen_Spawn_Street", Vector3(0, 1, 12), 0.0)
	await _capture(game, "WORLD_012_02_Greyfen_Shrine_Quarter", Vector3(6.0, 1, -4.2), 0.0)
	await _capture(game, "WORLD_012_03_Greyfen_Forge_Yard", Vector3(8.0, 1, 0.2), -0.78)
	await _capture(game, "WORLD_012_04_Greyfen_River_Bridge", Vector3(4.8, 1, 6.7), 1.57)
	print("WORLD-012 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _capture(game, stem: String, position: Vector3, yaw: float) -> void:
	game.player.global_position = position
	game.player.velocity = Vector3.ZERO
	game.camera_rig.yaw = yaw
	game.camera_rig.pitch = -0.18
	await _frames(18)
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720) or not _is_visible(image):
		failures += 1
		push_error("Invalid WORLD-012 frame: %s" % stem)
		return
	image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, stem]))
	print("CAPTURED %s" % stem)

func _is_visible(image: Image) -> bool:
	var minimum := 1.0
	var maximum := 0.0
	for y in range(0, image.get_height(), 12):
		for x in range(0, image.get_width(), 12):
			var pixel := image.get_pixel(x, y)
			var luminance := pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
	return maximum - minimum >= 0.08

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
