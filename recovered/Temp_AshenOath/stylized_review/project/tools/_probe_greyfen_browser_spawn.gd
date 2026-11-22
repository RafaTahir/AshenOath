extends SceneTree

## Native reproduction for the v67 browser stop at the exact Greyfen spawn.
## This uses the real CharacterBody3D, InputRouter key-event path, and live
## physics tree. It is ignored diagnostic evidence, not a release test.

var failures: Array[String] = []
var game: Node
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_assert(packed != null, "main scene did not load")
	if packed == null:
		_finish()
		return
	game = packed.instantiate()
	root.add_child(game)
	await _frames(3)
	_assert(game.has_method("_new_game"), "main scene has no _new_game")
	if not game.has_method("_new_game"):
		_finish()
		return
	game.call("_new_game")
	await _wait_for_player("greyfen", 1200)
	if player == null:
		_finish()
		return

	var camera := game.get("camera_rig") as Node
	if camera != null:
		camera.set("yaw", 0.0)
		camera.set("pitch", 0.30)
	var router := game.get("input_router") as Node
	if router != null and router.has_method("set_gameplay_context"):
		router.set_gameplay_context()
	player.global_position = Vector3(0.0, 0.03272, 9.8)
	player.velocity = Vector3.ZERO
	await _physics_frames(4)
	var start := player.global_position
	print("PROBE exact_spawn_start=%s floor=%s wall=%s velocity=%s" % [
		start, str(player.is_on_floor()), str(player.is_on_wall()), player.velocity
	])
	_parse_key_event(KEY_W, true)
	for index in range(240):
		await physics_frame
		if index % 10 == 0:
			print("PROBE exact_spawn_step=%d position=%s delta=%s floor=%s wall=%s velocity=%s" % [
				index, player.global_position, player.global_position - start,
				str(player.is_on_floor()), str(player.is_on_wall()), player.velocity
			])
	_parse_key_event(KEY_W, false)
	await _physics_frames(4)
	var finish := player.global_position
	print("PROBE exact_spawn_end=%s delta=%s floor=%s wall=%s velocity=%s" % [
		finish, finish - start, str(player.is_on_floor()), str(player.is_on_wall()), player.velocity
	])
	_test_move("exact_spawn_forward", Vector3(0.0, 0.0, -0.50))
	_print_capsule_owners("exact_spawn_end", finish)
	_assert(finish.z < 4.5, "native exact-spawn movement stopped at z=%.3f" % finish.z)
	if failures.is_empty():
		print("GREYFEN EXACT SPAWN PROBE: PASS")
	else:
		print("GREYFEN EXACT SPAWN PROBE: FAIL")
		for failure in failures:
			print("- %s" % failure)
	_finish()

func _wait_for_player(zone: String, max_frames: int) -> void:
	for _index in range(max_frames):
		await process_frame
		var candidate := game.get("player") as CharacterBody3D
		if candidate != null and str(game.get("current_zone_id")) == zone:
			player = candidate
			if not bool(player.get("transition_locked")) and bool(player.get("can_control")):
				return
	_assert(false, "timed out waiting for playable %s" % zone)

func _test_move(label: String, motion: Vector3) -> void:
	var collision := KinematicCollision3D.new()
	var blocked := player.test_move(player.global_transform, motion, collision, 0.0, true)
	print("PROBE test_move %s blocked=%s collider=%s normal=%s travel=%s remainder=%s" % [
		label, str(blocked),
		str(collision.get_collider().get_path()) if blocked and collision.get_collider() is Node else "",
		collision.get_normal(), collision.get_travel(), collision.get_remainder()
	])

func _print_capsule_owners(label: String, position: Vector3) -> void:
	var shape_node: CollisionShape3D
	for child in player.get_children():
		if child is CollisionShape3D:
			shape_node = child as CollisionShape3D
			break
	if shape_node == null or shape_node.shape == null:
		_assert(false, "player collision shape missing for %s" % label)
		return
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.transform = Transform3D(Basis.IDENTITY, position) * shape_node.transform
	query.collision_mask = player.collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	var owners: Array[String] = []
	for hit in game.get_world_3d().direct_space_state.intersect_shape(query, 64):
		var collider := hit.get("collider") as Node
		if collider != null:
			owners.append(str(collider.get_path()))
	print("PROBE exact_spawn_owners label=%s count=%d owners=%s" % [label, owners.size(), ";".join(owners)])

func _parse_key_event(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.unicode = keycode
	event.pressed = pressed
	event.echo = false
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _physics_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("PROBE ASSERT: %s" % message)

func _finish() -> void:
	Input.action_release("move_forward")
	Input.action_release("move_back")
	if is_instance_valid(game):
		if game.has_method("finalize_resource_shutdown"):
			game.call("finalize_resource_shutdown")
		await _frames(8)
		if game.is_inside_tree():
			root.remove_child(game)
		if is_instance_valid(game):
			game.free()
	await _frames(2)
	quit(1 if not failures.is_empty() else 0)
