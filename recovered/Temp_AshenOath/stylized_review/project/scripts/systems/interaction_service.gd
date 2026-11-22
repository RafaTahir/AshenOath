extends "res://scripts/systems/game_bindings.gd"
## Owns interaction operations; configure() injects dependencies.
signal interaction_focus_updated(target: Node)

func _handle_interaction(area) -> void:
	if current_zone_id == "greyfen" and area != null:
		preload("res://scripts/greyfen_guidance.gd").learn(_host, "use")
	if area != null and area.interaction_id == "bracken" and str(story_state.get_flag("bracken_home", "")) == "adopted":
		_show_companion_commands()
		return
	if area != null and area.interaction_type == "encounter" and area.interaction_id == "rootbound_challenge":
		_open_rootbound_encounter()
		return
	if area != null and area.interaction_type == "story_activity":
		preload("res://scripts/story_activity_director.gd").handle(_host, area)
		return
	var prop_activated := false
	if world_props != null and area != null and area.has_meta("world_prop_id"):
		prop_activated = world_props.activate_prop(str(area.get_meta("world_prop_id", "")))
	var world_prop_component := area.find_child("InteractiveWorldProp", true, false) as InteractiveWorldProp if area != null else null
	if world_prop_component != null and not prop_activated:
		world_prop_component.activate()
	if world_vfx != null and is_instance_valid(world_vfx) and area is Node3D:
		world_vfx.pulse_interaction((area as Node3D).global_position)
	if area.interaction_type == "covenant":
		CovenantResolution.activate(_host, area)
		return
	if area.interaction_type == "minigame":
		var village: Node = preload("res://scripts/greyfen_village_details.gd").current(_host)
		if village != null and village.open_table(area): return
		minigames.open_game("tic_tac_toe" if area.interaction_id == "common_table" else "draughts", "rook" if area.interaction_id == "common_table" else "blacksmith_tor")
	elif area.interaction_type == "vendor":
		if vendor_service == null:
			hud.toast("The shop is not available right now.")
			return
		audio.set_game_paused(true)
		_host.get_tree().paused = true
		_update_preparation_context()
		hud.show_vendor(area.interaction_id, vendor_service, inventory, quests, story_state)
	elif area.interaction_type == "village_place":
		_handle_village_place(area.interaction_id)
	elif area.interaction_type == "dialogue":
		if area.interaction_id == "sister_anwen" and preload("res://scripts/opening_care_scene.gd").introduce(_host, area):
			return
		if area.interaction_id == "vargan_ledger_choice":
			audio.play_event("record_page", 0.02)
			quests.complete_evidence("main_blood_under_stone", "evidence_ledger_fragment")
			quests.complete_objective("main_blood_under_stone", "recover_ledger")
		var dialogue_data = dialogue.get_dialogue(area.dialogue_id)
		if area.interaction_id == "vargan_steward" and not bool(story_state.get_flag("castle_access_granted", false)):
			# Intake now belongs to Merrow. Keep the original quest action and
			# save keys so a legacy journey can still earn its gate audience.
			var intake: Dictionary = dialogue.get_dialogue("vargan_gate_guard")
			for intake_action: Dictionary in intake.get("actions", []):
				dialogue_data.get_or_add("actions", []).append(intake_action.duplicate(true))
		if area.interaction_id == "bracken":
			for companion_action: Dictionary in dialogue_data.get("actions", []):
				companion_action["companion_actor_instance"] = area.get_instance_id()
		var report_chosen := false
		if _road_ready_to_report() and area.interaction_id in ["sister_anwen", "notice_board", "retain_evidence"]:
			report_chosen = true
			dialogue_data = dialogue.get_dialogue("report_decision")
		if area.interaction_id == "sister_anwen" and not quests.is_completed("main_road_of_crows") and not bool(tutorial_flags.get("anwen_talked", false)):
			tutorial_flags["anwen_talked"] = true
			quests.complete_objective("main_road_of_crows", "speak_anwen")
		elif area.interaction_id == "sister_anwen" and not report_chosen and quests.is_active("main_bell_beneath_greyfen"):
			quests.complete_objective("main_bell_beneath_greyfen", "meet_anwen_gate")
			story_state.set_flag("bell_gate_met", true)
			dialogue_data = dialogue.get_dialogue(area.dialogue_id)
			audio.set_music_state("shrine_anwen")
			hud.toast("The cut bell rope runs beneath the graves. Anwen waits for proof.")
			_show_current_objective_guidance(6.0)
		if report_chosen and area.interaction_id == "sister_anwen":
			audio.play_event("return_report", 0.02)
			audio.set_music_state("return_report")
			hud.show_status_cue("Bring back the road's account", "item")
		_set_interactable_label_visible(area, false)
		if not report_chosen:
			preload("res://scripts/story_activity_director.gd").add_friend_invitation(_host, area, dialogue_data)
			preload("res://scripts/story_activity_director.gd").add_personal_invitation(_host, area, dialogue_data)
			var regional: Node = zone_root.get_node_or_null("StoryActivities/SixWorldStories")
			if regional != null:
				regional.append_cast_topics(area, dialogue_data)
		for option: Dictionary in dialogue_data.get("actions", []):
			if not _dialogue_action_available(option):
				option["available"] = false
				option["unavailable_reason"] = _dialogue_action_unavailable_reason(option)
		_stage_dialogue_moment(area)
		var topic_context_id: String = dialogue_runtime_coordinator.bind_topic_context(str(area.interaction_id), current_zone_id)
		if not topic_context_id.is_empty():
			dialogue_data["topic_context_id"] = topic_context_id
			dialogue_data["optional_topics"] = dialogue.get_conversation_topics(str(area.interaction_id), current_zone_id, hud.get_dialogue_topic_seen_keys())
		preload("res://scripts/story_performance.gd").begin(area, player, dialogue_data, story_state)
		audio.set_dialogue_active(true)
		audio.set_game_paused(true)
		_host.get_tree().paused = true
		var introduction_key := preload("res://scripts/story_cast_profile.gd").introduce(_host, str(area.interaction_id), dialogue_data)
		hud.show_dialogue(_prepare_dialogue_presence(dialogue_data))
		preload("res://scripts/story_cast_profile.gd").remember_introduction(_host, introduction_key)
		# The displayed page owns its exact-text recording. A legacy scene-wide
		# sequence here would cancel that page and could speak a different turn.
	elif area.interaction_type == "clue":
		if area.interaction_id == "chapel_door" and not _chapel_can_open():
			if not quests.is_objective_done("main_bell_beneath_greyfen", "grave_truth"):
				hud.toast("The chapel seal has no keyhole. The disturbed graves must explain the bell.")
			else:
				hud.toast("Something moves beneath the grave soil. The chapel will not open while it remains.")
			hud.set_guidance_hint("Finish the cemetery investigation before opening the chapel.", 5.0)
			return
		if area.quest_id == "main_road_of_crows":
			_handle_road_of_crows_clue(area)
		elif area.interaction_id in ["sheepfold", "bandit_camp"]:
			story_state.set_flag("black_dog_%s_inspected" % area.interaction_id, true)
			_try_complete_black_dog_investigation()
		elif area.interaction_id == "oren_charm_shrine":
			story_state.set_flag("oren_charm_returned", true)
			quests.complete_objective("side_childs_charm", "return_charm")
		elif area.interaction_id.begins_with("memorial_candle_"):
			var candle_name: String = str(area.interaction_id).trim_prefix("memorial_candle_")
			story_state.set_flag("candle_%s_lit" % candle_name, true)
			if bool(story_state.get_flag("candle_bram_lit", false)) and bool(story_state.get_flag("candle_sella_lit", false)) and bool(story_state.get_flag("candle_oren_lit", false)):
				story_state.set_flag("three_candles_lit", true)
			var candle_visual := area.get_node_or_null("MemorialCandleVisual") as Node3D
			if candle_visual != null:
				candle_visual.reparent(zone_root, true)
				candle_visual.name = "LitMemorialCandle_%s" % candle_name
				var flame := candle_visual.get_node_or_null("Flame") as MeshInstance3D
				if flame != null:
					flame.visible = true
			quests.complete_objective("side_three_candles", "light_%s" % candle_name)
		elif area.interaction_id == "sacrifice_roots":
			story_state.set_flag("mira_garden_inspected", true)
		else:
			quests.complete_evidence(area.quest_id, area.objective_id)
		story_state.record_evidence(str(area.interaction_id), {"zone": current_zone_id, "kind": "fact", "title": str(area.prompt)})
		_present_castle_clue(str(area.interaction_id), str(area.prompt))
		if area.interaction_id == "tracks":
			if quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
				hud.toast("The tracks change after the Ghoulkin falls: boots beside claws, both leading back toward Greyfen.")
				_show_current_objective_guidance(5.5)
				audio.play_event("tracks_found", 0.02)
				audio.play_voice("voice_player_return_report_01")
				audio.set_music_state("return_report")
			else:
				hud.toast("The tracks pass untouched food and lead toward the tokens. These things are following names, not hunger.", 5.5)
				audio.play_voice("voice_player_clue_observation_01")
			audio.play_event("reveal", 0.02)
		elif area.interaction_id == "corpse":
			hud.toast("Bram's ledger. A page of debts, all crossed out. His hand still grips the cart brake.", 5.5)
		elif area.interaction_id == "claw_marks":
			hud.toast("Vargan binding wire. Someone fastened a name to these creatures, then tried to burn it off.", 5.5)
		elif area.interaction_id == "black_feathers":
			hud.toast("Sella's red thread. The knot is Anwen's. The feathers were tied here, not scattered by a bird.", 5.5)
		elif area.interaction_id == "oren_token":
			hud.toast("Oren's wooden crow. The wings are worn smooth; only his name has been scraped away.", 5.5)
		elif area.interaction_id == "chapel_names":
			story_state.set_flag("chapel_names_read", true)
			_try_complete_oren_thread_trace()
			hud.toast("The chapel lists Bram and Sella. Oren's name was cut away, but the red thread still marks his place.")
			_show_current_objective_guidance(6.0)
			audio.play_event("reveal", 0.02)
		elif area.interaction_id == "ritual_stones":
			quests.complete_objective("main_teeth_in_rain", "name_the_dead")
			story_state.set_flag("oren_name_spoken", true)
			_try_complete_oren_thread_trace()
			hud.toast("Kael speaks Oren's name. Something deeper in Wychwood answers.")
			_show_current_objective_guidance(6.0)
			audio.play_event("reveal", 0.03)
			if current_zone_id == "wychwood" and not _has_interactable("deep_wood_gate"):
				var deeper_gate = _make_zone_gate("Enter deeper Wychwood", Vector3(10.8, 0, -13.2), "deep_wood", Vector3(0, 1, 12))
				if deeper_gate != null:
					deeper_gate.name = "deep_wood_gate"
		elif area.interaction_id == "old_hall":
			quests.complete_objective("main_blood_under_stone", "locate_record_hall")
		elif area.interaction_id == "grave_bell":
			quests.complete_objective("side_widows_bell", "find_bell")
		elif area.interaction_id == "massacre_iron":
			quests.complete_objective("side_iron_remembers", "recover_iron")
			hud.toast("The iron bears Vargan hammer marks beneath the soot.")
		elif area.interaction_id == "rooks_false_road":
			hud.toast("Rook's older road is still here. The newer waystone hides where the refugees were sent.")
		elif area.interaction_id == "hidden_ash_measure":
			story_state.set_flag("ash_measure_recovered", true)
			hud.toast("The hidden measure weighs Greyfen's harvest against missing refugee wagons.")
		elif area.interaction_id == "deserters_muster":
			story_state.set_flag("deserters_muster_read", true)
			hud.toast("The deserters signed their refusal beneath an order to erase the refugee names.")
		elif area.interaction_id == "empty_grave_tracks":
			quests.complete_objective("side_empty_grave", "follow_empty_grave")
			if current_zone_id == "greyfen":
				load("res://scripts/zones/greyfen_section.gd").new().publish_returned_soldier(ZoneBuildContext.new(_host, "greyfen"))
			hud.toast("Bare footprints leave the grave and stop beside the old road.")
			_show_current_objective_guidance(5.0)
		elif area.interaction_id == "oren_charm_shrine":
			hud.toast("Oren's name has a place now. The red thread no longer marks an absence.")
		elif area.interaction_id.begins_with("memorial_candle_"):
			hud.toast("A candle burns for %s. The road keeps a name." % area.interaction_id.trim_prefix("memorial_candle_").capitalize())
		elif area.interaction_id == "bandit_camp":
			hud.toast("Boot prints. Rope. A child's torn ribbon. Not a dog's work.")
		elif area.interaction_id == "sheepfold":
			hud.toast("Human boot prints leave the fold beside smaller paw marks. Follow both into Wychwood.")
		elif area.interaction_id == "bitter_roots":
			quests.complete_objective("side_bitter_roots", "collect_roots")
			story_state.set_flag("bitter_roots_collected", true)
		elif area.interaction_id == "sacrifice_roots":
			hud.toast("The roots drink from old blood. Mira knew this place.")
		elif area.interaction_id == "post_victory_token":
			story_state.set_flag("road_token_recovered", true)
			_try_complete_oren_thread_trace()
			hud.toast("Oren's token is complete. Vargan binding wire is wound through the scratched name.")
			_show_current_objective_guidance(6.0)
			audio.play_event("reveal", 0.02)
		elif area.interaction_id == "chapel_door":
			story_state.set_flag("crow_chapel_opened", true)
			hud.toast("The chapel seal yields. The Crow Shrine inside is still bound to the erased names.")
			_show_current_objective_guidance(6.0)
			_spawn_crow_shrine_choice()
			_ensure_bell_eater()
		elif area.interaction_id.begins_with("grave_"):
			_ensure_cemetery_ambush()
		elif area.interaction_id.begins_with("vargan_"):
			story_state.set_flag(area.interaction_id, true)
			story_state.set_flag("castle_discovered", true)
			match area.interaction_id:
				"vargan_mile_marker": hud.toast("The seal is Vargan. The scrape marks are newer.")
				"vargan_supply_cart": hud.toast("Army weights and refugee canvas. Soldiers moved this cargo after the road closed.")
				"vargan_gate_notice": hud.toast("The road was not lost. It was closed by order.")
				"vargan_iron_binding": hud.toast("Iron wire, blackened at the twist. The same work as Oren's token.")
		StoryWorldDirector.refresh(_host)
		story_save_pending = true
		_host.call_deferred("_persist_story_action")
		_mark_interaction_removed(area)
		if area.interaction_id.begins_with("memorial_candle_"):
			area.queue_free()
		active_interactable = null
		hud.set_prompt("")
		area.queue_free()
	elif area.interaction_type == "herb":
		var gain = {}
		gain[area.interaction_id] = 1
		inventory.add_ingredients(gain)
		hud.toast("Gathered %s." % area.interaction_id.capitalize())
		_mark_interaction_removed(area)
		area.queue_free()
	elif area.interaction_type == "zone":
		var portal := area.find_child("OathGatePortal", true, false) as OathGatePortal
		if portal != null and portal.state != OathGatePortal.PortalState.READY:
			hud.toast("The Oath Gate is still gathering the road beyond.")
			return
		if portal != null:
			portal.mark_traveling()
		_request_zone_load(area.zone_target, area.get_meta("spawn_pos"))
	elif area.interaction_type == "blocked_zone":
		hud.toast(str(area.get_meta("message", "That road is barred tonight.")))

