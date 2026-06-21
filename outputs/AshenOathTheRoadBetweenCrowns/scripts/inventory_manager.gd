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
	if int(items.get(id, 0)) <= 0:
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
	items = state.get("items", items)
	ingredients = state.get("ingredients", ingredients)
	active_oil = str(state.get("active_oil", ""))
	coin = int(state.get("coin", coin))
	changed.emit()

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		push_warning("Missing JSON: %s" % path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed != null else {}
