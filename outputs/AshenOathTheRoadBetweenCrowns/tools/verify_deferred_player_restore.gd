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
	var deadline := Time.get_ticks_msec() + 60000
	while game.delayed_zone == "" and Time.get_ticks_msec() < deadline:
		await process_frame
	var passed: bool = game.player == null and not game.pending_player_restore.is_empty()
	game._load_zone(game.delayed_zone, game.delayed_position)
	passed = passed and game.player != null and game.pending_player_restore.is_empty()
	if game.player != null:
		passed = passed and is_equal_approx(game.player.health_component.health, 47.0)
		passed = passed and is_equal_approx(game.player.stamina_component.stamina, 31.0)
		var retained_player: int = game.player.get_instance_id()
		game.player.health_component.damage(999.0)
		passed = passed and game.player.animation_driver.dead
		game.player.hurt_react_time = 0.5
		game.player.attack_cooldown = 0.7
		game.player.visual_root.rotation.z = 1.0
		game.pending_player_restore = {"health":{"health":47.0,"max_health":125.0}, "stamina":{"stamina":31.0,"max_stamina":100.0}, "equipment":game.player.save_equipment_state()}
		game._apply_pending_player_restore()
		passed = passed and game.player.get_instance_id() == retained_player
		passed = passed and not game.player.animation_driver.dead and game.player.animation_driver.current_state == "idle"
		passed = passed and not game.player.health_component.dead and is_equal_approx(game.player.health_component.health, 47.0)
		passed = passed and is_equal_approx(game.player.stamina_component.stamina, 31.0)
		passed = passed and is_zero_approx(game.player.hurt_react_time) and is_zero_approx(game.player.attack_cooldown)
		passed = passed and game.player.visual_root.transform.is_equal_approx(Transform3D.IDENTITY)
	game.prepare_resource_shutdown()
	for frame in int(game.ZONE_RETIRE_FRAMES) + 4:
		await process_frame
	game.finalize_resource_shutdown()
	game.queue_free()
	for frame in 8:
		await process_frame
	if not passed:
		push_error("Deferred save must apply once after player creation and release a cached player's death pose without healing")
	print("DEFERRED PLAYER RESTORE: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
