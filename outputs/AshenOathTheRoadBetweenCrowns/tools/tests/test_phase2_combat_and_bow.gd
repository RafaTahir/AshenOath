extends SceneTree
const Frame = preload("res://scripts/core/input_frame.gd")
const Clock = preload("res://scripts/core/sim_clock.gd")
const Rng = preload("res://scripts/core/seeded_rng.gd")
const Events = preload("res://scripts/core/sim_event_bus.gd")
const Runner = preload("res://scripts/core/replay_runner.gd")
const Canonical = preload("res://scripts/core/canonical_state.gd")
const PlayerModel = preload("res://scripts/models/player_combat_locomotion_model.gd")
const Bow = preload("res://scripts/models/bow_aim_release_model.gd")
const Enemy = preload("res://scripts/models/enemy_tactics_model.gd")
const Ammo = preload("res://scripts/models/ammo_loadout_model.gd")
const PlayerScene = preload("res://scripts/player_controller.gd")
const EnemyScene = preload("res://scripts/enemy_ai.gd")
const Inventory = preload("res://scripts/inventory_manager.gd")

class Duel extends "res://scripts/core/deterministic_model.gd":
	const PlayerBrain = preload("res://scripts/models/player_combat_locomotion_model.gd")
	const BowBrain = preload("res://scripts/models/bow_aim_release_model.gd")
	const EnemyBrain = preload("res://scripts/models/enemy_tactics_model.gd")
	const Quiver = preload("res://scripts/models/ammo_loadout_model.gd")
	var player: PlayerBrain = PlayerBrain.new()
	var bow: BowBrain = BowBrain.new()
	var ammo: Quiver = Quiver.new()
	var enemies: Array[EnemyBrain] = []
	var health: Array[float] = [90.0, 140.0]
	var phases: int = 0

	func _init() -> void:
		ammo.load_state({"counts": {"standard_arrow": 24, "bodkin_arrow": 9, "ashfire_arrow": 6}})
		for index: int in 2:
			var enemy: EnemyBrain = EnemyBrain.new()
			enemy.identity = "ghoulkin" if index == 0 else "bell_eater"
			enemy.boss = index == 1
			enemy.position = Vector3(0.0, 0.0, -1.5 - index)
			enemy.home_position = enemy.position
			enemy.damage = 3.0
			enemies.append(enemy)

	func step(frame: Frame, delta: float, rng: Rng, events: Events) -> void:
		var local: Events = Events.new()
		player.step(frame, delta, local)
		bow.step(frame, delta, ammo, local, {"damage": 28.0, "velocity": 28.0})
		for event: Dictionary in local.drain_events():
			if event.kind == "blade_contact":
				health[0] = maxf(0.0, health[0] - float(event.payload.damage))
			elif event.kind == "arrow_released":
				health[1] = maxf(0.0, health[1] - 28.0 * float(event.payload.damage_mult))
			elif event.kind == "beam_released":
				health[1] = maxf(0.0, health[1] - 35.0 - 35.0 * float(event.payload.charge_ratio))
			events.emit_event(int(event.tick), str(event.kind), event.payload)
		for index: int in enemies.size():
			var enemy: EnemyBrain = enemies[index]
			var maximum: float = 90.0 if index == 0 else 140.0
			enemy.step(player.position, enemy.home_position, health[index] / maximum, rng, delta, local, frame.tick, true, index == frame.tick % 2)
			for event: Dictionary in local.drain_events():
				if event.kind == "enemy_contact" and player.position.distance_to(enemy.position) < 2.0:
					var outcome: String = player.receive_damage(float(event.payload.damage), frame.buttons & PlayerBrain.BLOCK != 0, local)
					if outcome == "parried":
						enemy.stagger(1.15)
				if event.kind == "boss_phase_changed":
					phases += 1
				events.emit_event(int(event.tick), str(event.kind), event.payload)
			for event: Dictionary in local.drain_events():
				events.emit_event(int(event.tick), str(event.kind), event.payload)

	func save_state() -> Dictionary:
		var agents: Array[Dictionary] = []
		for enemy: EnemyBrain in enemies:
			agents.append(enemy.save_state())
		return {"player": player.save_state(), "bow": bow.save_state(), "ammo": ammo.save_state(),
			"enemies": agents, "enemy_health": health.duplicate(), "phase_transitions": phases}

class ArenaInput extends Node:
	var actions: Dictionary = {}
	var previous: Dictionary = {}
	var move: Vector2 = Vector2.ZERO

	func set_actions(next: Dictionary) -> void:
		previous = actions.duplicate()
		actions = next.duplicate()

	func is_gameplay_context() -> bool:
		return true

	func movement_vector() -> Vector2:
		return move

	func is_action_pressed(action: StringName) -> bool:
		return bool(actions.get(action, false))

	func is_action_just_pressed(action: StringName) -> bool:
		return bool(actions.get(action, false)) and not bool(previous.get(action, false))

	func is_action_just_released(action: StringName) -> bool:
		return not bool(actions.get(action, false)) and bool(previous.get(action, false))

	func rumble(_low: float, _high: float, _duration: float) -> void:
		pass

