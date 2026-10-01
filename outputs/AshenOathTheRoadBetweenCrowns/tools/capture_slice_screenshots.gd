extends SceneTree

const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const EnemyAI = preload("res://scripts/enemy_ai.gd")

var output_dir = ""
var gallery_dir = ""
var gallery_timestamp = ""
var gallery_phase = "Capture"
var capture_game: Node

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		print("slice screenshot capture skipped: headless/dummy renderer cannot read viewport pixels")
		quit()
		return
	output_dir = ProjectSettings.globalize_path("res://verification_screenshots")
	gallery_dir = ProjectSettings.globalize_path("res://Development_Gallery/screenshots")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--candidate-dir=res://.release-gate/"):
			output_dir = ProjectSettings.globalize_path(argument.trim_prefix("--candidate-dir="))
			gallery_dir = output_dir
	gallery_timestamp = _timestamp_for_file()
	DirAccess.make_dir_recursive_absolute(output_dir)
	DirAccess.make_dir_recursive_absolute(gallery_dir)
	var scene = load("res://scenes/main.tscn")
	if scene == null:
		push_error("main scene failed to load")
		quit(1)
		return
	var game = scene.instantiate()
	capture_game = game
	root.add_child(game)
	await process_frame
	game.call("_on_launch_accepted")
	var prewarm_deadline := Time.get_ticks_msec() + 30000
	while not game.route_zone_cache.has("greyfen") and Time.get_ticks_msec() < prewarm_deadline:
		await process_frame
	if not game.route_zone_cache.has("greyfen"):
		push_error("Greyfen did not prewarm before screenshot startup")
		await _shutdown_capture_game(game)
		quit(1)
		return
	game.call("_new_game")
	await _wait_for_zone_ready(game)
	await _settle_frames(8)
	if "--campaign-wilds-only" in OS.get_cmdline_user_args():
		# Composition fixtures only; never substitute for player-route acceptance.
		for view in [
			["31_deeper_wychwood", "deep_wood", Vector3(0, 1, 6)],
			["33_burned_farmstead", "burned_farmstead", Vector3(0, 1, 6)],
			["34_marsh_crossing", "marsh_crossing", Vector3(0, 1, 8)],
			["35_bandit_road", "bandit_road", Vector3(0, 1, 6)],
		]:
			if not await _capture(game, view[0], view[2], view[1], view[2]):
				await _shutdown_capture_game(game)
				quit(1)
				return
		print("CAMPAIGN WILDS CAPTURE: PASS (staged visual evidence only)")
		await _shutdown_capture_game(game)
		quit(0)
		return
	if "--river-only" in OS.get_cmdline_user_args():
		await _capture(game, "73_river_forced_recovery_proof", Vector3(8, -0.5, 4.5), "greyfen", Vector3(8, -0.5, 4.5), 0.35)
		print("RIVER-ONLY CAPTURE: PASS")
		await _shutdown_capture_game(game)
		quit(0)
		return
	if "--combat-only" in OS.get_cmdline_user_args():
		await _capture_player_motion_state(game, "15_player_sword_ready", "idle")
		await _capture_player_motion_state(game, "13_player_light_attack_arc", "light")
		await _capture_player_motion_state(game, "14_player_heavy_attack_arc", "heavy")
		await _capture_blade_contact(game, "73_combat_001_blade_contact")
		print("COMBAT-001 CAPTURE: PASS")
		await _shutdown_capture_game(game)
		quit(0)
		return
	if "--target-only" in OS.get_cmdline_user_args():
		await _capture_target_lock(game, "74_target_001_soft_lock")
		print("TARGET-001 CAPTURE: PASS")
		await _shutdown_capture_game(game)
		quit(0)
		return
	if "--ai-only" in OS.get_cmdline_user_args():
		await _capture_ai_formation(game, "74_ai_001_engagement_roles", false)
		await _capture_ai_formation(game, "75_ai_001_attack_contact", true)
		print("AI-001 CAPTURE: PASS")
		await _shutdown_capture_game(game)
		quit(0)
		return
	if "--oath-only" in OS.get_cmdline_user_args():
		await _capture_oathfire_stage(game, "76_oath_001_charge_hands", "charge")
		await _capture_oathfire_state(game, "77_oath_001_release_contact", true)
		await _capture_oathfire_wall_impact(game, "78_oath_001_wall_impact")
		print("OATH-001 CAPTURE: PASS")
		await _shutdown_capture_game(game)
		quit(0)
		return
	if "--ui-only" in OS.get_cmdline_user_args():
		await _capture(game, "79_ui_001_hud_hierarchy", Vector3(0, 1, 7), "greyfen", Vector3(0, 1, 7))
		await _capture_anwen_approach(game, "80_ui_001_anwen_approach")
		await _capture_dialogue(game, "81_ui_001_dialogue_lower_third", Vector3(3.2, 1, -2.6))
		print("UI-001 CAPTURE: PASS")
		await _shutdown_capture_game(game)
		quit(0)
		return
	if "--record-only" in OS.get_cmdline_user_args():
		game.quests.active.clear()
		game.quests.unlocked["main_blood_under_stone"] = true
		game.quests.start_quest("main_blood_under_stone")
		if not await _capture(game, "38_record_hall", Vector3(0, 1, 6), "record_hall", Vector3(0, 1, 6)):
			await _shutdown_capture_game(game)
			quit(1)
			return
		if "--record-diagnostic" in OS.get_cmdline_user_args():
			await _capture_record_hall_visibility_diagnostic(game)
		if not _stage_record_hall_haunting(game):
			await _shutdown_capture_game(game)
			quit(1)
			return
		if not await _capture(game, "57_castle_record_hall_haunting", Vector3(0, 1, 7), "record_hall", Vector3(0, 1, 7)):
			await _shutdown_capture_game(game)
			quit(1)
			return
		print("RECORD-HALL CAPTURE: PASS")
		await _shutdown_capture_game(game)
		quit(0)
		return
	if "--campaign-world-only" in OS.get_cmdline_user_args() or "--vargan-world-only" in OS.get_cmdline_user_args() or "--mill-world-only" in OS.get_cmdline_user_args() or "--undercroft-world-only" in OS.get_cmdline_user_args() or "--assembly-world-only" in OS.get_cmdline_user_args() or "--finale-outdoors-only" in OS.get_cmdline_user_args():
		# Staged visual fixtures only; route acceptance belongs to the input driver.
		for view in [
			["32_ash_mill", "old_mill", Vector3(0, 1, 3)],
			["36_vargan_approach", "vargan_approach", Vector3(0, 1, 7)],
			["37_vargan_court", "vargan_court", Vector3(0, 1, 6)],
			["39_undercroft", "undercroft", Vector3(0, 1, 6)],
			["40_greyfen_assembly", "assembly", Vector3(0, 1, 6)],
			["41_white_hart_glade", "hart_glade", Vector3(0, 1, 6)],
		]:
			if "--vargan-world-only" in OS.get_cmdline_user_args() and view[1] not in ["vargan_approach", "vargan_court"]:
				continue
			if "--mill-world-only" in OS.get_cmdline_user_args() and view[1] != "old_mill":
				continue
			if "--undercroft-world-only" in OS.get_cmdline_user_args() and view[1] != "undercroft":
				continue
			if "--assembly-world-only" in OS.get_cmdline_user_args() and view[1] != "assembly":
				continue
			if "--finale-outdoors-only" in OS.get_cmdline_user_args() and view[1] not in ["assembly", "hart_glade"]:
				continue
			if not await _capture(game, view[0], view[2], view[1], view[2]):
				await _shutdown_capture_game(game)
				quit(1)
				return
		print("CAMPAIGN WORLD CAPTURE: PASS (staged visual evidence only)")
		await _shutdown_capture_game(game)
		quit(0)
		return
	if "--required-only" in OS.get_cmdline_user_args():
		if not await _capture(game, "01_greyfen_spawn", Vector3(0, 1, 7), "greyfen", Vector3(0, 1, 7)):
			await _shutdown_capture_game(game)
			quit(1)
			return
		await _capture_dialogue(game, "05_sister_anwen_dialogue", Vector3(3.2, 1, -5.0))
		for view in [
			["70_greyfen_river_bridge", "greyfen", Vector3(0, 1, 7.5)],
			["10_combat_clearing", "wychwood", Vector3(0, 1, -5)],
		]:
			if not await _capture(game, view[0], view[2], view[1], view[2]):
				await _shutdown_capture_game(game)
				quit(1)
				return
		await _capture_player_motion_state(game, "15_player_sword_ready", "idle")
		await _capture_player_motion_state(game, "13_player_light_attack_arc", "light")
		await _capture_player_motion_state(game, "14_player_heavy_attack_arc", "heavy")
		await _capture_blade_contact(game, "73_combat_001_blade_contact")
		game.quests.active.clear()
		game.quests.unlocked["main_blood_under_stone"] = true
		game.quests.start_quest("main_blood_under_stone")
		for view in [
			["36_vargan_approach", "vargan_approach", Vector3(0, 1, 11)],
			["38_record_hall", "record_hall", Vector3(0, 1, 6)],
		]:
			if not await _capture(game, view[0], view[2], view[1], view[2]):
				await _shutdown_capture_game(game)
				quit(1)
				return
		# Stage the finale frame with its own active quest so the compass and
		# tracker describe the same next action instead of inheriting Castle data.
		game.quests.active.clear()
		game.quests.unlocked["main_hart_remembers"] = true
		game.quests.start_quest("main_hart_remembers")
		if not await _capture(game, "41_white_hart_glade", Vector3(0, 1, 6), "hart_glade", Vector3(0, 1, 6)):
			await _shutdown_capture_game(game)
			quit(1)
			return
		print("REQUIRED VISUAL CAPTURE: PASS - eleven mandatory views refreshed")
		await _shutdown_capture_game(game)
		quit(0)
		return
	await _capture(game, "01_greyfen_spawn", Vector3(0, 1, 7), "greyfen", Vector3(0, 1, 7))
	await _capture(game, "02_village_center", Vector3(-2, 1, 8), "greyfen", Vector3(-2, 1, 8))
	await _capture(game, "70_greyfen_river_bridge", Vector3(0, 1, 7.5), "greyfen", Vector3(0, 1, 7.5))
	await _capture(game, "71_greyfen_river_bank", Vector3(-6, 1, 7.2), "greyfen", Vector3(-6, 1, 7.2), 0.55)
	await _capture(game, "73_river_forced_recovery_proof", Vector3(8, -0.5, 4.5), "greyfen", Vector3(8, -0.5, 4.5), 0.35)
	await _capture(game, "03_shrine_sister_anwen", Vector3(3.2, 1, -5.0), "greyfen", Vector3(3.2, 1, -5.0))
	await _capture(game, "04_graveyard_visible_area", Vector3(9.7, 1, 8.0), "greyfen", Vector3(9.7, 1, 8.0), -PI * 0.5)
	await _capture_dialogue(game, "05_sister_anwen_dialogue", Vector3(3.2, 1, -5.0))
	await _capture_post_anwen_objective(game, "06_post_anwen_objective")
	await _capture_gate_guidance(game, "07_wychwood_gate_guidance")
	await _capture(game, "08_forest_gate", Vector3(0, 1, -12), "greyfen", Vector3(0, 1, -12))
	await _capture(game, "09_forest_trail", Vector3(0, 1, 8), "wychwood", Vector3(0, 1, 8))
	await _capture(game, "72_wychwood_river_crossing", Vector3(0, 1, 4.5), "wychwood", Vector3(0, 1, 4.5))
	await _capture(game, "10_combat_clearing", Vector3(0, 1, -5), "wychwood", Vector3(0, 1, -5))
	await _capture(game, "19_shrine_graveyard_omen", Vector3(7.4, 1, -5.6), "greyfen", Vector3(7.4, 1, -5.6))
	await _capture(game, "20_wychwood_gate_threshold", Vector3(0, 1, -13.2), "greyfen", Vector3(0, 1, -13.2))
	await _capture(game, "21_old_road_clue_story", Vector3(-1.4, 1, 5.9), "wychwood", Vector3(-1.4, 1, 5.9))
	await _capture(game, "22_ghoulkin_clearing_story", Vector3(0, 1, -5.2), "wychwood", Vector3(0, 1, -5.2))
	await _capture(game, "31_deeper_wychwood", Vector3(0,1,6), "deep_wood", Vector3(0,1,6))
	await _capture(game, "32_ash_mill", Vector3(0,1,3), "old_mill", Vector3(0,1,3))
	await _capture(game, "33_burned_farmstead", Vector3(0,1,6), "burned_farmstead", Vector3(0,1,6))
	await _capture(game, "34_marsh_crossing", Vector3(0,1,8), "marsh_crossing", Vector3(0,1,8))
	await _capture(game, "35_bandit_road", Vector3(0,1,6), "bandit_road", Vector3(0,1,6))
	await _capture(game, "36_vargan_approach", Vector3(0,1,7), "vargan_approach", Vector3(0,1,7))
	await _capture(game, "37_vargan_court", Vector3(0,1,6), "vargan_court", Vector3(0,1,6))
	await _capture(game, "38_record_hall", Vector3(0,1,6), "record_hall", Vector3(0,1,6))
	await _capture(game, "39_undercroft", Vector3(0,1,6), "undercroft", Vector3(0,1,6))
	await _capture(game, "40_greyfen_assembly", Vector3(0,1,6), "assembly", Vector3(0,1,6))
	await _capture(game, "41_white_hart_glade", Vector3(0,1,6), "hart_glade", Vector3(0,1,6))
	await _capture(game, "42_greyfen_living_street", Vector3(-2,1,8), "greyfen", Vector3(-2,1,8))
	await _capture(game, "43_blacksmith_routine", Vector3(8.0,1,-4.2), "greyfen", Vector3(8.0,1,-4.2), -0.65)
	await _capture(game, "44_shrine_pilgrim", Vector3(2.0,1,-6.0), "greyfen", Vector3(2.0,1,-6.0), 0.55)
	await _capture_place_interaction(game, "45_notice_board_interaction", "notice_board", Vector3(-2,1,7.8))
	await _capture_minigame(game, "46_tic_tac_toe_ui", "tic_tac_toe")
	await _capture_minigame(game, "47_greyfen_draughts_ui", "draughts")
	await _capture(game, "48_minigame_tables_world", Vector3(-4.5,1,8.0), "greyfen", Vector3(-4.5,1,8.0), -0.35)
	await _capture(game, "49_greyfen_life_wide", Vector3(0,1,11), "greyfen", Vector3(0,1,11))
	await _capture_player_motion_state(game, "11_player_idle_pose", "idle")
	await _capture_player_motion_state(game, "12_player_walking_pose", "walk")
	await _capture_player_motion_state(game, "26_player_running_pose", "run")
	await _capture_player_motion_state(game, "27_player_strafe_turn_pose", "strafe")
	await _capture_player_motion_state(game, "28_player_jump_pose", "jump")
	await _capture_player_motion_state(game, "29_player_dodge_pose", "dodge")
	await _capture_player_motion_state(game, "30_player_slope_grounding", "slope")
	await _capture_player_motion_state(game, "15_player_sword_ready", "idle")
	await _capture_player_motion_state(game, "13_player_light_attack_arc", "light")
	await _capture_player_motion_state(game, "14_player_heavy_attack_arc", "heavy")
	await _capture_combat_state(game, "15_ghoulkin_windup_hud", "windup")
	await _capture_combat_state(game, "16_player_block_cue", "block")
	await _capture_combat_state(game, "17_ghoulkin_death_read", "death")
	await _capture_combat_state(game, "63_polish_parry_contact", "block")
	await _capture(game, "67_polish_enemy_approaches", Vector3(0,1,-5.0), "wychwood", Vector3(0,1,-5.0))
	await _capture_victory_state(game, "18_ghoulkin_victory_objective")
	await _capture_victory_state(game, "23_ghoulkin_aftermath_clue")
	await _capture_oathfire_state(game, "24_oathfire_charge", false)
	await _capture_oathfire_state(game, "25_oathfire_beam_release", true)
	await _capture(game, "60_polish_skeletal_villagers", Vector3(-2,1,8), "greyfen", Vector3(-2,1,8), -0.25)
	await _capture_dialogue(game, "61_polish_anwen_facing", Vector3(3.2, 1, -5.0))
	await _capture(game, "79_ui_001_hud_hierarchy", Vector3(0, 1, 7), "greyfen", Vector3(0, 1, 7))
	await _capture_anwen_approach(game, "80_ui_001_anwen_approach")
	await _capture_dialogue(game, "81_ui_001_dialogue_lower_third", Vector3(3.2, 1, -2.6))
	await _capture_player_motion_state(game, "62_polish_kael_character", "idle")
	await _capture_player_motion_state(game, "64_polish_sword_slash_alignment", "light")
	await _capture_blade_contact(game, "73_combat_001_blade_contact")
	await _capture_oathfire_stage(game, "65_polish_oathfire_sheathed", "sheathed")
	await _capture_oathfire_stage(game, "66_polish_oathfire_hand_charge", "charge")
	await _capture_oathfire_stage(game, "76_oath_001_charge_hands", "charge")
	await _capture_oathfire_state(game, "77_oath_001_release_contact", true)
	await _capture_oathfire_wall_impact(game, "78_oath_001_wall_impact")
	game.quests.active.clear()
	game.quests.unlocked["main_blood_under_stone"] = true
	game.quests.start_quest("main_blood_under_stone")
	await _capture(game, "50_castle_distant_approach", Vector3(0,1,12), "vargan_approach", Vector3(0,1,12))
	await _capture(game, "51_castle_outer_gate", Vector3(0,1,-8), "vargan_approach", Vector3(0,1,-8))
	await _capture(game, "52_castle_courtyard_wide", Vector3(0,1,9), "vargan_court", Vector3(0,1,9))
	await _capture_castle_interaction(game, "53_castle_guard_dialogue", "vargan_court", "vargan_gate_guard", Vector3(-2.7,1,9.0))
	await _capture(game, "54_castle_gatehouse_evidence", Vector3(3.8,1,8.5), "vargan_court", Vector3(3.8,1,8.5), -0.25)
	await _capture(game, "55_castle_record_hall", Vector3(0,1,9), "record_hall", Vector3(0,1,9))
	await _capture_castle_interaction(game, "56_castle_ledger_choice", "record_hall", "vargan_ledger_choice", Vector3(0,1,-5.8))
	if not _stage_record_hall_haunting(game):
		await _shutdown_capture_game(game)
		quit(1)
		return
	await _capture(game, "57_castle_record_hall_haunting", Vector3(0,1,7), "record_hall", Vector3(0,1,7))
	print("SCREENSHOT CAPTURE: PASS - route and Record Hall frames validated")
	await _capture(game, "58_castle_view_to_old_road", Vector3(0,1,0), "vargan_approach", Vector3(0,1,0), PI)
	game.settings.set_quality_preset("potato")
	await _capture(game, "59_castle_potato_mode", Vector3(0,1,9), "vargan_court", Vector3(0,1,9))
	print("Screenshots saved to %s and mirrored to %s" % [output_dir, gallery_dir])
	await _shutdown_capture_game(game)
	quit()

