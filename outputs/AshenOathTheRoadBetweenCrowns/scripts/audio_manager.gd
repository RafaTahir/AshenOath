extends Node

var sounds = {}
var recorded_variants = {}
var voices = {}
var voice_texts = {}
var music = {}
var ambient_streams = {}
var bus_name = "Master"
var ambient_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var browser_voice_fallback_enabled := false
var development_voice_stubs_enabled := false
var current_ambient_zone = ""
var ambient_accent_time = 0.0
var music_state = ""
var _voice_queue: Array = []
var master_volume_linear = 0.85
var transient_players: Array[AudioStreamPlayer] = []
var transient_pool_cursor := 0
var music_transition_generation := 0
var music_transition_tween: Tween
var ambient_accents_enabled := true
var game_paused := false
var event_cooldowns: Dictionary = {}
const TRANSIENT_POOL_SIZE := 8
const MUSIC_GROUP := "ashen_oath_music_players"
const WORLD_AUDIO_EVENTS := [
	"step", "step_road", "step_forest", "step_mud", "step_stone", "step_wood",
	"swing", "heavy", "hit", "light_hit", "heavy_hit", "hurt", "enemy_windup",
	"ghoulkin_idle", "ghoulkin_lunge", "block", "parry", "stagger", "death",
	"bomb", "potion", "boss", "reveal", "victory", "victory_return_cue",
	"return_report", "tracks_found", "shrine_hum", "shrine_candle", "shrine_bell",
	"oathfire_sheathe", "oathfire_charge", "oathfire_release", "village_life",
	"village_crow", "cloth_wind", "wychwood_drop", "wychwood_tension",
	"river_current", "forge_hammer", "forest_breath", "stone_room",
	"portal_ash", "portal_ready", "portal_travel", "portal_error"
]
var opening_soundscape_zone := ""
var opening_soundscape_listener: Node3D
var opening_soundscape_anchors: Dictionary = {}
var opening_soundscape_quality := "balanced"

func _process(delta: float) -> void:
	for event_name in event_cooldowns.keys():
		event_cooldowns[event_name] = maxf(float(event_cooldowns[event_name]) - delta, 0.0)
	if ambient_player != null and ambient_player.stream != null and not ambient_player.playing:
		if not game_paused:
			ambient_player.play()
	if music_player != null and music_player.stream != null and not music_player.playing:
		if not game_paused:
			music_player.play()
	if voice_player != null and not voice_player.playing and not _voice_queue.is_empty():
		_play_next_voice()
	if game_paused or current_ambient_zone == "" or not ambient_accents_enabled:
		return
	ambient_accent_time -= delta
	if ambient_accent_time <= 0.0:
		_play_ambient_accent()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_library()
	_build_recorded_library()
	_build_voice_library()
	for index in range(TRANSIENT_POOL_SIZE):
		var pooled := AudioStreamPlayer.new()
		pooled.name = "TransientCue%02d" % index
		pooled.bus = bus_name
		add_child(pooled)
		transient_players.append(pooled)
	set_master_volume(master_volume_linear)
	_prewarm_common_cues()

func _exit_tree() -> void:
	# Release generated streams before Godot tears down the audio server. This
	# keeps short headless/Web startup checks from retaining the menu stream.
	if music_transition_tween != null and music_transition_tween.is_valid():
		music_transition_tween.kill()
	for player in transient_players:
		_release_player(player)
	_release_player(ambient_player)
	_release_player(music_player)
	_release_player(voice_player)
	transient_players.clear()
	ambient_player = null
	music_player = null
	voice_player = null
	_voice_queue.clear()
	sounds.clear()
	recorded_variants.clear()
	voices.clear()
	voice_texts.clear()
	music.clear()
	ambient_streams.clear()

func _release_player(player: AudioStreamPlayer) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.stop()
	player.stream_paused = false
	player.stream = null

func _prewarm_common_cues() -> void:
	var cue_ids := ["cloth_wind", "village_life", "village_crow", "ghoulkin_idle"]
	var warmers: Array[AudioStreamPlayer] = []
	for index in range(cue_ids.size()):
		var player: AudioStreamPlayer = transient_players[index]
		player.stream = _event_stream(cue_ids[index])
		player.volume_db = -80.0
		player.play()
		warmers.append(player)
	get_tree().create_timer(0.12, true, false, true).timeout.connect(func():
		for player in warmers:
			if is_instance_valid(player):
				player.stop()
	, CONNECT_ONE_SHOT)

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

