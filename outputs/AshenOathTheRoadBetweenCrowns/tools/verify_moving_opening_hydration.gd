extends SceneTree

var failure := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._on_launch_accepted()
	var deadline := Time.get_ticks_msec() + 30000
	while not game.route_zone_cache.has("greyfen") and Time.get_ticks_msec() < deadline:
		await process_frame
	if not game.route_zone_cache.has("greyfen"):
		failure = "Opening cache unavailable"
	else:
		game._new_game()
		deadline = Time.get_ticks_msec() + 30000
		while (game.player == null or not game.game_started) and Time.get_ticks_msec() < deadline:
			await process_frame
		if game.player == null or not game.game_started:
			failure = "Player startup unavailable"
		else:
			# Scheduler fixture, not a real-input route: keep velocity nonzero without
			# moving into another zone while required content is being published.
			game.player.set_physics_process(false)
			game.player.velocity = Vector3(1, 0, 0)
			var scenery_boundary: int = game.OPENING_DETAIL_STAGES.find("opening_river_visual")
			deadline = Time.get_ticks_msec() + 30000
			while game.opening_detail_stage_index < scenery_boundary and Time.get_ticks_msec() < deadline:
				await process_frame
			if game.opening_detail_stage_index != scenery_boundary:
				failure = "Moving player starved gameplay hydration: stage=%s" % game.opening_detail_stage_index
			for actor_id in ["mira", "rook", "widow_elna", "blacksmith_tor", "farmer_toma", "common_table", "barrel_board"]:
				if game.zone_root.find_children(actor_id, "", true, false).size() != 1:
					failure = "Required interaction missing or duplicated: " + actor_id
			await create_timer(0.4).timeout
			if failure == "" and game.opening_detail_stage_index != scenery_boundary:
				failure = "Scenery movement safeguard was lost"
	game.prepare_resource_shutdown()
	for frame in range(12):
		await process_frame
	game.finalize_resource_shutdown()
	for frame in range(4):
		await process_frame
	game.queue_free()
	for frame in range(12):
		await process_frame
	if failure != "":
		push_error(failure)
	print("MOVING OPENING HYDRATION: " + ("PASS" if failure == "" else "FAIL: " + failure))
	quit(0 if failure == "" else 1)
