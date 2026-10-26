extends "res://scripts/systems/game_bindings.gd"
## Owns quest operations; configure() injects dependencies.
signal quest_completed(quest_id: String)

func _handle_road_of_crows_clue(area) -> void:
	if not quests.is_active("main_road_of_crows"):
		return
	match area.interaction_id:
		"corpse":
			quests.complete_evidence("main_road_of_crows", "bram")
			story_state.set_flag("road_evidence_bram", true)
		"black_feathers":
			quests.complete_evidence("main_road_of_crows", "sella")
			story_state.set_flag("road_evidence_sella", true)
		"oren_token":
			quests.complete_evidence("main_road_of_crows", "oren")
			story_state.set_flag("road_evidence_oren", true)
			if bool(story_state.get_flag("opening_coat_sheltered", false)) and not bool(story_state.get_flag("opening_coat_recalled", false)):
				story_state.set_flag("opening_coat_recalled", true)
				hud.set_guidance_hint("His coat is still on Anwen's bench. Someone mended the sleeve expecting him home.", 10.0)
			_try_complete_oren_thread_trace()
		"claw_marks":
			quests.complete_evidence("main_road_of_crows", "vargan_wire")
			story_state.set_flag("road_evidence_vargan_wire", true)
		"tracks":
			quests.complete_evidence("main_road_of_crows", "drag_marks")
			story_state.set_flag("road_evidence_drag_marks", true)
	if _road_evidence_count() >= 5 and not bool(story_state.get_flag("all_road_evidence", false)):
		story_state.set_flag("all_road_evidence", true)
		if quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
			hud.toast("Every clue agrees: the pack followed the names, not the food.")
		else:
			_make_all_evidence_safe_edge()
			hud.toast("Every clue agrees: the pack followed the names, not the food. A safer edge of the clearing reveals itself.")
			hud.set_guidance_hint("Use the marked edge when the creatures emerge.", 5.0)

func _road_evidence_count() -> int:
	var count := 0
	for evidence_id in ["bram", "sella", "oren", "vargan_wire", "drag_marks"]:
		if quests.is_objective_done("main_road_of_crows", evidence_id) or bool(story_state.get_flag("road_evidence_%s" % evidence_id, false)):
			count += 1
	return count

func _make_all_evidence_safe_edge() -> void:
	_zone_construction()._make_all_evidence_safe_edge()

func _apply_campaign_arrival(zone_id: String) -> void:
	if zone_id in ["vargan_approach", "vargan_court", "record_hall"]:
		story_state.set_flag("castle_discovered", true)
		if not quests.is_unlocked("main_blood_under_stone"):
			quests.unlocked["main_blood_under_stone"] = true
		if not quests.is_active("main_blood_under_stone") and not quests.is_completed("main_blood_under_stone"):
			quests.start_quest("main_blood_under_stone")
	var arrivals := {
		"old_mill":["main_ash_at_the_mill","reach_mill"],
		"bandit_road":["main_soldier_without_banner","reach_bandit_road"],
		"vargan_approach":["main_blood_under_stone","reach_castle"],
		"vargan_court":["main_blood_under_stone","enter_courtyard"],
		"record_hall":["main_blood_under_stone","locate_record_hall"],
		"undercroft":["main_last_witness","reach_undercroft"],
		"assembly":["main_crowns_without_mercy","greyfen_assembly"],
		"hart_glade":["main_hart_remembers","enter_glade"]
	}
	if arrivals.has(zone_id):
		quests.complete_objective(arrivals[zone_id][0], arrivals[zone_id][1])

func _road_ready_to_report() -> bool:
	var legacy_choice: bool = _legacy_report_choice_required()
	var active_route: bool = quests.is_active("main_road_of_crows") and quests.is_objective_done("main_road_of_crows", "fight_ghoulkin") and not quests.is_objective_done("main_road_of_crows", "return_village")
	return active_route or legacy_choice

func _legacy_report_choice_required() -> bool:
	return bool(story_state.get_flag("legacy_report_choice_required", false)) and str(story_state.get_flag("evidence_report", "")) == ""

func _crow_shrine_choice_ready() -> bool:
	return quests.is_active("main_bell_beneath_greyfen") \
		and quests.is_objective_done("main_bell_beneath_greyfen", "open_chapel") \
		and bool(story_state.get_flag("bell_eater_defeated", false)) \
		and not quests.is_objective_done("main_bell_beneath_greyfen", "crow_shrine_choice")

func _chapel_can_open() -> bool:
	return quests.is_active("main_bell_beneath_greyfen") \
		and quests.is_objective_done("main_bell_beneath_greyfen", "grave_truth") \
		and quests.is_objective_done("main_bell_beneath_greyfen", "cemetery_ambush")

