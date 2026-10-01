extends SceneTree

const Game = preload("res://scripts/game.gd")
const Spatial = preload("res://scripts/zone_spatial_service.gd")
const Materials = preload("res://scripts/world_material_library.gd")
const Settings = preload("res://scripts/settings_manager.gd")
const Wilderness = preload("res://scripts/zones/campaign_wilderness_section.gd")
const Road = preload("res://scripts/zones/bandit_road_section.gd")
const Presentation = preload("res://scripts/zones/campaign_wilds_presentation.gd")
const Frontier = preload("res://scripts/bandit_frontier.gd")
const AssetHelper = preload("res://scripts/asset_spawn_helper.gd")
const RoleSpec = preload("res://scripts/character_role_spec.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_cmdline_user_args().has("--bandit-frontier-only"):
		await _check_bandit_frontier()
		return
	create_timer(90.0).timeout.connect(func(): push_error("Campaign wilds contract timed out"); quit(1))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://runtime_asset_manifest.json"))
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK, "Export preset parse failure")
	var campaign_filter := ""
	for section in presets.get_sections():
		if presets.get_value(section, "name", "") == "Runtime Pack Campaign":
			campaign_filter = presets.get_value(section, "include_filter", "")
	for mesh in Presentation.LANDSCAPES.values() + Presentation.RUINS.values() + [Presentation.CHECKPOINT]:
		check(mesh is ArrayMesh, "Missing authored wilds resource")
		check(FileAccess.get_file_as_bytes(mesh.resource_path).size() < 60000, "Wilds mesh byte budget exceeded")
		var registered := false
		for entry in manifest.get("authored_environment_derivatives", []):
			if entry.get("path", "") == mesh.resource_path:
				registered = true
				check(entry.get("sha256", "") == FileAccess.get_sha256(mesh.resource_path), "Wilds manifest hash drift")
				check(int(entry.get("bytes", 0)) == FileAccess.get_file_as_bytes(mesh.resource_path).size(), "Wilds manifest byte drift")
		check(registered, "Unregistered authored wilds mesh: " + mesh.resource_path)
		check(campaign_filter.contains(mesh.resource_path.trim_prefix("res://")), "Campaign export omits authored wilds mesh")
		for surface in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			check(mesh.surface_get_material(surface) != null, "Null wilds material")
			check(not arrays[Mesh.ARRAY_INDEX].is_empty(), "Unindexed wilds surface")
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				check(vertex.is_finite(), "Nonfinite wilds vertex")
			for normal in arrays[Mesh.ARRAY_NORMAL]:
				check(normal.is_finite() and normal.length_squared() > 0.8, "Invalid wilds normal")
		for path in mesh.get_meta("source_sha256", {}):
			check(mesh.get_meta("source_sha256")[path] == FileAccess.get_sha256(path), "Wilds source hash drift: " + path)
	var marsh: ArrayMesh = Presentation.LANDSCAPES.marsh_crossing
	var bandit_landscape: ArrayMesh = Presentation.LANDSCAPES.bandit_road
	for surface in bandit_landscape.get_surface_count():
		var surface_id := bandit_landscape.surface_get_name(surface)
		check(Materials.SURFACES.has(surface_id), "Undeclared Bandit Road surface: " + surface_id)
		var vertices: PackedVector3Array = bandit_landscape.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		if surface_id == "wet_mud":
			for exit in [Vector3(-7, 0, 16.5), Vector3(7, 0, -16.5)]:
				var covered := false
				for vertex in vertices:
					if absf(vertex.z - exit.z) < 1.0 and absf(vertex.x - exit.x) < 1.0:
						covered = true
				check(covered, "Authored road does not join its actual sector exit: " + str(exit))
	for surface in marsh.get_surface_count():
		if marsh.surface_get_name(surface) != "timber":
			continue
		var arrays := marsh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for index in range(0, indices.size(), 3):
			var a := indices[index]
			var b := indices[index + 1]
			var c := indices[index + 2]
			if absf(vertices[a].y - vertices[b].y) < 0.001 and absf(vertices[a].y - vertices[c].y) < 0.001:
				check(absf((uvs[b] - uvs[a]).cross(uvs[c] - uvs[a])) > 0.001, "Collapsed timber top UV")
	for zone in ["deep_wood", "burned_farmstead", "marsh_crossing", "bandit_road"]:
		var game := Game.new()
		game.add_child(game.zone_residency)
		game.current_zone_id = zone
		game.shared_box_mesh = BoxMesh.new()
		game.settings = Settings.new()
		game.add_child(game.settings)
		game.asset_helper = AssetHelper.new()
		game.add_child(game.asset_helper)
		game.world_materials = Materials.new()
		game.add_child(game.world_materials)
		game.zone_root = Node3D.new()
		root.add_child(game.zone_root)
		game.spatial_service = Spatial.new()
		game.spatial_service.configure(zone, 999.0, Vector2(20, 16))
		game.zone_root.add_child(game.spatial_service)
		var context := ZoneBuildContext.new(game, zone)
		game._make_collision_box("ContractFloor", Vector3(0, -0.08, 0), Vector3(44, 0.16, 38))
		await physics_frame
		Presentation.landscape(context)
		if zone != "bandit_road":
			Presentation.adjoining_frontier(context)
			var frontier := game.zone_root.get_node_or_null("CampaignAuthoredFrontier") as Node3D
			check(frontier != null, "Wilds adjoining context is missing")
			if frontier != null:
				check(frontier.find_children("*", "CollisionObject3D", true, false).is_empty(), "Wilds context changes physical routes")
				var trees := frontier.get_node("BanditDistantTreeBatch") as MultiMeshInstance3D
				check(trees.multimesh.instance_count == 24, "Balanced wilds context drops intended tree stands")
				for index in trees.multimesh.instance_count:
					var center := frontier.transform * Frontier.tree_positions()[index]
					check(absf(center.x) > 20.0 or absf(center.z) > 16.0, "Wilds tree enters the physical core")
		if zone == "burned_farmstead":
			var builder := Wilderness.new()
			builder._make_burned_home(context, Vector3(-8, 0, -5), "West")
			builder._make_burned_home(context, Vector3(7, 0, 2), "East")
		elif zone == "bandit_road":
			Road.new()._make_checkpoint(context)
		await physics_frame
		await physics_frame
		var shapes := game.zone_root.find_children("*", "CollisionShape3D", true, false)
		for shape in shapes:
			if shape.name != "ContractFloorCollision":
				print("WILDS SHAPE: zone=%s id=%s position=%s size=%s" % [zone, shape.name, shape.global_position, shape.shape.size])
		if zone == "burned_farmstead":
			for position in [Vector3(-8, 1.25, -3.05), Vector3(7, 1.25, 3.95), Vector3(-10.72, 1.25, -5), Vector3(9.72, 1.25, 2)]:
				check(has_shape_at(shapes, position), "Visible ruin wall lacks matching collision: " + str(position))
		elif zone == "bandit_road":
			for position in [Vector3(-7.5, 1.4, -6), Vector3(7.5, 1.4, -6), Vector3(0, 3.1, -6), Vector3(-11.5, 0.625, -5), Vector3(11.5, 0.625, -5), Vector3(12, 1.35, -8), Vector3(9.5, 0.55, -2.3)]:
				check(has_shape_at(shapes, position), "Visible checkpoint structure lacks matching collision: " + str(position))
		var player := CharacterBody3D.new()
		var capsule := CollisionShape3D.new()
		var body_shape := CapsuleShape3D.new()
		body_shape.radius = 0.32
		body_shape.height = 1.76
		capsule.shape = body_shape
		capsule.position.y = 0.905
		player.add_child(capsule)
		root.add_child(player)
		await physics_frame
		for x in [-1.2, 0.0, 1.2]:
			await sweep(player, Vector3(x, 0, 12), Vector3(x, 0, -12), zone + " central route")
		await sweep(player, Vector3(0, 0, 12), Vector3(-7, 0, 13.5), zone + " return approach")
		await sweep(player, Vector3(0, 0, -12), Vector3(7, 0, -13.5), zone + " forward approach")
		if zone == "bandit_road":
			await sweep(player, Vector3(-7, 0, 16.5), Vector3(7, 0, -16.5), "bandit authored diagonal road")
			await sweep(player, Vector3(0, 0, 13), Vector3(21, 0, -11), "bandit sector approach")
			await sweep(player, Vector3(7, 0, -12), Vector3(7, 0, -17), "bandit north gate")
			await sweep(player, Vector3(-7, 0, 12), Vector3(-7, 0, 17), "bandit south gate")
		player.free()
		game.zone_residency._bind_retirement_material(game.zone_root)
		await process_frame
		game.zone_residency._release_zone_render_resources(game.zone_root)
		await process_frame
		game.zone_root.free()
		game.free()
		await process_frame
	RenderingServer.force_sync()
	print("CAMPAIGN WILDS CONTRACT: %s (resource and physical approach proof; not visual/story acceptance)" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _check_bandit_frontier() -> void:
	if DisplayServer.get_name() == "headless":
		check(false, "Bandit woodland instance placement requires graphical readback")
		quit(1)
		return
	var game := Game.new()
	game.add_child(game.zone_residency)
	game.settings = Settings.new()
	game.add_child(game.settings)
	game.asset_helper = AssetHelper.new()
	game.add_child(game.asset_helper)
	game.zone_root = Node3D.new()
	root.add_child(game.zone_root)
	Frontier.build(ZoneBuildContext.new(game, "bandit_road"))
	await process_frame
	RenderingServer.force_sync()
	var layer := game.zone_root.get_node_or_null("BanditAuthoredFrontier")
	check(layer != null, "Bandit adjoining landscape missing")
	if layer != null:
		check(layer.find_children("*", "CollisionObject3D", true, false).is_empty(), "Bandit scene pass modifies collision")
		var ground := layer.get_node("BanditAdjoiningGroundAndWorkLanes") as MeshInstance3D
		check(ground.mesh.get_surface_count() == 2 and ground.mesh.get_faces().size() / 3 < 2500 and FileAccess.get_file_as_bytes(Frontier.MESH_PATH).size() < 60000, "Bandit scene geometry/byte budget exceeded")
		for surface in range(2):
			var material := ground.get_active_material(surface) as StandardMaterial3D
			check(material != null and material.albedo_texture != null, "Bandit surface/texture missing")
			var arrays := ground.mesh.surface_get_arrays(surface)
			for normal in arrays[Mesh.ARRAY_NORMAL]:
				check(normal.is_finite() and normal.y > 0.5, "Bandit front-face ground normal invalid")
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				check(vertex.is_finite() and (surface != 0 or absf(vertex.x) >= 21.99 or absf(vertex.z) >= 18.99), "Bandit adjoining geometry enters the physical core")
		var trees := layer.get_node("BanditDistantTreeBatch") as MultiMeshInstance3D
		check(trees.multimesh.instance_count == 24, "Bandit woodland stand is incomplete")
		for index in trees.multimesh.instance_count:
			var bounds: AABB = trees.multimesh.get_instance_transform(index) * trees.multimesh.mesh.get_aabb()
			var position: Vector3 = Frontier.tree_positions()[index]
			check(absf(bounds.position.y - position.y) < 0.001 and (absf(position.x) > 22 or absf(position.z) > 19), "Bandit tree is floating or in the physical core")
	for x in [-22.0, -12.0, 0.0, 12.0, 22.0]:
		for z in [-19.0, -8.0, 6.0, 19.0]:
			check(absf(Frontier.height_at(x, z)) < 0.001, "Bandit adjoining ground join gap")
	for role in ["bandit_deserter", "bandit_tracker", "road_ranger_human"]:
		var actor: Node3D = game.asset_helper.spawn_enemy(role) if role.begins_with("bandit") else game.asset_helper.spawn_visual_role(role, "characters")
		check(actor != null, "Bandit focal role missing: " + role)
		if actor != null:
			game.zone_root.add_child(actor)
			var meshes := actor.find_children("*", "MeshInstance3D", true, false)
			check(not meshes.is_empty(), "Focal role has no rendered body")
			for mesh in meshes:
				if mesh.skin != null:
					check(mesh.visibility_range_end == RoleSpec.lod_distance(role) and mesh.visibility_range_end >= 32.0, "Focal body disappears inside the road camera's visible encounter")
	game.zone_residency._bind_retirement_material(game.zone_root)
	await process_frame
	game.zone_residency._release_zone_render_resources(game.zone_root)
	await process_frame
	game.zone_root.free()
	game.asset_helper.clear_runtime_caches()
	game.free()
	await process_frame
	RenderingServer.force_sync()
	print("BANDIT FRONTIER CONTRACT: %s (ground/stand/material/role distance/retirement; NOT visual or FPS acceptance)" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func sweep(player: CharacterBody3D, start: Vector3, finish: Vector3, label: String) -> void:
	for reverse in [false, true]:
		player.position = finish if reverse else start
		var motion := (start - finish if reverse else finish - start) / 120
		for step in range(120):
			# Static colliders are synchronized above. Body sweeps are synchronous;
			# idle physics frames between immutable queries provide no extra proof.
			var contact := player.move_and_collide(motion)
			if contact != null:
				check(false, "%s blocked at %s by %s" % [label, player.position, contact.get_collider()])
				break

func has_shape_at(shapes: Array, position: Vector3) -> bool:
	for shape in shapes:
		if shape.global_position.distance_to(position) < 0.002:
			return true
	return false

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
