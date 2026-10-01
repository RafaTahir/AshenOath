extends SceneTree

const Game = preload("res://scripts/game.gd")
const Spatial = preload("res://scripts/zone_spatial_service.gd")
const WorldMaterials = preload("res://scripts/world_material_library.gd")
const Settings = preload("res://scripts/settings_manager.gd")
const Castle = preload("res://scripts/zones/castle_vargan_section.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := Game.new()
	game.add_child(game.zone_residency)
	_check_authored_materials(game)
	if "--materials-only" in OS.get_cmdline_user_args():
		game.free()
		print("AUTHORED MATERIAL FALLBACK: %s" % ("PASS" if failures == 0 else "FAIL"))
		quit(0 if failures == 0 else 1)
		return
	game.current_zone_id = "vargan_approach"
	game.shared_box_mesh = BoxMesh.new()
	game.settings = Settings.new()
	game.add_child(game.settings)
	game.world_materials = WorldMaterials.new()
	game.add_child(game.world_materials)
	game.spatial_service = Spatial.new()
	game.spatial_service.configure("vargan_approach", 999.0, Vector2(23, 19))
	game.add_child(game.spatial_service)
	var scenarios := [
		["VarganGatehouseLeft", Vector3(-5.8, 3.5, -14), Vector3(5.4, 7, 3)],
		["VarganGatehouseRight", Vector3(5.8, 3.5, -14), Vector3(5.4, 7, 3)],
		["VarganGatehouseLintel", Vector3(0, 6, -14), Vector3(5.8, 2, 3)],
		["CrackedVarganTower", Vector3(-8.5, 3.75, -13.5), Vector3(5, 7.5, 5)],
		["CastleKeepCore", Vector3(0, 4.4, -19), Vector3(11, 8.8, 4)],
	]
	for scenario in scenarios:
		var snapshots: Array = []
		for render_geometry in [true, false]:
			game.zone_root = Node3D.new()
			root.add_child(game.zone_root)
			game.prop_collision_body = null
			game.prop_batch_data.clear()
			game._make_prop_box(scenario[0], scenario[1], scenario[2], Color(0.145, 0.145, 0.15), render_geometry)
			var shapes: Array = []
			for shape in game.zone_root.find_children("*", "CollisionShape3D", true, false):
				shapes.append([shape.name, shape.transform, shape.shape.size])
			snapshots.append(shapes)
			if not render_geometry:
				check(game.prop_batch_data.is_empty(), "Collision-only replacement still adds duplicate visual geometry")
			game.zone_root.free()
		check(snapshots[0] == snapshots[1], "Collision/reservation policy changed for " + scenario[0])
	var gate := load("res://assets_external/environment/village/Vargan_gatehouse_Authored.res") as ArrayMesh
	check(gate != null, "Gatehouse mesh is missing")
	if gate != null:
		game.zone_root = Node3D.new()
		root.add_child(game.zone_root)
		var context := ZoneBuildContext.new(game, "vargan_approach")
		Castle.new()._make_gatehouse(context, Vector3.ZERO)
		var body := game.zone_root.find_child("AuthoredMasonryCollision", true, false) as StaticBody3D
		check(body != null, "Visible masonry has no runtime collision owner")
		await physics_frame
		await physics_frame
		for x in [-3.6, -2.0, 0.0, 2.0, 3.6]:
			for y in [0.20, 1.0, 1.75, 2.4]:
				var query := PhysicsRayQueryParameters3D.create(Vector3(x, y, 3), Vector3(x, y, -3), 1)
				check(body.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Authored gate arch covers its walkable opening at %s" % Vector2(x, y))
		var player := CharacterBody3D.new()
		var capsule := CollisionShape3D.new()
		var player_shape := CapsuleShape3D.new()
		player_shape.radius = 0.32
		player_shape.height = 1.76
		capsule.shape = player_shape
		capsule.position.y = 0.905
		player.add_child(capsule)
		root.add_child(player)
		await physics_frame
		for x in [-10.5, -3.6, -2.0, 0.0, 2.0, 3.6, 10.5]:
			for direction in [-1.0, 1.0]:
				player.position = Vector3(x, 0, -direction * 3)
				for step in range(60):
					await physics_frame
					var contact := player.move_and_collide(Vector3(0, 0, direction * 0.1))
					check(contact == null, "Authored passage snags capsule at x=%s step=%d direction=%s" % [x, step, direction])
					if contact != null:
						break
		player.position = Vector3(7.3, 0, 3)
		check(player.move_and_collide(Vector3(0, 0, -6)) != null, "Visible wing remains a ghost wall")
		player.free()
		game.zone_residency._bind_retirement_material(game.zone_root)
		await process_frame
		game.zone_residency._release_zone_render_resources(game.zone_root)
		await process_frame
		game.zone_root.free()
		await process_frame
	game.free()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://runtime_asset_manifest.json"))
	var registration: Dictionary = {}
	for entry in manifest.get("authored_environment_derivatives", []):
		if entry.get("id", "") == "vargan_architecture":
			registration = entry
	check(not registration.is_empty(), "Architecture has no runtime manifest owner")
	check(FileAccess.file_exists(str(registration.get("license_file", ""))), "Architecture source license is missing")
	check(registration.get("assets", []).size() == 9, "Architecture registration has missing variants")
	var filters := ConfigFile.new()
	check(filters.load("res://export_presets.cfg") == OK, "Export presets cannot be parsed")
	var campaign_filter := ""
	for section in filters.get_sections():
		if filters.get_value(section, "name", "") == "Runtime Pack Campaign":
			campaign_filter = filters.get_value(section, "include_filter", "")
	for asset in registration.get("assets", []):
		var path: String = asset.get("path", "")
		check(FileAccess.get_sha256(path) == asset.get("sha256", ""), "Authored architecture hash drift: " + path)
		check(FileAccess.get_file_as_bytes(path).size() == int(asset.get("bytes", 0)), "Authored architecture byte drift: " + path)
		check(campaign_filter.contains(path.trim_prefix("res://")), "Campaign export omits architecture: " + path)
	for variant in ["gatehouse", "tower", "keep", "curtain", "stable", "cistern", "door", "forge", "record_entry"]:
		var mesh := load("res://assets_external/environment/village/Vargan_%s_Authored.res" % variant) as ArrayMesh
		check(mesh != null and mesh.get_surface_count() == 2, "Missing/broken authored variant: " + variant)
		if mesh != null:
			check(mesh.get_meta("license", "") == "CC0 1.0", "Unlicensed architecture: " + variant)
			var hashes: Dictionary = mesh.get_meta("source_sha256", {})
			for source in hashes:
				check(FileAccess.get_sha256("res://assets_external/environment/village/" + source) == hashes[source], "Architecture source drift: " + source)
			for surface in mesh.get_surface_count():
				check(mesh.surface_get_material(surface) != null, "Null architecture material: " + variant)
	await process_frame
	RenderingServer.force_sync()
	print("VARGAN ARCHITECTURE CONTRACT: %s (runtime masonry and bidirectional capsule passages; not full campaign acceptance)" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _check_authored_materials(game: Node) -> void:
	var instance := MeshInstance3D.new()
	instance.name = "VarganAuthoredGatehouse"
	instance.mesh = load("res://assets_external/environment/village/Vargan_gatehouse_Authored.res")
	game._apply_first_route_materials(instance)
	check(instance.material_override == null, "Fallback destroys authored masonry and timber vertex colors")
	instance.free()
	var blank := MeshInstance3D.new()
	blank.mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	blank.material_override = material
	check(game._mesh_needs_visible_fallback(blank), "Blank white surface must still fail")
	material.vertex_color_use_as_albedo = true
	check(game._mesh_needs_visible_fallback(blank), "A vertex-color flag without color data cannot pass")
	var mesh := ArrayMesh.new()
	var arrays := (blank.mesh as BoxMesh).get_mesh_arrays()
	var colors := PackedColorArray()
	colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	colors.fill(Color.WHITE)
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	blank.mesh = mesh
	check(game._mesh_needs_visible_fallback(blank), "All-white vertex data cannot hide a blank surface")
	colors.fill(Color(0.3, 0.2, 0.1))
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	blank.material_override = null
	blank.mesh = mesh
	check(game._mesh_needs_visible_fallback(blank), "A missing second-surface material must fail")
	blank.set_surface_override_material(1, material)
	check(not game._mesh_needs_visible_fallback(blank), "Valid authored colors and surface override must survive")
	blank.free()
