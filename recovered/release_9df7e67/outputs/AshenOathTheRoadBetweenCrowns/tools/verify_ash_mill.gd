extends SceneTree

const Game = preload("res://scripts/game.gd")
const Spatial = preload("res://scripts/zone_spatial_service.gd")
const Materials = preload("res://scripts/world_material_library.gd")
const Settings = preload("res://scripts/settings_manager.gd")
const Wilderness = preload("res://scripts/zones/campaign_wilderness_section.gd")
const PATH := "res://assets_external/environment/village/AshMill_Authored.res"
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var mesh := load(PATH) as ArrayMesh
	check(mesh != null, "Authored mill resource is missing")
	if mesh == null:
		quit(1)
		return
	check(mesh.get_surface_count() == 2, "Mill must retain its two-surface budget")
	check(mesh.get_aabb().position.y >= -0.002, "Mill foundation is below ground")
	check(mesh.get_aabb().end.y <= 4.4, "Mill exceeds its authored roof height")
	check(FileAccess.get_file_as_bytes(PATH).size() < 100000, "Mill exceeds its 100KB budget")
	check(mesh.get_meta("license", "") == "CC0 1.0", "Mill has no source license")
	for surface in mesh.get_surface_count():
		check(mesh.surface_get_material(surface) != null, "Null mill material")
		var indices: PackedInt32Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
		check(not indices.is_empty(), "Mill surface is not indexed")
	var hashes: Dictionary = mesh.get_meta("source_sha256", {})
	for source in hashes:
		check(hashes[source] == FileAccess.get_sha256("res://assets_external/environment/village/" + source), "Mill source hash drift: " + source)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://runtime_asset_manifest.json"))
	var registration: Dictionary = {}
	for entry in manifest.get("authored_environment_derivatives", []):
		if entry.get("id", "") == "ash_mill_architecture":
			registration = entry
	check(registration.get("sha256", "") == FileAccess.get_sha256(PATH), "Mill manifest hash drift")
	check(int(registration.get("bytes", 0)) == FileAccess.get_file_as_bytes(PATH).size(), "Mill manifest byte drift")
	check(FileAccess.file_exists(str(registration.get("license_file", ""))), "Mill source license is missing")
	var filters := ConfigFile.new()
	check(filters.load("res://export_presets.cfg") == OK, "Export presets cannot be parsed")
	var campaign_filter := ""
	for section in filters.get_sections():
		if filters.get_value(section, "name", "") == "Runtime Pack Campaign":
			campaign_filter = filters.get_value(section, "include_filter", "")
	check(campaign_filter.contains(PATH.trim_prefix("res://")), "Campaign export omits the mill shell")
	var game := Game.new()
	game.add_child(game.zone_residency)
	game.current_zone_id = "old_mill"
	game.shared_box_mesh = BoxMesh.new()
	game.settings = Settings.new()
	game.add_child(game.settings)
	game.world_materials = Materials.new()
	game.add_child(game.world_materials)
	game.spatial_service = Spatial.new()
	game.spatial_service.configure("old_mill", 999.0, Vector2(23, 19))
	game.add_child(game.spatial_service)
	game.zone_root = Node3D.new()
	root.add_child(game.zone_root)
	var context := ZoneBuildContext.new(game, "old_mill")
	var builder := Wilderness.new()
	builder._make_mill_shell(context)
	builder._make_mill_landscape(context)
	var track := game.zone_root.find_child("AshMillCartTrack", true, false) as MeshInstance3D
	var ridge := game.zone_root.find_child("AshMillDistantBank", true, false) as MeshInstance3D
	check(track != null and track.material_override != null, "Mill track has no valid surface")
	check(ridge != null and ridge.material_override != null, "Mill horizon has no valid surface")
	if ridge != null:
		check(ridge.mesh.get_aabb().end.z < -16.0, "Distant terrain invades the playable route")
	await physics_frame
	await physics_frame
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
	for x in [-8.2, -6.5, -5.2, -3.0, -2.2]:
		for direction in [-1.0, 1.0]:
			player.position = Vector3(x, 0, -4.6 if direction > 0 else -1.5)
			for step in range(30):
				await physics_frame
				var contact := player.move_and_collide(Vector3(0, 0, direction * 0.1))
				check(contact == null, "Mill front snags the capsule at x=%s step=%d" % [x, step])
				if contact != null:
					break
	player.position = Vector3(-5.2, 0, -4.6)
	check(player.move_and_collide(Vector3(0, 0, -5)) != null, "Original rear wall lost collision")
	player.free()
	game.zone_residency._bind_retirement_material(game.zone_root)
	await process_frame
	game.zone_residency._release_zone_render_resources(game.zone_root)
	await process_frame
	game.zone_root.free()
	game.free()
	await process_frame
	RenderingServer.force_sync()
	print("ASH MILL CONTRACT: %s (resource and physical open-front sweep; not visual/story acceptance)" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
