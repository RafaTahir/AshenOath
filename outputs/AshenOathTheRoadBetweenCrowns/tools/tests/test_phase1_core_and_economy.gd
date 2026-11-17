extends SceneTree

const Rng = preload("res://scripts/core/seeded_rng.gd")
const Clock = preload("res://scripts/core/sim_clock.gd")
const Frame = preload("res://scripts/core/input_frame.gd")
const Bus = preload("res://scripts/core/sim_event_bus.gd")
const Runner = preload("res://scripts/core/replay_runner.gd")
const Canonical = preload("res://scripts/core/canonical_state.gd")
const Ammo = preload("res://scripts/models/ammo_loadout_model.gd")
const Economy = preload("res://scripts/models/vendor_economy_model.gd")
const Codec = preload("res://scripts/models/save_payload_codec.gd")
const Selection = preload("res://scripts/models/save_selection_model.gd")
const Inventory = preload("res://scripts/inventory_manager.gd")
const Vendor = preload("res://scripts/vendor_service.gd")

class Scenario extends "res://scripts/core/deterministic_model.gd":
	var x: int = 0
	var z: int = 0
	var stamina: int = 10000
	var sequence: int = 0
	var selection: int = 0

	func step(frame: Frame, delta: float, rng: Rng, events: Events) -> void:
		assert(delta == 1.0 / 60.0)
		x += roundi(frame.move_x * 32767.0)
		z += roundi(frame.move_y * 32767.0)
		sequence = (sequence + rng.next_u32()) & 0xffffffff
		stamina = clampi(stamina + (1 if frame.buttons == 0 else -2), 0, 10000)
		selection = frame.selected_slot
		if frame.tick % 60 == 0:
			events.emit_event(frame.tick, "checkpoint", {"x": x, "selection": selection})

	func save_state() -> Dictionary:
		return {"x": x, "z": z, "stamina": stamina, "sequence": sequence, "selection": selection}

var _checks: int = 0
var _failures: Array[String] = []
var _data_cache: Dictionary = {}

func _init() -> void:
	_test_core()
	_test_replay()
	_test_ammo()
	_test_saves()
	_test_economy()
	_test_adapters()
	if _failures.is_empty():
		print("PHASE 1 PASS: %d checks; deterministic replay, ammo, save migration and vendor economy." % _checks)
		quit(0)
	else:
		for failure: String in _failures:
			printerr("FAIL: " + failure)
		printerr("PHASE 1 FAIL: %d/%d checks failed." % [_failures.size(), _checks])
		quit(1)

func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)

func _test_core() -> void:
	var rng: Rng = Rng.new(0)
	var control: Rng = Rng.new(1)
	_expect(rng.get_seed() == 1 and rng.next_u32() == control.next_u32(), "zero seed maps to one")
	_expect(Rng.new(0x100000002).get_seed() == 2, "seed is uint32")
	var state: int = rng.get_state()
	var next: int = rng.next_u32()
	rng.set_state(state)
	_expect(next == rng.next_u32(), "RNG state restores exactly")
	_expect(rng.chance(1.0) and not rng.chance(0.0), "probability bounds")
	_expect(rng.range_int(4, 4) == 4 and rng.range_float(2.0, 2.0) == 2.0, "range endpoints")
	var clock: Clock = Clock.new()
	_expect(clock.consume(Clock.TICK_DT / 2.0) == 0, "clock accumulates partial tick")
	_expect(clock.consume(Clock.TICK_DT / 2.0) == 1, "clock consumes exact fixed tick")
	_expect(clock.consume(Clock.TICK_DT * 10.0) == 4, "clock bounds work per call")
	_expect(clock.consume(Clock.TICK_DT) == 4 and clock.consume(Clock.TICK_DT) == 4, "clock retains backlog")
	_expect(clock.tick == 13 and clock.consume(-1.0) == 0 and clock.consume(NAN) == 0, "clock rejects invalid delta")
	var frame: Frame = Frame.new()
	frame.tick = 12
	frame.move_x = 0.12345678
	frame.move_y = -2.0
	frame.aim_yaw_delta = 0.0087654
	frame.aim_pitch_delta = -0.152733
	frame.buttons = 0x80
	frame.selected_slot = 2
	var restored: Frame = Frame.from_dict(JSON.parse_string(JSON.stringify(frame.to_dict(), "", true, true)))
	_expect(restored.to_dict() == frame.to_dict(), "quantized input round trip is lossless")
	_expect(frame.move_y == -1.0, "movement quantization clamps range")
	var bus: Bus = Bus.new()
	var payload: Dictionary = {"item": {"count": 1}}
	bus.emit_event(1, "pickup", payload)
	payload.item.count = 8
	var drained: Array[Dictionary] = bus.drain_events()
	_expect(drained[0].payload.item.count == 1 and bus.drain_events().is_empty(), "typed bus snapshots and drains once")
	_expect(Canonical.digest({"b": 2.0, "a": [1, true]}) == Canonical.digest({"a": [1.0, true], "b": 2}), "canonical hash ignores map order and JSON integer representation")
	_expect(Canonical.digest({"value": INF}).is_empty(), "canonical hash rejects nonfinite state")

