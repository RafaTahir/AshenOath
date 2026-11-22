extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var failures := 0
var timestamp := ""

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("PROP-003 capture requires a graphical renderer")
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
	await process_frame
	game.call("_new_game")
	await _wait_ready(game, "greyfen")
	for view in [
		[Vector3(-4.2, 0.95, 8.0), Vector3(-2.0, 1.25, 9.4), "PROP-003_01_Notice_Board_Life"],
		[Vector3(4.0, 0.95, -5.0), Vector3(6.0, 1.2, -7.0), "PROP-003_02_Shrine_Candles"],
		[Vector3(8.6, 0.95, -0.8), Vector3(11.0, 1.15, -1.2), "PROP-003_03_Forge_Working"],
		[Vector3(-5.2, 0.95, 7.0), Vector3(-6.2, 0.65, 9.0), "PROP-003_04_Cart_and_Market"],
		[Vector3(12.4, 0.95, 7.0), Vector3(15.2, 1.75, 9.7), "PROP-003_05_Cemetery_Bell"],
	]:
		game.player.global_position = view[0]
		game.player.velocity = Vector3.ZERO
		var focus: Vector3 = view[1]
		var direction: Vector3 = focus - game.player.global_position
		direction.y = 0.0
		if game.camera_rig != null and direction.length_squared() > 0.01:
			game.camera_rig.yaw = atan2(-direction.x, -direction.z)
			game.camera_rig.pitch = -0.12
			game.camera_rig._initialized = false
		await _frames(18)
		await RenderingServer.frame_post_draw
		_capture(game, str(view[2]))
	print("PROP-003 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _capture(game: Node, stem: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		failures += 1
		push_error("Invalid PROP-003 frame: %s" % stem)
		return
	var sample := image.duplicate()
	sample.resize(64, 36, Image.INTERPOLATE_NEAREST)
	var minimum := 1.0
	var maximum := 0.0
	for y in range(sample.get_height()):
		for x in range(sample.get_width()):
			var pixel: Color = sample.get_pixel(x, y)
			var luminance := pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
	if maximum - minimum < 0.08:
		failures += 1
		push_error("Blank PROP-003 frame: %s" % stem)
		return
	var output := "%s/%s_%s.png" % [OUTPUT_DIR, stem, timestamp]
	image.save_png(ProjectSettings.globalize_path(output))
	print("CAPTURED %s" % output)

func _wait_ready(game: Node, expected_zone: String) -> void:
	for _index in range(240):
		await process_frame
		if str(game.current_zone_id) == expected_zone and game.zone_root != null and not bool(game.zone_transition_pending):
			return
	push_error("Timed out waiting for playable PROP-003 capture")
	failures += 1

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
