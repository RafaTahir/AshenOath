extends SceneTree
## Real contact queries, attack resolution, normal defence inputs and restored field devices.
const Enemy = preload("res://scripts/enemy_ai.gd")
const Player = preload("res://scripts/player_controller.gd")
const Combat = preload("res://scripts/combat_manager.gd")
const Settings = preload("res://scripts/settings_manager.gd")

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_fn: String, file: String, line: int, code: String, detail: String, _editor: bool, kind: int, _stacks: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING: errors.append("%s:%d %s %s" % [file, line, code, detail])

class ClearPath extends RefCounted:
	func build_route(start: Vector3, finish: Vector3, _radius: float, _actor: CollisionObject3D) -> Array[Vector3]:
		return [start, finish]
	func validate_segment(_start: Vector3, _finish: Vector3, _radius: float) -> bool:
		return true

class DeviceHost extends Node3D:
	var zone_root: Node3D
	var player: CharacterBody3D
	var active_enemies: Array = []
	var current_zone_id := "wychwood"
	var game_started := true
	var zone_transition_pending := false
	var story_save_pending := false
	var audio: Node
	func play_spatial_event(_id: String, _a: Vector3, _b: Vector3, _c: float, _d: float, _e: float) -> void: pass
	func _persist_story_action() -> void: pass

var scene := DeviceHost.new()
var combat := Combat.new()
var player := Player.new(false)
var difficulty := Settings.new()
var definitions: Dictionary
var serial := 0
var checks := 0
var failures: Array[String] = []
var log_capture := ErrorLog.new()

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _spawn(id: String) -> Enemy:
	var actor := Enemy.new(false)
	scene.add_child(actor)
	actor.setup(id, definitions[id], player)
	actor.set_physics_process(false)
	actor.can_see_player = true
	return actor

func _arrow(actor: Enemy, from: Vector3, ammo: String = "standard_arrow") -> Dictionary:
	var center := actor.global_position + Vector3.UP * 0.9
	return combat.resolve_arrow_shot([actor], {"origin":center + from * 5.0, "endpoint":center - from * 2.0,
		"direction":-from, "damage":10.0, "source_tag":"arrow_" + ammo, "report_miss":false})

func _cut(actor: Enemy, from: Vector3, heavy: bool = false, blade: String = "steel") -> Dictionary:
	serial += 1
	player.equipment_loadout.select_blade(blade)
	player.equipment_loadout.set_sword_drawn(true)
	player.hurt_react_time = 0.0
	player.position = actor.position + from * 1.45
	var center := actor.global_position + Vector3.UP * 0.92
	var tangent := from.cross(Vector3.UP) * 0.3
	return combat.resolve_player_blade_contact(player, [actor], {"attack_id":serial, "blade_id":blade,
		"damage":10.0, "heavy":heavy, "reach":2.0, "base":center + tangent + from * 0.6,
		"tip":center + tangent - from * 0.3, "previous_base":center - tangent + from * 0.6,
		"previous_tip":center - tangent - from * 0.3}, "")

func _finish(actor: Enemy, fps: float = 60.0) -> void:
	while actor.pending_attack_time > 0.0: actor.enemy_strike_view._tick_pending_attack(1.0 / fps)

func _ghoul() -> void:
	if not InputMap.has_action("block"): InputMap.add_action("block")
	for mode: String in ["story", "standard", "veteran"]:
		difficulty.settings.difficulty = mode
		player.apply_difficulty_profile(difficulty.get_difficulty_profile())
		for defense: String in ["open", "block", "parry", "dodge", "miss"]:
			var actor := _spawn("ghoulkin")
			actor.health_component.damage(12)
			var before: float = actor.health_component.health
			player.position = Vector3.FORWARD * 0.42
			player.health_component.configure(125)
			player.stamina_component.stamina = 100
			player.sword_sheathed = false
			player.dodge_time = 0.0
			player.parry_window = 0.0
			_check(actor._begin_attack(), mode + " arms clutch against " + defense)
			match defense:
				"block": Input.action_press("block")
				"parry": player.parry_window = player.get_parry_window_duration()
				"dodge": player.dodge_time = 0.25
				"miss": player.position = Vector3.BACK * 5.0
			_finish(actor)
			var lost := 125.0 - float(player.health_component.health)
			var fed := float(actor.health_component.health) - before
			var label := mode + " clutch vs " + defense
			if defense == "open":
				_check(is_equal_approx(lost, 4.0 * float(difficulty.get_difficulty_profile().incoming_damage_multiplier)), label + " preserves player damage")
				_check(is_equal_approx(fed, minf(lost * 0.75, 3.0)), label + " restores a capped share of the wound")
			else:
				_check(is_zero_approx(fed), label + " cannot feed")
				_check(lost > 0.0 if defense == "block" else is_zero_approx(lost), label + " preserves guard, parry and evasion")
			if defense == "block": Input.action_release("block")
			actor.free()
	player.dodge_time = 0.0
	player.parry_window = 0.0
	var ghoul := _spawn("ghoulkin")
	player.position = Vector3.FORWARD * 0.42
	ghoul._begin_attack()
	var result := _cut(ghoul, Vector3.FORWARD)
	_check(result.get("counter_cue") == "Clutch interrupted" and ghoul.pending_attack_time == 0.0 and ghoul.stagger_time >= 0.65, "a quick steel cut actually cancels the clutch")
	ghoul.free()

