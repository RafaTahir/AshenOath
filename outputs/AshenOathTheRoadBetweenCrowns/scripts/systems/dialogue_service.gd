extends "res://scripts/systems/game_bindings.gd"
## Owns dialogue operations; configure() injects dependencies.
signal dialogue_action_completed(action: Dictionary)

func _handle_dialogue_action(action: Dictionary) -> void:
	if str(action.get("type", "")) == "greyfen_detail_action":
		preload("res://scripts/greyfen_village_details.gd").choose(_host, action)
		return
	if str(action.get("type", "")) == "saga_action":
		var owner: Node = zone_root.get_node_or_null("StoryActivities/SixWorldStories") if is_instance_valid(zone_root) else null
		if owner != null:
			owner.choose(action)
		return
	if str(action.get("type", "")) == "gathering_choice":
		preload("res://scripts/greyfen_gathering.gd").choose(_host, action)
		return
	if str(action.get("type", "")) == "field_trial":
		preload("res://scripts/bracken_field_trial.gd").choose(_host, action)
		return
	if str(action.get("type", "")) == "range_choice":
		preload("res://scripts/greyfen_archery_range.gd").choose(_host, action)
		return
	if str(action.get("type", "")) == "living_road_scene":
		preload("res://scripts/story_activity_director.gd").personal_scene(_host, action)
		return
	if str(action.get("type", "")) == "friend_scene":
		preload("res://scripts/story_activity_director.gd").friend_scene(_host, action)
		return
	if str(action.get("type", "")) == "rest_place":
		preload("res://scripts/story_activity_director.gd").rest_action(_host, action)
		return
	if str(action.get("type", "")) == "companion_menu":
		_show_companion_commands()
		return
	if str(action.get("type", "")) == "companion_command":
		if not preload("res://scripts/companion_controller.gd").issue_command(_host, str(action.get("command", ""))):
			hud.toast("Bracken cannot take that command during this journey handoff.")
		_resume_game()
		return
	if str(action.get("type", "")) == "story_travel":
		preload("res://scripts/story_activity_director.gd").travel(_host, action)
		return
	if not _dialogue_action_available(action):
		_apply_dialogue_action(action)
		return
	if str(action.get("type", "")) == "story_choice":
		var choice_id := str(action.get("choice_id", "%s:%s" % [action.get("quest", ""), action.get("objective", "")]))
		if choice_id == ":":
			var effect_keys: Array = action.get("sets_flags", {}).keys()
			effect_keys.sort()
			choice_id = "promise:" + ",".join(effect_keys)
		save_manager.predecision(_host, choice_id)
	var transaction = StoryDecisionCoordinator.new()
	transaction.begin(_host)
	var applied: bool = _apply_dialogue_action(action)
	transaction.finish(_host, action, applied)
	var blocking: bool = hud._gameplay_surface_blocked() or _journey_load_pending()
	_host.get_tree().paused = blocking
	audio.set_game_paused(blocking)

func _finish_story_action(action: Dictionary) -> void:
	if not game_started or resource_shutdown_prepared:
		return
	if action.get("sets_flags", {}).has("evidence_report"):
		story_state.set_flag("cemetery_bell_rung", true)
		story_state.set_flag("legacy_report_choice_required", false)
		_relocate_anwen_to_cemetery()
	if action.get("sets_flags", {}).has("mira_truth"):
		story_state.set_flag("mira_truth_known", true)
	if action.get("sets_flags", {}).has("confession_method"):
		story_state.set_flag("renewal_stopped", true)
	StoryWorldDirector.refresh(_host)
	_refresh_tracker()
	if str(action.get("type", "")) in ["story_choice", "resolve_side_quest", "ending"]:
		var receipt: Dictionary = preload("res://scripts/story_choice_presenter.gd").receipt(action, story_state, quests, current_zone_id)
		if not receipt.is_empty():
			hud.show_decision_result(receipt)
	if audio != null and not _story_has_active_combat():
		audio.set_story_context(story_state, current_zone_id)
	story_save_pending = true
	_host.call_deferred("_persist_story_action")
	dialogue_action_completed.emit(action)

func _persist_story_action() -> void:
	if not story_save_pending or resource_shutdown_prepared or not game_started:
		return
	if _journey_load_pending():
		return
	if zone_transition_pending or zone_load_request_pending or not pending_player_restore.is_empty():
		return
	if is_instance_valid(zone_root) and bool(zone_root.get_meta("arrival_support_pending", false)):
		return
	_collect_progression_rewards()
	story_save_pending = false
	save_manager.checkpoint(_host)
	save_manager.autosave(_host)

