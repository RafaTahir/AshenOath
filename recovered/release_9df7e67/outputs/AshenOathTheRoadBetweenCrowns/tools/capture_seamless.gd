extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var failures := 0
var timestamp := ""

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("SEAM capture requires a graphical renderer")
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
	await _wait_for_zone(game, "greyfen")
	await _capture(game, "SEAM_001_01_GreyfenBoundary", Vector3(0, 1, -15.7), 0.0)
	await _wait_for_zone(game, "greyfen")
	game.player.global_position = Vector3(0, 0.95, -16.7)
	game.call("_process", 0.25)
	await _wait_for_zone(game, "wychwood")
	await _capture(game, "SEAM_001_02_WychwoodArrival", Vector3(0, 1, 12.4), 3.14)
	print("SEAM-001 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	await _frames(int(game.ZONE_RETIRE_FRAMES) + 6)
	if game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
	await _frames(4)
	game.queue_free()
	await _frames(24)
	if is_instance_valid(game):
		game.free()
	await _frames(2)
	RenderingServer.force_sync()
	quit(0 if failures == 0 else 1)

func _capture(game, stem: String, position: Vector3, yaw: float) -> void:
	game.player.global_position = position
	game.player.velocity = Vector3.ZERO
	game.camera_rig.yaw = yaw
	game.camera_rig.pitch = -0.16
	await _frames(24)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_width() != 1280 or image.get_height() != 720:
		failures += 1
		push_error("Invalid SEAM frame: %s" % stem)
		return
	var sample := image.duplicate()
	sample.resize(64, 36, Image.INTERPOLATE_NEAREST)
	var minimum := 1.0
	var maximum := 0.0
	for y in range(sample.get_height()):
		for x in range(sample.get_width()):
			var color: Color = sample.get_pixel(x, y)
			var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
	if maximum - minimum < 0.08:
		failures += 1
		push_error("Blank SEAM frame: %s" % stem)
		return
	var path := "%s/%s_%s.png" % [OUTPUT_DIR, stem, timestamp]
	image.save_png(ProjectSettings.globalize_path(path))
	print("CAPTURED %s" % path)

func _wait_for_zone(game, zone_id: String) -> void:
	for _index in range(360):
		await process_frame
		if game.current_zone_id == zone_id and not game.zone_transition_pending:
			return
	failures += 1
	push_error("Timed out waiting for %s" % zone_id)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
