extends SceneTree

## Native-only reproduction for the browser stop at the Greyfen bridge exit.
## This inspects the real CharacterBody and live collision tree without changing
## gameplay code or using QA route/state mutation commands.

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
	var router := game.get("input_router") as Node
	if router != null and router.has_method("set_gameplay_context"):
		router.set_gameplay_context()
	if camera != null:
		# Direction from the browser's actual spawn/stop approach toward Sister
		# Anwen at (2,-5).
		camera.set("yaw", atan2(-2.0, 5.8966305))
		camera.set("pitch", 0.30)

	var start := Vector3(0.0, 0.032743, 0.8966305)
	player.global_position = start
	player.velocity = Vector3.ZERO
	await _physics_frames(4)
	print("PROBE start position=%s floor=%s wall=%s velocity=%s" % [
		player.global_position, str(player.is_on_floor()), str(player.is_on_wall()), player.velocity
	])
	_print_capsule_owners("start", player.global_position)
	_print_horizontal_test_move("toward_anwen", player, Vector3(0.0, 0.0, -0.50))

	# Enumerate every live capsule owner at the stop point and across the exit.
	for z in [1.20, 0.90, 0.60, 0.30, 0.0, -0.30, -0.60, -1.0, -2.0, -3.0, -4.0, -5.0]:
		_print_capsule_owners("corridor_z_%.2f" % z, Vector3(0.0, 0.032743, z))

	# Exercise the actual InputEventKey path from the stop point, then record
	# each position change and any horizontal test-move owner.
	_parse_key_event(KEY_W, true)
	for index in range(180):
		await physics_frame
		if index % 10 == 0:
			var moved := player.global_position.distance_to(start)
			print("PROBE step=%d position=%s delta=%.4f floor=%s wall=%s velocity=%s" % [
				index, player.global_position, moved, str(player.is_on_floor()), str(player.is_on_wall()), player.velocity
			])
			_print_horizontal_test_move("step_%d" % index, player, Vector3(0.0, 0.0, -0.20), true)
	_parse_key_event(KEY_W, false)
	await _physics_frames(4)
	print("PROBE final position=%s delta=%s floor=%s wall=%s velocity=%s" % [
		player.global_position, player.global_position - start,
		str(player.is_on_floor()), str(player.is_on_wall()), player.velocity
	])
	_print_capsule_owners("final", player.global_position)

	if player.global_position.z >= start.z - 0.75:
		failures.append("native W movement did not clear the browser stop point")
	if failures.is_empty():
		print("GREYFEN BRIDGE EXIT PROBE: PASS")
	else:
		print("GREYFEN BRIDGE EXIT PROBE: FAIL")
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

func _print_capsule_owners(label: String, position: Vector3) -> void:
	var shape_node: CollisionShape3D
	for child in player.get_children():
		if child is CollisionShape3D:
			shape_node = child as CollisionShape3D
			break
	if shape_node == null or shape_node.shape == null:
		failures.append("player collision shape missing for %s" % label)
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
		if collider == null:
			continue
		var shapes := collider.find_children("*", "CollisionShape3D", true, false)
		var shape_info := []
		for raw_shape in shapes:
			var node := raw_shape as CollisionShape3D
			if node == null or node.shape == null:
				continue
			shape_info.append("%s:%s@%s" % [node.name, node.shape.get_class(), node.global_position])
		owners.append("%s [%s]" % [str(collider.get_path()), ";".join(shape_info)])
	print("PROBE owners %s count=%d %s" % [label, owners.size(), "; ".join(owners)])

func _print_horizontal_test_move(label: String, body: CharacterBody3D, motion: Vector3, only_if_blocked: bool = false) -> void:
	var collision := KinematicCollision3D.new()
	var blocked := body.test_move(body.global_transform, motion, collision, 0.0, true)
	if only_if_blocked and not blocked:
		return
	if not blocked:
		print("PROBE test_move %s blocked=false travel=%s remainder=%s" % [
			label, collision.get_travel(), collision.get_remainder()
		])
		return
	print("PROBE test_move %s blocked=%s collider=%s normal=%s travel=%s remainder=%s" % [
		label, str(blocked),
		str(collision.get_collider().get_path()) if collision.get_collider() is Node else "",
		collision.get_normal(), collision.get_travel(), collision.get_remainder()
	])

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
