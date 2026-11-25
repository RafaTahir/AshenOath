extends RefCounted

## The road call is an invitation. The Raider waits for a second, physical
## answer in the clearing. Only the active opening wave can receive it.
const RAIDER_WAVE := 3
const ANSWER := "wychwood_road_answer"
const BROKEN := "wychwood_raider_truce_broken"
const SPARED := "wychwood_raider_spared"

static func footfall(host: Node) -> void:
	if host.current_zone_id == "wychwood" and host.player.movement_state in ["run", "run_back"]:
		for enemy: Node in host.active_enemies:
			if is_instance_valid(enemy) and enemy.enemy_id == "ghoulkin":
				enemy.enemy_navigation_view.hear_ghoulkin_footfall(host.player.global_position)

static func install_targets(owner: Node) -> void:
	var host: Node = owner.host
	for enemy: Node in host.active_enemies:
		if not is_instance_valid(enemy):
			continue
		var raider: bool = host.current_zone_id == "wychwood" and enemy.enemy_id == "wychwood_raider" and int(enemy.read_presentation_tag(enemy, "wychwood_wave", -1)) == RAIDER_WAVE
		if not raider and not bool(enemy.read_presentation_tag(enemy, "ordinary_surrender_eligible", false)):
			continue
		var id := "road_call" if raider else "surrender"
		var prompt := "Answer the Raider with an empty hand" if raider else "Accept surrender"
		var area: Node3D = owner.point_action(id, prompt, enemy.global_position)
		area.reparent(enemy, true)
		area.position = Vector3.ZERO
		enemy.write_presentation_tag(area, "interaction_collision_owner", NodePath(".."))
		area.set_interaction_enabled(false)
		owner.surrender_targets.append({"enemy":weakref(enemy), "area":weakref(area), "raider":raider})
		if raider:
			preload("res://scripts/views/wychwood_carter_art.gd").attach_raider_tally(enemy)
			enemy.damaged.connect(_on_damaged.bind(owner))

static func tick_targets(owner: Node) -> void:
	for entry: Dictionary in owner.surrender_targets:
		var enemy: Node = entry.enemy.get_ref()
		var area: Node = entry.area.get_ref()
		if not is_instance_valid(enemy) or not is_instance_valid(area): continue
		if entry.raider:
			refresh_offer(owner.host, enemy)
			area.set_interaction_enabled(enemy.surrender_offer and enemy.encounter_active and hands_empty(owner.host.player))
		else:
			area.set_interaction_enabled(enemy.surrender_offer and not enemy.dead)

static func _live_raider(host: Node, enemy: Node) -> bool:
	return is_instance_valid(enemy) and is_instance_valid(host.zone_root) and host.zone_root.is_ancestor_of(enemy) and host.current_zone_id == "wychwood" \
		and host.wychwood_pack_kills == RAIDER_WAVE and enemy.enemy_id == "wychwood_raider" and int(enemy.read_presentation_tag(enemy, "wychwood_wave", -1)) == RAIDER_WAVE \
		and enemy.encounter_active and not enemy.dead and not enemy.resolved_nonlethal and host.quests.is_active("main_road_of_crows")

static func _available(host: Node, enemy: Node) -> bool:
	return _live_raider(host, enemy) and host.story_state.get_flag(ANSWER, "") == "open_hand" \
		and not host.story_state.get_flag(BROKEN, false) and not host.story_state.get_flag(SPARED, false)

static func hands_empty(player: Node) -> bool:
	return is_instance_valid(player) and player.can_control and player.equipment_loadout != null and not player.equipment_loadout.is_drawn() \
		and not player.equipment_loadout.is_transitioning() and not player.bow_aiming and player.beam_cast_state == "" and player.attack_anim_time <= 0.0

static func refresh_offer(host: Node, enemy: Node) -> void:
	if not _available(host, enemy) or enemy.surrender_offer or enemy.surrender_declined or enemy.pending_attack_time > 0.0:
		return
	if enemy.stagger_time > 0.0 or enemy.attack_recovery_time > 0.0 or enemy.health_component.health < enemy.health_component.max_health:
		return
	if not is_instance_valid(host.player) or not enemy.can_see_player:
		return
	enemy.surrender_offer = true
	enemy.velocity = Vector3.ZERO
	var at: Vector3 = host.player.global_position
	at.y = enemy.global_position.y
	if enemy.global_position.distance_squared_to(at) > 0.01: enemy.look_at(at)
	host.hud.toast("The Raider loops the cord over one finger. It waits for an empty hand.")

static func _on_damaged(enemy: Node, current: float, maximum: float, owner: Node) -> void:
	if current >= maximum or not _live_raider(owner.host, enemy) or owner.host.story_state.get_flag(BROKEN, false):
		return
	owner.host.story_state.set_flag(BROKEN, true)
	owner.persist()

static func answer(owner: Node, area: Node3D) -> bool:
	var host: Node = owner.host
	var enemy: Node = area.get_parent()
	if not _available(host, enemy) or not enemy.surrender_offer or not hands_empty(host.player):
		return false
	if enemy.global_position.distance_to(host.player.global_position) > 2.8 or not enemy._has_attack_line():
		return false
	# Commit the durable choice and wave cursor before the next wave or any
	# save can observe the result. The normal death handler never runs here.
	host.story_state.set_flag(SPARED, true)
	host.wychwood_pack_kills = RAIDER_WAVE + 1
	enemy.surrender_offer = false
	enemy.resolved_nonlethal = true
	enemy.encounter_active = false
	enemy.velocity = Vector3.ZERO
	enemy.collision_layer = 0
	enemy.collision_mask = 0
	enemy.set_physics_process(false)
	if enemy.animation_driver != null:
		enemy.animation_driver.clear_observation_clip()
		enemy.animation_driver.set_observation_clip("Idle")
	area.set_interaction_enabled(false)
	if host.progression != null:
		host.progression.award_encounter("opening_wave:%d" % RAIDER_WAVE, "wychwood", "The Raider gave way")
		host._collect_progression_rewards()
	host._record_encounter_knowledge(enemy)
	host.hud.hide_enemy()
	host._activate_wychwood_wave(["wychwood_brute"], "The Raider lowers the cord. Behind it the Brute plants both feet in the wheel ruts.")
	owner.persist()
	return true