var checks: int = 0
var failures: Array[String] = []
var shots: Array[Dictionary] = []
var parries: int = 0

func _init() -> void:
	call_deferred("_run")

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _run() -> void:
	_test_replay()
	_test_bow()
	_test_combat()
	await _test_arena()
	if failures.is_empty():
		print("PHASE 2 PASS: %d checks; combat replay, bow invariants and 180-tick scene integration." % checks)
		quit(0)
	else:
		for failure: String in failures:
			printerr("FAIL: " + failure)
		quit(1)

func _test_replay() -> void:
	var frames: Array[Frame] = []
	for tick: int in 600:
		var frame: Frame = Frame.new()
		frame.tick = tick
		frame.move_x = 0.12 if tick % 120 < 60 else -0.12
		if tick in [12, 125, 330, 500]:
			frame.buttons |= PlayerModel.LIGHT
		if tick == 180:
			frame.buttons |= PlayerModel.HEAVY
		if tick in range(40, 90) or tick in range(410, 440):
			frame.buttons |= Bow.AIM | Bow.FIRE
		if tick in range(210, 300):
			frame.buttons |= PlayerModel.CAST
		if tick in range(340, 360):
			frame.buttons |= PlayerModel.BLOCK
		if tick == 370:
			frame.buttons |= PlayerModel.DODGE
		frames.append(frame)
	var runner: Runner = Runner.new()
	var first: Dictionary = runner.run(Duel.new(), frames, 42017)
	var second: Dictionary = runner.run(Duel.new(), frames, 42017)
	expect(first.ok and second.ok and first.digest == second.digest, "bit-exact 600-tick duel hash")
	expect(first.state.model.player.health == second.state.model.player.health and first.state.model.player.stamina == second.state.model.player.stamina, "identical HP and stamina")
	expect(first.events == second.events and not first.events.is_empty(), "identical complete combat event log")
	expect(first.state.model.phase_transitions > 0, "real boss-health threshold causes phase transition")
	frames[400].move_x = 1.0
	expect(runner.run(Duel.new(), frames, 42017).digest != first.digest, "changed combat input changes state")
	print("Combat replay: 600 ticks x2; SHA-256 %s; %.3f + %.3f ms; HP %.2f; stamina %.2f; phases %d." % [first.digest, first.elapsed_ms, second.elapsed_ms, first.state.model.player.health, first.state.model.player.stamina, first.state.model.phase_transitions])

func _shot(hold_ticks: int, ads: bool = true) -> Dictionary:
	var model: Bow = Bow.new()
	var ammo: Ammo = Ammo.new()
	ammo.load_state({"counts": {"standard_arrow": 24}})
	var events: Events = Events.new()
	for tick: int in hold_ticks + 1:
		var frame: Frame = Frame.new()
		frame.tick = tick
		frame.buttons = (Bow.FIRE if tick < hold_ticks else 0) | (Bow.AIM if ads else 0)
		model.step(frame, Clock.TICK_DT, ammo, events)
	var released: Array[Dictionary] = events.drain_events()
	return {"payload": released[0].payload if not released.is_empty() else {}, "count": ammo.count("standard_arrow")}

func _test_bow() -> void:
	var quick: Dictionary = _shot(1, false)
	var full: Dictionary = _shot(65)
	expect(not quick.payload.is_empty() and not full.payload.is_empty(), "quick tap and full draw both release")
	expect(quick.payload.speed < full.payload.speed and quick.payload.damage_mult < full.payload.damage_mult, "quick/full ballistic scaling")
	expect(quick.count == 23 and full.count == 23, "each release consumes exactly one arrow")
	var model: Bow = Bow.new()
	var ammo: Ammo = Ammo.new()
	ammo.load_state({"counts": {"standard_arrow": 2, "bodkin_arrow": 2}})
	var events: Events = Events.new()
	var frame: Frame = Frame.new()
	frame.buttons = Bow.AIM | Bow.FIRE
	model.step(frame, Clock.TICK_DT, ammo, events)
	frame.buttons |= Bow.DODGE
	model.step(frame, Clock.TICK_DT, ammo, events)
	expect(ammo.count("standard_arrow") == 2 and events.drain_events().is_empty(), "dodge cancels draw without consumption or shot")
	frame.buttons = 0
	model.step(frame, Clock.TICK_DT, ammo, events)
	frame.buttons = Bow.AIM | Bow.FIRE
	model.step(frame, Clock.TICK_DT, ammo, events)
	frame.selected_slot = 1
	model.step(frame, Clock.TICK_DT, ammo, events)
	expect(model.draw_time == 0.0 and model.requires_release and ammo.count("bodkin_arrow") == 2, "mid-draw family switch resets and requires release")
	ammo.load_state({"counts": {}})
	model.cancel(false)
	model.previous_buttons = 0
	frame.buttons = Bow.FIRE
	model.step(frame, Clock.TICK_DT, ammo, events)
	var missing: Array[Dictionary] = events.drain_events()
	expect(missing.size() == 1 and missing[0].kind == "arrow_unavailable", "empty quiver emits unavailable and no shot")
	model = Bow.new()
	model.clearance = false
	frame.selected_slot = 0
	ammo.load_state({"counts": {"standard_arrow": 3}})
	model.step(frame, Clock.TICK_DT, ammo, events)
	frame.buttons = 0
	model.step(frame, Clock.TICK_DT, ammo, events)
	expect(ammo.count("standard_arrow") == 3 and events.drain_events()[0].kind == "bow_obstructed", "blocked muzzle cannot spend ammo")
	print("Bow: quick/full scaling, one-arrow release, empty quiver, dodge cancel, switch reset and obstruction pass.")

