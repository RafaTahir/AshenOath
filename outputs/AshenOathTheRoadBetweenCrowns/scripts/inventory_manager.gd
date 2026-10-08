extends Node

signal changed
signal message(text: String)

var item_defs = {}
const STARTING_ITEMS = {
	"redroot_potion": 3,
	"bitterleaf_tonic": 1,
	"ash_bomb": 1,
	"moon_oil": 0,
	"rot_oil": 0,
	"iron_trap": 0,
	"standard_arrow": 24,
	"bodkin_arrow": 0,
	"ashfire_arrow": 0
}
const STARTING_INGREDIENTS = {
	"redroot": 2,
	"bitterleaf": 2,
	"mooncap": 1,
	"ash_salt": 2,
	"sparkstone": 1,
	"grave_moss": 1,
	"scrap_iron": 1
}
const STARTING_COIN := 15
var items: Dictionary = STARTING_ITEMS.duplicate(true)
var ingredients: Dictionary = STARTING_INGREDIENTS.duplicate(true)
var active_oil = ""
var coin = STARTING_COIN
const ITEM_TYPE_ORDER := ["ammo", "potion", "bomb", "oil", "trap"]
const DEFAULT_QUICK_SLOTS := {"use_potion": "redroot_potion", "throw_bomb": "ash_bomb"}
const QUICK_SLOT_TYPES := {"use_potion": ["potion"], "throw_bomb": ["bomb", "trap"]}
const KIT_CATEGORIES := ["equipment", "supplies", "ingredients"]
var quick_slots: Dictionary = DEFAULT_QUICK_SLOTS.duplicate()
var sort_mode := "type"
var kit_category := "supplies"

func load_items(path: String) -> void:
	var parsed = _read_json(path)
	if typeof(parsed) == TYPE_DICTIONARY:
		item_defs = parsed

func add_item(id: String, amount: int = 1) -> void:
	var target := int(items.get(id, 0)) + amount
	if get_item_type(id) == "ammo":
		var cap := get_ammo_cap(id)
		if cap > 0:
			target = mini(target, cap)
	items[id] = maxi(target, 0)
	changed.emit()

func add_ingredients(new_items: Dictionary) -> void:
	for id in new_items.keys():
		ingredients[id] = int(ingredients.get(id, 0)) + int(new_items[id])
	changed.emit()

func add_reward(reward: Dictionary) -> void:
	coin += int(reward.get("coin", 0))
	var reward_items: Dictionary = reward.get("items", {})
	for id in reward_items.keys():
		add_item(id, int(reward_items[id]))
	changed.emit()

func can_craft(id: String) -> bool:
	return bool(recipe_status(id).get("craftable", false))

func can_consume(id: String) -> bool:
	return item_defs.has(id) and int(items.get(id, 0)) > 0

func get_ammo_count(id: String) -> int:
	return int(items.get(id, 0)) if get_item_type(id) == "ammo" else 0

func get_ammo_cap(id: String) -> int:
	return int(item_defs.get(id, {}).get("cap", 0))

func add_ammo(id: String, amount: int) -> int:
	if get_item_type(id) != "ammo":
		return 0
	var before := get_ammo_count(id)
	var cap := get_ammo_cap(id)
	var target := before + amount if cap <= 0 else mini(before + amount, cap)
	items[id] = maxi(target, 0)
	changed.emit()
	return target - before

func apply_oil(id: String) -> bool:
	if get_item_type(id) != "oil" or not can_consume(id):
		message.emit("No %s left." % get_item_name(id))
		return false
	active_oil = id
	changed.emit()
	return true

func get_item_type(id: String) -> String:
	return str(item_defs.get(id, {}).get("type", "misc"))