func _ensure_cemetery_ambush() -> void:
	if not quests.is_active("main_bell_beneath_greyfen"):
		return
	if not quests.is_objective_done("main_bell_beneath_greyfen", "grave_truth"):
		return
	if quests.is_objective_done("main_bell_beneath_greyfen", "cemetery_ambush"):
		return
	for enemy in active_enemies:
		if is_instance_valid(enemy) and bool(enemy.get_meta("act_one_cemetery_ambush", false)):
			return
	var ambusher = _spawn_enemy("ghoulkin", Vector3(14.2, 0.8, 5.4))
	if ambusher != null:
		ambusher.set_meta("act_one_cemetery_ambush", true)
		hud.show_status_cue("The grave soil breaks", "hurt")
		hud.set_guidance_hint("Defeat the Ghoulkin between the graves and chapel.", 5.0)
		audio.play_event("reveal", 0.02)

func _spawn_crow_shrine_choice() -> void:
	if not _crow_shrine_choice_ready() or zone_root == null:
		return
	if zone_root.find_child("crow_shrine_choice", true, false) != null:
		return
	_make_named_interactable("crow_shrine_choice", "dialogue", "Choose the Crow Shrine's fate", CemeterySection.CROW_SHRINE_INTERACTION_STAGE, Color(0.3,0.38,0.3), Vector3(0.45,0.45,0.45))

func _restore_greyfen_cemetery_state() -> void:
	if _boss_is_resolved("bell_eater"):
		_retire_bell_eater()
	if not quests.is_active("main_bell_beneath_greyfen"):
		return
	_relocate_anwen_to_cemetery()
	if _crow_shrine_choice_ready():
		_spawn_crow_shrine_choice()
	elif bool(story_state.get_flag("crow_chapel_opened", false)):
		_ensure_bell_eater()
	else:
		_ensure_cemetery_ambush()

func _relocate_anwen_to_cemetery() -> void:
	if zone_root == null:
		return
	var anwen = zone_root.find_child("sister_anwen", true, false)
	if anwen == null:
		return
	var requested_position: Vector3 = CemeterySection.ANWEN_CEMETERY_STAGE
	var safe_position: Vector3 = Vector3(spatial_service.validate_position(requested_position, 0.85, spatial_service.bank_for(requested_position)))
	# This is an authored flat cemetery stage. A generic downward ray can hit
	# the nearby wall/roof collision and float Anwen above the graves.
	safe_position.y = 0.0
	anwen.global_position = safe_position + Vector3.UP * 0.02
	anwen.set("prompt", "Meet Sister Anwen at the cemetery gate")
	_face_npc_toward_player(anwen)

func _quest_required_objectives_done(quest_id: String) -> bool:
	var definition: Dictionary = quests.quest_defs.get(quest_id, {})
	for raw_objective in definition.get("objectives", []):
		if bool(raw_objective.get("optional", false)):
			continue
		if not quests.is_objective_done(quest_id, str(raw_objective.get("id", ""))):
			return false
	return true

func _story_choice_prerequisites_done(quest_id: String, choice_id: String) -> bool:
	var definition: Dictionary = quests.quest_defs.get(quest_id, {})
	var found_choice := false
	for raw_objective in definition.get("objectives", []):
		var objective_id := str(raw_objective.get("id", ""))
		if objective_id == choice_id:
			found_choice = true
			break
		if bool(raw_objective.get("optional", false)):
			continue
		if not quests.is_objective_done(quest_id, objective_id):
			return false
	return found_choice

func _complete_ending(ending: String) -> bool:
	var ending_id := str(ending)
	if ending_id not in ["expose", "free", "bind", "kill"]:
		hud.toast("The covenant offers no such answer.")
		return false
	if str(story_state.get_flag("final_covenant", "")) != "" or bool(story_state.get_flag("final_choice_completed", false)):
		hud.toast("The covenant has already been chosen.")
		return false
	if not quests.is_active("main_hart_remembers") or str(story_state.get_flag("confession_method", "")) == "":
		hud.toast("The Hart will not answer until Greyfen has heard the testimony.")
		return false
	# Preserve the last freely revisitable moment in its own slot.
	save_manager.save_game(_host, save_manager.PRE_COVENANT_PATH, "The moment before the covenant has been saved.")
	var witnesses: Array[String] = ["kael"]
	for witness in ["anwen", "rook", "mira", "edric", "halvern", "senn"]:
		if str(story_state.get_flag("witness_consent_" + witness, "")) == "voluntary":
			witnesses.append(witness)
	story_state.set_flag("final_witnesses", witnesses)
	story_state.set_flag("final_covenant", {"expose":"witness", "free":"mercy", "bind":"duty", "kill":"ash"}[ending_id])
	quests.world_flags["ending"] = ending_id
	quests.complete_objective("main_hart_remembers", "hear_testimony")
	if ending_id != "kill":
		CovenantResolution.begin(_host, ending_id)
		return true
	pending_ending = ending_id
	story_state.set_flag("human_records_preserved", true)
	active_interactable = null
	hud.set_prompt("")
	hud.hide_menus()
	_host.get_tree().paused = false
	audio.set_game_paused(false)
	_remove_interactable("white_hart")
	if zone_root != null and is_instance_valid(zone_root):
		var witness_display := zone_root.find_child("WhiteHartWitnessDisplay", true, false)
		if witness_display != null:
			witness_display.queue_free()
	if not _has_living_enemy("white_hart_avatar"):
		var hart_boss = _spawn_enemy("white_hart_avatar", Vector3(0, 0.8, -7))
		if hart_boss != null:
			hart_boss.name = "WhiteHartFinalEncounter"
			hart_boss.leash_radius = 10.0
	audio.play_event("boss", 0.02)
	hud.toast("The human record is safe. The Hart rises to defend the covenant.")
	return true

