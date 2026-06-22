extends Node3D

const PlayerController = preload("res://scripts/player_controller.gd")
const CameraController = preload("res://scripts/camera_controller.gd")
const EnemyAI = preload("res://scripts/enemy_ai.gd")
const Interactable = preload("res://scripts/interactable.gd")
const QuestManager = preload("res://scripts/quest_manager.gd")
const DialogueManager = preload("res://scripts/dialogue_manager.gd")
const InventoryManager = preload("res://scripts/inventory_manager.gd")
const CraftingManager = preload("res://scripts/crafting_manager.gd")
const CombatManager = preload("res://scripts/combat_manager.gd")
const SaveManager = preload("res://scripts/save_manager.gd")
const SettingsManager = preload("res://scripts/settings_manager.gd")
const AudioManager = preload("res://scripts/audio_manager.gd")
const HUD = preload("res://scripts/hud.gd")
const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const VisualDirector = preload("res://scripts/visual_director.gd")
const NpcAmbient = preload("res://scripts/npc_ambient.gd")
const CharacterPresentation = preload("res://scripts/character_presentation.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")

var player
var camera_rig
var hud
var quests
var dialogue
var inventory
var crafting
var combat
var save_manager
var settings
var audio
var asset_helper
var visual_director
var zone_root: Node3D
var active_interactable
var current_zone_id = "greyfen"
var enemy_defs = {}
var active_enemies: Array = []
var ghoulkin_kills = 0
var game_started = false
var paused_by_menu = true
var pending_ending = ""
var removed_interactions = {}
var autosave_cooldown = 0.0
var last_safe_player_position = Vector3(0, 1, 7)
var tutorial_flags = {}
var material_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_map()
	_build_global_environment()
	_setup_managers()
	hud.show_launch_screen()
	audio.set_music_state("main_menu")
	get_tree().paused = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			_play_voice_smoke_test("voice_sister_anwen_test", "AUDIO: voice_sister_anwen_test")
		elif event.keycode == KEY_B:
			_play_voice_smoke_test("voice_player_test", "AUDIO: voice_player_test")

func _unhandled_input(event: InputEvent) -> void:
	if not game_started:
		return
	if event.is_action_pressed("pause"):
		if get_tree().paused:
			_resume_game()
		else:
			_pause_game()
	elif event.is_action_pressed("interact") and active_interactable != null and not get_tree().paused:
		_handle_interaction(active_interactable)
	elif event.is_action_pressed("open_inventory") and not get_tree().paused:
		get_tree().paused = true
		hud.show_inventory(inventory, quests)

func _process(delta: float) -> void:
	if not game_started or player == null or get_tree().paused:
		return
	_keep_player_in_world()
	_update_tutorial_prompts()
	autosave_cooldown = max(autosave_cooldown - delta, 0.0)
	if autosave_cooldown <= 0.0:
		autosave_cooldown = 45.0
		save_manager.autosave(self)
	_update_compass()

func _play_voice_smoke_test(voice_id: String, label: String) -> void:
	if audio == null:
		return
	audio.play_voice(voice_id)
	print(label)
	if hud != null:
		hud.toast(label)

func _setup_managers() -> void:
	quests = QuestManager.new()
	dialogue = DialogueManager.new()
	inventory = InventoryManager.new()
	crafting = CraftingManager.new()
	combat = CombatManager.new()
	save_manager = SaveManager.new()
	settings = SettingsManager.new()
	settings.name = "SettingsManager"
	audio = AudioManager.new()
	asset_helper = AssetSpawnHelper.new()
	hud = HUD.new()
	for manager in [quests, dialogue, inventory, crafting, combat, save_manager, settings, audio, asset_helper, hud]:
		add_child(manager)
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	quests.load_quests("res://data/quests.json")
	dialogue.load_dialogue("res://data/dialogue.json")
	inventory.load_items("res://data/items.json")
	crafting.setup(inventory, quests)
	enemy_defs = _read_json("res://data/enemies.json")
	settings.apply()
	settings.changed.connect(_apply_runtime_settings)
	_apply_runtime_settings(settings.settings)
	hud.launch_accepted.connect(_on_launch_accepted)
	hud.menu_hovered.connect(func(): audio.play_event("menu_hover", 0.025))
	hud.menu_clicked.connect(func(): audio.play_event("menu_click", 0.015))
	hud.new_game_requested.connect(_new_game)
	hud.continue_requested.connect(func():
		audio.play_event("ui")
		if not save_manager.load_game(self):
			save_manager.load_game(self, SaveManager.AUTOSAVE_PATH)
	)
	hud.save_requested.connect(func():
		audio.play_event("ui")
		save_manager.save_game(self)
	)
	hud.load_requested.connect(func():
		audio.play_event("ui")
		save_manager.load_game(self)
	)
	hud.load_checkpoint_requested.connect(func():
		audio.play_event("ui")
		save_manager.load_checkpoint(self)
	)
	hud.resume_requested.connect(_resume_game)
	hud.settings_requested.connect(_handle_setting)
	hud.action_selected.connect(_handle_dialogue_action)
	hud.dialogue_closed.connect(func(): audio.stop_voice())
	hud.craft_requested.connect(func(item_id: String):
		crafting.craft(item_id)
		hud.show_inventory(inventory, quests)
	)
	hud.item_use_requested.connect(func(item_id: String):
		_use_inventory_item(item_id)
		hud.show_inventory(inventory, quests)
	)
	quests.changed.connect(_refresh_tracker)
	quests.message.connect(hud.toast)
	quests.message.connect(func(_text: String): audio.play_event("quest"))
	quests.quest_completed.connect(_on_quest_completed)
	inventory.message.connect(hud.toast)
	inventory.changed.connect(_refresh_equipment_readout)
	save_manager.message.connect(hud.toast)
	combat.message.connect(hud.toast)
	combat.enemy_hit.connect(func(name: String, amount: float):
		hud.show_status_cue("Hit: %d" % int(amount), "item")
		_hitstop(0.045)
	)
	combat.impact.connect(_on_combat_impact)

func _new_game() -> void:
	game_started = true
	paused_by_menu = false
	ghoulkin_kills = 0
	tutorial_flags.clear()
	current_zone_id = "greyfen"
	get_tree().paused = false
	hud.hide_menus()
	quests.start_quest("main_road_of_crows")
	_spawn_player(Vector3(0, 1, 7))
	_load_zone("greyfen", Vector3(0, 1, 7))
	hud.toast("Greyfen whispers about the old road. Sister Anwen is waiting at the shrine.")
	hud.set_guidance_hint("E - Speak to Sister Anwen", 5.5)
	_refresh_tracker()
	_refresh_equipment_readout()
	save_manager.checkpoint(self)

func load_save_state(data: Dictionary) -> void:
	game_started = true
	get_tree().paused = false
	hud.hide_menus()
	if player == null:
		_spawn_player(Vector3(0, 1, 7))
	inventory.load_state(data.get("inventory", {}))
	quests.load_state(data.get("quests", {}))
	load_world_state(data.get("world_state", {}))
	player.health_component.load_state(data.get("player_health", {}))
	player.stamina_component.load_state(data.get("player_stamina", {}))
	var zone = str(data.get("zone", "greyfen"))
	var pos_array: Array = data.get("player_position", [0, 1, 7])
	var pos = Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
	_load_zone(zone, pos)
	_refresh_tracker()
	_refresh_equipment_readout()

func _spawn_player(pos: Vector3) -> void:
	if player != null:
		player.queue_free()
	if camera_rig != null:
		camera_rig.queue_free()
	player = PlayerController.new()
	add_child(player)
	player.global_position = pos
	camera_rig = CameraController.new()
	add_child(camera_rig)
	camera_rig.setup(player)
	camera_rig.set_zone(current_zone_id)
	_apply_runtime_settings(settings.settings)
	player.camera_controller = camera_rig
	player.attack_performed.connect(_on_player_attack)
	player.potion_requested.connect(_use_potion)
	player.bomb_requested.connect(_throw_bomb)
	player.footstep.connect(_on_player_footstep)
	player.parried.connect(_on_player_parried)
	player.blocked.connect(_on_player_blocked)
	player.hurt.connect(_on_player_hurt)
	player.stamina_exhausted.connect(_on_player_stamina_exhausted)
	player.died.connect(_on_player_died)
	player.health_component.changed.connect(hud.update_health)
	player.stamina_component.changed.connect(hud.update_stamina)
	hud.update_health(player.health_component.health, player.health_component.max_health)
	hud.update_stamina(player.stamina_component.stamina, player.stamina_component.max_stamina)

func _load_zone(zone_id: String, spawn_pos: Vector3 = Vector3.ZERO) -> void:
	current_zone_id = zone_id
	if camera_rig != null and camera_rig.has_method("set_zone"):
		camera_rig.set_zone(zone_id)
	active_interactable = null
	active_enemies.clear()
	hud.set_prompt("")
	if zone_root != null:
		zone_root.queue_free()
	zone_root = Node3D.new()
	zone_root.name = zone_id
	add_child(zone_root)
	if zone_id == "greyfen":
		_build_greyfen()
	elif zone_id == "wychwood":
		_build_wychwood()
	elif zone_id == "ruins":
		_build_ruins()
	_apply_first_route_materials(zone_root)
	if visual_director != null:
		visual_director.apply_zone(zone_id)
	if audio != null:
		audio.play_ambient(zone_id)
		audio.set_music_state("wychwood_tension" if zone_id == "wychwood" else "greyfen_explore")
		if zone_id == "greyfen":
			audio.play_event("shrine_hum", 0.01)
	if player != null:
		player.global_position = spawn_pos
		player.velocity = Vector3.ZERO
		last_safe_player_position = spawn_pos
	if game_started:
		save_manager.autosave(self)
	if zone_id == "wychwood" and quests.is_active("main_road_of_crows") and not quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
		audio.play_event("reveal", 0.02)
		audio.play_event("wychwood_tension", 0.01)
		audio.set_music_state("wychwood_tension")
		hud.toast("The woods go quiet. Survive the Ghoulkin.")
		hud.set_guidance_hint("Left click strike | Space dodge | Q block/parry", 6.0)
		hud.show_status_cue("Survive the clearing", "neutral")

func _build_greyfen() -> void:
	_make_ground(Vector3(0, -0.08, 0), Vector3(42, 0.16, 34), Color(0.16, 0.18, 0.13))
	_make_greyfen_terrain_layers()
	_make_play_area_bounds(42, 34, Color(0.09, 0.12, 0.08))
	_make_road(Vector3(0, 0.018, 0), Vector3(4.2, 0.04, 30.0), Color(0.16, 0.13, 0.09))
	_make_road(Vector3(-5, 0.02, 5), Vector3(14.0, 0.04, 3.0), Color(0.15, 0.12, 0.085))
	_make_greyfen_path_edges()
	_make_light("Village Warmth", Vector3(-1.5, 5.2, 2), Color(1.0, 0.58, 0.30), 3.0)
	_make_light("Blue Dusk Fill", Vector3(9, 6, -10), Color(0.34, 0.42, 0.58), 2.8)
	_make_light("Shrine Beacon", Vector3(4.8, 4.8, -5.4), Color(0.70, 0.86, 0.60), 3.0)
	_make_light("Wychwood Gate Lantern", Vector3(0, 3.2, -14.3), Color(1.0, 0.48, 0.16), 2.2)
	_make_fog_sheet(Vector3(0, 1.1, -12), Vector3(18, 1, 5), Color(0.18, 0.22, 0.22, 0.12))
	_make_tree_wall(20.0, 15.2, 7, true)
	_make_tree_wall(20.0, -15.2, 7, true)
	_make_village_house_dressed(Vector3(-5,0,-3), 8.0, "DressedVillageHouse_WestLane")
	_make_village_house_dressed(Vector3(7,0,1), -18.0, "DressedVillageHouse_EastLane")
	_make_village_house_dressed(Vector3(-10,0,8), 24.0, "DressedVillageHouse_SpawnFrame")
	_make_village_house_dressed(Vector3(11.8,0,-7.8), -42.0, "DressedVillageHouse_ShrineFrame")
	for pos in [Vector3(-5.3, 0, 3.4), Vector3(4.8, 0, -5.3), Vector3(-9.3, 0, 11.2)]:
		_make_torch(pos)
	for x in [-17, -13, -9, -5, 5, 9, 13, 17]:
		_make_fence(Vector3(x, 0.35, 14), false)
		_make_fence(Vector3(x, 0.35, -14), false)
	for z in [-10, -6, -2, 2, 6, 10]:
		_make_fence(Vector3(-19, 0.35, z), true)
		_make_fence(Vector3(19, 0.35, z), true)
	_make_notice_board(Vector3(-2.0, 0, 9.4))
	_make_shrine_scene(Vector3(6.0, 0, -7.0))
	_make_blacksmith_scene(Vector3(9.5, 0, 4.6))
	_make_cemetery_scene(Vector3(14, 0, 8.6))
	_make_cart(Vector3(-6.2, 0, 5.8))
	_make_village_dressing()
	_make_greyfen_first_impression_dressing()
	_make_quality_greyfen_overhaul()
	_make_spawn_composition()
	_make_tree_cluster([Vector3(-16,0,-12), Vector3(-14,0,12), Vector3(16,0,-11), Vector3(15,0,13), Vector3(0,0,15)])
	_make_named_interactable("notice_board", "dialogue", "Read notice board", Vector3(-2, 0, 9.4), Color(0.48, 0.28, 0.12), Vector3(0.45, 0.45, 0.45))
	_make_named_interactable("sister_anwen", "dialogue", "Talk to Sister Anwen", Vector3(3.2, 0, -5.0), Color(0.34, 0.35, 0.48))
	_make_named_interactable("mira", "dialogue", "Talk to Mira Fen", Vector3(-6.8, 0, -2.3), Color(0.22, 0.48, 0.32), Vector3(0.62, 0.62, 0.62))
	_make_named_interactable("rook", "dialogue", "Talk to Rook", Vector3(-7.8, 0, 8.5), Color(0.42, 0.33, 0.23), Vector3(0.62, 0.62, 0.62))
	_make_named_interactable("widow_elna", "dialogue", "Talk to Widow Elna", Vector3(13.0, 0, 7.0), Color(0.32, 0.30, 0.42), Vector3(0.54, 0.54, 0.54))
	_make_named_interactable("blacksmith_tor", "dialogue", "Talk to Blacksmith Tor", Vector3(9.5, 0, 3.0), Color(0.43, 0.37, 0.31), Vector3(0.54, 0.54, 0.54))
	_make_named_interactable("farmer_toma", "dialogue", "Talk to Farmer Toma", Vector3(12, 0, -9), Color(0.39, 0.30, 0.18), Vector3(0.46, 0.46, 0.46))
	_make_clue("grave_bell", "Inspect grave bell", Vector3(15.8, 0, 9.5), "side_widows_bell", "inspect_bell", Color(0.60, 0.55, 0.44))
	_make_clue("sheepfold", "Inspect sheepfold", Vector3(15, 0, -11), "side_black_dog", "inspect_sheepfold", Color(0.36, 0.24, 0.16))
	_make_zone_gate("To Wychwood", Vector3(0, 0, -15.2), "wychwood", Vector3(0, 1, 13))
	_make_wychwood_gate_scene(Vector3(0, 0, -14.3))
	_make_route_markers()
	_make_greyfen_road_of_crows_story_beats()
	_make_collapsed_road(Vector3(18.0, 0, 0))
	_make_blocked_gate("Road to Castle Vargan", Vector3(17.5, 0, 0), "Castle Vargan is blocked for this vertical slice. The contract trail runs north into Wychwood.")