func set_ambient_accents_enabled(enabled: bool) -> void:
	ambient_accents_enabled = enabled

func set_game_paused(paused: bool) -> void:
	game_paused = paused
	if paused:
		# Environmental and combat one-shots belong to the world timeline. Stop
		# them at the pause edge so a menu/dialogue cannot finish with a stale hit,
		# forge, or river cue after the player resumes.
		for player in transient_players:
			if player != null and is_instance_valid(player):
				player.stop()
	if ambient_player != null:
		ambient_player.stream_paused = paused
	if music_player != null:
		music_player.stream_paused = paused

func prewarm_opening_audio() -> void:
	for state_id in ["greyfen_explore", "wychwood_tension"]:
		if not music.has(state_id):
			_build_music_state(state_id)
	for zone_id in ["greyfen", "wychwood"]:
		if not ambient_streams.has(zone_id):
			ambient_streams[zone_id] = _build_ambient_stream(zone_id)

func play_event(event_name: String, pitch_variation: float = 0.06) -> void:
	_play_event_internal(event_name, pitch_variation, 1.0)

func _play_event_internal(event_name: String, pitch_variation: float, volume_scale: float) -> void:
	if not sounds.has(event_name) and not recorded_variants.has(event_name):
		return
	if game_paused and event_name in WORLD_AUDIO_EVENTS:
		return
	var player := _available_transient_player()
	player.stream = _event_stream(event_name)
	if player.stream == null:
		return
	player.volume_db = _volume_for(event_name) + linear_to_db(clampf(volume_scale, 0.05, 1.0)) + randf_range(-1.2, 0.8)
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()

func play_event_limited(event_name: String, cooldown_seconds: float, pitch_variation: float = 0.06) -> void:
	var remaining := float(event_cooldowns.get(event_name, 0.0))
	if remaining > 0.0:
		return
	event_cooldowns[event_name] = maxf(cooldown_seconds, 0.0)
	play_event(event_name, pitch_variation)

func play_spatial_event(event_name: String, source_position: Vector3, listener_position: Vector3, max_distance: float = 16.0, cooldown_seconds: float = 5.0, pitch_variation: float = 0.05) -> void:
	if max_distance <= 0.0:
		return
	var distance := source_position.distance_to(listener_position)
	if distance > max_distance:
		return
	var remaining := float(event_cooldowns.get(event_name, 0.0))
	if remaining > 0.0:
		return
	event_cooldowns[event_name] = maxf(cooldown_seconds, 0.0)
	var attenuation := clampf(1.0 - distance / max_distance, 0.14, 1.0)
	_play_event_internal(event_name, pitch_variation, attenuation)

func has_opening_soundscape(zone_id: String) -> bool:
	return not _opening_soundscape_profile(zone_id).is_empty()

func get_opening_soundscape_profile(zone_id: String) -> Array:
	return _opening_soundscape_profile(zone_id)

func configure_opening_soundscape(zone_id: String, listener: Node3D, anchors: Dictionary, quality: String = "balanced") -> void:
	opening_soundscape_zone = zone_id
	opening_soundscape_listener = listener
	opening_soundscape_anchors = anchors.duplicate()
	opening_soundscape_quality = quality

func tick_opening_soundscape(zone_id: String, listener: Node3D, anchors: Dictionary, quality: String = "balanced") -> void:
	if game_paused or listener == null or not is_instance_valid(listener) or not listener.is_inside_tree():
		return
	configure_opening_soundscape(zone_id, listener, anchors, quality)
	var candidates: Array[Dictionary] = []
	for entry in _opening_soundscape_profile(zone_id):
		var source_key := str(entry.get("source", "listener"))
		var source_value: Variant = anchors.get(source_key, listener.global_position)
		if not source_value is Vector3:
			source_value = listener.global_position
		var source_position: Vector3 = source_value
		var max_distance := float(entry.get("range", 14.0))
		if source_position.distance_to(listener.global_position) <= max_distance:
			candidates.append({"entry": entry, "source": source_position})
	if candidates.is_empty():
		return
	# One short accent per tick keeps the opening soundscape legible and cheap.
	var selected: Dictionary = candidates[randi() % candidates.size()]
	var selected_entry: Dictionary = selected.get("entry", {})
	play_spatial_event(
		str(selected_entry.get("event", "cloth_wind")),
		selected.get("source", listener.global_position),
		listener.global_position,
		float(selected_entry.get("range", 14.0)),
		float(selected_entry.get("cooldown", 5.0)),
		float(selected_entry.get("pitch", 0.05))
	)