func _release_render_resources(game: Node) -> void:
	# Let the scene tree own renderer teardown. Detaching meshes while their
	# instances are still registered produces the null-material errors this
	# capture is meant to detect and can race RenderingServer cleanup.
	if game != null and is_instance_valid(game):
		game.process_mode = Node.PROCESS_MODE_DISABLED

func _shutdown_capture_game(game: Node) -> void:
	_release_render_resources(game)
	if game != null and is_instance_valid(game) and game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	# Retired zone roots own meshes, skeletons, navigation, and audio nodes. Let
	# their staged disposal complete while the game is still tree-owned.
	await _settle_frames(20)
	if game != null and is_instance_valid(game) and game.is_inside_tree():
		root.remove_child(game)
	if game != null and is_instance_valid(game):
		game.free()
	RenderingServer.force_sync()
	await _settle_frames(24)

func _stage_record_hall_haunting(game: Node) -> bool:
	const QUEST := "main_blood_under_stone"
	if not game.quests.is_active(QUEST):
		game.quests.unlocked[QUEST] = true
		if not game.quests.start_quest(QUEST):
			push_error("Record Hall capture could not start its quest")
			return false
	for objective_id in [
		"reach_castle", "speak_guard", "enter_courtyard",
		"evidence_mile_marker", "evidence_supply_cart", "evidence_gate_notice",
		"locate_record_hall", "recover_ledger", "ledger_choice",
	]:
		if not game.quests.is_objective_done(QUEST, objective_id):
			if not game.quests.complete_objective(QUEST, objective_id):
				push_error("Record Hall capture could not stage " + objective_id)
				return false
	game.story_state.set_flag("vargan_ledger_choice_made", true)
	game.quests.set_tracked_quest_for_zone("record_hall")
	if game.quests.get_active_objective_id(QUEST) != "survive_haunting":
		push_error("Record Hall capture objective is not the haunting")
		return false
	return true

