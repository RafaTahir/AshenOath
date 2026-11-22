extends SceneTree

var output_dir := ""
var gallery_dir := ""
var timestamp := ""

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		print("VISUAL-003 screenshots skipped: a graphical renderer is required")
		quit()
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	output_dir = ProjectSettings.globalize_path("res://verification_screenshots/visual_003")
	gallery_dir = ProjectSettings.globalize_path("res://Development_Gallery/screenshots")
	timestamp = _timestamp()
	DirAccess.make_dir_recursive_absolute(output_dir)
	DirAccess.make_dir_recursive_absolute(gallery_dir)
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("main scene failed to load")
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	game.settings.set_quality_preset("balanced")
	await _frames(8)
	await _capture(game, "01_greyfen_dusk_native720", "greyfen", Vector3(0, 1, 7), 990.0, 0.0)
	await _capture(game, "02_greyfen_day_native720", "greyfen", Vector3(-2, 1, 5), 780.0, -0.30)
	await _capture(game, "03_greyfen_night_lanterns", "greyfen", Vector3(0, 1, 5), 1320.0, 0.12)
	await _capture(game, "04_greyfen_pbr_road_and_houses", "greyfen", Vector3(-1.8, 1, 2.6), 840.0, -0.42, -0.30)
	await _capture(game, "05_sister_anwen_clean_rig", "greyfen", Vector3(1.8, 1, -5.4), 990.0, -PI * 0.5, -0.15)
	await _capture(game, "06_greyfen_skeletal_villagers", "greyfen", Vector3(-4.0, 1, 5.8), 780.0, -0.58)
	await _capture(game, "07_wychwood_day_pbr_ground", "wychwood", Vector3(0, 1, 6.0), 720.0, 0.0, -0.28)
	await _capture(game, "08_wychwood_night_readability", "wychwood", Vector3(0, 1, 0.0), 1380.0, 0.0)
	await _capture_monsters(game, "09_wychwood_horror_pack")
	await _capture_oathfire_lock(game, "10_oathfire_locked_direction")
	print("VISUAL-003 screenshots saved at 1280x720 to %s and %s" % [output_dir, gallery_dir])
	game.queue_free()
	await process_frame
	quit()

func _capture(game: Node, file_name: String, zone: String, player_pos: Vector3, minutes: float, yaw: float, pitch: float = -0.20) -> void:
	game.call("_load_zone", zone, player_pos)
	game.day_night.set_time(minutes)
	game.player.global_position = player_pos
	game.player.velocity = Vector3.ZERO
	if game.camera_rig != null:
		game.camera_rig.yaw = yaw
		game.camera_rig.pitch = pitch
	await _frames(14)
	_save_viewport(file_name)

func _capture_monsters(game: Node, file_name: String) -> void:
	game.call("_load_zone", "wychwood", Vector3(0, 1, -1.0))
	game.day_night.set_time(1170.0)
	game.player.global_position = Vector3(0, 1, -1.0)
	var positions := [Vector3(-3.4, 0.8, -7.6), Vector3(-1.7, 0.8, -8.4), Vector3(0, 0.8, -9.0), Vector3(1.8, 0.8, -8.4), Vector3(3.5, 0.8, -7.6)]
	for i in range(mini(game.active_enemies.size(), positions.size())):
		var enemy = game.active_enemies[i]
		enemy.set_physics_process(false)
		enemy.global_position = positions[i]
		enemy.look_at(Vector3(game.player.global_position.x, enemy.global_position.y, game.player.global_position.z), Vector3.UP)
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = -0.17
	await _frames(10)
	_save_viewport(file_name)

func _capture_oathfire_lock(game: Node, file_name: String) -> void:
	game.call("_load_zone", "wychwood", Vector3(0, 1, 2.0))
	game.day_night.set_time(1110.0)
	game.player.global_position = Vector3(0, 1, 2.0)
	game.player.rotation = Vector3(0, 0.38, 0)
	var direction: Vector3 = game.player.call("_lock_beam_direction")
	game.player.call("_set_sword_sheathed", true)
	game.player.beam_cast_state = "releasing"
	var origin: Vector3 = game.player.global_position + Vector3(0, 1.22, 0) + direction * 0.78
	game.call("_make_oathfire_beam", origin, origin + direction * 12.0, 1.0, true)
	if game.camera_rig != null:
		game.camera_rig.yaw = -0.55
		game.camera_rig.pitch = -0.18
	await _frames(2)
	_save_viewport(file_name)
	game.player.cancel_beam_charge()

func _save_viewport(file_name: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("%s produced no image" % file_name)
		quit(1)
		return
	if image.get_width() != 1280 or image.get_height() != 720:
		push_error("%s is %dx%d instead of 1280x720" % [file_name, image.get_width(), image.get_height()])
		quit(1)
		return
	_assert_nonblank(image, file_name)
	image.save_png("%s/%s.png" % [output_dir, file_name])
	image.save_png("%s/VISUAL-003_%s_%s.png" % [gallery_dir, file_name, timestamp])

func _assert_nonblank(image: Image, file_name: String) -> void:
	var total := 0.0
	var total_sq := 0.0
	var count := 0
	for y in range(0, image.get_height(), 30):
		for x in range(0, image.get_width(), 40):
			var c := image.get_pixel(x, y)
			var lum := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			total += lum
			total_sq += lum * lum
			count += 1
	var mean := total / maxf(float(count), 1.0)
	var variance := maxf(total_sq / maxf(float(count), 1.0) - mean * mean, 0.0)
	if mean < 0.025 or variance < 0.0005:
		push_error("%s appears blank: mean=%.4f variance=%.6f" % [file_name, mean, variance])
		quit(1)

func _frames(count: int) -> void:
	for _i in range(count): await process_frame

func _timestamp() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d_%02d%02d%02d" % [d.year, d.month, d.day, d.hour, d.minute, d.second]
