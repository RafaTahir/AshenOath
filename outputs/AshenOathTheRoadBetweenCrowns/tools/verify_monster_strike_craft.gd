extends SceneTree

## Production strike, player damage, native scythe rig and boss phase commitment.
const Enemy = preload("res://scripts/enemy_ai.gd")
const Player = preload("res://scripts/player_controller.gd")
const Boss = preload("res://scripts/boss_encounter.gd")
var definitions: Dictionary
var bosses: Dictionary
var failures: Array[String] = []
var checks := 0
var stage := Node3D.new()
var player: CharacterBody3D

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures.append(reason)

func _spawn(identity: String, visual: bool) -> CharacterBody3D:
	var actor := Enemy.new(visual)
	stage.add_child(actor)
	actor.setup(identity, definitions[identity], player)
	actor.set_physics_process(false)
	return actor

func _finish(actor: CharacterBody3D, fps: float) -> void:
	while actor.pending_attack_time > 0.0:
		actor.enemy_strike_view._tick_pending_attack(1.0 / fps)

func _run() -> void:
	definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	bosses = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses.json"))
	root.add_child(stage)
	player = Player.new(false)
	stage.add_child(player)
	player.set_physics_process(false)
	for identity: String in definitions:
		var profile: Dictionary = definitions[identity].get("strike", {})
		check(not profile.is_empty(), identity + " has an authored strike")
		if profile.is_empty(): continue
		var enemy := _spawn(identity, false)
		player.position = Vector3.FORWARD * 0.42
		player.health_component.configure(125.0)
		check(enemy._begin_attack(), identity + " arms")
		check(is_equal_approx(enemy.pending_attack_time, profile.windup), identity + " authored tell")
		check(is_equal_approx(enemy.attack_cooldown, profile.cooldown), identity + " authored cadence")
		_finish(enemy, 30.0)
		check(is_equal_approx(enemy.attack_recovery_time, profile.recovery), identity + " authored recovery")
		check(is_equal_approx(125.0 - player.health_component.health, enemy.damage * float(profile.damage_scale)), identity + " damage fires once at contact")
		enemy.free()
	_lunge()
	if "--skip-weapon" not in OS.get_cmdline_user_args():
		_weapon_variants()
		for fps: float in [24.0, 60.0, 120.0]:
			for defense: String in ["open", "block", "parry", "rear", "overhead"]:
				_scythe(fps, defense)
	stage.free()
	print(JSON.stringify({"fixture":"monster_strike_craft", "checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _lunge() -> void:
	var enemy := _spawn("halvern_boss", false)
	var controller := Boss.new()
	controller.name = "BossEncounterController"
	enemy.add_child(controller)
	controller.definition = bosses.halvern_boss
	controller.phase = 2
	player.position = Vector3.FORWARD * 1.8
	player.health_component.configure(125.0)
	var episodes: Array = []
	enemy.special_attack_resolved.connect(func(_actor: Node, id: String, _position: Vector3, _radius: float, damage: float, _parried: bool) -> void:
		episodes.append([id, damage]))
	check(enemy._begin_attack(), "Halvern begins counter-lunge")
	var tell: float = enemy.pending_attack_time
	enemy.enemy_strike_view._tick_pending_attack(tell * 0.65)
	var heading := enemy.rotation.y
	controller.phase = 1
	enemy.damage *= 2.0
	player.position = Vector3.RIGHT * 1.8
	_finish(enemy, 24.0)
	check(episodes == [["counter_lunge", 0.0]], "sidestep releases announced lunge even across a phase change")
	check(is_equal_approx(heading, enemy.rotation.y), "late sidestep leaves committed thrust on its original heading")
	check(is_equal_approx(enemy.attack_recovery_time, definitions.halvern_boss.strike.moves.counter_lunge.recovery), "whiff pays the lunge recovery")
	check(is_equal_approx(player.health_component.health, 125.0), "sidestep avoids damage")
	check(enemy._boss_attack_id() == "parry_test", "next attack uses the new phase")
	controller.phase = 2
	player.position = Vector3.FORWARD * 1.8
	enemy.damage = float(definitions.halvern_boss.damage)
	enemy._begin_attack()
	controller.phase = 1
	enemy.damage *= 1.5
	_finish(enemy, 30.0)
	var expected: float = float(definitions.halvern_boss.damage) * float(definitions.halvern_boss.strike.moves.counter_lunge.damage_scale) * 0.72
	check(is_equal_approx(125.0 - player.health_component.health, expected), "mid-windup phase change preserves announced lunge damage")
	enemy.free()

func _weapon_variants() -> void:
	var knight := _spawn("gravebound_knight", true)
	var halvern := _spawn("halvern_boss", true)
	var plate := knight.find_child("M04_FittedArmourAssembly", true, false) as MeshInstance3D
	var original := halvern.find_child("M04_FittedArmourAssembly", true, false) as MeshInstance3D
	check(plate != null and original != null, "Both equipped knights retain the native skinned plate")
	if plate != null and original != null:
		var source_faces: int = original.mesh.surface_get_array_index_len(0) / 3
		check(source_faces == 18705 and plate.mesh.surface_get_array_index_len(0) == 3 * (source_faces - 532), "Only the scythe-bearing knight relinquishes the original sword")
		check(original.mesh.surface_get_array_index_len(1) == plate.mesh.surface_get_array_index_len(1), "Funerary linen topology retained")
		for i in 2:
			check(plate.get_active_material(i) != null and plate.get_active_material(i).resource_name == original.get_active_material(i).resource_name, "Original equipped armour material %d" % i)
	check(halvern.find_child("GraveTitheGrip", true, false) == null and halvern.find_child("*AuthoredSword", true, false) == null, "Halvern carries the one sword embedded in his rig")
	knight.free()
	halvern.free()

func _scythe(fps: float, defense: String) -> void:
	var enemy := _spawn("gravebound_knight", true)
	var label := "Gravebound %s at %d Hz" % [defense, int(fps)]
	var edge: PackedVector3Array = enemy.enemy_equipment_view.weapon_edge()
	check(edge.size() == 2 and edge[0].distance_to(edge[1]) > 0.4, label + " uses the equipped cutting edge")
	if edge.size() != 2:
		enemy.free()
		return
	player.position = Vector3.FORWARD * 1.45
	player.health_component.configure(125.0)
	player.stamina_component.stamina = 100.0
	player.parry_window = 0.0
	check(enemy._begin_attack(), label + " arms")
	var windup: float = enemy.pending_attack_time
	enemy.enemy_strike_view._tick_pending_attack(windup * 0.65)
	match defense:
		"block":
			player.sword_sheathed = false
			if not InputMap.has_action("block"): InputMap.add_action("block")
			Input.action_press("block")
		"parry": player.parry_window = player.get_parry_window_duration()
		"rear": player.position = Vector3.BACK * 1.0
		"overhead": player.position.y = 3.0
	_finish(enemy, fps)
	var loss: float = 125.0 - player.health_component.health
	var damage: float = enemy.damage * float(definitions.gravebound_knight.strike.damage_scale)
	match defense:
		"open": check(is_equal_approx(loss, damage), label + " deals full sweep damage")
		"block": check(loss > 0.0 and loss < damage and player.stamina_component.stamina < 100.0, label + " spends guard stamina and reduces damage")
		"parry": check(is_zero_approx(loss) and enemy.parry_exposed_time > 1.0, label + " exposes the attacker")
		_: check(is_zero_approx(loss) and enemy.attack_recovery_time >= 1.0, label + " misses and remains punishable")
	if defense == "block": Input.action_release("block")
	enemy.free()
