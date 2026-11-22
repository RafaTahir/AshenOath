extends SceneTree

func _initialize() -> void:
	var presets := ConfigFile.new()
	if presets.load("res://export_presets.cfg") != OK:
		quit(1)
		return
	var path := "assets_external/environment/forest/HartWoodland_Authored.res"
	if not FileAccess.file_exists("res://" + path):
		quit(1)
		return
	for id in [0, 1, 4]:
		var section := "preset.%d" % id
		var entries := str(presets.get_value(section, "include_filter", "")).split(",")
		if not path in entries:
			entries.append(path)
		presets.set_value(section, "include_filter", ",".join(entries))
	if presets.save("res://export_presets.cfg") != OK:
		quit(1)
		return
	print("Hart woodland campaign export ownership registered; no export performed")
	quit(0)
