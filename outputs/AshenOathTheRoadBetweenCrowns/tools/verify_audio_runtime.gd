extends SceneTree

const AudioManager = preload("res://scripts/audio_manager.gd")

func _initialize() -> void:
	var audio = AudioManager.new()
	root.add_child(audio)
	await process_frame
	_assert(audio.has_method("play_voice"), "AudioManager is missing play_voice")
	_assert(audio.has_method("play_voice_sequence"), "AudioManager is missing play_voice_sequence")
	_assert(audio.has_method("stop_voice"), "AudioManager is missing stop_voice")
	_assert(audio.has_method("set_music_state"), "AudioManager is missing set_music_state")
	_assert(audio.has_method("play_music_cue"), "AudioManager is missing play_music_cue")
	_assert(audio.has_voice("voice_sister_anwen_test"), "Sister Anwen V smoke-test voice is missing")
	_assert(audio.has_voice("voice_player_test"), "Player B smoke-test voice is missing")
	_assert(audio.has_voice("voice_sister_anwen_greeting_01"), "Sister Anwen greeting voice is missing")
	_assert(audio.has_voice("voice_sister_anwen_report_01"), "Sister Anwen report voice is missing")
	_assert(audio.has_voice("voice_player_accept_contract_01"), "Player contract voice is missing")
	_assert(audio.has_voice("voice_player_clue_observation_01"), "Player clue voice is missing")
	_assert(audio.has_voice("voice_player_ghoulkin_death_01"), "Player Ghoulkin death voice is missing")
	audio.play_voice("missing_voice_should_not_crash")
	audio.play_voice("voice_sister_anwen_test")
	audio.stop_voice()
	audio.set_music_state("greyfen_explore")
	_assert(str(audio.music_state) == "greyfen_explore", "Greyfen exploration music state failed")
	audio.set_music_state("wychwood_tension")
	_assert(str(audio.music_state) == "wychwood_tension", "Wychwood tension music state failed")
	audio.set_music_state("ghoulkin_combat")
	_assert(str(audio.music_state) == "ghoulkin_combat", "Ghoulkin combat music state failed")
	audio.play_music_cue("victory_return_cue", "return_report")
	var game_source = FileAccess.get_file_as_string("res://scripts/game.gd")
	_assert(game_source.contains("KEY_V"), "V voice smoke-test key is not wired")
	_assert(game_source.contains("KEY_B"), "B voice smoke-test key is not wired")
	_assert(game_source.contains("voice_sister_anwen_report_01"), "Sister Anwen report voice hook is missing")
	_assert(game_source.contains("voice_player_ghoulkin_death_01"), "Player victory voice hook is missing")
	_assert(game_source.contains("set_music_state(\"ghoulkin_combat\")"), "Combat music trigger hook is missing")
	_assert(game_source.contains("victory_return_cue"), "Victory cue hook is missing")
	audio.queue_free()
	await process_frame
	print("audio runtime verification complete")
	quit()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
