extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var failures := 0
var timestamp := ""

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("AUDIO-006 capture requires a graphical renderer")
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
		[Vector3(4.0, 0.95, -5.0), Vector3(6.0, 1.2, -7.0), "AUDIO-006_01_Greyfen_Shrine"],
		[Vector3(8.6, 0.95, -0.8), Vector3(11.0, 1.15, -1.2), "AUDIO-006_02_Greyfen_Forge"],
		[Vector3(-0.2, 0.95, 3.0), Vector3(0.0, 0.35, 4.5), "AUDIO-006_03_Greyfen_River"],
	]:
		_prepare_view(game, view)
		await _frames(18)
		await RenderingServer.frame_post_draw
		_capture_frame(view)
	game.call("_load_zone", "wychwood", Vector3(0, 1, 12))
	await _wait_ready(game, "wychwood")
	var gate_view := [Vector3(0.0, 0.95, 10.0), Vector3(0.0, 1.1, 7.0), "AUDIO-006_04_Wychwood_Gate"]
	_prepare_view(game, gate_view)
	await _frames(18)
	await RenderingServer.frame_post_draw
	_capture_frame(gate_view)
	print("AUDIO-006 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _prepare_view(game: Node, view: Array) -> void:
	game.player.global_position = view[0]
	game.player.velocity = Vector3.ZERO
	var focus: Vector3 = view[1]
	var direction: Vector3 = focus - game.player.global_position
	direction.y = 0.0
	if game.camera_rig != null and direction.length_squared() > 0.01:
		game.camera_rig.yaw = atan2(-direction.x, -direction.z)
		game.camera_rig.pitch = -0.12
		game.camera_rig._initialized = false
func _capture_frame(view: Array) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		failures += 1
		push_error("Invalid AUDIO-006 frame: %s" % str(view[2]))
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
		push_error("Blank AUDIO-006 frame: %s" % str(view[2]))
		return
	var path := "%s/%s_%s.png" % [OUTPUT_DIR, str(view[2]), timestamp]
	var absolute_path := ProjectSettings.globalize_path(path)
	var save_error := image.save_png(absolute_path)
	print("CAPTURED %s" % absolute_path)
	if save_error != OK or not FileAccess.file_exists(absolute_path):
		failures += 1
		push_error("AUDIO-006 image save failed: %s" % absolute_path)

func _wait_ready(game: Node, expected_zone: String) -> void:
	for _index in range(240):
		await process_frame
		if str(game.current_zone_id) == expected_zone and game.zone_root != null and not bool(game.zone_transition_pending):
			return
	push_error("Timed out waiting for AUDIO-006 capture in %s" % expected_zone)
	failures += 1

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
