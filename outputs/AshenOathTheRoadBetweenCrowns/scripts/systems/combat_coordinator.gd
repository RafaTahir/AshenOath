extends "res://scripts/systems/game_bindings.gd"
## Owns combat operations; configure() injects dependencies.
signal combat_impact(position: Vector3, heavy: bool)

func _on_player_blade_contact(contact: Dictionary) -> void:
	var heavy := bool(contact.get("heavy", false))
	if bool(contact.get("first_sample", true)):
		audio.play_event("heavy" if heavy else "swing")
	var civilians := _civilian_contact_candidates(player.global_position, 4.0)
	var result: Dictionary = combat.resolve_player_blade_contact(player, active_enemies, contact, inventory.active_oil, civilians)
	if not bool(result.get("hit", false)):
		var practice: Node = preload("res://scripts/greyfen_village_details.gd").current(_host)
		if practice != null and practice.blade_contact(contact):
			result["hit"] = true
			result["surface"] = "wood"
			result["kind"] = "practice"
	player.confirm_blade_contact(int(contact.get("attack_id", -1)), bool(result.get("hit", false)))
	if bool(result.get("hit", false)):
		_present_surface_contact(result, false)
		_hitstop(0.055 if heavy else 0.032)
		var contact_color := Color(0.66, 0.88, 1.0) if str(result.get("blade_id", "steel")) == "oathblade" or str(result.get("source_tag", "")) == "spirit" else Color(0.98, 0.78, 0.34)
		if str(result.get("surface", "")) != "flesh": CombatFeedback.weapon_contact(
			zone_root,
			result.get("blade_base", player.global_position),
			result.get("blade_tip", player.global_position),
			result.get("contact_point", result.get("point", player.global_position)),
			heavy,
			contact_color,
			result.get("previous_base", Vector3.ZERO),
			result.get("previous_tip", Vector3.ZERO)
		)
		if input_router != null:
			input_router.rumble(0.16 if heavy else 0.09, 0.30 if heavy else 0.20, 0.07)
		if camera_rig != null:
			camera_rig.shake(0.09 if heavy else 0.045)
		var target = result.get("enemy")
		if target != null and is_instance_valid(target) and target.health_component != null:
			hud.show_enemy(target.display_name, target.health_component.health, target.health_component.max_health)
			if target.enemy_id == "bog_wretch":
				if inventory.active_oil == "moon_oil":
					_expose_bog_core(target, "Moon Oil")
				elif heavy:
					_record_bog_stagger(target, "heavy blows")

func _on_player_arrow_unavailable() -> void:
	hud.toast("No arrows. Tor keeps a reserve at his forge in Greyfen.")
	hud.show_status_cue("No arrows", "hurt")

func _on_player_arrow(request: Dictionary) -> void:
	if player == null or zone_root == null:
		return
	if bool(request.get("training", false)):
		var range_node := instance_from_id(int(request.get("training_owner", 0))) as Node
		if is_instance_valid(range_node) and range_node == zone_root.get_node_or_null("GreyfenArcheryRange"):
			range_node.fire(request)
		# A retired or cancelled training request can never fall through to damage.
		return
	var origin: Vector3 = request.get("origin", player.global_position + Vector3.UP * 1.3)
	var direction: Vector3 = request.get("direction", -player.global_transform.basis.z)
	if direction.length_squared() < 0.5:
		direction = -player.global_transform.basis.z
	direction = direction.normalized()
	var arrow_id := str(request.get("arrow_id", "standard_arrow"))
	var arrow_def: Dictionary = inventory.item_defs.get(arrow_id, {})
	var effect: Dictionary = arrow_def.get("effect", {})
	var damage := float(effect.get("damage", 28.0))
	if float(request.get("draw_ratio", 0.0)) >= 0.99:
		damage *= progression.effect_value("saga_full_draw_damage_multiplier", 1.0)
	var arrow_exclusions: Array[RID] = [player.get_rid()]
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			arrow_exclusions.append(enemy.get_rid())
	audio.play_event("swing", 0.02)
	var arrow_targets: Array = active_enemies.duplicate()
	arrow_targets.append_array(_civilian_contact_candidates(origin, float(request.get("range",24.0)) + 2.0))
	combat_vfx_coordinator.launch_arrow(zone_root, origin, direction, float(request.get("range", 24.0)), arrow_targets, combat, arrow_exclusions, {
		"width": float(request.get("width", 0.34)),
		"damage": damage,
		"source_tag": "arrow_%s" % arrow_id,
	}, Callable(_host, "_on_arrow_impact").bind(arrow_id, damage, zone_root.get_instance_id()))

func _on_arrow_impact(result: Dictionary, arrow_id: String, damage: float, zone_instance: int) -> void:
	if not is_instance_valid(zone_root) or zone_instance != zone_root.get_instance_id(): return
	if bool(result.get("hit", false)):
		_present_surface_contact(result, true)
		if str(result.get("kind", "")) == "scenery": return
		hud.show_status_cue("Arrow struck a person" if str(result.get("kind", "")) == "civilian" else "Arrow hit: %d" % int(damage), "item")
		var target = result.get("enemy")
		if target != null and is_instance_valid(target):
			hud.show_enemy(target.display_name, target.health_component.health, target.health_component.max_health)
			if target.dead and arrow_id in ["standard_arrow", "bodkin_arrow"] and progression.effect_value("arrow_recovery_on_kill", 0.0) > 0.0:
				inventory.add_item(arrow_id, 1)
				story_save_pending = true
				_host.call_deferred("_persist_story_action")

func _present_surface_contact(result: Dictionary, arrow: bool) -> void:
	var surface := str(result.get("surface", "metal"))
	var event := ("arrow_contact" if arrow else "flesh_contact") if surface == "flesh" else str({"wood":"wood_contact","stone":"stone_contact","foliage":"foliage_contact"}.get(surface,"light_hit"))
	audio.play_spatial_event(event,result.get("point",player.global_position),player.global_position,14.0,0.06,0.06)
	combat_vfx_coordinator.surface_contact(zone_root,result,bool(settings.settings.get("blood_effects",true)),bool(settings.settings.get("flash_reduction",false)))
	audio.perception_cue.emit(result.get("point",player.global_position),7.0,str(result.get("kind","")) != "scenery")