func _opening_soundscape_profile(zone_id: String) -> Array:
	match zone_id:
		"greyfen":
			return [
				{"event":"village_life", "source":"village", "range":16.0, "cooldown":7.0, "pitch":0.05},
				{"event":"village_crow", "source":"village", "range":18.0, "cooldown":9.0, "pitch":0.08},
				{"event":"shrine_candle", "source":"shrine", "range":9.0, "cooldown":6.0, "pitch":0.04},
				{"event":"forge_hammer", "source":"forge", "range":11.0, "cooldown":4.5, "pitch":0.035},
				{"event":"river_current", "source":"river", "range":18.0, "cooldown":6.0, "pitch":0.04},
				{"event":"cloth_wind", "source":"listener", "range":12.0, "cooldown":8.0, "pitch":0.04}
			]
		"wychwood":
			return [
				{"event":"forest_breath", "source":"forest", "range":16.0, "cooldown":6.5, "pitch":0.045},
				{"event":"wychwood_tension", "source":"forest", "range":14.0, "cooldown":8.0, "pitch":0.025},
				{"event":"river_current", "source":"river", "range":16.0, "cooldown":7.0, "pitch":0.04},
				{"event":"cloth_wind", "source":"listener", "range":12.0, "cooldown":9.0, "pitch":0.035}
			]
		"cemetery", "chapel":
			return [
				{"event":"shrine_hum", "source":"shrine", "range":13.0, "cooldown":7.0, "pitch":0.025},
				{"event":"shrine_bell", "source":"bell", "range":18.0, "cooldown":13.0, "pitch":0.035},
				{"event":"forest_breath", "source":"listener", "range":11.0, "cooldown":9.0, "pitch":0.04}
			]
		"vargan_approach", "vargan_court", "assembly":
			return [
				{"event":"stone_room", "source":"listener", "range":12.0, "cooldown":8.0, "pitch":0.03},
				{"event":"cloth_wind", "source":"listener", "range":12.0, "cooldown":10.0, "pitch":0.03}
			]
		"record_hall", "undercroft":
			return [
				{"event":"stone_room", "source":"listener", "range":12.0, "cooldown":9.0, "pitch":0.025},
				{"event":"forest_breath", "source":"listener", "range":10.0, "cooldown":11.0, "pitch":0.025}
			]
		"hart_glade":
			return [
				{"event":"shrine_hum", "source":"shrine", "range":16.0, "cooldown":8.0, "pitch":0.02},
				{"event":"forest_breath", "source":"forest", "range":16.0, "cooldown":9.0, "pitch":0.03}
			]
	return []

func _available_transient_player() -> AudioStreamPlayer:
	for player in transient_players:
		if not player.playing:
			return player
	var player: AudioStreamPlayer = transient_players[transient_pool_cursor % transient_players.size()]
	transient_pool_cursor = (transient_pool_cursor + 1) % transient_players.size()
	player.stop()
	return player

func has_recorded_event(event_name: String) -> bool:
	return recorded_variants.has(event_name) and not recorded_variants[event_name].is_empty()

func _event_stream(event_name: String) -> AudioStream:
	if has_recorded_event(event_name):
		var variants: Array = recorded_variants[event_name]
		return variants[randi() % variants.size()] as AudioStream
	return sounds.get(event_name) as AudioStream

func has_voice(voice_id: String) -> bool:
	return voices.has(voice_id)

func play_voice(voice_id: String) -> void:
	stop_voice()
	if _has_production_voice(voice_id):
		_play_voice_now(voice_id)
		return
	if browser_voice_fallback_enabled and _speak_voice_id(voice_id):
		return

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
	_voice_queue.clear()
	for voice_id in voice_ids:
		var id = str(voice_id)
		if _has_production_voice(id):
			_voice_queue.append(id)
	if not _voice_queue.is_empty():
		_play_next_voice()
	elif browser_voice_fallback_enabled:
		var text_parts: Array = []
		for voice_id in voice_ids:
			var id = str(voice_id)
			if voice_texts.has(id):
				text_parts.append(str(voice_texts[id]))
		_speak_text(text_parts, str(voice_ids[0]) if voice_ids.size() > 0 else "voice_sequence")

