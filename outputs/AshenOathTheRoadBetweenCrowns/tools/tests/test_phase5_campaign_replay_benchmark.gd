extends SceneTree
## Model-driven vertical slice, not a rendered campaign or browser acceptance run.
const Clock = preload("res://scripts/core/sim_clock.gd")
const Frame = preload("res://scripts/core/input_frame.gd")
const Rng = preload("res://scripts/core/seeded_rng.gd")
const Events = preload("res://scripts/core/sim_event_bus.gd")
const Runner = preload("res://scripts/core/replay_runner.gd")
const Canonical = preload("res://scripts/core/canonical_state.gd")
const Ammo = preload("res://scripts/models/ammo_loadout_model.gd")
const Economy = preload("res://scripts/models/vendor_economy_model.gd")
const Transition = preload("res://scripts/models/world_transition_model.gd")
const Player = preload("res://scripts/models/player_combat_locomotion_model.gd")
const Bow = preload("res://scripts/models/bow_aim_release_model.gd")
const Enemy = preload("res://scripts/models/enemy_tactics_model.gd")
const Cast = preload("res://scripts/models/living_cast_model.gd")
const Codec = preload("res://scripts/models/save_payload_codec.gd")
const Quests = preload("res://scripts/quest_manager.gd")
const RULESET_VERSION: String = Clock.RULESET_VERSION

class RunSnapshot extends RefCounted:
	## Durable checkpoint only: transient animation, cast gaze and attack timers are not saves.
	static func digest(payload: Dictionary) -> String:
		return Canonical.digest(Codec.migrate(payload))

