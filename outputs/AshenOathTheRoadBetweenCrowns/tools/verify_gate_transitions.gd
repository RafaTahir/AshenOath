extends SceneTree

var failures := 0

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "Main scene is unavailable")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_on_launch_accepted")
	await process_frame
	await process_frame
	var new_game_started := Time.get_ticks_msec()
	game.call("_new_game")
	await wait_for_zone(game, "greyfen")
	var click_to_play_ms := Time.get_ticks_msec() - new_game_started
	check(click_to_play_ms < 1500, "Prewarmed New Game exceeded 1500 ms: %d ms" % click_to_play_ms)
	print("NEW GAME CLICK-TO-PLAY: %d ms" % click_to_play_ms)
	await use_gate(game, "deep_wood")
	await use_gate(game, "wychwood")
	await use_gate(game, "greyfen")
	await use_gate(game, "vargan_approach")
	await use_gate(game, "vargan_court")
	await use_gate(game, "vargan_approach")
	check(not game.zone_transition_pending, "Final gate left the loading state active")
	check(game.player != null and game.player.can_control, "Final gate did not restore player control")
	print("GATE TRANSITION VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func use_gate(game, target: String) -> void:
	var gate = find_gate(game.zone_root, target)
	check(gate != null, "Missing real gate from %s to %s" % [game.current_zone_id, target])
	if gate == null:
		return
	game.call("_handle_interaction", gate)
	await wait_for_zone(game, target)

func find_gate(scope: Node, target: String):
	for node in scope.find_children("*", "Area3D", true, false):
		if str(node.get("interaction_type")) == "zone" and str(node.get("zone_target")) == target:
			return node
	return null

func wait_for_zone(game, target: String) -> void:
	for _frame in range(120):
		if game.current_zone_id == target and not game.zone_transition_pending and game.player != null:
			check(game.player.global_position.y > -2.0, "%s arrival left Kael below the world" % target)
			check(absf(game.player.velocity.x) < 0.05 and absf(game.player.velocity.z) < 0.05, "%s arrival retained lateral velocity" % target)
			check(not game.hud.loading_layer.visible, "%s arrival left the loading overlay visible" % target)
			return
		await process_frame
	check(false, "%s did not become playable within 120 frames" % target)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
