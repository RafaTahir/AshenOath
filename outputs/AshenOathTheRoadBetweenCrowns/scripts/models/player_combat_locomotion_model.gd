class_name PlayerCombatLocomotionModel
extends RefCounted

const Frame = preload("res://scripts/core/input_frame.gd")
const Events = preload("res://scripts/core/sim_event_bus.gd")
const RUN: int = 1 << 0
const JUMP: int = 1 << 1
const LIGHT: int = 1 << 2
const DODGE: int = 1 << 3
const HEAVY: int = 1 << 4
const BLOCK: int = 1 << 5
const CAST: int = 1 << 6
var tick: int = 0
var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var heading: float = 0.0
var health: float = 125.0
var stamina: float = 100.0
var max_stamina: float = 100.0
var grounded: bool = true
var dead: bool = false
var attack_cooldown: float = 0.0
var attack_time: float = 0.0
var attack_heavy: bool = false
var attack_contact: bool = false
var attack_sequence: int = 0
var combo: int = 0
var dodge_time: float = 0.0
var dodge_direction: Vector3 = Vector3.FORWARD
var parry_window: float = 0.0
var hurt_time: float = 0.0
var buffered_attack: String = ""
var buffer_time: float = 0.0
var beam_state: String = ""
var beam_time: float = 0.0
var beam_charge: float = 0.0
var beam_cooldown: float = 0.0
var beam_contact_emitted: bool = false
var beam_ratio: float = 0.0
var beam_release_elapsed: float = 0.0
var previous_buttons: int = 0
var foot_distance: float = 0.0
var regen_cooldown: float = 0.0
var difficulty: Dictionary = {"incoming_damage_multiplier": 1.0, "parry_window": 0.30, "dodge_cost_modifier": 0.0, "attack_buffer": 0.18}
var configuration: Dictionary = {}

static func horizontal_velocity(current: Vector3, direction: Vector3, forward: Vector3,
		delta: float, running: bool, aiming: bool, locked: bool, on_floor: bool, config: Dictionary) -> Vector3:
	var speed: float = float(config.get("run_speed", 5.3) if running else config.get("walk_speed", 3.4))
	if aiming:
		speed *= 0.42
	if bool(config.get("casting", false)):
		speed *= 0.4
	if locked:
		direction = forward * maxf(0.0, forward.dot(direction))
	var planar: Vector3 = Vector3(current.x, 0.0, current.z)
	var reversing: bool = not locked and direction.length_squared() > 0.01 and planar.length_squared() > 0.0225 and planar.normalized().dot(direction) < -0.35
	if not locked and on_floor:
		speed *= smoothstep(0.0, 0.90, maxf(0.0, forward.dot(direction)))
	var target: Vector3 = direction * speed
	var response: float = float(config.get("run_acceleration", 13.0) if running else config.get("acceleration", 17.0))
	if reversing or direction.length_squared() <= 0.01:
		response = float(config.get("deceleration", 21.0))
		if reversing:
			target = Vector3.ZERO
	return Vector3(move_toward(current.x, target.x, response * delta), current.y, move_toward(current.z, target.z, response * delta))

static func dodge_velocity(remaining: float, speed: float = 8.0) -> float:
	return speed * (0.62 + 0.38 * sin(clampf(remaining / 0.30, 0.0, 1.0) * PI))

static func damage_resolution(amount: float, dodge: float, parry: float, guarded: bool,
		available_stamina: float, profile: Dictionary, guard_multiplier: float = 1.0) -> Dictionary:
	if dodge > 0.0:
		return {"kind": "dodged", "damage": 0.0, "cost": 0.0}
	amount *= float(profile.get("incoming_damage_multiplier", 1.0))
	if parry > 0.0 and available_stamina >= 10.0:
		return {"kind": "parried", "damage": 0.0, "cost": 10.0}
	var cost: float = 12.0 * guard_multiplier
	if guarded and available_stamina >= cost:
		return {"kind": "blocked", "damage": amount * 0.25, "cost": cost}
	return {"kind": "hurt", "damage": amount, "cost": 0.0}

