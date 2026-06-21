extends Node

var sounds = {}
var voices = {}
var voice_texts = {}
var music = {}
var bus_name = "Master"
var ambient_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var current_ambient_zone = ""
var ambient_accent_time = 0.0
var music_state = ""
var _voice_queue: Array = []
var master_volume_linear = 0.85

func _process(delta: float) -> void:
	if ambient_player != null and ambient_player.stream != null and not ambient_player.playing:
		ambient_player.play()
	if music_player != null and music_player.stream != null and not music_player.playing:
		music_player.play()
	if voice_player != null and not voice_player.playing and not _voice_queue.is_empty():
		_play_next_voice()
	if current_ambient_zone == "":
		return
	ambient_accent_time -= delta
	if ambient_accent_time <= 0.0:
		_play_ambient_accent()

func _ready() -> void:
	_build_library()
	_build_voice_library()
	_build_music_library()

func set_master_volume(linear_volume: float) -> void:
	master_volume_linear = clamp(linear_volume, 0.0, 1.0)
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	if master_volume_linear <= 0.001:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(master_volume_linear))

func play_event(event_name: String, pitch_variation: float = 0.06) -> void:
	if not sounds.has(event_name):
		return
	print("AUDIO: event_%s" % event_name)
	var player = AudioStreamPlayer.new()
	player.bus = bus_name
	player.stream = sounds[event_name]
	player.volume_db = _volume_for(event_name) + randf_range(-1.2, 0.8)
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func has_voice(voice_id: String) -> bool:
	return voices.has(voice_id)

func play_voice(voice_id: String) -> void:
	stop_voice()
	if _speak_voice_id(voice_id):
		return
	_play_voice_now(voice_id)

func _play_voice_now(voice_id: String) -> void:
	if not voices.has(voice_id):
		return
	voice_player = AudioStreamPlayer.new()
	voice_player.bus = bus_name
	voice_player.stream = voices[voice_id]
	voice_player.volume_db = _volume_for("voice")
	add_child(voice_player)
	voice_player.finished.connect(func():
		if voice_player != null:
			voice_player.queue_free()
			voice_player = null
		if not _voice_queue.is_empty():
			_play_next_voice()
	)
	voice_player.play()

func play_voice_sequence(voice_ids: Array) -> void:
	stop_voice()
	var text_parts: Array = []
	for voice_id in voice_ids:
		var id = str(voice_id)
		if voice_texts.has(id):
			text_parts.append(str(voice_texts[id]))
	if not text_parts.is_empty() and _speak_text(text_parts, str(voice_ids[0]) if voice_ids.size() > 0 else "voice_sequence"):
		return
	_voice_queue.clear()
	for voice_id in voice_ids:
		var id = str(voice_id)
		if voices.has(id):
			_voice_queue.append(id)
	if not _voice_queue.is_empty():
		_play_next_voice()

func stop_voice() -> void:
	_voice_queue.clear()
	_stop_browser_speech()
	if voice_player != null:
		voice_player.stop()
		voice_player.queue_free()
		voice_player = null

func set_music_state(state_id: String) -> void:
	if state_id == music_state or not music.has(state_id):
		return
	print("AUDIO: music_state_%s" % state_id)
	music_state = state_id
	if music_player == null:
		music_player = AudioStreamPlayer.new()
		music_player.bus = bus_name
		add_child(music_player)
	music_player.stop()
	music_player.stream = music[state_id]
	music_player.volume_db = -52.0
	music_player.play()
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", _music_volume_for(state_id), 0.65)

func play_music_cue(cue_id: String, next_state: String = "") -> void:
	print("AUDIO: music_cue_%s" % cue_id)
	if sounds.has(cue_id):
		play_event(cue_id, 0.015)
	if next_state != "":
		var timer = get_tree().create_timer(0.7)
		timer.timeout.connect(func(): set_music_state(next_state))

func play_footstep(zone_id: String, on_road: bool) -> void:
	var event_name = "step_road" if on_road else "step_forest"
	if zone_id == "wychwood":
		event_name = "step_forest" if not on_road else "step_mud"
	play_event(event_name, 0.11)

