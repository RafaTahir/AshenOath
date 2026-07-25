extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("PROG-001 capture requires a graphical Compatibility renderer")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _frames(8)
	game.progression.load_state({
		"marks": 3,
		"unlocked": {"keen_edge": true},
		"rewarded_quests": {"main_road_of_crows": true}
	})
	game.hud.show_inventory(game.inventory, game.quests, game.story_state, game.progression)
	await _frames(5)
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.get_width() != 1280 or image.get_height() != 720:
		_fail("progression journal did not capture at native 1280x720")
	else:
		var output_dir := ProjectSettings.globalize_path("res://verification_screenshots/prog_001")
		var gallery_dir := ProjectSettings.globalize_path("res://Development_Gallery/screenshots")
		DirAccess.make_dir_recursive_absolute(output_dir)
		DirAccess.make_dir_recursive_absolute(gallery_dir)
		var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
		image.save_png("%s/01_progression_journal.png" % output_dir)
		image.save_png("%s/PROG_001_progression_journal_%s.png" % [gallery_dir, timestamp])
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PROG-001 CAPTURE: PASS (native-720p progression journal)")
		quit()
		return
	print("PROG-001 CAPTURE: FAIL")
	quit(1)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)