func _test_replay() -> void:
	var frames: Array[Frame] = []
	for tick: int in 600:
		var frame: Frame = Frame.new()
		frame.tick = tick
		frame.move_x = 1.0 if tick < 300 else -0.5
		frame.move_y = 0.25
		frame.buttons = tick % 3
		frame.selected_slot = tick % 3
		frames.append(frame)
	var runner: Runner = Runner.new()
	var first: Dictionary = runner.run(Scenario.new(), frames, 1729)
	var second: Dictionary = runner.run(Scenario.new(), frames, 1729)
	_expect(bool(first.ok) and first.digest == second.digest and first.state == second.state, "600-tick same-seed replay is bit-identical")
	_expect(first.events == second.events and first.events.size() == 10, "replay events are deterministic")
	_expect(float(first.elapsed_ms) + float(second.elapsed_ms) < 200.0, "both 600-tick replay runs complete in less than 200 ms")
	frames[311].move_x = 0.75
	var changed: Dictionary = runner.run(Scenario.new(), frames, 1729)
	_expect(first.digest != changed.digest, "changing one input changes final digest")
	frames[0].tick = 1
	_expect(not bool(runner.run(Scenario.new(), frames, 1729).ok), "noncontiguous replay rejected")
	print("Replay: 600 ticks x2; identical SHA-256 %s; %.3f + %.3f ms; changed-frame digest differs." % [str(first.digest), float(first.elapsed_ms), float(second.elapsed_ms)])

func _test_ammo() -> void:
	var model: Ammo = Ammo.new()
	_expect(model.quiver_capacity() == 39, "authored total quiver capacity")
	for id: String in Ammo.FAMILY_IDS:
		var pickup: Dictionary = model.pickup(id, 100)
		_expect(int(pickup.accepted) == int(Ammo.FAMILY_CAPS[id]) and int(pickup.overflow) == 100 - int(Ammo.FAMILY_CAPS[id]), "family cap and pickup overflow: " + id)
	_expect(not model.consume("standard_arrow", 25) and model.count("standard_arrow") == 24, "failed consumption is atomic")
	_expect(model.select("bodkin_arrow") and model.consume("bodkin_arrow", 9), "select and consume piercing family")
	_expect(model.selected_family == "ashfire_arrow", "empty active family cycles to stocked family")
	_expect(not model.select("bodkin_arrow"), "empty family cannot be selected")
	var before: String = Canonical.digest(model.save_state())
	_expect(int(model.pickup("standard_arrow", -2).accepted) == 0 and Canonical.digest(model.save_state()) == before, "invalid pickup leaves loadout untouched")
	var copy: Ammo = Ammo.new()
	copy.load_state(JSON.parse_string(JSON.stringify(model.save_state())))
	_expect(copy.save_state() == model.save_state(), "ammo serializes deterministically")
	copy.load_state({"counts": {}, "selected_family": "bogus"})
	_expect(copy.cycle() == "standard_arrow", "all-empty cycle has stable fallback")
	copy.load_state({"counts": {"standard_arrow": 31}})
	_expect(copy.count("standard_arrow") == 24 and int(copy.overflow.standard_arrow) == 7, "over-cap saved ammo retained in overflow")
	copy.consume("standard_arrow", 3)
	_expect(copy.claim_overflow("standard_arrow") == 3 and int(copy.overflow.standard_arrow) == 4, "saved overflow can be claimed without duplication")