static func cast_sequence(state: String, remaining: float, elapsed: float, emitted: bool,
		held: bool, equipment_transitioning: bool, delta: float) -> Dictionary:
	var result: Dictionary = {"remaining": maxf(0.0, remaining - delta), "elapsed": elapsed,
		"emitted": emitted, "release": false, "command": ""}
	if state == "sheathing" and float(result.remaining) <= 0.0:
		result.command = "charge" if held else "redraw"
	elif state == "releasing":
		result.elapsed = elapsed + delta
		if not emitted and float(result.elapsed) >= 0.11:
			result.emitted = true
			result.release = true
		if float(result.remaining) <= 0.0:
			result.command = "redraw"
	elif state == "redrawing" and float(result.remaining) <= 0.0 and not equipment_transitioning:
		result.command = "restore"
	return result

func spend(amount: float, events: Events, action: String) -> bool:
	if amount < 0.0 or stamina < amount:
		events.emit_event(tick, "stamina_exhausted", {"action": action})
		return false
	stamina -= amount
	regen_cooldown = 0.8
	return true

func step(frame: Frame, delta: float, events: Events) -> void:
	tick = frame.tick
	if dead:
		return
	var pressed: int = frame.buttons & ~previous_buttons
	var released: int = previous_buttons & ~frame.buttons
	previous_buttons = frame.buttons
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	attack_time = maxf(0.0, attack_time - delta)
	parry_window = maxf(0.0, parry_window - delta)
	hurt_time = maxf(0.0, hurt_time - delta)
	buffer_time = maxf(0.0, buffer_time - delta)
	beam_cooldown = maxf(0.0, beam_cooldown - delta)
	if buffer_time <= 0.0:
		buffered_attack = ""
	regen_cooldown = maxf(0.0, regen_cooldown - delta)
	if regen_cooldown == 0.0:
		stamina = minf(max_stamina, stamina + 24.0 * delta)
	_step_beam(pressed, released, frame.buttons, delta, events)
	var direction: Vector3 = Vector3(frame.move_x, 0.0, frame.move_y).limit_length()
	var running: bool = frame.buttons & RUN != 0 and direction.length_squared() > 0.01
	if running:
		running = spend(10.0 * float(configuration.get("sprint_multiplier", 1.0)) * delta, events, "sprint")
	if dodge_time > 0.0:
		dodge_time = maxf(0.0, dodge_time - delta)
		velocity.x = dodge_direction.x * dodge_velocity(dodge_time)
		velocity.z = dodge_direction.z * dodge_velocity(dodge_time)
	else:
		if direction.length_squared() > 0.01 and attack_time == 0.0 and beam_state == "":
			heading = lerp_angle(heading, atan2(-direction.x, -direction.z), 1.0 - exp(-11.0 * delta))
		velocity = horizontal_velocity(velocity, direction, -Basis(Vector3.UP, heading).z, delta,
			running, false, attack_time > 0.0 or beam_state != "", grounded, configuration)
		if pressed & JUMP != 0 and grounded and attack_time <= 0.0 and beam_state == "":
			velocity.y = 8.2
			grounded = false
		if pressed & DODGE != 0 and beam_state == "" and spend(maxf(1.0, 28.0 + float(difficulty.get("dodge_cost_modifier", 0.0)) - float(configuration.get("dodge_cost_reduction", 0.0))), events, "dodge"):
			dodge_time = 0.30
			dodge_direction = direction if direction.length_squared() > 0.01 else -Basis(Vector3.UP, heading).z
	if not grounded:
		velocity.y -= 24.0 * delta
	position += velocity * delta
	if position.y <= 0.0:
		position.y = 0.0
		velocity.y = 0.0
		grounded = true
	if pressed & BLOCK != 0:
		parry_window = float(difficulty.get("parry_window", 0.30))
	_step_melee(pressed, events)
	if attack_time > 0.0 and not attack_contact:
		var duration: float = 0.52 if attack_heavy else 0.34
		if 1.0 - attack_time / duration >= (0.30 if attack_heavy else 0.18):
			attack_contact = true
			events.emit_event(tick, "blade_contact", {"attack_id": attack_sequence, "heavy": attack_heavy, "damage": 34.0 if attack_heavy else 22.0})
	if grounded and velocity.length() > 0.18:
		foot_distance += Vector2(velocity.x, velocity.z).length() * delta
		var stride: float = 1.52 if running else 1.34
		if foot_distance >= stride:
			foot_distance -= stride
			events.emit_event(tick, "footstep")

