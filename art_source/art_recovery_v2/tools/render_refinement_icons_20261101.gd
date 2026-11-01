extends SceneTree

func _initialize() -> void:
	var output := "D:/Projects/AshenOath/art_source/art_recovery_v2/evidence/refinement_20261101/icons"
	DirAccess.make_dir_recursive_absolute(output)
	for file in DirAccess.get_files_at("res://assets/icons"):
		if not file.ends_with(".svg"): continue
		var picture := Image.new()
		var error := picture.load_svg_from_string(FileAccess.get_file_as_string("res://assets/icons/" + file))
		if error != OK or picture.is_empty():
			push_error("Cannot render inventory icon: " + file)
			quit(1)
			return
		picture.save_png(output.path_join(file.get_basename() + ".png"))
		picture.resize(40, 40, Image.INTERPOLATE_LANCZOS)
		picture.save_png(output.path_join(file.get_basename() + "_40px.png"))
	print("Rendered seven vector assets at authored and hotbar sizes")
	quit(0)