func _capture(game, file_name: String, player_pos: Vector3, zone_id: String, spawn_pos: Vector3, camera_yaw: float = 0.0) -> bool:
	game.call("_load_zone", zone_id, spawn_pos)
	await _wait_for_zone_ready(game)
	if str(game.current_zone_id) != zone_id or game.zone_root == null or not is_instance_valid(game.zone_root):
		push_error("capture destination failed: requested=%s active=%s file=%s" % [zone_id, str(game.current_zone_id), file_name])
		return false
	if not await _wait_for_zone_dressing(game, zone_id):
		return false
	# Validate after the destination zone is active. Validating before the load
	# uses the previous zone's river and exclusion rules and makes safe captures
	# look like drift or recovery failures.
	if not file_name.contains("forced_recovery") and game.has_method("validate_walkable_position"):
		player_pos = game.validate_walkable_position(player_pos)
		# Spatial validation preserves requested Y; find the actual supporting floor.
		var floor_query := PhysicsRayQueryParameters3D.create(player_pos + Vector3.UP * 2.0, player_pos + Vector3.DOWN * 4.0, 1, [game.player.get_rid()])
		floor_query.collide_with_areas = false
		var floor_hit: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(floor_query)
		if floor_hit.is_empty() or (floor_hit.normal as Vector3).y < 0.7:
			push_error("World capture has no walkable support: %s position=%s" % [file_name, player_pos])
			return false
		player_pos = (floor_hit.position as Vector3) + Vector3.UP * 0.05
	game.player.global_position = player_pos
	game.player.velocity = Vector3.ZERO
	_stabilize_player_capture_pose(game.player)
	if game.camera_rig != null:
		game.camera_rig.yaw = camera_yaw
		game.camera_rig.pitch = -0.2
	await _settle_frames(12)
	if not file_name.contains("forced_recovery") and not game.player.is_on_floor():
		push_error("World capture is not grounded: %s position=%s" % [file_name, game.player.global_position])
		return false
	_clear_transient_overlays(game)
	await RenderingServer.frame_post_draw
	print("CAPTURE_STATE: %s zone=%s player=%s visible=%s camera=%s" % [file_name, str(game.current_zone_id), str(game.player.global_position), str(game.player.visible), str(game.camera_rig.camera.global_position if game.camera_rig != null and game.camera_rig.camera != null else Vector3.ZERO)])
	if file_name == "73_river_forced_recovery_proof":
		print("RIVER-ONLY POSITION: %s" % str(game.player.global_position))
	_assert_capture_safe(game, player_pos, file_name)
	var image = root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("viewport screenshot capture returned no image")
		return false
	_assert_image_quality(image, file_name)
	_save_image(image, file_name)
	return true

