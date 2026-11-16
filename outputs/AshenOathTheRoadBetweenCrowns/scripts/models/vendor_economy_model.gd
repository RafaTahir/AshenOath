class_name VendorEconomyModel
extends RefCounted

const Ammo = preload("res://scripts/models/ammo_loadout_model.gd")
const Pricing = preload("res://scripts/models/vendor_pricing.gd")
const BUYBACK: Dictionary = {
	"nessa_kitchen": {"river_dace": [1, 0], "copper_perch": [2, 0]},
	"tor_forge": {"bodkin_arrow": [1, 3], "ashfire_arrow": [2, 2], "iron_trap": [2, 1], "moon_oil": [3, 1]},
	"mira_apothecary": {"redroot_potion": [1, 2], "bitterleaf_tonic": [1, 1], "ash_bomb": [2, 1], "moon_oil": [3, 1], "rot_oil": [3, 1]}
}
var _definitions: Dictionary = {}
var _item_defs: Dictionary = {}
var _inventory: Dictionary = {}
var _vendors: Dictionary = {}
var _flags: Dictionary = {}
var _quests: Dictionary = {}
var _chapter: String = "opening"

func configure(definitions: Dictionary, item_defs: Dictionary, inventory: Dictionary,
		vendors: Dictionary = {}, flags: Dictionary = {}, quests: Dictionary = {}, chapter: String = "opening") -> void:
	_definitions = definitions.duplicate(true)
	_item_defs = item_defs.duplicate(true)
	_inventory = inventory.duplicate(true)
	_inventory["items"] = inventory.get("items", {}).duplicate(true)
	_inventory["weapon_upgrades"] = inventory.get("weapon_upgrades", []).duplicate()
	_inventory["coin"] = Ammo.quantity(inventory.get("coin", 0))
	_vendors = vendors.duplicate(true)
	_flags = flags.duplicate(true)
	_quests = quests.duplicate(true)
	_chapter = chapter
	for key: String in ["stock_beats", "stock_purchases", "stock_ledger"]:
		if not _vendors.get(key) is Dictionary:
			_vendors[key] = {}

func inventory_state() -> Dictionary:
	return _inventory.duplicate(true)

func save_state() -> Dictionary:
	return _vendors.duplicate(true)

func owned(item_id: String) -> int:
	return int(item_id in _inventory.weapon_upgrades) if _type(item_id) == "blade_upgrade" else Ammo.quantity(_inventory.items.get(item_id, 0))

func _type(item_id: String) -> String:
	return str(_item_defs.get(item_id, {}).get("type", ""))

func _name(item_id: String) -> String:
	return str(_item_defs.get(item_id, {}).get("name", item_id))

func _unlocked(entry: Dictionary) -> bool:
	var flag: String = str(entry.get("requires_flag", ""))
	var known: bool = bool(_flags.get(flag, false))
	if flag == "mira_truth_known":
		known = known or str(_flags.get("mira_truth", "")) != ""
	var quest: String = str(entry.get("requires_quest", ""))
	var required_chapter: String = str(entry.get("requires_chapter", ""))
	return (flag.is_empty() or known) and (quest.is_empty() or _quests.has(quest)) and (required_chapter.is_empty() or _quests.has(required_chapter) or required_chapter == _chapter)

func _stock_key(vendor_id: String) -> String:
	return vendor_id + "|" + _chapter

func _purchases(vendor_id: String) -> Dictionary:
	var key: String = _stock_key(vendor_id)
	if _vendors.stock_ledger.get(key) is Dictionary:
		return _vendors.stock_ledger[key]
	# Adopt pre-ledger purchases once, without restocking old journeys.
	if not _vendors.stock_ledger.has(vendor_id + "|legacy_adopted"):
		var legacy: Variant = _vendors.stock_purchases.get(vendor_id, {})
		return legacy if legacy is Dictionary else {}
	return {}

