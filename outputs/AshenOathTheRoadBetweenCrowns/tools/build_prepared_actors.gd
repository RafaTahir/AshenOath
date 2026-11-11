extends SceneTree

## Asset compilation only. No game world, animation playback, camera or QA run.
const Helper = preload("res://scripts/asset_spawn_helper.gd")
const NodeManifest = preload("res://scripts/character_node_manifest.gd")
const MaterialBindings = preload("res://scripts/character_material_bindings.gd")
const CreatureAmbientContract = preload("res://tools/creature_ambient_source_contract.gd")
const OUTPUT := "res://assets_external/characters_prepared/"
var helper: Node
var presets := ConfigFile.new()
var entries: Dictionary = {}
var templates: Dictionary = {}
var template_materials: Dictionary = {}
var template_creature_ambient: Dictionary = {}
var failed := false
const NativeFace = preload("res://tools/build_native_facial_bindings.gd")
const FACIAL_ASSEMBLIES := ["Kael_A_Set_Atlas.gltf", "Anwen_A_Set_Atlas.gltf", "Villager_Male_Atlas.gltf", "Villager_Female_Atlas.gltf", "Villager_Worker_Atlas.gltf", "Villager_Hooded_Atlas.gltf", "Bandit_Deserter_Atlas.gltf", "Bandit_Tracker_Atlas.gltf", "Male_Ranger_Runtime.gltf"]

func _initialize() -> void:
	if "--verify-existing-scenes" in OS.get_cmdline_user_args():
		_verify_existing_scenes()
		return
	if "--refresh-library-ownership" in OS.get_cmdline_user_args():
		_refresh_library_ownership()
		return
	call_deferred("_compile")

func _refresh_library_ownership() -> void:
	var path := "res://data/prepared_actors.json"
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for key: String in catalog:
		var entry: Dictionary = catalog[key]
		for binding: Dictionary in entry.get("material_bindings", []):
			binding.surface = int(binding.surface)
		var pending: Array[String] = [str(entry.path)]
		# Living-cast libraries are selected by identity at runtime, so scene
		# dependency walking alone cannot discover them. Keep each beside its
		# owning actor instead of pulling every performance into the base pack.
		var life_profile: Dictionary = preload("res://scripts/story_cast_profile.gd").life_motion_profile(str(entry.get("role", "")))
		var life_library := str(life_profile.get("library", ""))
		if life_library != "":
			if not ResourceLoader.exists(life_library):
				push_error("Missing authored life library for %s: %s" % [entry.get("role", ""), life_library])
				quit(1)
				return
			pending.append(life_library)
		var visited: Dictionary = {}
		var libraries: Array[String] = []
		var source_scenes: Array[String] = []
		while not pending.is_empty():
			var resource_path: String = pending.pop_back()
			if visited.has(resource_path):
				continue
			visited[resource_path] = true
			if resource_path.begins_with(OUTPUT + "animations/") and resource_path.ends_with(".res"):
				libraries.append(resource_path)
			if resource_path.get_extension().to_lower() in ["glb", "gltf", "fbx", "dae"]:
				source_scenes.append(resource_path)
			for encoded: String in ResourceLoader.get_dependencies(resource_path):
				var dependency := ""
				for component: String in encoded.split("::"):
					if component.begins_with("res://"):
						dependency = component
						break
				if dependency.is_empty() and encoded.begins_with("uid://"):
					var uid := ResourceUID.text_to_id(encoded.get_slice("::", 0))
					if ResourceUID.has_id(uid):
						dependency = ResourceUID.get_id_path(uid)
				if dependency.begins_with("res://"):
					pending.append(dependency)
		libraries.sort()
		entry.animation_resources = libraries
		var dependencies: Array = visited.keys()
		dependencies.erase(str(entry.path))
		dependencies.sort()
		entry.resource_dependencies = dependencies
		source_scenes.sort()
		entry.source_scene_dependencies = source_scenes
		entry.compiled_sha256 = FileAccess.get_sha256(str(entry.path))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot record prepared actor animation ownership.")
		quit(1)
		return
	file.store_string(JSON.stringify(catalog, "\t") + "\n")
	file.close()
	print("PREPARED LIBRARY OWNERSHIP: %d actor records; existing scenes unchanged." % catalog.size())
	quit(0)

func _source_selections() -> Dictionary:
	var selections := {}
	for manifest in ["res://curated_runtime_assets.json", "res://visual_upgrade_manifest.json"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest))
		for category in ["characters", "enemies"]:
			for role in data.get("roles", {}).get(category, {}):
				var entry: Dictionary = data.roles[category][role]
				var path := str(entry.get("path", ""))
				if path.is_empty():
					continue
				selections[str(role) + "|" + path] = {"role": str(role), "path": path, "category": category}
	return selections

