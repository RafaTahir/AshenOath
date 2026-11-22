extends SceneTree

class DeferredGame extends "res://scripts/game.gd":
	var delayed_zone := ""
	var delayed_position := Vector3.ZERO
	func _load_zone_after_runtime_pack(id: String, position: Vector3) -> void:
		delayed_zone = id
		delayed_position = position

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(DeferredGame)
	root.add_child(game)
	await process_frame
	await process_frame
	game.load_save_state({"version":9, "zone":"greyfen", "player_position":[0,1,7], "player_health":{"health":47.0,"max_health":125.0}, "player_stamina":{"stamina":31.0,"max_stamina":100.0}})
	var passed: bool = game.player == null and not game.pending_player_restore.is_empty()
	game._load_zone(game.delayed_zone, game.delayed_position)
	passed = passed and game.player != null and game.pending_player_restore.is_empty()
	if game.player != null:
		passed = passed and is_equal_approx(game.player.health_component.health, 47.0)
		passed = passed and is_equal_approx(game.player.stamina_component.stamina, 31.0)
	game.prepare_resource_shutdown()
	for frame in int(game.ZONE_RETIRE_FRAMES) + 4:
		await process_frame
	game.queue_free()
	for frame in 8:
		await process_frame
	if not passed:
		push_error("Deferred save must apply once after player creation")
	print("DEFERRED PLAYER RESTORE: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