func list_stock(vendor_id: String, include_locked: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw: Dictionary in _definitions.get(vendor_id, {}).get("stock", []):
		var entry: Dictionary = raw.duplicate(true)
		var id: String = str(entry.get("item_id", ""))
		if not _item_defs.has(id):
			continue
		entry["unlocked"] = _unlocked(entry)
		if not include_locked and not entry.unlocked:
			continue
		entry["owned"] = owned(id)
		entry["price"] = maxi(0, int(entry.get("price", 0)))
		entry["cap"] = maxi(1, int(entry.get("cap", 999)))
		Pricing.apply(vendor_id, entry, _flags)
		var supply: int = maxi(0, int(entry.get("stock", entry.cap)))
		var purchased: int = Ammo.quantity(_purchases(vendor_id).get(id, 0)) if vendor_id in ["tor_forge", "mira_apothecary"] else 0
		entry["stock_remaining"] = maxi(0, supply - purchased)
		result.append(entry)
	return result

func _failure(result: Dictionary, text: String) -> Dictionary:
	result.merge({"ok": false, "reason": text, "message": text}, true)
	return result

func quote(vendor_id: String, item_id: String, quantity: int) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "", "item_id": item_id, "requested_quantity": quantity,
		"quantity": 0, "unit_price": 0, "total_price": 0, "owned": 0, "after": 0,
		"cap": 0, "coin_after": int(_inventory.coin), "supply_note": "", "message": ""}
	if quantity < 1 or quantity > 99:
		return _failure(result, "Choose a quantity from 1 to 99.")
	if item_id in ["__emergency_arrows__", "__emergency_healing__"]:
		return _reserve_quote(vendor_id, item_id, result)
	var stock: Dictionary = {}
	for entry: Dictionary in list_stock(vendor_id, true):
		if str(entry.item_id) == item_id:
			stock = entry
			break
	if stock.is_empty():
		return _failure(result, "That item is not available here.")
	var count: int = owned(item_id)
	var upgrade: bool = _type(item_id) == "blade_upgrade"
	var capacity: int = 1 if upgrade else int(stock.cap)
	if _type(item_id) == "ammo":
		capacity = mini(capacity, int(Ammo.FAMILY_CAPS.get(item_id, capacity)))
	result.merge({"owned": count, "after": count, "cap": capacity, "unit_price": int(stock.price),
		"total_price": int(stock.price), "supply_note": str(stock.get("supply_note", "")),
		"upgrade": upgrade, "requirement": str(stock.get("requirement_text", "")),
		"stock_remaining": int(stock.stock_remaining)}, true)
	if not bool(stock.unlocked):
		return _failure(result, str(stock.get("requirement_text", "The required account is not yet known.")))
	if count >= capacity:
		return _failure(result, "This improvement is already fitted." if upgrade else "You cannot carry more of %s." % _name(item_id))
	var accepted: int = mini(quantity, mini(capacity - count, int(stock.stock_remaining)))
	if accepted <= 0:
		return _failure(result, "This supply is sold out for this chapter.")
	var total: int = accepted * int(stock.price)
	result["quantity"] = accepted
	result["total_price"] = total
	if int(_inventory.coin) < total:
		return _failure(result, "You need %d more coin for %d." % [total - int(_inventory.coin), accepted])
	result.merge({"ok": true, "after": count + accepted, "coin_after": int(_inventory.coin) - total,
		"message": "%s x%d costs %d coin. You will carry %d and have %d coin left." % [_name(item_id), accepted, total, count + accepted, int(_inventory.coin) - total]}, true)
	if upgrade:
		result.message = "%s costs %d coin once. The fitted improvement remains through rest and saved journeys." % [_name(item_id), total]
	if accepted != quantity:
		result.message += " The quantity is limited to available stock and carrying space."
	return result