func ordered_item_ids() -> Array[String]:
	var result: Array[String] = []
	for id in item_defs.keys():
		result.append(str(id))
	for id in items:
		if str(id) not in result:
			result.append(str(id))
	result.sort_custom(func(a: String, b: String) -> bool:
		if sort_mode == "type" and get_item_type(a) != get_item_type(b):
			var a_order: int = ITEM_TYPE_ORDER.find(get_item_type(a))
			var b_order: int = ITEM_TYPE_ORDER.find(get_item_type(b))
			a_order = a_order if a_order >= 0 else ITEM_TYPE_ORDER.size()
			b_order = b_order if b_order >= 0 else ITEM_TYPE_ORDER.size()
			if a_order != b_order:
				return a_order < b_order
		var comparison: int = get_item_name(a).naturalnocasecmp_to(get_item_name(b))
		return comparison < 0 if comparison != 0 else a < b
	)
	return result

func ordered_ingredient_ids() -> Array[String]:
	var result: Array[String] = []
	for id in ingredients:
		result.append(str(id))
	result.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	return result

func quick_slot_for_item(id: String) -> String:
	for slot: String in QUICK_SLOT_TYPES:
		if get_item_type(id) in QUICK_SLOT_TYPES[slot]:
			return slot
	return ""

func quick_item(slot: String) -> String:
	return str(quick_slots.get(slot, DEFAULT_QUICK_SLOTS.get(slot, "")))

func set_quick_item(slot: String, id: String) -> bool:
	if not item_defs.has(id) or not QUICK_SLOT_TYPES.has(slot) or quick_slot_for_item(id) != slot:
		return false
	quick_slots[slot] = id
	changed.emit()
	return true

func set_kit_preference(key: String, value: String) -> bool:
	if key == "sort" and value in ["name", "type"]:
		sort_mode = value
	elif key == "category" and value in KIT_CATEGORIES:
		kit_category = value
	else:
		return false
	changed.emit()
	return true

func recipe_status(id: String) -> Dictionary:
	var required: Dictionary = item_defs.get(id, {}).get("recipe", {})
	var missing: Dictionary = {}
	for ingredient in required.keys():
		var shortage := int(required[ingredient]) - int(ingredients.get(ingredient, 0))
		if shortage > 0:
			missing[ingredient] = shortage
	var has_recipe: bool = item_defs.has(id) and not required.is_empty()
	var cap: int = get_ammo_cap(id) if get_item_type(id) == "ammo" else 0
	var full: bool = cap > 0 and int(items.get(id, 0)) >= cap
	var reason: String = ""
	if not has_recipe:
		reason = "There is no field recipe for this item."
	elif full:
		reason = "You cannot carry another %s." % get_item_name(id)
	elif not missing.is_empty():
		var names: Array[String] = []
		for ingredient in missing:
			names.append("%d %s" % [int(missing[ingredient]), str(ingredient).replace("_", " ")])
		reason = "You still need %s." % ", ".join(names)
	return {
		"required": required.duplicate(true),
		"missing": missing,
		"has_recipe": has_recipe,
		"capacity": cap,
		"reason": reason,
		"craftable": has_recipe and missing.is_empty() and not full
	}

func get_preparation_summary() -> Dictionary:
	var craftable: Array[String] = []
	for id in ordered_item_ids():
		if can_craft(id):
			craftable.append(id)
	return {
		"active_oil": active_oil,
		"potions": int(items.get("redroot_potion", 0)) + int(items.get("bitterleaf_tonic", 0)),
		"bombs": int(items.get("ash_bomb", 0)),
		"traps": int(items.get("iron_trap", 0)),
		"craftable": craftable
	}

func craft(id: String) -> bool:
	var result: Dictionary = craft_result(id)
	message.emit(str(result.get("message", "")))
	return bool(result.get("ok", false))

