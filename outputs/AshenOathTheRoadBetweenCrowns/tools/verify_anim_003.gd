extends SceneTree

var failures: Array[String] = []
var tested_game: Node = null

func _initialize() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_assert(packed != null, "main scene is unavailable")
	if packed == null:
		_finish()
		return
	tested_game = packed.instantiate()
	root.add_child(tested_game)
	await _frames(2)
	tested_game.call("_new_game")
	await _frames(8)

	var player = tested_game.player
	_assert(player != null, "player did not spawn")
	if player == null:
		_finish()
		return
	var driver = player.animation_driver
	_verify_driver(driver, "Kael")
	if driver != null and driver.has_method("is_valid") and driver.is_valid():
		_verify_locomotion(driver)
		_verify_action_recovery(driver)
		_verify_real_bone_motion(driver, "run", "Kael run")
		_verify_real_bone_motion(driver, "attack_light", "Kael light attack")
		_verify_real_bone_motion(driver, "dodge", "Kael dodge")
		_assert(bool(driver.get_contract_report().get("root_motion_disabled", false)), "root motion contract is not disabled")

	var anwen = tested_game.zone_root.find_child("sister_anwen", true, false)
	_assert(anwen != null, "Sister Anwen did not spawn")
	if anwen != null:
		var anwen_driver = anwen.find_child("CharacterAnimationDriver", true, false)
		_verify_driver(anwen_driver, "Sister Anwen")
		if anwen_driver != null:
			anwen_driver.set_dialogue_pose(true)
			_assert(str(anwen_driver.get_contract_report().get("presentation_state", "")) == "dialogue", "Anwen dialogue pose did not engage")
			anwen_driver.set_dialogue_pose(false)
			_assert(str(anwen_driver.get_contract_report().get("presentation_state", "")) == "", "Anwen dialogue pose did not release")

	var life = tested_game.zone_root.find_child("GreyfenLifeController", true, false)
	_assert(life != null and life.actors.size() >= 7, "Greyfen animation routines are missing")
	if life != null:
		for entry in life.actors:
			var routine_driver = entry.driver
			_verify_driver(routine_driver, str(entry.id))
			if str(entry.id) == "forge_helper" and routine_driver != null:
				routine_driver.set_working(true)
				_assert(str(routine_driver.get_contract_report().get("presentation_state", "")) == "work", "forge helper work pose did not engage")
				routine_driver.set_working(false)

	tested_game.call("_load_zone", "Wychwood", Vector3(0, 0.9, 9))
	await _frames(8)
	_assert(tested_game.active_enemies.size() == 5, "Wychwood's five enemies are missing")
	for enemy in tested_game.active_enemies:
		var enemy_driver = enemy.animation_driver
		_verify_driver(enemy_driver, str(enemy.enemy_id))
		if enemy_driver != null:
			_assert(enemy_driver.get_clip_for_state("windup") != StringName(), "%s has no windup clip" % enemy.enemy_id)
			_verify_real_bone_motion(enemy_driver, "attack", "%s attack" % enemy.enemy_id)

	_finish()

func _verify_driver(driver: Node, label: String) -> void:
	_assert(driver != null and driver.has_method("get_contract_report"), "%s has no animation driver" % label)
	if driver == null or not driver.has_method("get_contract_report"):
		return
	var report: Dictionary = driver.get_contract_report()
	_assert(bool(report.get("valid", false)), "%s animation contract is invalid: %s" % [label, report.get("errors", [])])
	_assert(driver.get_clip_for_state("idle") != StringName(), "%s has no idle clip" % label)
	_assert(driver.get_animation_player() != null, "%s has no AnimationPlayer" % label)
	_assert(driver.get_skeleton() != null and driver.get_skeleton().get_bone_count() > 0, "%s has no Skeleton3D" % label)

func _verify_locomotion(driver: Node) -> void:
	driver.set_locomotion(0.34, Vector3.FORWARD, true)
	var walk_state: String = str(driver.get_locomotion_state())
	driver.set_locomotion(0.34, Vector3.RIGHT, true)
	var strafe_state: String = str(driver.get_locomotion_state())
	driver.set_locomotion(0.34, Vector3.BACK, true)
	var back_state: String = str(driver.get_locomotion_state())
	driver.set_locomotion(0.0, Vector3.ZERO, true)
	_assert(walk_state == "walk" or walk_state == "strafe" or walk_state == "walk_back", "forward locomotion did not select a walk state")
	_assert(strafe_state == "strafe" or driver.get_clip_for_state("strafe") != StringName(), "strafe locomotion has no fallback clip")
	_assert(back_state == "walk_back" or driver.get_clip_for_state("walk_back") != StringName(), "backward locomotion has no fallback clip")
	_assert(float(driver.get_contract_report().get("playback_scale", 0.0)) > 0.0, "locomotion playback scale is invalid")

func _verify_action_recovery(driver: Node) -> void:
	_assert(driver.trigger_action("beam_cast"), "Oathfire action could not start")
	_assert(driver.has_active_action(), "Oathfire action did not enter active state")
	var action_state := str(driver.get_contract_report().get("current_state", ""))
	driver.set_locomotion(0.8, Vector3.FORWARD, true)
	_assert(str(driver.get_contract_report().get("current_state", "")) == action_state, "locomotion interrupted an active action")
	driver.stop_action("idle", 0.0)
	_assert(not driver.has_active_action(), "Oathfire action remained active after stop")
	_assert(str(driver.get_contract_report().get("current_state", "")) == "idle", "action recovery did not return to idle")
	_assert(driver.trigger_action("attack_light"), "light attack action could not start")
	_assert(driver.trigger_action("hit"), "hit reaction could not pre-empt attack")
	driver.stop_action("idle", 0.0)

func _verify_real_bone_motion(driver: Node, state: String, label: String) -> void:
	var clip: StringName = driver.get_clip_for_state(state)
	var player := driver.get_animation_player() as AnimationPlayer
	var skeleton := driver.get_skeleton() as Skeleton3D
	_assert(clip != StringName() and player != null and skeleton != null, "%s has no resolved clip" % label)
	if clip == StringName() or player == null or skeleton == null:
		return
	var was_active := player.active
	player.active = true
	player.play(clip)
	player.seek(0.0, true)
	if player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		player.advance(0.0)
	var before: Array[Transform3D] = []
	for index in range(skeleton.get_bone_count()):
		before.append(skeleton.get_bone_pose(index))
	var animation := player.get_animation(clip)
	var sample_time := minf(0.32, animation.length * 0.55) if animation != null else 0.32
	player.seek(sample_time, true)
	if player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		player.advance(0.0)
	var moved := false
	for index in range(skeleton.get_bone_count()):
		if _transform_delta(before[index], skeleton.get_bone_pose(index)) > 0.002:
			moved = true
			break
	player.active = was_active
	_assert(moved, "%s does not move real skeleton bones" % label)

func _transform_delta(a: Transform3D, b: Transform3D) -> float:
	return a.origin.distance_to(b.origin) + a.basis.x.distance_to(b.basis.x) + a.basis.y.distance_to(b.basis.y)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _finish() -> void:
	if is_instance_valid(tested_game):
		tested_game.free()
	if failures.is_empty():
		print("ANIM-003 VERIFIER: PASS - shared presentation states and real bone motion")
		quit(0)
		return
	print("ANIM-003 VERIFIER: FAIL (%d)" % failures.size())
	for failure in failures:
		print("- %s" % failure)
	quit(1)
