extends SceneTree

## Asset compilation only. No game world, animation playback, camera or QA run.
const Helper = preload("res://scripts/asset_spawn_helper.gd")
const NodeManifest = preload("res://scripts/character_node_manifest.gd")
const MaterialBindings = preload("res://scripts/character_material_bindings.gd")
const OUTPUT := "res://assets_external/characters_prepared/"
var helper: Node
var presets := ConfigFile.new()
var entries: Dictionary = {}
var templates: Dictionary = {}
var template_materials: Dictionary = {}
var failed := false
const FACIAL_SAMPLES := ["Anwen_A_Set_Atlas.gltf", "Villager_Male_Atlas.gltf", "Villager_Worker_Atlas.gltf"]

func _initialize() -> void:
	call_deferred("_compile")

func _compile() -> void:
	helper = Helper.new()
	helper.building_prepared_assets = true
	root.add_child(helper)
	presets.load("res://export_presets.cfg")
	var selections := {}
	var previous: Dictionary = {}
	if FileAccess.file_exists("res://data/prepared_actors.json"):
		previous = JSON.parse_string(FileAccess.get_file_as_string("res://data/prepared_actors.json"))
	for manifest in ["res://curated_runtime_assets.json", "res://visual_upgrade_manifest.json"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest))
		for category in ["characters", "enemies"]:
			for role in data.get("roles", {}).get(category, {}):
				var entry: Dictionary = data.roles[category][role]
				var path := str(entry.get("path", ""))
				if path.is_empty():
					continue
				selections[str(role) + "|" + path] = {"role": str(role), "path": path, "category": category}
	for key in selections:
		var entry: Dictionary = selections[key]
		var source: String = entry.path
		var role: String = entry.role
		var owner := _owner(source, str(entry.category))
		var normalized := source.to_lower()
		var hair: String = helper._hair_path_for_role(role, true) if normalized.ends_with("/male_peasant.gltf") else ""
		var assembly_key := source + "|" + owner + "|" + str(hair)
		var variant_safe := normalized.contains("_atlas.gltf") or normalized.ends_with("male_ranger_runtime.gltf")
		if templates.has(assembly_key):
			entries[key] = {"path": templates[assembly_key], "source": source, "role": role, "owner": owner, "variant_safe": variant_safe, "material_bindings": template_materials[assembly_key]}
			continue
		var source_resource := load(source) as PackedScene
		if source_resource == null:
			_failed("Required actor source cannot be compiled: %s" % source)
			continue
		var visual := source_resource.instantiate() as Node3D
		visual = helper._compose_player_body(visual, source, role)
		visual.name = role
		var source_transform := visual.transform
		var source_bounds: AABB = helper._calculate_node_bounds(visual)
		helper._prepare_spawned_asset(visual, source, role, entry.category)
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
		NodeManifest.compile(visual)
		_own(visual, visual)
		var packed := PackedScene.new()
		if packed.pack(visual) != OK:
			_failed("Cannot serialize actor: %s" % key)
			visual.free()
			continue
		var directory := OUTPUT + owner + "/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		var path := directory + assembly_key.sha256_text().substr(0, 24) + ".scn"
		if ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS) != OK:
			_failed("Cannot save actor: %s" % key)
		templates[assembly_key] = path
		template_materials[assembly_key] = MaterialBindings.descriptors(visual)
		entries[key] = {"path": path, "source": source, "role": role, "owner": owner, "variant_safe": variant_safe, "material_bindings": template_materials[assembly_key]}
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
	quit(1 if failed else 0)

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
	if source.get_file() in FACIAL_SAMPLES and result.size() != 11:
		_failed("Required CAST facial rig missing: %s; controls=%s" % [source, str(result.keys())])
	return result

func _own(node: Node, scene: Node) -> void:
	node.scene_file_path = ""
	if node != scene:
		node.owner = scene
	for child in node.get_children():
		_own(child, scene)

func _owner(source: String, category: String) -> String:
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
