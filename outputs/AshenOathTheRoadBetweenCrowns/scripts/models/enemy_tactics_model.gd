class_name EnemyTacticsModel
extends RefCounted

const Rng = preload("res://scripts/core/seeded_rng.gd")
const Events = preload("res://scripts/core/sim_event_bus.gd")
var identity: String = "ghoulkin"
var position: Vector3 = Vector3.ZERO
var home_position: Vector3 = Vector3.ZERO
var last_known: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var sense_range: float = 10.0
var leash_radius: float = 14.0
var attack_range: float = 1.4
var move_speed: float = 2.0
var damage: float = 10.0
var health_ratio: float = 1.0
var memory_time: float = 0.0
var attack_cooldown: float = 0.0
var pending_attack_time: float = 0.0
var attack_windup_total: float = 0.0
var recovery_time: float = 0.0
var stagger_time: float = 0.0
var parry_exposed_time: float = 0.0
var surrender_offer: bool = false
var surrender_declined: bool = false
var surrender_eligible: bool = false
var resolved_nonlethal: bool = false
var boss: bool = false
var phase: int = 1
var mode: String = "resting"
var flank_sign: float = 1.0
var heard_cue_cooldown: float = 0.0

static func engagement_radius(preferred: float, reach: float, visible: bool,
        cooldown: float, recovery: float, stopping_margin: float = 0.0) -> float:
	# Preferred spacing is a waiting ring; ready melee must close inside reach.
	if visible and cooldown <= 0.0 and recovery <= 0.0:
		return maxf(0.0, minf(preferred, reach * 0.85) - maxf(stopping_margin, 0.0))
	return preferred

static func phase_for_health(ratio: float) -> int:
	return 3 if ratio <= 0.33 else (2 if ratio <= 0.66 else 1)

static func incoming_damage(amount: float, source: String, weakness: String, tag: String,
		exposed: bool, actor_id: String, health: float) -> float:
	if exposed:
		amount += 8.0
	if source == weakness or source == tag or (source == "spirit" and weakness == "moon_oil") or (source == "undead" and weakness == "rot_oil"):
		amount += 15.0
	return minf(amount, maxf(0.0, health - 1.0)) if actor_id == "captain_senn" else amount

static func windup_duration(actor_id: String, is_boss: bool, preparation_bonus: float = 0.0) -> float:
	if is_boss:
		return float({"white_hart_avatar": 0.44, "bell_eater": 0.78, "rootbound_colossus": 0.92, "ashwing": 0.64, "halvern_boss": 0.48}.get(actor_id, 0.60)) + preparation_bonus
	if actor_id == "wychwood_brute":
		return 0.72 + preparation_bonus
	return (0.46 if actor_id in ["ghoulkin", "wychwood_stalker", "wychwood_raider"] else 0.34) + preparation_bonus

static func cooldown_duration(actor_id: String, is_boss: bool, boss_phase: int) -> float:
	if is_boss:
		return float({"white_hart_avatar": [1.55, 1.32, 1.16], "bell_eater": [1.80, 1.48, 1.18],
			"rootbound_colossus": [2.10, 1.72, 1.35], "ashwing": [1.65, 1.28, 1.00],
			"halvern_boss": [1.38, 1.05, 0.90]}.get(actor_id, [1.70, 1.35, 1.10])[clampi(boss_phase - 1, 0, 2)])
	return 1.65 if actor_id == "wychwood_brute" else (1.32 if actor_id in ["ghoulkin", "wychwood_stalker", "wychwood_raider"] else 1.16)