func _wait_for_zone_dressing(game: Node, zone_id: String) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if str(game.current_zone_id) != zone_id or game.zone_root == null or not is_instance_valid(game.zone_root):
			push_error("Capture changed zones while waiting for visual dressing: " + zone_id)
			return false
		var markers: Array[Node] = game.zone_root.find_children("DeferredVisualRole_*", "", true, false)
		var staged_opening: bool = zone_id == "greyfen" and str(game.zone_root.get_meta("opening_build_profile", "")) in ["opening_fast", "opening_boot"]
		var opening_complete: bool = not staged_opening or bool(game.zone_root.get_meta("opening_detail_complete", false))
		if opening_complete and markers.is_empty() and not bool(game.zone_root.get_meta("deferred_visual_roles_pending", false)):
			return true
		await process_frame
	push_error("Zone visual dressing did not finish within 10 seconds: " + zone_id)
	return false

func _capture_record_hall_visibility_diagnostic(game: Node) -> void:
	for profile in [
		["vault_rib", Color(0.24, 0.19, 0.14)],
		["door_arch", Color(0.29, 0.22, 0.15)],
		["side_wall", Color(0.16, 0.135, 0.11)],
	]:
		var owner_name: String = profile[0]
		var batch_name := "AuthoredDetailBatch_%s" % (profile[1] as Color).to_html(true)
		var owners: Array[Node] = game.zone_root.find_children(batch_name, "MultiMeshInstance3D", true, false)
		if owners.is_empty():
			push_error("Record Hall batch missing for diagnostic: " + batch_name)
			quit(1)
			return
		for owner in owners:
			(owner as MultiMeshInstance3D).visible = false
		await _settle_frames(4)
		await RenderingServer.frame_post_draw
		var image := root.get_viewport().get_texture().get_image()
		var path := "D:/Temp/AshenOath/record_hall_without_%s.png" % owner_name.to_snake_case()
		image.save_png(path)
		print("RECORD-HALL VISIBILITY DIAGNOSTIC: %s nodes=%d" % [path, owners.size()])
		for owner in owners:
			(owner as MultiMeshInstance3D).visible = true
		await _settle_frames(2)

