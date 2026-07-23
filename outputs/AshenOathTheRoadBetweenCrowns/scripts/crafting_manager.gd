extends Node

signal crafted(item_id: String)

var inventory
var quest_manager
var story_state

func setup(inventory_manager, quests, state = null) -> void:
	inventory = inventory_manager
	quest_manager = quests
	story_state = state

func craft(item_id: String) -> bool:
	if inventory == null:
		return false
	var ok: bool = inventory.craft(item_id)
	if ok:
		crafted.emit(item_id)
		if item_id == "moon_oil":
			quest_manager.complete_objective("main_teeth_in_rain", "craft_moon_oil")
			if story_state != null and bool(story_state.get_flag("moon_oil_mastery", false)):
				inventory.add_ingredients({"mooncap": 1})
				inventory.message.emit("Mira's refined formula saves one mooncap.")
	return ok
