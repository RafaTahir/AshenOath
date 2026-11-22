extends SceneTree

const DIRECTORY := "D:/Temp/AshenOath/perf_shared_humanoids_20260928/assets"
const SOURCE_DIR := "res://assets_external/characters_universal/runtime/"
const FILES: Array[String] = ["Anwen_A_Set_Atlas", "Kael_A_Set_Atlas", "Villager_Female_Atlas", "Villager_Hooded_Atlas", "Villager_Male_Atlas", "Villager_Worker_Atlas"]
var shared_meshes: Dictionary = {}
var failures: Array[String] = []
var report := {"scope": "offline_shared_geometry_candidate_not_production_acceptance", "scenes": [], "geometry": []}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	for basename in FILES:
		var path: String = SOURCE_DIR + basename + ".gltf"
		var original := load(path) as PackedScene
		var model := original.instantiate()
		var before := _snapshot(model)
		for raw in model.find_children("*", "MeshInstance3D", true, false):
			var node := raw as MeshInstance3D
			var source := node.mesh as ArrayMesh
			if source == null or source.get_blend_shape_count() != 0 or node.material_override != null:
				failures.append("Unsupported authored mesh: " + basename + "/" + node.name)
				continue
			var key := _geometry_hash(source)
			if key.is_empty():
				continue
			if not shared_meshes.has(key):
				var shared := source.duplicate(false) as ArrayMesh
				if shared.shadow_mesh != null:
					shared.shadow_mesh = shared.shadow_mesh.duplicate(false)
				for surface in shared.get_surface_count():
					var base := source.surface_get_material(surface)
					if base == null:
						failures.append("Null authored base material: " + basename)
					else:
						shared.surface_set_material(surface, base.duplicate(false))
				shared.set_meta("shared_immutable_geometry_candidate", true)
				var mesh_path := DIRECTORY + "/geometry_" + key + ".res"
				_check(ResourceSaver.save(shared, mesh_path, ResourceSaver.FLAG_COMPRESS) == OK, "Could not save geometry")
				shared.take_over_path(mesh_path)
				shared_meshes[key] = shared
				report.geometry.append({"hash": key, "path": mesh_path, "source": path, "vertices": source.surface_get_array_len(0)})
			for surface in source.get_surface_count():
				var effective := node.get_active_material(surface)
				_check(effective != null, "Missing authored effective material")
				if effective != null:
					node.set_surface_override_material(surface, effective.duplicate(false))
			if node.skin != null:
				node.skin = node.skin.duplicate(true)
			node.mesh = shared_meshes[key]
		var packed := PackedScene.new()
		_check(packed.pack(model) == OK, "Could not pack candidate " + basename)
		var output: String = DIRECTORY + "/" + basename + ".scn"
		_check(ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS) == OK, "Could not save candidate " + basename)
		model.free()
		# Reload from disk, not the in-memory PackedScene, to verify serialization.
		var reloaded := ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		_check(reloaded != null, "Saved scene could not be reloaded: " + basename)
		if reloaded == null:
			continue
		var restored := reloaded.instantiate()
		var after := _snapshot(restored)
		_check(before == after, "Serialized node/geometry/material/skin parity differs for " + basename)
		report.scenes.append({"source": path, "source_sha256": FileAccess.get_sha256(path), "candidate": output, "candidate_sha256": FileAccess.get_sha256(output), "dependencies": ResourceLoader.get_dependencies(output), "parity": before == after, "node_count": before.size()})
		restored.free()
		original = null
		packed = null
		reloaded = null
	_check(report.scenes.size() == FILES.size(), "Not all six authored scenes survived serialization")
	report["status"] = "unit_pass" if failures.is_empty() else "failed"
	report["failures"] = failures
	var file := FileAccess.open(DIRECTORY + "/manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	shared_meshes.clear()
	print("SHARED HUMANOID OFFLINE PARITY: %s, %d scenes / %d exact geometry resources" % [report.status, report.scenes.size(), report.geometry.size()])
	print("VERIFIER_PHASE: SHUTDOWN")
	await process_frame
	RenderingServer.force_sync()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _geometry_hash(mesh: ArrayMesh) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes([mesh.get_surface_count(), mesh.get_blend_shape_count(), mesh.blend_shape_mode, mesh.custom_aabb]))
	for surface in mesh.get_surface_count():
		var data := RenderingServer.mesh_get_surface(mesh.get_rid(), surface)
		if not data.has("vertex_data"):
			failures.append("Renderer did not supply complete surface data")
			return ""
		data.erase("material")
		var keys := data.keys()
		keys.sort()
		for key in keys:
			context.update(var_to_bytes([key, data[key]]))
	context.update(var_to_bytes(_geometry_hash(mesh.shadow_mesh) if mesh.shadow_mesh != null else "no_shadow_mesh"))
	return context.finish().hex_encode()

func _snapshot(model: Node) -> Array:
	var entries: Array = []
	var nodes: Array[Node] = [model]
	nodes.append_array(model.find_children("*", "", true, false))
	for node in nodes:
		var row: Array = [str(model.get_path_to(node)), node.get_class()]
		if node is Node3D:
			row.append(node.transform)
		if node is Skeleton3D:
			for bone in node.get_bone_count():
				row.append([node.get_bone_name(bone), node.get_bone_parent(bone), node.get_bone_rest(bone), node.get_bone_pose(bone)])
		if node is MeshInstance3D:
			row.append([_geometry_hash(node.mesh), node.skeleton, node.cast_shadow, node.visible, node.custom_aabb, node.lod_bias])
			if node.skin != null:
				for bind in node.skin.get_bind_count():
					row.append([node.skin.get_bind_name(bind), node.skin.get_bind_bone(bind), node.skin.get_bind_pose(bind)])
			for surface in node.mesh.get_surface_count():
				row.append(_material_snapshot(node.get_active_material(surface)))
		entries.append(row)
	return entries

func _material_snapshot(material: Material) -> Array:
	if material == null:
		return ["NULL"]
	var state: Array = [material.get_class()]
	for property in material.get_property_list():
		var name := str(property.name)
		if (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0 or name.begins_with("resource_") or name.begins_with("metadata/"):
			continue
		var value = material.get(name)
		if value is Texture2D:
			var image: Image = value.get_image()
			var context := HashingContext.new()
			context.start(HashingContext.HASH_SHA256)
			context.update(image.get_data())
			state.append([name, image.get_size(), image.get_format(), context.finish()])
		elif value is Resource:
			failures.append("Unsupported nested authored material resource: " + name)
		else:
			state.append([name, value])
	return state

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
