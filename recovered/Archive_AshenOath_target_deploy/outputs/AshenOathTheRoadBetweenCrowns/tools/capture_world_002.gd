extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var failures := 0
var timestamp := ""

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("WORLD-002 capture requires a graphical renderer")
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
	game.quests.start_quest("main_road_of_crows")
	game.call("_load_zone", "wychwood", Vector3(0, 1, 12.2))
	# Teleporting between proof views must allow the damped third-person boom to settle;
	# otherwise the capture can record a transient through the previous camera volume.
	await _frames(60)
	await _capture(game, "WORLD_002_01_GateThreshold", Vector3(0, 1, 12.2), 0.0)
	await _capture(game, "WORLD_002_02_InvestigationRoad", Vector3(-1.2, 1, 7.0), 0.05)
	await _capture(game, "WORLD_002_03_RiverCrossing", Vector3(0, 1, 4.3), 0.0)
	await _capture(game, "WORLD_002_04_CombatClearing", Vector3(0, 1, -3.3), 0.0)
	print("WORLD-002 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _capture(game, stem: String, position: Vector3, yaw: float) -> void:
	game.player.global_position = position
	game.player.velocity = Vector3.ZERO
	game.camera_rig.yaw = yaw
	game.camera_rig.pitch = -0.18
	await _frames(60)
	var image: Image = await _read_stable_frame()
	if image == null or image.get_width() != 1280 or image.get_height() != 720:
		failures += 1
		push_error("Invalid WORLD-002 frame: %s" % stem)
		return
	if _has_incomplete_angle_tile(image):
		failures += 1
		push_error("Incomplete ANGLE readback: %s" % stem)
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
		push_error("Blank WORLD-002 frame: %s" % stem)
		return
	var path := "%s/%s_%s.png" % [OUTPUT_DIR, stem, timestamp]
	image.save_png(ProjectSettings.globalize_path(path))
	print("CAPTURED %s" % path)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _read_stable_frame() -> Image:
	var image: Image
	for _attempt in range(4):
		await RenderingServer.frame_post_draw
		image = root.get_viewport().get_texture().get_image()
		if image != null and not _has_incomplete_angle_tile(image):
			return image
		await process_frame
	return image

func _has_incomplete_angle_tile(image: Image) -> bool:
	if image == null or image.get_width() < 1000 or image.get_height() < 500:
		return false
	var dark_samples := 0
	var sample_count := 0
	for y in range(16, 240, 32):
		for x in range(16, 752, 32):
			var color := image.get_pixel(x, y)
			var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			dark_samples += 1 if luminance < 0.008 else 0
			sample_count += 1
	var reference := image.get_pixel(1000, 180)
	var reference_luminance := reference.r * 0.2126 + reference.g * 0.7152 + reference.b * 0.0722
	return float(dark_samples) / float(maxi(sample_count, 1)) > 0.78 and reference_luminance > 0.04