func _civilian_contact_candidates(position: Vector3, radius: float) -> Array:
	if not is_instance_valid(zone_root): return []
	var life: Node
	for owner_name: String in ["GreyfenLifeController", "RegionalLifeController"]:
		life = zone_root.get_node_or_null(owner_name)
		if life != null: break
	var people: Array = []
	for area in interaction_focus.registered_nearby(position,zone_root,radius):
		if str(area.get("interaction_type")) == "dialogue" and area.find_child("CharacterAnimationDriver",true,false) != null:
			people.append(area)
	if life == null and not people.is_empty():
		life = _gameplay_script("greyfen_life_controller").new()
		life.name = "RegionalLifeController"
		zone_root.add_child(life)
		life.configure(_host,str(settings.settings.get("quality_preset","balanced")),true)
	if life == null: return []
	for person in people: life.enroll_contact_actor(person)
	return life.contact_candidates(position,radius)

func _make_arrow_trail(origin: Vector3, endpoint: Vector3, color: Color) -> void:
	combat_vfx_coordinator.make_arrow_trail(zone_root, origin, endpoint, color)

func _on_player_beam_phase(phase: String) -> void:
	match phase:
		"sheathing": audio.play_event("oathfire_sheathe",0.02)
		"charging": audio.play_event("oathfire_charge",0.01)
		"releasing": audio.play_event("oathfire_release",0.015)

func _on_player_beam(charge_ratio: float, direction: Vector3) -> void:
	if player == null or zone_root == null:
		return
	_clear_oathfire_effects()
	var locked_direction: Vector3 = direction
	locked_direction.y = 0.0
	if locked_direction.length_squared() < 0.5 and player.has_method("get_beam_locked_direction"):
		locked_direction = player.get_beam_locked_direction()
	if locked_direction.length_squared() < 0.5:
		locked_direction = -player.global_transform.basis.z
	locked_direction.y = 0.0
	if locked_direction.length_squared() < 0.5:
		locked_direction = Vector3.FORWARD
	locked_direction = locked_direction.normalized()
	var origin: Vector3 = player.get_oathfire_origin() if player.has_method("get_oathfire_origin") else player.global_position + Vector3(0, 1.12, 0) + locked_direction * 0.62
	var beam_range: float = 12.0 + progression.effect_value("beam_range_bonus", 0.0)
	var endpoint: Vector3 = origin + locked_direction * beam_range
	var query = PhysicsRayQueryParameters3D.create(origin, endpoint, 1)
	var beam_exclusions: Array[RID] = [player.get_rid()]
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			beam_exclusions.append(enemy.get_rid())
	query.exclude = beam_exclusions
	query.collide_with_areas = false
	var result: Dictionary = _host.get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		endpoint = result.position
	var damage: float = lerpf(35.0, 70.0, charge_ratio)
	var cast := {
		"origin": origin,
		"direction": locked_direction,
		"endpoint": endpoint,
		"endpoint_distance": origin.distance_to(endpoint),
		"width": 1.2,
		"damage": damage,
		"charge_ratio": charge_ratio
	}
	var hits: Array = combat.resolve_oathfire_cast(active_enemies, cast)
	var practice: Node = preload("res://scripts/greyfen_village_details.gd").current(_host)
	if practice != null: practice.oathfire_contact(cast)
	_host.set_meta("last_oathfire_cast", cast)
	_host.set_meta("last_oathfire_hit_count", hits.size())
	_make_oathfire_beam(origin, endpoint, charge_ratio, not _performance_mode())
	CombatFeedback.beam_endpoint(zone_root, endpoint, locked_direction, not _performance_mode())
	if camera_rig != null:
		camera_rig.shake(0.12 + 0.08 * charge_ratio)
	CombatFeedback.ground_ring(zone_root, player.global_position, Color(0.18, 0.72, 0.95), 0.75, 0.18)
	CombatFeedback.impact_burst(zone_root, origin, false, Color(0.62, 0.95, 1.0))
	CombatFeedback.impact_burst(zone_root, endpoint, true, Color(0.26, 0.82, 1.0))
	for enemy in hits:
		if is_instance_valid(enemy) and enemy.has_method("interrupt_boss_windup") and str(enemy.get("enemy_id")) == "ashwing":
			if enemy.interrupt_boss_windup("oathfire"):
				hud.toast("Oathfire breaks Ashwing's breath.")
		CombatFeedback.impact_burst(zone_root, enemy.global_position + Vector3(0, 0.9, 0), true, Color(0.30, 0.88, 1.0))
	hud.show_status_cue("Oathfire Beam", "item")

func _make_oathfire_beam(origin: Vector3, endpoint: Vector3, charge_ratio: float, rich_effect: bool) -> void:
	var reduce_flashes := bool(settings.settings.get("flash_reduction", false))
	combat_vfx_coordinator.make_oathfire_beam(zone_root, origin, endpoint, charge_ratio, rich_effect, reduce_flashes)

func _clear_oathfire_effects() -> void:
	combat_vfx_coordinator.clear_oathfire_effects()

func _on_player_footstep() -> void:
	if audio == null or player == null:
		return
	var on_road = abs(player.global_position.x) < 2.25
	if current_zone_id == "wychwood":
		on_road = abs(player.global_position.x) < 2.5 and player.global_position.z > -12.5
	var surface := "road" if on_road else "forest"
	if current_zone_id in ["vargan_court", "record_hall", "undercroft", "assembly"]:
		surface = "stone"
	elif current_zone_id in ["marsh_crossing", "old_mill", "burned_farmstead"]:
		surface = "mud"
	elif current_zone_id == "hart_glade":
		surface = "forest"
	elif spatial_service != null and spatial_service.is_on_bridge(player.global_position):
		surface = "wood"
	audio.play_footstep(current_zone_id, on_road, surface)