func _reserve_quote(vendor_id: String, request_id: String, result: Dictionary) -> Dictionary:
	var arrows: bool = request_id == "__emergency_arrows__"
	var id: String = "standard_arrow" if arrows else "redroot_potion"
	var count: int = owned(id)
	var capacity: int = int(Ammo.FAMILY_CAPS[id]) if arrows else 8
	result.merge({"item_id": id, "request_id": request_id, "owned": count, "after": count,
		"cap": capacity, "supply_note": "One emergency reserve, free of charge."}, true)
	if vendor_id != ("tor_forge" if arrows else "mira_apothecary"):
		return _failure(result, "That emergency reserve is not offered here.")
	var key: String = "emergency_refill_claimed" if arrows else "emergency_healing_claimed"
	if bool(_vendors.get(key, false)):
		return _failure(result, "You have already received this emergency reserve.")
	if arrows and count >= 5:
		return _failure(result, "Tor keeps this reserve for a traveler carrying fewer than five ordinary arrows.")
	if not arrows and count > 0:
		return _failure(result, "Mira's emergency medicine is for a traveler with no Redroot Potion left.")
	var amount: int = mini(5 - count, capacity - count) if arrows else 2
	result.merge({"ok": true, "quantity": amount, "after": count + amount,
		"message": "Receive %s x%d for no coin. This uses the one emergency reserve." % [_name(id), amount]}, true)
	return result

func _record_stock(vendor_id: String, item_id: String, delta: int) -> void:
	var purchases: Dictionary = _purchases(vendor_id).duplicate()
	purchases[item_id] = clampi(int(purchases.get(item_id, 0)) + delta, 0, 9999)
	_vendors.stock_ledger[_stock_key(vendor_id)] = purchases
	_vendors.stock_ledger[vendor_id + "|legacy_adopted"] = true
	_vendors.stock_purchases[vendor_id] = purchases.duplicate()

func buy(vendor_id: String, item_id: String, quantity: int) -> Dictionary:
	var current: Dictionary = quote(vendor_id, item_id, quantity)
	if not bool(current.ok):
		return current
	var id: String = str(current.item_id)
	var amount: int = int(current.quantity)
	var price: int = int(current.total_price)
	var reserve: bool = item_id.begins_with("__emergency")
	if reserve:
		_vendors["emergency_refill_claimed" if item_id == "__emergency_arrows__" else "emergency_healing_claimed"] = true
	else:
		_record_stock(vendor_id, id, amount)
	_inventory.coin = int(current.coin_after)
	if bool(current.get("upgrade", false)):
		_inventory.weapon_upgrades.append(id)
	else:
		_inventory.items[id] = int(current.after)
	var text: String = "Bought %s x%d for %d coin. You have %d coin left." % [_name(id), amount, price, int(_inventory.coin)]
	if reserve:
		text = "Received %s x%d from the free emergency reserve." % [_name(id), amount]
	elif bool(current.get("upgrade", false)):
		text = "Fitted %s for %d coin. You have %d coin left." % [_name(id), price, int(_inventory.coin)]
	return {"ok": true, "operation": "reserve" if reserve else "buy", "item_id": id,
		"quantity": amount, "price": price, "spent": {"coin": price}, "remaining": {
		"coin": int(_inventory.coin), "items": _inventory.items.duplicate(true),
		"weapon_upgrades": _inventory.weapon_upgrades.duplicate()}, "reason": "", "message": text}

