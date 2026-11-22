extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var timeout := Timer.new()
	timeout.wait_time = 30.0
	timeout.one_shot = true
	timeout.autostart = true
	timeout.timeout.connect(func(): _finish(1, "render-resource verifier timed out"))
	root.add_child(timeout)
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "Main scene failed to load")
	if scene == null:
		_finish(1)
		return
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	for _frame in range(20):
		await process_frame
		if game.game_started and not game.zone_transition_pending:
			break
	_check(game.game_started, "Game did not start")
	_check(not game.zone_transition_pending, "Greyfen did not settle")
	_scan_geometry(game)
	if failures.is_empty():
		print("RENDER RESOURCE VERIFIER: PASS")
	else:
		print("RENDER RESOURCE VERIFIER: FAIL (%d)" % failures.size())
	for failure in failures:
		push_error(failure)
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	for _frame in range(game.ZONE_RETIRE_FRAMES + 4):
		await process_frame
	game.free()
	for _frame in range(8):
		await process_frame
	_finish(0 if failures.is_empty() else 1)

func _scan_geometry(root_node: Node) -> void:
	for raw_node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := raw_node as MeshInstance3D
		if mesh_node.mesh == null:
			_check(false, "MeshInstance has no mesh: %s" % mesh_node.get_path())
			continue
		for surface_index in range(mesh_node.mesh.get_surface_count()):
			var material: Material = mesh_node.get_surface_override_material(surface_index)
			if material == null:
				material = mesh_node.material_override
			if material == null:
				material = mesh_node.mesh.surface_get_material(surface_index)
			_check(material != null, "Null mesh material: %s surface %d" % [mesh_node.get_path(), surface_index])
	for raw_node in root_node.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := raw_node as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.mesh == null:
			_check(false, "Incomplete MultiMeshInstance: %s" % batch.get_path())
			continue
		for surface_index in range(batch.multimesh.mesh.get_surface_count()):
			var material: Material = batch.material_override
			if material == null:
				material = batch.multimesh.mesh.surface_get_material(surface_index)
			_check(material != null, "Null multimesh material: %s surface %d" % [batch.get_path(), surface_index])

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)

func _finish(code: int, message: String = "") -> void:
	if message != "":
		push_error(message)
	quit(code)