func set_browser_voice_fallback_enabled(enabled: bool) -> void:
	browser_voice_fallback_enabled = enabled

func _has_production_voice(voice_id: String) -> bool:
	if not voices.has(voice_id):
		return false
	var stream := voices[voice_id] as AudioStream
	if stream == null:
		return false
	if development_voice_stubs_enabled:
		return true
	# Scratch WAVs and generated tone placeholders are development material. Do
	# not silently ship them as if they were finished acting.
	return not bool(stream.get_meta("development_voice_stub", false)) and not bool(stream.get_meta("scratch_voice", false))

func stop_voice() -> void:
	_voice_queue.clear()
	_stop_browser_speech()
	if voice_player != null:
		voice_player.stop()
		voice_player.queue_free()
		voice_player = null

func set_music_state(state_id: String) -> void:
	if state_id == music_state and music_player != null and is_instance_valid(music_player):
		return
	if not music.has(state_id):
		_build_music_state(state_id)
	if not music.has(state_id):
		return
	if music_transition_tween != null and music_transition_tween.is_valid():
		music_transition_tween.kill()
	_cleanup_stale_music_players(music_player)
	print("AUDIO: music_state_%s" % state_id)
	music_state = state_id
	music_transition_generation += 1
	var previous := music_player
	var incoming := AudioStreamPlayer.new()
	incoming.name = "CampaignMusic_%s" % state_id
	incoming.bus = bus_name
	incoming.stream = music[state_id]
	incoming.volume_db = -52.0
	incoming.add_to_group(MUSIC_GROUP)
	add_child(incoming)
	incoming.play()
	music_player = incoming
	var generation := music_transition_generation
	music_transition_tween = create_tween()
	music_transition_tween.set_parallel(true)
	music_transition_tween.tween_property(incoming, "volume_db", _music_volume_for(state_id), 0.85)
	if previous != null and is_instance_valid(previous):
		music_transition_tween.tween_property(previous, "volume_db", -52.0, 0.72)
		music_transition_tween.chain().tween_callback(func():
			if generation != music_transition_generation:
				return
			if is_instance_valid(previous) and previous != music_player:
				previous.stop()
				previous.queue_free()
		)

func _cleanup_stale_music_players(keep: AudioStreamPlayer) -> void:
	for node in get_tree().get_nodes_in_group(MUSIC_GROUP):
		if node == keep:
			continue
		if node is AudioStreamPlayer and is_instance_valid(node):
			(node as AudioStreamPlayer).stop()
			node.queue_free()

func music_player_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(MUSIC_GROUP):
		if node is AudioStreamPlayer and is_instance_valid(node):
			count += 1
	return count

func music_state_for_zone(zone_id: String) -> String:
	var states := {
		"greyfen": "greyfen_explore",
		"wychwood": "wychwood_tension",
		"deep_wood": "deep_wood",
		"old_mill": "ash_mill",
		"burned_farmstead": "ash_mill",
		"marsh_crossing": "marsh_crossing",
		"bandit_road": "bandit_road",
		"vargan_approach": "castle_silence",
		"vargan_court": "castle_silence",
		"record_hall": "record_hall",
		"undercroft": "undercroft",
		"assembly": "assembly",
		"hart_glade": "hart_glade",
	}
	return str(states.get(zone_id, "greyfen_explore"))

func play_music_cue(cue_id: String, next_state: String = "") -> void:
	print("AUDIO: music_cue_%s" % cue_id)
	if sounds.has(cue_id):
		play_event(cue_id, 0.015)
	if next_state != "":
		var timer = get_tree().create_timer(0.7)
		timer.timeout.connect(func(): set_music_state(next_state))

func play_footstep(zone_id: String, on_road: bool, surface: String = "") -> void:
	var event_name := "step_road" if on_road else "step_forest"
	match surface:
		"mud": event_name = "step_mud"
		"stone": event_name = "step_stone"
		"wood": event_name = "step_wood"
		"forest": event_name = "step_forest"
		"road": event_name = "step_road"
		_:
			if zone_id == "wychwood":
				event_name = "step_forest" if not on_road else "step_mud"
	play_event_limited(event_name, 0.055, 0.11)

func play_ambient(zone_id: String) -> void:
	stop_zone_audio()
	stop_voice()
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

