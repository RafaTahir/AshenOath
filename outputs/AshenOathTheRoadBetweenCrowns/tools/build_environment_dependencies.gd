extends SceneTree

const PREFIX := "res://assets_external/environment/"
const OUTPUT := "res://data/environment_material_dependencies.json"
var visited: Dictionary = {}
var textures: Dictionary = {}
var errors: Array[String] = []

func _initialize() -> void:
	var config := ConfigFile.new()
	if config.load("res://export_presets.cfg") != OK:
		quit(1)
		return
	var inventory: Array[String] = []
	_inventory(PREFIX, inventory)
	for section in config.get_sections():
		var name: String = config.get_value(section, "name", "")
		if name not in ["Runtime Pack Opening", "Runtime Pack Adjacent", "Runtime Pack Campaign"]:
			continue
		var owner := name.trim_prefix("Runtime Pack ").to_lower()
		var selections: PackedStringArray = config.get_value(section, "export_files", PackedStringArray())
		var includes := str(config.get_value(section, "include_filter", "")).split(",", false)
		var excludes := str(config.get_value(section, "exclude_filter", "")).split(",", false)
		for path in inventory:
			var relative := path.trim_prefix("res://")
			if _matches(relative, excludes):
				continue
			if path in selections or _matches(relative, includes):
				_collect(path, owner)
	var records: Dictionary = {}
	var paths := textures.keys()
	paths.sort()
	for path: String in paths:
		var consumers: Array = textures[path]
		consumers.sort()
		var owner := "opening" if "opening" in consumers else ("adjacent" if "adjacent" in consumers else "campaign")
		records[path] = {"owner": owner, "consumers": consumers}
	_retire_previous_selections(config, records)
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"schema_version": 1, "textures": records}, "  ", true) + "\n")
	file.close()
	print("ENVIRONMENT DEPENDENCIES: %d textures from selected environment resources" % records.size())
	quit()

func _retire_previous_selections(config: ConfigFile, records: Dictionary) -> void:
	if not errors.is_empty() or not FileAccess.file_exists(OUTPUT):
		return
	var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT))
	if not previous is Dictionary or not previous.get("textures") is Dictionary:
		errors.append("Cannot reconcile prior environment dependency catalog: " + OUTPUT)
		return
	var changed := false
	for path: String in previous["textures"]:
		if records.has(path):
			continue
		# Only retire exact entries generated for previously cataloged textures;
		# unrelated authored selections and wildcard policies remain untouched.
		for section in config.get_sections():
			if not config.has_section_key(section, "name"):
				continue
			var selections: PackedStringArray = config.get_value(section, "export_files", PackedStringArray())
			if path in selections:
				selections.remove_at(selections.find(path))
				config.set_value(section, "export_files", selections)
				changed = true
			for field in ["include_filter", "exclude_filter"]:
				var patterns := str(config.get_value(section, field, "")).split(",", false)
				var relative := path.trim_prefix("res://")
				if relative in patterns:
					patterns.remove_at(patterns.find(relative))
					config.set_value(section, field, ",".join(patterns))
					changed = true
	if changed and config.save("res://export_presets.cfg") != OK:
		errors.append("Could not retire obsolete generated environment selections")

func _inventory(directory: String, paths: Array[String]) -> void:
	for name in DirAccess.get_directories_at(directory):
		_inventory(directory.path_join(name), paths)
	for name in DirAccess.get_files_at(directory):
		if name.get_extension() in ["gltf", "glb", "obj", "fbx", "res", "tres", "scn", "tscn"]:
			paths.append(directory.path_join(name))

func _matches(path: String, patterns: PackedStringArray) -> bool:
	for pattern in patterns:
		if path.match(pattern):
			return true
	return false

func _collect(path: String, owner: String) -> void:
	var key := owner + ":" + path
	if visited.has(key):
		return
	visited[key] = true
	if path.get_extension() == "obj":
		_collect_obj_materials(path, owner)
	if not ResourceLoader.exists(path):
		errors.append("Environment dependency missing: %s (consumer %s)" % [path, owner])
		return
	if path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "svg"]:
		# Actor atlases and quality-dependent PBR channels retain their existing
		# catalog owners; this ledger closes imported environment kit materials.
		if not path.begins_with(PREFIX):
			return
		var consumers: Array = textures.get(path, [])
		if owner not in consumers:
			consumers.append(owner)
		textures[path] = consumers
		return
	var dependency_source := path
	if FileAccess.file_exists(path + ".import"):
		var remap := ConfigFile.new()
		if remap.load(path + ".import") != OK:
			errors.append("Cannot read environment import: " + path)
			return
		dependency_source = str(remap.get_value("remap", "path", path))
	for dependency in ResourceLoader.get_dependencies(dependency_source):
		# Godot includes UID/type fields when available; the final field is the
		# retained resource path, which remains portable across native/Web imports.
		var dependency_path := dependency.get_slice("::", dependency.get_slice_count("::") - 1)
		if dependency_path.begins_with("res://"):
			_collect(dependency_path, owner)

func _collect_obj_materials(path: String, owner: String) -> void:
	# Include-only OBJ sources can load their MTL at runtime. Their import's
	# dependency list does not describe those source-material texture requests.
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Cannot read selected environment OBJ: " + path)
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if not line.begins_with("mtllib "):
			continue
		var material_path := path.get_base_dir().path_join(line.trim_prefix("mtllib ").strip_edges().trim_prefix('"').trim_suffix('"'))
		var material := FileAccess.open(material_path, FileAccess.READ)
		if material == null:
			errors.append("Environment material library missing: " + material_path)
			continue
		while not material.eof_reached():
			var entry := material.get_line().strip_edges()
			var command := entry.get_slice(" ", 0)
			if not command.begins_with("map_") and command != "bump":
				continue
			var texture := entry.substr(command.length()).strip_edges()
			if texture.begins_with("-bm "):
				texture = texture.trim_prefix("-bm ").strip_edges()
				texture = texture.substr(texture.get_slice(" ", 0).length()).strip_edges()
			if texture.begins_with("-"):
				errors.append("Unsupported texture-map options in %s: %s" % [material_path, entry])
				continue
			_collect(material_path.get_base_dir().path_join(texture.trim_prefix('"').trim_suffix('"')), owner)
		material.close()
	file.close()