func _build_wychwood() -> void:
	_make_ground(Vector3(0, -0.08, 0), Vector3(44, 0.16, 34), Color(0.065, 0.105, 0.07))
	_make_wychwood_terrain_layers()
	_make_play_area_bounds(44, 34, Color(0.04, 0.075, 0.045))
	_make_road(Vector3(0, 0.018, 3), Vector3(4.0, 0.04, 27.0), Color(0.065, 0.075, 0.052))
	_make_road(Vector3(6, 0.019, -8), Vector3(10.0, 0.04, 3.0), Color(0.055, 0.065, 0.05))
	_make_wychwood_path_edges()
	_make_light("Moon Shaft", Vector3(0, 6.6, -7), Color(0.48, 0.58, 0.78), 4.2)
	_make_light("Sick Green Bounce", Vector3(9, 3.2, -9), Color(0.25, 0.42, 0.28), 1.7)
	_make_light("Trail Threat", Vector3(0, 2.4, -2.8), Color(0.42, 0.68, 0.62), 1.4)
	_make_fog_sheet(Vector3(0, 1.0, -6), Vector3(24, 1, 8), Color(0.24, 0.30, 0.28, 0.20))
	_make_fog_sheet(Vector3(-10, 0.8, 5), Vector3(14, 1, 5), Color(0.16, 0.24, 0.18, 0.16))
	_make_tree_wall(21.0, 15.2, 9, true)
	_make_tree_wall(21.0, -15.2, 9, true)
	_make_tree_wall(16.0, -20.0, 7, false)
	_make_tree_wall(16.0, 20.0, 7, false)
	_make_tree_cluster([
		Vector3(-18,0,-12), Vector3(-15,0,-6), Vector3(-16,0,7), Vector3(-13,0,13),
		Vector3(16,0,-12), Vector3(18,0,-5), Vector3(17,0,5), Vector3(14,0,13),
		Vector3(-8,0,-14), Vector3(8,0,14), Vector3(-4,0,15), Vector3(5,0,-15)
	])
	for pos in [Vector3(-8,0,-3), Vector3(6.7,0,-9.2), Vector3(9.8,0,-12.0), Vector3(-5,0,9.8)]:
		_make_deadfall(pos)
	_make_wychwood_route_dressing()
	_make_wychwood_corridor()
	_make_quality_wychwood_overhaul()
	for pos in [Vector3(6.8,0,-10.2), Vector3(8.5,0,-11.6), Vector3(10.0,0,-9.8), Vector3(8.5,0,-8.1)]:
		_make_ritual_stone(pos)
	_make_monster_clearing(Vector3(0, 0, -6.5))
	_make_wychwood_road_of_crows_story_beats()
	_make_zone_gate("Back to Greyfen", Vector3(0, 0, 15), "greyfen", Vector3(0, 1, -13))
	_make_clue("corpse", "Inspect blood-dark corpse", Vector3(-2, 0, 7.4), "main_road_of_crows", "inspect_corpse", Color(0.32, 0.18, 0.16))
	_make_clue("claw_marks", "Read strange claw marks", Vector3(2.5, 0, 4.8), "main_road_of_crows", "find_claw_marks", Color(0.18, 0.18, 0.18))
	_make_clue("black_feathers", "Take black feathers", Vector3(-4, 0, 2), "main_road_of_crows", "find_black_feathers", Color(0.03, 0.03, 0.035))
	_make_clue("tracks", "Inspect dragged tracks", Vector3(0, 0, -3), "main_road_of_crows", "return_village", Color(0.15, 0.11, 0.08))
	_make_clue("ritual_stones", "Study ritual stones", Vector3(8, 0, -10), "main_teeth_in_rain", "discover_stones", Color(0.38, 0.38, 0.36))
	_make_clue("vargan_signet", "Take signet ring", Vector3(11, 0, -12), "main_teeth_in_rain", "find_signet", Color(0.72, 0.56, 0.24))
	_make_clue("bandit_camp", "Inspect bandit camp", Vector3(-12, 0, -12), "side_black_dog", "find_bandit_camp", Color(0.30, 0.18, 0.10))
	_make_clue("bitter_roots", "Collect bitter roots", Vector3(8, 0, -7.8), "side_bitter_roots", "collect_roots", Color(0.46, 0.22, 0.16))
	_make_clue("sacrifice_roots", "Study sacrifice roots", Vector3(10, 0, -9.2), "side_bitter_roots", "learn_mira_past", Color(0.38, 0.16, 0.13))
	_make_herb("mooncap", Vector3(-7, 0, -6), Color(0.58, 0.65, 0.86))
	_make_herb("redroot", Vector3(-10, 0, -2), Color(0.55, 0.12, 0.11))
	_make_herb("grave_moss", Vector3(5, 0, -13), Color(0.24, 0.42, 0.24))
	if quests.is_active("main_road_of_crows") and not quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
		_spawn_enemy("ghoulkin", Vector3(-2.4, 0.8, -8.8))
		_spawn_enemy("ghoulkin", Vector3(2.7, 0.8, -9.6))
	if quests.is_active("main_teeth_in_rain") and not quests.is_objective_done("main_teeth_in_rain", "fight_bog_wretch"):
		_spawn_enemy("bog_wretch", Vector3(11, 0.8, -12))
	if quests.is_active("side_black_dog") and not quests.is_objective_done("side_black_dog", "deal_bandits"):
		_spawn_enemy("bandit", Vector3(-14, 0.8, -14))
		_spawn_enemy("bandit", Vector3(-12, 0.8, -15))

func _build_ruins() -> void:
	_make_ground(Vector3(0, -0.08, 0), Vector3(48, 0.16, 42), Color(0.13, 0.13, 0.13))
	_make_road(Vector3(-5, 0.018, 3), Vector3(24.0, 0.04, 4.0), Color(0.09, 0.08, 0.075))
	_make_light("Ruin Fire", Vector3(-4, 4, -5), Color(0.9, 0.42, 0.22), 4.0)
	_make_torch(Vector3(-6.5, 0, -4.5))
	_make_torch(Vector3(6.5, 0, -4.0))
	for pos in [Vector3(-8,0,-5), Vector3(0,0,-8), Vector3(8,0,-4), Vector3(0,0,8)]:
		_make_prop_box("BrokenWall", pos + Vector3(0,1,0), Vector3(5,2,0.7), Color(0.24,0.24,0.23))
	for pos in [Vector3(-10,0,-10), Vector3(-5,0,-11), Vector3(5,0,-11), Vector3(10,0,-10), Vector3(-10,0,7), Vector3(10,0,7)]:
		_make_pillar(pos)
	for pos in [Vector3(-1,0,-6.5), Vector3(1,0,-6.2), Vector3(3,0,-6.8)]:
		_make_rubble(pos)
	_make_zone_gate("Back to Greyfen", Vector3(-20, 0, 5), "greyfen", Vector3(17, 1, -2))
	_make_named_interactable("edric", "dialogue", "Talk to Lord Edric", Vector3(-14, 0, 3), Color(0.44, 0.35, 0.24))
	_make_clue("old_hall", "Search old hall", Vector3(-2, 0, -4), "main_blood_under_stone", "search_hall", Color(0.28, 0.24, 0.21))
	_make_clue("ritual_inscription", "Read ritual inscription", Vector3(4, 0, -8), "main_blood_under_stone", "read_inscription", Color(0.43, 0.39, 0.35))
	_make_clue("spirit_clearing", "Enter spirit clearing", Vector3(10, 0, 8), "main_hart_remembers", "enter_clearing", Color(0.70, 0.72, 0.66))
	if quests.is_active("main_blood_under_stone") and not quests.is_objective_done("main_blood_under_stone", "fight_knight"):
		_spawn_enemy("gravebound_knight", Vector3(3, 0.8, -3))
	if quests.is_active("main_hart_remembers") or quests.is_unlocked("main_hart_remembers"):
		_make_named_interactable("white_hart", "dialogue", "Speak to the White Hart", Vector3(12, 0, 10), Color(0.86, 0.83, 0.70), Vector3(0.9, 1.6, 0.9))

func _handle_interaction(area) -> void:
	if area.interaction_type == "dialogue":
		var dialogue_data = dialogue.get_dialogue(area.dialogue_id)
		var played_report_voice = false
		if area.interaction_id == "sister_anwen" and not bool(tutorial_flags.get("anwen_talked", false)):
			tutorial_flags["anwen_talked"] = true
			quests.complete_objective("main_road_of_crows", "speak_anwen")
			audio.set_music_state("shrine_anwen")
			hud.toast("Anwen named the signs before you found them. Follow the old road north.")
			hud.set_guidance_hint("Follow the lanterns to Wychwood. Find the cart, marks, and feathers.", 6.0)
		elif area.interaction_id == "sister_anwen" and _road_ready_to_report():
			quests.complete_objective("main_road_of_crows", "return_village")
			audio.play_event("return_report", 0.02)
			audio.play_voice("voice_sister_anwen_report_01")
			played_report_voice = true
			audio.set_music_state("return_report")
			hud.show_status_cue("Anwen knows the sign", "victory")
			hud.toast("Anwen goes still at the feathers. 'Then it was called here,' she says, and will say no more.")
		_stage_dialogue_moment(area)
		get_tree().paused = true
		hud.show_dialogue(dialogue_data)
		if dialogue_data.has("voice") and not played_report_voice:
			audio.play_voice_sequence(dialogue_data.get("voice", []))
	elif area.interaction_type == "clue":
		if area.quest_id == "main_road_of_crows":
			_handle_road_of_crows_clue(area)
		else:
			quests.complete_objective(area.quest_id, area.objective_id)
		if area.interaction_id == "tracks":
			if quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
				hud.toast("The tracks change after the Ghoulkin falls: boots beside claws, both leading back toward Greyfen.")
				hud.set_guidance_hint("Return to Greyfen. Report to Sister Anwen.", 5.5)
				audio.play_event("tracks_found", 0.02)
				audio.play_voice("voice_player_return_report_01")
				audio.set_music_state("return_report")
			else:
				hud.toast("Dragged tracks run beside boot prints. Something was led here, not merely hunting.")
				audio.play_voice("voice_player_clue_observation_01")
			audio.play_event("reveal", 0.02)
		elif area.interaction_id == "corpse":
			hud.toast("Old blood in the mud. The body was searched after death, carefully, by human hands.")
		elif area.interaction_id == "claw_marks":
			hud.toast("The claw marks are real, but they cut over wagon ruts. The beast came after the cart stopped.")
		elif area.interaction_id == "black_feathers":
			hud.toast("Black feathers, tied with red thread. A warning, or a prayer left too late.")
		elif area.interaction_id == "ritual_stones":
			quests.complete_objective("main_teeth_in_rain", "enter_deep_wood")
		elif area.interaction_id == "old_hall":
			quests.complete_objective("main_blood_under_stone", "enter_ruins")
		elif area.interaction_id == "grave_bell":
			quests.complete_objective("side_widows_bell", "meet_gravebound")
		elif area.interaction_id == "bandit_camp":
			hud.toast("Boot prints. Rope. A child's torn ribbon. Not a dog's work.")
		elif area.interaction_id == "bitter_roots":
			quests.complete_objective("side_bitter_roots", "accept_mira_roots")
		elif area.interaction_id == "sacrifice_roots":
			hud.toast("The roots drink from old blood. Mira knew this place.")
		_mark_interaction_removed(area)
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
		_load_zone(area.zone_target, area.get_meta("spawn_pos"))
	elif area.interaction_type == "blocked_zone":
		hud.toast(str(area.get_meta("message", "That road is barred tonight.")))

func _handle_road_of_crows_clue(area) -> void:
	if not quests.is_active("main_road_of_crows"):
		return
	match area.interaction_id:
		"corpse":
			quests.complete_objective("main_road_of_crows", "inspect_corpse")
		"claw_marks":
			quests.complete_objective("main_road_of_crows", "inspect_corpse")
			quests.complete_objective("main_road_of_crows", "find_claw_marks")
		"black_feathers":
			quests.complete_objective("main_road_of_crows", "inspect_corpse")
			quests.complete_objective("main_road_of_crows", "find_claw_marks")
			quests.complete_objective("main_road_of_crows", "find_black_feathers")
		"tracks":
			quests.complete_objective("main_road_of_crows", "inspect_corpse")
			quests.complete_objective("main_road_of_crows", "find_claw_marks")
			quests.complete_objective("main_road_of_crows", "find_black_feathers")

func _road_ready_to_report() -> bool:
	return quests.is_active("main_road_of_crows") and quests.is_objective_done("main_road_of_crows", "fight_ghoulkin") and not quests.is_objective_done("main_road_of_crows", "return_village")

func _handle_dialogue_action(action: Dictionary) -> void:
	audio.stop_voice()
	audio.play_event("ui")
	var type = str(action.get("type", ""))
	if type == "start_quest":
		quests.start_quest(action.get("quest", ""))
		if action.get("quest", "") == "main_road_of_crows":
			audio.play_voice("voice_player_accept_contract_01")
	elif type == "complete_objective":
		quests.complete_objective(action.get("quest", ""), action.get("objective", ""))
		if action.get("quest", "") == "main_road_of_crows" and action.get("objective", "") == "speak_anwen":
			hud.show_status_cue("Road of Crows updated", "item")
			hud.set_guidance_hint("Follow the old road: cart, clawed mud, black feathers.", 6.0)
	elif type == "give_ingredients":
		inventory.add_ingredients(action.get("items", {}))
		hud.toast("Supplies added.")
	elif type == "ending":
		_complete_ending(action.get("ending", "expose"))
		return
	get_tree().paused = false
	hud.hide_menus()
	_refresh_tracker()
	if current_zone_id != "":
		_load_zone(current_zone_id, player.global_position)
	save_manager.autosave(self)

func _on_launch_accepted() -> void:
	audio.play_event("ui", 0.0)

func _complete_ending(ending: String) -> void:
	quests.world_flags["ending"] = ending
	quests.complete_objective("main_hart_remembers", "speak_hart")
	if ending == "kill" or ending == "bind":
		pending_ending = ending
		active_interactable = null
		hud.set_prompt("")
		hud.hide_menus()
		get_tree().paused = false
		_remove_interactable("white_hart")
		if not _has_living_enemy("white_hart_avatar"):
			_spawn_enemy("white_hart_avatar", Vector3(12, 0.8, 6))
		audio.play_event("boss", 0.02)
		hud.toast("The White Hart answers with antler, root, and light.")
		return
	_show_ending_consequence(ending)

func _show_ending_consequence(ending: String) -> void:
	quests.world_flags["ending"] = ending
	quests.complete_objective("main_hart_remembers", "final_choice")
	var title = "The Road Between Crowns"
	var body = ""
	if ending == "kill":
		body = "Kael kills the White Hart after a brutal clearing fight. Greyfen survives the season, but the Wychwood fades into gray rot."
	elif ending == "free":
		body = "Kael frees the White Hart. The curse breaks, House Vargan falls, and frightened villagers abandon the old road."
	elif ending == "bind":
		body = "Kael breaks the avatar and binds the White Hart again. Greyfen prospers for now, and his name joins the crime beneath the stones."
	else:
		body = "Kael exposes House Vargan. The village turns on Edric, the spirit remains wounded, and truth finally has witnesses."
	get_tree().paused = true
	hud.show_ending(title, body)
	save_manager.checkpoint(self)

func _on_player_attack(damage: float, radius: float, heavy: bool) -> void:
	var target = _nearest_living_enemy(radius + 1.6)
	if target != null:
		player.face_target(target.global_position)
		hud.show_enemy(target.display_name, target.health_component.health, target.health_component.max_health)
	audio.play_event("heavy" if heavy else "swing")
	combat.resolve_player_attack(player, active_enemies, damage, radius, heavy, inventory.active_oil)

func _on_player_footstep() -> void:
	if audio == null or player == null:
		return
	var on_road = abs(player.global_position.x) < 2.25
	if current_zone_id == "wychwood":
		on_road = abs(player.global_position.x) < 2.5 and player.global_position.z > -12.5
	audio.play_footstep(current_zone_id, on_road)

