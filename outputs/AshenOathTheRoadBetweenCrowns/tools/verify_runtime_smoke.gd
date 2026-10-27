extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "Main scene failed to load")
	if scene == null:
		_finish()
		return
	var game := scene.instantiate()
	root.add_child(game)
	await _frames(12)
	_check(game != null and is_instance_valid(game), "Game root failed to initialize")
	_check(game.get("runtime_services") != null, "Runtime services were not initialized")
	_check(not bool(game.get("resource_shutdown_prepared")), "Runtime entered shutdown during smoke test")
	_check(not bool(game.get("game_started")), "Boot started a journey without explicit New Game")
	var deadline := Time.get_ticks_msec() + 120000
	while not game.opening_startup_metrics.has("menu_ready_ms") and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(game.opening_startup_metrics.has("menu_ready_ms"), "Main menu never reached usable readiness")
	game.call("_new_game")
	_check(await preload("res://tools/runtime_fixture.gd").ready(game, "greyfen"), "Explicit New Game readiness failed")
	_check(game.get("world_materials") != null, "World material service was not initialized before control")
	_check(bool(game.get("game_started")) and game.current_zone_id == "greyfen", "Explicit New Game did not enter Greyfen")
	_check(game.zone_root != null and game.player != null and bool(game.player.can_control), "Greyfen never reached playable readiness")

	# Runtime smoke owns teardown explicitly. This keeps normal shutdown errors
	# attributable to the game lifecycle instead of an unconditional quit timer.
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	await _frames(20)
	if game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
	await _frames(12)
	print("VERIFIER_PHASE: SHUTDOWN")
	if game.is_inside_tree():
		root.remove_child(game)
	if is_instance_valid(game):
		game.free()
	RenderingServer.force_sync()
	await _frames(8)
	RenderingServer.force_sync()
	_check(not is_instance_valid(game), "Game root did not retire after smoke teardown")
	if failures.is_empty():
		print("RUNTIME SMOKE: PASS")
	else:
		print("RUNTIME SMOKE: FAIL")
		for failure in failures:
			push_error(failure)
	_finish(0 if failures.is_empty() else 1)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)

func _finish(code: int = 1) -> void:
	call_deferred("quit", code)
