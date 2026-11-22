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
var stock_beats: Dictionary = {}
var stock_purchases: Dictionary = {}
var _transaction_active := false

func load_vendors(path: String) -> void:
	definitions = _read_json(path)

func reset_state() -> void:
	emergency_refill_claimed = false
	emergency_healing_claimed = false
	stock_beats.clear()
	stock_purchases.clear()
	changed.emit()

func get_vendor(vendor_id: String) -> Dictionary:
	return definitions.get(vendor_id, {}).duplicate(true)

func list_stock(vendor_id: String, inventory, story_state = null, quests = null, include_locked: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var vendor: Dictionary = get_vendor(vendor_id)
	if vendor.is_empty():
		return result
	for raw_entry in vendor.get("stock", []):
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry.duplicate(true)
		var unlocked: bool = _entry_unlocked(entry, story_state, quests)
		if not unlocked and not include_locked:
			continue
		var item_id := str(entry.get("item_id", ""))
		if item_id == "" or not inventory.item_defs.has(item_id):
			continue
		entry["owned"] = inventory.owned_count(item_id)
		entry["unlocked"] = unlocked
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

func quote(vendor_id: String, item_id: String, quantity: int, inventory, story_state = null, quests = null) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "", "item_id": item_id, "requested_quantity": quantity, "quantity": 0, "unit_price": 0, "total_price": 0, "owned": 0, "after": 0, "cap": 0, "coin_after": int(inventory.coin), "supply_note": "", "message": ""}
	if item_id in ["__emergency_arrows__", "__emergency_healing__"]:
		return _reserve_quote(vendor_id, item_id, inventory, result)
	var stock_entry: Dictionary = {}
	for entry in list_stock(vendor_id, inventory, story_state, quests, true):
		if str(entry.get("item_id", "")) == item_id:
			stock_entry = entry
			break
	if stock_entry.is_empty():
		return _quote_failure(result, "That item is not available here.")
	var owned: int = inventory.owned_count(item_id)
	var cap: int = int(stock_entry.get("cap", 999))
	var upgrade: bool = inventory.get_item_type(item_id) == "blade_upgrade"
	if upgrade:
		cap = 1
	if str(inventory.get_item_type(item_id)) == "ammo":
		var ammo_cap: int = int(inventory.get_ammo_cap(item_id))
		if ammo_cap > 0:
			cap = mini(cap, ammo_cap)
	var unit_price: int = int(stock_entry.get("price", 0))
	result["owned"] = owned
	result["after"] = owned
	result["cap"] = cap
	result["unit_price"] = unit_price
	result["supply_note"] = str(stock_entry.get("supply_note", ""))
	result["upgrade"] = upgrade
	result["requirement"] = str(stock_entry.get("requirement_text", ""))
	result["total_price"] = unit_price
	if not bool(stock_entry.get("unlocked", false)):
		return _quote_failure(result, str(stock_entry.get("requirement_text", "The required account is not yet known.")))
	if quantity <= 0:
		return _quote_failure(result, "Choose at least one item.")
	if owned >= cap:
		return _quote_failure(result, "This improvement is already fitted." if upgrade else "You cannot carry more of %s." % inventory.get_item_name(item_id))
	var accepted: int = mini(mini(quantity, 99), cap - owned)
	var total: int = unit_price * accepted
	result["quantity"] = accepted
	result["total_price"] = total
	if int(inventory.coin) < total:
		return _quote_failure(result, "You need %d more coin for %d." % [total - int(inventory.coin), accepted])
	result["ok"] = true
	result["after"] = owned + accepted
	result["coin_after"] = int(inventory.coin) - total
	result["message"] = "%s x%d costs %d coin. You will carry %d and have %d coin left." % [inventory.get_item_name(item_id), accepted, total, owned + accepted, int(result.coin_after)]
	if upgrade:
		result["message"] = "%s costs %d coin once. The fitted improvement remains through rest and saved journeys." % [inventory.get_item_name(item_id), total]
	if accepted != quantity:
		result["message"] = str(result.message) + " The quantity is limited to what you can carry in this exchange."
	return result

func _reserve_quote(vendor_id: String, request_id: String, inventory, result: Dictionary) -> Dictionary:
	var is_arrows: bool = request_id == "__emergency_arrows__"
	var item_id: String = "standard_arrow" if is_arrows else "redroot_potion"
	var owned: int = int(inventory.items.get(item_id, 0))
	result["item_id"] = item_id
	result["request_id"] = request_id
	result["owned"] = owned
	result["after"] = owned
	result["cap"] = int(inventory.get_ammo_cap(item_id)) if is_arrows else 8
	result["supply_note"] = "One emergency reserve, free of charge."
	if (is_arrows and vendor_id != "tor_forge") or (not is_arrows and vendor_id != "mira_apothecary"):
		return _quote_failure(result, "That emergency reserve is not offered here.")
	if (is_arrows and emergency_refill_claimed) or (not is_arrows and emergency_healing_claimed):
		return _quote_failure(result, "You have already received this emergency reserve.")
	if is_arrows and owned >= 5:
		return _quote_failure(result, "Tor keeps this reserve for a traveler carrying fewer than five ordinary arrows.")
	if not is_arrows and owned > 0:
		return _quote_failure(result, "Mira's emergency medicine is for a traveler with no Redroot Potion left.")
	var amount: int = mini(5 - owned, maxi(int(result.cap) - owned, 0)) if is_arrows else 2
	if amount <= 0:
		return _quote_failure(result, "You cannot carry this reserve.")
	result["ok"] = true
	result["quantity"] = amount
	result["after"] = owned + amount
	result["message"] = "Receive %s x%d for no coin. This uses the one emergency reserve." % [inventory.get_item_name(item_id), amount]
	return result

