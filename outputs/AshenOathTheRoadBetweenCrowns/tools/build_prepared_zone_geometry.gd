extends SceneTree

const Factory = preload("res://tools/prepared_zone_geometry_factory.gd")
const PreparedForestTrees = preload("res://scripts/prepared_forest_trees.gd")
const ROOT := "res://assets_external/environment/prepared/"
const FOREST_TREE_COMPILERS := [
	"res://scripts/prepared_forest_trees.gd",
	"res://tools/build_prepared_zone_geometry.gd",
	"res://tools/prepared_zone_geometry_factory.gd",
]
var failed := false

func _initialize() -> void:
	call_deferred("_compile")

func _compile() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	if "--forest-trees-only" in OS.get_cmdline_user_args():
		_compile_forest_trees()
		quit(1 if failed else 0)
		return
	if "--roads-only" in OS.get_cmdline_user_args():
		_compile_roads(true)
		quit(1 if failed else 0)
		return
	_compile_forest_trees()
	if failed:
		quit(1)
		return
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

func _compile_roads(only_missing: bool = false) -> void:
	var materials = load("res://scripts/world_material_library.gd")
	var specs := [
		["greyfen", Vector3(0,0.018,0), Vector3(4.2,0.04,30)],
		["greyfen", Vector3(-5,0.02,9), Vector3(14,0.04,3)],
		["greyfen", Vector3(15.2,0.022,0), Vector3(8.8,0.045,3.4)],
		["wychwood", Vector3(-5,0.018,3), Vector3(24,0.04,4)],
		["wychwood", Vector3(-15,0.018,5), Vector3(16,0.04,3.2)],
		["campaign", Vector3(0,0.02,0), Vector3(4,0.04,28)],
		["campaign", Vector3(0,0.02,1), Vector3(5.2,0.05,34)],
		["campaign", Vector3(0,0.02,0), Vector3(8,0.05,32)],
		["campaign", Vector3(15,0.025,9), Vector3(12,0.035,3)],
	]
	var community := load("res://scripts/zones/community_section.gd") as Script
	if community != null:
		var service_road: Array = community.LANTERN_SERVICE_ROAD
		specs.append(["campaign", service_road[0], service_road[1]])
		for road: Array in community.APPROACH_ROADS:
			specs.append(["campaign", road[0], road[1]])
	else:
		failed = true
		push_error("Community road specifications could not be loaded")
		return
	for origin in [Vector3.ZERO, Vector3(14,0,8.6)]:
		specs.append(["greyfen", origin + Vector3(-4,0.024,-0.6), Vector3(8,0.045,2.6)])
		specs.append(["greyfen", origin + Vector3(-0.3,0.025,-0.6), Vector3(6.8,0.045,7.4)])
	for spec in specs:
		var id := "%s_road_%s" % [spec[0], preload("res://scripts/prepared_zone_geometry.gd").geometry_key(spec[2], spec[1])]
		if only_missing and ResourceLoader.exists(ROOT + id + ".res"):
			continue
		_save(id, materials.make_tiled_ground_patch(spec[2], spec[1]))

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

func _forest_tree_failure(message: String) -> void:
	failed = true
	push_error("Prepared forest tree compilation failed: " + message)

func _forest_fingerprints(paths: Array) -> Dictionary:
	var result: Dictionary = {}
	for path: String in paths:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_forest_tree_failure("required fingerprint input is missing: " + path)
			return {}
		var size := file.get_length()
		file.close()
		var digest := FileAccess.get_sha256(path)
		if digest.length() != 64:
			_forest_tree_failure("cannot fingerprint " + path)
			return {}
		result[path] = {"sha256": digest, "bytes": size}
	return result

func _forest_source_fingerprints(source: String) -> Dictionary:
	if not FileAccess.file_exists(source) or not FileAccess.file_exists(source + ".import"):
		_forest_tree_failure("source OBJ or its completed import is missing: " + source)
		return {}
	var paths: Array = [source, source + ".import"]
	for line: String in FileAccess.get_file_as_string(source).split("\n"):
		var clean := line.strip_edges()
		if not clean.begins_with("mtllib "):
			continue
		var declaration := clean.trim_prefix("mtllib ").strip_edges()
		var names: PackedStringArray = PackedStringArray([declaration.trim_prefix('"').trim_suffix('"')]) if declaration.begins_with('"') else declaration.split(" ", false)
		for name: String in names:
			var path := source.get_base_dir().path_join(name).simplify_path()
			if not path.begins_with(source.get_base_dir() + "/"):
				_forest_tree_failure("material library escapes the tree source directory: " + path)
				return {}
			if path not in paths:
				paths.append(path)
	if paths.size() < 3:
		_forest_tree_failure("tree OBJ has no retained material library: " + source)
		return {}
	paths.sort()
	return _forest_fingerprints(paths)