class CampaignSlice extends "res://scripts/core/deterministic_model.gd":
	var cast: Cast = Cast.new()
	var player: Player = Player.new()
	var bow: Bow = Bow.new()
	var ammo: Ammo = Ammo.new()
	var enemy: Enemy = Enemy.new()
	var economy: Economy = Economy.new()
	var travel: Transition = Transition.new()
	var quests: Quests = Quests.new()
	var base_payload: Dictionary = {}
	var receipts: Array[Dictionary] = []
	var enemy_health: float = 90.0
	var contacts: int = 0
	var parries: int = 0
	var shots: int = 0
	var crossed: bool = false
	var invalid_steps: int = 0
	var routine_data: Dictionary
	var item_data: Dictionary
	var vendor_data: Dictionary

	func _init() -> void:
		item_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
		vendor_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/vendors.json"))
		routine_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/cast_life.json"))
		economy.configure(vendor_data, item_data, {"items":{"standard_arrow":2},"coin":100})
		ammo.load_inventory(economy.inventory_state())
		quests.load_quests("res://data/quests.json")
		cast.reset(51017)
		for id: String in ["blacksmith_tor", "mira", "rook"]:
			cast.register_actor(id, Cast.ROUTINE_PROFILES[id], Vector3.ZERO)
		enemy.position = Vector3(0, 0, -1)
		enemy.home_position = enemy.position
		enemy.damage = 3.0
		travel.enter_menu()
		var epoch: int = travel.prepare_opening("greyfen")
		travel.pack_mounted("opening", epoch)
		travel.mark_prepared("greyfen", epoch)

	func step(frame: Frame, delta: float, rng: Rng, events: Events) -> void:
		cast.advance(delta)
		if frame.tick == 0:
			var epoch: int = travel.request_travel("greyfen")
			if not travel.commit("greyfen", epoch, true, true): invalid_steps += 1
			quests.start_quest("main_road_of_crows")
			quests.complete_objective("main_road_of_crows", "speak_anwen")
			_buy("tor_forge", "standard_arrow", 6, frame.tick, events)
			_buy("tor_forge", "bodkin_arrow", 2, frame.tick, events)
			_buy("mira_apothecary", "bitterleaf_tonic", 1, frame.tick, events)
			ammo.load_inventory(economy.inventory_state())
		if frame.tick % 200 == 0:
			var phase_index: int = frame.tick / 200
			cast.set_chapter("", ["morning", "midday", "evening"][phase_index])
			for id: String in cast.actors:
				cast.actors[id].profile = cast.scheduled_intent(routine_data, id,
					{"work":[1,0,1],"rest":[2,0,2]}, Cast.ROUTINE_PROFILES[id],
					[480.0,780.0,1140.0][phase_index])
				if not cast.reserve_station("work:" + id, id): invalid_steps += 1
		for id: String in cast.actors:
			if cast.proximity(id, 3.5 if frame.tick % 90 < 30 else 5.0, false, true, true):
				events.emit_event(frame.tick, "greeting", {"actor":id})
		if frame.tick == 60: travel.prepare_adjacent("wychwood")
		if frame.tick == 120:
			var epoch: int = travel.transition_epoch
			if not travel.pack_mounted("wychwood", epoch) or not travel.mark_prepared("wychwood", epoch): invalid_steps += 1
			epoch = travel.request_travel("wychwood")
			crossed = travel.commit("wychwood", epoch, true, true)
			events.emit_event(frame.tick, "crossing", {"zone":travel.active_zone_id})
		if crossed:
			_combat(frame, delta, rng, events)
		if frame.tick == 520:
			for clue: String in ["vargan_wire", "bram", "sella"]:
				quests.complete_evidence("main_road_of_crows", clue)
			events.emit_event(frame.tick, "evidence", {"stage":quests.is_objective_done("main_road_of_crows", "evidence_ready")})
		if frame.tick == 560 and enemy_health <= 0.0:
			quests.complete_objective("main_road_of_crows", "fight_ghoulkin")

	func _buy(vendor: String, item: String, count: int, tick: int, events: Events) -> void:
		var receipt: Dictionary = economy.buy(vendor, item, count)
		receipts.append(receipt)
		if not bool(receipt.ok): invalid_steps += 1
		events.emit_event(tick, "purchase", {"vendor":vendor,"item":item,"ok":receipt.ok})

	func _combat(frame: Frame, delta: float, rng: Rng, events: Events) -> void:
		var local: Events = Events.new()
		player.step(frame, delta, local)
		bow.step(frame, delta, ammo, local, {"velocity":28.0})
		for event: Dictionary in local.drain_events():
			if event.kind == "blade_contact":
				contacts += 1
				enemy_health = maxf(0.0, enemy_health - float(event.payload.damage))
			elif event.kind == "arrow_released":
				shots += 1
				enemy_health = maxf(0.0, enemy_health - 28.0 * float(event.payload.damage_mult))
			events.emit_event(int(event.tick), str(event.kind), event.payload)
		enemy.step(player.position, enemy.home_position, enemy_health / 90.0, rng, delta, local, frame.tick)
		for event: Dictionary in local.drain_events():
			if event.kind == "enemy_contact":
				if player.receive_damage(float(event.payload.damage), frame.buttons & Player.BLOCK != 0, local) == "parried":
					parries += 1
					enemy.stagger(1.15)
			events.emit_event(int(event.tick), str(event.kind), event.payload)
		for event: Dictionary in local.drain_events():
			events.emit_event(int(event.tick), str(event.kind), event.payload)

	func payload() -> Dictionary:
		var data: Dictionary = base_payload.duplicate(true)
		data.merge({"version":14,"ruleset_version":RULESET_VERSION,"game_id":"ashen-oath",
			"journey_id":"phase5-isolated-model-replay","zone":travel.active_zone_id,
			"world_sector":travel.active_zone_id,"player_position":[player.position.x,player.position.y,player.position.z],
			"inventory":ammo.write_inventory(economy.inventory_state()),"vendors":economy.save_state(),
			"quests":quests.save_state(),"story_state":{"flags":{},"values":{},"evidence":{}},
			"world_state":{"wychwood_pack_kills":1 if enemy_health <= 0.0 else 0},
			"player_health":{"health":player.health,"max_health":125.0},
			"player_stamina":{"stamina":player.stamina,"max_stamina":100.0},
			"equipment":{"selected_arrow_id":ammo.selected_family}}, true)
		return Codec.migrate(data)

	func restore(data: Dictionary) -> void:
		base_payload = data.duplicate(true)
		economy.configure(vendor_data, item_data, data.inventory, data.vendors)
		ammo.load_inventory(data.inventory)
		quests.load_state(data.quests)
		player.position = Vector3(data.player_position[0], data.player_position[1], data.player_position[2])
		player.health = float(data.player_health.health)
		player.stamina = float(data.player_stamina.stamina)
		enemy_health = 0.0 if int(data.world_state.wychwood_pack_kills) == 1 else 90.0
		var epoch: int = travel.request_travel(str(data.zone))
		travel.commit(str(data.zone), epoch, true, true)

	func save_state() -> Dictionary:
		return {"durable":payload(),"cast":cast.snapshot(),"travel":travel.snapshot(),
			"player":player.save_state(),"bow":bow.save_state(),"enemy":enemy.save_state(),
			"contacts":contacts,"parries":parries,"shots":shots,"enemy_health":enemy_health,
			"receipts":receipts,"invalid_steps":invalid_steps}

	func dispose() -> void:
		quests.free()