func _clear_transient_overlays(game) -> void:
	var hud: Node = game.get("hud") as Node
	if hud == null:
		return
	for field_name in ["toast_label", "status_label", "hint_label"]:
		var overlay: CanvasItem = hud.get(field_name) as CanvasItem
		if overlay != null:
			overlay.visible = false

func _capture_dialogue(game, file_name: String, player_pos: Vector3) -> void:
	game.call("_load_zone", "greyfen", player_pos)
	await _wait_for_zone_ready(game)
	if not await _wait_for_zone_dressing(game, "greyfen"):
		quit(1)
		return
	var sister = _find_child_named(game.zone_root, "sister_anwen")
	if sister == null:
		push_error("dialogue capture could not find Sister Anwen")
		quit(1)
		return
	game.player.global_position = game.validate_walkable_position(sister.global_position + Vector3(0.0, 0.5, 2.2))
	game.player.velocity = Vector3.ZERO
	if not await _settle_capture_on_floor(game.player):
		return
	_stabilize_player_capture_pose(game.player)
	game.player.face_target(sister.global_position)
	await _settle_frames(12)
	game.call("_handle_interaction", sister)
	await _settle_frames(12)
	if not game.hud.dialogue_layer.visible or not game.camera_rig.camera.is_position_in_frustum(sister.global_position + Vector3.UP * 1.4):
		push_error("Anwen dialogue capture must show the actual speaker and open dialogue")
		quit(1)
		return
	var image = root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("dialogue viewport screenshot capture returned no image")
		quit(1)
		return
	_assert_image_quality(image, file_name)
	_save_image(image, file_name)
	if game.hud.call("_close_dialogue_surface"):
		game.hud.dialogue_closed.emit()

func _capture_anwen_approach(game, file_name: String) -> void:
	game.call("_load_zone", "greyfen", Vector3(3.2, 1, -2.6))
	await _wait_for_zone_ready(game)
	game.player.global_position = Vector3(3.2, 1, -2.6)
	game.player.velocity = Vector3.ZERO
	_stabilize_player_capture_pose(game.player)
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = -0.16
	await _settle_frames(24)
	var sister = _find_child_named(game.zone_root, "sister_anwen")
	if sister == null:
		push_error("Anwen approach capture could not find Sister Anwen")
		quit(1)
		return
	var to_player: Vector3 = game.player.global_position - sister.global_position
	to_player.y = 0.0
	# Route-visible humanoids use the gameplay-facing -Z contract. Checking the
	# source +Z basis here inverted the result and rejected a correctly staged
	# Anwen even though the rendered body was facing Kael.
	var visible_forward: Vector3 = -sister.global_basis.z
	visible_forward.y = 0.0
	if visible_forward.normalized().dot(to_player.normalized()) < 0.90:
		push_error("Anwen is not visibly facing Kael in approach capture")
		quit(1)
		return
	_save_viewport(file_name)

func _capture_place_interaction(game, file_name: String, place_id: String, player_pos: Vector3) -> void:
	game.call("_load_zone","greyfen",player_pos)
	await _wait_for_zone_ready(game)
	var place = _find_child_named(game.zone_root,place_id)
	if place == null: push_error("capture missing %s" % place_id); quit(1); return
	game.call("_handle_interaction",place)
	await _settle_frames(10)
	_save_viewport(file_name)
	game.get_tree().paused = false
	game.hud.hide_menus()

func _capture_castle_interaction(game, file_name: String, zone_id: String, interaction_id: String, player_pos: Vector3) -> void:
	game.call("_load_zone", zone_id, player_pos)
	await _wait_for_zone_ready(game)
	var target = _find_child_named(game.zone_root, interaction_id)
	if target == null:
		push_error("castle capture missing %s" % interaction_id)
		quit(1)
		return
	game.call("_handle_interaction", target)
	await _settle_frames(10)
	_save_viewport(file_name)
	game.get_tree().paused = false
	game.hud.hide_menus()

func _capture_minigame(game, file_name: String, game_id: String) -> void:
	game.call("_load_zone","greyfen",Vector3(-4,1,6))
	await _wait_for_zone_ready(game)
	game.minigames.open_game(game_id)
	await _settle_frames(8)
	_save_viewport(file_name)
	game.minigames.close_game()

func _capture_post_anwen_objective(game, file_name: String) -> void:
	game.call("_load_zone", "greyfen", Vector3(3.2, 1, -5.0))
	await _wait_for_zone_ready(game)
	game.player.global_position = Vector3(3.2, 1, -5.0)
	var sister = _find_child_named(game.zone_root, "sister_anwen")
	if sister == null:
		push_error("post-Anwen capture could not find Sister Anwen")
		quit(1)
		return
	game.call("_handle_dialogue_action", {"type": "complete_objective", "quest": "main_road_of_crows", "objective": "speak_anwen"})
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = -0.18
	await _settle_frames(12)
	_save_viewport(file_name)

func _capture_gate_guidance(game, file_name: String) -> void:
	game.call("_load_zone", "greyfen", Vector3(0, 1, -11.8))
	await _wait_for_zone_ready(game)
	game.player.global_position = Vector3(0, 1, -11.8)
	game.hud.set_guidance_hint("Wychwood gate ahead. Stay on the lit road.", 5.0)
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = -0.2
	await _settle_frames(12)
	_save_viewport(file_name)

func _capture_combat_state(game, file_name: String, state: String) -> void:
	game.call("_load_zone", "wychwood", Vector3(0, 1, 8))
	await _wait_for_zone_ready(game)
	game.player.global_position = Vector3(0, 1, -4.0)
	game.player.velocity = Vector3.ZERO
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = -0.18
	if game.active_enemies.is_empty():
		push_error("%s combat capture found no active enemies" % file_name)
		quit(1)
		return
	var enemy = game.active_enemies[0]
	enemy.global_position = Vector3(-1.4, 0.8, -7.0)
	if enemy.has_method("look_at"):
		enemy.look_at(Vector3(game.player.global_position.x, enemy.global_position.y, game.player.global_position.z), Vector3.UP)
	if state == "windup":
		enemy.windup_time = 0.42
		enemy.pending_attack_time = 0.42
		enemy.call("_show_windup_marker")
		game.call("_on_enemy_windup_started", enemy)
	elif state == "block":
		enemy.windup_time = 0.10
		CombatFeedback.block_flash(game.zone_root, game.player.global_position, false)
		CombatFeedback.ground_ring(game.zone_root, game.player.global_position, Color(0.58, 0.36, 0.12), 0.45, 0.18)
		game.hud.show_status_cue("Blocked", "block")
		game.hud.set_guidance_hint("Q at the lunge to parry. Hold Q to block.", 4.0)
	elif state == "death":
		enemy.call("_on_died")
		CombatFeedback.ground_ring(game.zone_root, enemy.global_position, Color(0.12, 0.08, 0.055), 0.9, 0.24)
		game.hud.show_status_cue("Ghoulkin slain", "victory")
	await _settle_frames(12)
	_save_viewport(file_name)