func _stalker() -> void:
	for phase: StringName in [&"gather", &"rush"]:
		var actor := _spawn("wychwood_stalker")
		actor.spatial_service = ClearPath.new()
		actor.navigation_agent = NavigationAgent3D.new()
		actor.add_child(actor.navigation_agent)
		player.position = Vector3.FORWARD * 4.0
		var nav: RefCounted = actor.enemy_navigation_view
		for i in 42:
			nav.step_pursuit(player.position, 4.0, 1.0 / 60.0)
			if nav.rush_phase() == phase: break
		_check(nav.rush_phase() == phase, "navigation reached Stalker " + String(phase))
		var before: float = actor.health_component.health
		var shot := _arrow(actor, Vector3.FORWARD)
		_check(shot.get("counter_cue") == "Pounce broken" and is_equal_approx(before - actor.health_component.health, 12), "standard arrow breaks Stalker " + String(phase))
		_check(nav.rush_phase() == &"" and actor.velocity.is_zero_approx() and actor.stagger_time >= 0.94, "Stalker loses momentum and opens for follow-up")
		actor.free()
	var ordinary := _spawn("wychwood_stalker")
	var arrow := _arrow(ordinary, Vector3.FORWARD)
	_check(is_equal_approx(arrow.get("damage", 0), 10) and arrow.get("counter_cue") == "", "uncommitted Stalker takes ordinary bow damage")
	ordinary.free()

func _raider() -> void:
	for heading: float in [0.0, PI * 0.5]:
		var sides := [Vector3.FORWARD, Vector3(-0.7, 0, -0.7).normalized(), Vector3.RIGHT, Vector3.BACK]
		for side: Vector3 in sides:
			var actor := _spawn("wychwood_raider")
			actor.rotation.y = heading
			var direction := actor.global_basis * side
			var blocked := side.z < -0.1
			_check(actor.wood_guard_raised(), "alert Raider carries its board high")
			var before: float = actor.health_component.health
			var result := _cut(actor, direction)
			_check(is_equal_approx(before - actor.health_component.health, 2.875 if blocked else 11.5), "board sector follows actor orientation and leaves free side accessible")
			_check((result.get("surface") == "wood") == blocked and (actor.stagger_time <= 0.0) == blocked, "only the board glances a cut with a wood impact")
			actor.free()
	for weapon: String in ["standard_arrow", "bodkin_arrow", "heavy"]:
		var actor := _spawn("wychwood_raider")
		var result := _cut(actor, Vector3.FORWARD, true) if weapon == "heavy" else _arrow(actor, Vector3.FORWARD, weapon)
		if weapon == "standard_arrow":
			_check(is_equal_approx(result.get("damage", 0), 2.5) and actor.wood_guard_raised(), "ordinary arrow lodges in the board")
		else:
			_check(result.get("counter_cue") == "Board knocked aside" and actor.stagger_time >= 0.79 and not actor.wood_guard_raised(), weapon + " opens the shield")
			var follow := _cut(actor, Vector3.FORWARD)
			_check(is_equal_approx(follow.get("damage", 0), 11.5), "unguarded follow-up reaches Raider")
		actor.free()
	var swinging := _spawn("wychwood_raider")
	player.position = Vector3.FORWARD * 0.5
	swinging._begin_attack()
	_check(not swinging.wood_guard_raised() and _arrow(swinging, Vector3.FORWARD).get("damage") == 10.0, "Raider lowers the board when it swings")
	swinging.free()
	var peaceful := _spawn("wychwood_raider")
	peaceful.set_meta("story_surrender_protected", true)
	var before: float = peaceful.health_component.health
	_check(not peaceful.wood_guard_raised() and not _arrow(peaceful, Vector3.FORWARD, "bodkin_arrow").hit and not _cut(peaceful, Vector3.FORWARD, true).hit, "yielded Raider remains clear of weapon contacts")
	_check(peaceful.health_component.health == before and peaceful.stagger_time == 0.0, "yielded Raider keeps its health and stance")
	peaceful.free()

