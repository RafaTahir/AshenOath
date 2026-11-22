extends SceneTree

# FileAccess only: no Script/scene instantiation and no models are loaded.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[args.find("--output") + 1]
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("D:/Temp/AshenOath/h1_retry_pack_source_audit/config.json"))
	var records := []
	DirAccess.make_dir_recursive_absolute(output)
	for relative: String in config.scripts:
		var path := "res://" + relative
		var remap := FileAccess.get_file_as_string(path + ".remap")
		var compiled := path + "c"
		assert(remap.contains(compiled), "The exported source must remap to its retained compiled script")
		assert(FileAccess.file_exists(compiled), "Missing compiled script: " + compiled)
		var target := output.path_join(relative + "c")
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		FileAccess.open(target,FileAccess.WRITE).store_buffer(FileAccess.get_file_as_bytes(compiled))
		records.append({"path":path,"remap":remap,"compiled":compiled,"compiled_sha256":FileAccess.get_sha256(compiled)})
	FileAccess.open(output.path_join("resources.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"\t",true)+"\n")
	print("FRESH H1 PACK SCRIPT EXTRACTION: PASS; seven compiled resources, no objects instantiated")
	quit()