func _verify_existing_scenes() -> void:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/prepared_actors.json"))
	var selections := _source_selections()
	if not catalog is Dictionary or selections.is_empty() or catalog.size() != selections.size():
		_failed("Prepared actor handoff does not cover the current source selections.")
		quit(1)
		return
	var hashes := {}
	for key: String in selections:
		var entry: Variant = catalog.get(key)
		if not entry is Dictionary or entry.get("source") != selections[key].path or entry.get("role") != selections[key].role:
			_failed("Prepared actor handoff has a stale role or source: " + key)
			continue
		var path := str(entry.get("path", ""))
		if not path.begins_with(OUTPUT) or not path.ends_with(".scn") or path != path.simplify_path():
			_failed("Invalid prepared actor scene path: " + key)
			continue
		if not hashes.has(path):
			hashes[path] = FileAccess.get_sha256(path)
		if str(hashes[path]).is_empty() or hashes[path] != entry.get("compiled_sha256") or not ResourceLoader.exists(entry.source, "PackedScene"):
			_failed("Prepared actor scene or source is missing or stale: " + key)
	if not failed:
		print("VERIFIED PREPARED ACTORS: %d exact scenes for %d roles." % [hashes.size(), catalog.size()])
	quit(1 if failed else 0)

func _compile() -> void:
	helper = Helper.new()
	helper.building_prepared_assets = true
	root.add_child(helper)
	presets.load("res://export_presets.cfg")
	var previous: Dictionary = {}
	if FileAccess.file_exists("res://data/prepared_actors.json"):
		previous = JSON.parse_string(FileAccess.get_file_as_string("res://data/prepared_actors.json"))
	var selections := _source_selections()
	var face_only := "--face-repair-only" in OS.get_cmdline_user_args()
	var face_sources := {}
	if face_only:
		var designs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/design_pack_assets.json"))
		for record: Dictionary in designs.get("assets", {}).values():
			if record.has("face_repair_certificate"):
				face_sources[str(record.path)] = true
		if face_sources.is_empty():
			_failed("Face repair compilation requires explicit source certificates.")
			quit(1)
			return
	for key in selections:
		var entry: Dictionary = selections[key]
		var source: String = entry.path
		var role: String = entry.role
		if face_only and not face_sources.has(source):
			var retained: Variant = previous.get(key)
			if not retained is Dictionary or retained.get("source") != source or retained.get("role") != role \
					or not retained.get("path") is String or not FileAccess.file_exists(retained.path) \
					or FileAccess.get_sha256(retained.path) != retained.get("compiled_sha256"):
				_failed("Unchanged prepared actor cannot be retained: " + str(key))
				continue
			entries[key] = retained.duplicate(true)
			continue
		var owner := _owner(source, str(entry.category))
		var normalized := source.to_lower()
		var hair: String = helper._hair_path_for_role(role, true) if normalized.ends_with("/male_peasant.gltf") else ""
		var assembly_key := source + "|" + owner + "|" + str(hair)
		var variant_safe := normalized.contains("_atlas.gltf") or normalized.ends_with("male_ranger_runtime.gltf") or normalized.begins_with("res://assets_external/design_pack_v1/")
		if templates.has(assembly_key):
			entries[key] = {"path": templates[assembly_key], "source": source, "source_sha256": FileAccess.get_sha256(source), "role": role, "owner": owner, "variant_safe": variant_safe, "material_bindings": template_materials[assembly_key]}
			if template_creature_ambient.has(assembly_key):
				entries[key]["authored_creature_ambient"] = template_creature_ambient[assembly_key]
			continue
		var source_resource := load(source) as PackedScene
		if source_resource == null:
			_failed("Required actor source cannot be compiled: %s" % source)
			continue
		var visual := source_resource.instantiate() as Node3D
		visual = helper._compose_player_body(visual, source, role)
		if source.get_file() == "Male_Ranger_Runtime.gltf" and not NativeFace.compile(visual):
			_failed("Required Ranger facial anatomy cannot be compiled: %s" % key)
			visual.free()
			continue
		visual.name = role
		var source_transform := visual.transform
		var source_bounds: AABB = helper._calculate_node_bounds(visual)
		helper._prepare_spawned_asset(visual, source, role, entry.category)
		# Authored replacements carry an explicit retained rig frame. Cache that
		# frame rather than recalculating scale from new cosmetic geometry.
		source_bounds = visual.get_meta("prepared_source_bounds", source_bounds)
		if not bool(visual.get_meta("character_material_bindings_valid", false)):
			_failed("Required actor material/texture failed: %s: %s" % [key, str(visual.get_meta("character_material_errors", []))])
			visual.free()
			continue
		var facial_controls := _compile_face_bindings(visual, source)
		if failed:
			visual.free()
			continue
		_save_libraries()
		visual.set_meta("prepared_actor_source", source)
		visual.set_meta("prepared_actor_role", role)
		visual.set_meta("prepared_facial_controls", facial_controls)
		visual.set_meta("prepared_source_transform", source_transform)
		visual.set_meta("prepared_source_bounds", source_bounds)
		var creature_ambient: Dictionary = CreatureAmbientContract.apply_to(visual, source)
		if creature_ambient.has("error"):
			_failed(str(creature_ambient.error))
			visual.free()
			continue
		NodeManifest.compile(visual)
		_own(visual, visual)
		var packed := PackedScene.new()
		if packed.pack(visual) != OK:
			_failed("Cannot serialize actor: %s" % key)
			visual.free()
			continue
		if bool(creature_ambient.get("verified", false)):
			var proof := packed.instantiate()
			var persisted := bool(proof.get_meta("authored_creature_ambient", false)) and str(proof.get_meta("authored_creature_ambient_source_sha256", "")) == str(creature_ambient.source_sha256)
			persisted = persisted and proof.get_meta("authored_creature_ambient_morphs", []) == creature_ambient.get("morph_bindings", [])
			persisted = persisted and proof.get_meta("authored_creature_water_probes", []) == creature_ambient.get("water_probes", [])
			proof.free()
			if not persisted:
				_failed("Verified creature metadata did not survive PackedScene compilation: " + source)
				visual.free()
				continue
		var directory := OUTPUT + owner + "/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		var path := directory + assembly_key.sha256_text().substr(0, 24) + ".scn"
		if ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS) != OK:
			_failed("Cannot save actor: %s" % key)
		templates[assembly_key] = path
		template_materials[assembly_key] = MaterialBindings.descriptors(visual)
		if bool(creature_ambient.get("verified", false)):
			template_creature_ambient[assembly_key] = creature_ambient
		entries[key] = {"path": path, "source": source, "source_sha256": FileAccess.get_sha256(source), "role": role, "owner": owner, "variant_safe": variant_safe, "material_bindings": template_materials[assembly_key]}
		if template_creature_ambient.has(assembly_key):
			entries[key]["authored_creature_ambient"] = template_creature_ambient[assembly_key]
		visual.free()
	if failed:
		helper.clear_runtime_caches()
		helper.free()
		quit(1)
		return
	var file := FileAccess.open("res://data/prepared_actors.json", FileAccess.WRITE)
	if file == null:
		_failed("Cannot write prepared actor catalog")
	else:
		file.store_string(JSON.stringify(entries, "\t") + "\n")
		file.close()
	var live: Dictionary = {}
	for entry in entries.values():
		live[str(entry.path)] = true
	# Retire only obsolete outputs named by this compiler's previous catalog.
	for entry in previous.values():
		var path := str(entry.get("path", ""))
		if path.begins_with(OUTPUT) and path.ends_with(".scn") and not live.has(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	helper.clear_runtime_caches()
	helper.free()
	if failed:
		quit(1)
	else:
		_refresh_library_ownership()

func _save_libraries() -> void:
	var directory := OUTPUT + "animations/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for source: Resource in helper.prepared_animation_libraries:
		var variants: Dictionary = helper.prepared_animation_libraries[source]
		for binding in variants:
			var library: AnimationLibrary = variants[binding]
			if library.resource_path.begins_with(directory):
				continue
			var path := directory + (source.resource_path + "|" + str(binding)).sha256_text().substr(0, 24) + ".res"
			if ResourceSaver.save(library, path, ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_CHANGE_PATH) != OK:
				_failed("Cannot save animation binding: %s" % path)

func _compile_face_bindings(visual: Node3D, source: String) -> Dictionary:
	var result: Dictionary = {}
	for node in visual.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		for bone in range(skeleton.get_bone_count()):
			var name := skeleton.get_bone_name(bone)
			if name.begins_with("Face_"):
				result[name] = {"skeleton":str(visual.get_path_to(skeleton)), "bone":name}
	var requires_face := source.get_file() in FACIAL_ASSEMBLIES or source.begins_with("res://assets_external/design_pack_v1/humans/")
	if requires_face and result.size() != 11:
		_failed("Required CAST facial rig missing: %s; controls=%s" % [source, str(result.keys())])
	return result

func _own(node: Node, scene: Node) -> void:
	node.scene_file_path = ""
	if node != scene:
		node.owner = scene
	for child in node.get_children():
		_own(child, scene)

func _owner(source: String, category: String) -> String:
	if source.begins_with("res://assets_external/design_pack_v1/"):
		var designs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/design_pack_assets.json"))
		for record: Dictionary in designs.get("assets", {}).values():
			if str(record.path) == source:
				return str(record.owner)
	var relative := source.trim_prefix("res://")
	for section in presets.get_sections():
		if str(presets.get_value(section, "name", "")) != "Runtime Pack Opening":
			continue
		for excluded in str(presets.get_value(section, "exclude_filter", "")).split(",", false):
			if relative.match(excluded):
				return "monsters" if category == "enemies" else "characters"
		for selected in presets.get_value(section, "export_files", PackedStringArray()):
			if str(selected) == source:
				return "opening"
		for included in str(presets.get_value(section, "include_filter", "")).split(",", false):
			if relative.match(included):
				return "opening"
	return "monsters" if category == "enemies" else "characters"

func _failed(reason: String) -> void:
	failed = true
	push_error(reason)