func _legacy_save(version: int = 13) -> Dictionary:
	return {"version": version, "game_id": "ashen-oath", "journey_id": "phase1-journey",
		"zone": "wychwood", "world_sector": "wychwood", "player_position": [0, 1, 8],
		"inventory": {"items": {"standard_arrow": 31, "bodkin_arrow": 2, "ashfire_arrow": 1, "redroot_potion": 3, "unknown_keepsake": 1},
			"coin": 27, "active_oil": "moon_oil", "oil_remaining_seconds": 123.0, "oil_version": 1},
		"equipment": {"selected_arrow_id": "bodkin_arrow"},
		"quests": {"active": {"main_teeth_in_rain": {"clue": true}}, "completed": {"main_road_of_crows": true},
			"completed_objectives": {"main_road_of_crows": {"arrive": true}}},
		"story_state": {"flags": {"evidence_report": "private"}}, "world_state": {"wychwood_pack_kills": 2}}

func _test_saves() -> void:
	var legacy: Dictionary = _legacy_save()
	var original: Dictionary = legacy.duplicate(true)
	var migrated: Dictionary = Codec.migrate(legacy)
	_expect(legacy == original, "save migration does not mutate caller")
	_expect(int(migrated.version) == 14 and migrated.ruleset_version == Clock.RULESET_VERSION, "v14 schema and ruleset stamp")
	_expect(migrated.quests == legacy.quests and migrated.story_state == legacy.story_state, "v13 quest facts and choices preserved")
	_expect(int(migrated.inventory.items.standard_arrow) == 24 and int(migrated.inventory.ammo_loadout.overflow.standard_arrow) == 7, "v13 excess arrows conserved")
	_expect(migrated.inventory.items.unknown_keepsake == 1 and migrated.inventory.items.redroot_potion == 3 and migrated.inventory.coin == 27, "unrelated inventory preserved")
	_expect(migrated.inventory.ammo_loadout.selected_family == "bodkin_arrow" and migrated.inventory.oil_remaining_seconds == 123.0, "selected family and finite oil preserved")
	_expect(Codec.migrate(migrated) == migrated, "migration is idempotent")
	for version: int in range(1, 14):
		_expect(int(Codec.migrate(_legacy_save(version)).get("version", 0)) == 14, "legacy version migration: %d" % version)
	_expect(Codec.migrate(_legacy_save(15)).is_empty(), "future save rejected")
	var unknown_ruleset: Dictionary = legacy.duplicate(true)
	unknown_ruleset.ruleset_version = "future-sim"
	_expect(Codec.migrate(unknown_ruleset).is_empty(), "unknown ruleset rejected")
	var parsed: Dictionary = Codec.decode(JSON.stringify(legacy), "fixture")
	_expect(bool(parsed.ok) and not str(parsed.legacy_state_token).is_empty(), "decode retains legacy Continue token")
	_expect(Codec.matches_payload_token(legacy, str(parsed.legacy_state_token)), "legacy payload token remains readable")
	var pointer: Dictionary = {"slot_id": "manual_1", "source": "primary", "journey_id": legacy.journey_id,
		"replay": false, "state_token": parsed.legacy_state_token, "payload": legacy}
	_expect(bool(Codec.resume_snapshot(pointer, "manual_1", "fixture", "content").ok), "legacy exact Continue snapshot survives v14")
	pointer.payload.inventory.coin = 28
	_expect(not bool(Codec.resume_snapshot(pointer, "manual_1", "fixture", "content").ok), "changed exact snapshot rejected")
	_expect(Codec.payload_token(migrated) == Codec.payload_token(JSON.parse_string(JSON.stringify(migrated))), "v14 token stable through storage round trip")
	var card: Dictionary = {"available": true, "summary": {"journey_id": "other", "replay": false}, "state_token": "other", "status": "ready"}
	var remembered: Dictionary = Selection.remembered_continue({"journey_id": "phase1-journey", "slot_id": "manual_1", "source": "primary", "replay": false}, card)
	_expect(not bool(remembered.get("available", false)), "Continue never silently switches journeys")
	print("Save migration: v1-v13 -> v14; items/quests/choices conserved; legacy Continue and overflow retained.")

