extends Node

const QuestManager = preload("res://scripts/quest_manager.gd")
const DialogueManager = preload("res://scripts/dialogue_manager.gd")
const StoryState = preload("res://scripts/story_state.gd")
const InventoryManager = preload("res://scripts/inventory_manager.gd")
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

const REQUIRED_SERVICES := [
	"story_state", "quests", "dialogue", "inventory", "crafting", "combat",
	"save_manager", "settings", "world_materials", "day_night", "audio",
	"asset_helper", "hud", "minigames", "progression"
]

var services: Dictionary = {}
var configured := false

func create_services() -> Dictionary:
	assert(services.is_empty(), "Runtime services may only be created once")
	services = {
		"story_state": StoryState.new(),
		"quests": QuestManager.new(),
		"dialogue": DialogueManager.new(),
		"inventory": InventoryManager.new(),
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
	var dialogue = services["dialogue"]
	var inventory = services["inventory"]
	var crafting = services["crafting"]
	var combat = services["combat"]
	var save_manager = services["save_manager"]
	var settings = services["settings"]
	var day_night = services["day_night"]
	var audio = services["audio"]
	var hud = services["hud"]
	var minigames = services["minigames"]
	var progression = services["progression"]

	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	quests.load_quests("res://data/quests.json")
	dialogue.load_dialogue("res://data/dialogue.json")
	dialogue.load_dialogue("res://data/campaign_dialogue.json")
	dialogue.setup(story_state)
	inventory.load_items("res://data/items.json")
	crafting.setup(inventory, quests, story_state)

	day_night.time_changed.connect(func(minutes: float, phase: String, count: int):
		var director = owner.get("visual_director")
		if director != null:
			director.set_time(minutes, phase, count)
	)
	settings.changed.connect(func(current: Dictionary): owner.call("_apply_runtime_settings", current))
	hud.launch_accepted.connect(Callable(owner, "_on_launch_accepted"))
	hud.menu_hovered.connect(func(): audio.play_event("menu_hover", 0.025))
	hud.menu_clicked.connect(func(): audio.play_event("menu_click", 0.015))
	hud.new_game_requested.connect(Callable(owner, "_new_game"))
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
	hud.resume_requested.connect(Callable(owner, "_resume_game"))
	hud.settings_requested.connect(Callable(owner, "_handle_setting"))
	hud.action_selected.connect(Callable(owner, "_handle_dialogue_action"))
	hud.dialogue_closed.connect(Callable(owner, "_release_dialogue_facing"))
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
