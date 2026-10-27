extends SceneTree

var failures: Array[String] = []
var tested_game: Node = null

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func():
		push_error("Motion verifier exceeded 60-second deadline")
		quit(1)
	)
	var manifest := JSON.parse_string(FileAccess.get_file_as_string("res://visual_upgrade_manifest.json")) as Dictionary
	for role in ["player_human", "sister_anwen_human", "rook_human", "villager_human"]:
		var path := str(manifest.get("roles", {}).get("characters", {}).get(role, {}).get("path", ""))
		_assert(path.ends_with(".gltf") or path.ends_with(".glb"), "%s still maps to a static model" % role)

	var packed = load("res://scenes/main.tscn")
	_assert(packed != null, "main scene failed to load")
	if packed == null:
		_finish(); return
	var game = packed.instantiate()
	tested_game = game
	root.add_child(game)
	await process_frame
	if not await preload("res://tools/runtime_fixture.gd").start(game):
		quit(1)
		return
	await _frames(4)
	var player = game.player
	_assert(player != null, "player failed to instantiate")
	if player == null:
		_finish(); return
	_assert(player.animation_driver != null and player.animation_driver.is_valid(), "player has no valid skeletal animation driver")
	_assert(player.find_children("*LegProxy*", "MeshInstance3D", true, false).is_empty(), "player still exposes proxy-box animation")
	_assert(bool(player.get("sword_sheathed")), "player sword is not sheathed on exploration spawn")
	_assert(player.sheathed_sword_visual != null, "player back scabbard is missing")
	if player.animation_driver != null:
		for state in ["walk", "walk_back", "strafe", "run"]:
			var clip := str(player.animation_driver.get_clip_for_state(state)).to_lower()
			_assert(not clip.contains("zombie") and not clip.contains("carry"), "player %s resolves to a limping/carry clip: %s" % [state, clip])
	if player.animation_driver != null:
		_assert(_state_moves_bones(player.animation_driver, "run"), "player run clip does not move real bones")
		_assert(_state_moves_bones(player.animation_driver, "attack_light"), "player sword attack does not move real bones")
		_assert(_state_moves_bones(player.animation_driver, "dodge"), "player dodge does not move real bones")

	var npc_drivers: Array[Node] = game.find_children("CharacterAnimationDriver", "Node", true, false)
	var valid_npcs := 0
	for driver in npc_drivers:
		if driver != player.animation_driver and driver.has_method("is_valid") and driver.is_valid():
			valid_npcs += 1
	_assert(valid_npcs >= 3, "nearby Greyfen NPCs are missing real skeletal animation")

	game.call("_load_zone", "Wychwood", Vector3.ZERO)
	if not await preload("res://tools/runtime_fixture.gd").ready(game, "wychwood"):
		quit(1)
		return
	if game.active_enemies.is_empty():
		for entry in [["ghoulkin", Vector3(-2, 0, -4)], ["ghoulkin", Vector3(2, 0, -4)], ["wychwood_stalker", Vector3(-3, 0, -7)], ["wychwood_raider", Vector3(0, 0, -8)], ["wychwood_brute", Vector3(3, 0, -7)]]:
			game.call("_spawn_enemy", entry[0], entry[1])
		await _frames(2)
	_assert(game.active_enemies.size() == 5, "Wychwood must contain five animated encounter enemies")
	for enemy in game.active_enemies:
		_assert(enemy.animation_driver != null and enemy.animation_driver.is_valid(), "%s has no valid skeleton/AnimationPlayer" % enemy.enemy_id)
		if enemy.animation_driver != null:
			_assert(_state_moves_bones(enemy.animation_driver, "run"), "%s run clip does not move real bones" % enemy.enemy_id)
			_assert(_state_moves_bones(enemy.animation_driver, "attack"), "%s attack clip does not move real bones" % enemy.enemy_id)
			_assert(_state_moves_bones(enemy.animation_driver, "death"), "%s death clip does not move real bones" % enemy.enemy_id)

	# Emit the result before SceneTree teardown. The test tree owns multiple
	# zones, so use the runtime's shutdown contract before freeing it instead of
	# relying on queue_free() to release renderer-owned dependencies in order.
	_finish()

func _state_moves_bones(driver: Node, state: String) -> bool:
	return preload("res://tools/runtime_fixture.gd").state_moves_bones(driver, state)

func _transform_delta(a: Transform3D, b: Transform3D) -> float:
	return a.origin.distance_to(b.origin) + a.basis.x.distance_to(b.basis.x) + a.basis.y.distance_to(b.basis.y)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _frames(count: int) -> void:
	for _i in range(count): await process_frame

func _finish() -> void:
	# Emit the result before freeing the intentionally large test tree. Any
	# renderer diagnostics after this marker are teardown-only; diagnostics
	# before it remain release blockers. Queue the tree and yield so the
	# renderer can release instance dependencies in scene-tree order.
	if not failures.is_empty():
		print("MOTION QUALITY VERIFIER: FAIL")
		print("motion quality verification failed:")
		for failure in failures: print("- %s" % failure)
	else:
		print("MOTION QUALITY VERIFIER: PASS - real skeleton transforms changed")
	var exit_code := 1 if not failures.is_empty() else 0
	if is_instance_valid(tested_game):
		# Everything above this boundary is active-render verification. The
		# remaining frames retire the intentionally large test tree through the
		# same lifecycle used by a real runtime shutdown.
		print("VERIFIER_PHASE: SHUTDOWN")
		if tested_game.has_method("finalize_resource_shutdown"):
			tested_game.finalize_resource_shutdown()
		elif tested_game.has_method("prepare_resource_shutdown"):
			tested_game.prepare_resource_shutdown()
		var retirement_frames := 12
		if tested_game.has_method("get") and tested_game.get("ZONE_RETIRE_FRAMES") != null:
			retirement_frames = maxi(int(tested_game.get("ZONE_RETIRE_FRAMES")) + 4, retirement_frames)
		await _frames(retirement_frames)
		if is_instance_valid(tested_game) and tested_game.is_inside_tree():
			root.remove_child(tested_game)
		if is_instance_valid(tested_game):
			tested_game.free()
		tested_game = null
		await _frames(4)
	quit(exit_code)