func _test_combat() -> void:
	var player: PlayerModel = PlayerModel.new()
	var events: Events = Events.new()
	player.parry_window = 0.3
	expect(player.receive_damage(20.0, false, events) == "parried" and player.health == 125.0 and player.stamina == 90.0, "parry window and stamina cost")
	expect(player.receive_damage(20.0, true, events) == "blocked" and player.health == 120.0 and player.stamina == 78.0, "guard damage and stamina cost")
	player.dodge_time = 0.3
	expect(player.receive_damage(100.0, false, events) == "dodged" and player.health == 120.0, "dodge i-frames")
	player.dodge_time = 0.0
	player.receive_damage(999.0, false, events)
	expect(player.dead and events.drain_events().any(func(e: Dictionary) -> bool: return e.kind == "died"), "hurt/death transition emits died")
	var enemy: Enemy = Enemy.new()
	enemy.surrender_eligible = true
	enemy.step(Vector3.ZERO, Vector3.ZERO, 0.20, Rng.new(3), Clock.TICK_DT, events, 1)
	expect(enemy.surrender_offer and enemy.mode == "surrender", "nonlethal surrender supersedes combat")
	expect(Enemy.incoming_damage(99.0, "steel", "", "human", false, "captain_senn", 4.0) == 3.0, "Senn cannot be killed by ordinary damage")
	expect(Enemy.phase_for_health(0.30) == 3 and Enemy.phase_for_health(0.60) == 2, "boss phase thresholds")
	print("Combat rules: guard/parry, dodge i-frames, death, nonlethal Senn and surrender pass.")

func _test_arena() -> void:
	var orphan_before: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var arena: Node3D = Node3D.new()
	root.add_child(arena)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	floor_collision.shape = box
	floor_body.position.y = -0.5
	floor_body.add_child(floor_collision)
	arena.add_child(floor_body)
	var controls: ArenaInput = ArenaInput.new()
	arena.add_child(controls)
	var inventory: Inventory = Inventory.new()
	inventory.load_items("res://data/items.json")
	arena.add_child(inventory)
	var player: PlayerScene = PlayerScene.new(false)
	player.position = Vector3(0, 0.1, 0)
	player.input_source = controls
	arena.add_child(player)
	player.bind_inventory(inventory)
	player.arrow_requested.connect(func(request: Dictionary) -> void: shots.append(request))
	player.parried.connect(func() -> void: parries += 1)
	var enemies: Array[EnemyScene] = []
	for index: int in 2:
		var enemy: EnemyScene = EnemyScene.new(false)
		enemy.position = Vector3(6.0 + index, 0.1, -2)
		arena.add_child(enemy)
		enemy.setup("ghoulkin", {"health": 60.0, "damage": 2.0, "speed": 2.0}, player)
		enemies.append(enemy)
	for signal_name: String in ["blade_contact_requested", "potion_requested", "bomb_requested", "beam_requested", "beam_phase_changed", "arrow_requested", "arrow_unavailable", "footstep", "ability_hint", "parried", "blocked", "hurt", "stamina_exhausted", "died"]:
		expect(player.has_signal(signal_name), "preserved player signal: " + signal_name)
	for signal_name: String in ["died", "damaged", "windup_started", "attack_resolved", "special_attack_resolved", "special_attack_interrupted", "parry_window_opened", "boss_phase_changed"]:
		expect(enemies[0].has_signal(signal_name), "preserved enemy signal: " + signal_name)
	var previous_hz: int = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 240
	player.weapon_mode = "bow"
	for tick: int in 180:
		controls.set_actions({"aim_bow": tick < 100, "fire_bow": (tick >= 25 and tick < 80) or tick == 150})
		await physics_frame
	Engine.physics_ticks_per_second = previous_hz
	expect(shots.size() == 2 and inventory.get_ammo_count("standard_arrow") == 22, "scene ADS and hip-fire releases route through model and ammo once each")
	player.parry_window = 0.3
	player.take_damage(5.0)
	expect(parries == 1, "scene parry signal preserved")
	expect(player._simulation_tick >= 30 and enemies[0].simulation_clock.tick >= 30, "real arena physics advances both 60 Hz adapters")
	arena.free()
	await process_frame
	expect(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphan_before, "arena frees all owned nodes without orphan leaks")
	print("Scene integration: 180 physics ticks at 240 Hz; fixed 60 Hz simulation; bow/parry signals; no orphan-node growth (rendering disabled).")
