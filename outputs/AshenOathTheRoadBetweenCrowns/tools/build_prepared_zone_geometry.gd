extends SceneTree

const Factory = preload("res://tools/prepared_zone_geometry_factory.gd")
const ROOT := "res://assets_external/environment/prepared/"
var failed := false

func _initialize() -> void:
	call_deferred("_compile")

func _compile() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	var packed := load("res://scenes/runtime/greyfen_gameplay_core.tscn") as PackedScene
	var source := packed.instantiate() as Node3D
	root.add_child(source)
	var specs: Array = []
	for id in ["GroundNorthWest", "GroundNorthEast", "GroundSouthWest", "GroundSouthEast", "GroundCenterNorthVisual", "GroundCenterSouthVisual"]:
		var node := source.find_child(id, true, false)
		var surface := node as MeshInstance3D if node is MeshInstance3D else node.get_node("Surface") as MeshInstance3D
		specs.append({"name": id, "origin": source.to_local(surface.global_position), "size": surface.scale})
	_save("greyfen_ground", Factory.greyfen_ground(specs))
	for id in ["PavedRoadMain", "PavedRoadVillage", "PavedRoadCastle"]:
		var road := source.find_child(id, true, false) as MeshInstance3D
		_save("greyfen_" + id, Factory._make_greyfen_road_surface(road.scale, road.position))
	source.free()
	_save("wychwood_clearing", Factory.wychwood_clearing())
	_save("wychwood_winding_path", Factory.wychwood_winding_path())
	_save("wychwood_layby", Factory.wychwood_layby())
	_compile_wychwood_ground()
	for z in [12, 9, 6, 3, 0, -3, -6, -9]:
		for x in [-4.25, 4.25]:
			var pos := Vector3(x, 0, z)
			var size := Vector3(1.4, 0.48, 2.2)
			_save("wychwood_berm_" + preload("res://scripts/prepared_zone_geometry.gd").geometry_key(size, pos), Factory.low_berm(pos, size))
	_save("AshMillYard", Factory.mill_path(Vector3(-5.2, 0.048, -5.5), 8.0, 3.0))
	_save("AshMillCartTrack", Factory.mill_path(Vector3(0, 0.039, 0), 3.35, 28.0))
	_save("mill_ridge", Factory.mill_ridge())
	_save("mill_ramp", Factory.ramp(0.48, 2.6))
	_save("farm_ramp", Factory.ramp(0.40, 1.6))
	var vault: Dictionary = Factory.record_vault()
	for id in vault:
		_save(id, vault[id])
	_save("record_ribs", Factory.record_ribs())
	var undercroft := load("res://assets_external/environment/village/UndercroftVault_Authored.res") as ArrayMesh
	var roof := ArrayMesh.new()
	roof.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, undercroft.surface_get_arrays(0))
	_save("undercroft_roof_collision", roof.create_trimesh_shape())
	quit(1 if failed else 0)

func _compile_wychwood_ground() -> void:
	# Same six visual extents as _make_split_ground; collision remains runtime-owned.
	var contract = preload("res://scripts/bridge_surface_contract.gd")
	var bridge_width: float = contract.DECK_WIDTH
	var side_width := maxf((44.0 - bridge_width) * 0.5, 0.1)
	var side_center := bridge_width * 0.5 + side_width * 0.5
	var north_depth := -3.4 * 0.5 + 34.0 * 0.5
	var south_edge := 3.4 * 0.5
	var south_depth := 34.0 * 0.5 - south_edge
	var support_half: float = contract.bridge_length(3.4) * 0.5 + contract.APPROACH_LENGTH
	var corridor_depth := maxf(34.0 * 0.5 - support_half, 0.0)
	var specs := [
		[Vector3(-side_center,-0.08,-34.0*0.5+north_depth*0.5), Vector3(side_width,0.16,north_depth)],
		[Vector3(side_center,-0.08,-34.0*0.5+north_depth*0.5), Vector3(side_width,0.16,north_depth)],
		[Vector3(-side_center,-0.08,south_edge+south_depth*0.5), Vector3(side_width,0.16,south_depth)],
		[Vector3(side_center,-0.08,south_edge+south_depth*0.5), Vector3(side_width,0.16,south_depth)],
		[Vector3(0,-0.08,-34.0*0.5+corridor_depth*0.5), Vector3(bridge_width,0.16,corridor_depth)],
		[Vector3(0,-0.08,support_half+corridor_depth*0.5), Vector3(bridge_width,0.16,corridor_depth)],
	]
	for spec in specs:
		_save("wychwood_ground_" + preload("res://scripts/prepared_zone_geometry.gd").geometry_key(spec[1], spec[0]), Factory.wychwood_ground(spec[1], spec[0]))

func _save(id: String, resource: Resource) -> void:
	var error := ResourceSaver.save(resource, ROOT + id + ".res", ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		failed = true
		push_error("Geometry compilation failed: %s (%s)" % [id, error_string(error)])