func _handle_village_place(id: String) -> void:
	match id:
		"village_well":
			player.stamina_component.restore(5.0)
			hud.toast("Cold iron in the water. Kael catches his breath.")
		"forge_corner": hud.toast("Vargan iron, hammered into Greyfen hinges. Tor never mentions the crest marks.")
		"shrine_prayer":
			var activities := zone_root.get_node_or_null("StoryActivities")
			if activities != null:
				activities.activate("shrine_prayer")
		"river_water":
			player.stamina_component.restore(18.0)
			hud.toast("Cold river water. Clean enough above Greyfen, for now.")
		_: hud.toast("Greyfen has made use of everything it could keep.")

func _on_minigame_result(game_id: String, outcome: String) -> void:
	if game_id == "tic_tac_toe" and quests.is_active("saga_gre_q04") and str(story_state.get_flag("saga_gre_q04_outcome", "")) == "replayed":
		story_state.set_flag("saga_gre_q04:round_played", true)
	var played_id := "%s_played" % game_id
	story_state.set_flag(played_id, int(story_state.get_flag(played_id,0)) + 1)
	if outcome == "win":
		var wins_id := "%s_wins" % game_id
		story_state.set_flag(wins_id, int(story_state.get_flag(wins_id,0)) + 1)
		var reward_id := "%s_reward_claimed" % game_id
		var person: String = str(minigames.opponent_id)
		var legacy_opponent := (game_id == "tic_tac_toe" and person == "rook") or (game_id == "draughts" and person == "blacksmith_tor")
		if legacy_opponent and not bool(story_state.get_flag(reward_id,false)):
			story_state.set_flag(reward_id,true)
			if game_id == "tic_tac_toe":
				story_state.set_flag("rook_road_hint",true)
				hud.toast("Rook: Road wasn't always cursed. Ask who bent it.")
			elif game_id == "draughts":
				story_state.set_flag("tor_iron_hint",true)
				inventory.add_ingredients({"scrap_iron":1})
				hud.toast("Tor gives up scrap bearing an old Vargan stamp.")
		if game_id == "chess":
			var claim := "chess_prize:" + person
			if not bool(story_state.get_flag(claim, false)):
				story_state.set_flag(claim, true)
				inventory.add_reward({"coin": 3 if person == "rook" else 8})
				hud.toast("%s pays the table's one-time prize." % ("Rook" if person == "rook" else "Tor"))
	save_manager.autosave(_host)