func _definitions(path: String) -> Dictionary:
	if _data_cache.has(path):
		return _data_cache[path]
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_expect(false, "required test data: " + path)
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	_data_cache[path] = value if value is Dictionary else {}
	return _data_cache[path]

func _economy(coin: int = 100, items: Dictionary = {}, flags: Dictionary = {}, quests: Dictionary = {}, saved: Dictionary = {}, chapter: String = "opening") -> Economy:
	var model: Economy = Economy.new()
	model.configure(_definitions("res://data/vendors.json"), _definitions("res://data/items.json"),
		{"coin": coin, "items": items, "weapon_upgrades": [], "ingredients": {"redroot": 2}}, saved, flags, quests, chapter)
	return model

func _atomic_failure(model: Economy, vendor: String, item: String, amount: int, selling: bool, label: String) -> void:
	var before: String = Canonical.digest({"inventory": model.inventory_state(), "vendors": model.save_state()})
	var result: Dictionary = model.sell(vendor, item, amount) if selling else model.buy(vendor, item, amount)
	_expect(not bool(result.ok), label + " rejects")
	_expect(before == Canonical.digest({"inventory": model.inventory_state(), "vendors": model.save_state()}), label + " leaves both states unchanged")

func _test_economy() -> void:
	_atomic_failure(_economy(0), "tor_forge", "standard_arrow", 1, false, "insufficient coin")
	_atomic_failure(_economy(100, {"standard_arrow": 24}), "tor_forge", "standard_arrow", 1, false, "full quiver")
	_atomic_failure(_economy(0), "mira_apothecary", "redroot_potion", 1, false, "Mira insufficient coin")
	_atomic_failure(_economy(100, {"redroot_potion": 8}), "mira_apothecary", "redroot_potion", 1, false, "full medicine cap")
	for vendor: String in ["tor_forge", "mira_apothecary"]:
		var id: String = "bodkin_arrow" if vendor == "tor_forge" else "redroot_potion"
		for quantity: int in [-1, 0, 100]:
			_atomic_failure(_economy(100, {id: 8}), vendor, id, quantity, false, vendor + " invalid buy quantity %d" % quantity)
			_atomic_failure(_economy(100, {id: 8}), vendor, id, quantity, true, vendor + " invalid sell quantity %d" % quantity)
	_atomic_failure(_economy(), "tor_forge", "moon_oil", 1, false, "quest-gated oil")
	_atomic_failure(_economy(), "mira_apothecary", "rot_oil", 1, false, "knowledge-gated oil")
	_expect(bool(_economy(100, {}, {}, {"main_teeth_in_rain": true}).buy("tor_forge", "moon_oil", 1).ok), "active/completed quest unlocks stock")
	_expect(bool(_economy(100, {}, {"mira_truth": "confessed"}).buy("mira_apothecary", "rot_oil", 1).ok), "truth alias unlocks stock")
	var empty_vendor: Economy = _economy()
	_expect(empty_vendor.presentation("missing_vendor", "").entries.is_empty(), "empty shop presentation stays valid")
	var tor: Economy = _economy()
	var bought: Dictionary = tor.buy("tor_forge", "bodkin_arrow", 5)
	_expect(bool(bought.ok) and tor.inventory_state().coin == 80 and tor.owned("bodkin_arrow") == 5, "Tor purchase debits exact price and credits arrows")
	_expect(int(tor.quote("tor_forge", "bodkin_arrow", 1).stock_remaining) == 4, "Tor finite stock updated")
	var sold: Dictionary = tor.sell("tor_forge", "bodkin_arrow", 5)
	_expect(bool(sold.ok) and int(sold.quantity) == 2 and tor.owned("bodkin_arrow") == 3 and tor.inventory_state().coin == 82, "Tor buyback preserves road reserve")
	var mira: Economy = _economy()
	_expect(bool(mira.buy("mira_apothecary", "redroot_potion", 5).ok) and mira.inventory_state().coin == 70, "Mira purchase")
	_expect(bool(mira.sell("mira_apothecary", "redroot_potion", 5).ok) and mira.owned("redroot_potion") == 2 and mira.inventory_state().coin == 73, "Mira buyback preserves medicine")
	_expect(int(_economy(100, {}, {"iron_fate": "surrendered"}).quote("tor_forge", "bodkin_arrow", 1).unit_price) == 5, "Tor bounded story price")
	_expect(int(_economy(100, {}, {"mira_truth": "confessed", "mill_operation": "restitution"}).quote("mira_apothecary", "redroot_potion", 1).unit_price) == 4, "Mira compounded story price")
	var reserve: Economy = _economy(0)
	_expect(bool(reserve.buy("tor_forge", "__emergency_arrows__", 1).ok) and reserve.owned("standard_arrow") == 5, "free emergency arrows")
	_atomic_failure(reserve, "tor_forge", "__emergency_arrows__", 1, false, "once-only reserve")
	var cap_purchase: Economy = _economy(100, {"bodkin_arrow": 8})
	_expect(int(cap_purchase.buy("tor_forge", "bodkin_arrow", 5).quantity) == 1 and cap_purchase.owned("bodkin_arrow") == 9, "partial purchase respects family cap")
	var depleted: Economy = _economy()
	depleted.buy("tor_forge", "bodkin_arrow", 9)
	var carried: Dictionary = depleted.inventory_state()
	carried.items.bodkin_arrow = 0
	var restored: Economy = _economy(100, carried.items, {}, {}, depleted.save_state())
	_atomic_failure(restored, "tor_forge", "bodkin_arrow", 1, false, "saved depleted stock")
	var new_chapter: Economy = _economy(100, carried.items, {}, {}, depleted.save_state(), "next")
	_expect(bool(new_chapter.buy("tor_forge", "bodkin_arrow", 1).ok), "new chapter supplies replenish")
	var old_chapter: Economy = _economy(100, carried.items, {}, {}, new_chapter.save_state(), "opening")
	_atomic_failure(old_chapter, "tor_forge", "bodkin_arrow", 1, false, "revisiting chapter cannot reset stock")
	print("Economy: Tor/Mira prices, caps, gates, stock, reserves and atomic rejection pass.")

