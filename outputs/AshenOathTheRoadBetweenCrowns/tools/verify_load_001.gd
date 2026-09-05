extends SceneTree

## Focused startup gate for LOAD-001. It exercises the real menu/prewarm
## handoff, but keeps the assertions limited to readiness and ownership so it
## does not duplicate the broader route, visual, or performance suites.

var failures: Array[String] = []
var game: Node

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "main scene failed to load")
	if scene == null:
		_finish()
		return
	game = scene.instantiate()
	root.add_child(game)
	await _frames(2)
	game.hud.show_main_menu()
	paused = true
	var prewarm_started := Time.get_ticks_msec()
	game.call("_on_launch_accepted")
	var prewarm_ready := await _wait_for_prewarm(30.0)
	_check(prewarm_ready, "Greyfen prewarm did not publish within 30 seconds")
	if prewarm_ready:
		var root_node: Node3D = game.route_zone_cache.get("greyfen") as Node3D
		_check(root_node != null and is_instance_valid(root_node), "published Greyfen cache root is invalid")
		_check(str(root_node.get_meta("opening_build_profile", "")) == "opening_boot", "prewarm did not use the minimal opening_boot profile")
		_check(game.greyfen_prewarm_spatial_service != null, "prewarm spatial service was not retained for handoff")
		_check(bool(game.hud.new_game_ready), "New Game remained disabled after prewarm")
		print("LOAD-001: menu_prewarm_ms=%d" % (Time.get_ticks_msec() - prewarm_started))
	game.call("_new_game")
	var playable := await _wait_for_playable(10.0)
	_check(playable, "New Game did not reach Greyfen after prewarm")
	if playable:
		_check(str(game.current_zone_id) == "greyfen", "New Game activated the wrong zone")
		_check(game.player != null and is_instance_valid(game.player), "player was not activated")
		# The full gameplay stage is intentionally delayed by less than one second;
		# wait for that stage and prove the first objective's speaker appears.
		var hydrated := await _wait_for_node("sister_anwen", 3.0)
		_check(hydrated, "opening gameplay hydration did not add Sister Anwen")
		_check(game.opening_detail_pending, "opening detail pipeline was not retained for post-handoff hydration")
	_prepare_shutdown()
	await _frames(12)
	if game != null and game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
	await _frames(8)
	if game != null and is_instance_valid(game):
		if game.is_inside_tree():
			root.remove_child(game)
		game.free()
	RenderingServer.force_sync()
	await _frames(4)
	if failures.is_empty():
		print("LOAD-001: PASS")
	else:
		print("LOAD-001: FAIL")
		for failure in failures:
			push_error(failure)
	_finish(0 if failures.is_empty() else 1)

func _wait_for_prewarm(timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if game.route_zone_cache.has("greyfen") and game.greyfen_prewarm_spatial_service != null:
			return true
		await process_frame
	return false

func _wait_for_playable(timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(game.game_started) and str(game.current_zone_id) == "greyfen" and not bool(game.zone_transition_pending):
			return true
		await process_frame
	return false

func _wait_for_node(node_name: String, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if game.zone_root != null and game.zone_root.find_child(node_name, true, false) != null:
			return true
		await process_frame
	return false

func _prepare_shutdown() -> void:
	if game != null and game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)

func _finish(code: int = 1) -> void:
	quit(code)
