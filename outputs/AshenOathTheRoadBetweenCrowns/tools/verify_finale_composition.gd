extends SceneTree

const Game = preload("res://scripts/game.gd")
const Spatial = preload("res://scripts/zone_spatial_service.gd")
const Materials = preload("res://scripts/world_material_library.gd")
const Settings = preload("res://scripts/settings_manager.gd")
const Finale = preload("res://scripts/zones/campaign_finale_section.gd")
const Helper = preload("res://scripts/asset_spawn_helper.gd")
const Woodland = preload("res://scripts/hart_woodland.gd")
const COURT := "res://assets_external/environment/village/AssemblyCourt_Authored.res"
const LANDSCAPE := "res://assets_external/environment/forest/HartLandscape_Authored.res"
const STONES := "res://assets_external/environment/forest/HartWitnessStones_Authored.res"
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_cmdline_user_args().has("--hart-woodland-only"):
		await _check_hart_woodland()
		return
	if OS.get_cmdline_user_args().has("--hart-aftermath-only"):
		await _check_hart_aftermath()
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://runtime_asset_manifest.json"))
	var filters := ConfigFile.new()
	check(filters.load("res://export_presets.cfg") == OK, "Export presets cannot be parsed")
	var campaign_filter := ""
	for section in filters.get_sections():
		if filters.get_value(section, "name", "") == "Runtime Pack Campaign":
			campaign_filter = filters.get_value(section, "include_filter", "")
	for item in [[COURT, 2, 500000], [LANDSCAPE, 2, 10000], [STONES, 1, 10000]]:
		var registration: Dictionary = {}
		for entry in manifest.get("authored_environment_derivatives", []):
			if entry.get("path", "") == item[0]:
				registration = entry
		check(registration.get("sha256", "") == FileAccess.get_sha256(item[0]), "Finale manifest hash drift: " + item[0])
		check(int(registration.get("bytes", 0)) == FileAccess.get_file_as_bytes(item[0]).size(), "Finale manifest byte drift")
		check(campaign_filter.contains(item[0].trim_prefix("res://")), "Campaign export omits finale geometry")
		var mesh := load(item[0]) as ArrayMesh
		check(mesh != null, "Missing finale geometry: " + item[0])
		if mesh == null:
			continue
		check(mesh.get_surface_count() == item[1], "Finale surface budget drift")
		check(FileAccess.get_file_as_bytes(item[0]).size() < item[2], "Finale byte budget exceeded")
		for surface in mesh.get_surface_count():
			check(mesh.surface_get_material(surface) != null, "Finale null material")
			var arrays := mesh.surface_get_arrays(surface)
			for point in arrays[Mesh.ARRAY_VERTEX]:
				check(point.is_finite(), "Nonfinite finale vertex")
			for normal in arrays[Mesh.ARRAY_NORMAL]:
				check(normal.is_finite() and normal.length_squared() > 0.8, "Invalid finale normal")
	var court := load(COURT) as ArrayMesh
	check(int(court.get_meta("house_count", 0)) == 4 and int(court.get_meta("bench_count", 0)) == 4 and int(court.get_meta("table_count", 0)) == 3 and int(court.get_meta("brazier_count", 0)) == 1, "Assembly content removed")
	for path in court.get_meta("source_sha256", {}):
		check(court.get_meta("source_sha256")[path] == FileAccess.get_sha256(path), "Assembly source hash drift: " + path)
	var game := Game.new()
	game.add_child(game.zone_residency)
	game.current_zone_id = "assembly"
	game.shared_box_mesh = BoxMesh.new()
	game.settings = Settings.new()
	game.add_child(game.settings)
	game.world_materials = Materials.new()
	game.add_child(game.world_materials)
	game.spatial_service = Spatial.new()
	game.spatial_service.configure("assembly", 999.0, Vector2(21, 17))
	game.add_child(game.spatial_service)
	game.zone_root = Node3D.new()
	root.add_child(game.zone_root)
	var builder := Finale.new()
	var context := ZoneBuildContext.new(game, "assembly")
	builder._make_assembly_court(context)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(42, 0.16, 34)
	floor_shape.shape = box
	floor_shape.position.y = -0.08
	floor_body.add_child(floor_shape)
	game.zone_root.add_child(floor_body)
	var player := CharacterBody3D.new()
	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.76
	capsule.shape = shape
	capsule.position.y = 0.905
	player.add_child(capsule)
	root.add_child(player)
	await physics_frame
	await physics_frame
	# Actual publication geometry leaves the established eastern testimony lane.
	for x in [5.9, 6.3, 6.45]:
		await sweep(player, Vector3(x, 0, 6), Vector3(x, 0, -14), "assembly east aisle")
	await sweep(player, Vector3(6.3, 0, -11), Vector3(0, 0, -11), "address-book approach")
	await sweep(player, Vector3(-7, 0, 8), Vector3(-7, 0, 15), "assembly return")
	var space := player.get_world_3d().direct_space_state
	for position in [Vector3(0, 2, -6.5), Vector3(0, 2, -9), Vector3(8, 2, -3.5)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(position, position - Vector3.UP * 2, 1, [player.get_rid()]))
		check(not hit.is_empty() and absf(hit.position.y - 1.0) < 0.002, "Reading table lacks matching physical top")
	var dialogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_dialogue.json"))
	var helper := Helper.new()
	game.add_child(helper)
	game.asset_helper = helper
	for id in ["witness_-7", "witness_-3", "witness_3"]:
		var role: String = game._role_for_interactable(id)
		check(not role.is_empty(), "Witness has no real character role: " + id)
		check(FileAccess.get_file_as_string("res://data/campaign_dialogue.json").contains('"' + id + '"'), "Witness has no dialogue: " + id)
		var visual: Node3D = game._make_role_visual(role, "characters", Vector3.ONE)
		check(visual != null, "Witness character does not resolve: " + id)
		if visual != null:
			check(not visual.find_children("*", "Skeleton3D", true, false).is_empty(), "Witness is not a skeletal body: " + id)
			game.zone_root.add_child(visual)
			for mesh in visual.find_children("*", "MeshInstance3D", true, false):
				check(not mesh.mesh is CapsuleMesh, "Witness still has capsule anatomy")
	check(not dialogue.is_empty(), "Campaign dialogue cannot be parsed")
	builder._make_hart_landscape(context)
	var landscape := game.zone_root.get_node("HartAuthoredLandscape") as MeshInstance3D
	check(landscape.get_surface_override_material(0) != null and landscape.get_surface_override_material(1) != null, "Hart runtime material missing")
	player.free()
	game.zone_residency._bind_retirement_material(game.zone_root)
	await process_frame
	game.zone_residency._release_zone_render_resources(game.zone_root)
	await process_frame
	game.zone_root.free()
	helper.clear_runtime_caches()
	game.free()
	await process_frame
	RenderingServer.force_sync()
	print("FINALE COMPOSITION CONTRACT: %s (resource, witness mapping and physical assembly lanes; not visual/campaign acceptance)" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _check_hart_woodland() -> void:
	if DisplayServer.get_name() == "headless":
		check(false, "Hart woodland instance readback requires the graphical renderer, not headless identity transforms")
		quit(1)
		return
	var game := Game.new()
	game.add_child(game.zone_residency)
	game.settings = Settings.new()
	game.add_child(game.settings)
	game.asset_helper = Helper.new()
	game.add_child(game.asset_helper)
	game.zone_root = Node3D.new()
	root.add_child(game.zone_root)
	var context := ZoneBuildContext.new(game, "hart_glade")
	Woodland.build(context)
	await process_frame
	RenderingServer.force_sync()
	var layer := game.zone_root.get_node_or_null("HartAuthoredWoodland")
	check(layer != null, "Fitted Hart woodland is missing")
	if layer != null:
		check(layer.find_children("*", "CollisionObject3D", true, false).is_empty(), "Woodland modifies encounter collision")
		var ground := layer.get_node("HartAdjoiningWoodlandGround") as MeshInstance3D
		check(ground.mesh.get_surface_count() == 2 and ground.mesh.get_faces().size() / 3 <= 2500, "Woodland geometry exceeds its bounded footprint")
		check(FileAccess.get_file_as_bytes(Woodland.MESH_PATH).size() < 60000, "Woodland byte budget exceeded")
		for surface in range(2):
			var material := ground.get_active_material(surface) as StandardMaterial3D
			check(material != null and (surface != 0 or material.albedo_texture != null), "Woodland material/ground texture is missing")
			var arrays := ground.mesh.surface_get_arrays(surface)
			for normal in arrays[Mesh.ARRAY_NORMAL]:
				check(normal.is_finite() and normal.length_squared() > 0.8 and (surface != 0 or normal.y > 0.5), "Woodland normal or front-face winding is invalid")
			for point in arrays[Mesh.ARRAY_VERTEX]:
				check(point.is_finite(), "Nonfinite woodland vertex")
				check(surface != 0 or absf(point.x) >= 22.49 or absf(point.z) >= 19.49, "Adjoining ground changes the physical core")
				check(surface != 1 or absf(point.x) > 10.0, "Understory obstructs the central encounter/return sightline")
		for source in ground.mesh.get_meta("source_sha256", {}):
			check(ground.mesh.get_meta("source_sha256")[source] == FileAccess.get_sha256(source), "Hart understory source identity drift")
		var trees := layer.get_node("HartWoodlandTreeBatch") as MultiMeshInstance3D
		check(trees.multimesh.instance_count == 32, "Balanced woodland stand is incomplete")
		for index in trees.multimesh.instance_count:
			var transform := trees.multimesh.get_instance_transform(index)
			var bounds: AABB = transform * trees.multimesh.mesh.get_aabb()
			var position: Vector3 = Woodland.tree_positions()[index]
			check(absf(bounds.position.y - position.y) < 0.001, "Woodland tree %d root=%f ground=%f transform=%s source=%s" % [index, bounds.position.y, position.y, transform, trees.multimesh.mesh.get_aabb()])
			check(absf(position.y - Woodland.height_at(position.x, position.z)) < 0.001 and (absf(position.x) > 22.5 or absf(position.z) > 19.5), "Woodland tree is not outside/grounded on its owner")
	for x in [-22.5, -12.0, 0.0, 12.0, 22.5]:
		for z in [-19.5, -8.0, 6.0, 19.5]:
			check(absf(Woodland.height_at(x, z) - 0.0265) < 0.001, "Woodland leaves a floor join gap")
	game.zone_residency._bind_retirement_material(game.zone_root)
	await process_frame
	game.zone_residency._release_zone_render_resources(game.zone_root)
	await process_frame
	game.zone_root.free()
	game.asset_helper.clear_runtime_caches()
	game.free()
	await process_frame
	RenderingServer.force_sync()
	print("HART WOODLAND CONTRACT: %s (ground/material/stand/clearance/retirement; NOT visual or FPS acceptance)" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _check_hart_aftermath() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://runtime_asset_manifest.json"))
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK, "Export configuration invalid")
	var filter := ""
	for section in presets.get_sections():
		if presets.get_value(section, "name", "") == "Runtime Pack Campaign":
			filter = presets.get_value(section, "include_filter", "")
	for covenant in ["witness", "mercy", "duty", "ash"]:
		var path := "res://assets_external/environment/forest/HartAftermath_%s_Authored.res" % covenant
		var mesh := load(path) as ArrayMesh
		check(mesh != null and mesh.get_surface_count() == 2, "Missing two-surface aftermath: " + covenant)
		if mesh == null:
			continue
		check(FileAccess.get_file_as_bytes(path).size() < 20000, "Aftermath byte budget exceeded")
		check(mesh.get_meta("covenant", "") == covenant, "Wrong covenant geometry")
		check(filter.contains(path.trim_prefix("res://")), "Campaign omits aftermath")
		var registered := false
		for entry in manifest.get("authored_environment_derivatives", []):
			if entry.get("path", "") == path:
				registered = entry.get("sha256", "") == FileAccess.get_sha256(path) and int(entry.get("bytes", 0)) == FileAccess.get_file_as_bytes(path).size()
		check(registered, "Aftermath manifest drift")
		for surface in mesh.get_surface_count():
			check(mesh.surface_get_material(surface) != null, "Null aftermath surface")
			for vertex in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				check(vertex.is_finite(), "Nonfinite aftermath vertex")
		var game := Game.new()
		game.current_zone_id = "hart_glade"
		game.add_child(game.zone_residency)
		game.settings = Settings.new()
		game.add_child(game.settings)
		game.world_materials = Materials.new()
		game.add_child(game.world_materials)
		game.zone_root = Node3D.new()
		root.add_child(game.zone_root)
		var context := ZoneBuildContext.new(game, "hart_glade")
		Finale.new()._make_hart_aftermath(context, covenant)
		var seal := game.zone_root.get_node("HartAftermathSeal") as MeshInstance3D
		check(seal.mesh == mesh and seal.get_surface_override_material(0) != null and seal.get_surface_override_material(1) != null, "Runtime aftermath is incomplete")
		check(game.zone_root.get_node("HartCovenantInscription").text != "", "Missing covenant inscription")
		var obstacles: Array = mesh.get_meta("obstacles", [])
		check(obstacles.size() == 5 and game.prop_collision_body.get_child_count() == 5, "Memorial collision count drift")
		for index in obstacles.size():
			var collision := game.prop_collision_body.get_child(index) as CollisionShape3D
			check(collision.position.is_equal_approx(obstacles[index].centre) and collision.shape.size.is_equal_approx(obstacles[index].size), "Memorial stone collision does not match geometry")
		var player := CharacterBody3D.new()
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.32
		capsule.height = 1.76
		collision.shape = capsule
		collision.position.y = 0.905
		player.add_child(collision)
		root.add_child(player)
		await physics_frame
		await physics_frame
		await sweep(player, Vector3(0, 0, 12), Vector3(0, 0, -9), covenant + " approach")
		await sweep(player, Vector3(0, 0, -9), Vector3(-7, 0, -9), covenant + " return turn")
		await sweep(player, Vector3(-7, 0, -9), Vector3(-7, 0, 16), covenant + " return lane")
		player.free()
		game.zone_residency._bind_retirement_material(game.zone_root)
		await process_frame
		game.zone_residency._release_zone_render_resources(game.zone_root)
		await process_frame
		game.zone_root.free()
		game.free()
		await process_frame
	RenderingServer.force_sync()
	print("HART AFTERMATH CONTRACT: %s (four resource/material/collision/physical capsule states; NOT earned endings, visual or performance acceptance)" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func sweep(player: CharacterBody3D, start: Vector3, finish: Vector3, label: String) -> void:
	for reverse in [false, true]:
		player.position = finish if reverse else start
		var motion := (start - finish if reverse else finish - start) / 160
		for step in range(160):
			await physics_frame
			var contact := player.move_and_collide(motion)
			if contact != null:
				check(false, "%s blocked at %s by %s" % [label, player.position, contact.get_collider()])
				break

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
