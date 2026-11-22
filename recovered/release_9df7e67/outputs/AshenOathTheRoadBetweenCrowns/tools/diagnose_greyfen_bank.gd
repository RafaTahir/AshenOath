extends SceneTree

const OUTPUT_DIR := "D:/Temp/AshenOath/world001/greyfen_bank"

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Bank diagnostic requires a graphical renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(2)
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	await _frames(16)
	game.camera_rig.set_process(false)
	game.camera_rig.camera.look_at_from_position(Vector3(0, 2.2, 10.2), Vector3(0, 0.35, 4.5), Vector3.UP)
	await _frames(24)
	var river: Node = game.zone_root.find_child("LivingRiverSection", true, false)
	await _capture("baseline")
	for category in ["Ground"]:
		var hidden: Array[GeometryInstance3D] = []
		_collect(game.zone_root if category == "Ground" else river, category, hidden)
		for node in hidden:
			node.visible = false
		await _frames(3)
		await _capture("without_" + category)
		for node in hidden:
			node.visible = true
		print("GREYFEN BANK DIAGNOSTIC %s hidden=%d" % [category, hidden.size()])
		await _frames(3)
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(20)
	if game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
		await _frames(12)
	game.queue_free()
	await _frames(8)
	RenderingServer.force_sync()
	quit(0)

func _collect(node: Node, category: String, found: Array[GeometryInstance3D]) -> void:
	if node is GeometryInstance3D:
		var node_name := str(node.name)
		var matches := (category == "BankSlope" and node_name.ends_with("BankSlope")) \
			or (category == "BankWetness" and node_name.begins_with("RiverBankWetness")) \
			or (category == "ShoreFoam" and node_name.begins_with("RiverShoreFoam")) \
			or (category == "RiverBoxes" and node_name == "RiverBoxBatch_river_boxes") \
			or (category == "Water" and node_name == "FlowingRiverWater") \
			or (category == "Ground" and (node_name.contains("Ground") or (node_name == "Surface" and str(node.get_parent().name).begins_with("Ground"))))
		if matches:
			found.append(node)
	for child in node.get_children():
		_collect(child, category, found)

func _capture(stem: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		push_error("Invalid Greyfen bank diagnostic: " + stem)
		return
	var path := OUTPUT_DIR + "/" + stem + ".png"
	if image.save_png(path) != OK:
		push_error("Cannot save Greyfen bank diagnostic: " + stem)
	else:
		print("GREYFEN BANK CAPTURE " + path)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
