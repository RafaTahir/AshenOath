extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "Main scene is missing")
	if scene == null:
		await _finish(null)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _settle(10)
	_check(game.current_zone_id == "greyfen", "Greyfen did not start")
	_check(game.spatial_service != null, "Greyfen spatial service is missing")
	if game.spatial_service == null:
		await _finish(game)
		return

	var service = game.spatial_service
	var south_water := Vector3(7.0, -1.0, service.river_center + 0.4)
	game.player.global_position = south_water
	game.call("_recover_from_river", game.player, service.river_center, 3.4)
	_check(service.bank_for(game.player.global_position) == 1, "River recovery changed the requested bank")
	_check(not service.is_river_excluded(game.player.global_position, 0.4), "River recovery remained in water")
	_check(not service.is_position_occupied(game.player.global_position, 0.34, 1.6), "River recovery selected occupied space")

	var known_safe: Vector3 = service.nearest_safe(Vector3(0.0, 0.0, 12.5), 1)
	game.last_safe_player_position = known_safe
	game.player.global_position = Vector3(100.0, -12.0, 100.0)
	game.call("_keep_player_in_world")
	_check(service.bank_for(game.player.global_position) == 1, "Fall recovery changed the last validated bank")
	_check(not service.is_river_excluded(game.player.global_position, 0.4), "Fall recovery selected water")
	_check(not service.is_position_occupied(game.player.global_position, 0.34, 1.6), "Fall recovery selected occupied space")
	_check(game.player.velocity.is_zero_approx(), "Fall recovery retained player velocity")
	var checkpoint: Vector3 = service.nearest_safe(Vector3(0.0, 0.9, 9.8), 1)
	game.player.global_position = checkpoint
	game.last_safe_player_position = checkpoint
	game.player.global_position = checkpoint + Vector3(0.10, 0, 0)
	game.call("_keep_player_in_world")
	_check(game.last_safe_player_position.is_equal_approx(checkpoint), "Idle checkpoint was revalidated before meaningful movement")
	game.player.global_position = checkpoint + Vector3(0.36, 0, 0)
	game.call("_keep_player_in_world")
	_check(game.last_safe_player_position.is_equal_approx(game.player.global_position), "Clear movement did not refresh the safe checkpoint")

	var migrated: Vector3 = game.call("_safe_loaded_position", "greyfen", Vector3(8.0, -4.0, service.river_center))
	_check(service.bank_for(migrated) == 1, "Invalid saved position changed bank")
	_check(not service.is_river_excluded(migrated, 0.4), "Invalid saved position remained in water")
	_check(not service.is_position_occupied(migrated, 0.34, 1.6), "Invalid saved position remained occupied")

	var spawn: Vector3 = service.validate_position(Vector3(0.0, 0.9, -12.5), 0.8, -1)
	_check(service.bank_for(spawn) == -1, "Validated arrival changed bank")
	_check(not service.is_river_excluded(spawn, 0.4), "Validated arrival is in water")

	game.call("_relocate_anwen_to_cemetery")
	var anwen = game.zone_root.find_child("sister_anwen", true, false)
	_check(anwen != null, "Anwen relocation lost the actor")
	if anwen != null:
		_check(not service.is_river_excluded(anwen.global_position, 0.4), "Anwen relocated into water")

	await _finish(game)

func _finish(game) -> void:
	if failures.is_empty():
		print("SPAT-002 VERIFIER: PASS")
	else:
		print("SPAT-002 VERIFIER: FAIL (%d)" % failures.size())
		for failure in failures:
			push_error(failure)
	if game != null:
		if game.has_method("finalize_resource_shutdown"):
			game.finalize_resource_shutdown()
		await _settle(6)
		game.free()
		await _settle(4)
	quit(0 if failures.is_empty() else 1)

func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
