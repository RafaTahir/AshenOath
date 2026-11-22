extends SceneTree

const OUTPUT_DIR := "D:/Temp/AshenOath/world001/slab_diagnostic"

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Slab diagnostic requires a graphical renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(2)
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	game.quests.start_quest("main_road_of_crows")
	game.quests.complete_objective("main_road_of_crows", "speak_anwen")
	game.call("_load_zone", "wychwood", Vector3(0, 1, 12.5))
	await _frames(18)
	game.player.velocity = Vector3.ZERO
	game.camera_rig.set_process(false)
	game.camera_rig.camera.look_at_from_position(Vector3(5.6, 3.0, 10.5), Vector3(0, 0.9, 4.0), Vector3.UP)
	await _frames(36)
	await _save("baseline")
	if "--instance-scan" in OS.get_cmdline_user_args():
		await _scan_instances(game.zone_root)
	else:
		for category in ["berm", "forest_rock", "deadfall", "detail_batch", "terrain_batch"]:
			var hidden: Array[Node3D] = []
			_collect(game.zone_root, category, hidden)
			for node in hidden:
				node.visible = false
			await _frames(4)
			await _save("without_" + category)
			for node in hidden:
				node.visible = true
			print("SLAB DIAGNOSTIC %s hidden=%d" % [category, hidden.size()])
			await _frames(4)
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(int(game.ZONE_RETIRE_FRAMES) + 4)
	game.queue_free()
	await _frames(8)
	RenderingServer.force_sync()
	quit(0)

func _scan_instances(zone_root: Node3D) -> void:
	var baseline := root.get_viewport().get_texture().get_image()
	var candidates: Array[GeometryInstance3D] = []
	_collect_geometry(zone_root, candidates)
	var results: Array[Dictionary] = []
	for node in candidates:
		if not node.is_visible_in_tree():
			continue
		node.visible = false
		await _frames(2)
		await RenderingServer.frame_post_draw
		var without := root.get_viewport().get_texture().get_image()
		var score := _dark_foreground_difference(baseline, without)
		results.append({"node": node, "score": score, "path": str(zone_root.get_path_to(node))})
		node.visible = true
		await _frames(2)
	results.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.score) > int(right.score))
	print("SLAB INSTANCE SCAN candidates=%d" % candidates.size())
	for index in range(mini(18, results.size())):
		var entry: Dictionary = results[index]
		print("SLAB INSTANCE RANK %02d score=%d path=%s" % [index + 1, int(entry.score), str(entry.path)])
	for index in range(mini(8, results.size())):
		var entry: Dictionary = results[index]
		if int(entry.score) < 20:
			continue
		var node: GeometryInstance3D = entry.node
		node.visible = false
		await _frames(2)
		await _save("rank_%02d_without_%s" % [index + 1, str(node.name).replace("/", "_")])
		node.visible = true
		await _frames(2)

func _collect_geometry(node: Node, found: Array[GeometryInstance3D]) -> void:
	if node is GeometryInstance3D:
		found.append(node)
	for child in node.get_children():
		_collect_geometry(child, found)

func _dark_foreground_difference(baseline: Image, without: Image) -> int:
	var score := 0
	for y in range(280, 640, 5):
		for x in range(15, 960, 5):
			var before := baseline.get_pixel(x, y)
			var after := without.get_pixel(x, y)
			var luminance := before.r * 0.2126 + before.g * 0.7152 + before.b * 0.0722
			if luminance < 0.28 and absf(before.r - after.r) + absf(before.g - after.g) + absf(before.b - after.b) > 0.09:
				score += 1
	return score

func _collect(node: Node, category: String, found: Array[Node3D]) -> void:
	if node is Node3D:
		var name_text := str(node.name)
		var matches := (category == "berm" and name_text == "RoundedEarthBerm") \
			or (category == "forest_rock" and name_text == "forest_rock") \
			or (category == "deadfall" and name_text == "DeadfallBatch") \
			or (category == "detail_batch" and name_text.begins_with("AuthoredDetailBatch_")) \
			or (category == "terrain_batch" and name_text.begins_with("TerrainPatchBatch_"))
		if matches:
			found.append(node)
			return
	for child in node.get_children():
		_collect(child, category, found)

func _save(stem: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		push_error("Invalid slab diagnostic frame: " + stem)
		return
	var path := OUTPUT_DIR + "/" + stem + ".png"
	var result := image.save_png(path)
	if result != OK:
		push_error("Cannot save slab diagnostic frame: " + stem)
	else:
		print("SLAB DIAGNOSTIC CAPTURE " + path)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
