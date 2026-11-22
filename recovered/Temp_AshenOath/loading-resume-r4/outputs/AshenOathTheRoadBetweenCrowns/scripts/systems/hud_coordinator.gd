extends "res://scripts/systems/game_bindings.gd"
## Owns hud operations; configure() injects dependencies.
signal tracker_refreshed()

func route_notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and input_router != null:
		input_router.reset_transient_input("focus_lost")
		if is_instance_valid(player) and player.has_method("cancel_buffered_input"):
			player.cancel_buffered_input("focus_lost")
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and game_started and settings != null:
		if bool(settings.settings.get("pause_on_focus_loss", true)) and not _host.get_tree().paused:
			_pause_game()

func _on_touch_layout_unavailable(reason: String) -> void:
	if hud != null:
		hud.set_touch_layout_reason(reason)
	if reason.is_empty() or resource_shutdown_prepared or not game_started or _journey_load_pending():
		return
	# A layout change must not leave a running fight behind unavailable touch
	# controls. Existing Pause retains the journey and exposes the way back.
	if not _host.get_tree().paused:
		_pause_game()

func _pause_game() -> void:
	if not game_started or not is_instance_valid(player) or _journey_load_pending():
		return
	if is_instance_valid(zone_root) and bool(zone_root.get_meta("opening_scene_active", false)):
		var life := zone_root.find_child("GreyfenLifeController", true, false)
		if life != null: life.finish_opening_scene("interrupted")
	if camera_rig != null and camera_rig.has_method("clear_target_lock"):
		camera_rig.clear_target_lock()
	if hud != null and hud.has_method("clear_target_lock_status"):
		hud.clear_target_lock_status()
	audio.set_game_paused(true)
	_host.get_tree().paused = true
	paused_by_menu = true
	if input_router != null and input_router.has_method("set_context"):
		input_router.set_context("pause")
	audio.play_event("ui")
	_refresh_journey_models()
	hud.show_pause_menu()

func _show_companion_commands() -> void:
	if not game_started or _journey_load_pending() or zone_transition_pending or zone_load_request_pending or str(story_state.get_flag("bracken_home", "")) != "adopted":
		return
	audio.set_game_paused(true)
	_host.get_tree().paused = true
	paused_by_menu = true
	input_router.set_context("pause")
	preload("res://scripts/companion_controller.gd").capture(_host)
	var travel: Dictionary = preload("res://scripts/companion_controller.gd").saved_travel(_host)
	var companion := zone_root.get_node_or_null("Bracken") as Node3D
	travel["present"] = companion != null and companion.is_visible_in_tree()
	hud.show_companion_commands(travel)

func _show_touch_actions() -> void:
	if not is_instance_valid(player):
		return
	audio.set_game_paused(true)
	_host.get_tree().paused = true
	paused_by_menu = true
	input_router.set_context("pause")
	hud.show_touch_actions(player.get_selected_weapon_name(), not player.sword_sheathed if player.weapon_mode == "sword" else player.equipment_loadout.is_drawn())

func _on_touch_quick_action(action: String) -> void:
	if hud.active_menu != "touch_actions" or not _host.get_tree().paused:
		return
	if action == "companion_command":
		_show_companion_commands()
		return
	var allowed := ["weapon_sword", "weapon_oathblade", "weapon_bow", "weapon_sheath", "use_potion", "throw_bomb", "target_lock", "target_next", "target_previous", "cycle_arrow", "camera_zoom_in", "camera_zoom_out"]
	if action not in allowed:
		return
	_resume_game()
	if _host.get_tree().paused or not input_router.is_gameplay_context() or _journey_load_pending() or zone_transition_pending or zone_load_request_pending:
		return
	input_router.set_virtual_action(StringName(action), true)
	input_router.set_virtual_action(StringName(action), false)

