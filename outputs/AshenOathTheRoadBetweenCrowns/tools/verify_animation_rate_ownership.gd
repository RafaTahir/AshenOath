extends SceneTree

const Driver = preload("res://scripts/character_animation_driver.gd")
var steps := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var stage := Node.new()
	root.add_child(stage)
	var player := AnimationPlayer.new()
	stage.add_child(player)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library := AnimationLibrary.new()
	var clip := Animation.new()
	clip.length = 2.0
	library.add_animation("test", clip)
	player.add_animation_library("", library)
	var driver := Driver.new()
	stage.add_child(driver)
	driver.animation_players.append(player)
	driver.animation_player = player
	driver.locomotion_step.connect(func(_foot): steps += 1)
	var passed := true
	for rate in [0.7, 1.22, 4.5]:
		for direction in [1.0, -1.0]:
			driver.current_playback_scale = rate
			driver._play_clip_all(&"test", 0.0, direction)
			player.advance(0.1)
			var expected: float = rate * 0.1 if direction > 0 else 2.0 - rate * 0.1
			passed = passed and is_equal_approx(player.current_animation_position, expected)
			print("RATE ", rate, " direction=", direction, " position=", player.current_animation_position, " expected=", expected)
	clip.loop_mode = Animation.LOOP_LINEAR
	driver.resolved_clip_map["walk"] = "test"
	driver.resolved_clip_map["walk_back"] = "test"
	for direction in [1.0, -1.0]:
		driver.current_state = "walk" if direction > 0 else "walk_back"
		driver.current_playback_scale = 1.0
		driver._play_clip_all(&"test", 0.0, direction)
		driver._emit_locomotion_step_events()
		var before := steps
		for frame in range(61):
			player.advance(1.0 / 30.0)
			driver._emit_locomotion_step_events()
		passed = passed and steps - before == 2
		print("STEP CLOCK direction=", direction, " events=", steps - before)
		driver.action_active = true
		player.advance(0.6)
		driver._emit_locomotion_step_events()
		passed = passed and steps - before == 2
		driver.action_active = false
	stage.free()
	print("ANIMATION RATE OWNERSHIP: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
