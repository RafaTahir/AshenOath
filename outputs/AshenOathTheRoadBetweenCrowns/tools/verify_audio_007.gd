extends SceneTree

const AudioManager = preload("res://scripts/audio_manager.gd")

var failures := 0

func _initialize() -> void:
	var audio := AudioManager.new()
	root.add_child(audio)
	await process_frame
	for state_id in [
		"boss_bell_eater",
		"boss_rootbound_colossus",
		"boss_ashwing",
		"boss_halvern_boss",
		"boss_white_hart_avatar"
	]:
		audio.set_music_state(state_id)
		await process_frame
		check(audio.music.has(state_id), "Boss music state was not built: %s" % state_id)
		check(audio.music[state_id] != null, "Boss music stream is empty: %s" % state_id)
	audio.set_music_state("greyfen_explore")
	audio.play_ambient("greyfen")
	audio.play_event("river_current", 0.0)
	audio.play_event("parry", 0.0)
	audio.set_game_paused(true)
	check(audio.game_paused, "Audio pause state was not retained")
	audio.set_game_paused(false)
	audio.set_master_volume(0.0)
	check(is_equal_approx(audio.master_volume_linear, 0.0), "Master volume mute did not apply")
	audio.set_master_volume(0.85)
	check(audio.master_volume_linear > 0.0, "Master volume restore did not apply")
	print("AUDIO-007 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	audio.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
