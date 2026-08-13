extends SceneTree

const AudioManager = preload("res://scripts/audio_manager.gd")
var failures: Array[String] = []

func _initialize() -> void:
	var audio := AudioManager.new()
	root.add_child(audio)
	await process_frame
	for method_name in ["play_spatial_event", "configure_opening_soundscape", "tick_opening_soundscape", "has_opening_soundscape"]:
		_check(audio.has_method(method_name), "AudioManager is missing %s" % method_name)
	for event_name in ["river_current", "forge_hammer", "forest_breath", "stone_room", "portal_ash", "portal_ready", "portal_travel", "portal_error"]:
		_check(audio.sounds.has(event_name), "Opening cue is missing: %s" % event_name)
	for zone_id in ["greyfen", "wychwood", "cemetery", "chapel", "vargan_court", "record_hall", "undercroft", "hart_glade"]:
		_check(audio.has_opening_soundscape(zone_id), "Opening soundscape profile is missing: %s" % zone_id)
		_check(not audio.get_opening_soundscape_profile(zone_id).is_empty(), "Opening profile has no cues: %s" % zone_id)
	audio.set_master_volume(0.0)
	_check(audio.master_volume_linear <= 0.001, "Master volume mute path did not update")
	audio.set_master_volume(0.85)
	audio.play_spatial_event("river_current", Vector3.ZERO, Vector3.ZERO, 12.0, 0.0, 0.02)
	_check(audio.event_cooldowns.has("river_current"), "Spatial event did not use the shared cooldown path")
	audio.queue_free()
	await process_frame

	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "Main scene is unavailable")
	if packed != null:
		var game := packed.instantiate()
		root.add_child(game)
		await process_frame
		game.call("_new_game")
		await _frames(24)
		_check(game.audio != null, "Game audio manager is missing")
		var soundscape = game.zone_root.find_child("OpeningSoundscape", true, false) if game.zone_root != null else null
		_check(soundscape != null, "OpeningSoundscape was not installed in Greyfen")
		if soundscape != null:
			_check(soundscape.listener == game.player, "OpeningSoundscape listener is not Kael")
			_check(not soundscape._anchors.is_empty(), "OpeningSoundscape did not discover landmark anchors")
		var portal = game.zone_root.find_child("OathGatePortal", true, false) if game.zone_root != null else null
		_check(portal != null, "Opening route has no Oath Gate")
		if portal != null:
			_check(portal.audio_manager == game.audio, "Oath Gate is not bound to AudioManager")
		game.queue_free()
		await process_frame
	_finish()

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _finish() -> void:
	if failures.is_empty():
		print("AUDIO-006 VERIFIER: PASS")
		quit(0)
		return
	print("AUDIO-006 VERIFIER: FAIL (%d)" % failures.size())
	quit(1)