func _on_player_parried() -> void:
	audio.play_event("parry")
	if camera_rig != null:
		camera_rig.shake(0.18)
	if zone_root != null and player != null:
		CombatFeedback.block_flash(zone_root, player.global_position, true)
		CombatFeedback.ground_ring(zone_root, player.global_position, Color(0.22, 0.46, 0.72), 0.65, 0.16)
	var target = _nearest_living_enemy(2.8)
	if target != null:
		target.stagger(1.0)
		CombatFeedback.impact_burst(zone_root, target.global_position + Vector3(0, 1.0, 0), true, Color(0.74, 0.88, 1.0))
		hud.show_enemy(target.display_name, target.health_component.health, target.health_component.max_health)
		hud.show_status_cue("Parry", "parry")
		hud.toast("Parry breaks %s's guard." % target.display_name)
	tutorial_flags["block_hint_done"] = true
	hud.set_guidance_hint("")

func _on_player_blocked(_amount: float) -> void:
	audio.play_event("block")
	if camera_rig != null:
		camera_rig.shake(0.08)
	if zone_root != null and player != null:
		CombatFeedback.block_flash(zone_root, player.global_position, false)
		CombatFeedback.ground_ring(zone_root, player.global_position, Color(0.58, 0.36, 0.12), 0.45, 0.12)
	hud.show_status_cue("Blocked", "block")
	tutorial_flags["block_hint_done"] = true
	hud.set_guidance_hint("")

func _on_player_hurt(_amount: float) -> void:
	audio.play_event("hurt")
	if camera_rig != null:
		camera_rig.shake(0.14)
	if zone_root != null and player != null:
		CombatFeedback.impact_burst(zone_root, player.global_position + Vector3(0, 1.0, 0), false, Color(0.9, 0.22, 0.12))
	hud.show_status_cue("Hit: -%d" % int(_amount), "hurt")

func _on_player_stamina_exhausted(_action: String) -> void:
	hud.mark_stamina_exhausted()
	hud.set_guidance_hint("Breath is spent. Back away, then strike.", 2.8)

func _use_potion() -> void:
	if inventory.consume("redroot_potion"):
		player.health_component.heal(45.0)
		audio.play_event("potion")
		hud.show_status_cue("Redroot used", "item")
		hud.toast("Redroot warms the blood.")
		_refresh_equipment_readout()
	else:
		hud.show_status_cue("No Redroot", "hurt")

func _throw_bomb() -> void:
	if inventory.consume("ash_bomb"):
		audio.play_event("bomb")
		if camera_rig != null:
			camera_rig.shake(0.12)
		combat.throw_bomb(player, active_enemies, 45.0)
		hud.show_status_cue("Ash Bomb thrown", "item")
		_refresh_equipment_readout()
	else:
		hud.show_status_cue("No Ash Bomb", "hurt")

func _use_inventory_item(item_id: String) -> void:
	if item_id == "redroot_potion":
		_use_potion()
	elif item_id == "bitterleaf_tonic":
		if inventory.consume("bitterleaf_tonic"):
			player.stamina_component.restore(55.0)
			audio.play_event("potion")
			hud.show_status_cue("Bitterleaf used", "item")
			hud.toast("Bitterleaf clears the lungs.")
	elif item_id == "ash_bomb":
		_throw_bomb()
	elif item_id == "moon_oil" or item_id == "rot_oil":
		if int(inventory.items.get(item_id, 0)) <= 0:
			hud.toast("No %s left." % inventory.get_item_name(item_id))
			return
		inventory.active_oil = item_id
		_refresh_equipment_readout()
		hud.show_status_cue("Oil applied", "item")
		hud.toast("%s slicks the blade." % inventory.get_item_name(item_id))
	elif item_id == "iron_trap":
		if inventory.consume("iron_trap"):
			combat.place_trap(player, active_enemies)
			hud.show_status_cue("Iron Trap set", "item")
			_refresh_equipment_readout()

func _on_enemy_died(enemy) -> void:
	audio.play_event("death", 0.05)
	if camera_rig != null:
		camera_rig.shake(0.09)
	if zone_root != null and enemy != null:
		CombatFeedback.ground_ring(zone_root, enemy.global_position, Color(0.12, 0.08, 0.055), 0.9, 0.24)
	if enemy.enemy_id == "ghoulkin":
		ghoulkin_kills += 1
		if ghoulkin_kills >= 2:
			quests.complete_objective("main_road_of_crows", "fight_ghoulkin")
			audio.play_event("victory", 0.03)
			audio.play_music_cue("victory_return_cue", "return_report")
			audio.set_music_state("return_report")
			audio.play_voice("voice_player_ghoulkin_death_01")
			hud.hide_enemy()
			hud.show_status_cue("Ghoulkin slain", "victory")
			hud.set_guidance_hint("Inspect the tracks, then return to Greyfen.", 6.0)
			hud.toast("The Ghoulkin dies too far from its den. Something drew it to the road. Search the tracks.")
			_make_post_ghoulkin_story_clue()
	elif enemy.enemy_id == "bog_wretch":
		quests.complete_objective("main_teeth_in_rain", "fight_bog_wretch")
	elif enemy.enemy_id == "gravebound_knight":
		quests.complete_objective("main_blood_under_stone", "fight_knight")
		if current_zone_id == "ruins" and quests.is_unlocked("main_hart_remembers"):
			_make_named_interactable("white_hart", "dialogue", "Speak to the White Hart", Vector3(12, 0, 10), Color(0.86, 0.83, 0.70), Vector3(0.9, 1.6, 0.9))
	elif enemy.enemy_id == "white_hart_avatar":
		var ending = pending_ending if pending_ending != "" else "kill"
		pending_ending = ""
		_show_ending_consequence(ending)
	elif enemy.enemy_id == "bandit":
		if not _has_living_enemy("bandit"):
			quests.complete_objective("side_black_dog", "deal_bandits")
	if enemy.health_component != null:
		hud.show_enemy(enemy.display_name, 0.0, enemy.health_component.max_health)
	hud.toast("%s slain." % enemy.display_name)
	save_manager.autosave(self)

func _on_enemy_damaged(enemy, current: float, maximum: float) -> void:
	hud.show_enemy(enemy.display_name, current, maximum)
	hud.show_status_cue("Enemy hit", "item")
	if enemy != null and enemy.enemy_id == "ghoulkin":
		audio.play_event("stagger", 0.06)

func _on_enemy_windup_started(enemy) -> void:
	audio.play_event("enemy_windup", 0.02)
	if zone_root != null and enemy != null:
		CombatFeedback.ground_ring(zone_root, enemy.global_position, Color(0.46, 0.05, 0.025), 0.62, 0.18)
	if enemy != null and enemy.health_component != null:
		hud.show_enemy(enemy.display_name, enemy.health_component.health, enemy.health_component.max_health)
	if current_zone_id == "wychwood" and not bool(tutorial_flags.get("block_hint_done", false)):
		hud.set_guidance_hint("Q at the lunge to parry. Hold Q to block.", 4.2)

func _on_enemy_attack_resolved(enemy, parried: bool) -> void:
	if parried:
		return
	audio.play_event("ghoulkin_lunge" if enemy != null and enemy.enemy_id == "ghoulkin" else "hit", 0.04)
	if zone_root != null and enemy != null:
		CombatFeedback.impact_burst(zone_root, enemy.global_position + Vector3(0, 0.8, 0), false, Color(0.85, 0.30, 0.12))
	if enemy != null and enemy.health_component != null:
		hud.show_enemy(enemy.display_name, enemy.health_component.health, enemy.health_component.max_health)

func _on_quest_completed(id: String) -> void:
	var reward = quests.quest_defs.get(id, {}).get("rewards", {})
	if not reward.is_empty():
		inventory.add_reward(reward)
		hud.toast("Reward received for %s." % quests.quest_defs.get(id, {}).get("title", id))
	save_manager.checkpoint(self)

func _on_combat_impact(pos: Vector3, heavy: bool) -> void:
	if audio != null:
		audio.play_event("heavy_hit" if heavy else "light_hit", 0.04)
	if camera_rig != null:
		camera_rig.shake(0.11 if heavy else 0.06)
	_make_hit_spark(pos, heavy)
	if zone_root != null:
		CombatFeedback.ground_ring(zone_root, pos, Color(0.54, 0.36, 0.16), 0.42 if heavy else 0.30, 0.12)

func _hitstop(seconds: float) -> void:
	Engine.time_scale = 0.18
	var timer = get_tree().create_timer(seconds, true, false, true)
	timer.timeout.connect(func(): Engine.time_scale = 1.0)

func _has_living_enemy(enemy_id: String) -> bool:
	for enemy in active_enemies:
		if enemy != null and not enemy.dead and enemy.enemy_id == enemy_id:
			return true
	return false

func _nearest_living_enemy(max_distance: float):
	var best = null
	var best_distance = max_distance
	for enemy in active_enemies:
		if enemy == null or enemy.dead:
			continue
		var dist = enemy.global_position.distance_to(player.global_position)
		if dist < best_distance:
			best_distance = dist
			best = enemy
	return best

func _remove_interactable(id: String) -> void:
	if zone_root == null:
		return
	for child in zone_root.get_children():
		if child.get("interaction_id") == id:
			child.queue_free()

func _mark_interaction_removed(area) -> void:
	removed_interactions["%s:%s" % [current_zone_id, area.interaction_id]] = true

func _is_interaction_removed(id: String) -> bool:
	return bool(removed_interactions.get("%s:%s" % [current_zone_id, id], false))

func save_world_state() -> Dictionary:
	return {
		"removed_interactions": removed_interactions,
		"pending_ending": pending_ending,
		"ghoulkin_kills": ghoulkin_kills
	}

func load_world_state(state: Dictionary) -> void:
	removed_interactions = state.get("removed_interactions", {})
	pending_ending = str(state.get("pending_ending", ""))
	ghoulkin_kills = int(state.get("ghoulkin_kills", ghoulkin_kills))

func _on_player_died() -> void:
	audio.play_event("hurt")
	get_tree().paused = true
	hud.show_death_screen("The road keeps its dead.\n\nLoad Last Checkpoint returns Kael to the last safe contract marker with quest progress preserved.")

func _pause_game() -> void:
	get_tree().paused = true
	paused_by_menu = true
	audio.play_event("ui")
	hud.show_pause_menu()

func _resume_game() -> void:
	get_tree().paused = false
	paused_by_menu = false
	audio.play_event("ui")
	hud.hide_menus()

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
	elif action == "mouse_sensitivity":
		settings.cycle_mouse_sensitivity()
	elif action == "invert_y":
		settings.toggle_invert_y()
	elif action == "volume":
		settings.cycle_master_volume()
	hud.toast("Settings updated.")

func _apply_runtime_settings(current_settings: Dictionary) -> void:
	if audio != null:
		audio.set_master_volume(float(current_settings.get("master_volume", 0.85)))
	if camera_rig != null:
		camera_rig.apply_settings(float(current_settings.get("mouse_sensitivity", 0.003)), bool(current_settings.get("invert_y", false)))

func _refresh_tracker() -> void:
	hud.set_tracker(quests.get_tracker_text())
	_update_compass()

func _refresh_equipment_readout() -> void:
	if hud == null or inventory == null:
		return
	var oil_name = ""
	if inventory.active_oil != "":
		oil_name = inventory.get_item_name(inventory.active_oil)
	hud.update_equipment(int(inventory.items.get("redroot_potion", 0)), int(inventory.items.get("ash_bomb", 0)), oil_name)

func _update_tutorial_prompts() -> void:
	if player == null:
		return
	if active_interactable != null and not bool(tutorial_flags.get("interact", false)):
		tutorial_flags["interact"] = true
		hud.toast("Press E to interact. In menus and dialogue, use the mouse pointer.")
	if current_zone_id == "greyfen" and not bool(tutorial_flags.get("route", false)) and player.global_position.z < -8.0:
		tutorial_flags["route"] = true
		audio.play_event("cloth_wind", 0.03)
		audio.set_music_state("wychwood_tension")
		hud.toast("The village noise thins behind you. The old road keeps its own silence.")
		hud.set_guidance_hint("Wychwood gate ahead. Stay on the lit road.", 4.5)
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
	if current_zone_id == "wychwood" and not bool(tutorial_flags.get("near_clearing_audio", false)) and player.global_position.z < -4.0:
		tutorial_flags["near_clearing_audio"] = true
		audio.play_event("ghoulkin_idle", 0.03)
	if current_zone_id == "wychwood" and active_enemies.size() > 0 and not bool(tutorial_flags.get("combat", false)):
		tutorial_flags["combat"] = true
		audio.set_music_state("ghoulkin_combat")
		audio.play_event("wychwood_tension", 0.01)
		hud.toast("Survive the Ghoulkin.")
		hud.set_guidance_hint("Left click strike | Space dodge | Q block/parry | R potion", 6.0)

func _update_compass() -> void:
	if hud == null or player == null:
		return
	var zone_name = {"greyfen": "Greyfen", "wychwood": "The Wychwood", "ruins": "Castle Vargan"}.get(current_zone_id, current_zone_id)
	hud.set_compass("%s | %s" % [zone_name, _nearest_interactable_summary()])

func _nearest_interactable_summary() -> String:
	if zone_root == null:
		return "No marker"
	var best_text = "No marker"
	var best_dist = 9999.0
	for child in zone_root.get_children():
		if not child.has_method("get_overlapping_bodies"):
			continue
		var interaction_id = child.get("interaction_id")
		if interaction_id == null or str(interaction_id) == "":
			continue
		var dist = child.global_position.distance_to(player.global_position)
		if dist < best_dist:
			best_dist = dist
			best_text = "%s %dm" % [child.get("prompt"), int(dist)]
	return best_text

func _keep_player_in_world() -> void:
	if player == null:
		return
	var half = _zone_half_extents(current_zone_id)
	if player.global_position.y > -2.0 and abs(player.global_position.x) < half.x - 1.5 and abs(player.global_position.z) < half.y - 1.5:
		last_safe_player_position = player.global_position
		return
	if player.global_position.y < -8.0 or abs(player.global_position.x) > half.x + 4.0 or abs(player.global_position.z) > half.y + 4.0:
		player.global_position = last_safe_player_position + Vector3(0, 1.2, 0)
		player.velocity = Vector3.ZERO
		hud.toast("Kael catches himself before the dark takes him.")

func _zone_half_extents(zone_id: String) -> Vector2:
	if zone_id == "wychwood":
		return Vector2(22, 17)
	if zone_id == "greyfen":
		return Vector2(21, 17)
	return Vector2(24, 21)

func _make_play_area_bounds(width: float, depth: float, color: Color) -> void:
	var half_w = width * 0.5
	var half_d = depth * 0.5
	_make_prop_box("NorthBerm", Vector3(0, 0.9, -half_d), Vector3(width, 1.8, 1.2), color)
	_make_prop_box("SouthBerm", Vector3(0, 0.9, half_d), Vector3(width, 1.8, 1.2), color)
	_make_prop_box("WestBerm", Vector3(-half_w, 0.9, 0), Vector3(1.2, 1.8, depth), color)
	_make_prop_box("EastBerm", Vector3(half_w, 0.9, 0), Vector3(1.2, 1.8, depth), color)
	_make_invisible_wall(Vector3(0, 1.6, -half_d - 0.65), Vector3(width, 3.2, 0.4))
	_make_invisible_wall(Vector3(0, 1.6, half_d + 0.65), Vector3(width, 3.2, 0.4))
	_make_invisible_wall(Vector3(-half_w - 0.65, 1.6, 0), Vector3(0.4, 3.2, depth))
	_make_invisible_wall(Vector3(half_w + 0.65, 1.6, 0), Vector3(0.4, 3.2, depth))

func _make_invisible_wall(pos: Vector3, size: Vector3) -> void:
	var body = StaticBody3D.new()
	body.name = "WorldBoundary"
	body.position = pos
	zone_root.add_child(body)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