func _story_has_active_combat() -> bool:
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.dead and player != null and enemy.is_encounter_active() and not bool(enemy.get_meta("dormant_arena", false)):
			if enemy.global_position.distance_squared_to(player.global_position) < 100.0:
				return true
	return false

func _apply_dialogue_action(action: Dictionary) -> bool:
	if not _dialogue_action_available(action):
		hud.toast(_dialogue_action_unavailable_reason(action))
		return false
	# Keep combat frozen until the complete choice transaction has published.
	_host.get_tree().paused = true
	if hud != null:
		hud.hide_menus()
	audio.stop_voice()
	audio.play_event("ui")
	var type = str(action.get("type", ""))
	if type == "greyfen_restore_choice":
		if not story_state.confirm_greyfen_choice(str(action.get("key", "")), str(action.get("value", ""))):
			return false
	elif type == "opening_care_account":
		var opening_anwen := zone_root.find_child("sister_anwen", true, false) as Node3D
		if current_zone_id == "greyfen" and opening_anwen != null:
			story_state.set_flag("opening_care_introduced", true)
			_host.call_deferred("_handle_interaction", opening_anwen)
	elif type == "opening_care_resume":
		var care_hint := "Oren's coat is on the bench. Anwen can tell you about the road whenever you are ready." if bool(story_state.get_flag("opening_cup_delivered", false)) else "The cup is on the low step. Anwen can tell you about the road whenever you are ready."
		hud.set_guidance_hint(care_hint, 8.0)
	elif type == "companion_choice":
		if not preload("res://scripts/companion_controller.gd").apply_choice(_host, action):
			return false
	elif type == "start_quest":
		quests.start_quest(action.get("quest", ""))
		if str(action.get("quest", "")) == "side_childs_charm":
			_try_complete_oren_thread_trace(false)
		if action.get("quest", "") == "main_road_of_crows":
			audio.play_voice("voice_player_accept_contract_01")
	elif type == "complete_objective":
		quests.complete_objective(action.get("quest", ""), action.get("objective", ""))
		for id in action.get("sets_flags", {}):
			story_state.set_flag(str(id), action["sets_flags"][id])
		if str(action.get("quest", "")) == "main_teeth_in_rain" and str(action.get("objective", "")) == "speak_mira" and current_zone_id == "greyfen":
			if not _has_interactable("chapel_names"):
				_make_clue("chapel_names", "Read the erased names in the chapel", Vector3(15.0,0,8.2), "main_teeth_in_rain", "read_chapel_names", Color(0.44,0.39,0.31))
		if action.get("quest", "") == "main_road_of_crows" and action.get("objective", "") == "speak_anwen":
			hud.show_status_cue("Road of Crows updated", "item")
			_show_current_objective_guidance(6.0)
	elif type == "give_ingredients":
		inventory.add_ingredients(action.get("items", {}))
		for id in action.get("sets_flags", {}):
			story_state.set_flag(str(id), action["sets_flags"][id])
		hud.toast("Supplies added.")
	elif type == "resolve_side_quest":
		var side_id := str(action.get("quest", ""))
		if quests.is_active(side_id):
			for objective in quests.active[side_id]["objectives"].duplicate(true):
				quests.complete_objective(side_id, str(objective["id"]))
			story_state.set_flag("%s_outcome" % side_id, str(action.get("outcome", "resolved")))
		else:
			return false
	elif type == "story_choice":
		if not story_state.commitment_allows(action):
			hud.toast("That promise cannot be made while another commitment stands. Speak honestly with the person it concerns.")
			return false
		if action.get("sets_flags", {}).has("crow_shrine_state") and str(story_state.get_flag("crow_shrine_state", "")) != "":
			hud.toast("The Crow Shrine has already answered Kael's choice.")
			return false
		if action.get("sets_flags", {}).has("bog_core_fate") and str(story_state.get_flag("bog_core_fate", "")) != "":
			hud.toast("The memory core has already been given a fate.")
			return false
		# Every consequential story choice is one-shot. The flag guard above
		# covers legacy one-off choices with custom wording; the objective guard
		# keeps names, mill, testimony, ledger, and ending decisions from being
		# replayed through a stale dialogue node or a saved interaction prompt.
		var choice_quest_id := str(action.get("quest", ""))
		var choice_objective_id := str(action.get("objective", ""))
		if choice_quest_id != "" and choice_objective_id != "" and quests.is_objective_done(choice_quest_id, choice_objective_id) and not (choice_quest_id == "main_road_of_crows" and _legacy_report_choice_required()):
			hud.toast("That decision has already been made.")
			return false
		if not story_state.apply_commitment(action):
			return false
		for id in action.get("sets_flags", {}):
			story_state.set_flag(str(id), action["sets_flags"][id])
		for id in action.get("adjusts_values", {}):
			story_state.adjust_value(str(id), int(action["adjusts_values"][id]))
		if action.has("quest") and action.has("objective"):
			quests.complete_choice(str(action["quest"]), str(action["objective"]))
		for completion in action.get("completes", []):
			quests.complete_choice(str(completion.get("quest", "")), str(completion.get("objective", "")))
		for item_id in action.get("gives_items", {}):
			inventory.add_item(str(item_id), int(action["gives_items"][item_id]))
		if action.get("sets_flags", {}).has("crow_shrine_state"):
			hud.show_status_cue("The covenant changes", "victory")
			_show_current_objective_guidance(6.0)
			if active_interactable != null and str(active_interactable.get("interaction_id")) == "crow_shrine_choice":
				_mark_interaction_removed(active_interactable)
				active_interactable.queue_free()
				active_interactable = null
		elif action.get("sets_flags", {}).has("bog_core_fate"):
			hud.show_status_cue("Memory given a fate", "victory")
			_show_current_objective_guidance(6.0)
			if active_interactable != null and str(active_interactable.get("interaction_id")) == "bog_core_choice":
				_mark_interaction_removed(active_interactable)
				active_interactable.queue_free()
				active_interactable = null
		elif action.get("sets_flags", {}).has("names_policy"):
			hud.show_status_cue("The names have a new public life", "victory")
			_show_current_objective_guidance(6.0)
			_consume_story_choice_interactable("names_decision")
		elif action.get("sets_flags", {}).has("mill_fate"):
			hud.show_status_cue("The mill's record is settled", "victory")
			_show_current_objective_guidance(6.0)
			_consume_story_choice_interactable("miller_record")
		elif action.get("sets_flags", {}).has("senn_fate"):
			if not StoryActorPresence.remains("captain_senn", str(story_state.get_flag("senn_fate", ""))):
				_consume_story_choice_interactable("captain_senn")
		elif action.get("sets_flags", {}).has("confession_method") and current_zone_id == "assembly":
			if not _has_interactable("gate_greyfen"):
				_make_zone_gate("Return to Greyfen and take the southern Hart road", Vector3(7, 0, -14), "greyfen", Vector3(0, 0.95, 11))
			_show_current_objective_guidance(6.0)
		if action.get("sets_flags", {}).has("halvern_fate"):
			var halvern_outcome := str(action["sets_flags"]["halvern_fate"])
			_publish_halvern_exit()
			for boss in active_enemies:
				if not is_instance_valid(boss) or boss.enemy_id != "halvern_boss":
					continue
				var controller: Node = boss.get_node_or_null("BossEncounterController")
				if controller != null and controller.has_method("resolve_peaceful"):
					controller.resolve_peaceful(halvern_outcome)
				break
			if not StoryActorPresence.remains("halvern", halvern_outcome):
				_consume_story_choice_interactable("halvern")
		if str(action.get("quest", "")) == "main_blood_under_stone" and str(action.get("objective", "")) == "ledger_choice":
			story_state.set_flag("vargan_ledger_found", true)
			story_state.set_flag("vargan_ledger_choice_made", true)
			story_state.set_flag("record_hall_unlocked", true)
			_show_current_objective_guidance(5.0)
	elif type == "ending":
		return _complete_ending(action.get("ending", "expose"))
	else:
		return false
	if audio != null:
		audio.set_game_paused(false)
	_host.get_tree().paused = false
	hud.hide_menus()
	_refresh_tracker()
	# Dialogue choices usually mutate state that is already reflected in-place.
	# Rebuilding the same zone for those actions creates an avoidable Web
	# lifecycle handoff and can leave control pending while the retired root is
	# still being collected. Only quest starts and objective completions that can
	# add gated world content need a composition rebuild.
	var refresh_zone_after_action := _dialogue_action_requires_zone_rebuild(action)
	if refresh_zone_after_action and current_zone_id != "":
		_load_zone(current_zone_id, player.global_position)
	return true

