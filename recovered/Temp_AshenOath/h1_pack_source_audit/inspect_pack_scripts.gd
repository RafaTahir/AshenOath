extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[args.find("--output") + 1]
	var records := []
	var method_names := []
	for method: Dictionary in ClassDB.class_get_method_list("GDScript", true):
		method_names.append(str(method.name))
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("gdscript_methods.json"),FileAccess.WRITE).store_string(JSON.stringify(method_names))
	for relative: String in ["scripts/mobile_touch_controls.gd", "scripts/input_router.gd", "scripts/player_controller.gd", "scripts/hud/hud_input.gd", "scripts/hud/hud_lifecycle.gd", "scripts/systems/hud_coordinator.gd"]:
		var path := "res://" + relative
		var direct := FileAccess.file_exists(path)
		var source := FileAccess.get_file_as_string(path) if direct else ""
		var remap := FileAccess.get_file_as_string(path + ".remap") if FileAccess.file_exists(path + ".remap") else ""
		var script = ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_IGNORE)
		var retained := str(script.get_source_code()) if script is Script else ""
		var record := {"path":path,"direct_exists":direct,"direct_sha256":FileAccess.get_sha256(path) if direct else "",
			"direct_length":source.length(),"remap":remap,"loaded":script != null,"script_source_length":retained.length(),
			"script_source_sha256":retained.sha256_text() if retained != "" else ""}
		records.append(record)
		if FileAccess.file_exists(path + "c"):
			var target := output.path_join(relative + "c")
			DirAccess.make_dir_recursive_absolute(target.get_base_dir())
			FileAccess.open(target,FileAccess.WRITE).store_buffer(FileAccess.get_file_as_bytes(path + "c"))
		if source != "":
			var target := output.path_join(relative)
			DirAccess.make_dir_recursive_absolute(target.get_base_dir())
			FileAccess.open(target,FileAccess.WRITE).store_string(source)
		if retained != "":
			var target := output.path_join("loaded").path_join(relative)
			DirAccess.make_dir_recursive_absolute(target.get_base_dir())
			FileAccess.open(target,FileAccess.WRITE).store_string(retained)
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("resources.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"\t",true)+"\n")
	print("H1 PACK SOURCE AUDIT: resource-only complete; output=",output)
	quit()
