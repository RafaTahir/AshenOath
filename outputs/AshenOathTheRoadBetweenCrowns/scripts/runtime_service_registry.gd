extends Node

const SERVICE_PATHS := {
	"story_state": "story_state", "quests": "quest_manager",
	"quest_presentation": "quest_presentation_state", "quest_beats": "quest_beat_director",
	"dialogue": "dialogue_manager", "inventory": "inventory_manager",
	"vendor_service": "vendor_service", "crafting": "crafting_manager", "combat": "combat_manager",
	"save_manager": "save_manager", "settings": "settings_manager",
	"world_materials": "world_material_library", "day_night": "day_night_controller",
	"audio": "audio_manager", "asset_helper": "asset_spawn_helper", "hud": "hud",
	"minigames": "minigame_manager", "progression": "progression_manager",
	"input_router": "input_router", "interaction_focus": "interaction_focus_service",
	"mobile_touch": "mobile_touch_controls", "zone_streaming": "zone_streaming_service",
	"runtime_packs": "runtime_pack_manager", "display_metrics": "display_metrics_bridge",
}

const REQUIRED_SERVICES := [
	"story_state", "quests", "quest_presentation", "quest_beats", "dialogue", "inventory", "vendor_service", "crafting", "combat",
	"save_manager", "settings", "world_materials", "day_night", "audio",
	"asset_helper", "hud", "minigames", "progression", "input_router", "interaction_focus", "mobile_touch", "zone_streaming", "runtime_packs", "display_metrics"
]

var services: Dictionary = {}
var configured := false
var menu_configured := false
var campaign_configured := false
var prepared_service_modes: Dictionary = {}
const MENU_SERVICES := ["save_manager", "settings", "audio", "hud", "input_router", "mobile_touch", "runtime_packs", "display_metrics"]

func create_services(menu_only := false) -> Dictionary:
	assert(services.is_empty(), "Runtime services may only be created once")
	return _create_missing_services(MENU_SERVICES if menu_only else REQUIRED_SERVICES)

func create_gameplay_services() -> Dictionary:
	return _create_missing_services(REQUIRED_SERVICES)

func prepare_gameplay_services(keep_preparing: Callable) -> bool:
	var slice_started := Time.get_ticks_usec()
	for id in REQUIRED_SERVICES:
		if not keep_preparing.call():
			return false
		_create_missing_services([id])
		if not services.has(id):
			return false
		if Time.get_ticks_usec() - slice_started >= 8000:
			await get_tree().process_frame
			slice_started = Time.get_ticks_usec()
	return bool(keep_preparing.call()) and is_complete()

func _create_missing_services(ids: Array) -> Dictionary:
	for id in ids:
		if services.has(id):
			continue
		var path := "res://scripts/%s.gd" % SERVICE_PATHS[id]
		var script := load(path) as Script
		assert(script != null and script.can_instantiate(), "Required service unavailable: %s (%s)" % [id, path])
		if script == null or not script.can_instantiate():
			push_error("Required service unavailable: %s (%s)" % [id, path])
			return services
		var service: Node = script.new()
		services[id] = service
		service.name = _service_node_name(id)
		if id == "hud":
			service.set_settings_source(services["settings"])
		add_child(service)
		if id not in MENU_SERVICES and not configured:
			prepared_service_modes[id] = service.process_mode
			service.process_mode = Node.PROCESS_MODE_DISABLED
	return services