func _dialogue_action_requires_zone_rebuild(action: Dictionary) -> bool:
	var action_type := str(action.get("type", ""))
	if action_type == "story_choice":
		# The ledger decision changes the active Record Hall composition: the
		# haunting and its post-choice handoff are authored by the zone builder.
		# Rebuild this one stateful choice so the new encounter appears without
		# requiring the player to leave and re-enter the hall.
		return str(action.get("quest", "")) == "main_blood_under_stone" \
			and str(action.get("objective", "")) == "ledger_choice"
	if action_type in ["give_ingredients", "resolve_side_quest"]:
		return false
	if action_type == "complete_objective":
		# These two opening interactions update their visible state directly.
		# Rebuilding them would retire the active Greyfen root for no spatial gain.
		var quest_id := str(action.get("quest", ""))
		var objective_id := str(action.get("objective", ""))
		if quest_id == "main_road_of_crows" and objective_id == "speak_anwen":
			return false
		if quest_id == "main_teeth_in_rain" and objective_id == "speak_mira":
			return false
		return true
	return action_type == "start_quest"

func _dialogue_action_available(action: Dictionary) -> bool:
	if action.get("sets_flags", {}).has("crow_shrine_state") and not bool(story_state.get_flag("bell_eater_defeated", false)):
		return false
	if action.get("sets_flags", {}).has("halvern_fate"):
		var yielding := bool(story_state.get_flag("halvern_guard_broken", false)) or bool(story_state.get_flag("command_proof_recovered", false)) or bool(story_state.get_flag("halvern_surrender_protected", false)) or str(story_state.get_flag("halvern_fate", "")) == "defeated"
		if not yielding:
			return false
	if not dialogue._conditions_match(action.get("conditions", {})):
		return false
	var type := str(action.get("type", ""))
	var quest_id := str(action.get("quest", ""))
	var objective_id := str(action.get("objective", ""))
	if type == "greyfen_restore_choice":
		var key := str(action.get("key", ""))
		var resolved: bool = quests.is_completed("side_iron_remembers") if key == "iron_fate" else quests.is_completed("main_road_of_crows") or quests.is_objective_done("main_road_of_crows", "return_village")
		return current_zone_id == "greyfen" and resolved and bool(story_state.get_flag(key + "_confirmation_needed", false))
	if type == "companion_choice":
		return preload("res://scripts/companion_controller.gd").choice_available(_host, action)
	if type == "start_quest":
		return quest_id != "" and quests.is_unlocked(quest_id) and not quests.is_active(quest_id) and not quests.is_completed(quest_id)
	if type == "complete_objective":
		if quest_id == "side_iron_remembers" and objective_id == "recover_iron" and not story_state.has_evidence("massacre_iron"):
			return false
		return quest_id != "" and objective_id != "" and quests.is_active(quest_id) and not quests.is_objective_done(quest_id, objective_id)
	if type == "resolve_side_quest":
		return quest_id != "" and quests.is_active(quest_id) and _quest_required_objectives_done(quest_id)
	if type == "story_choice" and quest_id != "" and objective_id != "":
		if quest_id == "main_road_of_crows" and objective_id == "return_village" and _legacy_report_choice_required():
			return true
		if not quests.is_active(quest_id) or quests.is_objective_done(quest_id, objective_id):
			return false
		return _story_choice_prerequisites_done(quest_id, objective_id)
	return true

