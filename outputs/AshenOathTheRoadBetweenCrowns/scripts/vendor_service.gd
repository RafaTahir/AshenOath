extends Node
class_name VendorService

const Economy = preload("res://scripts/models/vendor_economy_model.gd")

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
var stock_ledger: Dictionary = {}
var _transaction_active := false
var clock: Node
var fish_allowance := {"remaining":3, "day":0, "played":0.0}

func refresh_fish_allowance() -> void:
	if not is_instance_valid(clock): return
	if int(clock.day_count) > int(fish_allowance.day) and float(clock.active_play_seconds)-float(fish_allowance.played) >= 2160.0:
		fish_allowance = {"remaining":3,"day":int(clock.day_count),"played":float(clock.active_play_seconds)}

# Fixed buyback prices stay below the lowest permitted shop price. Keep a
# practical reserve; evidence, ingredients, keepsakes and fittings are excluded.
const BUYBACK := Economy.BUYBACK

func list_surplus(vendor_id: String, inventory) -> Array[Dictionary]:
	refresh_fish_allowance()
	return _economy(inventory).list_surplus(vendor_id)

func sell_quote(vendor_id: String, item_id: String, quantity: int, inventory) -> Dictionary:
	refresh_fish_allowance()
	return _economy(inventory).sell_quote(vendor_id, item_id, quantity)

func sell(vendor_id: String, item_id: String, quantity: int, inventory, story_state = null, quests = null) -> Dictionary:
	if _transaction_active:
		return _fail("An exchange is already being completed.", item_id, "sell")
	refresh_fish_allowance()
	var model: Economy = _economy(inventory, story_state, quests)
	return _apply_exchange(model, model.sell(vendor_id, item_id, quantity), inventory, vendor_id)

func load_vendors(path: String) -> void:
	definitions = _read_json(path)

func reset_state() -> void:
	fish_allowance = {"remaining":3,"day":0,"played":0.0}
	emergency_refill_claimed = false
	emergency_healing_claimed = false
	stock_beats.clear()
	stock_purchases.clear()
	stock_ledger.clear()
	changed.emit()

func get_vendor(vendor_id: String) -> Dictionary:
	return definitions.get(vendor_id, {}).duplicate(true)

func list_stock(vendor_id: String, inventory, story_state = null, quests = null, include_locked: bool = false) -> Array[Dictionary]:
	return _economy(inventory, story_state, quests).list_stock(vendor_id, include_locked)

func quote(vendor_id: String, item_id: String, quantity: int, inventory, story_state = null, quests = null) -> Dictionary:
	return _economy(inventory, story_state, quests).quote(vendor_id, item_id, quantity)

func presentation(vendor_id: String, selected_id: String, inventory, story_state = null, quests = null) -> Dictionary:
	refresh_fish_allowance()
	return _economy(inventory, story_state, quests).presentation(vendor_id, selected_id)

func buy(vendor_id: String, item_id: String, quantity: int, inventory, story_state = null, quests = null) -> Dictionary:
	if _transaction_active:
		return _fail("An exchange is already being completed.", item_id)
	var model: Economy = _economy(inventory, story_state, quests)
	return _apply_exchange(model, model.buy(vendor_id, item_id, quantity), inventory, vendor_id)

func _economy(inventory, story_state = null, quests = null) -> Economy:
	var quest_state: Dictionary = quests.save_state() if quests != null else {}
	var available: Dictionary = quest_state.get("active", {}).duplicate()
	available.merge(quest_state.get("completed", {}), true)
	var chapters: int = 0
	for id: String in quest_state.get("completed", {}):
		if id.begins_with("main_"):
			chapters += 1
	var model: Economy = Economy.new()
	model.configure(definitions, inventory.item_defs, inventory.save_state(), save_state(),
		story_state.flags if story_state != null else {}, available, str(chapters))
	return model

func _apply_exchange(model: Economy, receipt: Dictionary, inventory, vendor_id: String) -> Dictionary:
	if not bool(receipt.get("ok", false)):
		return _fail(str(receipt.get("message", "This exchange is unavailable.")), str(receipt.get("item_id", "")), str(receipt.get("operation", "buy")))
	_transaction_active = true
	var next: Dictionary = model.inventory_state()
	inventory.items = next.items.duplicate(true)
	inventory.coin = int(next.coin)
	inventory.weapon_upgrades.assign(next.weapon_upgrades)
	load_state(model.save_state())
	inventory.changed.emit()
	changed.emit()
	if str(receipt.get("operation", "")) == "buy":
		purchase_completed.emit(vendor_id, str(receipt.item_id), int(receipt.quantity))
	message.emit(str(receipt.message))
	_transaction_active = false
	return receipt

func claim_emergency_arrow_refill(vendor_id: String, inventory) -> Dictionary:
	return buy(vendor_id, "__emergency_arrows__", 1, inventory)

func save_state() -> Dictionary:
	return {"fish_allowance":fish_allowance.duplicate(), "emergency_refill_claimed": emergency_refill_claimed, "emergency_healing_claimed": emergency_healing_claimed, "stock_beats": stock_beats.duplicate(), "stock_purchases": stock_purchases.duplicate(true), "stock_ledger": stock_ledger.duplicate(true)}

func load_state(state: Dictionary) -> void:
	stock_ledger = state.get("stock_ledger", {}).duplicate(true) if state.get("stock_ledger", {}) is Dictionary else {}
	var fish: Variant = state.get("fish_allowance", {})
	fish_allowance = {"remaining":3,"day":0,"played":0.0}
	if fish is Dictionary:
		fish_allowance.remaining = clampi(int(fish.get("remaining",3)),0,3)
		fish_allowance.day = maxi(0,int(fish.get("day",0)))
		var seconds := float(fish.get("played",0.0))
		fish_allowance.played = maxf(0.0,seconds) if is_finite(seconds) else 0.0
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
