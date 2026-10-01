extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "Main scene is unavailable")
	if scene == null:
		_finish()
		return
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(3)
	game.call("_new_game")
	await _wait_for_zone(game, "greyfen")
	var actor_deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < actor_deadline:
		var published_actor: Node = game.zone_root.find_child("sister_anwen", true, false) if game.zone_root != null else null
		if published_actor != null and _find_interaction(game, "sister_anwen") != null:
			break
		await process_frame
	var actor_at_deadline: Node = game.zone_root.find_child("sister_anwen", true, false) if game.zone_root != null else null
	_check(_find_interaction(game, "sister_anwen") != null, "Deferred Greyfen hydration did not publish Anwen's interaction")
	game.call("_refresh_tracker")
	await _frames(2)

	var view: Dictionary = game.quest_presentation.get_objective_view_model()
	var action := str(view.get("contextual_text", ""))
	_check(str(view.get("quest_id", "")) == "main_road_of_crows", "Greyfen selected the wrong tracked quest")
	_check(str(view.get("objective_id", "")) == "speak_anwen", "Greyfen selected the wrong opening objective")
	_check(action != "", "Opening objective has no authored next action")
	_check(str(game.hud.tracker_label.text).contains(action), "Rendered tracker disagrees with the objective view")
	var compass_text := str(game.hud.compass_label.text)
	_check(compass_text.contains(str(view.get("zone_name", ""))), "Compass omits the objective zone")
	_check(compass_text.contains("m"), "Compass omits distance to the tracked Anwen interaction")
	_check(not compass_text.contains(action), "Compass duplicates the tracker action")
	_check(not game.hud.hint_label.visible or not str(game.hud.hint_label.text).contains(action), "Opening guidance duplicates the tracker action")

	var anwen: Node = actor_at_deadline
	_check(anwen != null and is_instance_valid(anwen) and anwen.has_method("get_context_prompt"), "Sister Anwen interaction is unavailable")
	if anwen != null and is_instance_valid(anwen):
		var decoy = anwen.duplicate()
		decoy.interaction_id = "unrelated_speaker"
		decoy.quest_id = "side_widows_bell"
		decoy.objective_id = "speak_widow"
		decoy.position = anwen.position + Vector3(0.1, 0, 0.1)
		anwen.get_parent().add_child(decoy)
		game.player.global_position = anwen.global_position + Vector3(0, 0, 2.0)
		var chosen: Node = game.zone_runtime_coordinator.choose_interaction(
			[decoy, anwen], game.player, null, Callable()
		)
		_check(chosen == anwen, "Runtime focus did not prioritize the authoritative objective target")
		if chosen != null and chosen.has_method("get_context_prompt"):
			game.hud.set_prompt("E - %s" % chosen.get_context_prompt())
			_check(str(game.hud.prompt_label.text).contains("Anwen"), "Rendered prompt does not identify the selected objective target")
		decoy.queue_free()

	var save_data: Dictionary = game.save_manager.call("_build_save_data", game)
	var saved_summary: Dictionary = save_data.get("quest_presentation", {}).get("objective_summary", {})
	var expected_summary: Dictionary = view.get("save_summary", {})
	_check(saved_summary == expected_summary, "Save payload objective summary differs from the rendered view")

	var result_code := 0 if failures.is_empty() else 1
	await _shutdown_game(game)
	_print_result()
	quit(result_code)

func _find_interaction(game: Node, interaction_id: String) -> Node:
	for candidate in game.interaction_area_cache:
		if candidate != null and is_instance_valid(candidate) and str(candidate.get("interaction_id")) == interaction_id:
			return candidate
	return null

func _wait_for_zone(game: Node, zone_id: String) -> void:
	for _index in range(180):
		await process_frame
		if str(game.current_zone_id) == zone_id and game.zone_root != null and not game.zone_transition_pending:
			return
	_check(false, "Timed out waiting for zone: %s" % zone_id)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _shutdown_game(game: Node) -> void:
	if game != null and is_instance_valid(game) and game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	await _frames(20)
	if game != null and is_instance_valid(game) and game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
	await _frames(12)
	print("VERIFIER_PHASE: SHUTDOWN")
	if game != null and is_instance_valid(game) and game.is_inside_tree():
		root.remove_child(game)
	if game != null and is_instance_valid(game):
		game.free()
	RenderingServer.force_sync()
	await _frames(8)

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)

func _print_result() -> void:
	print("QUEST-001 RUNTIME VERIFIER: %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	for failure in failures:
		print("- %s" % failure)

func _finish() -> void:
	_print_result()
	quit(0 if failures.is_empty() else 1)
