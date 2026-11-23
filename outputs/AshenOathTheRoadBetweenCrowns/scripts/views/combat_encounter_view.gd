extends RefCounted
## combat encounter view: scene effects and consequence presentation.

var _actor: Node3D

func _init(actor: Node3D) -> void:
	_actor = actor

func _on_enemy_died(enemy: Variant) -> void:
	if _actor.progression != null and not bool(enemy.get("is_boss")) and not bool(_actor.read_presentation_tag(enemy, "bell_called_ghoulkin", false)):
		var reward_id: Variant = str(_actor.read_presentation_tag(enemy, "progression_reward_id", ""))
		if bool(_actor.read_presentation_tag(enemy, "progression_opening_wave", false)):
			reward_id = "opening_wave:%d" % mini(_actor.wychwood_pack_kills, 4)
		if reward_id != "":
			_actor.progression.award_encounter(reward_id, str(_actor.read_presentation_tag(enemy, "progression_zone", _actor.current_zone_id)), enemy.display_name)
	_actor.audio.play_enemy_event(enemy.enemy_id, "death", enemy.global_position, _actor.player.global_position)
	if _actor.camera_rig != null:
		_actor.camera_rig.shake(0.09)
	if _actor.zone_root != null and enemy != null:
		_actor.CombatFeedback.ground_ring(_actor.zone_root, enemy.global_position, Color(0.12, 0.08, 0.055), 0.9, 0.24)
	if bool(enemy.get("is_boss")):
		if enemy.enemy_id == "bell_eater":
			_actor._restore_bell_eater_bystanders()
			_actor.story_state.set_flag("bell_eater_defeated", true)
			_actor.story_state.set_flag("cemetery_bell_silent", true)
			_actor._retire_bell_eater()
			_actor._spawn_crow_shrine_choice()
			_actor.hud.show_status_cue("The Bell-Eater is silent", "victory")
			_actor.hud.toast("The chapel bell stops. Beneath the silence, the Crow Shrine waits for your answer.")
			_actor._show_current_objective_guidance(6.0)
		elif enemy.enemy_id == "rootbound_colossus":
			_actor.story_state.set_flag("rootbound_colossus_defeated", true)
			_actor.hud.show_status_cue("The roots release Greyfen", "victory")
			_actor.hud.toast("The clearing opens around a heart of oathwood. The road remembers a new name.")
		elif enemy.enemy_id == "ashwing":
			_actor.story_state.set_flag("ashwing_defeated", true)
			if _actor.current_zone_id == "old_mill" and not _actor.quests.is_objective_done("main_ash_at_the_mill", "mill_choice"):
				_actor._make_named_interactable("miller_record", "dialogue", "Read the miller's record", Vector3(-5.2,0.48,-3.4), Color(0.5,0.4,0.25))
			_actor.hud.show_status_cue("Ashwing falls", "victory")
			_actor.hud.toast("The mill roof catches the last ember, then goes dark. Something useful survived in the ash.")
		elif enemy.enemy_id == "bog_wretch":
			_actor.quests.complete_objective("main_teeth_in_rain", "fight_bog_wretch")
			_actor.story_state.set_flag("bog_memory_core_revealed", true)
			if not bool(_actor.story_state.get_flag("bog_core_exposed", false)):
				_actor.story_state.set_flag("bog_core_forced_open", true)
			_actor._make_named_interactable("bog_core_choice", "dialogue", "Choose the memory core's fate", enemy.global_position, Color(0.35,0.58,0.52), Vector3.ONE * 0.4)
		elif enemy.enemy_id == "halvern_boss":
			_actor.story_state.set_flag("halvern_fate", "defeated")
			_actor._publish_halvern_exit()
			_actor.quests.complete_objective("main_last_witness", "break_halvern_guard")
			_actor.hud.show_status_cue("The Gravebound Knight yields", "victory")
			_actor._show_current_objective_guidance(6.0)
		elif enemy.enemy_id == "white_hart_avatar":
			var ending = _actor.pending_ending if _actor.pending_ending != "" else "kill"
			_actor.pending_ending = ""
			_actor.story_state.set_flag("hart_defeated", true)
			_actor._systems["quest"]._show_ending_consequence(ending)
	elif _actor.current_zone_id == "greyfen" and bool(_actor.read_presentation_tag(enemy, "act_one_cemetery_ambush", false)):
		_actor.quests.complete_objective("main_bell_beneath_greyfen", "cemetery_ambush")
		_actor.story_state.set_flag("cemetery_ambush_cleared", true)
		_actor.hud.hide_enemy()
		_actor.hud.show_status_cue("The graves fall still", "victory")
		_actor._show_current_objective_guidance(5.0)
		_actor.hud.toast("The Ghoulkin carried grave soil beneath its nails. The chapel seal answers its death.")
	elif _actor.current_zone_id == "wychwood" and enemy.enemy_id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute"]:
		_actor.wychwood_pack_kills += 1
		if _actor.wychwood_pack_kills == 1:
			_actor._activate_wychwood_wave(["ghoulkin"], "A second Ghoulkin answers from the trees.")
		elif _actor.wychwood_pack_kills == 2:
			_actor._activate_wychwood_wave(["wychwood_stalker"], "Branches snap along the left flank.")
		elif _actor.wychwood_pack_kills == 3:
			_actor._activate_wychwood_wave(["wychwood_raider"], "A raider cuts across the clearing.")
		elif _actor.wychwood_pack_kills == 4:
			_actor._activate_wychwood_wave(["wychwood_brute"], "The earth heaves. The Brute comes last.")
		if _actor.wychwood_pack_kills >= 5:
			_actor.quests.complete_objective("main_road_of_crows", "fight_ghoulkin")
			_actor.story_state.set_flag("wychwood_pack_cleared", true)
			_actor.audio.play_event("victory", 0.03)
			_actor.audio.play_music_cue("victory_return_cue")
			_actor.audio.set_music_state("return_report")
			_actor.audio.play_voice("voice_player_ghoulkin_death_01")
			_actor.hud.hide_enemy()
			_actor.hud.show_status_cue("Wychwood pack broken", "victory")
			_actor._show_current_objective_guidance(6.0)
			_actor.hud.toast("The Ghoulkin dies too far from its den. Something drew it to the road. Search the tracks.")
			_actor._make_post_ghoulkin_story_clue()
	elif enemy.enemy_id == "bog_wretch":
		_actor.quests.complete_objective("main_teeth_in_rain", "fight_bog_wretch")
		_actor.story_state.set_flag("bog_memory_core_revealed", true)
		if not bool(_actor.story_state.get_flag("bog_core_exposed", false)):
			_actor.story_state.set_flag("bog_core_forced_open", true)
		_actor._make_named_interactable("bog_core_choice", "dialogue", "Choose the memory core's fate", enemy.global_position, Color(0.35, 0.58, 0.52), Vector3(0.4, 0.4, 0.4))
		_actor.hud.show_status_cue("A memory remains", "victory")
		_actor._show_current_objective_guidance(5.0)
	elif enemy.enemy_id == "wychwood_stalker" and _actor.current_zone_id == "record_hall":
		_actor.story_state.set_flag("castle_haunting_cleared", true)
		_actor.quests.complete_objective("main_blood_under_stone", "survive_haunting")
		_actor.hud.toast("The erased names settle. Edric waits beneath the Vargan seal.")
		_actor._show_current_objective_guidance(6.0)
		_actor._load_zone("record_hall", _actor.player.global_position)
	elif enemy.enemy_id == "gravebound_knight":
		if _actor.current_zone_id == "undercroft":
			_actor.quests.complete_objective("main_last_witness", "break_halvern_guard")
		if _actor.current_zone_id == "ruins" and _actor.quests.is_unlocked("main_hart_remembers"):
			_actor._make_named_interactable("white_hart", "dialogue", "Speak to the White Hart", Vector3(12, 0, 10), Color(0.86, 0.83, 0.70), Vector3(0.36, 0.64,0.36))
	elif enemy.enemy_id == "bandit":
		if _actor.current_zone_id == "bandit_road" and bool(_actor.read_presentation_tag(enemy, "senn_guard", false)) and not _actor._has_living_enemy("bandit"):
			if not bool(_actor.story_state.get_flag("saga_senn_requires_duel", false)):
				_actor.quests.complete_objective("main_soldier_without_banner", "senn_confrontation")
				_actor.story_state.set_flag("senn_ready_to_testify", true)
			_actor.hud.show_status_cue("Senn's guard breaks", "victory")
			_actor._show_current_objective_guidance(5.5)
		elif _actor.current_zone_id == "wychwood" and _actor.quests.is_active("side_black_dog") and not _actor._has_living_enemy("bandit"):
			_actor.story_state.set_flag("black_dog_bandits_resolved", true)
			if not bool(_actor.story_state.get_flag("black_dog_any_surrender",false)):
				_actor.story_state.set_flag("black_dog_bandits_defeated", true)
			_actor._try_complete_black_dog_investigation()

	elif _actor.current_zone_id == "old_mill" and bool(_actor.read_presentation_tag(enemy, "ash_mill_enemy", false)):
		var ash_enemy_alive: Variant = false
		for candidate in _actor.active_enemies:
			if is_instance_valid(candidate) and candidate != enemy and not candidate.dead and bool(_actor.read_presentation_tag(candidate, "ash_mill_enemy", false)):
				ash_enemy_alive = true
				break
		if not ash_enemy_alive:
			_actor.quests.complete_objective("main_ash_at_the_mill", "mill_encounter")
			_actor.story_state.set_flag("ash_mill_cleared", true)
			if not _actor._has_living_enemy("ashwing") and not bool(_actor.story_state.get_flag("ashwing_defeated", false)) and _actor.enemy_defs.has("ashwing"):
				var ashwing: Variant = _actor._spawn_enemy("ashwing", Vector3(5.0, 1.0, -6.5))
				if ashwing != null:
					_actor.story_state.set_flag("ashwing_spawned", true)
					ashwing.name = "AshwingCarrionDrake"
					ashwing.leash_radius = 10.0
					_actor.hud.toast("The mill roof groans. Ashwing drops through the smoke.")
			_actor.hud.show_status_cue("The mill falls quiet", "victory")
		_actor._show_current_objective_guidance(5.5)
	if enemy.health_component != null:
		_actor.hud.show_enemy(enemy.display_name, 0.0, enemy.health_component.max_health)
	var memory_rule: Variant = str(_actor.read_presentation_tag(enemy, "memory_rule", ""))
	if memory_rule != "" and not bool(_actor.read_presentation_tag(enemy, "memory_rule_seen", false)):
		_actor.write_presentation_tag(enemy, "memory_rule_seen", true)
		_actor.hud.toast("%s slain. %s" % [enemy.display_name, memory_rule])
	else:
		_actor.hud.toast("%s slain." % enemy.display_name)
	_actor._collect_progression_rewards()
	_actor.save_manager.autosave(_actor._host)

