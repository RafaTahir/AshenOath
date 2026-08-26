extends Node

const QuestManager = preload("res://scripts/quest_manager.gd")
const QuestPresentationState = preload("res://scripts/quest_presentation_state.gd")
const QuestBeatDirector = preload("res://scripts/quest_beat_director.gd")
const DialogueManager = preload("res://scripts/dialogue_manager.gd")
const StoryState = preload("res://scripts/story_state.gd")
const InventoryManager = preload("res://scripts/inventory_manager.gd")
const VendorService = preload("res://scripts/vendor_service.gd")
const CraftingManager = preload("res://scripts/crafting_manager.gd")
const CombatManager = preload("res://scripts/combat_manager.gd")
const SaveManager = preload("res://scripts/save_manager.gd")
const SettingsManager = preload("res://scripts/settings_manager.gd")
const WorldMaterialLibrary = preload("res://scripts/world_material_library.gd")
const DayNightController = preload("res://scripts/day_night_controller.gd")
const AudioManager = preload("res://scripts/audio_manager.gd")
const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const HUD = preload("res://scripts/hud.gd")
const MinigameManager = preload("res://scripts/minigame_manager.gd")
const ProgressionManager = preload("res://scripts/progression_manager.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const InteractionFocusService = preload("res://scripts/interaction_focus_service.gd")
const MobileTouchControls = preload("res://scripts/mobile_touch_controls.gd")
const ZoneStreamingService = preload("res://scripts/zone_streaming_service.gd")
const RuntimePackManager = preload("res://scripts/runtime_pack_manager.gd")

const REQUIRED_SERVICES := [
	"story_state", "quests", "quest_presentation", "quest_beats", "dialogue", "inventory", "vendor_service", "crafting", "combat",
	"save_manager", "settings", "world_materials", "day_night", "audio",
	"asset_helper", "hud", "minigames", "progression", "input_router", "interaction_focus", "mobile_touch", "zone_streaming", "runtime_packs"
]

var services: Dictionary = {}
var configured := false

func create_services() -> Dictionary:
	assert(services.is_empty(), "Runtime services may only be created once")
	services = {
		"story_state": StoryState.new(),
		"quests": QuestManager.new(),
		"quest_presentation": QuestPresentationState.new(),
		"quest_beats": QuestBeatDirector.new(),
		"dialogue": DialogueManager.new(),
		"inventory": InventoryManager.new(),
		"vendor_service": VendorService.new(),
		"crafting": CraftingManager.new(),
		"combat": CombatManager.new(),
		"save_manager": SaveManager.new(),
		"settings": SettingsManager.new(),
		"world_materials": WorldMaterialLibrary.new(),
		"day_night": DayNightController.new(),
		"audio": AudioManager.new(),
		"asset_helper": AssetSpawnHelper.new(),
		"hud": HUD.new(),
		"minigames": MinigameManager.new(),
		"progression": ProgressionManager.new(),
		"input_router": InputRouter.new(),
		"interaction_focus": InteractionFocusService.new(),
		"mobile_touch": MobileTouchControls.new(),
		"zone_streaming": ZoneStreamingService.new(),
		"runtime_packs": RuntimePackManager.new(),
	}
	for id in REQUIRED_SERVICES:
		var service: Node = services[id]
		service.name = _service_node_name(id)
		add_child(service)
	assert(is_complete(), "Runtime service registry is incomplete")
	return services

func configure(owner: Node) -> void:
	assert(not configured, "Runtime services may only be configured once")
	assert(is_complete(), "Runtime services must exist before configuration")
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

	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	quests.load_quests("res://data/quests.json")
	quest_presentation.setup(quests)
	quest_beats.setup(quests, story_state)
	dialogue.load_dialogue("res://data/dialogue.json")
	dialogue.load_dialogue("res://data/campaign_dialogue.json")
	dialogue.setup(story_state, quests)
	inventory.load_items("res://data/items.json")
	vendor_service.load_vendors("res://data/vendors.json")
	crafting.setup(inventory, quests, story_state)
	input_router.install_default_actions()
	input_router.set_settings_manager(settings)
	input_router.apply_settings(settings.settings)
	interaction_focus.setup(quests)
	hud.set_input_source(input_router)
	minigames.setup(input_router)
	mobile_touch.setup(input_router, hud, settings.settings)
	zone_streaming.setup(owner)
	# The base manager is embedded in the main PCK. On Web, begin the verified
	# opening downloads immediately so the menu and Crow Flight can cover the
	# only unavoidable cold-cache wait. Desktop keeps the full project local.
	if runtime_packs.has_method("request_pack"):
		if runtime_packs.has_signal("pack_mounted") and audio.has_method("set_runtime_file_assets_available"):
			runtime_packs.pack_mounted.connect(func(pack_id: String, _path: String):
				if pack_id == "audio":
					audio.set_runtime_file_assets_available(true)
			)
		runtime_packs.request_pack("base")
		if OS.has_feature("web") and runtime_packs.has_method("request_startup_packs"):
			runtime_packs.request_startup_packs()
	settings.apply_platform_defaults(mobile_touch.touch_capable)
	input_router.device_changed.connect(func(_device: String):
		hud.set_input_device(input_router.active_device)
		owner.call("_refresh_equipment_readout")
	)
	input_router.gamepad_profile_changed.connect(func(profile: Dictionary):
		hud.set_input_device(input_router.active_device)
		if hud.has_method("set_gamepad_profile"):
			hud.set_gamepad_profile(profile)
		owner.call("_refresh_equipment_readout")
	)
	input_router.gamepad_disconnected.connect(func(_device_id: int):
		hud.set_input_device(input_router.active_device)
		hud.toast("Controller disconnected. Keyboard and mouse input is ready.")
		hud.restore_input_focus()
	)

	day_night.time_changed.connect(func(minutes: float, phase: String, count: int):
		var director = owner.get("visual_director")
		if director != null:
			director.set_time(minutes, phase, count)
	)
	settings.changed.connect(func(current: Dictionary):
		input_router.apply_settings(current)
		mobile_touch.apply_settings(current)
		owner.call("_apply_runtime_settings", current)
	)
	hud.launch_accepted.connect(Callable(owner, "_on_launch_accepted"))
	hud.menu_hovered.connect(func(): audio.play_event("menu_hover", 0.025))
	hud.menu_clicked.connect(func(): audio.play_event("menu_click", 0.015))
	hud.new_game_requested.connect(Callable(owner, "_new_game"))
	hud.quit_requested.connect(Callable(owner, "_handle_quit_request"))
	hud.continue_requested.connect(func():
		audio.play_event("ui")
		if not save_manager.load_game(owner):
			save_manager.load_game(owner, save_manager.AUTOSAVE_PATH)
	)
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
		hud.show_inventory(inventory, quests, story_state, progression)
	)
	hud.vendor_purchase_requested.connect(func(vendor_id: String, item_id: String, quantity: int):
		owner.call("_purchase_from_vendor", vendor_id, item_id, quantity)
		hud.show_vendor(vendor_id, vendor_service, inventory, quests, story_state)
	)
	hud.resume_requested.connect(Callable(owner, "_resume_game"))
	hud.settings_requested.connect(Callable(owner, "_handle_setting"))
	hud.action_selected.connect(Callable(owner, "_handle_dialogue_action"))
	hud.dialogue_closed.connect(Callable(owner, "_release_dialogue_facing"))
	hud.dialogue_closed.connect(Callable(owner, "_on_dialogue_closed_audio"))
	hud.dialogue_page_changed.connect(Callable(owner, "_on_dialogue_page_changed"))
	hud.craft_requested.connect(func(item_id: String):
		crafting.craft(item_id)
		hud.show_inventory(inventory, quests, story_state, progression)
	)
	hud.item_use_requested.connect(func(item_id: String):
		owner.call("_use_inventory_item", item_id)
		hud.show_inventory(inventory, quests, story_state, progression)
	)
	hud.upgrade_requested.connect(func(upgrade_id: String):
		if progression.unlock(upgrade_id):
			owner.call("_apply_progression_to_player")
			save_manager.autosave(owner)
		hud.show_inventory(inventory, quests, story_state, progression)
	)
	quests.changed.connect(Callable(owner, "_refresh_tracker"))
	quests.message.connect(Callable(hud, "toast"))
	quests.message.connect(func(_text: String): audio.play_event("quest"))
	quests.quest_completed.connect(Callable(owner, "_on_quest_completed"))
	inventory.message.connect(Callable(hud, "toast"))
	inventory.changed.connect(Callable(owner, "_refresh_equipment_readout"))
	vendor_service.message.connect(Callable(hud, "toast"))
	vendor_service.changed.connect(Callable(owner, "_refresh_equipment_readout"))
	save_manager.message.connect(Callable(hud, "toast"))
	progression.message.connect(Callable(hud, "toast"))
	combat.message.connect(Callable(hud, "toast"))
	combat.enemy_hit.connect(func(name: String, amount: float):
		hud.show_status_cue("Hit: %d" % int(amount), "item")
		owner.call("_hitstop", 0.045)
	)
	combat.impact.connect(Callable(owner, "_on_combat_impact"))
	minigames.result.connect(Callable(owner, "_on_minigame_result"))
	minigames.closed.connect(func(): hud.toast("The village carries on."))
	settings.apply()
	owner.call("_apply_runtime_settings", settings.settings)

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