func sell_quote(vendor_id: String, item_id: String, quantity: int) -> Dictionary:
	var result: Dictionary = {"ok": false, "item_id": item_id, "quantity": 0, "unit_price": 0,
		"total_price": 0, "message": "This is not a surplus supply accepted here."}
	var offer: Array = BUYBACK.get(vendor_id, {}).get(item_id, [])
	if quantity < 1 or quantity > 99 or offer.is_empty() or not _item_defs.has(item_id):
		return _failure(result, "Choose a valid surplus supply and quantity from 1 to 99.")
	var count: int = owned(item_id)
	var reserve: int = int(offer[1])
	var amount: int = mini(quantity, maxi(0, count - reserve))
	if vendor_id == "nessa_kitchen":
		amount = mini(amount, int(_vendors.get("fish_allowance", {}).get("remaining", 3)))
		if amount <= 0:
			return _failure(result, "Nessa needs at most three fish per allowance. Another day and a full day's active travel must pass before she needs more.")
	var total: int = amount * int(offer[0])
	result.merge({"owned": count, "reserve": reserve, "quantity": amount, "unit_price": int(offer[0]), "total_price": total}, true)
	if amount <= 0:
		return _failure(result, "Keep at least %d %s for the road; this allowance may be exhausted." % [reserve, _name(item_id)])
	if int(_inventory.coin) > 2147480000 - total:
		return _failure(result, "Your purse cannot hold this exchange.")
	result.merge({"ok": true, "message": "Sell %d %s for %d coin; keep %d. This is a supply exchange, not a quest handover." % [amount, _name(item_id), total, count - amount]}, true)
	return result

func sell(vendor_id: String, item_id: String, quantity: int) -> Dictionary:
	var current: Dictionary = sell_quote(vendor_id, item_id, quantity)
	if not bool(current.ok):
		return current
	_inventory.items[item_id] = owned(item_id) - int(current.quantity)
	_inventory.coin = int(_inventory.coin) + int(current.total_price)
	_record_stock(vendor_id, item_id, -int(current.quantity))
	if vendor_id == "nessa_kitchen":
		var allowance: Dictionary = _vendors.get("fish_allowance", {"remaining": 3, "day": 0, "played": 0.0})
		allowance.remaining = int(allowance.remaining) - int(current.quantity)
		_vendors["fish_allowance"] = allowance
	return {"ok": true, "operation": "sell", "item_id": item_id, "quantity": int(current.quantity),
		"message": "Sold %s x%d for %d coin. You have %d coin." % [_name(item_id), int(current.quantity), int(current.total_price), int(_inventory.coin)],
		"received": {"coin": int(current.total_price)}}

func list_surplus(vendor_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in BUYBACK.get(vendor_id, {}):
		var offer: Dictionary = sell_quote(vendor_id, id, 1)
		if bool(offer.ok):
			result.append(offer)
	return result

func presentation(vendor_id: String, selected_id: String) -> Dictionary:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in list_stock(vendor_id, true):
		entries.append({"id": str(entry.item_id), "title": _name(str(entry.item_id))})
	if vendor_id in ["tor_forge", "mira_apothecary"]:
		entries.append({"id": "__emergency_arrows__" if vendor_id == "tor_forge" else "__emergency_healing__",
			"title": "Emergency arrows" if vendor_id == "tor_forge" else "Emergency medicine"})
	var valid_selection: bool = false
	for entry: Dictionary in entries:
		valid_selection = valid_selection or entry.id == selected_id
	if not valid_selection:
		selected_id = str(entries[0].id) if not entries.is_empty() else ""
	var offer: Dictionary = quote(vendor_id, selected_id, 1)
	var label: String = "Buy %d · %d coin" % [int(offer.quantity), int(offer.total_price)]
	if selected_id.begins_with("__emergency"):
		label = "Claim emergency reserve"
	elif bool(offer.get("upgrade", false)):
		label = "Fit · %d coin" % int(offer.total_price)
	if not bool(offer.ok):
		label = "Already fitted" if bool(offer.get("upgrade", false)) and int(offer.owned) > 0 else "Unavailable"
	var five: Dictionary = quote(vendor_id, selected_id, 5)
	var bundle: bool = not selected_id.begins_with("__emergency") and not bool(offer.get("upgrade", false)) and bool(five.ok) and int(five.quantity) == 5
	return {"entries": entries, "selected_id": selected_id, "quote": offer, "purchase_label": label,
		"bundle": bundle, "bundle_price": int(five.total_price), "surplus": list_surplus(vendor_id)}