func _try_complete_black_dog_investigation() -> void:
	if not _actor.quests.is_active("side_black_dog") or _actor.quests.is_objective_done("side_black_dog", "find_dog"):
		return
	if not bool(_actor.story_state.get_flag("black_dog_sheepfold_inspected", false)):
		return
	if not bool(_actor.story_state.get_flag("black_dog_bandit_camp_inspected", false)):
		return
	if not bool(_actor.story_state.get_flag("black_dog_bandits_defeated", false)) and not bool(_actor.story_state.get_flag("black_dog_bandits_resolved",false)):
		return
	_actor.quests.complete_objective("side_black_dog", "find_dog")
	_actor.hud.toast("The bandits held the ribbon. The black dog drove them from the children, not toward them.")
	_actor._show_current_objective_guidance(5.0)

func _try_complete_oren_thread_trace(publish_return: bool = true) -> void:
	if not _actor.quests.is_active("side_childs_charm") or _actor.quests.is_objective_done("side_childs_charm", "trace_thread"):
		return
	var found_oren: Variant = bool(_actor.story_state.get_flag("road_evidence_oren", false)) \
		or bool(_actor.story_state.get_flag("road_token_recovered", false)) \
		or bool(_actor.story_state.get_flag("oren_name_spoken", false))
	if not found_oren or not bool(_actor.story_state.get_flag("chapel_names_read", false)):
		return
	_actor.quests.complete_objective("side_childs_charm", "trace_thread")
	if publish_return and _actor.current_zone_id == "greyfen" and _actor.zone_root != null:
		load("res://scripts/zones/greyfen_section.gd").new().publish_oren_charm_return(ZoneBuildContext.new(_actor._host, "greyfen"))
	_actor.hud.toast("The red thread from Oren's token matches his erased place in the chapel.")
	_actor._show_current_objective_guidance(5.0)