func _capture_ai_formation(game, file_name: String, show_contact: bool) -> void:
	game.call("_load_zone", "wychwood", Vector3(0, 1, -1.0))
	await _wait_for_zone_ready(game)
	game.player.global_position = Vector3(0, 1, -1.0)
	game.player.velocity = Vector3.ZERO
	game.player.set_physics_process(false)
	var formation := [
		Vector3(-2.4, 0.8, -4.0), Vector3(2.3, 0.8, -4.2),
		Vector3(-3.5, 0.8, -2.7), Vector3(3.5, 0.8, -2.8), Vector3(0, 0.8, -5.2)
	]
	for index in range(mini(game.active_enemies.size(), formation.size())):
		var enemy = game.active_enemies[index]
		enemy.set_encounter_active(true)
		enemy.set_physics_process(false)
		enemy.global_position = formation[index]
		enemy.look_at(Vector3(game.player.global_position.x, enemy.global_position.y, game.player.global_position.z), Vector3.UP)
	if show_contact and not game.active_enemies.is_empty():
		var attacker = game.active_enemies[0]
		attacker.global_position = Vector3(-0.55, 0.8, -2.55)
		attacker.windup_time = 0.30
		attacker.pending_attack_time = 0.30
		attacker.call("_show_windup_marker")
		CombatFeedback.impact_burst(game.zone_root, game.player.global_position + Vector3(0, 1.0, -0.25), false, Color(0.82, 0.26, 0.10))
	if game.camera_rig != null:
		game.camera_rig.set_process(false)
		game.camera_rig.camera.look_at_from_position(
			game.player.global_position + Vector3(3.8, 2.55, 4.7),
			game.player.global_position + Vector3(0, 0.95, -2.5),
			Vector3.UP
		)
	await _settle_frames(8)
	_save_viewport(file_name)
	game.player.set_physics_process(true)
	if game.camera_rig != null:
		game.camera_rig.set_process(true)

func _capture_blade_contact(game, file_name: String) -> void:
	game.call("_load_zone", "wychwood", Vector3(0, 1, -4.0))
	await _wait_for_zone_ready(game)
	game.player.global_position = Vector3(0, 1, -4.0)
	game.player.velocity = Vector3.ZERO
	game.player.set_physics_process(true)
	if not await _settle_capture_on_floor(game.player):
		return
	game.player.set_physics_process(false)
	_stabilize_player_capture_pose(game.player)
	_clear_transient_overlays(game)
	game.player.set_physics_process(false)
	game.player.attack_anim_time = 0.34
	game.player.attack_anim_heavy = false
	if game.player.animation_driver != null:
		game.player.animation_driver.trigger_action("attack_light", 1.22, 0.0, false, 0.34)
	game.player.call("_begin_blade_attack", 24.0, 2.0, false)
	for _frame in range(8):
		game.player.attack_anim_time = max(float(game.player.attack_anim_time) - 0.016, 0.0)
		game.player.call("_animate_visuals", 0.016, Vector3.ZERO, false)
		await process_frame
	var segment: Dictionary = game.player.get_blade_world_segment()
	var blade_base: Vector3 = segment.get("base", game.player.global_position + Vector3(0, 1, 0))
	var blade_tip: Vector3 = segment.get("tip", blade_base)
	var enemy = EnemyAI.new()
	game.zone_root.add_child(enemy)
	enemy.global_position = Vector3(0, 1, -5.0)
	enemy.setup("ghoulkin", game.enemy_defs.get("ghoulkin", {}), game.player)
	enemy.setup_navigation(game.spatial_service)
	enemy.set_physics_process(false)
	game.active_enemies.append(enemy)
	var target_point := blade_base.lerp(blade_tip, 0.78)
	enemy.global_position = Vector3(target_point.x, game.player.global_position.y, target_point.z)
	game.player.call("_update_blade_contact")
	if game.camera_rig != null:
		game.camera_rig.set_process(false)
		var camera: Camera3D = game.camera_rig.camera
		camera.look_at_from_position(
			game.player.global_position + Vector3(3.5, 1.75, 0.3),
			game.player.global_position + Vector3(0.0, 1.05, -0.55),
			Vector3.UP
		)
	await _settle_frames(3)
	_save_viewport(file_name)
	game.player.set_physics_process(true)
	if game.camera_rig != null:
		game.camera_rig.set_process(true)