func _test_adapters() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.load_items("res://data/items.json")
	inventory.load_state(Codec.migrate(_legacy_save()).inventory, false)
	_expect(inventory.get_ammo_count("standard_arrow") == 24 and inventory.items.unknown_keepsake == 1, "inventory adapter preserves migrated items")
	_expect(inventory.add_ammo("standard_arrow", 5) == 0 and inventory.consume("standard_arrow") and inventory.get_ammo_count("standard_arrow") == 23, "inventory adapter delegates ammo caps and consumption")
	_expect(inventory.save_state().ammo_loadout.overflow.standard_arrow == 7, "inventory adapter preserves legacy overflow")
	inventory.coin = 100
	var vendor: Vendor = Vendor.new()
	vendor.load_vendors("res://data/vendors.json")
	_expect(bool(vendor.buy("tor_forge", "bodkin_arrow", 1, inventory).ok) and inventory.coin == 96 and inventory.items.bodkin_arrow == 3, "vendor adapter applies complete pure receipt")
	_expect(not bool(vendor.buy("tor_forge", "standard_arrow", 0, inventory).ok) and inventory.coin == 96, "vendor adapter refuses invalid transaction")
	var view: Dictionary = vendor.presentation("tor_forge", "bodkin_arrow", inventory)
	_expect(view.selected_id == "bodkin_arrow" and not view.entries.is_empty(), "inventory panel receives model-owned vendor presentation")
	var state: Dictionary = vendor.save_state()
	vendor.load_state(state)
	_expect(vendor.save_state() == state, "vendor stock ledger survives adapter restore")
	vendor.free()
	inventory.free()
	print("Adapters: inventory, vendor transactions, presentation and stock restore pass.")