func _record_encounter_knowledge(enemy: Variant) -> void:
	if _actor.story_state == null or not is_instance_valid(enemy):
		return
	var enemy_id: Variant = str(enemy.enemy_id)
	var evidence_id: Variant = "creature:" + enemy_id
	if _actor.story_state.has_evidence(evidence_id):
		return
	_actor.story_state.record_evidence(evidence_id, {
		"kind": "observed", "enemy_id": enemy_id,
		"title": str(enemy.display_name), "zone": _actor.current_zone_id,
		"source": "Encounter in " + _actor.current_zone_id.replace("_", " ").capitalize(),
		"body": "Kael has faced this foe and seen how it moves."
	})

func _record_bog_stagger(enemy: Variant, source: String) -> void:
	var count: Variant = int(_actor.story_state.get_flag("bog_stagger_hits", 0)) + 1
	_actor.story_state.set_flag("bog_stagger_hits", count)
	if count >= 2:
		_actor._expose_bog_core(enemy, source)

func _expose_bog_core(enemy: Variant, method: String) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.enemy_id != "bog_wretch":
		return
	if bool(_actor.story_state.get_flag("bog_core_exposed", false)):
		return
	_actor.story_state.set_flag("bog_core_exposed", true)
	_actor.story_state.set_flag("bog_core_exposure_method", method)
	enemy.stagger(1.15)
	_actor.hud.show_status_cue("Memory core exposed", "victory")
	_actor.hud.toast("%s tears the dead memory loose from the Wretch's hide." % method)
	_actor.audio.play_event("reveal", 0.035)