func _capture_player_motion_state(game, file_name: String, state: String) -> void:
	# Keep motion proof on the authored south-bank route; z=5.5 lies inside
	# Greyfen's river exclusion band and produces an overhead bridge shot.
	game.call("_load_zone", "greyfen", Vector3(0, 1, 8.0))
	await _wait_for_zone_ready(game)
	if not await _wait_for_zone_dressing(game, "greyfen"):
		quit(1)
		return
	game.player.global_position = Vector3(0, 1, 8.0)
	game.player.velocity = Vector3.ZERO if state == "idle" else Vector3(0, 0, -4.0)
	game.player.set_physics_process(true)
	if not await _settle_capture_on_floor(game.player):
		return
	game.player.set_physics_process(false)
	_stabilize_player_capture_pose(game.player)
	if state in ["idle", "light", "heavy"]:
		game.player.velocity = Vector3.ZERO
		game.player.movement_state = "idle"
	_clear_transient_overlays(game)
	game.player.move_phase = PI * 0.5 if state == "walk" else 0.0
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = -0.18
	if state == "light":
		game.player.attack_anim_time = 0.34
		game.player.attack_anim_heavy = false
		game.player.animation_driver.trigger_action("attack_light", 1.22, 0.0, false, 0.34)
		game.player.call("_begin_blade_attack", 24.0, 2.0, false)
	elif state == "heavy":
		game.player.attack_anim_time = 0.52
		game.player.attack_anim_heavy = true
		game.player.animation_driver.trigger_action("attack_heavy", 0.76, 0.0, false, 0.52)
		game.player.call("_begin_blade_attack", 42.0, 2.25, true)
	elif state == "run":
		game.player.velocity = Vector3(0, 0, -5.2)
		game.player.movement_state = "run"
		game.player.move_phase = 0.72
	elif state == "strafe":
		game.player.velocity = Vector3(3.2, 0, -0.8)
		game.player.movement_state = "strafe"
		game.player.move_phase = 1.1
	elif state == "jump":
		game.player.velocity = Vector3(0, 5.0, -2.0)
		game.player.movement_state = "jump"
		game.player.jump_pose_weight = 1.0
	elif state == "dodge":
		game.player.velocity = Vector3(5.5, 0, -2.0)
		game.player.movement_state = "dodge"
		game.player.dodge_dir = Vector3(0.85, 0, -0.35).normalized()
		game.player.dodge_time = 0.22
	elif state == "slope":
		game.player.movement_state = "idle"
		game.player.smoothed_ground_normal = Vector3(0.22, 0.95, 0.18).normalized()
		game.player.left_foot_ground_offset = 0.12
		game.player.right_foot_ground_offset = -0.08
	var frame_count = 6 if state == "light" else (16 if state == "heavy" else 16)
	for i in range(frame_count):
		if state in ["walk", "run", "jump", "dodge"]:
			game.player.call("_animate_visuals", 0.016, Vector3(0, 0, -1), true)
		elif state == "strafe":
			game.player.call("_animate_visuals", 0.016, Vector3.RIGHT, true)
		elif state == "slope":
			game.player.smoothed_ground_normal = Vector3(0.22, 0.95, 0.18).normalized()
			game.player.left_foot_ground_offset = 0.12
			game.player.right_foot_ground_offset = -0.08
			game.player.call("_animate_visuals", 0.016, Vector3.ZERO, false)
		elif state == "idle":
			game.player.call("_animate_visuals", 0.016, Vector3.ZERO, false)
		else:
			game.player.attack_anim_time = max(float(game.player.attack_anim_time) - 0.016, 0.0)
			game.player.call("_animate_visuals", 0.016, Vector3.ZERO, false)
		await process_frame
	if state == "idle" and game.player.animation_driver != null:
		# The capture player is intentionally paused after staging. Reassert a
		# grounded locomotion state so the proof frame cannot inherit a jump clip
		# from the initial spawn while the runtime controller is disabled.
		game.player.animation_driver.set_locomotion(0.0, Vector3.ZERO, true)
		await _settle_frames(3)
	if state in ["idle", "light", "heavy"] and game.camera_rig != null:
		game.camera_rig.set_process(false)
		var camera: Camera3D = game.camera_rig.camera
		camera.look_at_from_position(
			game.player.global_position + Vector3(2.65, 1.72, 3.05),
			game.player.global_position + Vector3(0.0, 1.02, -0.38),
			Vector3.UP
		)
		await _settle_frames(2)
	_save_viewport(file_name)
	game.player.set_physics_process(true)
	if game.camera_rig != null:
		game.camera_rig.set_process(true)

func _capture_target_lock(game, file_name: String) -> void:
	game.call("_load_zone", "wychwood", Vector3(0, 1, -1.0))
	await _wait_for_zone_ready(game)
	game.player.global_position = Vector3(0, 0.95, -1.0)
	game.player.velocity = Vector3.ZERO
	for index in range(game.active_enemies.size()):
		var enemy = game.active_enemies[index]
		if enemy == null or not is_instance_valid(enemy):
			continue
		enemy.set_physics_process(false)
		if index == 0:
			enemy.set_encounter_active(true)
			enemy.global_position = Vector3(0.9, 0.8, -4.35)
			enemy.look_at(Vector3(game.player.global_position.x, enemy.global_position.y, game.player.global_position.z), Vector3.UP)
		else:
			enemy.set_encounter_active(false)
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = -0.18
	await _settle_frames(4)
	Input.action_press("target_lock")
	await _settle_frames(2)
	Input.action_release("target_lock")
	await _settle_frames(10)
	var locked = game.camera_rig.get_locked_combat_target() if game.camera_rig != null else null
	if locked == null:
		push_error("%s target lock did not acquire the staged enemy" % file_name)
		quit(1)
		return
	_save_viewport(file_name)

func _reset_combat_capture_pose(captured_player: Node) -> void:
	if captured_player == null:
		return
	captured_player.jump_pose_weight = 0.0
	captured_player.landing_compression = 0.0
	captured_player.dodge_time = 0.0
	captured_player.hurt_react_time = 0.0
	captured_player.hurt_flash_time = 0.0
	captured_player.was_on_floor = true

func _stabilize_player_capture_pose(game_player: Node) -> void:
	if game_player == null:
		return
	_reset_combat_capture_pose(game_player)
	var driver = game_player.get("animation_driver")
	if driver != null and driver.has_method("stop_action"):
		driver.stop_action("idle", 0.0)
	if driver != null and driver.has_method("set_locomotion"):
		driver.set_locomotion(0.0, Vector3.ZERO, true)
	if driver != null and driver.has_method("advance_external"):
		driver.advance_external(0.05)

func _capture_victory_state(game, file_name: String) -> void:
	for objective_id in ["speak_anwen", "inspect_corpse", "find_claw_marks", "find_black_feathers"]:
		game.quests.complete_objective("main_road_of_crows", objective_id)
	game.call("_load_zone", "wychwood", Vector3(0, 1, -4.0))
	await _wait_for_zone_ready(game)
	game.player.global_position = Vector3(0, 1, -4.0)
	for enemy in game.active_enemies:
		if enemy != null and not enemy.dead:
			enemy.call("_on_died")
	game.wychwood_pack_kills = 5
	game.quests.complete_objective("main_road_of_crows", "fight_ghoulkin")
	game.call("_make_post_ghoulkin_story_clue")
	game.hud.show_status_cue("Ghoulkin slain", "victory")
	game.hud.set_guidance_hint("Inspect the tracks, then return to Greyfen.", 6.0)
	game.call("_refresh_tracker")
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.0
		game.camera_rig.pitch = -0.18
	await _settle_frames(12)
	_save_viewport(file_name)

func _capture_oathfire_state(game, file_name: String, released: bool) -> void:
	game.call("_load_zone", "wychwood", Vector3(0, 1, -1.5))
	await _wait_for_zone_ready(game)
	game.player.global_position = Vector3(0, 1, -1.5)
	var direction = game.camera_rig.get_flat_forward() if game.camera_rig != null else Vector3.FORWARD
	game.player.face_target(game.player.global_position + direction * 4.0)
	game.player.beam_charging = true
	game.player.beam_cast_state = "charging"
	game.player.beam_charge_time = 1.1
	game.player.call("_set_sword_sheathed", true)
	if game.player.animation_driver != null:
		game.player.animation_driver.trigger_action("beam_cast")
	game.player.call("_update_beam_charge_visual")
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.72
		game.camera_rig.pitch = -0.16
	if released:
		game.player.call("_hide_beam_charge_visuals")
		game.player.beam_cast_state = "releasing"
		game.player.beam_charging = false
		game.call("_on_player_beam", 0.84, direction)
	await _settle_frames(2 if released else 8)
	_save_viewport(file_name)
	game.player.cancel_beam_charge()