func craft_result(id: String) -> Dictionary:
	var status: Dictionary = recipe_status(id)
	if not bool(status.get("craftable", false)):
		var reason: String = str(status.get("reason", "This item cannot be crafted."))
		return {"ok": false, "operation": "craft", "item_id": id, "quantity": 0, "spent": {}, "remaining": {}, "reason": reason, "message": reason}
	var recipe: Dictionary = status.get("required", {})
	for ingredient in recipe.keys():
		ingredients[ingredient] = int(ingredients.get(ingredient, 0)) - int(recipe[ingredient])
	add_item(id, 1)
	return {"ok": true, "operation": "craft", "item_id": id, "quantity": 1, "spent": {"ingredients": recipe.duplicate(true)}, "remaining": {"items": items.duplicate(true), "ingredients": ingredients.duplicate(true)}, "reason": "", "message": "Crafted %s. You now carry %d." % [get_item_name(id), int(items.get(id, 0))]}

func consume(id: String) -> bool:
	if not can_consume(id):
		message.emit("No %s left." % item_defs.get(id, {}).get("name", id))
		return false
	items[id] = int(items[id]) - 1
	changed.emit()
	return true

func get_item_name(id: String) -> String:
	return str(item_defs.get(id, {}).get("name", id))

func save_state() -> Dictionary:
	return {
		"items": items.duplicate(true),
		"ingredients": ingredients.duplicate(true),
		"active_oil": active_oil,
		"coin": coin,
		"quick_slots": quick_slots.duplicate(),
		"sort_mode": sort_mode,
		"kit_category": kit_category
	}

func load_state(state: Dictionary) -> void:
	# Missing legacy fields use the same defaults as a fresh load, never the
	# inventory belonging to the session that this save is replacing.
	items = STARTING_ITEMS.duplicate(true)
	ingredients = STARTING_INGREDIENTS.duplicate(true)
	var saved_items = state.get("items", {})
	if typeof(saved_items) == TYPE_DICTIONARY:
		for id in saved_items.keys():
			if typeof(id) != TYPE_STRING:
				continue
			var quantity := _restore_quantity(saved_items[id])
			items[id] = mini(quantity, get_ammo_cap(id)) if get_item_type(id) == "ammo" else quantity
	var saved_ingredients = state.get("ingredients", {})
	if typeof(saved_ingredients) == TYPE_DICTIONARY:
		for id in saved_ingredients.keys():
			if typeof(id) == TYPE_STRING:
				ingredients[id] = _restore_quantity(saved_ingredients[id])
	var saved_oil := str(state.get("active_oil", ""))
	active_oil = saved_oil if get_item_type(saved_oil) == "oil" and int(items.get(saved_oil, 0)) > 0 else ""
	coin = _restore_quantity(state.get("coin", STARTING_COIN))
	quick_slots = DEFAULT_QUICK_SLOTS.duplicate()
	var saved_slots: Variant = state.get("quick_slots", {})
	if saved_slots is Dictionary:
		for slot: String in DEFAULT_QUICK_SLOTS:
			var item_id: String = str(saved_slots.get(slot, ""))
			if item_defs.has(item_id) and quick_slot_for_item(item_id) == slot:
				quick_slots[slot] = item_id
	sort_mode = "name" if str(state.get("sort_mode", "type")) == "name" else "type"
	var saved_category: String = str(state.get("kit_category", "supplies"))
	kit_category = saved_category if saved_category in KIT_CATEGORIES else "supplies"
	changed.emit()

func _restore_quantity(value: Variant) -> int:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return 0
	var number := float(value)
	if not is_finite(number) or number != floorf(number):
		return 0
	return int(clampf(number, 0.0, 2147483647.0))

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		push_warning("Missing JSON: %s" % path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed != null else {}
func reset_starting_loadout() -> void:
	items = STARTING_ITEMS.duplicate(true)
	ingredients = STARTING_INGREDIENTS.duplicate(true)
	active_oil = ""
	coin = STARTING_COIN
	quick_slots = DEFAULT_QUICK_SLOTS.duplicate()
	sort_mode = "type"
	kit_category = "supplies"
	changed.emit()