func stop_zone_audio() -> void:
	for player in transient_players:
		if is_instance_valid(player):
			player.stop()
	if ambient_player != null:
		ambient_player.stop()
	event_cooldowns.clear()

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
	sounds["menu_hover"] = _tone_mix([392.0, 588.0], 0.060, 0.085, 32.0, 0.006)
	sounds["menu_click"] = _tone_mix([196.0, 392.0, 587.0], 0.110, 0.105, 24.0, 0.010)
	sounds["step"] = _footstep(0.045, 0.09, 82.0)
	sounds["step_road"] = _footstep(0.050, 0.11, 118.0)
	sounds["step_forest"] = _footstep(0.060, 0.08, 64.0)
	sounds["step_mud"] = _footstep(0.070, 0.10, 54.0)
	sounds["step_stone"] = _footstep(0.045, 0.095, 146.0)
	sounds["step_wood"] = _footstep(0.052, 0.085, 94.0)
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
	sounds["oathfire_sheathe"] = _tone_mix([180.0,240.0],0.16,0.10,70.0,0.025)
	sounds["oathfire_charge"] = _tone_mix([110.0,220.0,440.0],0.72,0.12,180.0,0.035)
	sounds["oathfire_release"] = _tone_mix([92.0,184.0,368.0,736.0],0.44,0.24,-80.0,0.055)
	sounds["village_life"] = _tone_mix([128.0, 171.0], 0.28, 0.055, 14.0, 0.030)
	sounds["village_crow"] = _tone_mix([690.0, 510.0], 0.18, 0.065, -250.0, 0.018)
	sounds["cloth_wind"] = _noise(0.32, 0.055)
	sounds["wychwood_drop"] = _tone_mix([62.0, 48.0], 0.40, 0.10, -36.0, 0.020)
	sounds["wychwood_tension"] = _tone_mix([62.0, 86.0, 129.0], 0.78, 0.085, -22.0, 0.052)
	sounds["river_current"] = _tone_mix([42.0, 63.0, 94.0], 0.52, 0.105, 3.0, 0.028)
	sounds["forge_hammer"] = _impact(0.095, 0.18, 182.0)
	sounds["forest_breath"] = _tone_mix([38.0, 57.0, 76.0], 0.46, 0.060, -8.0, 0.020)
	sounds["stone_room"] = _tone_mix([44.0, 66.0, 99.0], 0.42, 0.050, -4.0, 0.012)
	sounds["portal_ash"] = _noise(0.28, 0.045)
	sounds["portal_ready"] = _tone_mix([196.0, 294.0, 441.0], 0.32, 0.11, 54.0, 0.008)
	sounds["portal_travel"] = _tone_mix([92.0, 184.0, 368.0], 0.38, 0.16, 96.0, 0.014)
	sounds["portal_error"] = _tone_mix([72.0, 54.0], 0.24, 0.10, -28.0, 0.012)
	# Build every authored music identity up front. Zone transitions and
	# verification must see the same complete library before the first state
	# change; lazy creation alone made later campaign zones appear unconfigured.
	_build_music_library()

func _build_recorded_library() -> void:
	var root_path := "res://assets_external/audio/rpg/"
	recorded_variants["step_road"] = _load_streams(root_path, ["footstep00.ogg","footstep01.ogg","footstep02.ogg","footstep03.ogg"])
	recorded_variants["step_forest"] = _load_streams(root_path, ["footstep04.ogg","footstep05.ogg","footstep06.ogg"])
	recorded_variants["step_mud"] = _load_streams(root_path, ["footstep07.ogg","footstep08.ogg","footstep09.ogg"])
	recorded_variants["swing"] = _load_streams(root_path, ["knifeSlice.ogg","knifeSlice2.ogg"])
	recorded_variants["heavy"] = _load_streams(root_path, ["drawKnife2.ogg","drawKnife3.ogg"])
	recorded_variants["light_hit"] = _load_streams(root_path, ["metalClick.ogg","metalPot2.ogg"])
	recorded_variants["heavy_hit"] = _load_streams(root_path, ["metalPot1.ogg","metalPot3.ogg"])
	recorded_variants["block"] = _load_streams(root_path, ["metalClick.ogg","metalLatch.ogg"])
	recorded_variants["parry"] = _load_streams(root_path, ["metalLatch.ogg","metalPot2.ogg"])
	recorded_variants["oathfire_sheathe"] = _load_streams(root_path, ["drawKnife1.ogg"])
	recorded_variants["cloth_wind"] = _load_streams(root_path, ["cloth1.ogg","cloth2.ogg","cloth3.ogg"])
	recorded_variants["village_life"] = _load_streams(root_path, ["creak1.ogg","creak2.ogg"])
	var ui_hover := load("res://assets_external/audio/ui/rollover2.wav") as AudioStream
	var ui_click := load("res://assets_external/audio/ui/click3.wav") as AudioStream
	if ui_hover != null:
		recorded_variants["menu_hover"] = [ui_hover]
	if ui_click != null:
		recorded_variants["menu_click"] = [ui_click]
	for event_name in recorded_variants.keys():
		if recorded_variants[event_name].is_empty():
			recorded_variants.erase(event_name)

func _load_streams(root_path: String, file_names: Array) -> Array:
	var streams: Array = []
	for file_name in file_names:
		var stream := load(root_path + str(file_name)) as AudioStream
		if stream != null:
			streams.append(stream)
	return streams

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
	var campaign_lines := {
		"voice_senn_confession":"I barred the road. Halvern refused. They hanged him before dawn.",
		"voice_halvern_witness":"Do not call me loyal. I obeyed until obedience became murder.",
		"voice_edric_ledger":"I inherited the proof, then chose every morning not to open it.",
		"voice_anwen_confession":"The shrine taught Greyfen how to forget. I kept that teaching alive.",
		"voice_mira_ash":"Medicine made the knowing useful. It did not make it clean.",
		"voice_rook_road":"Roads do not lie. People redraw them until they do.",
		"voice_kael_names":"Bram. Sella. Oren. These names are not weapons.",
		"voice_hart_choice":"Ask which debt you are willing to carry awake.",
		"voice_kael_witness":"The dead were denied names. Tonight Greyfen will hear them.",
		"voice_kael_mercy":"Truth without mercy makes another road of bodies.",
		"voice_kael_duty":"No one else inherits this chain. It ends with me.",
		"voice_kael_ash":"A witness can die. What it witnessed cannot.",
		"voice_elna_bell":"My Harl is dead, but the bell still knows his hand.",
		"voice_tor_iron":"Iron remembers the shape of every fire.",
		"voice_oren_thread":"The thread is small enough for a child to trust.",
		"voice_sella_record":"Sella carried flour, needles, and a letter she never sent."
	}
	for voice_id in campaign_lines:
		voice_texts[voice_id] = campaign_lines[voice_id]
		voices[voice_id] = _voice_stub([102.0, 118.0, 94.0], 1.05, 0.055)
	_load_scratch_voice_library()

func _load_scratch_voice_library() -> void:
	var root_path := "res://assets_external/audio/voices/scratch/"
	for voice_id in voice_texts.keys():
		var path := root_path + str(voice_id) + ".wav"
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				stream.set_meta("scratch_voice_path", path)
				stream.set_meta("scratch_voice", true)
				voices[voice_id] = stream

func _build_music_library() -> void:
	for state_id in ["main_menu", "greyfen_explore", "shrine_anwen", "wychwood_tension", "ghoulkin_combat", "return_report", "castle_silence", "deep_wood", "ash_mill", "marsh_crossing", "bandit_road", "record_hall", "undercroft", "assembly", "hart_glade", "boss_bell_eater", "boss_rootbound_colossus", "boss_ashwing", "boss_halvern_boss", "boss_white_hart_avatar"]:
		_build_music_state(state_id)

func _build_music_state(state_id: String) -> void:
	match state_id:
		"main_menu": music[state_id] = _music_loop([55.0, 82.0, 110.0, 165.0], 6.4, 0.050, 0.016)
		"greyfen_explore": music[state_id] = _music_loop([73.0, 110.0, 146.0], 6.0, 0.060, 0.012)
		"shrine_anwen": music[state_id] = _music_loop([88.0, 132.0, 176.0, 264.0], 5.6, 0.052, 0.008)
		"wychwood_tension": music[state_id] = _music_loop([46.0, 69.0, 92.0], 6.2, 0.070, 0.020)
		"ghoulkin_combat": music[state_id] = _music_loop([54.0, 81.0, 108.0, 162.0], 3.8, 0.095, 0.018)
		"return_report": music[state_id] = _music_loop([66.0, 99.0, 148.0], 5.2, 0.056, 0.010)
		"castle_silence": music[state_id] = _music_loop([49.0, 73.5, 98.0, 147.0], 6.6, 0.048, 0.009)
		"deep_wood": music[state_id] = _music_loop([41.0, 61.5, 82.0, 123.0], 6.8, 0.052, 0.014)
		"ash_mill": music[state_id] = _music_loop([58.0, 87.0, 116.0], 6.4, 0.050, 0.011)
		"marsh_crossing": music[state_id] = _music_loop([43.0, 64.5, 96.0], 7.0, 0.046, 0.018)
		"bandit_road": music[state_id] = _music_loop([62.0, 93.0, 124.0, 186.0], 5.8, 0.056, 0.012)
		"record_hall": music[state_id] = _music_loop([52.0, 78.0, 104.0, 156.0], 7.2, 0.043, 0.008)
		"undercroft": music[state_id] = _music_loop([38.0, 57.0, 76.0], 7.4, 0.050, 0.016)
		"assembly": music[state_id] = _music_loop([69.0, 103.5, 138.0, 207.0], 6.6, 0.048, 0.007)
		"hart_glade": music[state_id] = _music_loop([77.0, 115.5, 154.0, 231.0], 7.2, 0.052, 0.010)
		"boss_bell_eater": music[state_id] = _music_loop([43.0, 57.0, 86.0, 129.0], 4.1, 0.108, 0.024)
		"boss_rootbound_colossus": music[state_id] = _music_loop([38.0, 51.0, 76.0, 114.0], 4.8, 0.102, 0.030)
		"boss_ashwing": music[state_id] = _music_loop([49.0, 73.0, 98.0, 147.0], 3.9, 0.112, 0.026)
		"boss_halvern_boss": music[state_id] = _music_loop([61.0, 91.0, 122.0, 183.0], 4.4, 0.088, 0.012)
		"boss_white_hart_avatar": music[state_id] = _music_loop([55.0, 82.0, 110.0, 165.0], 5.0, 0.082, 0.020)

func _ambient_stream(zone_id: String) -> AudioStreamWAV:
	if not ambient_streams.has(zone_id):
		ambient_streams[zone_id] = _build_ambient_stream(zone_id)
	return ambient_streams[zone_id] as AudioStreamWAV

func _build_ambient_stream(zone_id: String) -> AudioStreamWAV:
	if zone_id == "greyfen":
		return _ambient_mix([86.0, 146.0, 213.0], 2.6, 0.026, 0.0)
	if zone_id == "wychwood":
		return _ambient_mix([46.0, 73.0, 111.0], 3.0, 0.030, 0.0)
	if zone_id in ["deep_wood", "marsh_crossing"]:
		return _ambient_mix([38.0, 57.0, 91.0], 3.2, 0.026, 0.008)
	if zone_id in ["cemetery", "chapel"]:
		return _ambient_mix([42.0, 63.0, 94.0], 3.5, 0.023, 0.004)
	if zone_id in ["vargan_approach", "vargan_court", "record_hall", "undercroft"]:
		return _ambient_mix([44.0, 66.0, 99.0], 3.0, 0.022, 0.004)
	if zone_id == "hart_glade":
		return _ambient_mix([52.0, 78.0, 117.0], 3.4, 0.024, 0.003)
	return _ambient_mix([70.0], 2.2, 0.030, 0.0)

func _volume_for(event_name: String) -> float:
	if event_name == "voice":
		return -13.0
	if event_name.begins_with("step"):
		return -19.0
	if event_name == "ui":
		return -12.0
	if event_name == "menu_hover":
		return -24.0
	if event_name == "menu_click":
		return -17.0
	if event_name == "boss":
		return -7.0
	if event_name in ["shrine_hum", "shrine_candle", "cloth_wind", "village_crow", "village_life", "forest_breath", "stone_room"]:
		return -21.0
	if event_name in ["river_current", "forge_hammer", "portal_ash"]:
		return -19.5
	if event_name == "shrine_bell":
		return -18.0
	if event_name in ["portal_ready", "portal_travel", "portal_error"]:
		return -15.5
	if event_name in ["wychwood_tension", "wychwood_drop", "tracks_found", "return_report", "victory_return_cue"]:
		return -13.0
	if event_name == "ghoulkin_idle":
		return -16.0
	if event_name in ["enemy_windup", "death", "victory", "heavy_hit"]:
		return -10.5
	return -9.0

