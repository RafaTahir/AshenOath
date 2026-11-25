extends SceneTree
## Verifies authored streams and their real audio/pause/perception owners.

var failures: Array[String] = []
var heard: Array[bool] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	var audio := preload("res://scripts/audio_manager.gd").new()
	root.add_child(audio)
	audio.perception_cue.connect(func(_point: Vector3, _radius: float, urgent: bool) -> void: heard.append(urgent))
	# Both strikes have two closely spaced blows followed by a delayed third.
	for score: Array in [["wychwood_road_call", [0.018, 0.223, 0.772]], ["wychwood_road_answer", [0.055, 0.312, 0.955]]]:
		var cue := str(score[0])
		var stream := audio.prepared_audio.stream("cues", cue) as AudioStreamWAV
		check(stream != null, "Prepared cue missing: " + cue)
		if stream == null: continue
		check(stream.resource_name == cue and not stream.stereo and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Invalid spatial one-shot " + cue)
		for beat: float in score[1]:
			var impact := energy(stream, beat, 0.035)
			check(impact > 0.1 and energy(stream, beat+0.135, 0.02) < impact*0.15, "Unreadable strike in " + cue)
	audio.set_game_paused(true)
	audio.set_dialogue_active(true)
	audio.play_wychwood_dialogue_knock("wychwood_road_call", Vector3.ZERO, Vector3.ZERO)
	var ring := find_cue(audio, "wychwood_road_call")
	check(ring != null and ring.playing and not ring.stream_paused, "Axle must sound during dialogue")
	audio.set_dialogue_review_paused(true)
	await physics_frame
	await process_frame
	await physics_frame
	check(ring != null and ring.stream_paused, "History must pause the current strike")
	audio.set_dialogue_review_paused(false)
	audio.play_wychwood_dialogue_knock("wychwood_road_answer", Vector3(4, 1, -5), Vector3.ZERO)
	var reply := find_cue(audio, "wychwood_road_answer")
	check(reply != null and reply.playing and reply.global_position.is_equal_approx(Vector3(4,1,-5)), "Reply must originate on the far bank")
	check(reply != null and ring != null and reply.volume_db < ring.volume_db, "Far bank should sound farther away")
	check(heard.is_empty(), "The conversation should not alert a dormant wave")
	var reply_point := Vector3(4,1,-5)
	var give := {"id":"wychwood_road_grant", "source":Vector3.ZERO, "listener":Vector3.ZERO}
	var receive := {"id":"wychwood_road_ack", "source":reply_point, "listener":Vector3.ZERO}
	audio.play_dialogue_page({"road_knocks":[give,receive]})
	check(find_cue(audio,"wychwood_road_grant") != null and find_cue(audio,"wychwood_road_ack") != null, "An offered hand needs a strike on each bank")
	audio.play_dialogue_page({"road_knocks":[receive]})
	var near := find_cue(audio,"wychwood_road_grant")
	check(near == null or not near.playing, "Silence must leave Kael's bank quiet")
	reply = find_cue(audio,"wychwood_road_ack")
	check(reply != null and reply.playing and reply.global_position.is_equal_approx(reply_point), "The Raider can answer a silent player")
	audio.set_dialogue_active(false)
	check(reply != null and not reply.playing and ring != null and not ring.playing, "Closing dialogue must release both knocks")
	audio.set_game_paused(false)
	for species: String in ["wychwood_stalker", "wychwood_raider", "wychwood_brute"]:
		var warning := audio.enemy_event_name(species, "windup")
		var stream := audio.prepared_audio.stream("cues", warning) as AudioStreamWAV
		check(stream != null and stream.get_length() < 0.75, "Missing timed windup for " + species)
		audio.play_enemy_event(species, "windup", Vector3.ZERO, Vector3.ZERO)
		audio.play_enemy_event(species, "attack", Vector3.ZERO, Vector3.ZERO)
	check(heard == [false,true,false,true,false,true], "Strike and warning perception should retain their urgency")
	check(audio.enemy_event_name("ghoulkin", "attack") == "ghoulkin_lunge", "Ghoulkin lost its native vocal cue")
	audio.free()
	camera.free()
	print("WYCHWOOD ROAD AUDIO: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func find_cue(audio: Node, id: String) -> AudioStreamPlayer3D:
	for player: AudioStreamPlayer3D in audio.spatial_players:
		if player.stream != null and player.stream.resource_name == id: return player
	return null

func energy(wav: AudioStreamWAV, seconds: float, length: float) -> float:
	var pcm := wav.data
	var start := roundi(seconds*wav.mix_rate)
	var count := roundi(length*wav.mix_rate)
	var total := 0.0
	for i in range(start, start+count):
		total += pow(float(pcm.decode_s16(i*2))/32768.0, 2)
	return sqrt(total/count)
