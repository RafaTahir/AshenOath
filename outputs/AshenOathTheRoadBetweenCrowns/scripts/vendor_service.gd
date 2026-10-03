extends Node
class_name VendorService

## Transaction boundary for shops. Vendors never mutate story or quest state;
## they only apply a validated inventory purchase and expose readable feedback.
signal changed
signal purchase_completed(vendor_id: String, item_id: String, quantity: int)
signal message(text: String)

var definitions: Dictionary = {}
var emergency_refill_claimed := false
var emergency_healing_claimed := false

func load_vendors(path: String) -> void:
	definitions = _read_json(path)

func reset_state() -> void:
	emergency_refill_claimed = false
	emergency_healing_claimed = false
	changed.emit()

func get_vendor(vendor_id: String) -> Dictionary:
	return definitions.get(vendor_id, {}).duplicate(true)

func list_stock(vendor_id: String, inventory, story_state = null, quests = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var vendor: Dictionary = get_vendor(vendor_id)
	if vendor.is_empty():
		return result
	for raw_entry in vendor.get("stock", []):
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry.duplicate(true)
		if not _entry_unlocked(entry, story_state, quests):
			continue
		var item_id := str(entry.get("item_id", ""))
		if item_id == "" or not inventory.item_defs.has(item_id):
			continue
		entry["owned"] = int(inventory.items.get(item_id, 0))
		entry["price"] = maxi(int(entry.get("price", 0)), 0)
		entry["cap"] = maxi(int(entry.get("cap", 999)), 1)
		_apply_story_supply(vendor_id, entry, story_state)
		result.append(entry)
	return result

func _apply_story_supply(vendor_id: String, entry: Dictionary, state) -> void:
	if state == null:
		return
	var item_id := str(entry.get("item_id", ""))
	var price := int(entry["price"])
	var iron := str(state.get_flag("iron_fate", ""))
	var treatment := str(state.get_flag("mira_treatment", ""))
	var truth := str(state.get_flag("mira_truth", ""))
	var mill := str(state.get_flag("mill_operation", ""))
	var reason := ""
	if vendor_id == "tor_forge":
		if iron == "memorial" and item_id == "iron_trap":
			price -= 2
			reason = "Tor's replacement work leaves prepared trap parts."
		elif iron == "tools" and item_id in ["standard_arrow", "bodkin_arrow"]:
			price -= 1
			reason = "Acknowledged village tools support ordinary repair and arrows."
		elif iron == "surrendered":
			if item_id == "standard_arrow":
				price = 1
				reason = "The village reserve keeps ordinary arrows available."
			elif item_id in ["bodkin_arrow", "ashfire_arrow", "iron_trap"]:
				price += 1
				reason = "Shared stock takes extra labor; ordinary arrows remain affordable."
	if vendor_id == "mira_apothecary" and item_id in ["redroot_potion", "bitterleaf_tonic"]:
		if truth == "confessed" or treatment == "consented":
			price -= 1
			reason = "Disclosed treatment and agreed assistance support the dispensary."
		elif truth == "destroyed" or treatment == "replacement":
			price += 1
			reason = "Replacement medicine needs more gathering; basic care stays available."
		if mill == "closed":
			price += 1
			reason += " Relief supplies replace the closed mill."
		elif mill == "restitution":
			price -= 1
			reason += " Mill restitution helps pay for care."
		elif mill == "supervised":
			reason += " Supervised supplies keep basic medicine in circulation."
	# Consequences alter preparation within a bounded range; essentials never vanish.
	entry["price"] = clampi(price, 1, maxi(int(entry["price"]) + 2, 1))
	entry["supply_note"] = reason.strip_edges()

func buy(vendor_id: String, item_id: String, quantity: int, inventory, story_state = null, quests = null) -> Dictionary:
	quantity = clampi(quantity, 1, 99)
	var stock_entry: Dictionary = {}
	for entry in list_stock(vendor_id, inventory, story_state, quests):
		if str(entry.get("item_id", "")) == item_id:
			stock_entry = entry
			break
	if stock_entry.is_empty():
		return _fail("That item is not available here.")
	var owned := int(inventory.items.get(item_id, 0))
	var cap := int(stock_entry.get("cap", 999))
	if owned >= cap:
		return _fail("You cannot carry more of %s." % inventory.get_item_name(item_id))
	quantity = mini(quantity, cap - owned)
	var price := int(stock_entry.get("price", 0)) * quantity
	if int(inventory.coin) < price:
		return _fail("You need %d more coin." % (price - int(inventory.coin)))
	inventory.coin -= price
	inventory.add_item(item_id, quantity)
	var display_name: String = str(inventory.get_item_name(item_id))
	var text := "Bought %s x%d for %d coin." % [display_name, quantity, price]
	message.emit(text)
	purchase_completed.emit(vendor_id, item_id, quantity)
	changed.emit()
	return {"ok": true, "item_id": item_id, "quantity": quantity, "price": price, "message": text}

func claim_emergency_arrow_refill(vendor_id: String, inventory) -> Dictionary:
	if vendor_id != "tor_forge":
		return _fail("The forge has no free reserve arrows.")
	var owned := int(inventory.items.get("standard_arrow", 0))
	if emergency_refill_claimed or owned >= 5:
		return _fail("Tor has no free reserve arrows for you right now.")
	var amount := mini(5 - owned, 24 - owned)
	if amount <= 0:
		return _fail("Your arrow bundle is already full.")
	emergency_refill_claimed = true
	inventory.add_item("standard_arrow", amount)
	var text := "Tor presses reserve arrows into your hand. No charge."
	message.emit(text)
	changed.emit()
	return {"ok": true, "item_id": "standard_arrow", "quantity": amount, "price": 0, "message": text}

func save_state() -> Dictionary:
	return {"emergency_refill_claimed": emergency_refill_claimed, "emergency_healing_claimed": emergency_healing_claimed}

func load_state(state: Dictionary) -> void:
	var claimed: Variant = state.get("emergency_refill_claimed", false)
	emergency_refill_claimed = typeof(claimed) == TYPE_BOOL and claimed
	var healing: Variant = state.get("emergency_healing_claimed", false)
	emergency_healing_claimed = typeof(healing) == TYPE_BOOL and healing

func claim_emergency_healing_refill(vendor_id: String, inventory) -> Dictionary:
	if vendor_id != "mira_apothecary" or emergency_healing_claimed or int(inventory.items.get("redroot_potion", 0)) > 0:
		return _fail("Mira's emergency medicine is for a traveler with no remedy left.")
	emergency_healing_claimed = true
	inventory.add_item("redroot_potion", 2)
	var text := "Mira gives you two replacement remedies. Basic care is not a reward for agreeing with her."
	message.emit(text)
	changed.emit()
	return {"ok": true, "item_id": "redroot_potion", "quantity": 2, "price": 0, "message": text}

func _entry_unlocked(entry: Dictionary, story_state, quests) -> bool:
	var flag_id := str(entry.get("requires_flag", ""))
	if flag_id != "":
		var known := story_state != null and bool(story_state.get_flag(flag_id, false))
		if flag_id == "mira_truth_known" and story_state != null:
			known = known or str(story_state.get_flag("mira_truth", "")) != ""
		if not known:
			return false
	var quest_id := str(entry.get("requires_quest", ""))
	if quest_id != "" and (quests == null or not (quests.is_active(quest_id) or quests.is_completed(quest_id))):
		return false
	return true

func _fail(text: String) -> Dictionary:
	message.emit(text)
	return {"ok": false, "message": text}

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Missing vendor data: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
