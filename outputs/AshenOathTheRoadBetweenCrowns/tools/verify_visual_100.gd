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
	var found: Dictionary = {}
	_collect_features(game.zone_root, found)
	game.call("_load_zone", "wychwood", Vector3.ZERO)
	await _frames(3)
	_collect_features(game.zone_root, found)
	for id in range(1, 101):
		_assert(found.has(id), "Visual100 feature %03d is missing from the playable slice" % id)
	_assert(game.zone_root.find_child("WorldMotionController", true, false) != null, "shared world motion controller is missing")
	_assert(game.zone_root.find_child("SurfaceFeedbackManager", true, false) != null, "surface feedback manager is missing")
	game.queue_free()
	await process_frame
	_finish()

func _collect_features(node: Node, found: Dictionary) -> void:
	if node.has_meta("feature_id"):
		found[int(node.get_meta("feature_id"))] = true
	for child in node.get_children(): _collect_features(child, found)

func _frames(count: int) -> void:
	for _i in range(count): await process_frame

func _assert(condition: bool, message: String) -> void:
	if not condition: failures.append(message); push_error(message)

func _finish() -> void:
	if not failures.is_empty():
		print("Visual100 verification failed")
		quit(1); return
	print("Visual100 verification complete: all 100 numbered improvements are present")
	quit()
