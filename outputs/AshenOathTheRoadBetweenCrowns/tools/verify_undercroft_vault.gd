extends SceneTree

const Game = preload("res://scripts/game.gd")
const Spatial = preload("res://scripts/zone_spatial_service.gd")
const Materials = preload("res://scripts/world_material_library.gd")
const Settings = preload("res://scripts/settings_manager.gd")
const Finale = preload("res://scripts/zones/campaign_finale_section.gd")
const Memorial = preload("res://scripts/undercroft_memorial.gd")
const StoryState = preload("res://scripts/story_state.gd")
const PATH := "res://assets_external/environment/village/UndercroftVault_Authored.res"
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var mesh := load(PATH) as ArrayMesh
	check(mesh != null and mesh.get_surface_count() == 2, "Vault resource is missing or exceeds two surfaces")
	if mesh == null:
		quit(1)
		return
	check(int(mesh.get_meta("tomb_count", 0)) == 4, "A sarcophagus was removed")
	check(int(mesh.get_meta("wall_pier_count", 0)) == 10, "Vault ribs require ten grounded wall piers")
	check(int(mesh.get_meta("framed_door_count", 0)) == 2, "Both existing door openings need frames")
	check(int(mesh.get_meta("memorial_niche_count", 0)) == 1, "The witness memorial needs its supported rear-wall niche")
	check(FileAccess.get_file_as_bytes(PATH).size() < 100000, "Vault exceeds 100KB budget")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://runtime_asset_manifest.json"))
	var registration: Dictionary = {}
	for entry in manifest.get("authored_environment_derivatives", []):
		if entry.get("id", "") == "undercroft_vault":
			registration = entry
	check(registration.get("sha256", "") == FileAccess.get_sha256(PATH), "Vault manifest hash drift")
	check(int(registration.get("bytes", 0)) == FileAccess.get_file_as_bytes(PATH).size(), "Vault manifest byte drift")
	var filters := ConfigFile.new()
	check(filters.load("res://export_presets.cfg") == OK, "Export presets cannot be parsed")
	var campaign_filter := ""
	for section in filters.get_sections():
		if filters.get_value(section, "name", "") == "Runtime Pack Campaign":
			campaign_filter = filters.get_value(section, "include_filter", "")
	check(campaign_filter.contains(PATH.trim_prefix("res://")), "Campaign export omits the vault")
	for surface in mesh.get_surface_count():
		check(mesh.surface_get_material(surface) != null, "Null vault material")
		var arrays := mesh.surface_get_arrays(surface)
		for point in arrays[Mesh.ARRAY_VERTEX]:
			if surface == 0:
				check(point.y >= 3.045, "Vault intrudes on standing actor clearance")
			else:
				var tomb := absf(point.x) >= 7.89 and absf(point.x) <= 12.11 and (absf(point.z + 7) <= 1.051 or absf(point.z - 5) <= 1.051)
				var wall_dressing := absf(point.x) >= 13.12 or absf(point.z) >= 13.35
				check(tomb or wall_dressing, "Funerary dressing intrudes on reserved aisle or duel lane")
				check(point.y >= -0.002 and point.y <= (1.601 if tomb else 4.801), "Tomb or wall dressing exceeds declared height")
				for door in [Vector2(6, -14.5), Vector2(-6, 14.5)]:
					check(not (absf(point.z - door.y) < 1.0 and absf(point.x - door.x) < 2.10 and point.y < 3.4), "Dressing narrows an existing door opening")
	var game := Game.new()
	game.add_child(game.zone_residency)
	game.current_zone_id = "undercroft"
	game.shared_box_mesh = BoxMesh.new()
	game.settings = Settings.new()
	game.add_child(game.settings)
	game.world_materials = Materials.new()
	game.add_child(game.world_materials)
	game.spatial_service = Spatial.new()
	game.spatial_service.configure("undercroft", 999.0, Vector2(18, 17))
	game.add_child(game.spatial_service)
	game.zone_root = Node3D.new()
	root.add_child(game.zone_root)
	var context := ZoneBuildContext.new(game, "undercroft")
	var builder := Finale.new()
	builder._make_undercroft_vault(context)
	builder._make_undercroft_doorway_wall(context, -14.5, 6.0, false)
	builder._make_undercroft_doorway_wall(context, 14.5, -6.0, false)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(36, 0.16, 34)
	floor_shape.shape = box
	floor_shape.position.y = -0.08
	floor_body.add_child(floor_shape)
	game.zone_root.add_child(floor_body)
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
	for door in [Vector2(6, -14.5), Vector2(-6, 14.5)]:
		for offset in [-1.5, 0.0, 1.5]:
			for direction in [-1.0, 1.0]:
				player.position = Vector3(door.x + offset, 0, door.y - direction * 2)
				for step in range(40):
					await physics_frame
					var contact := player.move_and_collide(Vector3(0, 0, direction * 0.1))
					check(contact == null, "Vault or doorway snags capsule at %s offset=%s" % [door, offset])
					if contact != null:
						break
	var space := player.get_world_3d().direct_space_state
	var support := SpatialSurfaceContract.support_hit(space, Vector3(0, 6.2, 12), Vector3(0, -12, 12), [player.get_rid()])
	check(not support.is_empty() and absf(support.position.y) < 0.002, "Save grounding selects the overhead vault instead of the floor")
	for x in [-12.0, -6.0, 0.0, 6.0, 12.0]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 2.4, 0), Vector3(x, 6.5, 0), 1))
		check(not hit.is_empty(), "Authored vault has no matching overhead collision at x=%s" % x)
		if not hit.is_empty():
			check(hit.position.y >= 3.045, "Vault intrudes on standing actor clearance")
	# This fixture checks the new presentation lifecycle, not earned story choices.
	var story := StoryState.new()
	root.add_child(story)
	var memorial := Memorial.new()
	memorial.story_state = story
	memorial.stone_material = context.make_world_material("medieval_brick")
	memorial.timber_material = context.make_world_material("timber")
	game.zone_root.add_child(memorial)
	check(not memorial.vigil.visible and memorial.inscription.text.contains("BOUND TO VARGAN"), "Unresolved oath must not show a completed vigil")
	for fate in ["witness", "released", "destroyed", "defeated"]:
		story.set_flag("halvern_fate", fate)
		check(str(memorial.get_meta("halvern_fate", "")) == fate, "Memorial does not refresh on the existing story signal")
		check(memorial.vigil.visible == (fate in ["witness", "released"]), "Vigil misrepresents a violent or peaceful resolution")
		check((memorial.oath_inlay.material_override as StandardMaterial3D).albedo_color == (Color(0.59, 0.45, 0.24) if fate in ["witness", "released"] else Color(0.19, 0.17, 0.15)), "Duel inlay fails to reflect the resolved oath")
	check(memorial.oath_inlay.multimesh.instance_count == 3, "Stateful inlays changed the duel layout")
	for id in ["gate_record_hall", "gate_assembly"]:
		var area := Area3D.new()
		area.name = id
		area.set_meta("interior_door", true)
		game.zone_root.add_child(area)
		await process_frame
		check(area.has_node("UndercroftFittedDoor"), "Loaded or newly published door lacks its authored shell")
		var fitted := area.get_node_or_null("UndercroftFittedDoor") as MeshInstance3D
		if fitted != null:
			check(fitted.get_surface_override_material(0) != null and fitted.get_surface_override_material(1) != null, "Door has a null surface material")
	check(story.changed.get_connections().size() == 1, "Memorial duplicates its story subscription")
	memorial.free()
	check(story.changed.get_connections().is_empty(), "Retired memorial retains its story subscription")
	story.free()
	player.free()
	game.zone_residency._bind_retirement_material(game.zone_root)
	await process_frame
	game.zone_residency._release_zone_render_resources(game.zone_root)
	await process_frame
	game.zone_root.free()
	game.free()
	await process_frame
	RenderingServer.force_sync()
	print("UNDERCROFT VAULT CONTRACT: %s (support grounding, mesh/collision and bidirectional door sweeps; not visual/campaign acceptance)" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
