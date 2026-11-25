extends RefCounted
## Combat response at an already confirmed contact. Attack timing, geometry,
## oil damage, health, surrender and single-hit ownership stay with their owners.

const EnemyState = preload("res://scripts/views/enemy_scene_state.gd")
const RAIDER_BOARD_NORMAL := Vector3(-0.34, 0.0, -0.94)

static func _uses_woodland_rig(enemy: EnemyState) -> bool:
	return enemy.visual_role_override.is_empty() or enemy.visual_role_override == enemy.enemy_id + "_creature"

static func guard_raised(enemy: EnemyState) -> bool:
	return enemy.enemy_id == "wychwood_raider" and _uses_woodland_rig(enemy) and _can_engage(enemy) and enemy.can_see_player and enemy.pending_attack_time <= 0.0 and _balanced(enemy)

static func has_story_protection(target: Node) -> bool:
	return target is EnemyState and bool(target.read_presentation_tag(target, "story_surrender_protected", false))

static func _can_engage(enemy: EnemyState) -> bool:
	return enemy.encounter_active and not enemy.dead and not enemy.surrender_offer and not enemy.resolved_nonlethal and not has_story_protection(enemy)

static func _balanced(enemy: EnemyState) -> bool:
	return enemy.stagger_time <= 0.0 and enemy.attack_recovery_time <= 0.0 and enemy.parry_exposed_time <= 0.0 and enemy.slowed_time <= 0.0

static func weapon_contact(target: Node, amount: float, source: String, weapon: String, heavy: bool, towards_attacker: Vector3) -> Dictionary:
	var response := {}
	var enemy := target as EnemyState
	if enemy != null and _can_engage(enemy) and _uses_woodland_rig(enemy):
		response = _response(enemy, source, weapon, heavy, towards_attacker)
	var adjusted := amount * float(response.get("scale", 1.0))
	var light_blade := weapon != "bow" and not heavy
	if response.get("glance", false):
		target.apply_damage(adjusted, source, light_blade, true)
	elif weapon == "bow":
		target.apply_damage(adjusted, source)
	else:
		target.apply_damage(adjusted, source, light_blade)
	if response.has("stagger") and not enemy.dead and not enemy.surrender_offer:
		enemy.enemy_navigation_view.reset_stride()
		enemy.velocity.x = 0.0
		enemy.velocity.z = 0.0
		enemy.stagger(response.stagger)
	response.damage = adjusted
	return response

static func _response(enemy: EnemyState, source: String, weapon: String, heavy: bool, towards_attacker: Vector3) -> Dictionary:
	var from := enemy.global_basis.inverse() * towards_attacker
	from.y = 0.0
	from = from.normalized()
	match enemy.enemy_id:
		"ghoulkin":
			if weapon == "steel" and not heavy and enemy.pending_attack_time > 0.0:
				return {"stagger": 0.66, "cue": "Clutch interrupted"}
		"wychwood_stalker":
			if weapon == "bow" and enemy.enemy_navigation_view.rush_phase() != &"":
				return {"scale": 1.2, "stagger": 0.95, "cue": "Pounce broken"}
		"wychwood_raider":
			if guard_raised(enemy) and from.dot(RAIDER_BOARD_NORMAL) >= 0.43:
				if heavy or source == "arrow_bodkin_arrow":
					return {"stagger": 0.8, "surface": "wood", "cue": "Board knocked aside"}
				return {"scale": 0.25, "glance": true, "surface": "wood", "cue": "Caught on the board"}
		"wychwood_brute":
			if from.dot(Vector3.FORWARD) >= 0.60 and _balanced(enemy) and (enemy.can_see_player or enemy.pending_attack_time > 0.0):
				if source in ["arrow_bodkin_arrow", "arrow_ashfire_arrow"]:
					return {"stagger": 0.70, "cue": "Yoke breached"}
				return {"scale": 0.58 if heavy else 0.30, "glance": true, "surface": "metal", "cue": "Struck the yoke"}
			if weapon != "bow" and from.dot(Vector3.FORWARD) < 0.20 and enemy.pending_attack_time > 0.0:
				return {"stagger": 0.38, "cue": "Turned the yoke"}
			if heavy and from.dot(Vector3.FORWARD) < 0.20 and enemy.attack_recovery_time > 0.0:
				return {"scale": 1.25, "stagger": 0.65, "cue": "Exposed flank"}
	return {}

static func trap_closed(enemy: EnemyState) -> void:
	if not _can_engage(enemy) or not _uses_woodland_rig(enemy):
		return
	if enemy.enemy_id in ["wychwood_stalker", "wychwood_brute"]:
		enemy.enemy_navigation_view.reset_stride()
		enemy.velocity.x = 0.0
		enemy.velocity.z = 0.0
		enemy.stagger(1.15 if enemy.enemy_id == "wychwood_stalker" else 0.85)

static func strike_player(enemy: EnemyState, amount: float) -> bool:
	if enemy.enemy_id != "ghoulkin" or not _uses_woodland_rig(enemy) or not enemy.player.has_signal("hurt") or enemy.health_component.health >= enemy.health_component.max_health:
		return enemy.player.take_damage(amount)
	# The player emits hurt only for a penetrating blow. Guard, parry and
	# invulnerability are resolved once by the normal player damage owner.
	var feed := func(wound: float) -> void:
		if not enemy.dead: enemy.health_component.heal(minf(wound * 0.75, 3.0))
	enemy.player.hurt.connect(feed, CONNECT_ONE_SHOT)
	var parried: bool = enemy.player.take_damage(amount)
	if enemy.player.hurt.is_connected(feed): enemy.player.hurt.disconnect(feed)
	return parried
