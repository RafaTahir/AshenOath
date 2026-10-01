extends SceneTree

const Game = preload("res://scripts/game.gd")
const Spatial = preload("res://scripts/zone_spatial_service.gd")
const Wilderness = preload("res://scripts/zones/campaign_wilderness_section.gd")
const Records = preload("res://scripts/campaign_record_presentation.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := Game.new()
	game.add_child(game.zone_residency)
	game.shared_box_mesh = BoxMesh.new()
	game.settings = preload("res://scripts/settings_manager.gd").new()
	game.add_child(game.settings)
	game.world_materials = preload("res://scripts/world_material_library.gd").new()
	game.add_child(game.world_materials)
	game.zone_root = Node3D.new()
	root.add_child(game.zone_root)
	game.spatial_service = Spatial.new()
	game.zone_root.add_child(game.spatial_service)
	game.spatial_service.configure("burned_farmstead", 999, Vector2(20, 16))
	game._make_collision_box("Ground", Vector3(0, -0.08, 0), Vector3(40, 0.16, 32))
	Wilderness.new()._make_burned_home(ZoneBuildContext.new(game, "burned_farmstead"), Vector3(-8, 0, -5), "West")
	await physics_frame
	await physics_frame
	var position := Vector3(-7, 0, -5)
	var resolved: Vector3 = game.river_safe_position(position, 0.8)
	_check(resolved.is_equal_approx(position), "Existing register interaction moved under actor occupancy rules: " + str(resolved))
	var area := Node3D.new()
	area.position = resolved
	game.zone_root.add_child(area)
	_check(Records.apply(area, "register_rook"), "Charred record presentation missing")
	_check(area.find_children("*", "CollisionObject3D", true, false).is_empty(), "Record changes collision/routes")
	for identity in ["register_rook", "register_mira", "mill_pending", "mill_preserved", "mill_burned", "mill_exposed"]:
		var mesh := load(Records.PATH % identity) as ArrayMesh
		_check(mesh != null, "Missing record: " + identity)
		if mesh == null:
			continue
		_check(mesh.get_surface_count() == 2 and mesh.get_faces().size() / 3 < 6000, "Record draw/triangle budget: " + identity)
		_check(FileAccess.get_file_as_bytes(mesh.resource_path).size() < 120000, "Record byte budget: " + identity)
		_check(mesh.get_meta("record_identity", "") == identity and mesh.get_meta("license", "") == "CC0 1.0", "Record identity/license drift")
		_check(absf(mesh.get_aabb().position.y - float(mesh.get_meta("ground_offset"))) < 0.001, "Record support is floating or buried: " + identity)
		for source in mesh.get_meta("source_sha256", {}):
			_check(mesh.get_meta("source_sha256")[source] == FileAccess.get_sha256(source), "Record source hash changed")
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://runtime_asset_manifest.json"))
		var entry: Dictionary = {}
		for candidate in manifest.get("authored_environment_derivatives", []):
			if candidate.get("path", "") == mesh.resource_path:
				entry = candidate
		_check(entry.get("sha256", "") == FileAccess.get_sha256(mesh.resource_path) and int(entry.get("bytes", 0)) == FileAccess.get_file_as_bytes(mesh.resource_path).size(), "Record registration/hash/byte drift")
		var presets := ConfigFile.new()
		presets.load("res://export_presets.cfg")
		var exported := false
		for section in presets.get_sections():
			if presets.get_value(section, "name", "") == "Runtime Pack Campaign":
				exported = str(presets.get_value(section, "include_filter", "")).contains(mesh.resource_path.trim_prefix("res://"))
		_check(exported, "Required record absent from campaign export filter")
		for surface in mesh.get_surface_count():
			_check(mesh.surface_get_material(surface) != null, "Null record material")
			for normal in mesh.surface_get_arrays(surface)[Mesh.ARRAY_NORMAL]:
				_check(normal.is_finite() and normal.length_squared() > 0.8, "Invalid record normal")
	var id_source := FileAccess.get_file_as_string("res://scripts/zones/campaign_wilderness_section.gd")
	_check(id_source.contains('"register_rook", "Recover charred names", Vector3(-7,0,-5)') and id_source.contains('"register_mira", "Recover the healer\'s fragment", Vector3(3,0,-7)'), "Register identity/position changed")
	_check(not id_source.contains('"PostedMillLedgerCopies"') and not id_source.contains('"BurnedMillLedgerAsh"'), "Old flat fate proxies remain")
	print("CAMPAIGN RECORD CONTRACT: %s position=%s (materials/support/resources/unchanged interaction; NOT graphical or route acceptance)" % ["PASS" if failures.is_empty() else "FAIL", resolved])
	game.zone_residency._bind_retirement_material(game.zone_root)
	await process_frame
	game.zone_residency._release_zone_render_resources(game.zone_root)
	await process_frame
	game.zone_root.free()
	game.free()
	await process_frame
	RenderingServer.force_sync()
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
