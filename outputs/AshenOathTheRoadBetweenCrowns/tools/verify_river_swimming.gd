extends SceneTree

const BridgeSurfaceContract = preload("res://scripts/bridge_surface_contract.gd")
const BRIDGE_LANE_DRIFT_TOLERANCE := 0.50

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
	await _settle(3)
	await _verify_zone(game,"greyfen",4.5)
	await _verify_physical_bridge_crossings(game, 4.5)
	game.call("_load_zone","wychwood",Vector3(0,1,8))
	await _settle(3)
	await _verify_zone(game,"wychwood",0.0)
	await _verify_physical_bridge_crossings(game, 0.0)
	check(not game.player.has_method("enter_water"), "Obsolete swimming entry remains active")
	check(not game.player.has_method("is_swimming"), "Obsolete swimming state remains active")
	print("VERIFIER_PHASE: SHUTDOWN")
	await _shutdown_game(game)
	print("RIVER-002 SAFETY VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _verify_zone(game, zone_id: String, center_z: float) -> void:
	check(str(game.current_zone_id) == zone_id, "%s did not load" % zone_id)
	check(_has_named(game.zone_root,"LivingRiverSection"), "%s river is missing" % zone_id)
	check(_has_named(game.zone_root,"FlowingRiverWater"), "%s water surface is missing" % zone_id)
	check(not _has_named(game.zone_root,"SwimmableRiverVolume"), "%s still contains a swimming volume" % zone_id)
	check(_count_named(game.zone_root,"RiverBankBarrier") == 4, "%s does not have four bank barriers" % zone_id)
	check(_count_named(game.zone_root,"RiverRecoveryVolume") == 2, "%s does not have two recovery volumes" % zone_id)
	check(_count_named(game.zone_root,"BridgePlank") >= 9, "%s bridge planks are incomplete" % zone_id)
	check(_count_named(game.zone_root,"BridgeApproachRamp") == 2, "%s bridge approach visuals are incomplete" % zone_id)
	check(_count_named(game.zone_root,"BridgeApproachRampNorthCollision") == 0 and _count_named(game.zone_root,"BridgeApproachRampSouthCollision") == 0, "%s bridge approach still has a lip collider" % zone_id)
	check(_bridge_floor_is_walkable(game,center_z), "%s bridge approach requires a jump" % zone_id)
	check(_all_interactions_clear(game.zone_root,center_z), "%s contains an interaction in the river exclusion band" % zone_id)
	check(_all_enemies_clear(game.active_enemies,center_z), "%s contains an enemy in the river exclusion band" % zone_id)
	if zone_id == "greyfen":
		check(_all_npc_paths_clear(game.zone_root,center_z), "Greyfen contains an NPC schedule through the river")
	check(_bridge_corridor_clear(game), "%s bridge centre is obstructed" % zone_id)
	check(_bank_barrier_blocks(game,center_z,-1.0), "%s north bank barrier is open" % zone_id)
	check(_bank_barrier_blocks(game,center_z,1.0), "%s south bank barrier is open" % zone_id)
	_verify_recovery(game,center_z,Vector3(8.0,-0.15,center_z),-1.0)
	_verify_recovery(game,center_z,Vector3(-8.0,-1.6,center_z+0.4),1.0)
	_verify_recovery(game,center_z,Vector3(0.0,-1.0,center_z),-1.0)
	var valid_bridge_save := game.call("_safe_loaded_position",zone_id,Vector3(0.0,0.55,center_z)) as Vector3
	check(is_equal_approx(valid_bridge_save.z,center_z), "%s bridge save was incorrectly migrated" % zone_id)
	var invalid_water_save := game.call("_safe_loaded_position",zone_id,Vector3(8.0,-0.5,center_z)) as Vector3
	check(absf(invalid_water_save.z-center_z) > 2.5, "%s water save was not migrated" % zone_id)

func _verify_physical_bridge_crossings(game, center_z: float) -> void:
	var player = game.player
	check(player is CharacterBody3D, "%s bridge test has no CharacterBody3D" % str(game.current_zone_id))
	if not player is CharacterBody3D:
		return
	# Drive the actual player controller across the authored deck. This catches
	# the failure mode that ray-height checks miss: capsule lips, recovery
	# volumes, a deck that is visually present but not physically continuous,
	# and a bridge that only works on its centreline. Keep both probes well
	# inside the deck rails so the test represents ordinary player movement.
	player.can_control = true
	player.set_transition_locked(false)
	_reset_camera(game)
	# Start on the authored bank and approach the bridge through the same
	# ground-to-deck seam used by normal play. The deck-only probes below cannot
	# detect a bank edge that catches the capsule before it reaches the bridge.
	player.global_position = Vector3(0.0, 0.25, center_z + 5.3)
	player.rotation.y = 0.0
	await _walk_with_input(game, "move_forward", 150, center_z, -1.0)
	check(player.global_position.z < center_z - 2.55, "%s bank-to-bridge approach stopped at z=%.2f" % [str(game.current_zone_id), player.global_position.z])
	check(not game.call("_is_river_recovery_position", str(game.current_zone_id), player.global_position), "%s bank-to-bridge approach triggered river recovery" % str(game.current_zone_id))
	for lane_x in [-1.2, 1.2]:
		player.global_position = Vector3(lane_x, 0.25, center_z + 3.45)
		player.rotation.y = 0.0
		_reset_camera(game)
		await _walk_with_input(game, "move_forward", 90, center_z, -1.0)
		check(absf(player.global_position.x - lane_x) < BRIDGE_LANE_DRIFT_TOLERANCE, "%s bridge crossing drifted sideways from lane x=%.2f (actual x=%.2f z=%.2f y=%.2f velocity=%s)" % [str(game.current_zone_id), lane_x, player.global_position.x, player.global_position.z, player.global_position.y, player.velocity])
		check(absf(player.global_position.x) < BridgeSurfaceContract.HALF_WIDTH - 0.32, "%s bridge crossing left the rail-safe corridor (actual x=%.2f width=%.2f)" % [str(game.current_zone_id), player.global_position.x, BridgeSurfaceContract.DECK_WIDTH])
		check(player.global_position.z < center_z - 2.55, "%s south-to-north bridge crossing stopped at lane x=%.2f z=%.2f" % [str(game.current_zone_id), lane_x, player.global_position.z])
		check(not game.call("_is_river_recovery_position", str(game.current_zone_id), player.global_position), "%s crossing ended in river recovery state at lane x=%.2f" % [str(game.current_zone_id), lane_x])

		player.global_position = Vector3(lane_x, 0.25, center_z - 3.45)
		player.rotation.y = PI
		_reset_camera(game)
		# Player movement follows the active camera, not the actor yaw. From the
		# north bank the real return input is reverse, so this leg exercises the
		# same player-facing control path without accidentally walking away from
		# the bridge.
		await _walk_with_input(game, "move_back", 92, center_z, 1.0)
		check(absf(player.global_position.x - lane_x) < BRIDGE_LANE_DRIFT_TOLERANCE, "%s return crossing drifted sideways from lane x=%.2f (actual x=%.2f z=%.2f y=%.2f contacts=%s)" % [str(game.current_zone_id), lane_x, player.global_position.x, player.global_position.z, player.global_position.y, _slide_collision_names(player)])
		check(absf(player.global_position.x) < BridgeSurfaceContract.HALF_WIDTH - 0.32, "%s return crossing left the rail-safe corridor (actual x=%.2f width=%.2f)" % [str(game.current_zone_id), player.global_position.x, BridgeSurfaceContract.DECK_WIDTH])
		check(player.global_position.z > center_z + 2.55, "%s north-to-south bridge crossing stopped at lane x=%.2f z=%.2f contacts=%s" % [str(game.current_zone_id), lane_x, player.global_position.z, _slide_collision_names(player)])
		check(not game.call("_is_river_recovery_position", str(game.current_zone_id), player.global_position), "%s return crossing ended in river recovery state at lane x=%.2f" % [str(game.current_zone_id), lane_x])

func _reset_camera(game: Node) -> void:
	var camera_rig = game.get("camera_rig")
	if camera_rig != null and is_instance_valid(camera_rig):
		camera_rig.set("yaw", 0.0)

func _slide_collision_names(body: CharacterBody3D) -> String:
	var names: Array[String] = []
	for index in range(body.get_slide_collision_count()):
		var collision := body.get_slide_collision(index)
		var collider = collision.get_collider()
		if collider is Node:
			names.append(str((collider as Node).name))
	return ",".join(names)

func _walk_with_input(game, action: String, frame_count: int, center_z: float, direction: float) -> void:
	var player = game.player
	var previous_z: float = player.global_position.z
	Input.action_press(action)
	for _frame in range(frame_count):
		await physics_frame
		var current_z: float = player.global_position.z
		check(absf(current_z - previous_z) < 1.5, "%s bridge movement teleported during physical crossing" % str(game.current_zone_id))
		if absf(current_z - center_z) < 2.25:
			check(not game.call("_is_river_recovery_position", str(game.current_zone_id), player.global_position), "%s physical crossing triggered river recovery" % str(game.current_zone_id))
		previous_z = current_z
	Input.action_release(action)
	await physics_frame

func _verify_recovery(game, center_z: float, forced_position: Vector3, expected_side: float) -> void:
	game.player.global_position = forced_position
	game.player.velocity = Vector3(2,-4,1)
	game.call("_keep_player_in_world")
	var recovered: Vector3 = game.player.global_position
	check(absf(recovered.z-center_z) > 2.5, "River recovery left Kael inside the channel")
	check(game.player.velocity.length() < 0.01, "River recovery did not clear velocity")
	check(signf(recovered.z-center_z) == expected_side, "River recovery placed Kael on the wrong bank")
	check(recovered.y >= 0.8, "River recovery left Kael below ground")

func _all_interactions_clear(root_node: Node, center_z: float) -> bool:
	for node in _walk(root_node):
		if node.has_method("get_context_prompt") and node is Node3D:
			if absf((node as Node3D).global_position.z-center_z) < 2.75:
				push_error("River interaction conflict: %s at %s" % [node.name,(node as Node3D).global_position])
				return false
	return true

func _all_enemies_clear(enemies: Array, center_z: float) -> bool:
	for enemy in enemies:
		if is_instance_valid(enemy) and absf(enemy.global_position.z-center_z) < 2.9:
			return false
	return true

func _all_npc_paths_clear(root_node: Node, center_z: float) -> bool:
	var life = root_node.find_child("GreyfenLifeController",true,false)
	if life == null:
		return false
	for entry in life.actors:
		for waypoint in entry.path:
			var point := waypoint as Vector3
			if absf(point.z-center_z) < 2.75 and absf(point.x) > 2.7:
				return false
		for index in range(1,entry.path.size()):
			var previous := entry.path[index-1] as Vector3
			var current := entry.path[index] as Vector3
			if (previous.z-center_z)*(current.z-center_z) < 0.0 and (absf(previous.x) > 2.7 or absf(current.x) > 2.7):
				return false
	return true

func _bridge_corridor_clear(game) -> bool:
	var center_z := float(game.call("_river_center"))
	var query := PhysicsRayQueryParameters3D.create(Vector3(0,1.0,center_z-3.0),Vector3(0,1.0,center_z+3.0))
	query.collide_with_areas = false
	query.exclude = [game.player.get_rid()]
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

func _bridge_floor_is_walkable(game, center_z: float) -> bool:
	var previous_height := -999.0
	for step in range(19):
		var z := center_z - 4.5 + float(step) * 0.5
		var query := PhysicsRayQueryParameters3D.create(Vector3(0,2.0,z),Vector3(0,-1.0,z))
		query.collide_with_areas = false
		query.exclude = [game.player.get_rid()]
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return false
		var height := float((hit.position as Vector3).y)
		if previous_height > -900.0 and absf(height-previous_height) > 0.18:
			return false
		previous_height = height
	return true

func _bank_barrier_blocks(game, center_z: float, side: float) -> bool:
	var target_z := center_z + side * 1.88
	for node in _walk(game.zone_root):
		if node is StaticBody3D and str(node.name).begins_with("RiverBankBarrier"):
			var body := node as StaticBody3D
			if absf(body.position.z-target_z) < 0.25:
				return true
	return false

func _walk(parent: Node) -> Array:
	var found: Array = [parent]
	for child in parent.get_children():
		found.append_array(_walk(child))
	return found

func _has_named(parent: Node, target: String) -> bool:
	return parent.find_child(target,true,false) != null

func _count_named(parent: Node, target: String) -> int:
	var count := 1 if str(parent.name).begins_with(target) else 0
	for child in parent.get_children():
		count += _count_named(child,target)
	return count

func _settle(frames: int) -> void:
	for _i in range(frames):
		await process_frame

func _shutdown_game(game: Node) -> void:
	# Release active and cached zone ownership before SceneTree teardown. A
	# direct quit leaves hidden collision/render resources alive long enough for
	# Compatibility to report them as leaks, which obscures real runtime errors.
	if game != null and game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _settle(int(game.ZONE_RETIRE_FRAMES) + 4)
	if game != null and game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
	# PhysicsServer3D releases CharacterBody shapes on a physics flush, while
	# the scene tree releases queued nodes on a process flush. Give both servers
	# a frame before the verifier exits so teardown diagnostics stay meaningful.
	await physics_frame
	await _settle(3)
	if game != null and is_instance_valid(game):
		game.queue_free()
	await physics_frame
	await _settle(8)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