func _on_player_parried() -> void:
	if current_zone_id == "wychwood": preload("res://scripts/greyfen_guidance.gd").learn(_host, "parry")
	if progression != null and player != null:
		player.stamina_component.restore(progression.effect_value("parry_stamina_restore", 0.0) + progression.entitlement_effect("saga_parry_restore", 0.0))
	tutorial_flags["block_hint_done"] = true
	hud.set_guidance_hint("")

func _on_player_blocked(_amount: float) -> void:
	if current_zone_id == "wychwood": preload("res://scripts/greyfen_guidance.gd").learn(_host, "block")
	audio.play_event("block")
	if input_router != null:
		input_router.rumble(0.18, 0.32, 0.08)
	if camera_rig != null:
		camera_rig.shake(0.08)
	if zone_root != null and player != null:
		var blade: Dictionary = player.get_blade_world_segment()
		var contact: Vector3 = (blade.base as Vector3).lerp(blade.tip, 0.55)
		CombatFeedback.block_flash(zone_root, player.global_position, false, contact)
		CombatFeedback.ground_ring(zone_root, player.global_position, Color(0.58, 0.36, 0.12), 0.45, 0.12)
	hud.show_status_cue("Blocked", "block")
	tutorial_flags["block_hint_done"] = true
	hud.set_guidance_hint("")

func _on_player_hurt(_amount: float) -> void:
	audio.play_event("hurt")
	if input_router != null:
		input_router.rumble(0.36, 0.58, 0.14)
	if camera_rig != null:
		camera_rig.shake(0.14)
	if zone_root != null and player != null:
		CombatFeedback.impact_burst(zone_root, player.global_position + Vector3(0, 1.0, 0), false, Color(0.9, 0.22, 0.12))
	hud.show_status_cue("Hit: -%d" % int(_amount), "hurt")

func _on_player_stamina_exhausted(_action: String) -> void:
	hud.mark_stamina_exhausted()
	hud.set_guidance_hint("Breath is spent. Back away, then strike.", 2.8)

