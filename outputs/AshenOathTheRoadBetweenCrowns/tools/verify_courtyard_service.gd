extends "res://tools/verify_campaign_records.gd"

func _run() -> void:
	var game := Game.new()
	game.add_child(game.zone_residency)
	game.current_zone_id = "vargan_court"
	game.shared_box_mesh = BoxMesh.new()
	game.settings = preload("res://scripts/settings_manager.gd").new()
	game.add_child(game.settings)
	game.world_materials = preload("res://scripts/world_material_library.gd").new()
	game.add_child(game.world_materials)
	game.zone_root = Node3D.new()
	root.add_child(game.zone_root)
	game.spatial_service = Spatial.new()
	game.zone_root.add_child(game.spatial_service)
	game.spatial_service.configure("vargan_court", 999, Vector2(23, 19))
	game._make_collision_box("Floor", Vector3(0, -0.08, 0), Vector3(46, 0.16, 38))
	var context := ZoneBuildContext.new(game, "vargan_court")
	preload("res://scripts/zones/castle_vargan_section.gd").new()._make_courtyard_dressing(context)
	var service := game.zone_root.get_node_or_null("CourtyardAuthoredServiceGroundAndSupplies") as MeshInstance3D
	_check(service != null, "Missing authored service court")
	if service != null:
		var mesh := service.mesh
		_check(mesh.get_surface_count() == 2 and mesh.get_faces().size() / 3 < 12000, "Service court geometry budget")
		_check(FileAccess.get_file_as_bytes(mesh.resource_path).size() < 220000, "Service court byte budget")
		_check(service.find_children("*", "CollisionObject3D", true, false).is_empty(), "Service dressing added new colliders")
		for surface in mesh.get_surface_count():
			_check(service.get_active_material(surface) != null, "Service court null material")
		for bounds in mesh.get_meta("prop_bounds", []):
			_check(bounds.end.x < -4.2 or bounds.position.x > 4.2, "Service supplies obscure the primary road")
		for source in mesh.get_meta("source_sha256", {}):
			_check(mesh.get_meta("source_sha256")[source] == FileAccess.get_sha256(source), "Service prop source drift")
	var shapes := game.zone_root.find_children("*", "CollisionShape3D", true, false)
	for x in [11.7, 14.3]:
		var found := false
		for shape in shapes:
			if shape.global_position.is_equal_approx(Vector3(x, 0.55, 1)):
				found = shape.shape.size.is_equal_approx(Vector3(0.78, 1.1, 0.78))
		_check(found, "Forge barrel reservation/physical bounds changed")
	await physics_frame
	await physics_frame
	var player := CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = CapsuleShape3D.new()
	collision.shape.radius = 0.32
	collision.shape.height = 1.76
	collision.position.y = 0.905
	player.add_child(collision)
	root.add_child(player)
	await physics_frame
	for x in [-1.2, 0.0, 1.2]:
		for direction in [-1.0, 1.0]:
			player.position = Vector3(x, 0, -direction * 12)
			_check(player.move_and_collide(Vector3(0, 0, direction * 24)) == null, "Service pass snags primary bidirectional route")
	player.free()
	game.zone_residency._bind_retirement_material(game.zone_root)
	await process_frame
	game.zone_residency._release_zone_render_resources(game.zone_root)
	await process_frame
	game.zone_root.free()
	game.free()
	await process_frame
	RenderingServer.force_sync()
	print("COURTYARD SERVICE CONTRACT: %s (draw/byte/material/source/collision/primary capsule; NOT visual/story/FPS acceptance)" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