func _brute() -> void:
	for heavy: bool in [false, true]:
		var actor := _spawn("wychwood_brute")
		player.position = Vector3.FORWARD
		actor._begin_attack()
		var result := _cut(actor, Vector3.FORWARD, heavy)
		_check(is_equal_approx(result.get("damage", 0), 11.5 * (0.58 if heavy else 0.30)) and result.get("surface") == "metal", "yoke resists frontal blade contact")
		_check(actor.pending_attack_time > 0.0 and actor.stagger_time == 0.0, "frontal impact cannot cancel planted sweep")
		var flank := _cut(actor, Vector3.RIGHT)
		_check(flank.get("counter_cue") == "Turned the yoke" and actor.pending_attack_time == 0.0, "flank cut interrupts the committed body")
		actor.free()
	var missed := _spawn("wychwood_brute")
	player.position = Vector3.FORWARD * 0.6
	missed._begin_attack()
	missed.enemy_strike_view._tick_pending_attack(missed.attack_windup_total * 0.65)
	player.position = Vector3.RIGHT * 2.4
	var kael_hp: float = player.health_component.health
	_finish(missed, 30.0)
	var punish := _cut(missed, Vector3.RIGHT, true)
	_check(player.health_component.health == kael_hp and punish.get("counter_cue") == "Exposed flank" and is_equal_approx(punish.get("damage", 0), 14.375), "sidestep then heavy makes a real missed sweep punishable")
	missed.free()
	for ammo: String in ["standard_arrow", "bodkin_arrow", "ashfire_arrow"]:
		var actor := _spawn("wychwood_brute")
		var shot := _arrow(actor, Vector3.FORWARD, ammo)
		_check(shot.get("damage") == (3.0 if ammo == "standard_arrow" else 10.0), ammo + " has the intended yoke response")
		_check((actor.stagger_time >= 0.69) == (ammo != "standard_arrow"), ammo + " armour penetration")
		actor.free()

func _traps() -> void:
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 0.2, 8)
	collider.shape = box
	floor_body.add_child(collider)
	floor_body.position.y = -0.1
	scene.add_child(floor_body)
	await physics_frame
	for id: String in ["wychwood_stalker", "wychwood_brute", "bandit"]:
		var actor := _spawn(id)
		combat.load_devices({"serial":1, "zones":{"wychwood":[{"kind":"trap", "id":"1", "position":[0, 0, 0], "yaw":0.0}]}})
		scene.active_enemies = [actor]
		combat.activate_devices(scene)
		var trap := scene.zone_root.get_node("FieldDevices").get_child(0)
		var slowed_before := actor.slowed_time
		player.position = Vector3.FORWARD
		actor._begin_attack()
		combat.try_trigger_trap(trap)
		_check(trap.consumed and is_zero_approx(slowed_before) and is_equal_approx(actor.slowed_time, 4.0) and combat.save_devices().zones.wychwood.is_empty(), id + " triggers restored, supported trap exactly once")
		if id == "bandit":
			_check(actor.stagger_time <= 0.0 and actor.pending_attack_time > 0.0, "ordinary trap behavior stays intact off the woodland rigs")
		else:
			_check(actor.stagger_time >= 0.84 and actor.pending_attack_time == 0.0, id + " loses its footing and attack")
			if id == "wychwood_brute": _check(_arrow(actor, Vector3.FORWARD).get("damage") == 10.0, "trapped Brute cannot use its frontal advantage")
		actor.free()
	scene.active_enemies = []

func _run() -> void:
	OS.add_logger(log_capture)
	root.add_child(scene)
	scene.zone_root = scene
	scene.audio = scene
	scene.player = player
	scene.add_child(combat)
	scene.add_child(player)
	player.set_physics_process(false)
	for marker_name: String in ["blade_base_marker", "blade_tip_marker"]:
		var marker := Marker3D.new()
		player.add_child(marker)
		player.set(marker_name, marker)
	definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	await physics_frame
	_ghoul()
	_stalker()
	_raider()
	_brute()
	await _traps()
	scene.free()
	difficulty.free()
	OS.remove_logger(log_capture)
	for error: String in log_capture.errors: failures.append(error)
	print(JSON.stringify({"fixture":"wychwood_counterplay", "checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