func _on_enemy_died(enemy) -> void:
	if progression != null and not bool(enemy.get("is_boss")) and not bool(enemy.get_meta("bell_called_ghoulkin", false)):
		var reward_id := str(enemy.get_meta("progression_reward_id", ""))
		if bool(enemy.get_meta("progression_opening_wave", false)):
			reward_id = "opening_wave:%d" % mini(wychwood_pack_kills, 4)
		if reward_id != "":
			progression.award_encounter(reward_id, str(enemy.get_meta("progression_zone", current_zone_id)), enemy.display_name)
	audio.play_enemy_event(enemy.enemy_id, "death", enemy.global_position, player.global_position)
	if camera_rig != null:
		camera_rig.shake(0.09)
	if zone_root != null and enemy != null:
		CombatFeedback.ground_ring(zone_root, enemy.global_position, Color(0.12, 0.08, 0.055), 0.9, 0.24)
	if bool(enemy.get("is_boss")):
		if enemy.enemy_id == "bell_eater":
			_restore_bell_eater_bystanders()
			story_state.set_flag("bell_eater_defeated", true)
			story_state.set_flag("cemetery_bell_silent", true)
			_retire_bell_eater()
			_spawn_crow_shrine_choice()
			hud.show_status_cue("The Bell-Eater is silent", "victory")
			hud.toast("The chapel bell stops. Beneath the silence, the Crow Shrine waits for your answer.")
			_show_current_objective_guidance(6.0)
		elif enemy.enemy_id == "rootbound_colossus":
			story_state.set_flag("rootbound_colossus_defeated", true)
			hud.show_status_cue("The roots release Greyfen", "victory")
			hud.toast("The clearing opens around a heart of oathwood. The road remembers a new name.")
		elif enemy.enemy_id == "ashwing":
			story_state.set_flag("ashwing_defeated", true)
			if current_zone_id == "old_mill" and not quests.is_objective_done("main_ash_at_the_mill", "mill_choice"):
				_make_named_interactable("miller_record", "dialogue", "Read the miller's record", Vector3(-5.2,0.48,-3.4), Color(0.5,0.4,0.25))
			hud.show_status_cue("Ashwing falls", "victory")
			hud.toast("The mill roof catches the last ember, then goes dark. Something useful survived in the ash.")
		elif enemy.enemy_id == "bog_wretch":
			quests.complete_objective("main_teeth_in_rain", "fight_bog_wretch")
			story_state.set_flag("bog_memory_core_revealed", true)
			if not bool(story_state.get_flag("bog_core_exposed", false)):
				story_state.set_flag("bog_core_forced_open", true)
			_make_named_interactable("bog_core_choice", "dialogue", "Choose the memory core's fate", enemy.global_position, Color(0.35,0.58,0.52), Vector3.ONE * 0.4)
		elif enemy.enemy_id == "halvern_boss":
			story_state.set_flag("halvern_fate", "defeated")
			_publish_halvern_exit()
			quests.complete_objective("main_last_witness", "break_halvern_guard")
			hud.show_status_cue("The Gravebound Knight yields", "victory")
			_show_current_objective_guidance(6.0)
		elif enemy.enemy_id == "white_hart_avatar":
			var ending = pending_ending if pending_ending != "" else "kill"
			pending_ending = ""
			story_state.set_flag("hart_defeated", true)
			_show_ending_consequence(ending)
	elif current_zone_id == "greyfen" and bool(enemy.get_meta("act_one_cemetery_ambush", false)):
		quests.complete_objective("main_bell_beneath_greyfen", "cemetery_ambush")
		story_state.set_flag("cemetery_ambush_cleared", true)
		hud.hide_enemy()
		hud.show_status_cue("The graves fall still", "victory")
		_show_current_objective_guidance(5.0)
		hud.toast("The Ghoulkin carried grave soil beneath its nails. The chapel seal answers its death.")
	elif current_zone_id == "wychwood" and enemy.enemy_id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute"]:
		wychwood_pack_kills += 1
		if wychwood_pack_kills == 1:
			_activate_wychwood_wave(["ghoulkin"], "A second Ghoulkin answers from the trees.")
		elif wychwood_pack_kills == 2:
			_activate_wychwood_wave(["wychwood_stalker"], "Branches snap along the left flank.")
		elif wychwood_pack_kills == 3:
			_activate_wychwood_wave(["wychwood_raider"], "A raider cuts across the clearing.")
		elif wychwood_pack_kills == 4:
			_activate_wychwood_wave(["wychwood_brute"], "The earth heaves. The Brute comes last.")
		if wychwood_pack_kills >= 5:
			quests.complete_objective("main_road_of_crows", "fight_ghoulkin")
			story_state.set_flag("wychwood_pack_cleared", true)
			audio.play_event("victory", 0.03)
			audio.play_music_cue("victory_return_cue", "return_report")
			audio.set_music_state("return_report")
			audio.play_voice("voice_player_ghoulkin_death_01")
			hud.hide_enemy()
			hud.show_status_cue("Wychwood pack broken", "victory")
			_show_current_objective_guidance(6.0)
			hud.toast("The Ghoulkin dies too far from its den. Something drew it to the road. Search the tracks.")
			_make_post_ghoulkin_story_clue()
	elif enemy.enemy_id == "bog_wretch":
		quests.complete_objective("main_teeth_in_rain", "fight_bog_wretch")
		story_state.set_flag("bog_memory_core_revealed", true)
		if not bool(story_state.get_flag("bog_core_exposed", false)):
			story_state.set_flag("bog_core_forced_open", true)
		_make_named_interactable("bog_core_choice", "dialogue", "Choose the memory core's fate", enemy.global_position, Color(0.35, 0.58, 0.52), Vector3(0.4, 0.4, 0.4))
		hud.show_status_cue("A memory remains", "victory")
		_show_current_objective_guidance(5.0)
	elif enemy.enemy_id == "wychwood_stalker" and current_zone_id == "record_hall":
		story_state.set_flag("castle_haunting_cleared", true)
		quests.complete_objective("main_blood_under_stone", "survive_haunting")
		hud.toast("The erased names settle. Edric waits beneath the Vargan seal.")
		_show_current_objective_guidance(6.0)
		_load_zone("record_hall", player.global_position)
	elif enemy.enemy_id == "gravebound_knight":
		if current_zone_id == "undercroft":
			quests.complete_objective("main_last_witness", "break_halvern_guard")
		if current_zone_id == "ruins" and quests.is_unlocked("main_hart_remembers"):
			_make_named_interactable("white_hart", "dialogue", "Speak to the White Hart", Vector3(12, 0, 10), Color(0.86, 0.83, 0.70), Vector3(0.36, 0.64,0.36))
	elif enemy.enemy_id == "bandit":
		if current_zone_id == "bandit_road" and bool(enemy.get_meta("senn_guard", false)) and not _has_living_enemy("bandit"):
			if not bool(story_state.get_flag("saga_senn_requires_duel", false)):
				quests.complete_objective("main_soldier_without_banner", "senn_confrontation")
				story_state.set_flag("senn_ready_to_testify", true)
			hud.show_status_cue("Senn's guard breaks", "victory")
			_show_current_objective_guidance(5.5)
		elif current_zone_id == "wychwood" and quests.is_active("side_black_dog") and not _has_living_enemy("bandit"):
			story_state.set_flag("black_dog_bandits_defeated", true)
			_try_complete_black_dog_investigation()

	elif current_zone_id == "old_mill" and bool(enemy.get_meta("ash_mill_enemy", false)):
		var ash_enemy_alive := false
		for candidate in active_enemies:
			if is_instance_valid(candidate) and candidate != enemy and not candidate.dead and bool(candidate.get_meta("ash_mill_enemy", false)):
				ash_enemy_alive = true
				break
		if not ash_enemy_alive:
			quests.complete_objective("main_ash_at_the_mill", "mill_encounter")
			story_state.set_flag("ash_mill_cleared", true)
			if not _has_living_enemy("ashwing") and not bool(story_state.get_flag("ashwing_defeated", false)) and enemy_defs.has("ashwing"):
				var ashwing := _spawn_enemy("ashwing", Vector3(5.0, 1.0, -6.5))
				if ashwing != null:
					story_state.set_flag("ashwing_spawned", true)
					ashwing.name = "AshwingCarrionDrake"
					ashwing.leash_radius = 10.0
					hud.toast("The mill roof groans. Ashwing drops through the smoke.")
			hud.show_status_cue("The mill falls quiet", "victory")
		_show_current_objective_guidance(5.5)
	if enemy.health_component != null:
		hud.show_enemy(enemy.display_name, 0.0, enemy.health_component.max_health)
	var memory_rule := str(enemy.get_meta("memory_rule", ""))
	if memory_rule != "" and not bool(enemy.get_meta("memory_rule_seen", false)):
		enemy.set_meta("memory_rule_seen", true)
		hud.toast("%s slain. %s" % [enemy.display_name, memory_rule])
	else:
		hud.toast("%s slain." % enemy.display_name)
	_collect_progression_rewards()
	save_manager.autosave(_host)

func _try_complete_black_dog_investigation() -> void:
	if not quests.is_active("side_black_dog") or quests.is_objective_done("side_black_dog", "find_dog"):
		return
	if not bool(story_state.get_flag("black_dog_sheepfold_inspected", false)):
		return
	if not bool(story_state.get_flag("black_dog_bandit_camp_inspected", false)):
		return
	if not bool(story_state.get_flag("black_dog_bandits_defeated", false)):
		return
	quests.complete_objective("side_black_dog", "find_dog")
	hud.toast("The bandits held the ribbon. The black dog drove them from the children, not toward them.")
	_show_current_objective_guidance(5.0)

