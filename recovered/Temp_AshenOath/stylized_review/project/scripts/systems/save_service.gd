extends "res://scripts/systems/game_bindings.gd"
## Owns save operations; configure() injects dependencies.
signal world_state_loaded()

func load_save_state(data: Dictionary) -> void:
	_ensure_gameplay_runtime()
	runtime_services.configure_campaign()
	# Direct payload callers retain the same preparation boundary as file-backed
	# selections. SaveManager owns identity/history for ordinary UI loads.
	var migrated_data: Dictionary = data
	if save_manager != null and save_manager.has_method("migrate_save_data"):
		migrated_data = save_manager.migrate_save_data(data)
		if migrated_data.is_empty():
			if hud != null:
				hud.toast("This save belongs to a newer version of Ashen Oath.")
			return
	_on_prepared_journey_load({
		"ok": true, "request_id": "direct:%d" % Time.get_ticks_usec(),
		"data": migrated_data, "summary": {}, "source": {"direct_data": true}
	})

func _apply_loaded_journey(data: Dictionary) -> void:
	opening_scene_pending = false
	_ensure_gameplay_runtime()
	if _zone_requires_campaign_pack(str(data.get("zone", "greyfen"))):
		runtime_services.configure_campaign()
	_begin_gameplay_handoff("load_journey")
	if not game_started:
		_discard_menu_opening()
	new_game_start_pending = false
	opening_save_generation += 1
	opening_checkpoint_pending = false
	story_save_pending = false
	_clear_route_zone_cache()
	game_started = true
	_host.get_viewport().disable_3d = false
	paused_by_menu = false
	if audio != null:
		audio.set_game_paused(false)
	_host.get_tree().paused = false
	hud.hide_menus()
	if vendor_service != null:
		vendor_service.load_state(data.get("vendors", {}))
	if minigames != null:
		minigames.load_state(data.get("minigames", {}) if data.get("minigames", {}) is Dictionary else {})
	quests.load_state(data.get("quests", {}))
	if quest_presentation != null:
		quest_presentation.load_state(data.get("quest_presentation", {}))
	if quest_beats != null:
		quest_beats.load_state(data.get("quest_beats", {}))
	# Journey snapshots are a legacy fallback, not an override for newer global
	# input/accessibility preferences selected before loading that journey.
	if settings != null and not settings.loaded_user_settings and typeof(data.get("settings", {})) == TYPE_DICTIONARY and not data.get("settings", {}).is_empty():
		settings.restore_settings(data.settings)
		settings.apply()
	story_state.load_state(data.get("story_state", {}))
	progression.load_state(data.get("progression", {}))
	if seamless_world != null and seamless_world.has_method("load_state"):
		seamless_world.load_state(data.get("seamless_world", {}))
	var saved_sector := str(data.get("world_sector", data.get("zone", "greyfen")))
	var discovered: Dictionary = seamless_world.discovered_sectors if seamless_world != null else {}
	progression.restore_journey(quests, story_state, saved_sector, discovered)
	# Restore entitlement ownership before migrating a legacy coating duration.
	inventory.load_state(data.get("inventory", {}), int(data.get("migrated_from_version", data.get("version", 0))) < 13)
	if int(data.get("version", 0)) < 3 and quests.is_completed("main_road_of_crows"):
		story_state.set_flag("legacy_report_choice_required", true)
	load_world_state(data.get("world_state", {}))
	var zone = str(data.get("world_sector", data.get("zone", "greyfen")))
	var pos_array: Array = data.get("player_position", [0, 1, 7])
	var pos = Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
	var world_array: Array = data.get("world_position", [])
	if seamless_world != null and world_array.size() >= 3:
		pos = seamless_world.local_position_for(zone, Vector3(float(world_array[0]), float(world_array[1]), float(world_array[2])))
	if zone == "deep_wood" and quests.is_active("main_teeth_in_rain") and quests.is_objective_done("main_teeth_in_rain", "name_the_dead") and not quests.is_objective_done("main_teeth_in_rain", "bog_core_choice") and str(story_state.get_flag("saga_bog_arena_owner", "")) == "":
		pos = Vector3(-7,1,11)
		story_state.set_flag("saga_bog_arena_owner", "wychwood")
		story_state.record_evidence("saga_bog_migration", {"zone":"deep_wood", "title":"The memory's northern clearing", "text":"The Bog Wretch and its pending memory core now have one owner in northern Wychwood. Return south along the existing path. Your recorded fight, choices, health and supplies are unchanged."})
	pos = _safe_loaded_position(zone, pos)
	# Campaign saves must follow the same streamed-pack handoff as a gate
	# transition. Otherwise a legacy save opened directly in a later sector
	# reaches the lazy builder before its script pack is mounted.
	pending_player_restore = {
		"health": data.get("player_health", {}).duplicate(true),
		"stamina": data.get("player_stamina", {}).duplicate(true),
		"equipment": data.get("equipment", {}).duplicate(true)
	}
	_load_zone_after_runtime_pack(zone, pos)
	_refresh_tracker()
	_refresh_equipment_readout()
	_host.call_deferred("_finish_gameplay_handoff")