func _make_greyfen_terrain_layers() -> void:
	_make_terrain_patch("GreyfenVillageGreen", Vector3(-9.5, 0.012, -4.0), Vector3(11.5, 0.035, 8.0), Color(0.095, 0.145, 0.085))
	_make_terrain_patch("GreyfenShrineRise", Vector3(6.0, 0.038, -7.0), Vector3(7.4, 0.08, 5.2), Color(0.105, 0.125, 0.095))
	_make_terrain_patch("GreyfenCemeterySoil", Vector3(14.0, 0.028, 8.6), Vector3(8.0, 0.045, 5.0), Color(0.095, 0.090, 0.078))
	_make_terrain_patch("GreyfenBlacksmithYard", Vector3(9.5, 0.026, 4.5), Vector3(7.0, 0.045, 5.2), Color(0.115, 0.095, 0.072))
	for z in [-12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.0]:
		_make_terrain_patch("GreyfenRoadShoulder", Vector3(-3.4, 0.024, z), Vector3(1.2, 0.032, 2.6), Color(0.095, 0.105, 0.075))
		_make_terrain_patch("GreyfenRoadShoulder", Vector3(3.4, 0.024, z), Vector3(1.2, 0.032, 2.6), Color(0.095, 0.105, 0.075))
	_make_grass_tufts([
		Vector3(-3.4, 0, -11.5), Vector3(3.1, 0, -10.7), Vector3(-3.6, 0, -7.5), Vector3(3.3, 0, -5.6),
		Vector3(-3.8, 0, -1.4), Vector3(3.6, 0, 1.8), Vector3(-3.0, 0, 5.6), Vector3(3.7, 0, 7.9),
		Vector3(5.2, 0, -8.8), Vector3(7.4, 0, -4.9), Vector3(11.9, 0, 7.4), Vector3(14.8, 0, 6.2)
	], Color(0.070, 0.145, 0.070))

func _make_wychwood_terrain_layers() -> void:
	_make_terrain_patch("WychwoodWetRoad", Vector3(0, 0.028, 4.0), Vector3(5.2, 0.045, 22.0), Color(0.045, 0.055, 0.043))
	_make_terrain_patch("WychwoodRootFloorLeft", Vector3(-7.0, 0.018, 1.0), Vector3(8.0, 0.04, 25.0), Color(0.035, 0.072, 0.045))
	_make_terrain_patch("WychwoodRootFloorRight", Vector3(7.0, 0.018, 0.0), Vector3(8.0, 0.04, 25.0), Color(0.035, 0.068, 0.045))
	_make_terrain_patch("WychwoodClearingMud", Vector3(0, 0.032, -6.5), Vector3(10.0, 0.05, 7.0), Color(0.035, 0.044, 0.036))
	for z in [12.0, 8.0, 4.0, 0.0, -4.0, -8.0]:
		_make_terrain_patch("WychwoodPathShoulder", Vector3(-3.0, 0.035, z), Vector3(1.0, 0.035, 2.6), Color(0.032, 0.060, 0.040))
		_make_terrain_patch("WychwoodPathShoulder", Vector3(3.0, 0.035, z), Vector3(1.0, 0.035, 2.6), Color(0.032, 0.060, 0.040))
	_make_grass_tufts([
		Vector3(-2.8, 0, 11.8), Vector3(2.6, 0, 10.5), Vector3(-3.1, 0, 7.2), Vector3(3.3, 0, 5.6),
		Vector3(-3.4, 0, 2.0), Vector3(3.5, 0, -0.2), Vector3(-3.7, 0, -4.2), Vector3(3.4, 0, -6.1),
		Vector3(-5.0, 0, -8.4), Vector3(5.3, 0, -9.0)
	], Color(0.045, 0.115, 0.065))

func _make_greyfen_path_edges() -> void:
	var marker = Node3D.new()
	marker.name = "GreyfenPathEdgeComposition"
	zone_root.add_child(marker)
	for z in [-12, -9, -6, -3, 0, 3, 6, 9, 12]:
		_make_path_stone(Vector3(-2.35 + randf_range(-0.12, 0.12), 0, z + randf_range(-0.35, 0.35)), 0.35)
		_make_path_stone(Vector3(2.35 + randf_range(-0.12, 0.12), 0, z + randf_range(-0.35, 0.35)), 0.32)
	for z in [-11.8, -7.8, -3.8, 0.2, 4.2, 8.2]:
		_make_low_berm(Vector3(-4.7, 0, z), Vector3(1.2, 0.38, 2.2), Color(0.085, 0.105, 0.070))
		_make_low_berm(Vector3(4.7, 0, z), Vector3(1.2, 0.38, 2.2), Color(0.085, 0.105, 0.070))

func _make_wychwood_path_edges() -> void:
	var marker = Node3D.new()
	marker.name = "WychwoodPathEdgeComposition"
	zone_root.add_child(marker)
	for z in [12, 9, 6, 3, 0, -3, -6, -9]:
		_make_path_stone(Vector3(-2.25 + randf_range(-0.18, 0.18), 0, z + randf_range(-0.25, 0.25)), 0.42)
		_make_path_stone(Vector3(2.25 + randf_range(-0.18, 0.18), 0, z + randf_range(-0.25, 0.25)), 0.42)
		_make_low_berm(Vector3(-4.25, 0, z), Vector3(1.4, 0.48, 2.2), Color(0.030, 0.060, 0.038))
		_make_low_berm(Vector3(4.25, 0, z), Vector3(1.4, 0.48, 2.2), Color(0.030, 0.060, 0.038))