func _capture_oathfire_stage(game, file_name: String, stage: String) -> void:
	game.call("_load_zone", "wychwood", Vector3(0, 1, -1.5))
	await _wait_for_zone_ready(game)
	game.player.global_position = Vector3(0, 1, -1.5)
	var direction = game.camera_rig.get_flat_forward() if game.camera_rig != null else Vector3.FORWARD
	game.player.face_target(game.player.global_position + direction * 4.0)
	game.player.call("_set_sword_sheathed", true)
	game.player.beam_cast_state = "sheathing" if stage == "sheathed" else "charging"
	game.player.beam_charging = true
	if stage == "charge":
		game.player.beam_charge_time = 1.1
		if game.player.animation_driver != null:
			game.player.animation_driver.trigger_action("beam_cast")
		game.player.call("_update_beam_charge_visual")
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.72
		game.camera_rig.pitch = -0.16
	await _settle_frames(8)
	_save_viewport(file_name)
	game.player.cancel_beam_charge()

func _capture_oathfire_wall_impact(game, file_name: String) -> void:
	game.call("_load_zone", "wychwood", Vector3(0, 1, -1.5))
	await _wait_for_zone_ready(game)
	game.player.global_position = Vector3(0, 1, -1.5)
	game.player.rotation.y = 0.0
	game.player.call("_lock_beam_direction")
	game.player.call("_set_sword_sheathed", true)
	game.player.beam_cast_state = "releasing"
	game.player.beam_pending_ratio = 1.0
	var wall := StaticBody3D.new()
	wall.name = "OathfireCaptureWall"
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(3.4, 2.8, 0.45)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	var wall_mesh := MeshInstance3D.new()
	var wall_visual := BoxMesh.new()
	wall_visual.size = wall_box.size
	wall_mesh.mesh = wall_visual
	wall.add_child(wall_mesh)
	game.zone_root.add_child(wall)
	wall.global_position = game.player.global_position + Vector3(0, 1.15, -5.2)
	await physics_frame
	game.call("_on_player_beam", 1.0, game.player.get_beam_locked_direction())
	if game.camera_rig != null:
		game.camera_rig.yaw = 0.72
		game.camera_rig.pitch = -0.12
	await _settle_frames(2)
	_save_viewport(file_name)
	game.player.cancel_beam_charge()

func _save_viewport(file_name: String) -> void:
	_clear_transient_overlays(capture_game)
	var image = root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("%s viewport screenshot capture returned no image" % file_name)
		quit(1)
		return
	_assert_image_quality(image, file_name)
	_save_image(image, file_name)

func _save_image(image: Image, file_name: String) -> void:
	var output_path := "%s/%s.png" % [output_dir, file_name]
	if not _write_png(image, output_path, file_name):
		quit(1)
		return
	var gallery_name = "%s_%s_%s.png" % [gallery_phase, file_name, gallery_timestamp]
	var gallery_path := "%s/%s" % [gallery_dir, gallery_name]
	if not _write_png(image, gallery_path, "%s gallery" % file_name):
		quit(1)

func _write_png(image: Image, path: String, label: String) -> bool:
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("%s screenshot save failed for %s: %s" % [label, path, error])
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0:
		push_error("%s screenshot save produced an empty file: %s" % [label, path])
		return false
	return true

func _timestamp_for_file() -> String:
	var datetime = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d_%02d%02d%02d" % [
		int(datetime.get("year", 0)),
		int(datetime.get("month", 0)),
		int(datetime.get("day", 0)),
		int(datetime.get("hour", 0)),
		int(datetime.get("minute", 0)),
		int(datetime.get("second", 0))
	]

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

func _wait_for_zone_ready(game: Node, max_frames: int = 90) -> void:
	await _settle_frames(3)
	for _frame in range(max_frames):
		var pending := bool(game.get("zone_transition_pending"))
		var request_pending := bool(game.get("zone_load_request_pending"))
		var active_player = game.get("player")
		var locked := active_player != null and bool(active_player.get("transition_locked"))
		if not pending and not request_pending and not locked:
			return
		await process_frame
	push_error("capture zone did not become playable within %d frames" % max_frames)
	quit(1)

func _settle_frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _settle_capture_on_floor(actor: CharacterBody3D) -> bool:
	actor.set_physics_process(true)
	for _frame in range(180):
		await physics_frame
		if actor.is_on_floor() and absf(actor.velocity.y) < 0.2:
			return true
	push_error("Staged visual actor did not reach a supporting floor")
	quit(1)
	return false

func _assert_capture_safe(game, expected_pos: Vector3, file_name: String) -> void:
	var actual: Vector3 = game.player.global_position
	if actual.y < -0.5:
		push_error("%s capture is below the playable surface: %s" % [file_name, str(actual)])
		quit(1)
	var horizontal_drift := Vector2(actual.x, actual.z).distance_to(Vector2(expected_pos.x, expected_pos.z))
	if not file_name.contains("forced_recovery") and (horizontal_drift > 1.25 or actual.y > expected_pos.y + 1.5):
		push_error("%s capture drifted away from its safe point. Expected %s got %s" % [file_name, str(expected_pos), str(actual)])
		quit(1)

func _assert_image_quality(image: Image, file_name: String) -> void:
	var width = image.get_width()
	var height = image.get_height()
	var samples = 0
	var total = 0.0
	var total_sq = 0.0
	var step_y: int = int(max(1, height / 24))
	var step_x: int = int(max(1, width / 32))
	for y in range(0, height, step_y):
		for x in range(0, width, step_x):
			var color = image.get_pixel(x, y)
			var luminance = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			total += luminance
			total_sq += luminance * luminance
			samples += 1
	if samples <= 0:
		push_error("%s capture produced no sampleable pixels" % file_name)
		quit(1)
	var mean = total / samples
	var variance = max(total_sq / samples - mean * mean, 0.0)
	if mean < 0.03 or variance < 0.0006:
		push_error("%s capture appears blank or visually flat. mean=%f variance=%f" % [file_name, mean, variance])
		quit(1)
