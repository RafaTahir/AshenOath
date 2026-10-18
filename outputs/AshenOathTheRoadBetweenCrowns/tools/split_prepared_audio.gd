extends SceneTree

## Lossless asset compilation: existing streams, formats and loop points stay intact.
const OUTPUT := "res://assets/audio/prepared/"
const INDEX := "res://data/prepared_audio.json"
const OPENING_MUSIC := ["greyfen_explore", "shrine_anwen", "wychwood_tension", "ghoulkin_combat", "return_report", "boss_bell_eater"]
const OPENING_AMBIENCE := ["greyfen", "wychwood", "cemetery", "chapel", "default"]

func _initialize() -> void:
	var bank := load("res://assets/audio/prepared_bank.res")
	if bank == null:
		push_error("Prepared audio source bank is required.")
		quit(1)
		return
	var index := {"schema_version": 1, "cues": {}, "music": {}, "ambience": {}}
	for category in ["cues", "music", "ambience"]:
		var streams: Dictionary = bank.get(category)
		for id: String in streams:
			var owner := "opening"
			if category == "cues":
				owner = "menu" if id in ["ui", "menu_hover", "menu_click"] else "opening"
			elif category == "music":
				owner = "menu" if id == "main_menu" else ("opening" if id in OPENING_MUSIC else "campaign")
			else:
				owner = "opening" if id in OPENING_AMBIENCE else "campaign"
			var path: String = OUTPUT + owner + "/" + category + "_" + id + ".res"
			var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
			if error == OK:
				error = ResourceSaver.save(streams[id], path, ResourceSaver.FLAG_COMPRESS)
			if error != OK:
				push_error("Audio compilation failed for %s: %s" % [path, error_string(error)])
				quit(1)
				return
			index[category][id] = path
	var file := FileAccess.open(INDEX, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(index, "\t") + "\n")
	file.close()
	print("Prepared audio split: %d cues, %d music, %d ambience; no re-encoding." % [index.cues.size(), index.music.size(), index.ambience.size()])
	quit(0)