func _dialogue_action_unavailable_reason(action: Dictionary) -> String:
	if action.get("sets_flags", {}).has("crow_shrine_state"):
		return "Defeat the Bell-Eater before deciding the shrine's fate."
	if str(action.get("quest", "")) == "main_soldier_without_banner" and str(action.get("objective", "")) == "senn_choice":
		return "First settle the checkpoint guards, by combat or their earned surrender."
	if str(action.get("quest", "")) == "main_ash_at_the_mill" and not bool(story_state.get_flag("ashwing_defeated", false)):
		return "Defeat Ashwing before settling the mill's surviving records."
	return "Complete the current step before making this choice."

func _on_dialogue_closed_audio() -> void:
	# First encounters are collected as their pages are read. Persist them when
	# the reading surface closes, keeping disk writes out of voice/page handoff.
	_host.call_deferred("_persist_story_action")
	if bool(story_state.get_flag("aftermath_epilogue_pending", false)):
		story_state.set_flag("aftermath_epilogue_pending", false)
		_host.call_deferred("_show_completed_epilogue")
	if audio != null:
		audio.set_game_paused(false)
	interaction_focus_dirty = true
	interaction_focus_cache_valid = false
	_host.call_deferred("_finish_covenant_if_ready")

func _finish_covenant_if_ready() -> void:
	CovenantResolution.finish_if_ready(_host)
	if bool(story_state.get_flag("aftermath_epilogue_pending", false)):
		story_state.set_flag("aftermath_epilogue_pending", false)
		_host.call_deferred("_show_completed_epilogue")
	_publish_journey_arrival()

