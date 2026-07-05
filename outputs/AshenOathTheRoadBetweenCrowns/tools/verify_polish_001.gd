extends SceneTree

var failures := 0

func _initialize() -> void:
	var scene = load("res://scenes/main.tscn")
	check(scene != null, "Main scene missing")
	if scene == null: quit(1); return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await settle(5)

	var life = game.zone_root.find_child("GreyfenLifeController", true, false)
	check(life != null, "Greyfen life controller missing")
	if life != null:
		for entry in life.actors:
			if not bool(entry.get("named", false)):
				check(_find_type(entry.node, "Skeleton3D") != null, "Ambient villager %s is not skeletal" % entry.id)
				var driver = entry.node.find_child("CharacterAnimationDriver", true, false)
				check(driver != null and driver.is_valid(), "Ambient villager %s lacks active animation" % entry.id)

	var anwen = game.zone_root.find_child("sister_anwen", true, false)
	check(anwen != null and _find_type(anwen, "Skeleton3D") != null, "Sister Anwen is not a rigged human")
	check(anwen != null and anwen.find_child("SisterAnwenGoldStole", true, false) != null, "Anwen role colors/details are missing")
	if anwen != null:
		game.player.global_position = anwen.global_position + Vector3(0.8, 0, 1.4)
		game.call("_stage_dialogue_moment", anwen)
		var locked_yaw = anwen.rotation.y
		var ambient = anwen.find_child("NpcAmbient", true, false)
		if ambient != null: ambient.call("_process", 0.5)
		check(bool(anwen.get_meta("dialogue_facing_lock", false)), "Anwen dialogue facing lock was not set")
		check(abs(angle_difference(locked_yaw, anwen.rotation.y)) < 0.01, "Anwen turned away while dialogue facing was locked")

	check(game.player.find_child("PlayerFacePlane", true, false) != null, "Kael face presentation is missing")
	check(game.player.find_child("OathfireLeftHand", true, false) != null and game.player.find_child("OathfireRightHand", true, false) != null, "Oathfire hand choreography nodes are missing")
	check(game.player.find_child("OathfireSheathedSword", true, false) != null, "Oathfire sheathed sword state is missing")
	check(game.player.find_child("visible_sword_slash_arc_root", true, false) != null, "Sword-aligned slash trail is missing")
	var rig_sword = game.player.find_child("Warrior_Sword", true, false)
	check(rig_sword != null, "Kael rig sword is missing")
	game.player.call("_set_sword_sheathed", true)
	check(rig_sword == null or not rig_sword.visible, "Oathfire does not hide Kael's rigged sword")
	check(game.player.find_child("OathfireSheathedSword", true, false).visible, "Oathfire back sheath is not visible")
	game.player.call("_set_sword_sheathed", false)

	game.player.parry_window = 0.24
	var health_before = game.player.health_component.health
	check(game.player.take_damage(20.0), "Timed parry did not resolve")
	check(is_equal_approx(game.player.health_component.health, health_before), "Successful parry dealt player damage")

	game.call("_load_zone", "wychwood", Vector3(0,1,8))
	await settle(4)
	var profiles := {}
	for enemy in game.active_enemies: profiles[enemy.enemy_id] = enemy.behavior_profile
	check(profiles.get("ghoulkin", "") == "skirmisher", "Ghoulkin behavior profile missing")
	check(profiles.get("wychwood_stalker", "") == "flanker", "Stalker behavior profile missing")
	check(profiles.get("wychwood_raider", "") == "feinter", "Raider behavior profile missing")
	check(profiles.get("wychwood_brute", "") == "brute", "Brute behavior profile missing")

	print("POLISH-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func settle(count: int) -> void:
	for i in range(count): await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _find_type(node: Node, type_name: String):
	if node.is_class(type_name): return node
	for child in node.get_children():
		var found = _find_type(child, type_name)
		if found != null: return found
	return null