func _resume_game() -> void:
	if not game_started or not is_instance_valid(player) or _journey_load_pending() or hud.active_menu == "main":
		return
	var returning_from_ending: bool = hud.active_menu == "ending"
	var touch_reason: String = mobile_touch.gameplay_layout_reason() if mobile_touch != null else ""
	hud.set_touch_layout_reason(touch_reason)
	if not touch_reason.is_empty():
		if not _host.get_tree().paused or hud.active_menu != "pause":
			_pause_game()
		return
	audio.set_game_paused(false)
	_host.get_tree().paused = false
	paused_by_menu = false
	if input_router != null and input_router.has_method("set_gameplay_context"):
		input_router.set_gameplay_context()
	audio.play_event("ui")
	hud.hide_menus()
	_publish_journey_arrival()
	if returning_from_ending and bool(story_state.get_flag("final_choice_completed", false)) and current_zone_id == "hart_glade":
		story_state.set_flag("aftermath_returned", true)
		story_save_pending = true
		_load_zone_after_runtime_pack("greyfen", Vector3(0, 1, 9.8))

func _handle_setting(action: String) -> void:
	audio.play_event("ui")
	if action == "render_scale":
		settings.cycle_resolution_scale()
	elif action == "shadows":
		settings.cycle_shadows()
	elif action == "vsync":
		settings.toggle_vsync()
	elif action == "fullscreen":
		settings.toggle_fullscreen()
	elif action == "potato":
		settings.set_potato_mode(not bool(settings.settings["potato_mode"]))
	elif action == "visual_preset":
		var preset = settings.cycle_quality_preset()
		hud.toast("Visual preset: %s" % preset.capitalize())
		if game_started and player != null:
			_load_zone_after_runtime_pack(current_zone_id, player.global_position)
	elif action == "mouse_sensitivity":
		settings.cycle_mouse_sensitivity()
	elif action == "gamepad_sensitivity":
		settings.cycle_gamepad_look_sensitivity()
	elif action == "gamepad_vibration":
		settings.toggle_gamepad_vibration()
	elif action == "touch_controls":
		settings.cycle_touch_controls()
	elif action == "touch_sensitivity":
		settings.cycle_touch_look_sensitivity()
	elif action == "invert_y":
		settings.toggle_invert_y()
	elif action == "volume":
		settings.cycle_master_volume()
	elif action == "subtitle_scale":
		settings.cycle_subtitle_scale()
	elif action == "camera_shake":
		settings.cycle_camera_shake()
	elif action == "blood_effects":
		settings.toggle_blood_effects()
	elif action == "reduced_motion":
		settings.toggle_reduced_motion()
	elif action == "high_contrast":
		settings.toggle_high_contrast()
	elif action == "control_preset":
		settings.cycle_control_preset()
	elif action == "difficulty":
		settings.cycle_difficulty()
	elif action == "focus_pause":
		settings.toggle_pause_on_focus_loss()
	else:
		settings.cycle_accessibility(action)
	if action != "visual_preset":
		hud.toast("Settings updated.")
	hud.show_settings_menu(hud.controls_back_target)

func _apply_runtime_settings(current_settings: Dictionary) -> void:
	CombatFeedback.reduce_flashes = bool(current_settings.get("flash_reduction", false))
	if runtime_packs != null:
		var preset := str(current_settings.get("quality_preset", "balanced"))
		var changed: bool = runtime_packs.quality_preset != preset
		runtime_packs.quality_preset = preset
		if changed and not game_started and (greyfen_prewarm_started or startup_packs_waiting \
				or startup_prepare_failed or route_zone_cache.has("greyfen")):
			_restart_menu_opening()
	if performance_budget_monitor != null:
		performance_budget_monitor.quality = str(current_settings.get("quality_preset", "balanced"))
	if SettingsDelta.changed(_applied_setting_groups, "audio", audio, current_settings, ["master_volume", "music_volume", "sfx_volume", "voice_volume", "quality_preset"]):
		audio.set_master_volume(float(current_settings.get("master_volume", 0.85)))
		audio.apply_mix_settings(current_settings)
		audio.set_ambient_accents_enabled(str(current_settings.get("quality_preset", "balanced")) == "quality")
	if SettingsDelta.changed(_applied_setting_groups, "hud", hud, current_settings, ["reduced_motion", "flash_reduction", "subtitle_speaker_names", "high_contrast", "subtitle_scale", "subtitle_background_opacity"]):
		hud.apply_accessibility(current_settings)
	if SettingsDelta.changed(_applied_setting_groups, "player", player, current_settings, ["difficulty"]):
		player.apply_difficulty_profile(settings.get_difficulty_profile())
	if SettingsDelta.changed(_applied_setting_groups, "camera", camera_rig, current_settings, ["mouse_sensitivity", "invert_y", "gamepad_look_sensitivity", "camera_shake", "reduced_motion", "flash_reduction", "targeting_assist"]):
		camera_rig.apply_settings(
			float(current_settings.get("mouse_sensitivity", 0.003)),
			bool(current_settings.get("invert_y", false)),
			float(current_settings.get("gamepad_look_sensitivity", 1.0))
		)
		camera_rig.apply_accessibility(current_settings)
		camera_rig.shake_decay = 1000.0 if float(current_settings.get("camera_shake", 1.0)) <= 0.0 else 6.0 / maxf(float(current_settings.get("camera_shake", 1.0)), 0.5)
	if visual_director != null and visual_director.sun != null and SettingsDelta.changed(_applied_setting_groups, "visuals", visual_director.sun, current_settings, ["quality_preset", "reduced_motion", "shadow_quality"]):
		visual_director.apply_settings(current_settings)
		visual_director.sun.shadow_enabled = int(current_settings.get("shadow_quality", 1)) > 0
		visual_director.sun.directional_shadow_max_distance = 42.0

