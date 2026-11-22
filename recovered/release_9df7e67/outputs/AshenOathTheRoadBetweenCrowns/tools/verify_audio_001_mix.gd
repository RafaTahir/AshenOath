extends SceneTree

const Manager := preload("res://scripts/audio_manager.gd")
var failures: Array[String] = []
var samples: Dictionary = {}
var capture: AudioEffectCapture
var bus_index := -1
var audio: Node

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Audio mix proof requires native camera/listener and actual audio mixing")
		quit(1)
		return
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	bus_index = AudioServer.get_bus_count()
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, "RecoveryAudioMix")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(bus_index, capture)
	audio = Manager.new()
	audio.bus_name = "RecoveryAudioMix"
	root.add_child(audio)
	await process_frame
	await audio.wait_until_ready()
	var cue_bus_name: String = audio.cue_bus_name
	var cue_bus := AudioServer.get_bus_index(cue_bus_name)
	_check(cue_bus > 0 and AudioServer.get_bus_effect(cue_bus, 0) is AudioEffectHardLimiter, "Cue mix has no owned peak protection")
	audio.set_ambient_accents_enabled(false)
	audio.play_spatial_event("forge_hammer", Vector3(-4, 0, -3), Vector3.ZERO, 12, 0, 0)
	var left := await _measure("landmark_left", 0.35)
	_check(float(left.left_rms) > float(left.right_rms) * 1.4 and float(left.left_rms) > 0.00001, "Left landmark is silent or not positionally panned")
	audio.stop_zone_audio()
	await create_timer(0.12).timeout
	audio.play_spatial_event("forge_hammer", Vector3(4, 0, -3), Vector3.ZERO, 12, 0, 0)
	var right := await _measure("landmark_right", 0.35)
	_check(float(right.right_rms) > float(right.left_rms) * 1.4 and float(right.right_rms) > 0.00001, "Right landmark is silent or not positionally panned")
	audio.stop_zone_audio()
	var previous_cooldowns: Dictionary = audio.event_cooldowns.duplicate()
	audio.play_spatial_event("forge_hammer", Vector3(20, 0, 0), Vector3.ZERO, 12, 2, 0)
	_check(audio.event_cooldowns == previous_cooldowns, "Out-of-range cue consumes cooldown")
	audio.play_ambient("greyfen")
	await create_timer(0.9).timeout
	var previous: AudioStreamPlayer = audio.ambient_player
	audio.play_ambient("wychwood")
	var incoming: AudioStreamPlayer = audio.ambient_player
	_check(previous != incoming and previous.playing and incoming.playing, "Ambience cuts instead of crossfading")
	var first_gain := incoming.volume_db
	await create_timer(0.3).timeout
	_check(incoming.volume_db > first_gain and previous.volume_db < -30.0, "Ambience fade gains do not progress")
	audio.set_music_state("greyfen_explore")
	audio.set_music_state("ghoulkin_combat")
	audio.set_game_paused(true)
	for player in audio.ambient_players:
		_check(player.stream_paused, "Outgoing ambience ignores pause")
	for player in get_nodes_in_group(Manager.MUSIC_GROUP):
		_check(player.stream_paused, "Outgoing music ignores pause")
	audio.set_music_state("boss_bell_eater")
	_check(audio.music_player.stream_paused, "Music initiated during pause is audible")
	audio.play_spatial_event("forge_hammer", Vector3.ZERO, Vector3.ZERO, 12, 0, 0)
	_check(not audio.spatial_players.any(func(player: AudioStreamPlayer3D) -> bool: return player.playing), "Spatial cues survive pause")
	await create_timer(0.15).timeout
	var paused := await _measure("paused_world", 0.2)
	_check(float(paused.peak) < 0.00001, "Paused world still produces mixed samples")
	audio.set_game_paused(false)
	var resumed := await _measure("resumed_world", 0.25)
	_check(float(resumed.peak) > 0.00001, "Resume does not restore sound")
	for zone in ["record_hall", "undercroft", "hart_glade", "greyfen"]:
		audio.play_ambient(zone)
	_check(audio.ambient_players.size() <= 2, "Rapid ambience changes exceed two-player budget")
	await create_timer(0.95).timeout
	_check(audio.ambient_players.size() == 1, "Outgoing ambience was not retired")
	for index in range(12):
		audio.play_event("heavy_hit", 0)
		audio.play_spatial_event("river_current", Vector3(index % 2 * 4 - 2, 0, -4), Vector3.ZERO, 12, 0, 0)
	await process_frame
	var active := 0
	for player in audio.transient_players:
		active += 1 if player.playing else 0
	for player in audio.spatial_players:
		active += 1 if player.playing else 0
	_check(active <= Manager.TRANSIENT_POOL_SIZE and audio.spatial_players.size() <= Manager.SPATIAL_POOL_SIZE, "Combined cue pool exceeds original active budget")
	var mix := await _measure("combat_landmark_music_mix", 0.4)
	_check(float(mix.peak) < 0.95, "Native combined mix clips or has insufficient headroom")
	audio._stop_transient_cues()
	await create_timer(0.15).timeout
	audio.set_master_volume(1.0)
	for _index in range(Manager.TRANSIENT_POOL_SIZE):
		audio.play_event("heavy_hit", 0)
	var maximum := await _measure("maximum_volume_eight_impacts", 0.35)
	_check(float(maximum.peak) < 0.95, "Eight simultaneous impacts clip at maximum user volume")
	audio._stop_transient_cues()
	await create_timer(0.12).timeout
	for enemy_id in ["ghoulkin", "rootbound_colossus", "halvern_boss", "ashwing", "white_hart_avatar"]:
		audio.play_enemy_event(enemy_id, "windup", Vector3(2, 0, -3), Vector3.ZERO)
	var enemies := await _measure("recorded_enemy_family_mix", 0.35)
	_check(float(enemies.peak) > 0.00001 and float(enemies.peak) < 0.95, "Recorded family cues are silent or clip")
	_check(not audio._has_production_voice("voice_sister_anwen_greeting_01"), "Unapproved scratch voice ships as acting")
	audio.stop_zone_audio()
	audio.stop_voice()
	audio.queue_free()
	for _frame in range(8):
		await process_frame
	await create_timer(0.18).timeout
	_check(AudioServer.get_bus_index(cue_bus_name) == -1, "Owned cue bus leaks after shutdown")
	camera.free()
	AudioServer.remove_bus(bus_index)
	capture = null
	var output := ProjectSettings.globalize_path("res://.release-gate/audio001_mix_20260927.json")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "Native actual stereo PCM, state, pause and headroom; NOT listening, browser unlock or full gameplay acceptance", "audio_manager_sha256": FileAccess.get_sha256("res://scripts/audio_manager.gd"), "verifier_sha256": FileAccess.get_sha256("res://tools/verify_audio_001_mix.gd"), "samples": samples, "failures": failures}, "\t"))
	file.close()
	for failure in failures:
		push_error(failure)
	print("AUDIO-001 NATIVE MIX: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _measure(id: String, seconds: float) -> Dictionary:
	capture.clear_buffer()
	await create_timer(seconds).timeout
	var frames := capture.get_buffer(capture.get_frames_available())
	var left := 0.0
	var right := 0.0
	var peak := 0.0
	for frame in frames:
		_check(frame.is_finite(), id + ": invalid mixed sample")
		left += frame.x * frame.x
		right += frame.y * frame.y
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	_check(not frames.is_empty(), id + ": no native mixed frames")
	var result := {"frames": frames.size(), "left_rms": sqrt(left / maxi(frames.size(), 1)), "right_rms": sqrt(right / maxi(frames.size(), 1)), "peak": peak}
	samples[id] = result
	print("AUDIO PCM %s %s" % [id, JSON.stringify(result)])
	return result

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
