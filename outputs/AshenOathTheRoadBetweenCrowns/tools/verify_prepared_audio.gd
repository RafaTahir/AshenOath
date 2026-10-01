extends SceneTree

const Audio = preload("res://scripts/audio_manager.gd")
var failures: Array[String] = []

func _initialize() -> void:
	# GDScript preloads are not exposed by get_dependencies() on this script.
	# This checks source resolution only; packed inclusion requires packed startup.
	_check(Audio.PREPARED_AUDIO.resource_path == "res://assets/audio/prepared_bank.res", "Prepared bank resolved to an unexpected source")
	seed(41021)
	var source := Audio.new()
	source.use_prepared_audio = false
	source._build_library()
	source._build_music_library()
	var runtime := Audio.new()
	var started := Time.get_ticks_usec()
	runtime._build_menu_library()
	runtime._build_library()
	runtime._build_music_library()
	print("PREPARED AUDIO REGISTRATION MS: %.3f" % ((Time.get_ticks_usec() - started) / 1000.0))
	_compare_library(source.sounds, runtime.sounds)
	_compare_library(source.music, runtime.music)
	for zone in Audio.PREPARED_AUDIO.ambience:
		_compare(source._build_ambient_stream(zone), runtime._build_ambient_stream(zone), "ambience:" + zone)
	_compare(runtime._build_ambient_stream("unlisted_zone"), Audio.PREPARED_AUDIO.ambience["default"], "default ambience")
	var survivor: AudioStreamWAV = runtime.sounds["heavy"]
	source.free()
	runtime.free()
	_check(not survivor.data.is_empty(), "Audio resource did not survive consumer deletion")
	print("PREPARED AUDIO: %s - PCM, sample rate, format, stereo, loops, coverage and lifetime" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _compare_library(expected: Dictionary, actual: Dictionary) -> void:
	_check(expected.size() == actual.size(), "Audio cue count changed")
	for id in expected:
		_check(actual.has(id), "Missing cue: " + id)
		if actual.has(id):
			_compare(expected[id], actual[id], id)

func _compare(expected: AudioStreamWAV, actual: AudioStreamWAV, id: String) -> void:
	_check(expected.data == actual.data and expected.mix_rate == actual.mix_rate and expected.format == actual.format and expected.stereo == actual.stereo and expected.loop_mode == actual.loop_mode and expected.loop_begin == actual.loop_begin and expected.loop_end == actual.loop_end, "Audio changed: " + id)

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