func play_ambient(zone_id: String) -> void:
	if ambient_player == null:
		ambient_player = AudioStreamPlayer.new()
		ambient_player.bus = bus_name
		add_child(ambient_player)
	var stream = _ambient_stream(zone_id)
	current_ambient_zone = zone_id
	ambient_accent_time = randf_range(3.5, 7.0)
	ambient_player.stop()
	ambient_player.stream = stream
	ambient_player.volume_db = -30.0 if zone_id == "greyfen" else -26.5
	ambient_player.play()

func _play_next_voice() -> void:
	if _voice_queue.is_empty():
		return
	var next_id = str(_voice_queue.pop_front())
	if voice_player != null:
		voice_player.stop()
		voice_player.queue_free()
		voice_player = null
	_play_voice_now(next_id)

func _build_library() -> void:
	sounds["ui"] = _tone(660.0, 0.055, 0.20)
	sounds["step"] = _footstep(0.045, 0.09, 82.0)
	sounds["step_road"] = _footstep(0.050, 0.11, 118.0)
	sounds["step_forest"] = _footstep(0.060, 0.08, 64.0)
	sounds["step_mud"] = _footstep(0.070, 0.10, 54.0)
	sounds["swing"] = _tone_mix([180.0, 238.0], 0.105, 0.17, 74.0, 0.05)
	sounds["heavy"] = _tone_mix([105.0, 154.0], 0.18, 0.24, 42.0, 0.07)
	sounds["hit"] = _impact(0.095, 0.30, 150.0)
	sounds["light_hit"] = _impact(0.080, 0.22, 190.0)
	sounds["heavy_hit"] = _impact(0.145, 0.36, 92.0)
	sounds["hurt"] = _tone_mix([92.0, 138.0], 0.18, 0.18, -28.0, 0.05)
	sounds["enemy_windup"] = _tone_mix([104.0, 142.0], 0.34, 0.15, -74.0, 0.045)
	sounds["ghoulkin_idle"] = _tone_mix([54.0, 81.0], 0.42, 0.085, -12.0, 0.055)
	sounds["ghoulkin_lunge"] = _impact(0.13, 0.25, 82.0)
	sounds["block"] = _tone_mix([230.0, 360.0], 0.105, 0.17, -115.0, 0.04)
	sounds["parry"] = _tone_mix([640.0, 920.0], 0.16, 0.16, 260.0, 0.025)
	sounds["stagger"] = _impact(0.13, 0.25, 72.0)
	sounds["death"] = _tone_mix([72.0, 47.0], 0.46, 0.19, -38.0, 0.065)
	sounds["bomb"] = _impact(0.24, 0.42, 70.0)
	sounds["potion"] = _tone_mix([360.0, 520.0], 0.20, 0.14, 80.0, 0.015)
	sounds["quest"] = _tone_mix([410.0, 615.0], 0.22, 0.12, 120.0, 0.01)
	sounds["boss"] = _tone_mix([56.0, 72.0], 0.52, 0.22, -16.0, 0.05)
	sounds["reveal"] = _tone_mix([166.0, 102.0], 0.44, 0.13, -80.0, 0.045)
	sounds["victory"] = _tone_mix([196.0, 294.0, 392.0], 0.58, 0.13, 28.0, 0.018)
	sounds["victory_return_cue"] = _tone_mix([174.0, 261.0, 349.0, 523.0], 0.92, 0.105, 18.0, 0.012)
	sounds["return_report"] = _tone_mix([220.0, 330.0, 440.0], 0.46, 0.12, 34.0, 0.012)
	sounds["tracks_found"] = _tone_mix([138.0, 206.0], 0.34, 0.11, -34.0, 0.035)
	sounds["shrine_hum"] = _tone_mix([96.0, 192.0, 288.0], 0.95, 0.060, 1.0, 0.010)
	sounds["shrine_candle"] = _tone_mix([132.0, 264.0], 0.36, 0.045, 3.0, 0.040)
	sounds["shrine_bell"] = _tone_mix([294.0, 440.0], 0.62, 0.075, -8.0, 0.008)
	sounds["village_life"] = _tone_mix([128.0, 171.0], 0.28, 0.055, 14.0, 0.030)
	sounds["village_crow"] = _tone_mix([690.0, 510.0], 0.18, 0.065, -250.0, 0.018)
	sounds["cloth_wind"] = _noise(0.32, 0.055)
	sounds["wychwood_drop"] = _tone_mix([62.0, 48.0], 0.40, 0.10, -36.0, 0.020)
	sounds["wychwood_tension"] = _tone_mix([62.0, 86.0, 129.0], 0.78, 0.085, -22.0, 0.052)