func _on_minigame_state_changed() -> void:
	if game_started and not zone_transition_pending and not zone_load_request_pending and pending_player_restore.is_empty():
		save_manager.autosave(_host)

func _remove_interactable(id: String) -> void:
	if zone_root == null:
		return
	for child in zone_root.get_children():
		if child.get("interaction_id") == id:
			if child.has_method("set_interaction_enabled"):
				child.set_interaction_enabled(false)
			_remove_interaction_candidate(child)
			child.queue_free()

func _consume_story_choice_interactable(id: String) -> void:
	if active_interactable != null and str(active_interactable.get("interaction_id")) == id:
		_mark_interaction_removed(active_interactable)
		active_interactable.queue_free()
		active_interactable = null
	_remove_interactable(id)

func _has_interactable(id: String) -> bool:
	if zone_root == null:
		return false
	for child in zone_root.get_children():
		if str(child.name) == id or str(child.get("interaction_id")) == id:
			return true
	return false

func _mark_interaction_removed(area) -> void:
	removed_interactions["%s:%s" % [current_zone_id, area.interaction_id]] = true
	if area.has_method("set_interaction_enabled"):
		area.set_interaction_enabled(false)
	_remove_interaction_candidate(area)
	_invalidate_interaction_prompt()

func _is_interaction_removed(id: String) -> bool:
	return bool(removed_interactions.get("%s:%s" % [current_zone_id, id], false))

