extends SceneTree

const AudioManager = preload("res://scripts/audio_manager.gd")

func _initialize() -> void:
	var audio = AudioManager.new()
	root.add_child(audio)
	await process_frame
	await audio.wait_until_ready()
	_assert(audio.has_method("play_voice"), "AudioManager is missing play_voice")
	_assert(audio.has_method("play_voice_sequence"), "AudioManager is missing play_voice_sequence")
	_assert(audio.has_method("stop_voice"), "AudioManager is missing stop_voice")
	_assert(audio.has_method("set_music_state"), "AudioManager is missing set_music_state")
	_assert(audio.has_method("play_music_cue"), "AudioManager is missing play_music_cue")
	for voice_id in audio.voices:
		if audio.has_voice(voice_id):
			_assert(audio.voices[voice_id] is AudioStream, "Approved voice has no playable stream: " + str(voice_id))
	_assert(not audio.browser_voice_fallback_enabled, "Unapproved generated browser speech must remain disabled")
	audio.play_voice("missing_voice_should_not_crash")
	audio.play_voice("voice_sister_anwen_test")
	audio.stop_voice()
	audio.set_music_state("greyfen_explore")
	_assert(str(audio.music_state) == "greyfen_explore", "Greyfen exploration music state failed")
	_assert(audio.music_player != null and audio.music_player.stream != null, "Exploration has no decoded music stream")
	audio.set_music_state("wychwood_tension")
	_assert(str(audio.music_state) == "wychwood_tension", "Wychwood tension music state failed")
	audio.set_music_state("ghoulkin_combat")
	_assert(str(audio.music_state) == "ghoulkin_combat", "Ghoulkin combat music state failed")
	audio.play_music_cue("victory_return_cue", "return_report")
	var game_source = FileAccess.get_file_as_string("res://scripts/systems/dialogue_service.gd") + FileAccess.get_file_as_string("res://scripts/systems/combat_coordinator.gd") + FileAccess.get_file_as_string("res://scripts/systems/hud_coordinator.gd")
	_assert(game_source.contains("play_voice") and FileAccess.get_file_as_string("res://scripts/systems/interaction_service.gd").contains("get_dialogue"), "Authored dialogue voice dispatch hook is missing")
	_assert(game_source.contains("voice_player_ghoulkin_death_01"), "Player victory voice hook is missing")
	_assert(game_source.contains("set_music_state(\"ghoulkin_combat\")"), "Combat music trigger hook is missing")
	_assert(game_source.contains("victory_return_cue"), "Victory cue hook is missing")
	print("AUDIO RUNTIME VERIFIER: PASS")
	# All checks above are active audio verification. Retire the generated
	# streams and pooled players before process exit so resource diagnostics are
	# classified as owned shutdown work rather than a runtime leak.
	print("VERIFIER_PHASE: SHUTDOWN")
	if audio != null and is_instance_valid(audio):
		audio.stop_zone_audio()
		audio.stop_voice()
		audio.queue_free()
	for _index in range(8):
		await process_frame
	# Audio mixing retires on its own clock, not eight unpaced headless frames.
	await create_timer(0.25).timeout
	call_deferred("quit", 0)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
