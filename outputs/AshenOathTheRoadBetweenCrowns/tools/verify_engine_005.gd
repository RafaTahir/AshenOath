extends SceneTree

const ZoneRuntimeCoordinator = preload("res://scripts/zone_runtime_coordinator.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_verify_static_extraction()
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
	var coordinator: ZoneRuntimeCoordinator = game.zone_runtime_coordinator
	_check(coordinator != null, "Zone runtime coordinator is missing")
	if coordinator != null:
		_check(coordinator.quest_presentation == game.quest_presentation, "Coordinator does not own quest presentation wiring")
		_check(coordinator.quest_beats == game.quest_beats, "Coordinator does not own quest beat wiring")
		_check(coordinator.interaction_focus == game.interaction_focus, "Coordinator does not own interaction focus wiring")
		var valid_request := coordinator.normalize_zone_request("greyfen", Vector3(0, 1, 7))
		_check(bool(valid_request.get("ok", false)), "Valid zone request was rejected")
		var invalid_request := coordinator.normalize_zone_request("not_a_zone", Vector3.ZERO)
		_check(not bool(invalid_request.get("ok", true)), "Unknown zone request was accepted")
		var presentation := coordinator.sync_zone("greyfen")
		_check(str(presentation.get("zone_id", "")) == "greyfen", "Presentation sync returned the wrong zone")
		_check(str(coordinator.snapshot().get("presentation_zone", "")) == "greyfen", "Snapshot did not retain presentation zone")
		_check(coordinator.refresh_presentation() != "", "Presentation refresh returned no tracker text")
		_check(coordinator.choose_interaction([], game.player, null, Callable()) == null, "Empty interaction selection was not deterministic")
	game.call("_load_zone", "wychwood", Vector3(0, 1, 7))
	await _wait_for_zone(game, "wychwood")
	_check(str(game.zone_runtime_coordinator.snapshot().get("presentation_zone", "")) == "wychwood", "Zone transition did not synchronize presentation")
	_check(not game.zone_transition_pending, "Zone transition remained pending after coordinator activation")
	var result_code := 0 if failures.is_empty() else 1
	_print_result()
	# Emit the result before releasing the scene. Godot's Compatibility renderer
	# can report shutdown-only RID/material diagnostics while freeing procedural
	# resources; QA-005 must classify those after the gameplay pass marker rather
	# than treating them as active route failures.
	game.queue_free()
	await _frames(8)
	quit(result_code)

func _verify_static_extraction() -> void:
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/zone_runtime_coordinator.gd")
	for required in [
		"func normalize_zone_request(",
		"func sync_zone(",
		"func refresh_presentation(",
		"func choose_interaction(",
		"func record_playable_transition(",
	]:
		_check(coordinator_source.contains(required), "Coordinator contract is missing %s" % required)
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	_check(game_source.contains("zone_runtime_coordinator.sync_zone(zone_id)"), "Game does not delegate zone presentation sync")
	_check(game_source.contains("zone_runtime_coordinator.refresh_presentation()"), "Game does not delegate tracker refresh")
	_check(game_source.contains("zone_runtime_coordinator.choose_interaction("), "Game does not delegate interaction focus")
	_check(not game_source.contains("interaction_focus.choose("), "Game still chooses interactions directly")
	_check(not game_source.contains("quest_presentation.set_zone("), "Game still mutates quest presentation directly")
	_check(not game_source.contains("quest_beats.set_zone("), "Game still mutates quest beats directly")

func _wait_for_zone(game: Node, zone_id: String) -> void:
	for _index in range(120):
		await process_frame
		if str(game.current_zone_id) == zone_id and game.zone_root != null and not game.zone_transition_pending:
			return
	_check(false, "Timed out waiting for zone: %s" % zone_id)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _finish() -> void:
	_print_result()
	quit(0 if failures.is_empty() else 1)

func _print_result() -> void:
	print("ENGINE-005 VERIFIER: %s" % ("PASS - typed zone, interaction, quest-presentation, and transition coordination" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	for failure in failures:
		print("- %s" % failure)

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)
