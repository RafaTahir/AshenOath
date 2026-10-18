extends SceneTree

const Factory = preload("res://tools/prepared_zone_geometry_factory.gd")
const ROOT := "res://assets_external/environment/prepared/"
var failed := false

func _initialize() -> void:
	call_deferred("_compile")

func _compile() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	_compile_static_batches()
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
	_save("wychwood_path_rocks", Factory.wychwood_path_rocks())
	for side in [-1.0, 1.0]:
		for bank in [0, 1]:
			_save("wychwood_floor_edge_%s_%s" % [side, bank], Factory.wychwood_floor_edge(side, bank))
	for count in [6, 9, 12]:
		_save_batch("wychwood_canopy_2.8_%d" % count, Factory.wychwood_canopy(2.8, count))
	for count in [4, 7, 9]:
		_save_batch("wychwood_canopy_4.4_%d" % count, Factory.wychwood_canopy(4.4, count))
	for count in [10, 16, 22]:
		_save_batch("wychwood_understory_%d" % count, Factory.wychwood_understory(count))
	for count in [12, 20, 28]:
		_save_batch("wychwood_floor_%d" % count, Factory.wychwood_floor(count))
	_compile_roads()
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

func _save_batch(id: String, transforms: Array[Transform3D]) -> void:
	var source := load("res://assets_external/environment/forest/Bush_Common.obj") as ArrayMesh
	var source_bounds := source.get_aabb()
	var data := PackedFloat32Array()
	var bounds := AABB()
	for index in transforms.size():
		data.append_array(preload("res://scripts/static_multimesh_upload.gd").prepare_record(transforms[index]).buffer)
		var instance_bounds: AABB = transforms[index] * source_bounds
		bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
	var result := Resource.new()
	result.set_meta("buffer", data)
	result.set_meta("bounds", bounds.grow(0.02))
	_save(id, result)

func _compile_roads() -> void:
	var materials = load("res://scripts/world_material_library.gd")
	var specs := [
		["greyfen", Vector3(0,0.018,0), Vector3(4.2,0.04,30)],
		["greyfen", Vector3(-5,0.02,9), Vector3(14,0.04,3)],
		["greyfen", Vector3(15.2,0.022,0), Vector3(8.8,0.045,3.4)],
		["wychwood", Vector3(-5,0.018,3), Vector3(24,0.04,4)],
		["campaign", Vector3(0,0.02,0), Vector3(4,0.04,28)],
		["campaign", Vector3(0,0.02,1), Vector3(5.2,0.05,34)],
		["campaign", Vector3(0,0.02,0), Vector3(8,0.05,32)],
	]
	for origin in [Vector3.ZERO, Vector3(14,0,8.6)]:
		specs.append(["greyfen", origin + Vector3(-4,0.024,-0.6), Vector3(8,0.045,2.6)])
		specs.append(["greyfen", origin + Vector3(-0.3,0.025,-0.6), Vector3(6.8,0.045,7.4)])
	for spec in specs:
		_save("%s_road_%s" % [spec[0], preload("res://scripts/prepared_zone_geometry.gd").geometry_key(spec[2], spec[1])], materials.make_tiled_ground_patch(spec[2], spec[1]))

func _save(id: String, resource: Resource) -> void:
	var error := ResourceSaver.save(resource, ROOT + id + ".res", ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		failed = true
		push_error("Geometry compilation failed: %s (%s)" % [id, error_string(error)])

func _compile_static_batches() -> void:
	var recipes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/static_batch_recipes.json"))
	if not recipes is Dictionary:
		failed = true
		push_error("Static batch source recipes are missing or invalid")
		return
	var entries: Dictionary = {}
	for id in recipes:
		var recipe: Dictionary = recipes[id]
		var pos := Vector3(recipe.position[0], recipe.position[1], recipe.position[2])
		var size := Vector3(recipe.size[0], recipe.size[1], recipe.size[2])
		var color := Color(recipe.color[0], recipe.color[1], recipe.color[2], recipe.color[3])
		var record := preload("res://scripts/static_multimesh_upload.gd").prepare_record(Transform3D(Basis.IDENTITY.scaled(size), pos), color)
		record["name"] = recipe.name
		record["position"] = pos
		record["size"] = size
		entries[id] = record
	var catalog := Resource.new()
	catalog.set_meta("entries", entries)
	var error := ResourceSaver.save(catalog, "res://data/prepared_static_batches.res", ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		failed = true
		push_error("Static batch compilation failed: " + error_string(error))
