extends Node

signal changed
signal message(text: String)

var item_defs = {}
var items = {
	"redroot_potion": 1,
	"bitterleaf_tonic": 1,
	"ash_bomb": 1,
	"moon_oil": 0,
	"rot_oil": 0,
	"iron_trap": 0
}
var ingredients = {
	"redroot": 2,
	"bitterleaf": 2,
	"mooncap": 1,
	"ash_salt": 2,
	"sparkstone": 1,
	"grave_moss": 1,
	"scrap_iron": 1
}
var active_oil = ""
var coin = 15
const ITEM_TYPE_ORDER := ["potion", "bomb", "oil", "trap"]

func load_items(path: String) -> void:
	var parsed = _read_json(path)
	if typeof(parsed) == TYPE_DICTIONARY:
		item_defs = parsed

func add_item(id: String, amount: int = 1) -> void:
	items[id] = int(items.get(id, 0)) + amount
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
	if not item_defs.has(id):
		return false
	var recipe: Dictionary = item_defs[id].get("recipe", {})
	for ingredient in recipe.keys():
		if int(ingredients.get(ingredient, 0)) < int(recipe[ingredient]):
			return false
	return true

func can_consume(id: String) -> bool:
	return item_defs.has(id) and int(items.get(id, 0)) > 0

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
	for item_type in ITEM_TYPE_ORDER:
		for id in item_defs.keys():
			if get_item_type(str(id)) == item_type:
				result.append(str(id))
	for id in item_defs.keys():
		if str(id) not in result:
			result.append(str(id))
	return result

func recipe_status(id: String) -> Dictionary:
	var required: Dictionary = item_defs.get(id, {}).get("recipe", {})
	var missing: Dictionary = {}
	for ingredient in required.keys():
		var shortage := int(required[ingredient]) - int(ingredients.get(ingredient, 0))
		if shortage > 0:
			missing[ingredient] = shortage
	return {
		"required": required.duplicate(true),
		"missing": missing,
		"craftable": not required.is_empty() and missing.is_empty()
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
	if not can_craft(id):
		message.emit("Missing ingredients for %s." % item_defs.get(id, {}).get("name", id))
		return false
	var recipe: Dictionary = item_defs[id].get("recipe", {})
	for ingredient in recipe.keys():
		ingredients[ingredient] = int(ingredients.get(ingredient, 0)) - int(recipe[ingredient])
	add_item(id, 1)
	message.emit("Crafted %s." % item_defs[id].get("name", id))
	return true

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
		"items": items,
		"ingredients": ingredients,
		"active_oil": active_oil,
		"coin": coin
	}

func load_state(state: Dictionary) -> void:
	var saved_items = state.get("items", {})
	if typeof(saved_items) == TYPE_DICTIONARY:
		for id in saved_items.keys():
			items[id] = max(0, int(saved_items[id]))
	var saved_ingredients = state.get("ingredients", {})
	if typeof(saved_ingredients) == TYPE_DICTIONARY:
		for id in saved_ingredients.keys():
			ingredients[id] = max(0, int(saved_ingredients[id]))
	var saved_oil := str(state.get("active_oil", ""))
	active_oil = saved_oil if get_item_type(saved_oil) == "oil" and int(items.get(saved_oil, 0)) > 0 else ""
	coin = int(state.get("coin", coin))
	changed.emit()

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		push_warning("Missing JSON: %s" % path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed != null else {}