func _build_voice_library() -> void:
	voice_texts["voice_sister_anwen_test"] = "Sister Anwen: The road remembers every oath broken upon it."
	voice_texts["voice_player_test"] = "Player: Then I will hear what the dead have to say."
	voice_texts["voice_sister_anwen_greeting_01"] = "Keep your blade low in Greyfen, hunter. Fear already has hands around every throat here."
	voice_texts["voice_sister_anwen_road_warning_01"] = "The old road has taken three men and returned none whole. That is not hunger. Hunger is honest."
	voice_texts["voice_sister_anwen_wychwood_warning_01"] = "Look for the cart, the clawed mud, and the black feathers. If you find them together, come back before you chase the dark farther."
	voice_texts["voice_sister_anwen_report_01"] = "Then it was called here. Greyfen owes you coin, and more truth than I can bear tonight."
	voice_texts["voice_player_accept_contract_01"] = "I'll take the road."
	voice_texts["voice_player_clue_observation_01"] = "These tracks were dragged through blood."
	voice_texts["voice_player_ghoulkin_death_01"] = "That thing was not hunting alone."
	voice_texts["voice_player_return_report_01"] = "Back to Greyfen. Anwen needs to hear this."
	voices["voice_sister_anwen_greeting_01"] = _voice_stub([146.0, 174.0, 130.0], 1.15, 0.060)
	voices["voice_sister_anwen_road_warning_01"] = _voice_stub([132.0, 121.0, 154.0, 118.0], 1.35, 0.056)
	voices["voice_sister_anwen_wychwood_warning_01"] = _voice_stub([116.0, 138.0, 104.0, 126.0], 1.45, 0.054)
	voices["voice_sister_anwen_report_01"] = _voice_stub([128.0, 108.0, 145.0, 96.0], 1.30, 0.058)
	voices["voice_player_accept_contract_01"] = _voice_stub([96.0, 111.0, 90.0], 0.82, 0.070)
	voices["voice_player_clue_observation_01"] = _voice_stub([88.0, 102.0, 80.0], 0.95, 0.062)
	voices["voice_player_ghoulkin_death_01"] = _voice_stub([82.0, 74.0, 101.0], 1.05, 0.068)
	voices["voice_player_return_report_01"] = _voice_stub([92.0, 108.0, 86.0], 0.96, 0.064)
	voices["voice_sister_anwen_test"] = _voice_stub([146.0, 172.0, 122.0, 158.0], 1.45, 0.085)
	voices["voice_player_test"] = _voice_stub([92.0, 110.0, 84.0, 104.0], 1.20, 0.090)

func _build_music_library() -> void:
	music["greyfen_explore"] = _music_loop([73.0, 110.0, 146.0], 6.0, 0.060, 0.012)
	music["shrine_anwen"] = _music_loop([88.0, 132.0, 176.0, 264.0], 5.6, 0.052, 0.008)
	music["wychwood_tension"] = _music_loop([46.0, 69.0, 92.0], 6.2, 0.070, 0.020)
	music["ghoulkin_combat"] = _music_loop([54.0, 81.0, 108.0, 162.0], 3.8, 0.095, 0.018)
	music["return_report"] = _music_loop([66.0, 99.0, 148.0], 5.2, 0.056, 0.010)

func _ambient_stream(zone_id: String) -> AudioStreamWAV:
	if zone_id == "greyfen":
		return _ambient_mix([86.0, 146.0, 213.0], 2.6, 0.026, 0.018)
	if zone_id == "wychwood":
		return _ambient_mix([46.0, 73.0, 111.0], 3.0, 0.030, 0.040)
	return _ambient_mix([70.0], 2.2, 0.030, 0.030)

