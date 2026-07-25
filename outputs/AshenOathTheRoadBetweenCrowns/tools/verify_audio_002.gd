extends SceneTree

const AudioManager = preload("res://scripts/audio_manager.gd")

var failures := 0

func _initialize() -> void:
	var audio := AudioManager.new()
	root.add_child(audio)
	await process_frame
	var required_states := [
		"main_menu", "greyfen_explore", "wychwood_tension", "ghoulkin_combat",
		"deep_wood", "ash_mill", "marsh_crossing", "bandit_road",
		"castle_silence", "record_hall", "undercroft", "assembly", "hart_glade",
	]
	for state in required_states:
		check(audio.music.has(state), "Campaign music state is missing: %s" % state)
	for zone_id in [
		"greyfen", "wychwood", "deep_wood", "old_mill", "marsh_crossing",
		"bandit_road", "vargan_court", "record_hall", "undercroft",
		"assembly", "hart_glade",
	]:
		var state := audio.music_state_for_zone(zone_id)
		check(state != "" and audio.music.has(state), "Zone has no valid music identity: %s" % zone_id)
	audio.set_music_state("greyfen_explore")
	await process_frame
	var first_player := audio.music_player
	audio.set_music_state("deep_wood")
	await process_frame
	check(audio.music_player != null and audio.music_player != first_player, "Music transition did not create a crossfade player")
	check(first_player != null and is_instance_valid(first_player), "Outgoing music was destroyed before crossfade")
	await create_timer(1.0).timeout
	check(first_player == null or not is_instance_valid(first_player), "Outgoing music remained after crossfade")
	audio.play_ambient("undercroft")
	check(audio.current_ambient_zone == "undercroft", "Campaign ambience did not select the requested zone")
	check(audio.ambient_player != null and audio.ambient_player.stream != null, "Campaign ambience stream is missing")
	print("AUDIO-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