func _journey_load_pending() -> bool:
	return neighbor_crossing_pending or journey_loading.pending(_host)

func _on_prepared_journey_load(prepared: Dictionary) -> void:
	journey_loading.request(_host, prepared)

func _cancel_journey_load() -> void:
	if neighbor_crossing_pending:
		neighbor_crossing_pending = false
		zone_pack_request_serial += 1
		seamless_world.cancel_preparation()
		hud.end_journey_load(false)
		_host.get_tree().paused = neighbor_crossing_was_paused
		audio.set_game_paused(neighbor_crossing_was_paused)
		_recover_failed_pack_load("Crossing cancelled. Your current location and journey are unchanged.")
		return
	journey_loading.cancel(_host)

func _publish_journey_arrival() -> void:
	journey_loading.publish_arrival(_host)

func _queue_journey_models_refresh() -> void:
	if journey_models_refresh_pending:
		return
	journey_models_refresh_pending = true
	_host.call_deferred("_refresh_journey_models")

func _refresh_journey_models() -> void:
	journey_models_refresh_pending = false
	if hud == null or save_manager == null or resource_shutdown_prepared:
		return
	var current: Dictionary = {}
	if game_started:
		current = preload("res://scripts/story_journal.gd").recap_model(quests, story_state, str(current_zone_id))
	hud.set_journey_models({"continue": save_manager.continue_model(), "recovery": save_manager.checkpoint_model(), "current": current})

func _request_journey_load(selection: Dictionary) -> void:
	audio.play_event("ui")
	print("JOURNEY: load_requested slot=%s source=%s" % [str(selection.get("slot_id", "")), str(selection.get("source", ""))])
	save_manager.request_load(selection)

func _open_journal_section(section_id: String) -> void:
	if _journey_load_pending():
		return
	_update_preparation_context()
	hud.show_inventory(inventory, quests, story_state, progression, section_id)

func _apply_pending_player_restore() -> void:
	if pending_player_restore.is_empty() or player == null or not is_instance_valid(player):
		return
	var restore := pending_player_restore
	pending_player_restore = {}
	player.health_component.load_state(restore.health)
	player.stamina_component.load_state(restore.stamina)
	if not player.health_component.dead:
		player.reset_for_journey_restore()
	if player.has_method("load_equipment_state"):
		player.load_equipment_state(restore.equipment)
	_apply_progression_to_player()
	_refresh_tracker()
	_refresh_equipment_readout()

func save_world_state() -> Dictionary:
	var boss_states: Dictionary = boss_saved_states.duplicate(true)
	for enemy in active_enemies:
		if not is_instance_valid(enemy) or not bool(enemy.get("is_boss")):
			continue
		var controller: Node = enemy.get_node_or_null("BossEncounterController")
		if controller != null and controller.has_method("save_state"):
			boss_states[enemy.enemy_id] = controller.save_state()
	return {
		"removed_interactions": removed_interactions.duplicate(true),
		"pending_ending": pending_ending,
		"wychwood_pack_kills": wychwood_pack_kills,
		"ghoulkin_kills": wychwood_pack_kills,
		"wychwood_encounter": {"started": wychwood_encounter_started, "wave": wychwood_pack_kills},
		"boss_states": boss_states,
		"day_night": day_night.save_state() if day_night != null else {}
	}

func load_world_state(state: Dictionary) -> void:
	removed_interactions = state.get("removed_interactions", {}).duplicate(true) if typeof(state.get("removed_interactions", {})) == TYPE_DICTIONARY else {}
	pending_ending = str(state.get("pending_ending", ""))
	wychwood_pack_kills = int(state.get("wychwood_pack_kills", state.get("ghoulkin_kills", wychwood_pack_kills)))
	var encounter: Variant = state.get("wychwood_encounter", {})
	wychwood_encounter_started = bool(encounter.get("started", wychwood_pack_kills > 0)) if encounter is Dictionary else wychwood_pack_kills > 0
	boss_saved_states = state.get("boss_states", {}).duplicate(true) if typeof(state.get("boss_states", {})) == TYPE_DICTIONARY else {}
	if day_night != null:
		day_night.load_state(state.get("day_night", {}))
	world_state_loaded.emit()