func _show_ending_consequence(ending: String) -> void:
	if bool(story_state.get_flag("final_choice_completed", false)):
		return
	story_action_in_progress = true
	story_state.begin_change()
	quests.begin_change()
	quests.world_flags["ending"] = ending
	story_state.set_flag("final_choice_completed", true)
	story_state.set_flag("covenant_ritual_ready", false)
	story_state.set_flag("renewal_stopped", true)
	pending_ending = ""
	quests.complete_choice("main_hart_remembers", "final_choice")
	var cards: Array[String] = EpilogueResolver.resolve(ending, story_state)
	story_state.set_flag("epilogue_cards", cards)
	quests.end_change()
	story_state.end_change()
	story_action_in_progress = false
	StoryWorldDirector.refresh(_host)
	audio.set_story_context(story_state, current_zone_id)
	audio.set_game_paused(true)
	_host.get_tree().paused = true
	hud.show_ending("The covenant is made", "The Hart has answered. The road behind you leads to Greyfen.\n\nReturn to the people who must live with this decision. There is still work to do, and lives to hear before this account is closed.")
	story_save_pending = true
	_host.call_deferred("_persist_story_action")

func _show_completed_epilogue() -> void:
	if not bool(story_state.get_flag("final_choice_completed", false)):
		return
	var ending := str(quests.world_flags.get("ending", "expose"))
	var cards: Array[String] = EpilogueResolver.resolve(ending, story_state)
	story_state.set_flag("epilogue_cards", cards)
	story_state.set_flag("epilogue_presented", true)
	audio.set_dialogue_active(false)
	audio.set_game_paused(true)
	_host.get_tree().paused = true
	hud.show_ending("The lives that continue", "\n\n".join(cards))
	story_save_pending = true
	_host.call_deferred("_persist_story_action")

func _on_quest_completed(id: String) -> void:
	if id == "main_bell_beneath_greyfen":
		story_state.set_flag("teeth_in_rain_available", true)
	if id == "main_teeth_in_rain":
		story_state.set_flag("teeth_in_rain_completed", true)
		story_state.set_flag("deep_wychwood_passage", true)
	if id == "main_blood_under_stone":
		story_state.set_flag("blood_under_stone_completed", true)
	var reward = quests.quest_defs.get(id, {}).get("rewards", {})
	progression.award_for_quest(id, str(quests.quest_defs.get(id, {}).get("type", "")))
	if not reward.is_empty():
		inventory.add_reward(reward)
		hud.toast("Reward received for %s." % quests.quest_defs.get(id, {}).get("title", id))
	if not story_action_in_progress:
		story_save_pending = true
		_host.call_deferred("_persist_story_action")
	quest_completed.emit(id)

func _apply_progression_to_player() -> void:
	if player != null and progression != null:
		player.set_progression(progression)

func _on_progression_changed() -> void:
	if hud != null and progression != null:
		hud.update_progression(progression.progress_model())

func _queue_progression_rewards() -> void:
	if progression_refresh_pending or not game_started or resource_shutdown_prepared:
		return
	progression_refresh_pending = true
	_host.call_deferred("_flush_progression_rewards")

func _flush_progression_rewards() -> void:
	progression_refresh_pending = false
	if not game_started or resource_shutdown_prepared or _journey_load_pending() or zone_transition_pending or zone_load_request_pending:
		return
	if _collect_progression_rewards():
		story_save_pending = true
		_host.call_deferred("_persist_story_action")

func _collect_progression_rewards() -> bool:
	if progression == null or quests == null or story_state == null or not game_started:
		return false
	var before: int = progression.claimed_rewards.size()
	progression.sync_story(quests, story_state, current_zone_id)
	return progression.claimed_rewards.size() != before

func _on_progression_arrival(zone_id: String) -> void:
	if not game_started or progression == null or resource_shutdown_prepared:
		return
	progression.record_arrival(zone_id, quests, story_state, _journey_load_pending())
	_queue_progression_rewards()