func _connect_interactable(area, owner_root: Node3D = null, owner_cache: Array = []) -> void:
	var root := owner_root if is_instance_valid(owner_root) else zone_root
	var cache: Array = owner_cache if owner_root != null else interaction_area_cache
	if area is Area3D and area not in cache:
		cache.append(area as Area3D)
		if interaction_focus != null and root == zone_root:
			interaction_focus.register(area)
	area.body_entered.connect(func(body: Node):
		if root != zone_root or not is_instance_valid(root):
			return
		if body == player and is_instance_valid(area) and not area.is_queued_for_deletion() and not bool(area.get_meta("seamless_exterior_gate", false)) and area not in interaction_candidates:
			if interaction_focus != null:
				interaction_focus.register(area)
			interaction_candidates.append(area)
			interaction_focus_dirty = true
	)
	area.body_exited.connect(func(body: Node):
		if root != zone_root or not is_instance_valid(root):
			return
		if body == player:
			_remove_interaction_candidate(area)
			if is_instance_valid(area):
				_set_interactable_label_visible(area,false)
			if is_instance_valid(active_interactable) and is_instance_valid(area) and active_interactable == area:
				active_interactable = null
			interaction_focus_dirty = true
	)

func _update_interaction_focus() -> void:
	_refresh_interaction_candidates()
	for index in range(interaction_candidates.size() - 1, -1, -1):
		var candidate = interaction_candidates[index]
		if candidate == null or not is_instance_valid(candidate):
			interaction_candidates.remove_at(index)
			continue
		if bool(candidate.get_meta("seamless_exterior_gate", false)):
			interaction_candidates.remove_at(index)
	var camera: Camera3D = _host.get_viewport().get_camera_3d()
	var best = zone_runtime_coordinator.choose_interaction(interaction_candidates, player, camera, Callable(_host, "_interaction_target_valid")) if zone_runtime_coordinator != null else null
	if active_interactable != best:
		if active_interactable != null and is_instance_valid(active_interactable):
			_set_interactable_label_visible(active_interactable,false)
		active_interactable = best
		compass_dirty = true
		if active_interactable != null:
			_set_interactable_label_visible(active_interactable,true)
	_publish_interaction_prompt()
	interaction_focus_dirty = false
	interaction_focus_cache_valid = true
	last_focus_position = player.global_position
	var camera_after_update: Camera3D = _host.get_viewport().get_camera_3d()
	last_focus_forward = (-camera_after_update.global_basis.z).normalized() if camera_after_update != null else (-player.global_basis.z).normalized()
	interaction_focus_updated.emit(active_interactable)