func _volume_for(event_name: String) -> float:
	if event_name == "voice":
		return -13.0
	if event_name.begins_with("step"):
		return -19.0
	if event_name == "ui":
		return -12.0
	if event_name == "boss":
		return -7.0
	if event_name in ["shrine_hum", "shrine_candle", "cloth_wind", "village_crow", "village_life"]:
		return -21.0
	if event_name == "shrine_bell":
		return -18.0
	if event_name in ["wychwood_tension", "wychwood_drop", "tracks_found", "return_report", "victory_return_cue"]:
		return -13.0
	if event_name == "ghoulkin_idle":
		return -16.0
	if event_name in ["enemy_windup", "death", "victory", "heavy_hit"]:
		return -10.5
	return -9.0

func _music_volume_for(state_id: String) -> float:
	if state_id == "ghoulkin_combat":
		return -11.0
	if state_id == "shrine_anwen":
		return -17.0
	if state_id == "wychwood_tension":
		return -14.0
	if state_id == "return_report":
		return -15.0
	return -16.0

func _speak_voice_id(voice_id: String) -> bool:
	if not voice_texts.has(voice_id):
		return false
	return _speak_text([str(voice_texts[voice_id])], voice_id)

func _speak_text(text_parts: Array, debug_id: String) -> bool:
	if text_parts.is_empty():
		return false
	var text = ""
	for part in text_parts:
		if text != "":
			text += " "
		text += str(part)
	if not OS.has_feature("web"):
		print("AUDIO: browser_speech_unavailable_%s" % debug_id)
		return false
	var escaped_text = JSON.stringify(text)
	var volume = clamp(master_volume_linear, 0.0, 1.0)
	var pitch = 0.82 if debug_id.contains("sister") else 0.92
	var rate = 0.86 if debug_id.contains("sister") else 0.94
	var js = """
(function() {
	if (!('speechSynthesis' in window) || typeof SpeechSynthesisUtterance === 'undefined') {
		return false;
	}
	window.speechSynthesis.cancel();
	var utterance = new SpeechSynthesisUtterance(%s);
	utterance.volume = %f;
	utterance.pitch = %f;
	utterance.rate = %f;
	window.speechSynthesis.speak(utterance);
	return true;
})()
""" % [escaped_text, volume, pitch, rate]
	var spoken = JavaScriptBridge.eval(js, true)
	if bool(spoken):
		print("AUDIO: %s" % debug_id)
		return true
	print("AUDIO: browser_speech_failed_%s" % debug_id)
	return false

func _stop_browser_speech() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("if ('speechSynthesis' in window) { window.speechSynthesis.cancel(); }", false)

func _play_ambient_accent() -> void:
	if current_ambient_zone == "greyfen":
		var roll = randf()
		if roll > 0.72:
			play_event("village_crow", 0.08)
		elif roll > 0.38:
			play_event("village_life", 0.05)
		else:
			play_event("cloth_wind", 0.04)
		ambient_accent_time = randf_range(6.5, 12.5)
	elif current_ambient_zone == "wychwood":
		play_event("ghoulkin_idle" if randf() > 0.62 else "cloth_wind", 0.05)
		ambient_accent_time = randf_range(5.0, 9.0)
	else:
		ambient_accent_time = randf_range(8.0, 14.0)

