extends SceneTree

const SpatialSurfaceContract = preload("res://scripts/spatial_surface_contract.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var capture := "--capture" in OS.get_cmdline_user_args()
	if capture and DisplayServer.get_name().to_lower() == "headless":
		_check(false, "Board capture requires graphical rendering")
		_finish()
		return
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main scene is unavailable")
	if packed == null:
		_finish()
		return
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline and (game.zone_root == null or not bool(game.zone_root.get_meta("opening_detail_complete", false))):
		await process_frame
	_check(game.zone_root != null and bool(game.zone_root.get_meta("opening_detail_complete", false)), "Board presentation requires the complete opening scene")
	var camera: Camera3D
	if capture:
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1280, 720)
		game.hud.hide()
		camera = Camera3D.new()
		root.add_child(camera)
		camera.current = true
	for id in ["common_table", "barrel_board"]:
		var area: Node = game.zone_root.find_child(id, true, false)
		_check(area != null, "physical board table is missing: %s" % id)
		if area == null:
			continue
		var chairs: Array = []
		for candidate in area.find_children("*", "", true, false):
			if str(candidate.name).begins_with("BoardGameChair"):
				chairs.append(candidate)
		_check(chairs.size() >= 2, "board table lacks two chairs: %s" % id)
		var furniture := area.find_child("GreyfenSocialFurniture", true, false) as MeshInstance3D
		_check(furniture != null and furniture.mesh != null, "Board table lacks complete authored furniture: " + id)
		if furniture != null and furniture.mesh != null:
			_check(furniture.mesh.get_surface_count() == 2, "Authored seating and table surfaces are incomplete: " + id)
			_check(furniture.mesh.get_aabb().position.y >= -0.002, "Furniture is not grounded: " + id)
			var footprint := furniture.mesh.get_aabb()
			for local_x in [footprint.position.x, footprint.end.x]:
				for local_z in [footprint.position.z, footprint.end.z]:
					var corner := furniture.to_global(Vector3(local_x, 0.0, local_z))
					_check(not SpatialSurfaceContract.is_river_excluded("greyfen", corner, 0.0), "Social seating crosses the Greyfen river: %s %s" % [id, corner])
			_check(furniture.mesh.get_faces().size() / 3 == 1978, "Native chair/table geometry was removed: " + id)
			var sources: Dictionary = furniture.mesh.get_meta("source_sha256", {})
			for source in ["Table_Large.obj", "Chair_1.obj"]:
				_check(sources.get(source, "") == FileAccess.get_sha256("res://assets_external/environment/props/" + source), "Native furniture source identity drift: " + source)
		_check(area.find_child("%s_Opponent" % id, true, false) != null, "board table lacks its opponent: %s" % id)
		_check(area.find_child("BoardGameBeckoningGesture", true, false) == null, "board opponent still has a proxy hand: %s" % id)
		var invitation: Node = area.find_child("BoardGameOpponentController", true, false)
		_check(invitation != null and invitation.animation_driver != null, "board opponent lacks a skeletal invitation: %s" % id)
		var squares := 0
		for batch in area.find_children("%s_BoardSquares*" % id, "MultiMeshInstance3D", true, false):
			squares += batch.multimesh.instance_count
		_check(squares == (9 if id == "common_table" else 36), "physical board lost squares: %s" % id)
		if capture:
			var dimensions := Vector3(2.8, 0.85, 1.8) if id == "common_table" else Vector3(2.2, 0.85, 1.5)
			var columns := 3 if id == "common_table" else 6
			var board := Vector2(dimensions.x * 0.70, dimensions.z * 0.68)
			var occupied: Dictionary = {}
			for parity in range(2):
				var batch := area.find_child("%s_BoardSquares_%d" % [id, parity], true, false) as MultiMeshInstance3D
				_check(batch != null, "physical board color batch missing")
				if batch == null:
					continue
				for index in range(batch.multimesh.instance_count):
					var transform := batch.multimesh.get_instance_transform(index)
					var column := int(round((transform.origin.x + board.x * 0.5) / (board.x / columns) - 0.5))
					var row := int(round((transform.origin.z + board.y * 0.5) / (board.y / columns) - 0.5))
					var cell := Vector2i(column, row)
					_check(column >= 0 and column < columns and row >= 0 and row < columns and (row + column) % 2 == parity, "board square misplaced or wrong parity")
					_check(not occupied.has(cell), "board squares overlap")
					occupied[cell] = true
					_check(is_equal_approx(transform.origin.y, dimensions.y + 0.14), "board square has incorrect height")
					_check(transform.basis.get_scale().is_equal_approx(Vector3(board.x / columns - 0.018, 0.018, board.y / columns - 0.018)), "board square dimensions changed")
			_check(occupied.size() == columns * columns, "rendered board cells incomplete")
			game.player.global_position = area.global_position + Vector3(0, 0.1, 3.0)
			camera.global_position = area.global_position + Vector3(2.5, 2.6, 3.8)
			camera.look_at(area.global_position + Vector3(0, 0.9, 0))
			var invitation_deadline := Time.get_ticks_msec() + 2000
			while invitation != null and not bool(invitation.invitation_started) and Time.get_ticks_msec() < invitation_deadline:
				await process_frame
			_check(invitation != null and bool(invitation.invitation_started), "nearby opponent did not start skeletal invitation: " + id)
			await _frames(12)
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			_check(image.get_size() == Vector2i(1280, 720), "board capture dimensions incorrect")
			_check(image.save_png("D:/Temp/AshenOath/board_%s_batch.png" % id) == OK, "board screenshot failed: " + id)
	var minigames: Node = game.minigames
	minigames.open_game("draughts")
	await _frames(2)
	_check(minigames.board_grid.get_child_count() == 36, "draughts board did not render 36 squares")
	minigames.call("_on_draughts_square", 6)
	_check(not minigames.draughts_legal_targets.is_empty(), "draughts selection has no highlighted legal destinations")
	minigames.close_game()
	game.prepare_resource_shutdown()
	if camera != null:
		camera.queue_free()
	await _frames(20)
	game.queue_free()
	await _frames(8)
	_finish()

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)

func _finish() -> void:
	print("MINIGAME PRESENTATION VERIFIER: %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	quit(0 if failures.is_empty() else 1)
