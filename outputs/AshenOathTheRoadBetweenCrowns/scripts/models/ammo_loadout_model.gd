class_name AmmoLoadoutModel
extends RefCounted

const FAMILY_IDS: Array[String] = ["standard_arrow", "bodkin_arrow", "ashfire_arrow"]
const FAMILY_CAPS: Dictionary = {"standard_arrow": 24, "bodkin_arrow": 9, "ashfire_arrow": 6}
const MAX_QUANTITY: int = 2147483647
var counts: Dictionary = {"standard_arrow": 0, "bodkin_arrow": 0, "ashfire_arrow": 0}
var overflow: Dictionary = {"standard_arrow": 0, "bodkin_arrow": 0, "ashfire_arrow": 0}
var selected_family: String = "standard_arrow"

static func quantity(value: Variant) -> int:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return 0
	var number: float = float(value)
	return int(clampf(number, 0.0, MAX_QUANTITY)) if is_finite(number) and number == floorf(number) else 0

func cap(item_id: String) -> int:
	return int(FAMILY_CAPS.get(item_id, 0))

func count(item_id: String) -> int:
	return int(counts.get(item_id, 0))

func quiver_capacity() -> int:
	var total: int = 0
	for id: String in FAMILY_IDS:
		total += cap(id)
	return total

func select(item_id: String) -> bool:
	if item_id not in FAMILY_IDS or count(item_id) <= 0:
		return false
	selected_family = item_id
	return true

func cycle() -> String:
	var start: int = FAMILY_IDS.find(selected_family)
	for offset: int in range(1, FAMILY_IDS.size() + 1):
		var candidate: String = FAMILY_IDS[(maxi(start, 0) + offset) % FAMILY_IDS.size()]
		if count(candidate) > 0:
			selected_family = candidate
			return candidate
	selected_family = "standard_arrow"
	return selected_family

func consume(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or item_id not in FAMILY_IDS or count(item_id) < amount:
		return false
	counts[item_id] = count(item_id) - amount
	if count(selected_family) == 0:
		cycle()
	return true

func pickup(item_id: String, amount: int) -> Dictionary:
	var accepted: int = 0
	if item_id in FAMILY_IDS and amount > 0:
		accepted = mini(amount, maxi(0, cap(item_id) - count(item_id)))
		counts[item_id] = count(item_id) + accepted
	return {"item_id": item_id, "accepted": accepted, "overflow": maxi(0, amount - accepted)}

func claim_overflow(item_id: String) -> int:
	var result: Dictionary = pickup(item_id, int(overflow.get(item_id, 0)))
	overflow[item_id] = int(result.overflow)
	return int(result.accepted)

func save_state() -> Dictionary:
	return {"version": 1, "counts": counts.duplicate(), "selected_family": selected_family,
		"overflow": overflow.duplicate()}

func load_state(state: Dictionary) -> void:
	var saved_counts: Dictionary = state.get("counts", {}) if state.get("counts", {}) is Dictionary else {}
	var saved_overflow: Dictionary = state.get("overflow", {}) if state.get("overflow", {}) is Dictionary else {}
	overflow = saved_overflow.duplicate(true)
	for id: String in FAMILY_IDS:
		var saved: int = quantity(saved_counts.get(id, 0))
		counts[id] = mini(saved, cap(id))
		overflow[id] = mini(MAX_QUANTITY, quantity(saved_overflow.get(id, 0)) + maxi(0, saved - cap(id)))
	var selected: String = str(state.get("selected_family", "standard_arrow"))
	selected_family = selected if selected in FAMILY_IDS else "standard_arrow"
	if count(selected_family) == 0:
		cycle()

func load_inventory(inventory: Dictionary) -> void:
	var state: Dictionary = inventory.get("ammo_loadout", {}).duplicate(true) if inventory.get("ammo_loadout", {}) is Dictionary else {}
	var items: Dictionary = inventory.get("items", {}) if inventory.get("items", {}) is Dictionary else {}
	state["counts"] = {}
	for id: String in FAMILY_IDS:
		state.counts[id] = items.get(id, 24 if id == "standard_arrow" else 0)
	load_state(state)

func write_inventory(inventory: Dictionary) -> Dictionary:
	var result: Dictionary = inventory.duplicate(true)
	var items: Dictionary = result.get("items", {}).duplicate(true) if result.get("items", {}) is Dictionary else {}
	for id: String in FAMILY_IDS:
		items[id] = count(id)
	result["items"] = items
	result["ammo_loadout"] = save_state()
	return result

static func migrate_inventory(inventory: Dictionary, equipment: Dictionary = {}) -> Dictionary:
	var model: AmmoLoadoutModel = load("res://scripts/models/ammo_loadout_model.gd").new()
	model.load_inventory(inventory)
	var selected: String = str(equipment.get("selected_arrow_id", equipment.get("selected_arrow", model.selected_family)))
	model.select(selected)
	return model.write_inventory(inventory)
