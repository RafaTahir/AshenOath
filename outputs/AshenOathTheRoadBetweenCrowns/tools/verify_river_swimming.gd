extends SceneTree

var failures := 0

func _initialize() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	check(packed != null, "Main scene is missing")
	if packed == null:
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await process_frame
	check(str(game.current_zone_id) == "greyfen", "New Game did not start in Greyfen")
	check(_has_named(game.zone_root, "LivingRiverSection"), "Greyfen river section is missing")
	check(_has_named(game.zone_root, "FlowingRiverWater"), "Greyfen water surface is missing")
	check(_has_named(game.zone_root, "SwimmableRiverVolume"), "Greyfen swim volume is missing")
	check(_has_named(game.zone_root, "RiverBridgeDeck"), "Greyfen crossing bridge is missing")
	check(_count_named(game.zone_root, "BridgePlank") >= 9, "Greyfen bridge lacks authored planks")
	check(_count_named(game.zone_root, "RiverBankStone") >= 10, "Greyfen banks lack grounding detail")
	var initial_direction: Vector3 = Vector3(0.32, 0.0, 0.0)
	game.player.enter_water({"surface_y":0.08,"current":initial_direction,"safe_exit":Vector3(0,0.8,0)})
	check(game.player.is_swimming(), "Player did not enter swimming state")
	check(str(game.player.get_water_state().state) == "surface_swim", "Swimming state contract is invalid")
	game.player.exit_water()
	check(not game.player.is_swimming(), "Player did not leave swimming state")
	game.call("_load_zone", "wychwood", Vector3(0,1,8))
	await process_frame
	check(_has_named(game.zone_root, "LivingRiverSection"), "Wychwood river continuation is missing")
	check(_has_named(game.zone_root, "SwimmableRiverVolume"), "Wychwood swim volume is missing")
	check(_has_named(game.zone_root, "RiverBridgeDeck"), "Wychwood crossing bridge is missing")
	check(game.player.has_signal("breath_changed"), "Swimming breath signal is missing")
	check(game.player.has_signal("splash_requested"), "Swimming splash signal is missing")
	print("RIVER/SWIMMING VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _has_named(parent: Node, target: String) -> bool:
	return parent.find_child(target, true, false) != null

func _count_named(parent: Node, target: String) -> int:
	var count := 1 if str(parent.name).begins_with(target) else 0
	for child in parent.get_children():
		count += _count_named(child, target)
	return count

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
