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
	var result: Dictionary = craft_result(item_id)
	if inventory != null:
		inventory.message.emit(str(result.get("message", "")))
	return bool(result.get("ok", false))

func quote(item_id: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "Your pack is unavailable.", "item_id": item_id, "output_quantity": 1, "costs": [], "message": "Your pack is unavailable."}
	if inventory == null:
		return result
	var status: Dictionary = inventory.recipe_status(item_id)
	var required: Dictionary = status.get("required", {})
	var costs: Array[Dictionary] = []
	for raw_id in required:
		var id: String = str(raw_id)
		var amount: int = int(required[id])
		var owned: int = int(inventory.ingredients.get(id, 0))
		var returned: int = 1 if item_id == "moon_oil" and id == "mooncap" and story_state != null and bool(story_state.get_flag("moon_oil_mastery", false)) else 0
		costs.append({"id": id, "name": id.replace("_", " ").capitalize(), "owned": owned, "required": amount, "spent": amount - returned, "returned": returned, "after": owned - amount + returned if bool(status.get("craftable", false)) else owned})
	result["costs"] = costs
	result["ok"] = bool(status.get("craftable", false))
	result["reason"] = str(status.get("reason", ""))
	result["message"] = "Makes 1 %s." % inventory.get_item_name(item_id) if bool(result.ok) else str(result.reason)
	return result

func craft_result(item_id: String) -> Dictionary:
	var current: Dictionary = quote(item_id)
	if not bool(current.get("ok", false)):
		return {"ok": false, "operation": "craft", "item_id": item_id, "quantity": 0, "spent": {}, "remaining": {}, "message": str(current.get("message", "")), "reason": str(current.get("reason", ""))}
	var refund: Dictionary = {}
	var spent: Dictionary = {}
	for cost: Dictionary in current.get("costs", []):
		spent[str(cost.id)] = int(cost.spent)
		if int(cost.returned) > 0:
			refund[str(cost.id)] = int(cost.returned)
	# Commit the item and learned returns before the inventory emits changed.
	# The full recipe is still required before any ingredients are spent.
	var result: Dictionary = inventory.craft_result(item_id, refund)
	if not bool(result.get("ok", false)):
		return result
	if not refund.is_empty():
		result["message"] = str(result.message) + " Mira's refined formula returns one mooncap."
	result["spent"] = {"ingredients": spent}
	result["remaining"] = {"items": inventory.items.duplicate(true), "ingredients": inventory.ingredients.duplicate(true)}
	if item_id == "moon_oil" and quest_manager != null:
		quest_manager.complete_objective("main_teeth_in_rain", "craft_moon_oil")
	crafted.emit(item_id)
	return result
