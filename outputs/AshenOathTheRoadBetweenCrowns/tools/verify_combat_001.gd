extends SceneTree

var failures := 0

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Main scene missing")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await settle(5)

	var player = game.player
	check(player != null, "Player missing")
	check(player.has_signal("blade_contact_requested"), "Player lacks authoritative blade-contact signal")
	check(player.find_child("BladeContactBase", true, false) != null, "Sword hilt contact marker missing")
	check(player.find_child("BladeContactTip", true, false) != null, "Sword tip contact marker missing")
	var segment: Dictionary = player.get_blade_world_segment()
	var blade_base: Vector3 = segment.get("base", Vector3.ZERO)
	var blade_tip: Vector3 = segment.get("tip", Vector3.ZERO)
	check(blade_base.distance_to(blade_tip) > 0.75, "Measured blade segment is too short")
	check(blade_tip.distance_to(player.global_position) < 2.5, "Measured blade tip is detached from Kael")

	game.call("_load_zone", "wychwood", Vector3(0, 1, -4))
	await settle(5)
	check(not game.active_enemies.is_empty(), "Wychwood combat pack missing")
	if not game.active_enemies.is_empty():
		var enemy = game.active_enemies[0]
		enemy.set_encounter_active(true)
		enemy.set_physics_process(false)
		player.set_physics_process(false)
		segment = player.get_blade_world_segment()
		blade_base = segment.get("base", player.global_position + Vector3(0, 1, 0))
		blade_tip = segment.get("tip", blade_base)
		var sweep_center := blade_base.lerp(blade_tip, 0.72)
		enemy.global_position = Vector3(sweep_center.x, player.global_position.y, sweep_center.z)
		var health_before: float = enemy.health_component.health
		var contact := {
			"base": blade_base, "tip": blade_tip,
			"previous_base": blade_base, "previous_tip": blade_tip,
			"damage": 24.0, "reach": 2.0, "heavy": false
		}
		var result: Dictionary = game.combat.resolve_player_blade_contact(player, [enemy], contact, "")
		check(bool(result.get("hit", false)), "Blade sweep did not hit an enemy intersecting the sword")
		check(enemy.health_component.health < health_before, "Blade contact did not apply damage")
		var damage_after_hit: float = enemy.health_component.health
		var miss_offset := Vector3(3.2, 0, 0)
		contact.base = blade_base + miss_offset
		contact.tip = blade_tip + miss_offset
		contact.previous_base = contact.base
		contact.previous_tip = contact.tip
		result = game.combat.resolve_player_blade_contact(player, [enemy], contact, "")
		check(not bool(result.get("hit", false)), "Off-target blade sweep incorrectly used the old radius hit")
		check(is_equal_approx(enemy.health_component.health, damage_after_hit), "Missed sweep applied damage")

		var contact_state := {"count": 0}
		player.blade_contact_requested.connect(func(_contact: Dictionary): contact_state.count += 1)
		player.attack_anim_time = 0.16
		player.call("_begin_blade_attack", 24.0, 2.0, false)
		player.call("_update_blade_contact")
		player.call("_update_blade_contact")
		check(int(contact_state.count) == 1, "One sword attack did not emit exactly one contact event")

		var parry_state := {"position": Vector3.ZERO, "resolved": false}
		enemy.attack_resolved.connect(func(_enemy: Node, parried: bool, position: Vector3):
			parry_state.resolved = parried
			parry_state.position = position
		)
		enemy.global_position = player.global_position + Vector3(0, 0, -1.0)
		player.parry_window = 0.24
		enemy.call("_resolve_attack")
		check(bool(parry_state.resolved), "Timed parry did not resolve through enemy contact")
		var resolved_parry_position: Vector3 = parry_state.position
		check(resolved_parry_position.distance_to(player.global_position + Vector3(0, 1.0, 0)) < 1.2, "Parry contact point is detached from the weapons")
		check(enemy.stagger_time >= 1.0, "Parry did not stagger the attacker")

	print("COMBAT-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func settle(count: int) -> void:
	for _index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