func _queue_story_guidance_refresh() -> void:
	compass_dirty = true
	if story_guidance_refresh_pending:
		return
	story_guidance_refresh_pending = true
	_host.call_deferred("_apply_story_guidance_refresh")

func _apply_story_guidance_refresh() -> void:
	story_guidance_refresh_pending = false
	if resource_shutdown_prepared or hud == null or quest_hud_coordinator == null:
		return
	_refresh_tracker()

func _refresh_tracker() -> void:
	_reconcile_preparation_objective()
	# Quest changes can alter both the preferred interaction target and the
	# compass summary without moving the player. Invalidate the small runtime
	# caches instead of forcing per-frame scans.
	interaction_focus_dirty = true
	compass_dirty = true
	quest_hud_coordinator.refresh_tracker(hud, zone_runtime_coordinator.refresh_presentation if zone_runtime_coordinator != null else Callable())
	_update_compass()
	tracker_refreshed.emit()

func _show_current_objective_guidance(seconds: float = 5.0) -> void:
	quest_hud_coordinator.show_guidance(hud, seconds)

func _refresh_equipment_readout() -> void:
	if hud == null or inventory == null:
		return
	var oil_name = ""
	if inventory.active_oil != "":
		oil_name = inventory.get_item_name(inventory.active_oil)
	var weapon_name := "Steel"
	var arrow_id := "standard_arrow"
	if is_instance_valid(player):
		weapon_name = player.get_selected_weapon_name()
		arrow_id = player.equipment_loadout.selected_arrow_id
	var arrow_type := str({"standard_arrow": "Standard", "bodkin_arrow": "Bodkin", "ashfire_arrow": "Ashfire"}.get(arrow_id, "Standard"))
	var remedy_id: String = inventory.quick_item("use_potion")
	var tool_id: String = inventory.quick_item("throw_bomb")
	hud.update_equipment(int(inventory.items.get(remedy_id, 0)), int(inventory.items.get(tool_id, 0)), oil_name, int(inventory.items.get(arrow_id, 0)), arrow_type, weapon_name, remedy_id, tool_id, ceili(inventory.oil_remaining_seconds))
	if mobile_touch != null and is_instance_valid(player):
		mobile_touch.set_weapon_mode(player.get_weapon_mode())

func _reconcile_preparation_objective() -> void:
	if not game_started or _journey_load_pending() or inventory == null or quests == null:
		return
	if quests.is_active("main_teeth_in_rain") and not quests.is_objective_done("main_teeth_in_rain", "craft_moon_oil"):
		if int(inventory.items.get("moon_oil", 0)) > 0 or str(inventory.active_oil) == "moon_oil":
			quests.complete_objective("main_teeth_in_rain", "craft_moon_oil")

