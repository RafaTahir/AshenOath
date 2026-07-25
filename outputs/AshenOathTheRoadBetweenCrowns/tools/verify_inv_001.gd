extends SceneTree

const InventoryManager = preload("res://scripts/inventory_manager.gd")
var failures := 0

func _initialize() -> void:
	var inventory = InventoryManager.new()
	root.add_child(inventory)
	inventory.load_items("res://data/items.json")
	var contract = JSON.parse_string(FileAccess.get_file_as_string("res://preparation_contract.json"))
	check(typeof(contract) == TYPE_DICTIONARY, "Preparation contract is invalid")
	check(inventory.ordered_item_ids().size() == 6, "Released preparation set is incomplete")
	var moon_status := inventory.recipe_status("moon_oil")
	check(not bool(moon_status.craftable), "Moon Oil should not be craftable from the default ingredients")
	check(int(moon_status.missing.get("mooncap", 0)) == 1, "Moon Oil shortage is not reported accurately")
	inventory.add_ingredients({"mooncap": 1})
	check(inventory.can_craft("moon_oil"), "Moon Oil does not become craftable after collecting the missing ingredient")
	check(inventory.craft("moon_oil"), "Moon Oil crafting failed")
	check(inventory.apply_oil("moon_oil"), "Owned oil cannot be prepared")
	check(inventory.active_oil == "moon_oil", "Prepared blade oil was not recorded")
	var saved := inventory.save_state()
	var restored = InventoryManager.new()
	root.add_child(restored)
	restored.load_items("res://data/items.json")
	restored.load_state(saved)
	check(restored.active_oil == "moon_oil", "Prepared oil did not survive save/load")
	restored.load_state({"items": [], "ingredients": [], "active_oil": "missing_oil", "coin": 3})
	check(typeof(restored.items) == TYPE_DICTIONARY, "Malformed legacy items replaced the valid inventory")
	check(restored.active_oil == "", "Invalid legacy oil was retained")
	var summary := inventory.get_preparation_summary()
	check(summary.has("potions") and summary.has("bombs") and summary.has("traps"), "Preparation summary is incomplete")
	print("INV-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