func choose_mode(player_position: Vector3, visible: bool, active: bool) -> String:
	if surrender_offer or resolved_nonlethal:
		return "surrender"
	if boss and player_position.distance_to(home_position) > leash_radius:
		return "return"
	if pending_attack_time > 0.0:
		return "windup"
	if stagger_time > 0.0:
		return "stagger"
	if position.distance_to(home_position) > leash_radius:
		return "return"
	if memory_time <= 0.0 and not visible:
		return "ambient"
	if recovery_time > 0.0:
		return "recover"
	var strike_radius := engagement_radius(attack_range, attack_range, visible, attack_cooldown, recovery_time)
	if position.distance_to(player_position if visible else last_known) > strike_radius or not visible:
		return "pursue"
	return "attack" if active else "ambient"

func advance_timers(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	recovery_time = maxf(0.0, recovery_time - delta)
	stagger_time = maxf(0.0, stagger_time - delta)
	parry_exposed_time = maxf(0.0, parry_exposed_time - delta)
	memory_time = maxf(0.0, memory_time - delta)
	heard_cue_cooldown = maxf(0.0, heard_cue_cooldown - delta)

func step(player_position: Vector3, home: Vector3, ratio: float, rng: Rng, delta: float,
		events: Events, tick: int, visible: bool = true, slot_available: bool = true) -> void:
	home_position = home
	health_ratio = clampf(ratio, 0.0, 1.0)
	if health_ratio <= 0.0:
		if mode != "dead":
			events.emit_event(tick, "died", {"enemy_id": identity})
		mode = "dead"
		velocity = Vector3.ZERO
		return
	var next_phase: int = phase_for_health(health_ratio) if boss else 1
	if phase != next_phase:
		phase = next_phase
		events.emit_event(tick, "boss_phase_changed", {"enemy_id": identity, "phase": phase})
	advance_timers(delta)
	if visible and position.distance_to(player_position) <= sense_range:
		last_known = player_position
		memory_time = 2.5
	elif position.distance_to(player_position) > sense_range + 1.0:
		visible = false
	if surrender_eligible and not boss and not surrender_declined and health_ratio <= 0.25:
		if not surrender_offer:
			events.emit_event(tick, "surrender_offer", {"enemy_id": identity})
		surrender_offer = true
	mode = choose_mode(player_position, visible, true)
	velocity = Vector3.ZERO
	if mode in ["return", "pursue"]:
		var target: Vector3 = home_position if mode == "return" else (player_position if visible else last_known)
		velocity = position.direction_to(target) * move_speed
	elif mode == "windup":
		pending_attack_time = maxf(0.0, pending_attack_time - delta)
		if pending_attack_time <= 0.0:
			recovery_time = 0.55
			events.emit_event(tick, "enemy_contact", {"enemy_id": identity, "damage": damage, "parryable": true})
	elif mode == "attack" and attack_cooldown <= 0.0 and slot_available:
		flank_sign = -1.0 if rng.chance(0.5) else 1.0
		attack_windup_total = windup_duration(identity, boss)
		pending_attack_time = attack_windup_total
		attack_cooldown = cooldown_duration(identity, boss, phase)
		events.emit_event(tick, "windup_started", {"enemy_id": identity, "duration": attack_windup_total})
	position += velocity * delta

func stagger(seconds: float = 0.7) -> void:
	stagger_time = maxf(stagger_time, seconds)
	pending_attack_time = 0.0

func save_state() -> Dictionary:
	return {"identity": identity, "position": [position.x, position.y, position.z],
		"home": [home_position.x, home_position.y, home_position.z], "last_known": [last_known.x, last_known.y, last_known.z],
		"velocity": [velocity.x, velocity.y, velocity.z], "health_ratio": health_ratio,
		"memory_time": memory_time, "attack_cooldown": attack_cooldown, "pending_attack_time": pending_attack_time,
		"attack_windup_total": attack_windup_total, "recovery_time": recovery_time, "stagger_time": stagger_time,
		"parry_exposed_time": parry_exposed_time, "surrender_offer": surrender_offer,
		"surrender_declined": surrender_declined, "resolved_nonlethal": resolved_nonlethal,
		"phase": phase, "mode": mode, "flank_sign": flank_sign, "heard_cue_cooldown": heard_cue_cooldown}