func _compile_forest_trees() -> void:
	var compiler_fingerprints := _forest_fingerprints(FOREST_TREE_COMPILERS)
	if compiler_fingerprints.is_empty():
		return
	var catalog: Dictionary = {}
	for source_path: String in PreparedForestTrees.source_paths():
		var source_fingerprints := _forest_source_fingerprints(source_path)
		if source_fingerprints.is_empty():
			return
		# Deliberately load the original only inside this compiler. Runtime paths
		# resolve directly to the certified derivative and never need its textures.
		var source := ResourceLoader.load(source_path, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		if source == null:
			_forest_tree_failure("cannot load the completed tree import: " + source_path)
			return
		var original_geometry := PreparedForestTrees.geometry_signature(source)
		var mesh := Factory.forest_tree(source, source_path)
		if mesh == null or original_geometry == "":
			_forest_tree_failure("geometry or effective material contract rejected " + source_path)
			return
		var material_signature := PreparedForestTrees.material_signature(mesh)
		mesh.set_meta("forest_tree_contract_version", PreparedForestTrees.CONTRACT_VERSION)
		mesh.set_meta("forest_tree_source", source_path)
		mesh.set_meta("forest_tree_geometry_sha256", original_geometry)
		mesh.set_meta("forest_tree_material_sha256", material_signature)
		var output_path := PreparedForestTrees.resource_path(source_path)
		var error := ResourceSaver.save(mesh, output_path, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			_forest_tree_failure("cannot save %s: %s" % [output_path, error_string(error)])
			return
		var dependencies := ResourceLoader.get_dependencies(output_path)
		if not dependencies.is_empty():
			_forest_tree_failure("prepared tree retains external resources: %s %s" % [output_path, str(dependencies)])
			return
		var reloaded := ResourceLoader.load(output_path, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		if reloaded == null or PreparedForestTrees.geometry_signature(reloaded) != original_geometry:
			_forest_tree_failure("saved tree changed surface arrays, names, LODs or bounds: " + source_path)
			return
		var names: Array = []
		for index in source.get_surface_count():
			names.append(source.surface_get_name(index))
		var bounds := source.get_aabb()
		var compiled := _forest_fingerprints([output_path])
		if compiled.is_empty():
			return
		var record := {
			"contract_version": PreparedForestTrees.CONTRACT_VERSION,
			"source_path": source_path,
			"path": output_path,
			"compiled_sha256": compiled[output_path].sha256,
			"compiled_bytes": compiled[output_path].bytes,
			"source_fingerprints": source_fingerprints,
			"compiler_fingerprints": compiler_fingerprints,
			"source_geometry_sha256": original_geometry,
			"geometry_sha256": PreparedForestTrees.geometry_signature(reloaded),
			"material_sha256": material_signature,
			"surface_names": names,
			"aabb": [bounds.position.x, bounds.position.y, bounds.position.z, bounds.size.x, bounds.size.y, bounds.size.z],
			"source_scene_dependencies": [],
			"resource_dependencies": [],
		}
		if not PreparedForestTrees.validate(reloaded, source_path, record):
			_forest_tree_failure("saved tree failed its exact effective material check: " + source_path)
			return
		if _forest_source_fingerprints(source_path) != source_fingerprints:
			_forest_tree_failure("tree inputs changed during compilation: " + source_path)
			return
		catalog[source_path] = record
		print("PREPARED FOREST TREE: PASS source=%s surfaces=%d exact_geometry=true exact_flat_materials=true dependencies=0" % [source_path, names.size()])
	if _forest_fingerprints(FOREST_TREE_COMPILERS) != compiler_fingerprints or catalog.size() != PreparedForestTrees.SOURCES.size():
		_forest_tree_failure("compiler inputs changed or the catalog is incomplete")
		return
	var file := FileAccess.open(PreparedForestTrees.CATALOG_PATH, FileAccess.WRITE)
	if file == null:
		_forest_tree_failure("cannot write " + PreparedForestTrees.CATALOG_PATH)
		return
	file.store_string(JSON.stringify(catalog, "  ", true, true) + "\n")
	file.close()
	# Autoloads may have inspected an earlier receipt in this same compiler
	# process. The following zone preparation must see the newly written proof.
	PreparedForestTrees.clear_cached_catalog()
