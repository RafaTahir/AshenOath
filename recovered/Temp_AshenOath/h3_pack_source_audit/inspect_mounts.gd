extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var config_path := args[args.find("--config") + 1]
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	var output := config_path.get_base_dir().path_join("mounted_hashes.json")
	var paths: Array = []
	for relative: String in config.scripts:
		paths.append(relative + "c")
	paths.append_array(config.get("resources", []))
	var stages := []
	var baseline := {}
	for path: String in paths:
		assert(FileAccess.file_exists("res://" + path), "Root resource is missing: " + path)
		baseline[path] = FileAccess.get_sha256("res://" + path)
	stages.append({"mount":"actual_root_index", "hashes":baseline.duplicate()})
	for id: String in config.packs:
		var pack: String = str(config.raw_packs).path_join(id + ".pck")
		assert(ProjectSettings.load_resource_pack(pack), "Cannot mount retained raw pack " + id)
		var hashes := {}
		for path: String in paths:
			hashes[path] = FileAccess.get_sha256("res://" + path)
		stages.append({"mount":id, "hashes":hashes.duplicate(), "matches_actual_root":hashes == baseline})
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(stages,"\t",true)+"\n")
	print("MOUNTED RESOURCE HASH AUDIT: ", stages.size(), " map-only stages; output=", output)
	quit()