func _quote_failure(result: Dictionary, reason: String) -> Dictionary:
	result["ok"] = false
	result["reason"] = reason
	result["message"] = reason
	return result

func buy(vendor_id: String, item_id: String, quantity: int, inventory, story_state = null, quests = null) -> Dictionary:
	if _transaction_active:
		return {"ok": false, "reason": "An exchange is already being completed.", "message": "An exchange is already being completed."}
	# The displayed quote is advisory; rederive the authoritative quote now.
	var current: Dictionary = quote(vendor_id, item_id, quantity, inventory, story_state, quests)
	var reserve: bool = item_id in ["__emergency_arrows__", "__emergency_healing__"]
	var operation: String = "reserve" if reserve else "buy"
	if not bool(current.get("ok", false)):
		return _fail(str(current.get("reason", "This purchase is unavailable.")), str(current.get("item_id", item_id)), operation)
	var received_id: String = str(current.item_id)
	var received: int = int(current.quantity)
	var price: int = int(current.total_price)
	_transaction_active = true
	if item_id == "__emergency_arrows__":
		emergency_refill_claimed = true
	elif item_id == "__emergency_healing__":
		emergency_healing_claimed = true
	inventory.coin -= price
	if not reserve:
		_record_stock_exchange(vendor_id, received_id, received, inventory, story_state, quests)
	if bool(current.get("upgrade", false)):
		inventory.weapon_upgrades.append(received_id)
		inventory.changed.emit()
	else:
		inventory.add_item(received_id, received)
	var text: String = "Bought %s x%d for %d coin. You have %d coin left." % [inventory.get_item_name(received_id), received, price, int(inventory.coin)]
	if reserve:
		text = "Received %s x%d from the free emergency reserve." % [inventory.get_item_name(received_id), received]
	elif bool(current.get("upgrade", false)):
		text = "Fitted %s for %d coin. You have %d coin left." % [inventory.get_item_name(received_id), price, int(inventory.coin)]
	message.emit(text)
	if not reserve:
		purchase_completed.emit(vendor_id, received_id, received)
	changed.emit()
	_transaction_active = false
	return {"ok": true, "operation": operation, "item_id": received_id, "quantity": received, "price": price, "spent": {"coin": price}, "remaining": {"coin": int(inventory.coin), "items": inventory.items.duplicate(true), "weapon_upgrades": inventory.weapon_upgrades.duplicate()}, "reason": "", "message": text}

func _record_stock_exchange(vendor_id: String, item_id: String, quantity: int, inventory, state, quests) -> void:
	var offers: Array[String] = []
	for entry: Dictionary in list_stock(vendor_id, inventory, state, quests):
		offers.append("%s:%d" % [str(entry.item_id), int(entry.price)])
	var beat: String = "|".join(offers)
	if str(stock_beats.get(vendor_id, "")) != beat:
		stock_purchases[vendor_id] = {}
	stock_beats[vendor_id] = beat
	var purchases: Dictionary = stock_purchases.get(vendor_id, {})
	purchases[item_id] = mini(int(purchases.get(item_id, 0)) + quantity, 9999)
	stock_purchases[vendor_id] = purchases

func claim_emergency_arrow_refill(vendor_id: String, inventory) -> Dictionary:
	return buy(vendor_id, "__emergency_arrows__", 1, inventory)

func save_state() -> Dictionary:
	return {"emergency_refill_claimed": emergency_refill_claimed, "emergency_healing_claimed": emergency_healing_claimed, "stock_beats": stock_beats.duplicate(), "stock_purchases": stock_purchases.duplicate(true)}

func load_state(state: Dictionary) -> void:
	var claimed: Variant = state.get("emergency_refill_claimed", false)
	emergency_refill_claimed = typeof(claimed) == TYPE_BOOL and claimed
	var healing: Variant = state.get("emergency_healing_claimed", false)
	emergency_healing_claimed = typeof(healing) == TYPE_BOOL and healing
	stock_beats.clear()
	stock_purchases.clear()
	var beats: Variant = state.get("stock_beats", {})
	var purchases: Variant = state.get("stock_purchases", {})
	for vendor_id: String in definitions:
		if beats is Dictionary and beats.get(vendor_id) is String:
			stock_beats[vendor_id] = str(beats[vendor_id]).left(2048)
		if purchases is Dictionary and purchases.get(vendor_id) is Dictionary:
			var restored: Dictionary = {}
			for item_id: Variant in purchases[vendor_id]:
				var count: Variant = purchases[vendor_id][item_id]
				if item_id is String and typeof(count) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(count)):
					restored[item_id] = int(clampf(float(count), 0.0, 9999.0))
			stock_purchases[vendor_id] = restored

func claim_emergency_healing_refill(vendor_id: String, inventory) -> Dictionary:
	return buy(vendor_id, "__emergency_healing__", 1, inventory)

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

func _fail(text: String, item_id: String = "", operation: String = "buy") -> Dictionary:
	message.emit(text)
	return {"ok": false, "operation": operation, "item_id": item_id, "quantity": 0, "spent": {}, "remaining": {}, "reason": text, "message": text}

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Missing vendor data: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