func _tone(freq: float, seconds: float, amp: float, sweep: float = 0.0) -> AudioStreamWAV:
	var mix_rate = 22050
	var frames = int(seconds * mix_rate)
	var data = PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t = float(i) / float(mix_rate)
		var env = 1.0 - float(i) / float(max(frames, 1))
		var current = freq + sweep * t
		var sample = int(sin(TAU * current * t) * amp * env * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream

func _noise(seconds: float, amp: float) -> AudioStreamWAV:
	var mix_rate = 22050
	var frames = int(seconds * mix_rate)
	var data = PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var env = 1.0 - float(i) / float(max(frames, 1))
		var sample = int(randf_range(-1.0, 1.0) * amp * env * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream

func _tone_mix(freqs: Array, seconds: float, amp: float, sweep: float = 0.0, noise_amp: float = 0.0) -> AudioStreamWAV:
	var mix_rate = 22050
	var frames = int(seconds * mix_rate)
	var data = PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t = float(i) / float(mix_rate)
		var env = pow(1.0 - float(i) / float(max(frames, 1)), 1.35)
		var sample_value = 0.0
		for j in range(freqs.size()):
			var current = float(freqs[j]) + sweep * t * (1.0 + 0.18 * float(j))
			sample_value += sin(TAU * current * t) / float(max(freqs.size(), 1))
		sample_value = sample_value * amp
		if noise_amp > 0.0:
			sample_value += randf_range(-noise_amp, noise_amp)
		data.encode_s16(i * 2, int(clamp(sample_value * env, -1.0, 1.0) * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream

func _footstep(seconds: float, amp: float, thud_freq: float) -> AudioStreamWAV:
	var mix_rate = 22050
	var frames = int(seconds * mix_rate)
	var data = PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t = float(i) / float(mix_rate)
		var env = pow(1.0 - float(i) / float(max(frames, 1)), 2.4)
		var thud = sin(TAU * thud_freq * t) * amp
		var grit = randf_range(-amp * 0.55, amp * 0.55)
		data.encode_s16(i * 2, int(clamp((thud + grit) * env, -1.0, 1.0) * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream

func _impact(seconds: float, amp: float, thud_freq: float) -> AudioStreamWAV:
	var mix_rate = 22050
	var frames = int(seconds * mix_rate)
	var data = PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t = float(i) / float(mix_rate)
		var env = pow(1.0 - float(i) / float(max(frames, 1)), 1.8)
		var thud = sin(TAU * thud_freq * t) * amp
		var crack = randf_range(-amp, amp) * 0.45
		data.encode_s16(i * 2, int(clamp((thud + crack) * env, -1.0, 1.0) * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream

func _ambient_mix(freqs: Array, seconds: float, tone_amp: float, noise_amp: float) -> AudioStreamWAV:
	var mix_rate = 22050
	var frames = int(seconds * mix_rate)
	var data = PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t = float(i) / float(mix_rate)
		var slow_env = 0.72 + 0.28 * sin(TAU * 0.23 * t)
		var sample_value = 0.0
		for j in range(freqs.size()):
			sample_value += sin(TAU * float(freqs[j]) * t) / float(max(freqs.size(), 1))
		sample_value = sample_value * tone_amp * slow_env + randf_range(-noise_amp, noise_amp)
		data.encode_s16(i * 2, int(clamp(sample_value, -1.0, 1.0) * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream

func _voice_stub(freqs: Array, seconds: float, amp: float) -> AudioStreamWAV:
	var mix_rate = 22050
	var frames = int(seconds * mix_rate)
	var data = PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t = float(i) / float(mix_rate)
		var syllable = 0.45 + 0.55 * max(0.0, sin(TAU * 4.1 * t))
		var env = min(1.0, t * 7.0) * pow(max(0.0, 1.0 - t / max(seconds, 0.001)), 0.65)
		var sample_value = 0.0
		for j in range(freqs.size()):
			var current = float(freqs[j]) * (1.0 + 0.018 * sin(TAU * (5.0 + j) * t))
			sample_value += sin(TAU * current * t) / float(max(freqs.size(), 1))
		sample_value = sample_value * amp * syllable * env + randf_range(-0.006, 0.006) * env
		data.encode_s16(i * 2, int(clamp(sample_value, -1.0, 1.0) * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream

func _music_loop(freqs: Array, seconds: float, tone_amp: float, noise_amp: float) -> AudioStreamWAV:
	var mix_rate = 22050
	var frames = int(seconds * mix_rate)
	var data = PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t = float(i) / float(mix_rate)
		var slow = 0.64 + 0.36 * sin(TAU * 0.17 * t)
		var pulse = 0.82 + 0.18 * max(0.0, sin(TAU * 0.72 * t))
		var sample_value = 0.0
		for j in range(freqs.size()):
			sample_value += sin(TAU * float(freqs[j]) * t) / float(max(freqs.size(), 1))
		sample_value = sample_value * tone_amp * slow * pulse + randf_range(-noise_amp, noise_amp)
		data.encode_s16(i * 2, int(clamp(sample_value, -1.0, 1.0) * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream
