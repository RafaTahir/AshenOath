extends SceneTree

const AudioManager = preload("res://scripts/audio_manager.gd")
var failures := 0

func _initialize() -> void:
	var audio := AudioManager.new()
	root.add_child(audio)
	await process_frame
	await audio.wait_until_ready()
	check(audio.has_method("play_event_limited"), "Debounced event API is missing")
	check(audio.has_method("set_game_paused"), "World-audio pause API is missing")
	check(audio.has_method("play_footstep"), "Surface-aware footstep API is missing")
	check(str(audio.bus_name) == "Master", "Runtime audio does not use the Master bus")
	for event_name in [
		"light_hit", "heavy_hit", "block", "parry", "stagger", "death",
		"enemy_windup", "ghoulkin_lunge", "oathfire_sheathe", "oathfire_charge",
		"oathfire_release", "shrine_bell", "shrine_candle", "village_life",
		"village_crow", "cloth_wind", "wychwood_tension", "tracks_found",
	]:
		check(audio.sounds.has(event_name) or audio.recorded_variants.has(event_name), "Cue is not registered: %s" % event_name)
		check(audio.call("_event_stream", event_name) is AudioStream, "Cue has no playable stream: %s" % event_name)
	for zone_id in ["greyfen", "wychwood", "cemetery", "record_hall", "undercroft", "hart_glade"]:
		audio.play_ambient(zone_id)
		check(audio.current_ambient_zone == zone_id, "Ambient zone did not update: %s" % zone_id)
		check(audio.ambient_player != null and audio.ambient_player.stream != null, "Ambient stream missing: %s" % zone_id)
	audio.set_game_paused(true)
	check(audio.game_paused, "World audio pause state did not latch")
	audio.set_game_paused(false)
	check(not audio.game_paused, "World audio resume state did not latch")
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	check(game_source.contains("light_hit"), "Player blade result has no light-hit cue")
	check(game_source.contains("heavy_hit"), "Player blade result has no heavy-hit cue")
	check(game_source.contains("play_footstep(current_zone_id, on_road, surface)"), "Footsteps are not surface-aware")
	check(game_source.contains("set_game_paused(true)"), "Gameplay pause hook is missing")
	var registry_source := FileAccess.get_file_as_string("res://scripts/runtime_service_registry.gd")
	check(registry_source.contains("_on_dialogue_closed_audio"), "Dialogue close does not resume world audio")
	print("AUDIO-REPAIR-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	audio.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("AUDIO-REPAIR-001: %s" % message)
