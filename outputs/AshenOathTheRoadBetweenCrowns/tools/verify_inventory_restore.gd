extends SceneTree

const Inventory = preload("res://scripts/inventory_manager.gd")
const Vendors = preload("res://scripts/vendor_service.gd")
const Saves = preload("res://scripts/save_manager.gd")
var failures := 0

func _initialize() -> void:
	var inventory := Inventory.new()
	var vendors := Vendors.new()
	var saves := Saves.new()
	inventory.load_items("res://data/items.json")
	inventory.load_state({"items": {"standard_arrow": 1000, "bodkin_arrow": 1000, "ashfire_arrow": 1000}, "coin": -20})
	for id in ["standard_arrow", "bodkin_arrow", "ashfire_arrow"]:
		check(inventory.get_ammo_count(id) == inventory.get_ammo_cap(id), "Restored ammunition must obey its capacity: " + id)
	check(inventory.coin == 0, "Saved currency must not become negative")
	var restored := saves.migrate_save_data({"vendors": {"emergency_refill_claimed": true}})
	vendors.load_state(restored.vendors)
	check(vendors.emergency_refill_claimed, "Save migration must preserve the claimed emergency refill")
	for invalid in [[], {}, null, true, "3", INF, NAN, 1.5]:
		inventory.load_state({"items": {"standard_arrow": invalid}, "ingredients": {"redroot": invalid}, "coin": invalid})
		check(inventory.get_ammo_count("standard_arrow") == 0 and inventory.ingredients.redroot == 0 and inventory.coin == 0, "Malformed quantities must not crash or manufacture items")
	for invalid in [[], {}, null, 1, "true"]:
		vendors.load_state({"emergency_refill_claimed": invalid})
		check(not vendors.emergency_refill_claimed, "Malformed refill flag must not masquerade as a boolean")
	inventory.load_state({"items": {"standard_arrow": 4.0, "moon_oil": 1}, "active_oil": "moon_oil", "coin": 12.0})
	check(inventory.get_ammo_count("standard_arrow") == 4 and inventory.coin == 12 and inventory.active_oil == "moon_oil", "Valid JSON inventory must survive")
	vendors.load_state(restored.vendors)
	check(not vendors.claim_emergency_arrow_refill("tor_forge", inventory).ok, "Restored claimed refill must actually deny repeat redemption")
	vendors.load_vendors("res://data/vendors.json")
	var purchase := vendors.buy("tor_forge", "standard_arrow", 2, inventory)
	check(purchase.ok and inventory.coin == 10 and inventory.get_ammo_count("standard_arrow") == 6, "Restored inventory must support an exact shop transaction")
	var refused := vendors.buy("tor_forge", "standard_arrow", 18, inventory)
	check(not refused.ok and inventory.coin == 10 and inventory.get_ammo_count("standard_arrow") == 6, "Unaffordable purchase must leave restored state unchanged")
	var snapshot := inventory.save_state()
	inventory.add_item("standard_arrow", 1)
	inventory.ingredients.redroot = 99
	check(snapshot.items.standard_arrow == 6 and snapshot.ingredients.redroot != 99, "Saved inventory must not alias mutable live dictionaries")
	var clean := Inventory.new()
	clean.load_items("res://data/items.json")
	var sparse := {"items": {"redroot_potion": 1}, "ingredients": {"redroot": 1}}
	clean.load_state(sparse)
	inventory.items["stale_session_item"] = 3
	inventory.coin = 999
	inventory.load_state(sparse)
	check(inventory.save_state() == clean.save_state(), "Sparse legacy restore must not inherit the previous session inventory")
	clean.free()
	inventory.free()
	vendors.free()
	saves.free()
	print("INVENTORY RESTORE: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
