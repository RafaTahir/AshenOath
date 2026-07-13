extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_assert(packed != null, "main scene is unavailable")
	if packed == null:
		_finish()
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _frames(6)

	var player = game.player
	_assert(player != null, "Kael did not spawn")
	if player != null:
		_verify_driver(player.animation_driver, "Kael", ["idle", "walk", "run", "jump", "attack_light", "attack_heavy", "dodge", "parry", "beam_cast", "hit", "death"])
		_assert(player.find_child("KaelSwordSocket", true, false) is BoneAttachment3D, "Kael's drawn sword is not bone-attached")
		_assert(player.find_child("KaelBackSwordSocket", true, false) is BoneAttachment3D, "Kael's sheathed sword is not bone-attached")
		_assert(_has_bone_attachment_ancestor(player.rig_sword_visual), "Kael's sword is detached from the hand socket")
		_assert(_has_bone_attachment_ancestor(player.sheathed_sword_visual), "Kael's sheathed sword is detached from the back socket")
		_verify_equipment_scale(player.rig_sword_visual, "drawn sword")
		_verify_equipment_scale(player.sheathed_sword_visual, "sheathed sword")
		_assert(not _has_proxy_anatomy(player), "Kael still contains proxy-box anatomy")
		_verify_locomotion_cadence(player.animation_driver)

	var anwen = game.zone_root.find_child("sister_anwen", true, false)
	_assert(anwen != null, "Sister Anwen did not spawn")
	if anwen != null:
		var anwen_driver = anwen.find_child("CharacterAnimationDriver", true, false)
		_verify_driver(anwen_driver, "Sister Anwen", ["idle", "walk", "run", "hit", "death"])
		_assert(_active_clip_contains(anwen_driver, "idle"), "Sister Anwen is not playing her resolved idle")

	var life = game.zone_root.find_child("GreyfenLifeController", true, false)
	_assert(life != null and life.actors.size() >= 7, "Greyfen's seven animation-driven routines are missing")
	if life != null:
		for entry in life.actors:
			_verify_driver(entry.driver, str(entry.id), ["idle", "walk"])

	game.call("_load_zone", "wychwood", Vector3(0, 0.9, 9))
	await _frames(6)
	_assert(game.active_enemies.size() == 5, "Wychwood's five animated enemies are missing")
	for enemy in game.active_enemies:
		_verify_driver(enemy.animation_driver, str(enemy.enemy_id), ["idle", "walk", "run", "attack", "hit", "death"])
		_assert(not _has_proxy_anatomy(enemy), "%s contains proxy anatomy" % enemy.enemy_id)

	game.queue_free()
	await process_frame
	_finish()

func _verify_driver(driver, label: String, required_states: Array[String]) -> void:
	_assert(driver != null and driver.has_method("get_contract_report"), "%s has no shared animation driver" % label)
	if driver == null or not driver.has_method("get_contract_report"):
		return
	if driver.has_method("set_distance_suspended"):
		driver.set_distance_suspended(false)
	var report: Dictionary = driver.get_contract_report()
	_assert(bool(report.get("valid", false)), "%s animation contract is invalid: %s" % [label, report.get("errors", [])])
	var states: Dictionary = report.get("states", {})
	for state in required_states:
		_assert(states.has(state) or driver.get_clip_for_state(state) != StringName(), "%s has no resolved %s clip" % [label, state])
	var player := driver.get_animation_player() as AnimationPlayer
	_assert(player != null and player.active, "%s AnimationPlayer is inactive at inspection distance" % label)
	_assert(driver.get_skeleton() != null and driver.get_skeleton().get_bone_count() > 0, "%s has no animated skeleton" % label)

func _verify_locomotion_cadence(driver) -> void:
	driver.set_locomotion(0.32, Vector3.FORWARD, true)
	var slow_scale: float = driver.target_playback_scale
	driver.set_locomotion(0.68, Vector3.FORWARD, true)
	var fast_scale: float = driver.target_playback_scale
	driver.set_locomotion(1.0, Vector3.FORWARD, true)
	var run_scale: float = driver.target_playback_scale
	_assert(slow_scale >= 0.68 and slow_scale < fast_scale, "walk cadence does not scale with movement speed")
	_assert(fast_scale <= 1.22 and run_scale >= 0.88 and run_scale <= 1.20, "locomotion cadence exceeds the safe playback range")
	driver.set_locomotion(0.0, Vector3.ZERO, true)

func _active_clip_contains(driver, state: String) -> bool:
	if driver == null:
		return false
	if driver.has_method("set_distance_suspended"):
		driver.set_distance_suspended(false)
	driver.set_locomotion(0.0, Vector3.ZERO, true)
	var player := driver.get_animation_player() as AnimationPlayer
	var resolved: StringName = driver.get_clip_for_state(state)
	return player != null and resolved != StringName() and player.current_animation == resolved

func _has_proxy_anatomy(node: Node) -> bool:
	var forbidden := ["faceplane", "motionarm", "motionleg", "weaponarm", "longarm", "clawleft", "clawright", "chestread", "bootread"]
	for child in node.find_children("*", "", true, false):
		var normalized := str(child.name).to_lower().replace("_", "").replace(" ", "")
		for token in forbidden:
			if normalized.contains(token):
				return true
	return false

func _has_bone_attachment_ancestor(node: Node) -> bool:
	var ancestor := node
	while ancestor != null:
		if ancestor is BoneAttachment3D:
			return true
		ancestor = ancestor.get_parent()
	return false

func _verify_equipment_scale(equipment: Node3D, label: String) -> void:
	_assert(equipment != null, "Kael's %s is missing" % label)
	if equipment == null:
		return
	var world_scale := equipment.global_basis.get_scale()
	_assert(world_scale.x < 100.0 and world_scale.y < 100.0 and world_scale.z < 100.0, "Kael's %s inherited an oversized rig scale: %s" % [label, world_scale])

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _finish() -> void:
	if failures.is_empty():
		print("ANIM-001 VERIFIER: PASS")
		quit()
		return
	print("ANIM-001 VERIFIER: FAIL (%d)" % failures.size())
	quit(1)
