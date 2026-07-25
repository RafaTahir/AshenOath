extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var timestamp := ""
var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("WORLD-006 capture requires a graphical renderer")
		quit(1)
		return
	timestamp = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(35)
	await _capture(game, "WORLD_006_01_Undercroft", "undercroft", Vector3(0, 1, 8), 0.0)
	await _capture(game, "WORLD_006_02_Assembly", "assembly", Vector3(0, 1, 8), 0.0)
	await _capture(game, "WORLD_006_03_HartGlade", "hart_glade", Vector3(0, 1, 9), 0.0)
	print("WORLD-006 SCREENSHOTS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _capture(game, stem: String, zone_id: String, position: Vector3, yaw: float) -> void:
	game.call("_load_zone", zone_id, position)
	await _frames(20)
	game.player.global_position = position
	game.player.velocity = Vector3.ZERO
	game.camera_rig.yaw = yaw
	game.camera_rig.pitch = -0.18
	await _frames(25)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_width() != 1280 or image.get_height() != 720:
		failures += 1
		push_error("Invalid WORLD-006 frame: %s" % stem)
		return
	image.save_png(ProjectSettings.globalize_path("%s/%s_%s.png" % [OUTPUT_DIR, stem, timestamp]))

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