func _interaction_focus_needs_refresh() -> bool:
	if player == null or interaction_focus_dirty or not interaction_focus_cache_valid:
		return true
	if interaction_focus != null and interaction_focus.needs_refresh():
		return true
	if active_interactable != null and (not is_instance_valid(active_interactable) or not _interaction_target_valid(active_interactable)):
		return true
	if player.global_position.distance_squared_to(last_focus_position) >= 0.0064:
		return true
	var camera: Camera3D = _host.get_viewport().get_camera_3d()
	var current_forward: Vector3 = (-camera.global_basis.z).normalized() if camera != null else (-player.global_basis.z).normalized()
	return last_focus_forward.is_zero_approx() or last_focus_forward.dot(current_forward) < 0.9995

func _refresh_interaction_candidates() -> void:
	if zone_root == null or player == null:
		return
	if not interaction_area_cache_ready:
		# Build this list once per active zone. The previous implementation walked
		# the complete zone tree every 100 ms, which made Greyfen frame pacing
		# collapse even though the interaction set itself was small and stable.
		for raw_candidate in zone_root.find_children("*", "Area3D", true, false):
			var discovered := raw_candidate as Area3D
			if discovered != null and not discovered.is_queued_for_deletion() and discovered.has_method("get_context_prompt"):
				if discovered not in interaction_area_cache:
					interaction_area_cache.append(discovered)
				# Prepared roots already own their area list, but must join the
				# active targeting index exactly when that root is published.
				if interaction_focus != null:
					interaction_focus.register(discovered)
		interaction_area_cache_ready = true
	_prune_invalid_interaction_candidates()
	# The registered grid also covers save/spawn placement between Area signals.
	# Rebuild only the local set, not every interactable in the zone.
	interaction_candidates.clear()
	for candidate in interaction_focus.nearby(player.global_position, zone_root):
		if candidate.is_queued_for_deletion() or not candidate.has_method("get_context_prompt"):
			continue
		if not candidate.is_visible_in_tree() or (candidate.has_method("is_interaction_enabled") and not candidate.is_interaction_enabled()):
			continue
		if bool(candidate.get_meta("seamless_exterior_gate", false)):
			continue
		var candidate_type := str(candidate.get("interaction_type"))
		var range_limit := 3.6 if candidate_type in ["zone", "dialogue"] else 2.8
		if candidate.global_position.distance_to(player.global_position) <= range_limit:
			if str(candidate.get("interaction_type")) == "zone":
				var portal := candidate.find_child("OathGatePortal", true, false) as OathGatePortal
				if portal != null and portal.state == OathGatePortal.PortalState.DORMANT:
					portal.begin_preload()
			if candidate in interaction_candidates:
				continue
			interaction_candidates.append(candidate)

func _prune_invalid_interaction_candidates() -> void:
	for index in range(interaction_candidates.size() - 1, -1, -1):
		var candidate = interaction_candidates[index]
		if candidate == null or not is_instance_valid(candidate):
			interaction_candidates.remove_at(index)

func _remove_interaction_candidate(area) -> void:
	if interaction_focus != null:
		interaction_focus.forget(area)
	for index in range(interaction_candidates.size() - 1, -1, -1):
		var candidate = interaction_candidates[index]
		if candidate == null or not is_instance_valid(candidate):
			interaction_candidates.remove_at(index)
			continue
		if area != null and is_instance_valid(area) and candidate == area:
			interaction_candidates.remove_at(index)

func _interaction_target_valid(area: Area3D) -> bool:
	return interaction_focus != null and interaction_focus.target_is_valid(area, player, _host.get_viewport().get_camera_3d())

func _set_interactable_label_visible(area: Node, visible: bool) -> void:
	var label := area.find_child("InteractionWorldLabel", true, false) as Label3D
	if label != null:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.width = 240.0
		label.visible = visible
