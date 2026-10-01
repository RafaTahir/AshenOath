extends SceneTree

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pack-only="):
			var mounted := ProjectSettings.load_resource_pack(argument.trim_prefix("--pack-only="))
			var valid := mounted
			for relative in ["village/Wall_Plaster_Door_Flat.obj", "village/Wall_Plaster_Window_Wide_Flat.obj", "village/Wall_Plaster_Straight_Base.obj", "village/Prop_Chimney.obj", "forest/TwistedTree_2.obj", "forest/RockPath_Round_Small_1.obj"]:
				var path: String = "res://assets_external/environment/" + relative
				var imported: Resource = load(path) if ResourceLoader.exists(path) else null
				valid = valid and imported is ArrayMesh
				print("PACKED OBJ %s imported=%s" % [relative, imported is ArrayMesh])
			var path_rock_texture := "res://assets_external/environment/forest/PathRocks_Diffuse.png"
			var packed_texture := load(path_rock_texture) if ResourceLoader.exists(path_rock_texture) else null
			valid = valid and packed_texture is Texture2D
			print("PACKED TEXTURE %s imported=%s" % [path_rock_texture, packed_texture is Texture2D])
			quit(0 if valid else 1)
			return
	var helper = load("res://scripts/asset_spawn_helper.gd").new()
	var passed := true
	for relative in ["village/Wall_Plaster_Door_Flat.obj", "village/Wall_Plaster_Straight_Base.obj", "village/Roof_RoundTiles_8x10.obj", "forest/TwistedTree_2.obj", "forest/Rock_Medium_1.obj", "forest/RockPath_Round_Small_1.obj"]:
		var path: String = "res://assets_external/environment/" + relative
		var started := Time.get_ticks_usec()
		var fast: ArrayMesh = helper._load_obj_mesh(path)
		var fast_us := Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		var legacy: ArrayMesh = helper._load_obj_mesh_text(path)
		var legacy_us := Time.get_ticks_usec() - started
		var valid := fast != null and legacy != null
		if valid:
			valid = fast.get_aabb().position.is_equal_approx(legacy.get_aabb().position) and fast.get_aabb().size.is_equal_approx(legacy.get_aabb().size)
			valid = valid and _matching_vertices(_vertices(fast), _vertices(legacy))
			valid = valid and absf(_area(fast) - _area(legacy)) <= maxf(0.001, _area(legacy) * 0.001)
		passed = passed and valid
		print("OBJ IMPORT %s valid=%s imported_us=%d text_us=%d" % [relative, valid, fast_us, legacy_us])
		if not valid:
			print("GEOMETRY DETAIL bounds=%s/%s vertices=%d/%d area=%f/%f" % [fast.get_aabb(), legacy.get_aabb(), _vertices(fast).size(), _vertices(legacy).size(), _area(fast), _area(legacy)])
			push_error("Imported OBJ geometry differs: " + relative)
	helper.free()
	quit(0 if passed else 1)

func _vertices(mesh: ArrayMesh) -> Array[String]:
	var result: Array[String] = []
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for index in indices:
			var vertex := positions[index]
			var key := "%.3f,%.3f,%.3f" % [vertex.x + 0.00001, vertex.y + 0.00001, vertex.z + 0.00001]
			if not result.has(key):
				result.append(key)
	result.sort()
	return result

func _area(mesh: ArrayMesh) -> float:
	var total := 0.0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for index in range(0, indices.size(), 3):
			total += (vertices[indices[index + 1]] - vertices[indices[index]]).cross(vertices[indices[index + 2]] - vertices[indices[index]]).length() * 0.5
	return total

func _matching_vertices(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	var remaining := right.duplicate()
	for key in left:
		if remaining.has(key):
			remaining.erase(key)
			continue
		var xyz := key.split(",")
		var point := Vector3(float(xyz[0]), float(xyz[1]), float(xyz[2]))
		var match_index := -1
		for index in remaining.size():
			var other: PackedStringArray = remaining[index].split(",")
			if point.distance_to(Vector3(float(other[0]), float(other[1]), float(other[2]))) < 0.0011:
				match_index = index
				break
		if match_index < 0:
			return false
		remaining.remove_at(match_index)
	return remaining.is_empty()