func _try_complete_oren_thread_trace(publish_return := true) -> void:
	if not quests.is_active("side_childs_charm") or quests.is_objective_done("side_childs_charm", "trace_thread"):
		return
	var found_oren := bool(story_state.get_flag("road_evidence_oren", false)) \
		or bool(story_state.get_flag("road_token_recovered", false)) \
		or bool(story_state.get_flag("oren_name_spoken", false))
	if not found_oren or not bool(story_state.get_flag("chapel_names_read", false)):
		return
	quests.complete_objective("side_childs_charm", "trace_thread")
	if publish_return and current_zone_id == "greyfen" and zone_root != null:
		load("res://scripts/zones/greyfen_section.gd").new().publish_oren_charm_return(ZoneBuildContext.new(_host, "greyfen"))
	hud.toast("The red thread from Oren's token matches his erased place in the chapel.")
	_show_current_objective_guidance(5.0)

func _record_encounter_knowledge(enemy) -> void:
	if story_state == null or not is_instance_valid(enemy):
		return
	var enemy_id := str(enemy.enemy_id)
	var evidence_id := "creature:" + enemy_id
	if story_state.has_evidence(evidence_id):
		return
	story_state.record_evidence(evidence_id, {
		"kind": "observed", "enemy_id": enemy_id,
		"title": str(enemy.display_name), "zone": current_zone_id,
		"source": "Encounter in " + current_zone_id.replace("_", " ").capitalize(),
		"body": "Kael has faced this foe and seen how it moves."
	})

func _on_enemy_damaged(enemy, current: float, maximum: float) -> void:
	_record_encounter_knowledge(enemy)
	hud.show_enemy(enemy.display_name, current, maximum)
	hud.show_status_cue("Enemy hit", "item")
	audio.play_enemy_event(enemy.enemy_id, "hit", enemy.global_position, player.global_position)

func _on_enemy_windup_started(enemy) -> void:
	_record_encounter_knowledge(enemy)
	if enemy != null and player != null:
		audio.play_enemy_event(enemy.enemy_id, "windup", enemy.global_position, player.global_position)
	if zone_root != null and enemy != null:
		if bool(enemy.get("is_boss")):
			CombatFeedback.boss_telegraph(zone_root, enemy.global_position, enemy.enemy_id)
		else:
			CombatFeedback.ground_ring(zone_root, enemy.global_position, Color(0.46, 0.05, 0.025), 0.62, 0.18)
	if enemy != null and enemy.health_component != null:
		hud.show_enemy(enemy.display_name, enemy.health_component.health, enemy.health_component.max_health)
	var guide_guard_pending := str(story_state.get_flag("greyfen_guide", "")) == "active" and (not bool(story_state.get_flag("greyfen_lesson:block", false)) or not bool(story_state.get_flag("greyfen_lesson:parry", false)))
	if current_zone_id == "wychwood" and (guide_guard_pending or not bool(tutorial_flags.get("block_hint_done", false))):
		hud.set_guidance_hint(_guard_tutorial_hint(), 4.2)

func _on_enemy_attack_resolved(enemy, parried: bool, contact_position: Vector3) -> void:
	if parried:
		var blade: Dictionary = player.get_blade_world_segment()
		contact_position = Geometry3D.get_closest_point_to_segment(contact_position, blade.base, blade.tip)
		audio.play_event_limited("parry", 0.10, 0.03)
		if input_router != null:
			input_router.rumble(0.24, 0.52, 0.10)
		if camera_rig != null:
			camera_rig.shake(0.18)
		if zone_root != null:
			CombatFeedback.block_flash(zone_root, player.global_position, true, contact_position)
			CombatFeedback.impact_burst(zone_root, contact_position, true, Color(0.74, 0.88, 1.0))
			CombatFeedback.ground_ring(zone_root, player.global_position, Color(0.22, 0.46, 0.72), 0.65, 0.16)
		hud.show_status_cue("Parry", "parry")
		hud.toast("Parry breaks %s's guard." % enemy.display_name)
		if enemy != null and enemy.enemy_id == "bog_wretch":
			_record_bog_stagger(enemy, "parries")
	else:
		if enemy != null:
			audio.play_enemy_event(enemy.enemy_id, "attack", contact_position, player.global_position)
		if zone_root != null and enemy != null:
			CombatFeedback.impact_burst(zone_root, contact_position, false, Color(0.85, 0.30, 0.12))
	if enemy != null and enemy.health_component != null:
		hud.show_enemy(enemy.display_name, enemy.health_component.health, enemy.health_component.max_health)

func _on_enemy_parry_window_opened(enemy: Node, duration: float) -> void:
	if enemy == null or not is_instance_valid(enemy) or not bool(enemy.get("is_boss")):
		return
	if enemy.enemy_id == "captain_senn":
		preload("res://scripts/saga_encounters.gd").senn_yields(_host, enemy)
	elif enemy.enemy_id == "halvern_boss":
		story_state.set_flag("halvern_guard_broken", true)
		if quests.is_active("main_last_witness"):
			quests.complete_objective("main_last_witness", "break_halvern_guard")
		hud.show_status_cue("Halvern's guard breaks", "parry")
		_show_current_objective_guidance(maxf(duration, 2.5))
		audio.play_event_limited("parry", 0.16, 0.02)

func _record_bog_stagger(enemy, source: String) -> void:
	var count := int(story_state.get_flag("bog_stagger_hits", 0)) + 1
	story_state.set_flag("bog_stagger_hits", count)
	if count >= 2:
		_expose_bog_core(enemy, source)

func _expose_bog_core(enemy, method: String) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.enemy_id != "bog_wretch":
		return
	if bool(story_state.get_flag("bog_core_exposed", false)):
		return
	story_state.set_flag("bog_core_exposed", true)
	story_state.set_flag("bog_core_exposure_method", method)
	enemy.stagger(1.15)
	hud.show_status_cue("Memory core exposed", "victory")
	hud.toast("%s tears the dead memory loose from the Wretch's hide." % method)
	audio.play_event("reveal", 0.035)

func _on_target_lock_changed(target_actor: Node3D, locked: bool) -> void:
	if hud == null:
		return
	if not locked or target_actor == null or not is_instance_valid(target_actor):
		hud.clear_target_lock_status()
		return
	var display_name := str(target_actor.get("display_name"))
	hud.set_target_lock_status(display_name if display_name != "" else "Enemy", player.global_position.distance_to(target_actor.global_position))