func _make_terrain_patch(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh = MeshInstance3D.new()
	mesh.name = name
	var cube = BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.position = pos
	mesh.rotation_degrees.y = randf_range(-2.0, 2.0)
	mesh.material_override = _terrain_material(name, color)
	zone_root.add_child(mesh)

func _make_path_stone(pos: Vector3, scale_value: float) -> void:
	_make_terrain_patch("PathStone", pos + Vector3(0, 0.03, 0), Vector3(scale_value, 0.06, scale_value * 0.75), Color(0.18, 0.17, 0.15))

func _make_low_berm(pos: Vector3, size: Vector3, color: Color) -> void:
	var body = StaticBody3D.new()
	body.name = "LowBerm"
	body.position = pos + Vector3(0, size.y * 0.5, 0)
	zone_root.add_child(body)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh = MeshInstance3D.new()
	var cube = BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.material_override = _mat(color)
	body.add_child(mesh)

func _make_grass_tufts(points: Array, color: Color) -> void:
	if points.is_empty():
		return
	if _performance_mode() and int(settings.settings.get("foliage_density", 0)) <= 0:
		return
	var batch = MultiMeshInstance3D.new()
	batch.name = "GrassBatch"
	var blade_mesh = BoxMesh.new()
	blade_mesh.size = Vector3(0.055, 1.0, 0.045)
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = blade_mesh
	multimesh.instance_count = points.size() * 9
	var instance_index = 0
	for raw_pos in points:
		var pos: Vector3 = raw_pos
		for i: int in range(9):
			var height: float = randf_range(0.34, 0.72)
			var basis = Basis()
			basis = basis.rotated(Vector3.UP, randf_range(0.0, TAU))
			basis = basis.rotated(Vector3.RIGHT, randf_range(-0.20, 0.20))
			basis = basis.scaled(Vector3(randf_range(0.7, 1.25), height, randf_range(0.7, 1.25)))
			var offset = Vector3(randf_range(-0.38, 0.38), height * 0.5, randf_range(-0.38, 0.38))
			multimesh.set_instance_transform(instance_index, Transform3D(basis, pos + offset))
			instance_index += 1
	batch.multimesh = multimesh
	batch.material_override = _grass_material(color)
	zone_root.add_child(batch)

func _make_spawn_composition() -> void:
	var marker = Node3D.new()
	marker.name = "GreyfenSpawnComposition"
	marker.position = Vector3(0, 0, 7)
	zone_root.add_child(marker)
	_make_light("SpawnWarmRead", Vector3(-2.6, 2.8, 5.7), Color(1.0, 0.42, 0.16), 1.0)
	_make_light("SpawnCoolBackplate", Vector3(1.8, 3.5, 0.4), Color(0.30, 0.36, 0.50), 1.4)
	_make_fog_sheet(Vector3(0, 0.8, 0.8), Vector3(10.0, 0.7, 3.2), Color(0.13, 0.15, 0.16, 0.07))
	_make_fake_light_pool("SpawnLanternPool", Vector3(-2.55, 0.035, 5.6), Vector3(1.9, 0.025, 1.25), Color(0.42, 0.20, 0.075))
	_make_visual_box("SpawnViewShadowLeft", Vector3(-4.0, 0.035, 4.6), Vector3(1.2, 0.025, 3.4), Color(0.055, 0.070, 0.055))
	_make_visual_box("SpawnViewShadowRight", Vector3(4.0, 0.035, 3.9), Vector3(1.1, 0.025, 3.7), Color(0.055, 0.068, 0.055))
	for pos in [Vector3(-3.1, 0, 4.2), Vector3(3.0, 0, 3.4), Vector3(-2.9, 0, 0.2), Vector3(2.9, 0, -1.5)]:
		_make_path_stone(pos, 0.22)
	_make_lantern_post(Vector3(-2.8, 0, 5.7), false, true)
	_make_lantern_post(Vector3(2.65, 0, 1.5), false, false)
	_make_firewood_stack(Vector3(-5.1, 0, 5.2), 18.0)
	_make_broken_fence_run(Vector3(4.7, 0, 5.8), false)

func _make_greyfen_first_impression_dressing() -> void:
	var marker = Node3D.new()
	marker.name = "GreyfenFirstImpressionDressing"
	marker.position = Vector3(0, 0, 0)
	zone_root.add_child(marker)
	_make_road_ruts()
	_make_lantern_rhythm()
	_make_shrine_approach()
	_make_village_story_clusters()
	_make_crow_silhouettes()

func _make_quality_greyfen_overhaul() -> void:
	if _performance_mode():
		return
	var marker = Node3D.new()
	marker.name = "QualityGreyfenVisualOverhaul"
	zone_root.add_child(marker)
	for z in [-13.0, -10.5, -8.0, -5.5, -3.0, -0.5, 2.0, 4.5, 7.0, 9.5, 12.0]:
		_make_visual_box("QualityWetRoadSheen", Vector3(randf_range(-0.45, 0.45), 0.058, z), Vector3(randf_range(0.55, 1.35), 0.012, randf_range(0.42, 1.15)), Color(0.045, 0.037, 0.030))
		_make_visual_box("QualityRoadLeafLitter", Vector3(randf_range(-1.9, 1.9), 0.066, z + randf_range(-0.75, 0.75)), Vector3(randf_range(0.18, 0.55), 0.012, randf_range(0.08, 0.20)), Color(0.12, 0.060, 0.030))
	for pos in [Vector3(-5.8,0,2.5), Vector3(-7.0,0,-3.2), Vector3(7.2,0,-0.2), Vector3(9.8,0,1.8), Vector3(-10.0,0,8.8), Vector3(11.2,0,-7.4)]:
		_make_quality_survival_cluster(pos)
	for pos in [Vector3(4.0,0,-6.0), Vector3(5.2,0,-4.5), Vector3(7.5,0,-7.2), Vector3(6.8,0,-5.8)]:
		_make_fake_light_pool("QualityShrineCandlePool", pos + Vector3(0, 0.038, 0), Vector3(1.05, 0.016, 0.64), Color(0.34, 0.19, 0.07))
	for pos in [Vector3(-3.2,0,-12.5), Vector3(3.4,0,-11.6), Vector3(-3.6,0,-9.2), Vector3(3.2,0,-7.8), Vector3(-3.1,0,-4.8), Vector3(3.5,0,-2.0)]:
		_make_visual_box("QualityRoadEdgeWeeds", pos + Vector3(0, 0.15, 0), Vector3(0.12, randf_range(0.26, 0.46), 0.08), Color(0.060, 0.120, 0.055))
	_make_light("QualityShrineWarmth", Vector3(5.5, 2.7, -5.9), Color(1.0, 0.50, 0.20), 1.2)
	_make_light("QualityVillageColdEdge", Vector3(-10.0, 3.8, -8.0), Color(0.22, 0.32, 0.46), 1.1)

func _make_quality_survival_cluster(pos: Vector3) -> void:
	_make_visual_box("QualityMudSack", pos + Vector3(0.0, 0.16, 0.0), Vector3(0.58, 0.32, 0.36), Color(0.17, 0.115, 0.065))
	_make_visual_box("QualityBrokenBoard", pos + Vector3(0.62, 0.13, -0.14), Vector3(0.88, 0.08, 0.18), Color(0.13, 0.075, 0.038))
	_make_visual_box("QualityBucket", pos + Vector3(-0.52, 0.24, 0.18), Vector3(0.32, 0.48, 0.32), Color(0.10, 0.085, 0.065))
	_make_visual_box("QualityClothScrap", pos + Vector3(0.1, 0.045, 0.5), Vector3(0.82, 0.018, 0.32), Color(0.23, 0.055, 0.044))

func _make_road_ruts() -> void:
	for z in [-11.5, -8.6, -5.7, -2.8, 0.1, 3.0, 5.9, 8.8]:
		_make_visual_box("RoadWheelRut", Vector3(-0.82, 0.044, z), Vector3(0.18, 0.018, 2.0), Color(0.075, 0.058, 0.040))
		_make_visual_box("RoadWheelRut", Vector3(0.82, 0.044, z + 0.18), Vector3(0.18, 0.018, 2.0), Color(0.075, 0.058, 0.040))
	for z in [-10.0, -6.0, -2.0, 2.0, 6.0, 10.0]:
		_make_visual_box("RoadCenterMud", Vector3(0, 0.046, z), Vector3(0.42, 0.016, 1.25), Color(0.090, 0.066, 0.043))

func _make_lantern_rhythm() -> void:
	var points = [
		[Vector3(-2.85, 0, 6.4), true],
		[Vector3(2.95, 0, 2.2), false],
		[Vector3(-2.75, 0, -2.5), false],
		[Vector3(2.85, 0, -6.8), false],
		[Vector3(-2.55, 0, -10.8), false]
	]
	for item in points:
		_make_lantern_post(item[0], false, bool(item[1]))
		_make_fake_light_pool("RoadLanternPool", item[0] + Vector3(0, 0.035, 0.25), Vector3(1.55, 0.022, 1.05), Color(0.32, 0.135, 0.045))

func _make_shrine_approach() -> void:
	_make_visual_box("ShrinePathWarmEdge", Vector3(3.05, 0.047, -5.55), Vector3(2.9, 0.018, 0.22), Color(0.24, 0.16, 0.075))
	_make_visual_box("ShrinePathWarmEdge", Vector3(4.65, 0.047, -6.55), Vector3(2.3, 0.018, 0.22), Color(0.24, 0.16, 0.075))
	_make_lantern_post(Vector3(3.4, 0, -4.25), true, true)
	_make_lantern_post(Vector3(7.65, 0, -6.1), true, false)
	for offset in [Vector3(-1.25, 0, 0.75), Vector3(1.18, 0, 0.82), Vector3(-1.55, 0, -0.25), Vector3(1.5, 0, -0.3)]:
		_make_shrine_candle(Vector3(6.0, 0, -7.0) + offset)
	_make_hanging_cloth(Vector3(4.85, 1.25, -7.95), Vector3(0.55, 0.72, 0.035), Color(0.34, 0.035, 0.030))
	_make_hanging_cloth(Vector3(7.05, 1.20, -7.92), Vector3(0.48, 0.62, 0.035), Color(0.12, 0.16, 0.13))

func _make_village_story_clusters() -> void:
	_make_firewood_stack(Vector3(-6.8, 0, -0.8), -12.0)
	_make_firewood_stack(Vector3(8.2, 0, -1.2), 24.0)
	_make_broken_fence_run(Vector3(-4.8, 0, -7.0), true)
	_make_broken_fence_run(Vector3(4.9, 0, -10.4), true)
	_make_wheelbarrow(Vector3(-7.9, 0, 6.6), -22.0)
	_make_wheelbarrow(Vector3(11.7, 0, -10.2), 35.0)
	for pos in [Vector3(-10.7, 0, 10.5), Vector3(12.4, 0, 6.3), Vector3(15.6, 0, 7.7)]:
		_make_mourning_marker(pos)
	for pos in [Vector3(-12.7, 0, -5.8), Vector3(-11.8, 0, -4.3), Vector3(13.2, 0, -5.4), Vector3(14.2, 0, -4.0)]:
		_make_fake_fog_bank(pos)

func _make_lantern_post(pos: Vector3, shrine_style: bool, casts_light: bool) -> void:
	_make_prop_box("LanternPost", pos + Vector3(0, 0.75, 0), Vector3(0.12, 1.5, 0.12), Color(0.12, 0.070, 0.038))
	_make_visual_box("LanternArm", pos + Vector3(0.28, 1.38, 0), Vector3(0.56, 0.08, 0.08), Color(0.12, 0.070, 0.038))
	_make_visual_box("LanternCage", pos + Vector3(0.56, 1.18, 0), Vector3(0.22, 0.34, 0.22), Color(0.055, 0.040, 0.030))
	var glow_color = Color(1.0, 0.50, 0.16) if not shrine_style else Color(0.74, 0.88, 0.58)
	var glow = MeshInstance3D.new()
	glow.name = "LanternGlow"
	glow.set_meta("visual_name", "LanternGlow")
	glow.mesh = SphereMesh.new()
	glow.scale = Vector3(0.16, 0.22, 0.16)
	glow.position = pos + Vector3(0.56, 1.17, 0)
	glow.material_override = _emissive_mat(glow_color, 1.25)
	zone_root.add_child(glow)
	if casts_light:
		_make_light("SpawnWarmRead" if not shrine_style else "Shrine Beacon", pos + Vector3(0.45, 1.45, 0), glow_color, 0.9)

func _make_fake_light_pool(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	_make_visual_box(name, pos, size, color)

func _make_firewood_stack(pos: Vector3, yaw: float) -> void:
	var root = Node3D.new()
	root.name = "FirewoodStack"
	root.position = pos
	root.rotation_degrees.y = yaw
	zone_root.add_child(root)
	for i in range(5):
		var log_mesh = MeshInstance3D.new()
		log_mesh.name = "StackedLog"
		var mesh = CylinderMesh.new()
		mesh.top_radius = 0.075
		mesh.bottom_radius = 0.085
		mesh.height = 1.05
		mesh.radial_segments = 6
		log_mesh.mesh = mesh
		log_mesh.position = Vector3(-0.34 + float(i) * 0.17, 0.18 + float(i % 2) * 0.13, 0)
		log_mesh.rotation_degrees = Vector3(90, 0, 90)
		log_mesh.material_override = _mat(Color(0.135, 0.078, 0.044))
		root.add_child(log_mesh)

func _make_broken_fence_run(pos: Vector3, vertical: bool) -> void:
	for i in range(3):
		var offset = Vector3(0, 0, float(i) * 0.85) if vertical else Vector3(float(i) * 0.85, 0, 0)
		_make_visual_box("BrokenFencePost", pos + offset + Vector3(0, 0.42 + 0.06 * float(i % 2), 0), Vector3(0.12, 0.84, 0.12), Color(0.13, 0.075, 0.040))
	var rail_size = Vector3(0.10, 0.10, 2.35) if vertical else Vector3(2.35, 0.10, 0.10)
	_make_visual_box("BrokenFenceRail", pos + Vector3(0.42 if not vertical else 0, 0.72, 0.42 if vertical else 0), rail_size, Color(0.16, 0.095, 0.050))

func _make_wheelbarrow(pos: Vector3, yaw: float) -> void:
	var root = Node3D.new()
	root.name = "WheelbarrowStoryProp"
	root.position = pos
	root.rotation_degrees.y = yaw
	zone_root.add_child(root)
	_add_visual_box_child(root, "WheelbarrowTray", Vector3(0, 0.38, 0), Vector3(1.0, 0.24, 0.55), Color(0.15, 0.085, 0.045))
	_add_visual_box_child(root, "WheelbarrowHandle", Vector3(-0.62, 0.42, -0.23), Vector3(0.75, 0.07, 0.07), Color(0.12, 0.070, 0.038))
	_add_visual_box_child(root, "WheelbarrowHandle", Vector3(-0.62, 0.42, 0.23), Vector3(0.75, 0.07, 0.07), Color(0.12, 0.070, 0.038))
	var wheel = MeshInstance3D.new()
	wheel.name = "WheelbarrowWheel"
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.22
	mesh.height = 0.08
	mesh.radial_segments = 8
	wheel.mesh = mesh
	wheel.position = Vector3(0.53, 0.22, 0)
	wheel.rotation_degrees.z = 90
	wheel.material_override = _mat(Color(0.055, 0.040, 0.030))
	root.add_child(wheel)

func _make_mourning_marker(pos: Vector3) -> void:
	_make_visual_box("MourningMarkerPost", pos + Vector3(0, 0.38, 0), Vector3(0.09, 0.76, 0.09), Color(0.11, 0.075, 0.050))
	_make_visual_box("MourningMarkerCross", pos + Vector3(0, 0.62, 0), Vector3(0.54, 0.07, 0.07), Color(0.11, 0.075, 0.050))
	_make_hanging_cloth(pos + Vector3(0.25, 0.45, 0.01), Vector3(0.18, 0.28, 0.025), Color(0.30, 0.030, 0.025))

func _make_shrine_candle(pos: Vector3) -> void:
	_make_visual_box("ShrineCandle", pos + Vector3(0, 0.17, 0), Vector3(0.10, 0.34, 0.10), Color(0.72, 0.62, 0.44))
	var flame = MeshInstance3D.new()
	flame.name = "ShrineCandleFlame"
	flame.mesh = SphereMesh.new()
	flame.scale = Vector3(0.07, 0.11, 0.07)
	flame.position = pos + Vector3(0, 0.39, 0)
	flame.material_override = _emissive_mat(Color(1.0, 0.48, 0.14), 1.1)
	zone_root.add_child(flame)

func _make_hanging_cloth(pos: Vector3, size: Vector3, color: Color) -> void:
	_make_visual_box("HangingCloth", pos, size, color)

func _make_fake_fog_bank(pos: Vector3) -> void:
	_make_visual_box("LowColdFogBank", pos + Vector3(0, 0.07, 0), Vector3(1.6, 0.10, 0.55), Color(0.105, 0.125, 0.118))

func _make_crow_silhouettes() -> void:
	for item in [
		[Vector3(-8.5, 5.8, -11.5), -14.0],
		[Vector3(-7.8, 6.15, -12.2), 8.0],
		[Vector3(10.2, 5.5, -10.6), 18.0]
	]:
		var root = Node3D.new()
		root.name = "CrowSilhouette"
		root.position = item[0]
		root.rotation_degrees.y = float(item[1])
		zone_root.add_child(root)
		_add_visual_box_child(root, "CrowWing", Vector3(-0.16, 0, 0), Vector3(0.34, 0.035, 0.08), Color(0.010, 0.010, 0.012))
		_add_visual_box_child(root, "CrowWing", Vector3(0.16, 0, 0), Vector3(0.34, 0.035, 0.08), Color(0.010, 0.010, 0.012))

func _make_visual_box(name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = name
	mesh_instance.set_meta("visual_name", name)
	var cube = BoxMesh.new()
	cube.size = size
	mesh_instance.mesh = cube
	mesh_instance.position = pos
	mesh_instance.material_override = _mat(color)
	zone_root.add_child(mesh_instance)
	return mesh_instance

func _add_visual_box_child(parent: Node3D, name: String, local_pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = name
	mesh_instance.set_meta("visual_name", name)
	var cube = BoxMesh.new()
	cube.size = size
	mesh_instance.mesh = cube
	mesh_instance.position = local_pos
	mesh_instance.material_override = _mat(color)
	parent.add_child(mesh_instance)
	return mesh_instance

func _make_greyfen_road_of_crows_story_beats() -> void:
	var marker = Node3D.new()
	marker.name = "RoadOfCrowsGreyfenStoryBeats"
	zone_root.add_child(marker)
	_make_black_feather_scatter("RoadCrowsNoticeBlackFeathers", Vector3(-2.8, 0.09, 9.0), 4, 0.75)
	_make_broken_charm("RoadCrowsNoticePrayerCharm", Vector3(-1.35, 0.10, 8.95), 0.0)
	_make_black_feather_scatter("RoadCrowsShrineBlackFeathers", Vector3(5.25, 0.10, -6.25), 5, 0.65)
	_make_broken_charm("RoadCrowsShrineSnappedToken", Vector3(5.65, 0.12, -6.75), -22.0)
	_make_visual_box("RoadCrowsExtinguishedCandle", Vector3(6.55, 0.16, -6.35), Vector3(0.11, 0.28, 0.11), Color(0.075, 0.065, 0.055))
	_make_visual_box("RoadCrowsGraveyardDisturbedSoil", Vector3(13.65, 0.065, 9.45), Vector3(1.65, 0.035, 0.85), Color(0.060, 0.044, 0.033))
	_make_broken_charm("RoadCrowsGraveyardHalfBuriedCharm", Vector3(13.18, 0.13, 9.15), 14.0)
	_make_black_feather_scatter("RoadCrowsGateThresholdFeathers", Vector3(-1.25, 0.10, -13.65), 5, 0.9)
	_make_dark_track("RoadCrowsGateMudTrail", Vector3(0.0, 0.071, -13.15), Vector3(0.42, 0.022, 2.15), Color(0.040, 0.027, 0.020))
	_make_visual_box("RoadCrowsGateBrokenSign", Vector3(-2.95, 0.86, -13.85), Vector3(1.05, 0.14, 0.38), Color(0.135, 0.075, 0.038))
	_make_claw_marks("RoadCrowsGateClawedPost", Vector3(2.35, 0.95, -13.85), true)

func _make_wychwood_road_of_crows_story_beats() -> void:
	var marker = Node3D.new()
	marker.name = "RoadOfCrowsWychwoodStoryBeats"
	zone_root.add_child(marker)
	_make_cart(Vector3(-5.35, 0, 6.6))
	_make_visual_box("RoadCrowsBrokenCartSupplySack", Vector3(-4.65, 0.18, 6.0), Vector3(0.58, 0.24, 0.42), Color(0.17, 0.115, 0.075))
	_make_dark_track("RoadCrowsDraggedTrackA", Vector3(-1.05, 0.073, 6.4), Vector3(0.32, 0.018, 2.6), Color(0.050, 0.027, 0.020))
	_make_dark_track("RoadCrowsDraggedTrackB", Vector3(0.75, 0.074, 5.1), Vector3(0.26, 0.018, 2.0), Color(0.055, 0.030, 0.022))
	_make_claw_marks("RoadCrowsCartClawMarks", Vector3(2.7, 0.22, 4.65), false)
	_make_visual_box("RoadCrowsTornRedCloth", Vector3(-3.65, 0.105, 2.15), Vector3(0.58, 0.035, 0.24), Color(0.28, 0.055, 0.042))
	_make_broken_charm("RoadCrowsBrokenPrayerToken", Vector3(-3.18, 0.13, 2.25), -12.0)
	_make_black_feather_scatter("RoadCrowsOldRoadBlackFeathers", Vector3(-3.95, 0.10, 1.75), 6, 0.75)
	_make_dark_track("RoadCrowsClearingDraggedMarks", Vector3(0.0, 0.074, -5.65), Vector3(0.46, 0.020, 3.1), Color(0.060, 0.022, 0.016))
	_make_visual_box("RoadCrowsClearingOldBloodMud", Vector3(-0.8, 0.076, -6.95), Vector3(1.35, 0.020, 0.62), Color(0.080, 0.018, 0.013))
	_make_broken_charm("RoadCrowsClearingSnappedCharm", Vector3(1.35, 0.13, -6.9), 24.0)
	_make_black_feather_scatter("RoadCrowsClearingFeathers", Vector3(1.55, 0.10, -7.25), 5, 0.72)

func _make_post_ghoulkin_story_clue() -> void:
	if zone_root == null or zone_root.find_child("RoadCrowsPostVictoryBootTracks", true, false) != null:
		return
	_make_dark_track("RoadCrowsPostVictoryBootTracks", Vector3(0.95, 0.087, -4.25), Vector3(0.30, 0.026, 1.9), Color(0.020, 0.018, 0.015))
	_make_dark_track("RoadCrowsPostVictoryClawTracks", Vector3(1.45, 0.088, -4.75), Vector3(0.34, 0.025, 1.55), Color(0.060, 0.022, 0.016))
	_make_visual_box("RoadCrowsPostVictoryCutThread", Vector3(0.55, 0.13, -3.72), Vector3(0.70, 0.030, 0.06), Color(0.36, 0.035, 0.030))
	_make_black_feather_scatter("RoadCrowsPostVictoryFeathers", Vector3(0.35, 0.11, -3.95), 4, 0.55)

func _make_black_feather_scatter(base_name: String, center: Vector3, count: int, spread: float) -> void:
	for i in range(count):
		var offset = Vector3(randf_range(-spread, spread), 0.0, randf_range(-spread * 0.55, spread * 0.55))
		var feather = _make_visual_box(base_name, center + offset, Vector3(randf_range(0.24, 0.42), 0.022, 0.070), Color(0.010, 0.010, 0.012))
		feather.rotation_degrees.y = randf_range(-35.0, 35.0)

func _make_broken_charm(name: String, pos: Vector3, yaw: float) -> void:
	var root = Node3D.new()
	root.name = name
	root.position = pos
	root.rotation_degrees.y = yaw
	zone_root.add_child(root)
	_add_visual_box_child(root, "%sBoneHalfA" % name, Vector3(-0.08, 0.0, 0.0), Vector3(0.17, 0.035, 0.24), Color(0.54, 0.50, 0.42))
	_add_visual_box_child(root, "%sBoneHalfB" % name, Vector3(0.11, 0.0, 0.04), Vector3(0.15, 0.035, 0.20), Color(0.48, 0.45, 0.38))
	_add_visual_box_child(root, "%sRedThread" % name, Vector3(0.0, 0.024, -0.12), Vector3(0.38, 0.020, 0.045), Color(0.30, 0.035, 0.028))

func _make_dark_track(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var track = _make_visual_box(name, pos, size, color)
	track.rotation_degrees.y = randf_range(-8.0, 8.0)

func _make_claw_marks(name: String, pos: Vector3, vertical: bool) -> void:
	for i in range(3):
		var mark_pos = pos + (Vector3(0.0, 0.11 * float(i), 0.0) if vertical else Vector3(0.18 * float(i), 0.0, 0.0))
		var size = Vector3(0.045, 0.50, 0.035) if vertical else Vector3(0.055, 0.030, 0.62)
		var mark = _make_visual_box(name, mark_pos, size, Color(0.030, 0.018, 0.012))
		mark.rotation_degrees.z = -18.0 if vertical else 0.0

func _make_wychwood_corridor() -> void:
	var marker = Node3D.new()
	marker.name = "WychwoodCorridorComposition"
	marker.position = Vector3(0, 0, 4)
	zone_root.add_child(marker)
	for z in [11.0, 7.5, 4.0, 0.5, -3.0]:
		_make_tree(Vector3(-9.2 + randf_range(-0.25, 0.25), 0, z))
		_make_tree(Vector3(9.2 + randf_range(-0.25, 0.25), 0, z + randf_range(-0.25, 0.25)))
		_make_fog_sheet(Vector3(0, 0.75, z - 0.8), Vector3(7.5, 0.72, 1.5), Color(0.12, 0.18, 0.16, 0.11))

func _make_stylized_house(pos: Vector3) -> void:
	_make_prop_box("VillageHouseBody", pos + Vector3(0, 1.05, 0), Vector3(3.8, 2.1, 3.0), Color(0.25, 0.18, 0.13))
	_make_roof(pos + Vector3(0, 2.45, 0), Vector3(4.6, 0.95, 3.6), Color(0.12, 0.085, 0.06))
	_make_prop_box("VillageDoor", pos + Vector3(0, 0.75, -1.55), Vector3(0.75, 1.35, 0.12), Color(0.08, 0.055, 0.035))
	_make_prop_box("VillageWindow", pos + Vector3(-1.15, 1.25, -1.56), Vector3(0.55, 0.45, 0.08), Color(0.86, 0.55, 0.22))
	_make_prop_box("VillageWindow", pos + Vector3(1.15, 1.25, -1.56), Vector3(0.55, 0.45, 0.08), Color(0.86, 0.55, 0.22))

func _make_village_house_dressed(pos: Vector3, yaw: float, node_name: String) -> void:
	var root = Node3D.new()
	root.name = node_name
	root.add_to_group("first_route_house")
	root.add_to_group("greyfen_house")
	root.set_meta("visible_house", true)
	root.position = pos
	root.rotation_degrees.y = yaw
	zone_root.add_child(root)
	_make_house_collision(root)
	_add_house_box(root, "PlasteredWall", Vector3(0, 1.05, 0), Vector3(4.3, 2.1, 3.35), Color(0.30, 0.22, 0.15))
	_add_house_box(root, "LeftRoofSlope", Vector3(-0.9, 2.42, 0), Vector3(2.55, 0.42, 3.95), Color(0.14, 0.055, 0.035), Vector3(0, 0, -13))
	_add_house_box(root, "RightRoofSlope", Vector3(0.9, 2.42, 0), Vector3(2.55, 0.42, 3.95), Color(0.14, 0.055, 0.035), Vector3(0, 0, 13))
	_add_house_box(root, "RoofRidge", Vector3(0, 2.72, 0), Vector3(0.28, 0.18, 4.05), Color(0.075, 0.035, 0.025))
	_add_house_box(root, "FrontDoor", Vector3(0, 0.78, -1.72), Vector3(0.78, 1.28, 0.12), Color(0.10, 0.055, 0.030))
	_add_house_box(root, "TimberLintel", Vector3(0, 1.53, -1.78), Vector3(1.05, 0.14, 0.12), Color(0.11, 0.065, 0.035))
	for x in [-1.42, 1.42]:
		_add_house_box(root, "FrontTimber", Vector3(x, 1.12, -1.78), Vector3(0.13, 1.85, 0.12), Color(0.10, 0.060, 0.035))
		_add_house_box(root, "LitWindow", Vector3(x * 0.62, 1.42, -1.80), Vector3(0.52, 0.38, 0.045), Color(0.95, 0.52, 0.18))
	_add_house_box(root, "SideTimberLeft", Vector3(-2.18, 1.18, 0), Vector3(0.12, 1.75, 2.45), Color(0.11, 0.065, 0.035))
	_add_house_box(root, "SideTimberRight", Vector3(2.18, 1.18, 0), Vector3(0.12, 1.75, 2.45), Color(0.11, 0.065, 0.035))
	_add_lit_window(root, Vector3(-0.72, 1.45, -1.56))
	_add_lit_window(root, Vector3(0.72, 1.45, -1.56))

func _add_house_box(parent: Node3D, node_name: String, local_pos: Vector3, size: Vector3, color: Color, local_rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = node_name
	var cube = BoxMesh.new()
	cube.size = size
	mesh_instance.mesh = cube
	mesh_instance.position = local_pos
	mesh_instance.rotation_degrees = local_rot
	if node_name.to_lower().contains("window"):
		mesh_instance.material_override = _emissive_mat(color, 0.7)
	else:
		mesh_instance.material_override = _mat(color)
	parent.add_child(mesh_instance)
	return mesh_instance

func _make_house_collision(parent: Node3D) -> void:
	var body = StaticBody3D.new()
	body.name = "HouseCollision"
	parent.add_child(body)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(4.2, 2.4, 3.4)
	shape.shape = box
	shape.position.y = 1.2
	body.add_child(shape)

func _add_lit_window(parent: Node3D, local_pos: Vector3) -> void:
	var pane = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.52, 0.38, 0.035)
	pane.mesh = mesh
	pane.position = local_pos
	pane.material_override = _emissive_mat(Color(1.0, 0.58, 0.20), 0.85)
	parent.add_child(pane)

func _add_role_child(parent: Node3D, role_name: String, scale_value: Vector3, local_pos: Vector3, yaw: float) -> Node3D:
	var node = _make_role_visual(role_name, "environment", scale_value)
	if node == null:
		return null
	node.position = local_pos
	node.rotation_degrees.y = yaw
	parent.add_child(node)
	return node

func _make_village_dressing() -> void:
	for item in [
		["barrel", Vector3(-4.0, 0, 3.4), 0.56, -8.0],
		["barrel", Vector3(-4.8, 0, 4.1), 0.48, 15.0],
		["crate", Vector3(-7.3, 0, 4.9), 0.64, 25.0],
		["crate", Vector3(8.0, 0, 2.8), 0.72, -18.0],
		["barrel", Vector3(10.7, 0, 2.9), 0.58, 18.0],
		["forest_rock", Vector3(4.6, 0, -11.0), 0.55, 0.0],
		["forest_rock", Vector3(-4.8, 0, -12.4), 0.52, 0.0],
		["crate", Vector3(5.5, 0, -6.9), 0.46, -12.0],
		["barrel", Vector3(7.2, 0, -6.4), 0.46, 10.0]
	]:
		_make_loose_role(str(item[0]), item[1], Vector3.ONE * float(item[2]), float(item[3]))
	for pos in [Vector3(-3.8, 0, -6.0), Vector3(3.9, 0, -9.2), Vector3(-4.4, 0, -13.0)]:
		_make_rubble(pos)

func _make_wychwood_gate_scene(pos: Vector3) -> void:
	for offset in [-2.25, 2.25]:
		_make_torch(pos + Vector3(offset, 0, 0.2))
		_make_loose_role("fence", pos + Vector3(offset * 0.82, 0, 0.65), Vector3(0.92, 0.92, 0.92), 90.0)
	for offset in [Vector3(-4.2, 0, 1.4), Vector3(4.0, 0, 1.2), Vector3(-4.0, 0, -1.1), Vector3(3.9, 0, -1.0)]:
		_make_rubble(pos + offset)
	_make_fog_sheet(pos + Vector3(0, 0.75, -0.4), Vector3(6.2, 0.9, 1.9), Color(0.20, 0.24, 0.22, 0.16))

func _make_wychwood_route_dressing() -> void:
	for item in [
		["forest_rock", Vector3(-2.8, 0, 9.0), 1.0, 8.0],
		["forest_rock", Vector3(3.1, 0, 7.8), 0.8, -16.0],
		["forest_rock", Vector3(-3.4, 0, 1.6), 1.1, 22.0],
		["forest_rock", Vector3(3.7, 0, -1.7), 0.9, 0.0],
		["barrel", Vector3(-5.2, 0, 8.2), 0.48, 0.0],
		["crate", Vector3(-5.8, 0, 7.6), 0.56, 11.0]
	]:
		_make_loose_role(str(item[0]), item[1], Vector3.ONE * float(item[2]), float(item[3]))
	for pos in [Vector3(-4.7, 0, 11.5), Vector3(4.6, 0, 10.5), Vector3(-4.8, 0, 5.5), Vector3(4.8, 0, 3.0), Vector3(-5.0, 0, -2.0), Vector3(4.8, 0, -4.8)]:
		_make_deadfall(pos)
	for pos in [Vector3(-8.4, 0, 12.5), Vector3(8.3, 0, 11.8), Vector3(-8.6, 0, 4.8), Vector3(8.5, 0, 1.2), Vector3(-8.8, 0, -5.4), Vector3(8.7, 0, -7.2)]:
		_make_tree(pos)

func _make_quality_wychwood_overhaul() -> void:
	if _performance_mode():
		return
	var marker = Node3D.new()
	marker.name = "QualityWychwoodVisualOverhaul"
	zone_root.add_child(marker)
	for z in [12.0, 9.5, 7.0, 4.5, 2.0, -0.5, -3.0, -5.5, -8.0]:
		_make_visual_box("QualityWychwoodWetMud", Vector3(randf_range(-0.55, 0.55), 0.060, z), Vector3(randf_range(0.70, 1.55), 0.012, randf_range(0.42, 1.05)), Color(0.018, 0.027, 0.024))
		_make_visual_box("QualityWychwoodRootCrossing", Vector3(randf_range(-2.3, 2.3), 0.145, z + randf_range(-0.6, 0.6)), Vector3(randf_range(0.95, 1.8), 0.11, 0.13), Color(0.070, 0.038, 0.022))
	for z in [10.5, 7.5, 4.5, 1.5, -1.5, -4.5, -7.5]:
		_make_deadfall(Vector3(-5.8 + randf_range(-0.4, 0.2), 0, z))
		_make_deadfall(Vector3(5.8 + randf_range(-0.2, 0.4), 0, z + randf_range(-0.3, 0.3)))
		_make_tree(Vector3(-10.4, 0, z + randf_range(-0.5, 0.5)))
		_make_tree(Vector3(10.4, 0, z + randf_range(-0.5, 0.5)))
	for pos in [Vector3(-2.2,0,6.7), Vector3(2.6,0,4.6), Vector3(-2.8,0,1.2), Vector3(2.9,0,-1.8)]:
		_make_visual_box("QualityClueGroundDarkening", pos + Vector3(0, 0.065, 0), Vector3(1.15, 0.014, 0.56), Color(0.027, 0.022, 0.018))
	for pos in [Vector3(-4.8,0,-5.8), Vector3(4.6,0,-6.4), Vector3(-2.6,0,-8.8), Vector3(2.8,0,-8.3), Vector3(0.0,0,-6.2)]:
		_make_visual_box("QualityClearingBloodMud", pos + Vector3(0, 0.070, 0), Vector3(1.15, 0.014, 0.46), Color(0.070, 0.018, 0.012))
	for pos in [Vector3(-7.0,0,-10.4), Vector3(7.2,0,-10.0), Vector3(-6.8,0,-4.8), Vector3(6.7,0,-4.2)]:
		_make_fog_sheet(pos + Vector3(0, 0.85, 0), Vector3(4.4, 0.72, 1.45), Color(0.10, 0.18, 0.16, 0.18))
	for pos in [Vector3(-8.2,0,13.0), Vector3(8.0,0,12.8), Vector3(-6.5,0,8.8)]:
		_make_visual_box("QualityBrokenForestSign", pos + Vector3(0, 0.85, 0), Vector3(0.95, 0.12, 0.40), Color(0.11, 0.065, 0.034))
	_make_light("QualityForestBlueRim", Vector3(0, 3.6, -6.5), Color(0.22, 0.42, 0.58), 1.4)
	_make_light("QualityGateLastWarmth", Vector3(0, 2.6, 11.6), Color(1.0, 0.42, 0.14), 1.0)

func _make_loose_role(role_name: String, pos: Vector3, scale_value: Vector3, yaw: float) -> Node3D:
	var key = role_name.to_lower()
	if key == "forest_rock":
		_make_rubble(pos)
		return null
	if key == "crate":
		_make_prop_box("RouteCrate", pos + Vector3(0, 0.32 * scale_value.y, 0), Vector3(0.72, 0.64, 0.72) * scale_value, Color(0.20, 0.12, 0.065))
		return null
	if key == "barrel":
		_make_prop_box("RouteBarrel", pos + Vector3(0, 0.36 * scale_value.y, 0), Vector3(0.58, 0.72, 0.58) * scale_value, Color(0.17, 0.09, 0.045))
		return null
	if key == "fence":
		var fence_size = Vector3(1.9, 0.32, 0.18) * scale_value
		if abs(fposmod(yaw, 180.0) - 90.0) < 2.0:
			fence_size = Vector3(0.18, 0.32, 1.9) * scale_value
		_make_prop_box("RouteFence", pos + Vector3(0, 0.46, 0), fence_size, Color(0.15, 0.085, 0.045))
		return null
	var node = _make_role_visual(role_name, "environment", scale_value)
	if node == null:
		return null
	node.position = pos
	node.rotation_degrees.y = yaw
	zone_root.add_child(node)
	return node

func _make_roof(pos: Vector3, size: Vector3, color: Color) -> void:
	_make_prop_box("VillageRoof", pos, size, color)
	_make_prop_box("RoofRidge", pos + Vector3(0, 0.55, 0), Vector3(size.x * 0.18, 0.18, size.z * 1.05), color.darkened(0.18))

func _make_notice_board(pos: Vector3) -> void:
	_make_prop_box("NoticePost", pos + Vector3(-0.55, 0.7, 0), Vector3(0.16, 1.4, 0.16), Color(0.14, 0.08, 0.045))
	_make_prop_box("NoticePost", pos + Vector3(0.55, 0.7, 0), Vector3(0.16, 1.4, 0.16), Color(0.14, 0.08, 0.045))
	_make_prop_box("NoticeBoard", pos + Vector3(0, 1.25, 0), Vector3(1.55, 0.9, 0.12), Color(0.28, 0.16, 0.08))

func _make_route_markers() -> void:
	for pos in [Vector3(-0.9, 0, -4.5), Vector3(0.95, 0, -8.2), Vector3(-0.7, 0, -11.4)]:
		_make_prop_box("RoadCandle", pos + Vector3(0, 0.18, 0), Vector3(0.14, 0.36, 0.14), Color(0.20, 0.11, 0.05))
		var flame = MeshInstance3D.new()
		flame.mesh = SphereMesh.new()
		flame.scale = Vector3(0.12, 0.18, 0.12)
		flame.position = pos + Vector3(0, 0.48, 0)
		flame.material_override = _emissive_mat(Color(1.0, 0.48, 0.16), 1.1)
		zone_root.add_child(flame)
		_make_light("RoadCandleGlow", pos + Vector3(0, 0.72, 0), Color(1.0, 0.45, 0.16), 0.8)

func _make_shrine_scene(pos: Vector3) -> void:
	_make_prop_box("ShrineBase", pos + Vector3(0, 0.15, 0), Vector3(2.0, 0.3, 1.4), Color(0.26, 0.25, 0.23))
	_make_prop_box("ShrineStone", pos + Vector3(0, 0.95, -0.1), Vector3(0.55, 1.55, 0.32), Color(0.46, 0.45, 0.40))
	_make_prop_box("ShrineGlow", pos + Vector3(0, 1.05, -0.29), Vector3(0.08, 0.6, 0.03), Color(0.68, 0.86, 0.70))
	_make_prop_box("ShrineOfferings", pos + Vector3(-0.65, 0.36, -0.45), Vector3(0.52, 0.16, 0.34), Color(0.28, 0.18, 0.10))
	_make_prop_box("ShrineCloth", pos + Vector3(0.58, 0.38, -0.42), Vector3(0.46, 0.08, 0.32), Color(0.36, 0.08, 0.07))
	_make_loose_role("shrine", pos + Vector3(0, 0.15, -0.05), Vector3(1.45, 1.45, 1.45), 0.0)
	_make_loose_role("crate", pos + Vector3(-1.15, 0, -0.65), Vector3.ONE * 0.48, -12.0)
	_make_loose_role("barrel", pos + Vector3(1.2, 0, -0.55), Vector3.ONE * 0.42, 16.0)
	_make_light("ShrineGlow", pos + Vector3(0, 1.7, -0.3), Color(0.56, 0.78, 0.62), 1.6)

func _make_blacksmith_scene(pos: Vector3) -> void:
	_make_prop_box("BlacksmithShop", pos + Vector3(0, 0.9, 1.2), Vector3(3.4, 1.8, 2.4), Color(0.20, 0.15, 0.11))
	_make_prop_box("Forge", pos + Vector3(1.5, 0.55, -0.3), Vector3(1.0, 1.1, 0.75), Color(0.12, 0.11, 0.10))
	_make_prop_box("ForgeCoal", pos + Vector3(1.5, 1.15, -0.3), Vector3(0.75, 0.12, 0.55), Color(0.95, 0.30, 0.08))
	_make_light("ForgeLight", pos + Vector3(1.5, 1.5, -0.3), Color(1.0, 0.35, 0.12), 2.5)
	var anvil = _make_role_visual("blacksmith_shop", "environment", Vector3(0.9, 0.9, 0.9))
	if anvil != null:
		anvil.position = pos + Vector3(-1.2, 0, -0.35)
		zone_root.add_child(anvil)
	_make_loose_role("crate", pos + Vector3(-2.2, 0, 0.35), Vector3.ONE * 0.62, 9.0)
	_make_loose_role("barrel", pos + Vector3(2.15, 0, 0.95), Vector3.ONE * 0.55, -20.0)
	_make_torch(pos + Vector3(-1.8, 0, -1.2))

func _make_cemetery_scene(pos: Vector3) -> void:
	_make_prop_box("CemeteryWall", pos + Vector3(0, 0.35, 1.9), Vector3(7.0, 0.7, 0.45), Color(0.18, 0.18, 0.17))
	for i in range(5):
		_make_gravestone(pos + Vector3(-2.6 + i * 1.3, 0, 0.4 + (i % 2) * 0.75))
	for offset in [Vector3(-3.4, 0, 2.0), Vector3(3.2, 0, 1.8), Vector3(0.4, 0, 2.2)]:
		_make_rubble(pos + offset)
	_make_fog_sheet(pos + Vector3(0, 0.55, 0.8), Vector3(7.2, 0.7, 2.8), Color(0.18, 0.18, 0.16, 0.11))

func _make_tree_cluster(points: Array) -> void:
	for pos in points:
		_make_tree(pos)

func _make_collapsed_road(pos: Vector3) -> void:
	_make_prop_box("BlockedRoadBerm", pos + Vector3(0.8, 0.65, 0), Vector3(3.2, 1.3, 5.4), Color(0.10, 0.095, 0.075))
	_make_prop_box("BlockedRoadPalisade", pos + Vector3(-0.1, 1.05, -1.25), Vector3(0.28, 2.1, 0.28), Color(0.13, 0.075, 0.04))
	_make_prop_box("BlockedRoadPalisade", pos + Vector3(-0.1, 1.05, 1.25), Vector3(0.28, 2.1, 0.28), Color(0.13, 0.075, 0.04))
	_make_prop_box("BlockedRoadRail", pos + Vector3(-0.15, 1.25, 0), Vector3(0.28, 0.28, 3.4), Color(0.15, 0.08, 0.045))
	for offset in [Vector3(0.5, 0, -1.8), Vector3(1.0, 0, 1.6), Vector3(1.4, 0, 0.2)]:
		_make_rubble(pos + offset)
	_make_torch(pos + Vector3(-1.0, 0, -2.1))

func _make_monster_clearing(pos: Vector3) -> void:
	var marker = Node3D.new()
	marker.name = "FirstCombatReadabilityDressing"
	marker.position = pos
	zone_root.add_child(marker)
	_make_road(pos + Vector3(0, 0.023, 0), Vector3(9.0, 0.045, 6.8), Color(0.045, 0.050, 0.042))
	_make_combat_readability_marks(pos)
	_make_light("ClearingColdSpot", pos + Vector3(0, 2.8, -0.4), Color(0.35, 0.48, 0.58), 2.4)
	_make_light("ClearingRimLantern", pos + Vector3(-3.2, 1.9, 1.8), Color(0.9, 0.38, 0.14), 1.2)
	_make_fog_sheet(pos + Vector3(0, 0.55, 0), Vector3(8, 1, 4.5), Color(0.18, 0.25, 0.22, 0.22))
	_make_fog_sheet(pos + Vector3(0, 1.15, -1.8), Vector3(9.2, 1, 3.0), Color(0.16, 0.20, 0.19, 0.16))
	for offset in [Vector3(-5.2,0,-2.9), Vector3(5.2,0,-2.4), Vector3(-5.0,0,2.8), Vector3(5.0,0,3.0)]:
		_make_deadfall(pos + offset)
	for offset in [Vector3(-6.2,0,-3.4), Vector3(6.2,0,-3.2), Vector3(-6.4,0,3.4), Vector3(6.3,0,3.3)]:
		_make_tree(pos + offset)
	for offset in [Vector3(-2.0,0,-1.1), Vector3(1.7,0,-1.4), Vector3(-0.6,0,1.4)]:
		_make_prop_box("BonePile", pos + offset + Vector3(0, 0.09, 0), Vector3(0.9, 0.18, 0.36), Color(0.46, 0.42, 0.35))
	for offset in [Vector3(-1.2,0,0.8), Vector3(1.1,0,0.6), Vector3(0.2,0,-1.9)]:
		_make_prop_box("BlackFeatherScatter", pos + offset + Vector3(0, 0.035, 0), Vector3(0.55, 0.04, 0.10), Color(0.015, 0.014, 0.016))
	for offset in [Vector3(-4.2,0,0.1), Vector3(4.2,0,0.0), Vector3(0,0,-3.2)]:
		_make_rubble(pos + offset)
	_make_loose_role("crate", pos + Vector3(-4.2, 0, 2.1), Vector3.ONE * 0.48, 18.0)
	_make_loose_role("barrel", pos + Vector3(-4.9, 0, 1.4), Vector3.ONE * 0.42, -8.0)
	_make_torch(pos + Vector3(-4.2, 0, 2.1))

func _make_combat_readability_marks(pos: Vector3) -> void:
	_make_visual_box("CombatClearingCenterRead", pos + Vector3(0, 0.054, -0.1), Vector3(2.2, 0.018, 1.55), Color(0.070, 0.052, 0.038))
	for x in [-2.9, 2.9]:
		_make_visual_box("CombatLaneEdge", pos + Vector3(x, 0.056, -0.35), Vector3(0.18, 0.020, 4.6), Color(0.055, 0.070, 0.052))
	for offset in [Vector3(-2.4, 0, -2.6), Vector3(2.4, 0, -2.6), Vector3(-2.6, 0, 1.9), Vector3(2.6, 0, 1.9)]:
		_make_visual_box("CombatSafeFootingStone", pos + offset + Vector3(0, 0.062, 0), Vector3(0.72, 0.035, 0.40), Color(0.16, 0.14, 0.115))
	for offset in [Vector3(-3.8, 0, -1.9), Vector3(3.8, 0, -1.6), Vector3(-3.8, 0, 1.6), Vector3(3.8, 0, 1.4)]:
		_make_visual_box("CombatBoundaryRoot", pos + offset + Vector3(0, 0.14, 0), Vector3(1.15, 0.16, 0.18), Color(0.10, 0.060, 0.035))

func _make_named_interactable(id: String, type: String, prompt: String, pos: Vector3, color: Color, scale_override: Vector3 = Vector3.ONE):
	if _is_interaction_removed(id):
		return null
	var area = Interactable.new()
	area.setup(id, type, prompt)
	area.position = pos
	area.build_collision(1.6)
	zone_root.add_child(area)
	var role = _role_for_interactable(id)
	var mapped = _make_role_visual(role, "characters", Vector3(0.9, 0.9, 0.9) * scale_override)
	if mapped != null:
		area.add_child(mapped)
	elif type == "zone" or type == "blocked_zone":
		_make_gate_marker(area, color, scale_override)
	else:
		var mesh = MeshInstance3D.new()
		mesh.mesh = CapsuleMesh.new()
		mesh.scale = Vector3(0.45, 0.85, 0.45) * scale_override
		mesh.position.y = 0.85 * scale_override.y
		mesh.material_override = _mat(color)
		area.add_child(mesh)
	if type == "dialogue" and id != "notice_board":
		CharacterPresentation.apply_npc(area, id)
	if type != "clue" and type != "herb" and id != "notice_board":
		var label = Label3D.new()
		label.text = _label_for_interactable(id, prompt)
		label.position = Vector3(0, 2.15 * max(scale_override.y, 0.75), 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 22
		label.pixel_size = 0.009
		label.modulate = Color(0.84, 0.78, 0.62)
		label.outline_size = 5
		label.outline_modulate = Color(0.02, 0.018, 0.015)
		area.add_child(label)
	if type == "dialogue" and id != "notice_board":
		var ambient = NpcAmbient.new()
		ambient.setup(id, player)
		area.add_child(ambient)
	_connect_interactable(area)
	return area

func _stage_dialogue_moment(area) -> void:
	if player == null or area == null or not (area is Node3D):
		return
	var npc = area as Node3D
	var flat_to_player = player.global_position - npc.global_position
	flat_to_player.y = 0.0
	var distance = flat_to_player.length()
	if area.interaction_id == "sister_anwen":
		var desired = npc.global_position + Vector3(-0.95, 0, 1.35)
		if distance < 1.05 or distance > 2.8:
			player.global_position = Vector3(desired.x, player.global_position.y, desired.z)
			player.velocity = Vector3.ZERO
	if player.has_method("face_target"):
		player.face_target(npc.global_position)
	var to_player = player.global_position - npc.global_position
	to_player.y = 0.0
	if to_player.length() > 0.1:
		npc.rotation_degrees.y = rad_to_deg(atan2(-to_player.x, -to_player.z))

func _make_gate_marker(parent: Node3D, color: Color, scale_override: Vector3) -> void:
	var arch = MeshInstance3D.new()
	var arch_mesh = BoxMesh.new()
	arch_mesh.size = Vector3(1.2, 1.6, 0.18)
	arch.mesh = arch_mesh
	arch.position.y = 0.8
	arch.scale = scale_override
	arch.material_override = _mat(color)
	parent.add_child(arch)
	var lintel = MeshInstance3D.new()
	var lintel_mesh = BoxMesh.new()
	lintel_mesh.size = Vector3(1.75, 0.22, 0.26)
	lintel.mesh = lintel_mesh
	lintel.position.y = 1.65 * scale_override.y
	lintel.material_override = _mat(color.lightened(0.12))
	parent.add_child(lintel)

func _label_for_interactable(id: String, prompt: String) -> String:
	if dialogue != null and dialogue.dialogues.has(id):
		return dialogue.dialogues[id].get("name", prompt)
	if id.begins_with("gate_"):
		return prompt
	return prompt.replace("Inspect ", "").replace("Gather ", "").replace("Take ", "")

func _make_clue(id: String, prompt: String, pos: Vector3, quest_id: String, objective_id: String, color: Color):
	var area = _make_named_interactable(id, "clue", prompt, pos, color, Vector3(0.55, 0.25, 0.55))
	if area == null:
		return null
	area.quest_id = quest_id
	area.objective_id = objective_id
	return area

func _make_herb(id: String, pos: Vector3, color: Color):
	return _make_named_interactable(id, "herb", "Gather %s" % id.capitalize(), pos, color, Vector3(0.35, 0.35, 0.35))

func _make_zone_gate(prompt: String, pos: Vector3, zone_target: String, spawn_pos: Vector3):
	var area = _make_named_interactable("gate_%s" % zone_target, "zone", prompt, pos, Color(0.18, 0.22, 0.28), Vector3(1.0, 1.2, 1.0))
	if area == null:
		return null
	area.zone_target = zone_target
	area.set_meta("spawn_pos", spawn_pos)
	return area

func _make_blocked_gate(prompt: String, pos: Vector3, message: String):
	var area = _make_named_interactable("blocked_ruins", "blocked_zone", prompt, pos, Color(0.20, 0.16, 0.11), Vector3(0.8, 0.8, 0.8))
	if area == null:
		return null
	area.set_meta("message", message)
	return area

func _connect_interactable(area) -> void:
	area.body_entered.connect(func(body: Node):
		if body == player:
			active_interactable = area
			hud.set_prompt("E - %s" % area.prompt)
	)
	area.body_exited.connect(func(body: Node):
		if body == player and active_interactable == area:
			active_interactable = null
			hud.set_prompt("")
	)

func _spawn_enemy(id: String, pos: Vector3) -> Node:
	if active_enemies.size() >= 5:
		return null
	var enemy = EnemyAI.new()
	zone_root.add_child(enemy)
	enemy.global_position = pos
	enemy.setup(id, enemy_defs.get(id, {}), player)
	if id == "ghoulkin":
		enemy.rotation_degrees.y = 180.0
		if audio != null and current_zone_id == "wychwood" and not bool(tutorial_flags.get("ghoulkin_spawn_audio", false)):
			tutorial_flags["ghoulkin_spawn_audio"] = true
			audio.play_event("ghoulkin_idle", 0.025)
	enemy.died.connect(_on_enemy_died)
	enemy.damaged.connect(_on_enemy_damaged)
	enemy.windup_started.connect(_on_enemy_windup_started)
	enemy.attack_resolved.connect(_on_enemy_attack_resolved)
	active_enemies.append(enemy)
	return enemy

func _make_ground(pos: Vector3, size: Vector3, color: Color) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	zone_root.add_child(body)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh = MeshInstance3D.new()
	var cube = BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.material_override = _mat(color)
	body.add_child(mesh)

func _make_hut(pos: Vector3) -> void:
	_make_prop_box("Hut", pos + Vector3(0, 1, 0), Vector3(3.6, 2, 3.0), Color(0.22, 0.16, 0.12))
	_make_prop_box("Roof", pos + Vector3(0, 2.25, 0), Vector3(4.2, 0.8, 3.6), Color(0.10, 0.09, 0.08))
	_make_prop_box("Door", pos + Vector3(0, 0.65, -1.54), Vector3(0.75, 1.25, 0.08), Color(0.10, 0.07, 0.045))
	_make_prop_box("Chimney", pos + Vector3(1.1, 2.95, 0.4), Vector3(0.38, 0.9, 0.38), Color(0.12, 0.11, 0.10))

func _make_tree(pos: Vector3) -> void:
	pos = _route_safe_position(pos, 4.9)
	if _is_first_route_clearance(pos, 1.55):
		return
	_make_prop_box("TreeTrunk", pos + Vector3(0, 0.9, 0), Vector3(0.42, 1.8, 0.42), Color(0.16, 0.095, 0.055))
	var crown = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = randf_range(1.0, 1.35)
	cone.height = randf_range(2.0, 2.7)
	cone.radial_segments = 6
	crown.mesh = cone
	crown.position = pos + Vector3(0, 2.35, 0)
	crown.rotation_degrees.y = randf_range(0, 360)
	crown.material_override = _mat(Color(0.055, 0.18, 0.085).lerp(Color(0.13, 0.24, 0.11), randf()))
	zone_root.add_child(crown)
	_make_invisible_wall(pos + Vector3(0, 2.1, 0), Vector3(2.6, 4.2, 2.6))

func _make_tree_wall(axis_extent: float, fixed_pos: float, count: int, along_x: bool) -> void:
	for i in range(count):
		var t: float = 0.0 if count <= 1 else float(i) / float(count - 1)
		var offset: float = lerp(-axis_extent, axis_extent, t)
		var pos = Vector3(offset, 0, fixed_pos) if along_x else Vector3(fixed_pos, 0, offset)
		_make_tree(pos + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.5, 0.5)))

func _make_deadfall(pos: Vector3) -> void:
	var trunk = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.22
	mesh.height = 3.4
	trunk.mesh = mesh
	trunk.position = pos + Vector3(0, 0.35, 0)
	trunk.rotation_degrees = Vector3(88, randf_range(-20, 20), randf_range(-8, 8))
	trunk.material_override = _mat(Color(0.12, 0.075, 0.045))
	zone_root.add_child(trunk)

func _make_road(pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh = MeshInstance3D.new()
	mesh.name = "PavedRoad" if current_zone_id == "greyfen" else "MudRoad"
	var cube = BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.position = pos
	mesh.material_override = _road_material(current_zone_id == "greyfen", color)
	zone_root.add_child(mesh)

func _make_fence(pos: Vector3, vertical: bool) -> void:
	_make_prop_box("FencePost", pos + Vector3(0, 0.2, 0), Vector3(0.16, 0.8, 0.16), Color(0.15, 0.09, 0.055))
	var rail_size = Vector3(2.5, 0.12, 0.12)
	if vertical:
		rail_size = Vector3(0.12, 0.12, 2.5)
	_make_prop_box("FenceRail", pos + Vector3(0, 0.52, 0), rail_size, Color(0.17, 0.105, 0.06))

func _make_gravestone(pos: Vector3) -> void:
	_make_prop_box("Gravestone", pos + Vector3(0, 0.45, 0), Vector3(0.45, 0.9, 0.18), Color(0.31, 0.31, 0.30))
	_make_prop_box("GraveBase", pos + Vector3(0, 0.09, 0.34), Vector3(0.75, 0.16, 1.0), Color(0.11, 0.10, 0.09))
	_make_prop_box("GraveMoss", pos + Vector3(0.08, 0.72, -0.095), Vector3(0.18, 0.20, 0.025), Color(0.09, 0.18, 0.08))

func _make_cart(pos: Vector3) -> void:
	_make_prop_box("BrokenCartBed", pos + Vector3(0, 0.45, 0), Vector3(2.0, 0.28, 1.1), Color(0.17, 0.10, 0.055))
	for x in [-0.78, 0.78]:
		var wheel = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		mesh.top_radius = 0.35
		mesh.bottom_radius = 0.35
		mesh.height = 0.12
		wheel.mesh = mesh
		wheel.position = pos + Vector3(x, 0.35, -0.62)
		wheel.rotation_degrees.z = 90
		wheel.material_override = _mat(Color(0.07, 0.05, 0.035))
		zone_root.add_child(wheel)

func _make_ritual_stone(pos: Vector3) -> void:
	_make_prop_box("RitualStone", pos + Vector3(0, 0.8, 0), Vector3(0.6, 1.6, 0.35), Color(0.32, 0.34, 0.32))
	var rune = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.05, 0.42, 0.02)
	rune.mesh = mesh
	rune.position = pos + Vector3(0, 0.95, -0.19)
	rune.material_override = _emissive_mat(Color(0.64, 0.85, 0.72), 0.55)
	zone_root.add_child(rune)

func _make_pillar(pos: Vector3) -> void:
	var mapped = _make_role_visual("ruins_pillar", "environment", Vector3(1.2, 1.2, 1.2))
	if mapped != null:
		mapped.position = pos
		zone_root.add_child(mapped)
		return
	var pillar = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.48
	mesh.height = 3.0
	mesh.radial_segments = 8
	pillar.mesh = mesh
	pillar.position = pos + Vector3(0, 1.5, 0)
	pillar.material_override = _mat(Color(0.27, 0.27, 0.25))
	zone_root.add_child(pillar)

func _make_rubble(pos: Vector3) -> void:
	pos = _route_safe_position(pos, 3.8)
	if _is_first_route_clearance(pos, 0.95):
		return
	for i in range(2):
		var offset = Vector3(randf_range(-0.18, 0.18), 0, randf_range(-0.16, 0.16))
		_make_prop_box("Rubble", pos + offset + Vector3(0, 0.16, 0), Vector3(randf_range(0.45, 0.95), randf_range(0.20, 0.42), randf_range(0.35, 0.82)), Color(0.18, 0.18, 0.165).lerp(Color(0.08, 0.13, 0.08), randf() * 0.35))

func _make_torch(pos: Vector3) -> void:
	_make_prop_box("TorchPost", pos + Vector3(0, 0.85, 0), Vector3(0.13, 1.7, 0.13), Color(0.10, 0.06, 0.035))
	var flame = MeshInstance3D.new()
	flame.mesh = SphereMesh.new()
	flame.scale = Vector3(0.22, 0.34, 0.22)
	flame.position = pos + Vector3(0, 1.75, 0)
	flame.material_override = _emissive_mat(Color(1.0, 0.45, 0.14), 1.4)
	zone_root.add_child(flame)
	_make_light("TorchLight", pos + Vector3(0, 1.8, 0), Color(1.0, 0.45, 0.16), 2.3)

func _make_hit_spark(pos: Vector3, heavy: bool) -> void:
	if zone_root == null:
		return
	var spark = MeshInstance3D.new()
	spark.mesh = SphereMesh.new()
	spark.scale = Vector3.ONE * (0.22 if heavy else 0.14)
	spark.global_position = pos
	spark.material_override = _emissive_mat(Color(1.0, 0.68, 0.24), 1.8)
	zone_root.add_child(spark)
	var tween = create_tween()
	tween.tween_property(spark, "scale", Vector3.ONE * 0.02, 0.18)
	tween.parallel().tween_property(spark, "position:y", spark.position.y + 0.45, 0.18)
	tween.tween_callback(spark.queue_free)

func _make_fog_sheet(pos: Vector3, scale_value: Vector3, color: Color) -> void:
	if _performance_mode() and current_zone_id == "greyfen":
		return
	if _performance_mode() and randf() < 0.45:
		return
	var fog = MeshInstance3D.new()
	fog.mesh = PlaneMesh.new()
	fog.position = pos
	fog.scale = scale_value
	fog.rotation_degrees.x = 90
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog.material_override = material
	zone_root.add_child(fog)

func _make_prop_box(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var body = StaticBody3D.new()
	body.name = name
	body.position = pos
	zone_root.add_child(body)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh = MeshInstance3D.new()
	var cube = BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.material_override = _mat(color)
	body.add_child(mesh)

func _is_first_route_clearance(pos: Vector3, radius: float = 0.0) -> bool:
	if current_zone_id == "greyfen":
		if abs(pos.x) < 2.85 + radius and pos.z > -15.8 and pos.z < 13.4:
			return true
		if pos.x > 1.2 - radius and pos.x < 7.0 + radius and pos.z > -8.8 - radius and pos.z < -3.8 + radius:
			return true
	elif current_zone_id == "wychwood":
		if abs(pos.x) < 3.15 + radius and pos.z > -13.2 and pos.z < 14.2:
			return true
		if abs(pos.x) < 4.4 + radius and pos.z > -9.8 and pos.z < -3.0:
			return true
	return false

func _route_safe_position(pos: Vector3, target_x: float) -> Vector3:
	if not _is_first_route_clearance(pos, 0.0):
		return pos
	var side = -1.0 if pos.x < 0.0 else 1.0
	if abs(pos.x) < 0.2:
		side = -1.0 if randf() < 0.5 else 1.0
	pos.x = side * target_x
	return pos

func _apply_first_route_materials(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		_apply_first_route_materials(child)
	if root is MeshInstance3D:
		var mesh_instance = root as MeshInstance3D
		var palette_key = _first_route_palette_key(mesh_instance)
		if palette_key == "":
			return
		if _mesh_needs_visible_fallback(mesh_instance):
			mesh_instance.material_override = _first_route_material(palette_key)

func _first_route_palette_key(node: Node) -> String:
	var combined = _node_keyword_path(node)
	if combined.contains("roof"):
		return "roof"
	if combined.contains("house") or combined.contains("wall") or combined.contains("plaster"):
		return "wall"
	if combined.contains("tree") or combined.contains("trunk"):
		return "trunk"
	if combined.contains("leaf") or combined.contains("leaves") or combined.contains("crown"):
		return "leaves"
	if combined.contains("rock") or combined.contains("rubble") or combined.contains("stone") or combined.contains("pathstone"):
		return "rock"
	if combined.contains("grave"):
		return "grave"
	if combined.contains("shrine"):
		return "shrine"
	if combined.contains("fence") or combined.contains("wood") or combined.contains("cart") or combined.contains("crate") or combined.contains("barrel") or combined.contains("torch"):
		return "wood"
	if combined.contains("road") or combined.contains("mud") or combined.contains("ground") or combined.contains("berm"):
		return "ground"
	if combined.contains("cloth") or combined.contains("cloak") or combined.contains("robe"):
		return "cloth"
	if combined.contains("skin") or combined.contains("face") or combined.contains("sister") or combined.contains("npc") or combined.contains("villager"):
		return "skin"
	if combined.contains("ghoul") or combined.contains("monster") or combined.contains("enemy"):
		return "monster"
	if combined.contains("metal") or combined.contains("sword") or combined.contains("blade"):
		return "metal"
	return ""

func _node_keyword_path(node: Node) -> String:
	var combined = ""
	var current: Node = node
	while current != null and current != zone_root:
		combined += " " + String(current.name).to_lower()
		current = current.get_parent()
	return combined

func _mesh_needs_visible_fallback(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.material_override != null:
		return _is_bad_white_material(mesh_instance.material_override)
	if mesh_instance.mesh == null:
		return true
	var saw_material = false
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var material = mesh_instance.mesh.surface_get_material(surface_index)
		if material == null:
			continue
		saw_material = true
		if _is_bad_white_material(material):
			return true
	return not saw_material

func _is_bad_white_material(material: Material) -> bool:
	if material == null:
		return true
	if material is StandardMaterial3D:
		var standard = material as StandardMaterial3D
		var has_texture = standard.albedo_texture != null
		var color = standard.albedo_color
		return not has_texture and color.r > 0.85 and color.g > 0.85 and color.b > 0.85
	return false

func _first_route_material(key: String) -> StandardMaterial3D:
	var cache_key = "first_route:%s" % key
	if material_cache.has(cache_key):
		return material_cache[cache_key]
	var colors = {
		"rock": Color(0.17, 0.18, 0.16),
		"trunk": Color(0.16, 0.095, 0.055),
		"leaves": Color(0.055, 0.15, 0.075),
		"roof": Color(0.13, 0.055, 0.035),
		"wall": Color(0.30, 0.22, 0.15),
		"grave": Color(0.30, 0.31, 0.30),
		"shrine": Color(0.37, 0.38, 0.35),
		"ground": Color(0.11, 0.10, 0.07),
		"wood": Color(0.16, 0.09, 0.045),
		"metal": Color(0.44, 0.44, 0.42),
		"cloth": Color(0.11, 0.12, 0.13),
		"skin": Color(0.66, 0.52, 0.40),
		"monster": Color(0.15, 0.20, 0.14)
	}
	var material = StandardMaterial3D.new()
	material.albedo_color = colors.get(key, Color(0.24, 0.24, 0.22))
	material.roughness = 0.86
	if key == "metal":
		material.metallic = 0.35
		material.roughness = 0.52
	material_cache[cache_key] = material
	return material

func _role_for_interactable(id: String) -> String:
	var roles = {
		"sister_anwen": "sister_anwen",
		"mira": "mira_herbalist",
		"rook": "rook_smuggler",
		"widow_elna": "widow_elna",
		"blacksmith_tor": "blacksmith_tor",
		"farmer_toma": "generic_villager_01",
		"edric": "lord_edric",
		"white_hart": "white_hart_avatar"
	}
	return str(roles.get(id, ""))

func _visual_role_for_interactable(id: String) -> String:
	var roles = {
		"sister_anwen": "sister_anwen_human",
		"mira": "mira_human",
		"rook": "rook_human",
		"widow_elna": "villager_human",
		"blacksmith_tor": "villager_human",
		"farmer_toma": "villager_human"
	}
	return str(roles.get(id, ""))

func _role_for_prop(name: String) -> String:
	var key = name.to_lower()
	if key.contains("crate"):
		return "crate"
	if key.contains("barrel"):
		return "barrel"
	return ""

func _make_role_visual(role_name: String, category: String, scale_value: Vector3) -> Node3D:
	if role_name == "" or asset_helper == null:
		return null
	if _performance_mode() and category == "environment":
		return null
	var node: Node3D
	if category == "characters":
		var visual_role = _visual_role_for_legacy_character(role_name)
		if visual_role != "" and asset_helper.has_method("spawn_visual_role") and asset_helper.has_method("has_visual_role") and asset_helper.has_visual_role(visual_role):
			node = asset_helper.spawn_visual_role(visual_role, "characters")
			if node != null and not node.name.ends_with("_placeholder"):
				node.scale = scale_value
				return node
			if node != null:
				node.queue_free()
		node = asset_helper.spawn_character(role_name)
	elif category == "enemies":
		node = asset_helper.spawn_enemy(role_name)
	else:
		node = asset_helper.spawn_environment(role_name)
	if node == null or node.name.ends_with("_placeholder"):
		if node != null:
			node.queue_free()
		return null
	node.scale = scale_value
	return node

func _visual_role_for_legacy_character(role_name: String) -> String:
	var roles = {
		"player_kael": "player_human",
		"sister_anwen": "sister_anwen_human",
		"mira_herbalist": "mira_human",
		"rook_smuggler": "rook_human",
		"widow_elna": "villager_human",
		"blacksmith_tor": "villager_human",
		"generic_villager_01": "villager_human",
		"lord_edric": "villager_human"
	}
	return str(roles.get(role_name, ""))

func _make_light(name: String, pos: Vector3, color: Color, energy: float) -> void:
	if _performance_mode() and not _keep_performance_light(name):
		return
	var light = OmniLight3D.new()
	light.name = name
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 8.0 if _performance_mode() else 14.0
	if settings != null and int(settings.settings.get("shadow_quality", 0)) <= 0:
		light.shadow_enabled = false
	else:
		light.shadow_enabled = true
	zone_root.add_child(light)

func _performance_mode() -> bool:
	return settings != null and bool(settings.settings.get("potato_mode", true))

func _keep_performance_light(name: String) -> bool:
	return name in ["Village Warmth", "Shrine Beacon", "Wychwood Gate Lantern", "Moon Shaft", "Trail Threat", "ClearingColdSpot", "SpawnWarmRead"]

func _build_global_environment() -> void:
	visual_director = VisualDirector.new()
	add_child(visual_director)

func _mat(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _terrain_material(name: String, color: Color) -> StandardMaterial3D:
	var key = "terrain:%s:%s" % [name, color.to_html()]
	if material_cache.has(key):
		return material_cache[key]
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	material.metallic = 0.0
	if name.to_lower().contains("mud") or name.to_lower().contains("wet"):
		material.albedo_color = color.lerp(Color(0.025, 0.030, 0.026), 0.35)
		material.roughness = 0.70
	elif name.to_lower().contains("green") or name.to_lower().contains("shoulder"):
		material.albedo_color = color.lerp(Color(0.060, 0.120, 0.055), 0.24)
	material_cache[key] = material
	return material

func _road_material(paved: bool, color: Color) -> StandardMaterial3D:
	var key = "road:paved" if paved else "road:mud"
	if material_cache.has(key):
		return material_cache[key]
	var material = StandardMaterial3D.new()
	if paved:
		material.albedo_color = color.lerp(Color(0.22, 0.20, 0.17), 0.45)
		material.roughness = 0.96
	else:
		material.albedo_color = color.lerp(Color(0.026, 0.034, 0.030), 0.55)
		material.roughness = 0.68
	material_cache[key] = material
	return material

func _grass_material(color: Color) -> StandardMaterial3D:
	var key = "grass:%s" % color.to_html()
	if material_cache.has(key):
		return material_cache[key]
	var material = StandardMaterial3D.new()
	material.albedo_color = color.lerp(Color(0.075, 0.115, 0.060), 0.28)
	material.roughness = 0.88
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_cache[key] = material
	return material

func _emissive_mat(color: Color, energy: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		push_warning("Missing JSON: %s" % path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed != null else {}

func _ensure_input_map() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("run", KEY_SHIFT)
	_add_key_action("dodge", KEY_SPACE)
	_add_key_action("block", KEY_Q)
	_add_key_action("interact", KEY_E)
	_add_key_action("use_potion", KEY_R)
	_add_key_action("throw_bomb", KEY_F)
	_add_key_action("open_inventory", KEY_TAB)
	_add_key_action("pause", KEY_ESCAPE)
	_add_key_action("camera_left", KEY_LEFT)
	_add_key_action("camera_right", KEY_RIGHT)
	_add_key_action("camera_up", KEY_UP)
	_add_key_action("camera_down", KEY_DOWN)
	_add_mouse_action("light_attack", MOUSE_BUTTON_LEFT)
	_add_mouse_action("heavy_attack", MOUSE_BUTTON_RIGHT)

func _add_key_action(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var event = InputEventKey.new()
		event.keycode = keycode
		InputMap.action_add_event(action, event)

func _add_mouse_action(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var event = InputEventMouseButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)
