extends SceneTree

const OUTPUT_DIR := "res://Development_Gallery/screenshots"
var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		quit(1)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await settle(30)
	game.quests.unlocked["main_hart_remembers"] = true
	game.quests.start_quest("main_hart_remembers")
	game.story_state.set_flag("confession_method", "witnesses")
	game.call("_load_zone", "hart_glade", Vector3(0, 1, 8))
	await settle(20)
	game.call("_complete_ending", "bind")
	await settle(25)
	game.player.global_position = Vector3(0, 1, 7)
	game.camera_rig.yaw = 0.0
	game.camera_rig.pitch = -0.16
	await settle(20)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.get_width() != 1280 or image.get_height() != 720:
		failures += 1
	else:
		var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
		image.save_png(ProjectSettings.globalize_path("%s/BOSS_001_WhiteHart_%s.png" % [OUTPUT_DIR, stamp]))
	var result_code := 0 if failures == 0 else 1
	print("VERIFIER_PHASE: SHUTDOWN")
	await _release_game(game)
	print("BOSS-001 SCREENSHOT: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(result_code)

func settle(count: int) -> void:
	for _index in range(count):
		await process_frame

func _release_game(game: Node) -> void:
	if is_instance_valid(game) and game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await settle(20)
	if is_instance_valid(game) and game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
		await settle(16)
	if is_instance_valid(game) and game.is_inside_tree():
		root.remove_child(game)
	if is_instance_valid(game):
		game.free()
	RenderingServer.force_sync()
	await settle(12)
	RenderingServer.force_sync()
