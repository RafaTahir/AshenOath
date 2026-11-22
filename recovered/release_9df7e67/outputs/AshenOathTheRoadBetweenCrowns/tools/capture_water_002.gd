extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var failures := 0
var timestamp := ""

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("WATER-002 capture requires a graphical renderer")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
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
	if not await _wait_for_zone(game, "greyfen", true):
		await _release_game(game)
		quit(1)
		return
	await _capture(game, "WATER-002_01_Greyfen_Bridge_Current", Vector3(4.8, 1, 6.7), 1.57)
	game.call("_load_zone", "wychwood", Vector3(0, 1, 8))
	if not await _wait_for_zone(game, "wychwood", false):
		await _release_game(game)
		quit(1)
		return
	await _capture(game, "WATER-002_02_Wychwood_Bridge_Current", Vector3(0, 1, 4.3), 0.0)
	await _capture(game, "WATER-002_03_Wychwood_Root_Arch", Vector3(0, 1, 4.3), PI)
	print("WATER-002 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	await _release_game(game)
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
	if stem.begins_with("WATER-002_01_Greyfen"):
		var water_pixel := image.get_pixel(950, 600)
		if water_pixel.r > 0.30 or water_pixel.b <= water_pixel.r:
			failures += 1
			push_error("Greyfen river did not render in gameplay frame: %s" % water_pixel)
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

func _wait_for_zone(game: Node, zone_id: String, require_detail: bool) -> bool:
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		var playable: bool = game.game_started and not paused and game.player != null and game.zone_root != null and game.current_zone_id == zone_id and not game.zone_transition_pending and not game.zone_load_request_pending and not game.player.transition_locked
		if playable and (not require_detail or bool(game.zone_root.get_meta("opening_detail_complete", false))):
			return true
		await process_frame
	push_error("WATER-002 capture timed out: zone=%s current=%s started=%s pending=%s detail=%s" % [zone_id, game.current_zone_id, game.game_started, game.zone_transition_pending, game.zone_root.get_meta("opening_detail_complete", false) if game.zone_root != null else false])
	return false

func _release_game(game: Node) -> void:
	if game != null and is_instance_valid(game):
		if game.has_method("finalize_resource_shutdown"):
			game.finalize_resource_shutdown()
		elif game.has_method("prepare_resource_shutdown"):
			game.prepare_resource_shutdown()
		await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
		game.queue_free()
	await _frames(24)
	if is_instance_valid(game):
		game.free()
		await _frames(2)
	RenderingServer.force_sync()