func _music_volume_for(state_id: String) -> float:
	if state_id.begins_with("boss_"):
		return -12.5
	if state_id == "ghoulkin_combat":
		return -11.0
	if state_id == "shrine_anwen":
		return -17.0
	if state_id == "wychwood_tension":
		return -14.0
	if state_id == "return_report":
		return -15.0
	if state_id == "main_menu":
		return -18.0
	if state_id in ["record_hall", "undercroft"]:
		return -18.0
	if state_id in ["assembly", "hart_glade"]:
		return -15.5
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
	var feminine = debug_id.contains("sister") or debug_id.contains("anwen") or debug_id.contains("mira") or debug_id.contains("elna")
	var pitch = 0.84 if feminine else (0.89 if debug_id.contains("hart") else 0.94)
	var rate = 0.88 if feminine else (0.82 if debug_id.contains("hart") else 0.94)
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
	var voices = window.speechSynthesis.getVoices();
	var feminine = %s;
	var preferred = voices.filter(function(v) {
		return /^en(-|_)/i.test(v.lang) && feminine === /(female|susan|samantha|hazel|zira|aria|google uk english female)/i.test(v.name);
	});
	if (preferred.length > 0) {
		utterance.voice = preferred[0];
	}
	window.speechSynthesis.speak(utterance);
	return true;
})()
""" % [escaped_text, volume, pitch, rate, "true" if feminine else "false"]
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
		play_event_limited("ghoulkin_idle" if randf() > 0.62 else "cloth_wind", 0.35, 0.05)
		ambient_accent_time = randf_range(5.0, 9.0)
	elif current_ambient_zone in ["cemetery", "chapel"]:
		if randf() > 0.78:
			play_event_limited("shrine_bell", 0.45, 0.04)
		else:
			play_event_limited("shrine_candle" if randf() > 0.45 else "cloth_wind", 0.25, 0.04)
		ambient_accent_time = randf_range(6.5, 12.0)
	elif current_ambient_zone in ["record_hall", "undercroft"]:
		play_event_limited("wychwood_drop" if randf() > 0.58 else "cloth_wind", 0.30, 0.04)
		ambient_accent_time = randf_range(7.0, 13.0)
	elif current_ambient_zone in ["vargan_approach", "vargan_court", "assembly"]:
		play_event_limited("cloth_wind", 0.25, 0.04)
		ambient_accent_time = randf_range(8.0, 14.0)
	elif current_ambient_zone == "hart_glade":
		play_event_limited("shrine_hum" if randf() > 0.64 else "cloth_wind", 0.30, 0.03)
		ambient_accent_time = randf_range(8.0, 15.0)
	else:
		ambient_accent_time = randf_range(8.0, 14.0)

func _tone(freq: float, seconds: float, amp: float, sweep: float = 0.0) -> AudioStreamWAV:
	var mix_rate = 11025
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
	stream.set_meta("development_voice_stub", true)
	return stream

func _noise(seconds: float, amp: float) -> AudioStreamWAV:
	var mix_rate = 11025
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
	var mix_rate = 11025
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
	var mix_rate = 11025
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
	var mix_rate = 11025
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
	var mix_rate = 11025
	var frames = int(seconds * mix_rate)
	var data = PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t = float(i) / float(mix_rate)
		var slow_env = 0.72 + 0.28 * sin(TAU * 0.23 * t)
		var sample_value = 0.0
		for j in range(freqs.size()):
			sample_value += sin(TAU * float(freqs[j]) * t) / float(max(freqs.size(), 1))
		# White-noise samples in this continuous stream were heard as static.
		var drift = sin(TAU * 0.37 * t) * noise_amp * 0.18
		sample_value = sample_value * tone_amp * slow_env + drift
		data.encode_s16(i * 2, int(clamp(sample_value, -1.0, 1.0) * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream

func _voice_stub(freqs: Array, seconds: float, amp: float) -> AudioStreamWAV:
	# Subtitles and browser speech are authoritative. Keep a tiny silent fallback
	# instead of synthesizing seconds of placeholder speech during startup.
	var mix_rate = 11025
	var data = PackedByteArray([0, 0])
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream

func _music_loop(freqs: Array, seconds: float, tone_amp: float, noise_amp: float) -> AudioStreamWAV:
	var mix_rate = 11025
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
		var drift = sin(TAU * 0.19 * t) * noise_amp * 0.16
		sample_value = sample_value * tone_amp * slow * pulse + drift
		data.encode_s16(i * 2, int(clamp(sample_value, -1.0, 1.0) * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream
