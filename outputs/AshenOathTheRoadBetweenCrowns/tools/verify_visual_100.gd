extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var packed = load("res://scenes/main.tscn")
	_assert(packed != null, "main scene failed to load")
	if packed == null: _finish(); return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _frames(3)
	_assert(game.zone_root.find_child("AuthoredVisualLayer_Greyfen", true, false) != null, "authored Greyfen visual layer is missing")
	_assert(not _has_synthetic_feature(game.zone_root), "synthetic Visual100 marker geometry remains in Greyfen")
	_assert(_has_textured_surface(game.zone_root), "Greyfen has no textured authored surface")
	game.call("_load_zone", "wychwood", Vector3.ZERO)
	await _frames(3)
	_assert(game.zone_root.find_child("AuthoredVisualLayer_Wychwood", true, false) != null, "authored Wychwood visual layer is missing")
	_assert(not _has_synthetic_feature(game.zone_root), "synthetic Visual100 marker geometry remains in Wychwood")
	_assert(_has_textured_surface(game.zone_root), "Wychwood has no textured authored surface")
	_assert(game.zone_root.find_child("WorldMotionController", true, false) != null, "shared world motion controller is missing")
	_assert(game.zone_root.find_child("SurfaceFeedbackManager", true, false) != null, "surface feedback manager is missing")
	await _finish(game)

func _has_synthetic_feature(node: Node) -> bool:
	if node.has_meta("feature_id") or node.name.begins_with("Visual100Feature"):
		return true
	for child in node.get_children():
		if _has_synthetic_feature(child): return true
	return false

func _has_textured_surface(node: Node) -> bool:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var material := mesh_node.material_override as StandardMaterial3D
		# Balanced keeps authored albedo at native 720p while Quality enables
		# the normal/ORM stack verified by verify_visual_003.gd.
		if material != null and material.albedo_texture != null:
			return true
	for child in node.get_children():
		if _has_textured_surface(child): return true
	return false

func _frames(count: int) -> void:
	for _i in range(count): await process_frame

func _assert(condition: bool, message: String) -> void:
	if not condition: failures.append(message); push_error(message)

func _shutdown_game(game: Node) -> void:
	if is_instance_valid(game) and game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(20)
	if is_instance_valid(game) and game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
		await _frames(12)
	print("VERIFIER_PHASE: SHUTDOWN")
	if is_instance_valid(game):
		game.queue_free()
		await _frames(8)
	RenderingServer.force_sync()
	await _frames(4)

func _finish(game: Node = null) -> void:
	var result_code := 0 if failures.is_empty() else 1
	await _shutdown_game(game)
	if failures.is_empty():
		print("VISUAL100 VERIFIER: PASS - synthetic markers removed; authored systems present")
	else:
		print("Visual100 verification failed (%d)" % failures.size())
	quit(result_code)
