extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var manager := preload("res://scripts/progression_manager.gd").new()
	root.add_child(manager)
	manager.load_definitions()
	var first: String = manager.ordered_upgrade_ids()[0]
	var passed := true
	for value in [null, "99", {}, true, NAN, INF, 1.5]:
		manager.load_state({"marks":value, "unlocked":{first:"false"}, "rewarded_quests":{"main_fixture":"false"}})
		passed = passed and manager.marks == 0 and manager.unlocked.is_empty() and manager.rewarded_quests.is_empty()
	manager.load_state({"marks":1e30})
	passed = passed and manager.marks == manager.MASTERY_MARK_LIMIT
	manager.load_state({"marks":2.0, "unlocked":{first:true}, "rewarded_quests":{"main_road_of_crows":true}, "claimed_rewards":{"quest:main_road_of_crows":{"xp":400}}})
	passed = passed and manager.marks == 2 and manager.has_upgrade(first)
	passed = passed and not manager.award_for_quest("main_road_of_crows", "main") and manager.marks == 2
	check(passed, "Progression restore accepted malformed values or changed valid rewards")
	check(manager.level_cap() == 30 and manager.definitions.size() == 20, "Expected level 30 and 20 practices")
	check(manager.rules.mark_levels.size() == 17, "Expected 17 once-only Mark milestones")
	for level in range(1, 21):
		var steps: int = level - 1
		check(manager.xp_for_level(level) == steps * 200 + steps * (steps - 1) * 25, "Retained level threshold changed: %d" % level)
	manager.load_state({})
	for prefix in ["gre", "wyc", "dep", "roa", "var", "har"]:
		for index in range(1, 6):
			var id := "saga_%s_q%02d" % [prefix, index]
			check(manager.rules.quests.has(id), "Missing additive quest XP: " + id)
			check(int(manager.rules.quests.get(id, {}).get("xp", 0)) == [300, 350, 250, 300, 500][index - 1], "Incorrect regional quest XP: " + id)
			var previous: int = manager.total_xp
			check(manager.award_for_quest(id, "side", true), "First legitimate completion claim failed: " + id)
			check(not manager.award_for_quest(id, "side", true), "Repeated completion paid twice: " + id)
			check(manager.total_xp - previous == [300, 350, 250, 300, 500][index - 1], "Completion credited incorrect XP: " + id)
	var saved: Dictionary = manager.save_state()
	manager.load_state(JSON.parse_string(JSON.stringify(saved)))
	check(not manager.award_for_quest("saga_gre_q01", "side", true), "Reload duplicated regional XP")
	manager.award_saga_secret("unit_secret", "greyfen", "Unit-only secret claim")
	var secret_xp: int = manager.total_xp
	manager.award_saga_secret("unit_secret", "greyfen", "Unit-only secret claim")
	check(manager.total_xp == secret_xp, "Repeated secret claim duplicated XP")
	_verify_oils_and_delivery(manager)
	manager.free()
	await process_frame
	print("FINISH-006/017 UNIT CONTRACTS: ", "PASS" if failures.is_empty() else "FAIL")
	print("SCOPE: isolated service assertions; not earned-route, browser, phone or user acceptance")
	quit(0 if failures.is_empty() else 1)

func _verify_oils_and_delivery(manager: Node) -> void:
	var inventory := preload("res://scripts/inventory_manager.gd").new()
	root.add_child(inventory)
	inventory.load_items("res://data/items.json")
	inventory.set_progression(manager)
	check(not inventory.apply_oil("moon_oil"), "Oil applied without a bottle")
	inventory.add_item("moon_oil", 3)
	check(inventory.apply_oil("moon_oil") and int(inventory.items.moon_oil) == 2, "Application must spend exactly one bottle")
	check(is_equal_approx(inventory.oil_remaining_seconds, 300.0), "Base oil duration must be 300 seconds")
	inventory.advance_oil(21.5)
	check(is_equal_approx(inventory.oil_remaining_seconds, 278.5), "Oil countdown lost active-play time")
	check(inventory.apply_oil("moon_oil") and int(inventory.items.moon_oil) == 1 and is_equal_approx(inventory.oil_remaining_seconds, 300.0), "Refresh must replace duration and spend one bottle")
	inventory.add_item("rot_oil", 1)
	check(inventory.apply_oil("rot_oil") and inventory.active_oil == "rot_oil" and int(inventory.items.rot_oil) == 0, "Another oil must replace the coating and consume its last bottle")
	inventory.advance_oil(42.25)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(inventory.save_state()))
	inventory.load_state(saved, false)
	check(inventory.active_oil == "rot_oil" and is_equal_approx(inventory.oil_remaining_seconds, 257.75), "Last-bottle coating/time must survive serialization")
	manager.grant_saga_entitlement("saga_ash_tempered_fitting")
	check(is_equal_approx(inventory.oil_remaining_seconds, 257.75), "Earning the fitting must not refill the current oil")
	check(inventory.apply_oil("moon_oil") and is_equal_approx(inventory.oil_remaining_seconds, 360.0), "Fitting must extend newly applied oil to 360 seconds")
	manager.respec_result()
	check(is_equal_approx(inventory.get_oil_duration_seconds("moon_oil"), 360.0), "Respec must retain the permanent fitting")
	inventory.advance_oil(360.0)
	check(inventory.active_oil == "" and is_zero_approx(inventory.oil_remaining_seconds), "Expiry must clear the coating")
	for bad in [null, "300", -1, 0, NAN, INF, true, {}]:
		inventory.load_state({"active_oil":"moon_oil", "oil_version":1, "oil_remaining_seconds":bad}, false)
		check(inventory.active_oil == "", "Invalid/expired new timer must not refill")
	inventory.load_state({"active_oil":"moon_oil"}, true)
	check(inventory.active_oil == "moon_oil" and is_equal_approx(inventory.oil_remaining_seconds, 360.0), "Legacy oil must migrate with the loaded fitting and no new charge")
	inventory.load_state({"active_oil":"moon_oil"}, false)
	check(inventory.active_oil == "", "Missing modern timer must not receive legacy refill")
	inventory.items.standard_arrow = inventory.get_ammo_cap("standard_arrow")
	inventory.deliver_once("unit_overflow", {"items":{"standard_arrow":4}})
	check(inventory.has_pending_delivery("unit_overflow"), "Full quiver must retain pending arrows")
	inventory.items.standard_arrow -= 4
	inventory.deliver_once("unit_overflow", {"items":{"standard_arrow":4}})
	var quantity: int = inventory.items.standard_arrow
	inventory.deliver_once("unit_overflow", {"items":{"standard_arrow":4}})
	check(not inventory.has_pending_delivery("unit_overflow") and int(inventory.items.standard_arrow) == quantity, "Collecting overflow must not repeat delivered arrows")
	inventory.free()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
