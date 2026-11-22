extends SceneTree

const Bank = preload("res://scripts/prepared_audio_bank.gd")
const Audio = preload("res://scripts/audio_manager.gd")

func _initialize() -> void:
	if "--approved-arrangements" in OS.get_cmdline_user_args():
		_compile_arrangements()
		return
	seed(41021)
	var audio := Audio.new()
	if "use_prepared_audio" in audio:
		audio.use_prepared_audio = false
	audio._build_library()
	audio._build_music_library()
	var bank := Bank.new()
	bank.cues = audio.sounds.duplicate()
	bank.music = audio.music.duplicate()
	for zone in ["greyfen", "wychwood", "deep_wood", "marsh_crossing", "cemetery", "chapel", "vargan_approach", "vargan_court", "record_hall", "undercroft", "hart_glade", "default"]:
		bank.ambience[zone] = audio._build_ambient_stream(zone)
	var path := "res://assets/audio/prepared_bank.res"
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error == OK:
		error = ResourceSaver.save(bank, path, ResourceSaver.FLAG_COMPRESS)
	print("PREPARED AUDIO BUILD: %s cues=%d music=%d ambience=%d" % [error_string(error), bank.cues.size(), bank.music.size(), bank.ambience.size()])
	audio.free()
	quit(0 if error == OK else 1)

func _compile_arrangements() -> void:
	var path := "res://assets_external/audio/story_score/arrangements/arrangements.json"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not bool(manifest.get("production_replacement_authorized", false)):
		push_error("Production arrangements do not have replacement authorization.")
		quit(1)
		return
	var states := {"greyfen_belonging":"greyfen_explore", "road_uncertainty":"wychwood_tension", "hold_the_road":"ghoulkin_combat"}
	var catalog_path := "res://data/prepared_audio.json"
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	for theme: String in states:
		var definition: Dictionary = manifest.tracks[theme]
		var stream := load(str(definition.path)) as AudioStream
		if stream == null:
			push_error("Required approved arrangement cannot compile: " + str(definition.path))
			quit(1)
			return
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(definition.frames)
		var owner := "opening" if theme == "greyfen_belonging" else "adjacent"
		var output := "res://assets/audio/prepared/%s/music_%s.res" % [owner, str(states[theme])]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
		var error := ResourceSaver.save(stream, output, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			push_error("Cannot serialize arrangement %s: %s" % [output, error_string(error)])
			quit(1)
			return
		print("PREPARED ARRANGEMENT: %s -> %s" % [theme, output])
		catalog.music[str(states[theme])] = output
	var file := FileAccess.open(catalog_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write approved music ownership.")
		quit(1)
		return
	file.store_string(JSON.stringify(catalog, "\t") + "\n")
	file.close()
	quit(0)
