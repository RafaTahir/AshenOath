extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var timestamp := ""
var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("WORLD-004 capture requires a graphical renderer")
		quit(1)
		return
	timestamp = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(40)
	await _capture(game, "WORLD_004_01_DeepWood", "deep_wood", Vector3(0,1,6), 0.0)
	await _capture(game, "WORLD_004_02_AshMill", "old_mill", Vector3(0,1,3), -0.35)
	await _capture(game, "WORLD_004_03_BurnedFarmstead", "burned_farmstead", Vector3(0,1,6), 0.2)
	await _capture(game, "WORLD_004_04_MarshCrossing", "marsh_crossing", Vector3(0,1,8), 0.0)
	print("WORLD-004 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _capture(game, stem: String, zone_id: String, position: Vector3, yaw: float) -> void:
	game.call("_load_zone", zone_id, position)
	await _frames(20)
	game.player.global_position = position
	game.player.velocity = Vector3.ZERO
	game.camera_rig.yaw = yaw
	game.camera_rig.pitch = -0.18
	await _frames(30)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_width() != 1280 or image.get_height() != 720:
		failures += 1
		push_error("Invalid WORLD-004 frame: %s" % stem)
		return
	var sample := image.duplicate()
	sample.resize(64, 36, Image.INTERPOLATE_NEAREST)
	var low := 1.0
	var high := 0.0
	for y in range(sample.get_height()):
		for x in range(sample.get_width()):
			var color: Color = sample.get_pixel(x, y)
			var luminance: float = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			low = minf(low, luminance)
			high = maxf(high, luminance)
	if high - low < 0.08:
		failures += 1
		push_error("Blank WORLD-004 frame: %s" % stem)
		return
	image.save_png(ProjectSettings.globalize_path("%s/%s_%s.png" % [OUTPUT_DIR, stem, timestamp]))

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
