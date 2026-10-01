extends SceneTree

const Greyfen = preload("res://scripts/zones/greyfen_section.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.current_zone_id = "greyfen"
	game.settings.set_quality_preset("balanced")
	var builder := Greyfen.new()
	var snapshots: Array = []
	for staged in [false, true]:
		game.zone_root = Node3D.new()
		game.add_child(game.zone_root)
		game.runtime_light_count = 0
		game._clear_environment_batch_buffers()
		var context := ZoneBuildContext.new(game, "greyfen")
		seed(41021)
		if staged:
			for stage in Greyfen.BOUNDARY_STAGES:
				builder.build_detail_stage(context, "boundary_" + stage)
				if stage != Greyfen.BOUNDARY_STAGES.back():
					_check(not game.zone_root.get_meta("greyfen_boundary_complete", false), "Boundary completed before all stages")
			_check(game.zone_root.get_meta("greyfen_boundary_complete", false), "Boundary never completed")
		else:
			_build_legacy(context, builder)
		var snapshot := _snapshot(game)
		snapshots.append(snapshot)
		if staged:
			builder._build_boundary_dressing(context)
			_check(snapshot == _snapshot(game), "Repeated boundary build duplicated content")
		game._clear_environment_batch_buffers()
		game.zone_root.free()
		game.zone_root = null
	_check(snapshots[0] == snapshots[1], "Staged geometry/collision/batch transforms differ from legacy")
	game.prepare_resource_shutdown()
	for frame in 20:
		await process_frame
	game.queue_free()
	for frame in 8:
		await process_frame
	print("BOUNDARY STAGES: %s - legacy geometry, collision, random tree order, completion and idempotence" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _snapshot(game: Node) -> Dictionary:
	var nodes: Array = []
	for node in game.zone_root.find_children("*", "", true, false):
		var row: Array = [node.get_class()]
		if node is Node3D:
			row.append(node.transform)
		if node is MeshInstance3D:
			row.append(node.mesh.get_aabb() if node.mesh != null else AABB())
			row.append(node.mesh.get_surface_count() if node.mesh != null else 0)
			if node.material_override is StandardMaterial3D:
				row.append(node.material_override.albedo_color)
		if node is CollisionShape3D:
			row.append(node.disabled)
			row.append(node.shape.get_class())
			if node.shape is BoxShape3D:
				row.append(node.shape.size)
			elif node.shape is CylinderShape3D:
				row.append([node.shape.radius, node.shape.height])
		if node is CollisionObject3D:
			row.append([node.collision_layer, node.collision_mask])
		nodes.append(row)
	return {"nodes": nodes, "trees": game.tree_batch_data.duplicate(true), "props": game.prop_batch_data.duplicate(true)}

func _build_legacy(context: ZoneBuildContext, builder: RefCounted) -> void:
	# Frozen pre-split call order, independent of the new staged dispatcher.
	builder._build_horizon_ridges(context)
	builder._build_horizon_forest(context)
	context.make_tree_wall(20.0, 15.2, 7, true)
	context.make_tree_wall(20.0, -15.2, 7, true)
	for tree in [
		[Vector3(-16.2, 0, -10.8), 1.10, -18.0], [Vector3(-14.8, 0, -7.2), 0.92, 21.0],
		[Vector3(15.8, 0, -10.7), 1.04, 12.0], [Vector3(16.5, 0, -6.4), 0.88, -26.0],
		[Vector3(-16.0, 0, 11.6), 1.00, 8.0], [Vector3(16.2, 0, 12.0), 0.96, -11.0],
	]:
		context.make_loose_role("forest_tree", tree[0], Vector3.ONE * float(tree[1]), float(tree[2]))
	for pos in [Vector3(-5.3, 0, 3.4), Vector3(4.8, 0, -5.3), Vector3(-9.3, 0, 11.2)]:
		context.make_torch(pos)
	for x in [-17, -13, -9, -5, 5, 9, 13, 17]:
		context.make_fence(Vector3(x, 0.35, 14), false)
		context.make_fence(Vector3(x, 0.35, -14), false)
	for z in [-10, -6, -2, 2, 6, 10]:
		context.make_fence(Vector3(-19, 0.35, z), true)
		if absf(float(z)) > 2.5:
			context.make_fence(Vector3(19, 0.35, z), true)

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
