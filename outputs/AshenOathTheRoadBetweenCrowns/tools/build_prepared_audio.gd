extends SceneTree

const Bank = preload("res://scripts/prepared_audio_bank.gd")
const Audio = preload("res://scripts/audio_manager.gd")

func _initialize() -> void:
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
