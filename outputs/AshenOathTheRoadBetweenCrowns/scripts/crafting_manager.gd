extends Node

signal crafted(item_id: String)

var inventory
var quest_manager

func setup(inventory_manager, quests) -> void:
	inventory = inventory_manager
	quest_manager = quests

func craft(item_id: String) -> bool:
	if inventory == null:
		return false
	var ok: bool = inventory.craft(item_id)
	if ok:
		crafted.emit(item_id)
		if item_id == "moon_oil":
			quest_manager.complete_objective("main_teeth_in_rain", "craft_moon_oil")
	return ok
