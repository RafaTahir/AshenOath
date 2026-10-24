extends SceneTree

## Lossless asset compilation: existing streams, formats and loop points stay intact.
const OUTPUT := "res://assets/audio/prepared/"
const INDEX := "res://data/prepared_audio.json"
const OPENING_MUSIC := ["greyfen_explore", "shrine_anwen", "wychwood_tension", "ghoulkin_combat", "return_report", "boss_bell_eater"]
const OPENING_AMBIENCE := ["greyfen", "wychwood", "cemetery", "chapel", "default"]

func _initialize() -> void:
	if "--curated-opening" in OS.get_cmdline_user_args():
		var existing: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
		if not existing is Dictionary:
			quit(1)
			return
		var result := _apply_curated_opening(existing)
		quit(0 if result == OK else 1)
		return
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
	var curated_error := _apply_curated_opening(index)
	if curated_error != OK:
		quit(1)
		return
	print("Prepared audio split: %d cues, %d music, %d ambience; no re-encoding." % [index.cues.size(), index.music.size(), index.ambience.size()])
	quit(0)

func _apply_curated_opening(index: Dictionary) -> Error:
	var samples := ProjectSettings.globalize_path("res://../../plans/living-road/music-samples/").simplify_path()
	var music := {"greyfen_explore":"greyfen_belonging", "wychwood_tension":"road_uncertainty", "ghoulkin_combat":"hold_the_road"}
	var cues := {"flesh_contact":"authored/flesh_cut", "arrow_contact":"authored/arrow_pierce", "wood_contact":"authored/forest_twigs", "stone_contact":"rpg/footstep00", "foliage_contact":"rpg/cloth1"}
	for category: String in ["music", "cues"]:
		var tracks: Dictionary = music if category == "music" else cues
		for id: String in tracks:
			var source := samples.path_join(str(tracks[id]) + ".ogg") if category == "music" else ProjectSettings.globalize_path("res://assets_external/audio/" + str(tracks[id]) + ".ogg")
			if not FileAccess.file_exists(source):
				push_error("Curated audio source missing: " + source)
				return ERR_FILE_NOT_FOUND
			var stream := AudioStreamOggVorbis.load_from_file(source)
			if stream == null: return ERR_FILE_CORRUPT
			stream.loop = category == "music"
			var path := OUTPUT + "opening/" + category + "_" + id + ".res"
			var error := ResourceSaver.save(stream, path, ResourceSaver.FLAG_COMPRESS)
			if error != OK: return error
			index[category][id] = path
	var file := FileAccess.open(INDEX, FileAccess.WRITE)
	if file == null:
		return ERR_FILE_CANT_WRITE
	file.store_string(JSON.stringify(index, "\t") + "\n")
	file.close()
	print("Curated opening audio compiled: 3 approved-direction music themes, 5 material cues. Listening/runtime acceptance remains user-owned.")
	return OK