func _update_target_lock_hud() -> void:
	if hud == null or camera_rig == null or not camera_rig.has_method("get_locked_combat_target"):
		return
	var target_actor: Node3D = camera_rig.get_locked_combat_target()
	if target_actor == null or not is_instance_valid(target_actor):
		hud.clear_target_lock_status()
		return
	var display_name := str(target_actor.get("display_name"))
	hud.set_target_lock_status(display_name if display_name != "" else "Enemy", player.global_position.distance_to(target_actor.global_position))

func _on_combat_impact(pos: Vector3, heavy: bool) -> void:
	_hitstop(0.055 if heavy else 0.032)
	if audio != null:
		audio.play_event("heavy_hit" if heavy else "light_hit", 0.04)
	if camera_rig != null:
		camera_rig.shake(0.11 if heavy else 0.06)
	_make_hit_spark(pos, heavy)
	if zone_root != null:
		CombatFeedback.ground_ring(zone_root, pos, Color(0.54, 0.36, 0.16), 0.42 if heavy else 0.30, 0.12)
	combat_impact.emit(pos, heavy)

func _hitstop(seconds: float) -> void:
	if _host.get_tree().paused or zone_transition_pending:
		return
	if settings != null and bool(settings.settings.get("reduced_motion", false)):
		return
	if not is_equal_approx(Engine.time_scale, 0.18):
		_hitstop_restore_scale = Engine.time_scale
	_hitstop_generation += 1
	var generation := _hitstop_generation
	Engine.time_scale = 0.18
	var timer := _create_owned_timer(seconds, true)
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.timeout.connect(func():
		if generation == _hitstop_generation:
			Engine.time_scale = _hitstop_restore_scale
	)

func _has_living_enemy(enemy_id: String) -> bool:
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.enemy_id == enemy_id:
			return true
	return false

func _nearest_living_enemy(max_distance: float):
	var best = null
	var best_distance = max_distance
	for enemy in active_enemies:
		if enemy == null or enemy.dead:
			continue
		var dist = enemy.global_position.distance_to(player.global_position)
		if dist < best_distance:
			best_distance = dist
			best = enemy
	return best

func _on_player_died() -> void:
	if camera_rig != null and camera_rig.has_method("clear_target_lock"):
		camera_rig.clear_target_lock()
	if hud != null and hud.has_method("clear_target_lock_status"):
		hud.clear_target_lock_status()
	audio.play_event("hurt")
	audio.set_game_paused(true)
	_host.get_tree().paused = true
	hud.clear_journey_transients(false)
	_refresh_journey_models()
	hud.show_death_screen("The road keeps its dead.\n\nChoose a recorded journey to return to its saved story state.")

func _spawn_enemy(id: String, pos: Vector3, visual_role: String = "") -> Node:
	return _zone_construction()._spawn_enemy(id, pos, visual_role)

func _boss_is_resolved(id: String) -> bool:
	if id == "bell_eater" and bool(story_state.get_flag("bell_eater_legacy_retired", false)):
		return true
	if id == "bog_wretch" and quests.is_objective_done("main_teeth_in_rain", "fight_bog_wretch"):
		return true
	if id == "captain_senn" and (quests.is_objective_done("main_soldier_without_banner", "senn_confrontation") or str(story_state.get_flag("senn_fate", "")) not in ["", "unresolved"]):
		return true
	if not bool(enemy_defs.get(id, {}).get("boss", false)):
		return false
	var story_resolved: String = str({
		"bell_eater": "bell_eater_defeated",
		"rootbound_colossus": "rootbound_colossus_defeated",
		"ashwing": "ashwing_defeated",
	}.get(id, ""))
	if story_resolved != "" and bool(story_state.get_flag(story_resolved, false)):
		return true
	if id == "white_hart_avatar" and bool(story_state.get_flag("final_choice_completed", false)):
		return true
	var saved: Variant = boss_saved_states.get(id, {})
	if typeof(saved) == TYPE_DICTIONARY:
		var saved_outcome := str(saved.get("outcome", ""))
		return saved_outcome in ["defeated", "release", "testimony", "witness", "mercy", "duty", "ash"]
	return false

func _ensure_bell_eater() -> void:
	if current_zone_id != "greyfen" or _boss_is_resolved("bell_eater"):
		return
	for enemy in active_enemies:
		if is_instance_valid(enemy) and str(enemy.get_meta("boss_id", "")) == "bell_eater" and not enemy.dead:
			return
	# The chapel shell is occupied scenery. Spawn the boss in the broad west
	# cemetery approach so spatial recovery cannot relocate it outside its arena.
	var boss := _spawn_enemy("bell_eater", Vector3(10.0, 0.8, 8.0))
	if boss != null:
		boss.name = "BellEaterEncounter"
		boss.leash_radius = 9.0
		boss.set_meta("boss_arena", "cemetery")
		_evacuate_bell_eater_bystanders()
		hud.show_status_cue("The Bell-Eater wakes", "danger")
		hud.toast("The bell rings once beneath the chapel. Something large pulls against the graves.")
		_show_current_objective_guidance(6.0)
		audio.play_event("boss", 0.02)

func _retire_bell_eater() -> void:
	for enemy in active_enemies.duplicate():
		if not is_instance_valid(enemy):
			continue
		if str(enemy.enemy_id) != "bell_eater" and not bool(enemy.get_meta("bell_called_ghoulkin", false)):
			continue
		if enemy.dead:
			continue
		enemy.set_encounter_active(false)
		active_enemies.erase(enemy)
		if active_enemy_attacker == enemy:
			active_enemy_attacker = null
		enemy.queue_free()
	_restore_bell_eater_bystanders()
	if camera_rig != null:
		camera_rig.clear_target_lock()
	if hud != null:
		hud.hide_enemy()
	_sync_camera_enemy_cache()

