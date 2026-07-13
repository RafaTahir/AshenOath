extends RefCounted

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

const REQUIRED_SERVICES := [
	"story_state", "quests", "dialogue", "inventory", "crafting", "combat",
	"save_manager", "settings", "world_materials", "day_night", "audio",
	"asset_helper", "hud", "minigames"
]

static func create(owner: Node) -> Dictionary:
	var services := {
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
	}
	services["settings"].name = "SettingsManager"
	services["world_materials"].name = "WorldMaterialLibrary"
	services["day_night"].name = "DayNightController"
	for id in REQUIRED_SERVICES:
		owner.add_child(services[id])
	return services

static func is_complete(services: Dictionary) -> bool:
	for id in REQUIRED_SERVICES:
		if not services.has(id) or services[id] == null:
			return false
	return true
