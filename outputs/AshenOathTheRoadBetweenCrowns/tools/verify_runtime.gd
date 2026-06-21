extends SceneTree

const AssetDatabase = preload("res://scripts/asset_database.gd")
const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")

func _initialize() -> void:
	_assert(_release_shape_is_web_only(), "Release shape is not web-only")
	_assert(_visual_roles_are_imported(), "One or more major visual roles are not imported ResourceLoader assets")
	var scene = load("res://scenes/main.tscn")
	if scene == null:
		_fail("main scene failed to load")
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _settle_frames(3)
	_assert(str(game.current_zone_id) == "greyfen", "Greyfen did not load as the new-game zone")
	_assert(game.quests.is_active("main_road_of_crows"), "Main contract did not start for the vertical slice")
	_assert(str(game.quests.quest_defs["main_road_of_crows"]["objectives"][1]["text"]).contains("blood-dark"), "Road of Crows narrative objective text is missing")
	_assert(str(game.quests.quest_defs["main_road_of_crows"]["objectives"][5]["text"]).contains("confessed"), "Road of Crows return/report objective is not narrative-forward")
	_assert(game.audio.has_method("play_voice"), "AudioManager is missing voice playback hook")
	_assert(game.audio.has_method("set_music_state"), "AudioManager is missing dynamic music state hook")
	game.audio.play_voice("missing_voice_should_not_crash")
	game.audio.set_music_state("greyfen_explore")
	_assert(str(game.audio.music_state) == "greyfen_explore", "Greyfen music state did not activate")
	_assert(_has_child_named(game.hud, "QuestTrackerObjective"), "Quest tracker HUD objective is missing")
	_assert(_has_child_named(game.hud, "EquipmentQuickRead"), "Equipment quick-read HUD is missing")
	_assert(_has_child_named(game.hud, "ContextualCombatHint"), "Contextual guidance hint HUD is missing")
	_assert(str(game.hud.tracker_label.text).contains("SPEAK") or str(game.hud.tracker_label.text).contains("Speak"), "First objective HUD text is not readable")
	_assert(_has_child_named(game, "SkyGradientDome"), "VisualDirector sky dome is missing")
	_assert(_has_child_named(game, "SunDisc"), "VisualDirector sun disc is missing")
	_assert(_has_child_named(game, "CloudLayer"), "VisualDirector cloud layer is missing")
	_assert(_has_child_named(game.zone_root, "GreyfenSpawnComposition"), "Greyfen spawn composition marker is missing")
	_assert(_has_child_named(game.zone_root, "GreyfenFirstImpressionDressing"), "Greyfen first-impression dressing marker is missing")
	_assert(_has_child_named(game.zone_root, "QualityGreyfenVisualOverhaul"), "Quality Greyfen visual overhaul marker is missing")
	_assert(_has_child_named(game.zone_root, "GreyfenPathEdgeComposition"), "Greyfen path edge composition marker is missing")
	_assert(_has_child_named(game.zone_root, "RoadOfCrowsGreyfenStoryBeats"), "Greyfen Road of Crows environmental story beats are missing")
	_assert(_has_child_named(game.zone_root, "RoadCrowsNoticeBlackFeathers"), "Notice board black-feather story beat is missing")
	_assert(_has_child_named(game.zone_root, "RoadCrowsShrineSnappedToken"), "Shrine broken-token story beat is missing")
	_assert(_has_child_named(game.zone_root, "RoadCrowsGraveyardDisturbedSoil"), "Graveyard omen story beat is missing")
	_assert(_has_child_named(game.zone_root, "RoadCrowsGateClawedPost"), "Wychwood gate claw-mark threshold beat is missing")
	_assert(_has_child_named(game.zone_root, "PavedRoad"), "Greyfen paved road material anchor is missing")
	_assert(_grass_state_is_valid(game), "Greyfen batched grass is missing outside performance mode")
	_assert(_count_name_prefix(game.zone_root, "DressedVillageHouse") >= 4, "Greyfen does not have enough dressed village houses")
	var rut_count = _count_name_contains(game.zone_root, "RoadWheelRut")
	var lantern_count = _count_name_contains(game.zone_root, "LanternGlow")
	_assert(rut_count >= 8, "Greyfen road readability ruts are missing; found %d; sample=%s" % [rut_count, _debug_names(game.zone_root)])
	_assert(lantern_count >= 4, "Greyfen lantern rhythm is missing; found %d; sample=%s" % [lantern_count, _debug_names(game.zone_root)])
	_assert(_count_name_prefix(game.zone_root, "Greyfen") >= 4, "Greyfen terrain layering is missing")
	_assert(not _has_player_placeholder(game), "Player is still using a placeholder visual")
	var sister = _find_child_named(game.zone_root, "sister_anwen")
	_assert(sister != null, "Sister Anwen is missing from Greyfen")
	_assert(str(game.dialogue.dialogues["sister_anwen"]["greeting"]).contains("Fear"), "Sister Anwen first dialogue lost its emotional hook")
	_assert(str(game.dialogue.dialogues["sister_anwen"]["lines"][2]).contains("not ready"), "Sister Anwen withholding-truth beat is missing")
	_assert(game.dialogue.dialogues["sister_anwen"].has("voice"), "Sister Anwen dialogue is missing voice metadata")
	_assert(game.audio.has_voice("voice_sister_anwen_greeting_01"), "Sister Anwen generated voice clip is unavailable")
	_assert(str(game.dialogue.dialogues["rook"]["lines"][1]).contains("black feathers"), "Greyfen micro-story black-feather rumor is missing")
	_assert(_count_name_contains(game.player, "CharacterContactShadow") >= 1, "Player contact shadow is missing")
	_assert(_count_name_contains(game.player, "PlayerCloakSilhouette") >= 1, "Player silhouette overlay is missing")
	_assert(_count_name_contains(game.player, "PlayerLeatherHarness") >= 1, "Player Phase 1G harness overlay is missing")
	_assert(_count_name_contains(game.player, "PlayerBootRead") >= 1, "Player Phase 1G boot grounding is missing")
	_assert(_count_name_contains(sister, "CharacterContactShadow") >= 1, "Sister Anwen contact shadow is missing")
	_assert(_count_name_contains(sister, "SisterAnwenRobeFall") >= 1, "Sister Anwen presentation overlay is missing")
	_assert(_count_name_contains(sister, "SisterAnwenStaffCap") >= 1, "Sister Anwen Phase 1G staff read is missing")
	game.call("_handle_interaction", sister)
	await _settle_frames(1)
	_assert(paused, "Dialogue did not pause the game")
	_assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Dialogue did not release the mouse pointer")
	_assert(game.player.global_position.distance_to((sister as Node3D).global_position) >= 1.0, "Dialogue staging placed the player too close to Sister Anwen")
	paused = false
	game.hud.hide_menus()
	await _settle_frames(1)
	if DisplayServer.get_name().to_lower() != "headless":
		_assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Gameplay did not recapture the mouse after closing dialogue")
	_assert(_has_child_named(game.zone_root, "blocked_ruins"), "Blocked Castle Vargan gate is missing")
	var blocked = _find_child_named(game.zone_root, "blocked_ruins")
	if blocked == null:
		_fail("Blocked Castle Vargan gate lookup failed after presence assertion")
		return
	game.call("_handle_interaction", blocked)
	await _settle_frames(1)
	_assert(str(game.current_zone_id) == "greyfen", "Blocked ruins gate changed zones")

	game.call("_load_zone", "wychwood", Vector3(0, 1, 13))
	await _settle_frames(3)
	_assert(str(game.current_zone_id) == "wychwood", "Wychwood did not load")
	_assert(str(game.audio.music_state) in ["wychwood_tension", "ghoulkin_combat"], "Wychwood music state did not activate")
	_assert(_has_child_named(game.zone_root, "WychwoodCorridorComposition"), "Wychwood corridor composition marker is missing")
	_assert(_has_child_named(game.zone_root, "WychwoodPathEdgeComposition"), "Wychwood path edge composition marker is missing")
	_assert(_has_child_named(game.zone_root, "FirstCombatReadabilityDressing"), "First combat readability dressing marker is missing")
	_assert(_has_child_named(game.zone_root, "QualityWychwoodVisualOverhaul"), "Quality Wychwood visual overhaul marker is missing")
	_assert(_has_child_named(game.zone_root, "RoadOfCrowsWychwoodStoryBeats"), "Wychwood Road of Crows environmental story beats are missing")
	_assert(_has_child_named(game.zone_root, "RoadCrowsBrokenCartSupplySack"), "Broken cart supply story beat is missing")
	_assert(_has_child_named(game.zone_root, "RoadCrowsDraggedTrackA"), "Old road drag-mark story beat is missing")
	_assert(_has_child_named(game.zone_root, "RoadCrowsBrokenPrayerToken"), "Broken prayer token story beat is missing")
	_assert(_has_child_named(game.zone_root, "RoadCrowsClearingOldBloodMud"), "Ghoulkin clearing blood-mud payoff is missing")
	_assert(_has_child_named(game.zone_root, "MudRoad"), "Wychwood mud road material anchor is missing")
	_assert(_grass_state_is_valid(game), "Wychwood batched grass is missing outside performance mode")
	_assert(_count_name_prefix(game.zone_root, "Wychwood") >= 4, "Wychwood terrain layering is missing")
	_assert(game.active_enemies.size() >= 2, "First ghoulkin encounter did not spawn")
	_assert(_living_enemy_count(game, "ghoulkin") >= 2, "Ghoulkin encounter is incomplete")
	var tracks = _find_child_named(game.zone_root, "tracks")
	_assert(tracks != null, "Road of Crows tracks clue is missing")
	var corpse = _find_child_named(game.zone_root, "corpse")
	var feathers = _find_child_named(game.zone_root, "black_feathers")
	_assert(corpse != null and str(corpse.prompt).contains("blood-dark"), "Blood-dark corpse clue prompt is missing")
	_assert(feathers != null and str(feathers.prompt).contains("black feathers"), "Black feathers clue prompt is missing")
	game.call("_handle_interaction", tracks)
	await _settle_frames(1)
	_assert(game.quests.is_objective_done("main_road_of_crows", "inspect_corpse"), "Tracks did not safely complete skipped corpse clue")
	_assert(game.quests.is_objective_done("main_road_of_crows", "find_claw_marks"), "Tracks did not safely complete skipped claw clue")
	_assert(game.quests.is_objective_done("main_road_of_crows", "find_black_feathers"), "Tracks did not safely complete skipped feather clue")
	_assert(not game.quests.is_objective_done("main_road_of_crows", "return_village"), "Tracks completed return/report before Ghoulkin victory")
	if game.active_enemies.size() > 0:
		game.audio.set_music_state("ghoulkin_combat")
		_assert(str(game.audio.music_state) == "ghoulkin_combat", "Ghoulkin combat music state did not activate")
		_assert(_count_name_contains(game.active_enemies[0], "CharacterContactShadow") >= 1, "Enemy contact shadow is missing")
		_assert(_count_name_contains(game.active_enemies[0], "GhoulkinLongArm") >= 1, "Ghoulkin Phase 1G long-arm silhouette is missing")
		_assert(_count_name_contains(game.active_enemies[0], "GhoulkinEye") >= 1, "Ghoulkin Phase 1G eye read is missing")
		game.active_enemies[0].windup_time = 0.30
		game.active_enemies[0].call("_show_windup_marker")
		game.call("_on_enemy_windup_started", game.active_enemies[0])
		await _settle_frames(1)
		_assert(_count_name_contains(game.active_enemies[0], "EnemyWindupWarning") >= 1, "Enemy windup warning marker is missing")
		_assert(game.hud.enemy_bar.visible, "Enemy health HUD did not appear during first combat")
		_assert(game.hud.hint_label.visible, "Block/parry contextual hint did not appear during first combat")
	if game.active_enemies.size() >= 2:
		game.call("_on_enemy_died", game.active_enemies[0])
		game.call("_on_enemy_died", game.active_enemies[1])
		await _settle_frames(1)
		_assert(game.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"), "Ghoulkin victory did not complete fight objective")
		_assert(game.quests.is_active("main_road_of_crows"), "Road of Crows completed before return/report")
		_assert(str(game.hud.tracker_label.text).contains("Return to Greyfen"), "Return/report objective is not visible after victory")
		_assert(str(game.audio.music_state) == "return_report", "Victory did not move audio toward return/report music state")
		_assert(_has_child_named(game.zone_root, "RoadCrowsPostVictoryBootTracks"), "Post-victory human boot-track clue is missing")
	_assert(not _has_placeholder_major_visuals(game), "Major characters or enemies are still using placeholder visuals")

	game.call("_load_zone", "greyfen", Vector3(0, 1, 7))
	await _settle_frames(2)
	var report_sister = _find_child_named(game.zone_root, "sister_anwen")
	_assert(report_sister != null, "Sister Anwen report target is missing")
	game.call("_handle_interaction", report_sister)
	await _settle_frames(1)
	_assert(game.quests.is_completed("main_road_of_crows"), "Reporting to Sister Anwen did not complete Road of Crows")
	paused = false
	game.hud.hide_menus()
	game.player.global_position = Vector3(0, -20, 0)
	await _settle_frames(3)
	_assert(game.player.global_position.y > -5, "Fall recovery failed")
	_assert(FileAccess.file_exists("res://visual_upgrade_manifest.json"), "Visual upgrade manifest is missing")
	_assert(FileAccess.file_exists("res://MISSING_VISUAL_ASSETS.md"), "Missing visual asset report is missing")

	game.queue_free()
	await process_frame
	print("runtime vertical slice verification complete")
	quit()

func _settle_frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _debug_names(root_node: Node, limit: int = 40) -> String:
	var names: Array[String] = []
	_collect_names(root_node, names, limit)
	return ", ".join(names)

func _collect_names(root_node: Node, names: Array[String], limit: int) -> void:
	if root_node == null or names.size() >= limit:
		return
	names.append(root_node.name)
	for child in root_node.get_children():
		_collect_names(child, names, limit)

func _release_shape_is_web_only() -> bool:
	var presets = FileAccess.get_file_as_string("res://export_presets.cfg")
	if presets.contains("Windows Low Spec") or presets.contains("Windows Desktop") or presets.contains("AshenOath_Windows"):
		return false
	if FileAccess.file_exists("res://Export_Windows_Build.bat"):
		return false
	var project_root = ProjectSettings.globalize_path("res://")
	for folder_name in ["Probe_Web", "work_web_export_probe"]:
		if DirAccess.dir_exists_absolute(project_root.path_join(folder_name)):
			return false
	var outputs_root = project_root.path_join("..").simplify_path()
	if DirAccess.dir_exists_absolute(outputs_root.path_join("AshenOath_Windows")):
		return false
	return true

func _has_child_named(root_node: Node, node_name: String) -> bool:
	return _find_child_named(root_node, node_name) != null

func _grass_state_is_valid(game) -> bool:
	var potato = game.settings != null and bool(game.settings.settings.get("potato_mode", false))
	return potato or _has_child_named(game.zone_root, "GrassBatch")

func _count_name_prefix(root_node: Node, prefix: String) -> int:
	if root_node == null:
		return 0
	var count = 1 if root_node.name.begins_with(prefix) else 0
	for child in root_node.get_children():
		count += _count_name_prefix(child, prefix)
	return count

func _count_name_contains(root_node: Node, needle: String) -> int:
	if root_node == null:
		return 0
	var visual_name = str(root_node.get_meta("visual_name", ""))
	var count = 1 if root_node.name.contains(needle) or visual_name.contains(needle) else 0
	for child in root_node.get_children():
		count += _count_name_contains(child, needle)
	return count

func _find_child_named(root_node: Node, node_name: String) -> Node:
	if root_node == null:
		return null
	if root_node.name == node_name:
		return root_node
	for child in root_node.get_children():
		var found = _find_child_named(child, node_name)
		if found != null:
			return found
	return null

func _living_enemy_count(game, enemy_id: String) -> int:
	var count = 0
	for enemy in game.active_enemies:
		if enemy != null and not enemy.dead and enemy.enemy_id == enemy_id:
			count += 1
	return count

func _has_placeholder_major_visuals(game) -> bool:
	var names = ["player_human_placeholder", "player_kael_placeholder", "sister_anwen_human_placeholder", "sister_anwen_placeholder", "mira_human_placeholder", "mira_herbalist_placeholder", "rook_human_placeholder", "rook_smuggler_placeholder", "villager_human_placeholder", "ghoulkin_placeholder", "bog_wretch_placeholder"]
	for placeholder_name in names:
		if _find_child_named(game, placeholder_name) != null:
			return true
	return false

func _has_player_placeholder(game) -> bool:
	if game.player == null:
		return true
	return _find_child_named(game.player, "player_human_placeholder") != null or _find_child_named(game.player, "player_kael_placeholder") != null

func _visual_roles_are_imported() -> bool:
	var database = AssetDatabase.new()
	root.add_child(database)
	database.reload()
	var helper = AssetSpawnHelper.new()
	root.add_child(helper)
	helper.setup(database)
	var roles = ["player_human", "sister_anwen_human", "mira_human", "rook_human", "villager_human"]
	for role_name in roles:
		var entry = database.get_visual_asset_for_role(role_name)
		var path = str(entry.get("path", ""))
		if path == "" or not ResourceLoader.exists(path):
			push_error("Visual role %s is not an imported ResourceLoader asset: %s" % [role_name, path])
			return false
		var node = helper.spawn_visual_role(role_name, "characters")
		if node == null or node.name.ends_with("_placeholder"):
			push_error("Visual role %s did not instantiate a real node" % role_name)
			return false
		node.free()
	helper.free()
	database.free()
	return true
