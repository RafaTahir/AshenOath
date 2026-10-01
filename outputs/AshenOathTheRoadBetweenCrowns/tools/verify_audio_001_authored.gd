extends SceneTree

const AudioManager = preload("res://scripts/audio_manager.gd")
const Game = preload("res://scripts/game.gd")
var failures: Array[String] = []

class SurfaceAudio:
	extends Node
	var last_surface := ""
	func play_footstep(_zone_id: String, _on_road: bool, surface: String) -> void:
		last_surface = surface

class BridgeProbe:
	extends Node
	var on_bridge := false
	func is_on_bridge(_position: Vector3) -> bool:
		return on_bridge

func _initialize() -> void:
	var audio := AudioManager.new()
	root.add_child(audio)
	await process_frame
	audio.set_runtime_file_assets_available(false)
	await audio.wait_until_ready()
	audio.play_ambient("greyfen")
	check(audio.ambient_player.stream is AudioStreamWAV, "Missing-pack ambience must remain playable")
	audio.set_runtime_file_assets_available(true)
	check(audio.ambient_player.stream is AudioStreamOggVorbis, "Mounted audio did not replace active Greyfen ambience")
	for zone_id in ["greyfen", "wychwood", "marsh_crossing", "cemetery", "record_hall", "hart_glade"]:
		audio.play_ambient(zone_id)
		var stream := audio.ambient_player.stream
		check(stream is AudioStreamOggVorbis, "No authored ambience for %s" % zone_id)
		if stream is AudioStreamOggVorbis:
			check(stream.loop, "Authored ambience does not loop in %s" % zone_id)
	for event_name in ["light_hit", "heavy_hit", "parry", "oathfire_sheathe", "forge_hammer", "river_current", "record_page", "village_crow"]:
		check(audio.has_recorded_event(event_name), "Missing recorded event: %s" % event_name)
		check(audio.call("_event_stream", event_name) is AudioStreamOggVorbis, "Event is not an authored OGG: %s" % event_name)
	for surface in ["step_road", "step_forest", "step_mud", "step_stone", "step_wood"]:
		check(audio.has_recorded_event(surface), "Missing recorded footstep surface: %s" % surface)
		check(audio.call("_event_stream", surface) is AudioStreamOggVorbis, "Footstep is still synthetic: %s" % surface)
	var event_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets_external/audio/authored/event_manifest.json"))
	for entry in event_manifest.get("entries", []):
		var path: String = entry.path
		check(FileAccess.get_sha256(path) == str(entry.sha256), "Recorded event checksum mismatch: " + path)
		for event in entry.events:
			check(audio.has_recorded_event(str(event)), "Missing recorded creature/Oathfire/prop event: " + str(event))
			var stream := audio._event_stream(str(event)) as AudioStreamOggVorbis
			check(stream != null and not stream.loop and absf(stream.get_length() - float(entry.seconds)) < 0.04, "Event loops, is synthetic, or has incorrect duration: " + str(event))
	check(not audio.call("_has_production_voice", "voice_sister_anwen_greeting_01"), "Scratch voice must remain subtitle-only")
	var creature_vocals := ["enemy_windup", "stagger", "death", "ghoulkin_lunge"]
	for enemy_id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "bell_eater"]:
		for phase in ["windup", "hit", "death", "attack"]:
			check(audio.has_recorded_event(audio.enemy_event_name(enemy_id, phase)), "Ghoulkin event is not recorded: " + enemy_id + "/" + phase)
	for enemy_id in ["bandit", "gravebound_knight", "halvern_boss", "rootbound_colossus", "ashwing", "white_hart_avatar", "bog_wretch"]:
		for phase in ["windup", "hit", "death", "attack"]:
			check(audio.enemy_event_name(enemy_id, phase) not in creature_vocals, "Non-Ghoulkin inherited a Ghoulkin voice: " + enemy_id)
			check(audio.has_recorded_event(audio.enemy_event_name(enemy_id, phase)), "Opponent event still uses a synthetic cue: " + enemy_id + "/" + phase)
	check(audio.enemy_event_name("ghoulkin", "invalid") == "", "Unknown enemy phase plays an unrelated cue")
	check(FileAccess.get_file_as_string("res://export_presets.cfg").contains("assets_external/audio/authored/*.ogg"), "Audio pack omits authored clips")
	check(FileAccess.get_file_as_string("res://scripts/hud.gd").contains("Dark Ambience Loop by Iwan Gabovitch"), "Required ambience attribution is missing from Credits")
	audio.play_event_limited("village_crow", 14.0, 0.0)
	var crow_expiry := int(audio.event_cooldowns.get("village_crow", 0))
	check(crow_expiry > Time.get_ticks_usec(), "Crow accent has no active cooldown")
	audio.play_event_limited("village_crow", 14.0, 0.0)
	check(int(audio.event_cooldowns.get("village_crow", 0)) == crow_expiry, "Crow accent stacked during its recording")
	audio.play_event("record_page", 0.0)
	check(audio.transient_players.any(func(player: AudioStreamPlayer) -> bool: return player.playing), "Ledger page cue did not play")
	var game := Game.new()
	var actor := Node3D.new()
	var captured_audio := SurfaceAudio.new()
	var bridge := BridgeProbe.new()
	root.add_child(actor)
	game.player = actor
	game.audio = captured_audio
	game.spatial_service = bridge
	actor.position = Vector3(0, 0, 4.5)
	bridge.on_bridge = true
	game.call("_on_player_footstep")
	check(captured_audio.last_surface == "wood", "Greyfen bridge did not select the wood footstep")
	bridge.on_bridge = false
	game.call("_on_player_footstep")
	check(captured_audio.last_surface == "road", "Greyfen road did not restore the road footstep")
	game.current_zone_id = "record_hall"
	game.call("_on_player_footstep")
	check(captured_audio.last_surface == "stone", "Record Hall did not select the stone footstep")
	game.zone_residency.free()
	game.zone_residency = null
	game.free()
	root.remove_child(actor)
	actor.free()
	captured_audio.free()
	bridge.free()
	audio.set_game_paused(true)
	check(not audio.transient_players.any(func(player: AudioStreamPlayer) -> bool: return player.playing), "World cue continued through pause")
	audio.stop_zone_audio()
	audio.stop_voice()
	root.remove_child(audio)
	audio.free()
	for _frame in range(6):
		await process_frame
	RenderingServer.force_sync()
	OS.delay_msec(180)
	print("AUDIO-001 AUTHORED VERIFIER: %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