func _open_rootbound_encounter() -> void:
	story_state.set_flag("rootbound_arena_entered", true)
	for enemy in active_enemies:
		if is_instance_valid(enemy) and str(enemy.enemy_id) == "rootbound_colossus":
			enemy.set_meta("dormant_arena", false)
			enemy.set_physics_process(true)
	var invitation: Node = zone_root.find_child("rootbound_challenge", true, false) if zone_root != null else null
	if invitation != null:
		_remove_interaction_candidate(invitation)
		invitation.queue_free()
	hud.toast("The guardian braces around the name-board. Follow the root channels before its heart opens.")

func _evacuate_bell_eater_bystanders() -> void:
	if zone_root == null:
		return
	var staging := {
		"sister_anwen": Vector3(9.2, 0.0, 5.2),
		"widow_elna": Vector3(8.6, 0.0, 6.0),
	}
	for actor_id in staging:
		var actor := zone_root.find_child(actor_id, true, false) as Node3D
		if actor == null or bool(actor.get_meta("bell_eater_evacuated", false)):
			continue
		actor.set_meta("bell_eater_evacuated", true)
		actor.set_meta("bell_eater_return_position", actor.global_position)
		actor.global_position = validate_walkable_position(staging[actor_id])
		if actor is Area3D:
			(actor as Area3D).monitoring = false
			(actor as Area3D).monitorable = false
		var driver := actor.find_child("CharacterAnimationDriver", true, false)
		if driver != null and driver.has_method("set_dialogue_pose"):
			driver.set_dialogue_pose(true)
		_face_npc_toward_player(actor)

func _restore_bell_eater_bystanders() -> void:
	if zone_root == null:
		return
	for actor_id in ["sister_anwen", "widow_elna"]:
		var actor := zone_root.find_child(actor_id, true, false) as Node3D
		if actor == null or not bool(actor.get_meta("bell_eater_evacuated", false)):
			continue
		var original: Variant = actor.get_meta("bell_eater_return_position", actor.global_position)
		if original is Vector3:
			actor.global_position = validate_walkable_position(original)
		if actor is Area3D:
			(actor as Area3D).monitoring = true
			(actor as Area3D).monitorable = true
		actor.set_meta("bell_eater_evacuated", false)
		var driver := actor.find_child("CharacterAnimationDriver", true, false)
		if driver != null and driver.has_method("set_dialogue_pose"):
			driver.set_dialogue_pose(false)

func _on_boss_controller_phase_changed(boss_id: String, phase: int) -> void:
	story_state.set_flag("boss_%s_phase" % boss_id, phase)
	if audio != null:
		audio.set_music_state("boss_%s" % boss_id)

func _on_boss_checkpoint(controller: Node) -> void:
	if controller == null:
		return
	var boss_id := str(controller.get("boss_id"))
	var state: Dictionary = controller.save_state() if controller.has_method("save_state") else {}
	boss_saved_states[boss_id] = state
	story_state.set_flag("boss_%s_checkpoint" % boss_id, int(controller.get("checkpoint")))
	# A phase boundary is an authored checkpoint. It must survive a reload even
	# when the player dies before the next ordinary autosave boundary.
	if save_manager != null and player != null and is_instance_valid(player) and not resource_shutdown_prepared:
		save_manager.checkpoint(_host)

func _on_boss_resolved(boss_id: String, outcome: String) -> void:
	story_state.set_flag("boss_%s_outcome" % boss_id, outcome)
	_apply_boss_resolution_contract(boss_id)
	_collect_progression_rewards()
	for candidate in active_enemies:
		if not is_instance_valid(candidate) or str(candidate.enemy_id) != boss_id:
			continue
		var controller: Node = candidate.get_node_or_null("BossEncounterController")
		if controller != null and controller.has_method("save_state"):
			boss_saved_states[boss_id] = controller.save_state()
		break
	if save_manager != null and player != null and is_instance_valid(player) and not resource_shutdown_prepared:
		save_manager.checkpoint(_host)

func _apply_boss_resolution_contract(boss_id: String) -> void:
	var definition: Dictionary = boss_defs.get(boss_id, {})
	if definition.is_empty():
		return
	var grant_key := "boss_reward_granted_%s" % boss_id
	if not bool(story_state.get_flag(grant_key, false)):
		var rewards: Variant = definition.get("rewards", [])
		if typeof(rewards) == TYPE_ARRAY:
			for reward_id in rewards:
				var reward := str(reward_id).strip_edges()
				if reward != "":
					story_state.set_flag("boss_reward_%s" % reward, true)
		story_state.set_flag(grant_key, true)
	var aftermath := str(definition.get("aftermath_state", "")).strip_edges()
	if aftermath != "":
		story_state.set_flag(aftermath, true)

func _publish_halvern_exit() -> void:
	if current_zone_id == "undercroft" and str(story_state.get_flag("halvern_fate", "")) != "" and not _has_interactable("gate_record_hall"):
		_make_zone_gate("Return through the Record Hall toward Greyfen", Vector3(-6, 0, 14), "record_hall", Vector3(6, 0.95, -12))

func _on_boss_peaceful_resolution(boss_id: String, outcome: String, enemy: Node) -> void:
	story_state.set_flag("boss_%s_outcome" % boss_id, outcome)
	if boss_id == "halvern_boss":
		story_state.set_flag("halvern_fate", "witness" if outcome in ["testimony", "release", "witness"] else outcome)
		_publish_halvern_exit()
		if current_zone_id == "undercroft":
			quests.complete_objective("main_last_witness", "break_halvern_guard")
			hud.show_status_cue("Halvern lowers his blade", "victory")
			hud.toast("The knight will speak. The undercroft no longer needs a gravekeeper.")
			if enemy != null:
				enemy.set_encounter_active(false)
	elif boss_id == "white_hart_avatar":
		var covenant := str({"witness":"witness", "mercy":"mercy", "release":"mercy", "duty":"duty", "ash":"ash"}.get(outcome, outcome))
		story_state.set_flag("final_covenant", covenant)
		story_state.set_flag("final_choice_completed", true)
		quests.complete_objective("main_hart_remembers", "final_choice")
		if current_zone_id == "hart_glade":
			hud.show_status_cue("The Hart accepts the oath", "victory")
			hud.toast("The road remembers %s." % covenant.capitalize())
			if enemy != null:
				enemy.set_encounter_active(false)

