extends SceneTree

const ProgressionManager = preload("res://scripts/progression_manager.gd")
const PlayerController = preload("res://scripts/player_controller.gd")
const HealthComponent = preload("res://scripts/health_component.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var progression := ProgressionManager.new()
	root.add_child(progression)
	await process_frame
	_verify_definitions(progression)
	_verify_rewards_and_unlocks(progression)
	_verify_gameplay_values(progression)
	await _verify_roundtrip(progression)
	progression.queue_free()
	await process_frame
	if failures.is_empty():
		print("PROG-001 VERIFIER: PASS (9 upgrades, quest rewards, gameplay effects, save roundtrip)")
		quit()
		return
	print("PROG-001 VERIFIER: FAIL (%d)" % failures.size())
	quit(1)

func _verify_definitions(progression: Node) -> void:
	_check(progression.definitions.size() == 9, "progression does not contain exactly nine upgrades")
	_check(progression.ordered_upgrade_ids().size() == 9, "ordered progression omits or duplicates upgrades")
	for branch in progression.BRANCH_ORDER:
		var branch_count := 0
		for definition in progression.definitions.values():
			if str(definition.get("branch", "")) == branch:
				branch_count += 1
		_check(branch_count == 3, "%s branch does not contain exactly three upgrades" % branch)
	for id in progression.definitions:
		var definition: Dictionary = progression.definitions[id]
		var required := str(definition.get("requires", ""))
		_check(required == "" or progression.definitions.has(required), "%s has a missing prerequisite" % id)

func _verify_rewards_and_unlocks(progression: Node) -> void:
	progression.load_state({})
	_check(not progression.award_for_quest("side_widows_bell", "side"), "side quest awarded an Oath Mark")
	_check(progression.award_for_quest("main_road_of_crows", "main"), "main quest did not award an Oath Mark")
	_check(progression.marks == 1, "main quest did not award exactly one Oath Mark")
	_check(not progression.award_for_quest("main_road_of_crows", "main"), "main quest awarded duplicate Oath Marks")
	_check(not progression.can_unlock("measured_riposte"), "tier-two Blade upgrade ignored its prerequisite")
	_check(progression.unlock("keen_edge"), "available tier-one upgrade could not be learned")
	_check(progression.marks == 0 and progression.has_upgrade("keen_edge"), "learning did not spend one mark")
	_check(not progression.unlock("keen_edge"), "upgrade could be learned twice")
	progression.load_state({
		"marks": 2,
		"unlocked": {"measured_riposte": true, "fell_weight": true},
		"rewarded_quests": {}
	})
	_check(not progression.has_upgrade("measured_riposte"), "invalid save bypassed an upgrade prerequisite")
	_check(not progression.has_upgrade("fell_weight"), "invalid save retained a broken upgrade chain")
	progression.load_state({})
	var reconciled: int = progression.reconcile_completed_quests(
		{
			"main_road_of_crows": {"type": "main"},
			"main_bell_beneath_greyfen": {"type": "main"},
			"side_widows_bell": {"type": "side"}
		},
		{
			"main_road_of_crows": true,
			"main_bell_beneath_greyfen": true,
			"side_widows_bell": true
		}
	)
	_check(reconciled == 2 and progression.marks == 2, "legacy completed main quests did not receive owed Oath Marks")
	_check(progression.reconcile_completed_quests(
		{"main_road_of_crows": {"type": "main"}},
		{"main_road_of_crows": true}
	) == 0, "legacy reconciliation duplicated a rewarded main quest")

func _verify_gameplay_values(progression: Node) -> void:
	var all_unlocked: Dictionary = {}
	for id in progression.definitions:
		all_unlocked[id] = true
	progression.load_state({"marks": 0, "unlocked": all_unlocked, "rewarded_quests": {}})
	var player := PlayerController.new()
	player.health_component = HealthComponent.new()
	player.add_child(player.health_component)
	player.health_component.configure(125.0)
	player.set_progression(progression)
	_check(is_equal_approx(player.health_component.max_health, 145.0), "Hardened Vow did not raise maximum health to 145")
	_check(is_equal_approx(player.get_blade_attack_damage(false), 26.4), "Keen Edge light-attack damage is incorrect")
	_check(is_equal_approx(player.get_blade_attack_damage(true), 55.44), "Blade heavy-upgrade damage is incorrect")
	_check(is_equal_approx(player.get_dodge_stamina_cost(), 23.0), "Sure Step dodge cost is incorrect")
	_check(is_equal_approx(player.get_oathfire_stamina_cost(), 30.0), "Kindled Core Oathfire cost is incorrect")
	_check(is_equal_approx(player.get_oathfire_cooldown_duration(), 3.0), "Ashen Flow cooldown is incorrect")
	_check(is_equal_approx(progression.effect_value("beam_range_bonus"), 2.0), "Far Reach range bonus is incorrect")
	_check(is_equal_approx(progression.effect_value("parry_stamina_restore"), 15.0), "Measured Riposte restoration is incorrect")
	_check(is_equal_approx(progression.effect_value("potion_heal_bonus"), 15.0), "Redroot Lore healing is incorrect")
	player.free()

func _verify_roundtrip(progression: Node) -> void:
	progression.load_state({
		"marks": 3,
		"unlocked": {
			"keen_edge": true,
			"measured_riposte": true,
			"hardened_vow": true,
			"unknown_upgrade": true
		},
		"rewarded_quests": {"main_road_of_crows": true}
	})
	var saved: Dictionary = progression.save_state()
	var restored := ProgressionManager.new()
	root.add_child(restored)
	await process_frame
	restored.load_state(saved)
	_check(restored.marks == 3, "Oath Marks did not survive save/load")
	_check(restored.has_upgrade("keen_edge") and restored.has_upgrade("measured_riposte"), "learned upgrades did not survive save/load")
	_check(not restored.has_upgrade("unknown_upgrade"), "unknown upgrade survived save sanitization")
	_check(bool(restored.rewarded_quests.get("main_road_of_crows", false)), "rewarded quest history did not survive save/load")
	restored.queue_free()

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