func _step_melee(pressed: int, events: Events) -> void:
	if beam_state != "" or dodge_time > 0.0:
		return
	var requested: String = "light" if pressed & LIGHT != 0 else ("heavy" if pressed & HEAVY != 0 else "")
	if attack_cooldown > 0.0:
		if requested != "":
			buffered_attack = "heavy" if pressed & HEAVY != 0 else requested
			buffer_time = float(difficulty.get("attack_buffer", 0.18))
		return
	if requested == "":
		requested = buffered_attack
	buffered_attack = ""
	if requested == "":
		return
	if requested == "heavy" and not spend(maxf(1.0, 22.0 - float(configuration.get("heavy_cost_reduction", 0.0))), events, "heavy attack"):
		return
	attack_heavy = requested == "heavy"
	attack_time = 0.52 if attack_heavy else 0.34
	attack_cooldown = 0.70 if attack_heavy else maxf(0.34, 0.38 * float(configuration.get("light_recovery_multiplier", 1.0)))
	attack_sequence += 1
	combo = (combo + 1) % 3
	attack_contact = false

func _step_beam(pressed: int, released: int, buttons: int, delta: float, events: Events) -> void:
	var sequence: Dictionary = cast_sequence(beam_state, beam_time, beam_release_elapsed, beam_contact_emitted, buttons & CAST != 0, false, delta)
	beam_time = float(sequence.remaining)
	beam_release_elapsed = float(sequence.elapsed)
	beam_contact_emitted = bool(sequence.emitted)
	if bool(sequence.release):
		events.emit_event(tick, "beam_released", {"charge_ratio": beam_ratio})
	if sequence.command == "charge":
		beam_state = "charging"
	elif sequence.command == "redraw":
		beam_state = "redrawing"
		beam_time = 0.14
	elif sequence.command == "restore":
		beam_state = ""
	if pressed & CAST != 0 and beam_state == "" and beam_cooldown <= 0.0 and dodge_time <= 0.0:
		beam_state = "sheathing"
		beam_time = 0.24
		beam_charge = 0.0
	if beam_state == "charging":
		if buttons & CAST != 0:
			beam_charge = minf(1.25, beam_charge + delta / maxf(0.01, float(configuration.get("charge_multiplier", 1.0))))
		if released & CAST != 0:
			if beam_charge >= 0.35 and spend(float(configuration.get("beam_cost", 40.0)), events, "Oathfire Beam"):
				beam_ratio = clampf((beam_charge - 0.35) / 0.90, 0.0, 1.0)
				beam_state = "releasing"
				beam_time = 0.34
				beam_release_elapsed = 0.0
				beam_cooldown = float(configuration.get("beam_cooldown", 4.0))
				beam_contact_emitted = false
			else:
				beam_state = "redrawing"
				beam_time = 0.14
	elif beam_state == "sheathing" and released & CAST != 0:
		beam_state = "redrawing"
		beam_time = 0.14

func receive_damage(amount: float, blocking: bool, events: Events) -> String:
	if dead:
		return "dead"
	var result: Dictionary = damage_resolution(amount, dodge_time, parry_window, blocking, stamina, difficulty, float(configuration.get("guard_multiplier", 1.0)))
	if result.kind == "dodged":
		return str(result.kind)
	spend(float(result.cost), events, "guard")
	if result.kind == "parried":
		parry_window = 0.0
	else:
		health = maxf(0.0, health - float(result.damage))
		hurt_time = 0.13 if result.kind == "blocked" else 0.20
		beam_state = ""
	events.emit_event(tick, str(result.kind), {"damage": float(result.damage)})
	if health <= 0.0:
		dead = true
		events.emit_event(tick, "died")
	return str(result.kind)

func save_state() -> Dictionary:
	return {"tick": tick, "position": [position.x, position.y, position.z],
		"velocity": [velocity.x, velocity.y, velocity.z], "heading": heading, "health": health,
		"stamina": stamina, "dead": dead, "grounded": grounded, "attack_cooldown": attack_cooldown,
		"attack_time": attack_time, "attack_heavy": attack_heavy, "attack_sequence": attack_sequence,
		"attack_contact": attack_contact, "combo": combo, "dodge_time": dodge_time,
		"dodge_direction": [dodge_direction.x, dodge_direction.y, dodge_direction.z],
		"parry_window": parry_window, "hurt_time": hurt_time, "buffered_attack": buffered_attack,
		"buffer_time": buffer_time, "beam_state": beam_state, "beam_time": beam_time,
		"beam_charge": beam_charge, "beam_cooldown": beam_cooldown, "beam_ratio": beam_ratio,
		"beam_contact_emitted": beam_contact_emitted, "beam_release_elapsed": beam_release_elapsed, "previous_buttons": previous_buttons,
		"foot_distance": foot_distance, "regen_cooldown": regen_cooldown}