func _guard_tutorial_hint() -> String:
	var guard: Dictionary = input_router.describe_action("block") if input_router != null else {}
	var guarded := bool(story_state.get_flag("greyfen_lesson:block", false))
	return ("Begin guarding as the lunge lands to parry. " if guarded else "Hold your guard through an incoming strike to block. ") + str(guard.get("instruction", "Use your guard control")).trim_suffix(".")

func _update_tutorial_prompts() -> void:
	if player == null:
		return
	if active_interactable != null and not bool(tutorial_flags.get("interact", false)):
		tutorial_flags["interact"] = true
	if current_zone_id == "greyfen" and not bool(tutorial_flags.get("route", false)) and player.global_position.z < -8.0:
		tutorial_flags["route"] = true
		audio.play_event("cloth_wind", 0.03)
		audio.set_music_state("wychwood_tension")
		hud.toast("The village noise thins behind you. The old road keeps its own silence.")
		_show_current_objective_guidance(4.5)
	if current_zone_id == "greyfen" and not bool(tutorial_flags.get("shrine_audio", false)) and player.global_position.distance_to(Vector3(6.0, player.global_position.y, -7.0)) < 5.0:
		tutorial_flags["shrine_audio"] = true
		audio.set_music_state("shrine_anwen")
		audio.play_event("shrine_hum", 0.005)
		audio.play_event("shrine_candle", 0.02)
		audio.play_event("shrine_bell", 0.01)
	if current_zone_id == "wychwood" and not bool(tutorial_flags.get("clearing_tension", false)) and player.global_position.z < 1.0:
		tutorial_flags["clearing_tension"] = true
		audio.set_music_state("wychwood_tension")
		audio.play_event("wychwood_drop", 0.01)
		audio.play_event("wychwood_tension", 0.02)
	if current_zone_id == "wychwood" and (wychwood_encounter_started or player.global_position.z < 1.0):
		_ensure_wychwood_wave()
	if current_zone_id == "wychwood" and not bool(tutorial_flags.get("near_clearing_audio", false)) and player.global_position.z < -4.0:
		tutorial_flags["near_clearing_audio"] = true
		audio.play_event("ghoulkin_idle", 0.03)
	if current_zone_id == "wychwood" \
			and not bool(story_state.get_flag("wychwood_pack_cleared", false)) \
			and player.global_position.z < 1.0 \
			and _has_active_encounter_enemy() \
			and not bool(tutorial_flags.get("combat", false)):
		tutorial_flags["combat"] = true
		audio.set_music_state("ghoulkin_combat")
		audio.play_event("wychwood_tension", 0.01)
		hud.toast("Survive the Ghoulkin.")
		var strike_binding: String = input_router.action_label("light_attack") if input_router != null else "Attack"
		var dodge_binding: String = input_router.action_label("dodge") if input_router != null else "Dodge"
		hud.set_guidance_hint("%s strike | %s dodge\n%s" % [strike_binding, dodge_binding, _guard_tutorial_hint()], 6.0)

func _update_compass() -> void:
	quest_hud_coordinator.update_compass(hud, player, current_zone_id, interaction_area_cache if zone_root != null else [], _zone_display_name(current_zone_id))

func _compass_state_signature() -> String:
	return quest_hud_coordinator.state_signature()

func _compass_needs_refresh() -> bool:
	return quest_hud_coordinator.needs_refresh(player, current_zone_id)

func _distance_to_tracked_interactable(objective_view: Dictionary) -> int:
	return quest_hud_coordinator.objective_distance(objective_view, player, interaction_area_cache if zone_root != null else [])

func _tracked_objective_id(quest_id: String) -> String:
	if quest_id == "" or not quests.active.has(quest_id):
		return ""
	for objective in quests.active[quest_id].get("objectives", []):
		if not bool(objective.get("done", false)):
			return str(objective.get("id", ""))
	return ""

func _tracked_objective_text(quest_id: String, objective_id: String) -> String:
	if not quests.active.has(quest_id):
		return "Follow the road"
	for objective in quests.active[quest_id].get("objectives", []):
		if str(objective.get("id", "")) == objective_id:
			return str(objective.get("text", "Follow the road")).trim_suffix(".")
	return "Follow the road"