func _on_boss_phase_changed(enemy: Node, phase: int) -> void:
	if enemy == null or not is_instance_valid(enemy) or not bool(enemy.get("is_boss")):
		return
	var cue := "The arena shifts beneath the witness."
	if enemy.enemy_id == "white_hart_avatar":
		cue = "The Hart tears roots from the old road." if phase == 2 else "The covenant is breaking."
	elif enemy.enemy_id == "bell_eater":
		cue = "The bell harness splits. The dead answer from below."
	elif enemy.enemy_id == "rootbound_colossus":
		cue = "The roots tear open around its heart."
	elif enemy.enemy_id == "ashwing":
		cue = "Ashwing breaks from the mill roof."
	elif enemy.enemy_id == "halvern_boss":
		cue = "Halvern stops defending the old command."
	hud.show_status_cue("%s — Phase %d" % [enemy.display_name, phase], "danger")
	hud.toast(cue)
	audio.set_music_state("boss_%s" % str(enemy.enemy_id))
	audio.play_event("reveal" if phase == 2 else "boss", 0.025)
	if world_vfx != null and is_instance_valid(world_vfx):
		world_vfx.pulse_interaction(enemy.global_position)
		CombatFeedback.impact_burst(zone_root, enemy.global_position + Vector3.UP, true, Color(0.58, 0.88, 0.72))

func _on_boss_special_attack(enemy: Node, attack_id: String, contact_position: Vector3, radius: float, damage: float, parried: bool) -> void:
	if enemy == null or not is_instance_valid(enemy) or not bool(enemy.get("is_boss")):
		return
	if zone_root != null:
		var attack_direction: Vector3 = -enemy.global_transform.basis.z
		CombatFeedback.boss_attack_release(zone_root, contact_position, attack_direction, attack_id, radius, parried)
	var cue: String = str({
		"bell_shockwave": "Bell shockwave",
		"grave_slam": "Grave slam",
		"ghoulkin_call": "The graves answer",
		"root_lanes": "Root lanes split the clearing",
		"ground_rupture": "The ground remembers the rupture",
		"heart_stagger": "The oathwood heart is exposed",
		"wing_blast": "Ashwing's wings break the air",
		"ash_breath": "Ash breath fills the mill",
		"swoop": "Ashwing drops from the smoke",
		"parry_test": "Halvern tests the guard",
		"counter_lunge": "Halvern answers the opening",
		"memory_echo": "The Hart returns a memory",
		"antler_sweep": "The Hart sweeps the old road",
		"road_reopening": "The road opens beneath the witness",
	}.get(attack_id, "The arena answers"))
	hud.show_status_cue(cue, "danger" if not parried else "parry")
	audio.play_event_limited("parry" if parried else "boss", 0.18, 0.025)
	if attack_id == "ghoulkin_call" and not bool(enemy.get_meta("called_ghoulkin", false)):
		enemy.set_meta("called_ghoulkin", true)
		var call_position: Vector3 = enemy.global_position + Vector3(2.2, 0.8, 1.4)
		var called := _spawn_enemy("ghoulkin", call_position)
		if called != null:
			called.set_meta("bell_called_ghoulkin", true)
			called.leash_radius = 8.0
			hud.toast("A Ghoulkin claws up through the bell's shadow.")

func _activate_wychwood_wave(ids: Array, cue: String) -> void:
	wychwood_encounter_started = true
	for enemy in active_enemies:
		if enemy != null and not enemy.dead and not enemy.is_encounter_active() and enemy.enemy_id in ids:
			enemy.set_encounter_active(true)
			break
	if hud != null:
		hud.toast(cue)
	if audio != null:
		audio.play_event("reveal", 0.02)

func _ensure_wychwood_wave() -> void:
	if wychwood_pack_kills >= 5 or quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
		return
	for enemy in active_enemies:
		if not is_instance_valid(enemy) or enemy.dead or not enemy.has_meta("wychwood_wave"):
			continue
		if int(enemy.get_meta("wychwood_wave")) != wychwood_pack_kills:
			continue
		wychwood_encounter_started = true
		if not enemy.is_encounter_active():
			enemy.set_encounter_active(true)
			if hud != null:
				hud.toast("Movement answers from the clearing.")
		return

func checkpoint_return_position() -> Vector3:
	var recorded: Vector3 = player.global_position
	if spatial_service == null or not _story_has_active_combat():
		return recorded
	var bank: int = spatial_service.bank_for(recorded)
	var best: Vector3 = recorded
	var best_clearance := -1.0
	var anchors: Array = spatial_service.safe_spawns.duplicate()
	anchors.append_array(spatial_service.recovery_anchors)
	for anchor: Vector3 in anchors:
		if spatial_service.bank_for(anchor) != bank or not spatial_service.is_walkable_position(anchor, 0.55, bank):
			continue
		var clearance := INF
		for enemy in active_enemies:
			if is_instance_valid(enemy) and not enemy.dead and enemy.is_encounter_active():
				clearance = minf(clearance, anchor.distance_to(enemy.global_position))
		if clearance > best_clearance:
			best_clearance = clearance
			best = anchor
	return best if best_clearance >= 5.0 else recorded

func _has_active_encounter_enemy() -> bool:
	for enemy in active_enemies:
		if enemy != null and is_instance_valid(enemy) and not enemy.dead and enemy.is_encounter_active():
			return true
	return false

func _enemy_attack_token(enemy: Node, claim: bool) -> bool:
	if claim:
		if active_enemy_attacker != null and is_instance_valid(active_enemy_attacker) and active_enemy_attacker != enemy:
			return false
		active_enemy_attacker = enemy
		return true
	if active_enemy_attacker == enemy:
		active_enemy_attacker = null
	return true
