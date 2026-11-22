extends SceneTree

const DEADLINE_MS := 15000

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("opening fast-click readiness requires graphical rendering")
		return
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("main scene is unavailable")
		return
	var game := packed.instantiate()
	root.add_child(game)
	# The click occurs before the deferred Greyfen builder can publish its cache.
	game.call("_new_game")
	if not game.new_game_start_pending or game.game_started or game.route_zone_cache.has("greyfen"):
		_fail("New Game did not queue while the menu prewarm was in flight")
		return
	var deadline := Time.get_ticks_msec() + DEADLINE_MS
	while Time.get_ticks_msec() < deadline and not game.game_started:
		await process_frame
	if not game.game_started or game.current_zone_id != "greyfen" or game.zone_root == null:
		_fail("queued New Game never reached Greyfen control")
		return
	if str(game.zone_root.get_meta("opening_build_profile", "")) != "opening_boot":
		_fail("queued New Game used a cold Greyfen build")
		return
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	for _index in range(game.ZONE_RETIRE_FRAMES + 6):
		await process_frame
	if game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
	for _index in range(8):
		await process_frame
	root.remove_child(game)
	game.free()
	print("OPENING FAST CLICK: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	print("OPENING FAST CLICK: FAIL - " + message)
	quit(1)