func configure_menu(owner: Node) -> void:
	if menu_configured:
		return
	menu_configured = true
	var hud = services["hud"]
	var save_manager = services["save_manager"]
	var settings = services["settings"]
	var input_router = services["input_router"]
	var mobile_touch = services["mobile_touch"]
	var audio = services["audio"]
	settings.storage_written.connect(save_manager.confirm_file_persistence)
	settings.storage_failed.connect(save_manager.report_persistence_failure)
	audio.bind_runtime_packs(services["runtime_packs"])
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_runtime_services(owner, save_manager)
	var summary_quests: Dictionary = owner.call("_read_json", "res://data/quests.json")
	summary_quests.merge(preload("res://scripts/saga_catalog.gd").quest_definitions(), true)
	save_manager.set_summary_definitions(summary_quests, owner.call("_read_json", "res://data/items.json"))
	save_manager.load_prepared_requested.connect(Callable(owner, "_on_prepared_journey_load"))
	save_manager.library_changed.connect(Callable(owner, "_queue_journey_models_refresh"))
	save_manager.message.connect(func(text: String):
		var failed: bool = "failed" in text.to_lower() or "no valid" in text.to_lower() or "could not" in text.to_lower()
		hud.post_notice(text, "error" if failed else "save", 5.5 if failed else 2.5, text)
	)
	input_router.install_default_actions()
	input_router.set_settings_manager(settings)
	input_router.apply_settings(settings.settings)
	hud.set_input_source(input_router)
	mobile_touch.setup(input_router, hud, settings.settings)
	settings.apply_platform_defaults(mobile_touch.touch_capable)
	settings.changed.connect(func(current: Dictionary):
		input_router.apply_settings(current)
		mobile_touch.apply_settings(current)
		owner.call("_apply_runtime_settings", current)
	)
	input_router.input_context_changed.connect(Callable(owner, "_on_input_context_changed"))
	input_router.transient_input_reset.connect(Callable(owner, "_on_transient_input_reset"))
	mobile_touch.gameplay_layout_unavailable.connect(Callable(owner, "_on_touch_layout_unavailable"))
	mobile_touch.gameplay_layout_reason_changed.connect(hud.set_touch_layout_reason)
	hud.pause_requested.connect(Callable(owner, "_pause_game"))
	hud.resume_requested.connect(Callable(owner, "_resume_game"))
	hud.new_game_requested.connect(Callable(owner, "_new_game"))
	hud.new_game_cancel_requested.connect(Callable(owner, "_cancel_new_game_request"))
	hud.quit_requested.connect(Callable(owner, "_handle_quit_request"))
	hud.settings_requested.connect(Callable(owner, "_handle_setting"))
	hud.launch_accepted.connect(Callable(owner, "_on_launch_accepted"))
	hud.journey_load_requested.connect(Callable(owner, "_request_journey_load"))
	hud.journey_load_cancel_requested.connect(Callable(owner, "_cancel_journey_load"))
	hud.continue_requested.connect(func():
		var model: Dictionary = save_manager.continue_model()
		if bool(model.get("available", false)):
			owner.call("_request_journey_load", model.get("selection", {}))
	)
	hud.menu_hovered.connect(func(): audio.play_event("menu_hover", 0.025))
	hud.menu_clicked.connect(func(): audio.play_event("menu_click", 0.015))
	hud.audio_mix_requested.connect(settings.set_mix_level)
	settings.apply()
	owner.call("_apply_runtime_settings", settings.settings)
	services["display_metrics"].setup(hud, mobile_touch)
	hud.set_touch_layout_reason(mobile_touch.gameplay_layout_reason())
	owner.call_deferred("_refresh_journey_models")

func configure_campaign() -> void:
	if campaign_configured:
		return
	assert(configured, "Opening services must be configured before campaign data")
	campaign_configured = true
	services["dialogue"].load_dialogue("res://data/campaign_dialogue.json")

