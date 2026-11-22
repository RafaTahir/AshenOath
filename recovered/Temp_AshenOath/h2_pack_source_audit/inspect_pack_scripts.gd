extends SceneTree

# FileAccess only; no Script/scene instantiation or models.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var config_path := args[args.find("--config") + 1]
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	var output := config_path.get_base_dir().path_join("root")
	var records := []
	for relative: String in config.scripts:
		var path := "res://" + relative
		var remap := FileAccess.get_file_as_string(path + ".remap")
		var compiled := path + "c"
		assert(remap.contains(compiled), "Expected exported compiled-script remap: " + path)
		assert(FileAccess.file_exists(compiled), "Missing compiled script: " + compiled)
		var target := output.path_join(relative + "c")
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		FileAccess.open(target, FileAccess.WRITE).store_buffer(FileAccess.get_file_as_bytes(compiled))
		records.append({"path":path, "remap":remap, "compiled":compiled, "compiled_sha256":FileAccess.get_sha256(compiled)})
	for relative: String in config.get("resources", []):
		var target := output.path_join(relative)
		assert(FileAccess.file_exists("res://" + relative), "Missing configured data resource")
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		FileAccess.open(target, FileAccess.WRITE).store_buffer(FileAccess.get_file_as_bytes("res://" + relative))
	FileAccess.open(output.path_join("resources.json"), FileAccess.WRITE).store_string(JSON.stringify(records,"\t",true)+"\n")
	print("PACK SCRIPT EXTRACTION: PASS; configured resources only, no objects instantiated")
	quit()