func _has_living_enemy(enemy_id: String) -> bool:
	for enemy in _actor.active_enemies:
		if is_instance_valid(enemy) and not enemy.dead and not bool(enemy.get("resolved_nonlethal")) and enemy.enemy_id == enemy_id:
			return true
	return false

func accept_ordinary_surrender(enemy: Node) -> void:
	if not is_instance_valid(enemy) or not _actor.zone_root.is_ancestor_of(enemy) or enemy.global_position.distance_to(_actor.player.global_position)>3.0:return
	if not enemy.accept_ordinary_surrender():return
	var reward_id:=str(_actor.read_presentation_tag(enemy, "progression_reward_id",""))
	_actor.story_state.set_flag("ordinary_surrender:"+_actor.current_zone_id+":"+reward_id,true)
	if _actor.current_zone_id=="wychwood":_actor.story_state.set_flag("black_dog_any_surrender",true)
	if reward_id!="":_actor.progression.award_encounter(reward_id,str(_actor.read_presentation_tag(enemy, "progression_zone",_actor.current_zone_id)),"Encounter resolved without a death")
	if _actor.current_zone_id=="wychwood" and not _actor._has_living_enemy("bandit"):
		_actor.story_state.set_flag("black_dog_bandits_resolved",true)
		_actor._try_complete_black_dog_investigation()
	_actor.hud.hide_enemy()
	_actor.hud.toast("Surrender accepted. The encounter is resolved; no death or Honor change is recorded.")
	_actor.story_save_pending=true
	_actor._host.call_deferred("_persist_story_action")

func _nearest_living_enemy(max_distance: float) -> Variant:
	var best = null
	var best_distance = max_distance
	for enemy in _actor.active_enemies:
		if not is_instance_valid(enemy) or enemy.dead or not enemy.is_encounter_active():
			continue
		var dist = enemy.global_position.distance_to(_actor.player.global_position)
		if dist < best_distance:
			best_distance = dist
			best = enemy
	return best

func _on_player_died() -> void:
	if _actor.camera_rig != null and (_actor.camera_rig != null):
		_actor.camera_rig.clear_target_lock()
	if _actor.hud != null and (_actor.hud != null):
		_actor.hud.clear_target_lock_status()
	_actor.audio.play_event("hurt")
	_actor.audio.set_game_paused(true)
	_actor._host.get_tree().paused = true
	_actor.hud.clear_journey_transients(false)
	_actor._refresh_journey_models()
	_actor.hud.show_death_screen("The road keeps its dead.\n\nChoose a recorded journey to return to its saved story state.")