func configure(owner: Node) -> void:
	services["hud"].prepare_gameplay_ui()
	assert(not configured, "Runtime services may only be configured once")
	assert(is_complete(), "Runtime services must exist before configuration")
	configure_menu(owner)
	configured = true
	var story_state = services["story_state"]
	var quests = services["quests"]
	var quest_presentation = services["quest_presentation"]
	var quest_beats = services["quest_beats"]
	var dialogue = services["dialogue"]
	var inventory = services["inventory"]
	var vendor_service = services["vendor_service"]
	var crafting = services["crafting"]
	var combat = services["combat"]
	var save_manager = services["save_manager"]
	var settings = services["settings"]
	var day_night = services["day_night"]
	var audio = services["audio"]
	var hud = services["hud"]
	var minigames = services["minigames"]
	var progression = services["progression"]
	var input_router = services["input_router"]
	var interaction_focus = services["interaction_focus"]
	var mobile_touch = services["mobile_touch"]
	var zone_streaming = services["zone_streaming"]
	var runtime_packs = services["runtime_packs"]

	quests.load_quests("res://data/quests.json")
	hud.set_runtime_services(owner, save_manager)
	quest_presentation.setup(quests, quest_beats, story_state)
	quest_beats.setup(quests, story_state)
	dialogue.load_dialogue("res://data/dialogue.json")
	# This shared file also owns the opening report and Crow Shrine choice.
	configure_campaign()
	dialogue.load_dialogue("res://data/interaction_scenes.json")
	dialogue.load_conversation_topics("res://data/conversation_topics.json")
	dialogue.setup(story_state, quests)
	inventory.load_items("res://data/items.json")
	inventory.set_progression(progression)
	save_manager.set_summary_definitions(quests.quest_defs, inventory.item_defs)
	vendor_service.load_vendors("res://data/vendors.json")
	crafting.setup(inventory, quests, story_state)
	hud.set_preparation_services(crafting)
	interaction_focus.setup(quests, quest_presentation)
	interaction_focus.candidates_changed.connect(func(): owner.set("interaction_focus_dirty", true))
	combat.contact_missed.connect(func(_contact: Dictionary): hud.show_status_cue("No blade contact", "neutral"))
	minigames.setup(input_router,settings)
	services["display_metrics"].register_target(minigames)
	input_router.gameplay_action_requested.connect(Callable(owner, "_on_virtual_gameplay_action"))
	hud.touch_quick_action_requested.connect(Callable(owner, "_on_touch_quick_action"))
	zone_streaming.setup(owner)
	# The base manager is embedded in the main PCK. On Web, begin the verified
	# opening downloads immediately so the menu and Crow Flight can cover the
	# only unavoidable cold-cache wait. Desktop keeps the full project local.
	if runtime_packs.has_method("request_pack"):
		# Startup readiness belongs to the launch transition. Requesting Web packs
		# while services are being constructed races the menu and duplicates the
		# base-pack progress path owned by Game._on_launch_accepted().
		if not OS.has_feature("web"):
			runtime_packs.request_pack("base")
	input_router.device_changed.connect(func(_device: String):
		hud.set_input_device(input_router.active_device)
		owner.call("_refresh_equipment_readout")
		owner.call("_invalidate_interaction_prompt")
	)
	input_router.bindings_changed.connect(func(_bindings: Dictionary): owner.call("_invalidate_interaction_prompt"))
	story_state.changed.connect(Callable(owner, "_invalidate_interaction_prompt"))
	story_state.changed.connect(Callable(owner, "_queue_story_guidance_refresh"))
	input_router.gamepad_profile_changed.connect(func(profile: Dictionary):
		hud.set_input_device(input_router.active_device)
		if hud.has_method("set_gamepad_profile"):
			hud.set_gamepad_profile(profile)
		owner.call("_refresh_equipment_readout")
	)
	input_router.gamepad_disconnected.connect(func(_device_id: int):
		hud.set_input_device(input_router.active_device)
		var fallback_hint: String = "Touch the screen to use touch controls, or use a keyboard and mouse." if mobile_touch.is_touch_enabled() else "Keyboard and mouse input is ready."
		hud.toast("Controller disconnected. " + fallback_hint)
		hud.restore_input_focus()
	)

	day_night.time_changed.connect(func(minutes: float, phase: String, count: int):
		hud.set_world_clock(minutes, phase, count)
		var director = owner.get("visual_director")
		if director != null:
			director.set_time(minutes, phase, count)
	)
	hud.set_world_clock(day_night.get_time(), day_night.current_phase, day_night.day_count)
	hud.journal_section_requested.connect(Callable(owner, "_open_journal_section"))
	hud.save_requested.connect(func():
		audio.play_event("ui")
		save_manager.save_game(owner)
	)
	hud.load_requested.connect(func():
		audio.play_event("ui")
		save_manager.load_game(owner)
	)
	hud.load_checkpoint_requested.connect(func():
		audio.play_event("ui")
		save_manager.load_checkpoint(owner)
	)
	hud.journal_requested.connect(func():
		audio.play_event("ui")
		owner.call("_show_preparation_menu")
	)
	hud.vendor_purchase_requested.connect(func(vendor_id: String, item_id: String, quantity: int):
		owner.call("_purchase_from_vendor", vendor_id, item_id, quantity)
	)
	hud.vendor_sale_requested.connect(Callable(owner, "_sell_to_vendor"))
	hud.action_selected.connect(Callable(owner, "_handle_dialogue_action"))
	hud.dialogue_closed.connect(Callable(owner, "_release_dialogue_facing"))
	hud.dialogue_closed.connect(Callable(owner, "_on_dialogue_closed_audio"))
	hud.dialogue_page_changed.connect(Callable(owner, "_on_dialogue_page_changed"))
	hud.dialogue_topic_requested.connect(Callable(owner, "_on_dialogue_topic_requested"))
	hud.dialogue_speech_interrupted.connect(audio.stop_voice)
	hud.dialogue_review_changed.connect(audio.set_dialogue_review_paused)
	hud.craft_requested.connect(func(item_id: String):
		owner.call("_craft_preparation_item", item_id)
	)
	hud.item_use_requested.connect(func(item_id: String):
		owner.call("_use_preparation_item", item_id)
	)
	hud.inventory_preference_requested.connect(Callable(owner, "_set_inventory_preference"))
	hud.upgrade_requested.connect(func(upgrade_id: String):
		owner.call("_learn_preparation_practice", upgrade_id)
	)
	hud.respec_requested.connect(Callable(owner, "_redistribute_practices"))
	progression.changed.connect(Callable(owner, "_on_progression_changed"))
	owner.call("_on_progression_changed")
	quests.changed.connect(Callable(owner, "_queue_progression_rewards"))
	story_state.changed.connect(Callable(owner, "_queue_progression_rewards"))
	quests.changed.connect(Callable(owner, "_refresh_tracker"))
	quests.message.connect(func(text: String): hud.post_notice(text, "story", 5.5, text))
	quests.message.connect(func(_text: String): audio.play_event("quest"))
	quests.quest_completed.connect(Callable(owner, "_on_quest_completed"))
	inventory.message.connect(func(text: String):
		if not bool(owner.get("preparation_action_in_progress")):
			hud.post_notice(text, "inventory", 3.5, text)
	)
	inventory.changed.connect(Callable(owner, "_refresh_equipment_readout"))
	inventory.oil_time_changed.connect(Callable(owner, "_refresh_equipment_readout"))
	inventory.changed.connect(Callable(owner, "_reconcile_preparation_objective"))
	vendor_service.message.connect(func(text: String):
		if not bool(owner.get("preparation_action_in_progress")):
			hud.post_notice(text, "inventory", 3.5, text)
	)
	vendor_service.changed.connect(Callable(owner, "_refresh_equipment_readout"))
	progression.message.connect(func(text: String):
		if not bool(owner.get("preparation_action_in_progress")):
			hud.post_notice(text, "inventory", 3.5, text)
	)
	combat.message.connect(func(text: String): hud.post_notice(text, "combat", 2.5, text))
	combat.enemy_hit.connect(func(name: String, amount: float):
		hud.show_status_cue("Hit: %d" % int(amount), "item")
		owner.call("_hitstop", 0.045)
	)
	combat.impact.connect(Callable(owner, "_on_combat_impact"))
	minigames.result.connect(Callable(owner, "_on_minigame_result"))
	minigames.state_changed.connect(Callable(owner, "_on_minigame_state_changed"))
	minigames.closed.connect(func(): hud.toast("The village carries on."))
	settings.apply()
	owner.call("_apply_runtime_settings", settings.settings)
	for id in prepared_service_modes:
		services[id].process_mode = int(prepared_service_modes[id])
	prepared_service_modes.clear()

func get_service(id: String):
	return services.get(id)

func is_complete() -> bool:
	for id in REQUIRED_SERVICES:
		if not services.has(id) or services[id] == null or not is_instance_valid(services[id]):
			return false
		if services[id].get_parent() != self:
			return false
	return true

func _service_node_name(id: String) -> String:
	var result := ""
	for part in id.split("_"):
		result += part.capitalize()
	return result