func _prepare_dialogue_presence(content: Dictionary) -> Dictionary:
	var result: Dictionary = content.duplicate(true)
	var aliases := {"anwen":"sister_anwen", "senn":"captain_senn", "tor":"blacksmith_tor", "elna":"widow_elna", "edric":"edric_campaign", "record_keeper_vale":"vargan_record_keeper", "vale":"vargan_record_keeper", "guard":"vargan_gate_guard"}
	for page: Dictionary in result.get("pages", []):
		var id := str(page.get("speaker_id", "narrator"))
		if id in ["player", "kael", "narrator", ""]:
			continue
		var supplied := instance_from_id(int(page.get("speaker_actor_id", 0))) as Node3D
		var actor: Node3D = supplied if is_instance_valid(supplied) and is_instance_valid(zone_root) and zone_root.is_ancestor_of(supplied) else null
		if actor == null:
			actor = zone_root.find_child(str(aliases.get(id, id)), true, false) as Node3D if zone_root != null else null
		if actor == null and zone_root != null and id == "edric":
			actor = zone_root.find_child("edric_castle", true, false) as Node3D
		if actor == null and zone_root != null:
			var witness: String = {"mira":"witness_-7", "rook":"witness_-3", "anwen":"witness_3"}.get(id, "")
			if witness != "":
				actor = zone_root.find_child(witness, true, false) as Node3D
		if actor != null and actor.is_visible_in_tree() and (player == null or actor.global_position.distance_to(player.global_position) <= 12.0):
			page["speaker_actor_id"] = actor.get_instance_id()
		else:
			page["speaker"] = str(page.get("speaker", id.capitalize())) + " - recorded account"
			page["speaker_id"] = "narrator"
			page["voice"] = ""
	return result

func _stage_dialogue_moment(area) -> void:
	if not (area is Node3D):
		return
	dialogue_runtime_coordinator.stage(area, player, camera_rig, Callable(_host, "validate_walkable_position"))

func _on_dialogue_page_changed(_speaker: String, _speaker_id: String, _page_index: int, _total_pages: int) -> void:
	var page: Dictionary = hud.get_current_dialogue_page()
	var read_only: bool = bool(page.get("read_only", false))
	# Optional questions enter the existing reading history, without registering
	# new story evidence or changing a person's commitments. Persist on close.
	if read_only:
		story_save_pending = true
	var encounter: Dictionary = {} if read_only else preload("res://scripts/story_journal.gd").encounter_record(_speaker_id, current_zone_id)
	if not encounter.is_empty():
		var encounter_id: String = str(encounter.get("id", ""))
		if encounter_id != "" and not story_state.has_evidence(encounter_id):
			# Record only the speaker whose words are currently displayed. Later
			# participants remain undiscovered until their own page is reached.
			story_state.record_evidence(encounter_id, encounter.get("entry", {}))
			story_save_pending = true
	dialogue_runtime_coordinator.refresh_page(player, camera_rig, page)
	if audio != null:
		audio.set_dialogue_active(true)
		audio.play_dialogue_page(page)
	preload("res://scripts/story_performance.gd").page(dialogue_runtime_coordinator.get_page_actor(), page, audio)

func _on_dialogue_topic_requested(context_id: String, topic_id: String, revision_key: String) -> void:
	# A reading request never re-enters interaction or action dispatch. Resolve
	# against the still-present speaker and current knowledge at selection time.
	var context: Dictionary = dialogue_runtime_coordinator.get_topic_context(context_id)
	if resource_shutdown_prepared or _journey_load_pending() or context.is_empty() or str(context.get("zone_id", "")) != current_zone_id:
		hud.dialogue_topic_unavailable(context_id)
		return
	var topic: Dictionary = dialogue.get_conversation_topic(topic_id, str(context.get("actor_id", "")), current_zone_id, revision_key)
	if topic.is_empty():
		hud.dialogue_topic_unavailable(context_id)
		return
	topic["topic_context_id"] = context_id
	hud.show_dialogue_topic(topic)

func _face_npc_toward_player(npc: Node3D) -> void:
	dialogue_runtime_coordinator.face_actor(npc, player)

func _release_dialogue_facing() -> void:
	audio.stop_voice()
	audio.set_dialogue_active(false)
	preload("res://scripts/story_performance.gd").finish(dialogue_runtime_coordinator.get_focus_actor())
	interaction_input_block_until_usec = Time.get_ticks_usec() + int(DIALOGUE_INTERACTION_GUARD_SECONDS * 1000000.0)
	dialogue_runtime_coordinator.release(player)
	if zone_root == null:
		return
	if pending_anwen_relocation:
		pending_anwen_relocation = false
		_relocate_anwen_to_cemetery()