var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run()
	for failure: String in failures: printerr("FAIL: " + failure)
	print("PHASE 5 CAMPAIGN REPLAY: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _frames() -> Array[Frame]:
	var result: Array[Frame] = []
	for tick: int in 600:
		var frame: Frame = Frame.new()
		frame.tick = tick
		if tick in [185, 330]: frame.buttons |= Player.LIGHT
		if tick in range(145, 170): frame.buttons |= Player.BLOCK
		if tick in range(220, 281) or tick in range(440, 496): frame.buttons |= Bow.AIM | Bow.FIRE
		result.append(frame)
	return result

func _run() -> void:
	var started: int = Time.get_ticks_usec()
	var first: CampaignSlice = CampaignSlice.new()
	var second: CampaignSlice = CampaignSlice.new()
	var runner: Runner = Runner.new()
	var frames: Array[Frame] = _frames()
	var a: Dictionary = runner.run(first, frames, 51017)
	var b: Dictionary = runner.run(second, frames, 51017)
	_check(a.ok and b.ok and a.digest == b.digest and a.events == b.events, "full vertical-slice replay and events are bit-identical")
	_check(a.state.ruleset_version == RULESET_VERSION, "replay uses current RULESET_VERSION")
	_check(first.invalid_steps == 0 and first.crossed and first.travel.active_zone_id == "wychwood", "explicit opening and prepared Wychwood travel succeed")
	_check(first.receipts.size() == 3 and first.economy.inventory_state().coin == 81, "Tor/Mira exact purchase receipts and coin conservation")
	_check(first.shots == 2 and first.ammo.count("standard_arrow") == 6 and first.ammo.count("bodkin_arrow") == 2, "hybrid bow consumes one arrow per release, preserving other families")
	_check(first.contacts == 2 and first.parries > 0 and first.enemy_health <= 0.0, "encounter includes actual melee contacts, parry and bow defeat")
	_check(first.quests.is_objective_done("main_road_of_crows", "evidence_ready") and first.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"), "out-of-order clues and earned defeat advance quest stages")
	_check(not first.quests.is_objective_done("main_road_of_crows", "oren"), "omitted optional evidence stays unknown")
	_check(float(a.elapsed_ms) < 250.0 and float(b.elapsed_ms) < 250.0, "each 600-tick combat/cast replay is strictly below 250 ms")
	var saved: Dictionary = first.payload()
	var decoded: Dictionary = Codec.decode(JSON.stringify(saved, "", true, true), "isolated-phase5-checkpoint")
	_check(bool(decoded.get("ok", false)), "SavePayloadCodec decodes checkpoint without disk or user saves")
	if bool(decoded.get("ok", false)):
		var restored: CampaignSlice = CampaignSlice.new()
		restored.restore(decoded.data)
		_check(RunSnapshot.digest(saved) == RunSnapshot.digest(restored.payload()), "fresh-session durable RunSnapshot SHA-256 matches bit-for-bit")
		_check(restored.quests.is_objective_done("main_road_of_crows", "evidence_ready") and not restored.quests.is_objective_done("main_road_of_crows", "oren"), "reload retains observed and omitted objective truth")
		_check(Canonical.digest(restored.ammo.save_state()) == Canonical.digest(first.ammo.save_state()), "reload preserves the exact canonical quiver")
		_check(Canonical.digest(restored.economy.save_state()) == Canonical.digest(saved.vendors), "reload preserves normalized vendor stock ledgers across JSON numeric types")
		var before: String = Canonical.digest(restored.quests.save_state())
		_check(not restored.quests.complete_objective("main_road_of_crows", "fight_ghoulkin") and before == Canonical.digest(restored.quests.save_state()), "repeated resolution cannot re-award or change quest state")
		restored.dispose()
	var changed: CampaignSlice = CampaignSlice.new()
	frames[185].buttons = 0
	_check(runner.run(changed, frames, 51017).digest != a.digest, "changed input changes campaign digest")
	changed.dispose()
	first.dispose()
	second.dispose()
	var total_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	_check(total_ms < 1000.0, "full vertical-slice replay, duplicate run, reload and sensitivity check are strictly below 1000 ms")
	print("Campaign ruleset: %s; 600 ticks x2; SHA-256 %s" % [RULESET_VERSION,a.digest])
	print("Benchmark: combat/cast %.3f / %.3f ms (<250 each); full replay + save/reload %.3f ms (<1000)." % [a.elapsed_ms,b.elapsed_ms,total_ms])
	print("RunSnapshot (durable checkpoint): %s; Tor/Mira, quiver, Wychwood, melee/parry/bow and evidence retained." % RunSnapshot.digest(saved))
