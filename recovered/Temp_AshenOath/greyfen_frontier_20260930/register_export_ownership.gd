extends SceneTree

func _initialize() -> void:
	var presets := ConfigFile.new()
	if presets.load("res://export_presets.cfg") != OK:
		quit(1)
		return
	var opening_files := [
		"assets_external/environment/forest/GreyfenFrontier_Authored.res",
		"assets_external/environment/village/GreyfenFrontages_Authored.res",
		"assets_external/environment/props/GreyfenForgeWork_Authored.res",
	]
	var monster_files := [
		"assets_external/characters_universal/runtime/Ghoulkin_Authored_Atlas.gltf",
		"assets_external/characters_universal/runtime/Ghoulkin_Authored_Atlas.bin",
		"assets_external/characters_universal/runtime/Ghoulkin_Authored_Atlas.png",
	]
	for id in [0, 1, 2, 6]:
		var section := "preset.%d" % id
		var entries := str(presets.get_value(section, "include_filter", "")).split(",")
		var additions: Array = monster_files if id == 6 else opening_files
		for path in additions:
			if not FileAccess.file_exists("res://" + path):
				push_error("Missing required runtime asset: " + path)
				quit(1)
				return
			if not path in entries:
				entries.append(path)
		presets.set_value(section, "include_filter", ",".join(entries))
	if presets.save("res://export_presets.cfg") != OK:
		quit(1)
		return
	print("Opening art / grounded Ghoulkin export ownership registered; no export performed")
	quit(0)
