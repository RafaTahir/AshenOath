extends SceneTree

const CemeterySection = preload("res://scripts/zones/cemetery_section.gd")
const DEADLINE_MS := 15000

var failures: Array[String] = []
var stabilize_route_bearing := false
var route_camera_yaw := 0.0
var expected_ash_supply_arrows := 20

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Real-input route requires a graphical viewport")
		_finish()
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_move_to_foreground()
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("Main scene unavailable")
		_finish()
		return
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(3)
	var continue_teeth := OS.get_cmdline_user_args().has("--continue-teeth")
	var continue_bog := OS.get_cmdline_user_args().has("--continue-bog")
	var continue_names := OS.get_cmdline_user_args().has("--continue-names")
	var continue_names_greyfen := OS.get_cmdline_user_args().has("--continue-names-greyfen") or OS.get_cmdline_user_args().has("--continue-names-choice")
	var continue_names_farmstead := OS.get_cmdline_user_args().has("--continue-names-farmstead")
	var continue_names_mill := OS.get_cmdline_user_args().has("--continue-names-mill")
	var continue_rootbound := OS.get_cmdline_user_args().has("--continue-rootbound")
	var continue_rootbound_fight := OS.get_cmdline_user_args().has("--continue-rootbound-fight")
	var continue_rootbound_defeated := OS.get_cmdline_user_args().has("--continue-rootbound-defeated")
	var continue_ash_shop := OS.get_cmdline_user_args().has("--continue-ash-shop")
	var continue_ash_mill := OS.get_cmdline_user_args().has("--continue-ash-mill")
	var continue_ash_mill_clue := OS.get_cmdline_user_args().has("--continue-ash-mill-clue")
	var continue_ashwing := OS.get_cmdline_user_args().has("--continue-ashwing")
	var continue_soldier_road := OS.get_cmdline_user_args().has("--continue-soldier-road")
	var continue_senn := OS.get_cmdline_user_args().has("--continue-senn")
	var continue_castle_road := OS.get_cmdline_user_args().has("--continue-castle-road")
	var continue_castle_evidence := OS.get_cmdline_user_args().has("--continue-castle-evidence")
	var continue_record_hall := OS.get_cmdline_user_args().has("--continue-record-hall")
	var continue_record_ledger := OS.get_cmdline_user_args().has("--continue-record-ledger")
	var continue_record_haunting := OS.get_cmdline_user_args().has("--continue-record-haunting")
	var continue_edric := OS.get_cmdline_user_args().has("--continue-edric")
	var continue_undercroft := OS.get_cmdline_user_args().has("--continue-undercroft")
	var continue_halvern := OS.get_cmdline_user_args().has("--continue-halvern")
	var continue_halvern_choice := OS.get_cmdline_user_args().has("--continue-halvern-choice")
	var continue_assembly := OS.get_cmdline_user_args().has("--continue-assembly")
	var continue_assembly_choice := OS.get_cmdline_user_args().has("--continue-assembly-choice")
	var continue_hart_glade := OS.get_cmdline_user_args().has("--continue-hart-glade")
	var continue_hart_witness := OS.get_cmdline_user_args().has("--continue-hart-witness")
	var continue_hart_mercy := OS.get_cmdline_user_args().has("--continue-hart-mercy")
	var continue_hart_duty := OS.get_cmdline_user_args().has("--continue-hart-duty")
	var continue_hart_ash := OS.get_cmdline_user_args().has("--continue-hart-ash")
	var continue_hart_choice := continue_hart_witness or continue_hart_mercy or continue_hart_duty or continue_hart_ash
	var continue_side_widow := OS.get_cmdline_user_args().has("--continue-side-widow")
	var continue_side_iron := OS.get_cmdline_user_args().has("--continue-side-iron")
	var continue_side_empty_grave := OS.get_cmdline_user_args().has("--continue-side-empty-grave")
	var continue_side_bitter := OS.get_cmdline_user_args().has("--continue-side-bitter") or OS.get_cmdline_user_args().has("--continue-side-bitter-kept")
	var continue_side_black_dog := OS.get_cmdline_user_args().has("--continue-side-black-dog") or OS.get_cmdline_user_args().has("--continue-side-black-dog-hidden")
	var continue_side_oren := OS.get_cmdline_user_args().has("--continue-side-oren")
	var continue_side_candles := OS.get_cmdline_user_args().has("--continue-side-candles")
	var continue_side_candles_reload := OS.get_cmdline_user_args().has("--continue-side-candles-reload")
	var continue_side_rook := OS.get_cmdline_user_args().has("--continue-side-rook")
	var continue_side_measure := OS.get_cmdline_user_args().has("--continue-side-measure")
	var continue_side_banner := OS.get_cmdline_user_args().has("--continue-side-banner")
	var continue_side_rook_destroy := OS.get_cmdline_user_args().has("--continue-side-rook-destroy")
	var continue_side_measure_healer := OS.get_cmdline_user_args().has("--continue-side-measure-healer")
	var continue_measure_mill := OS.get_cmdline_user_args().has("--continue-measure-assembly-mill")
	var continue_measure_halvern := OS.get_cmdline_user_args().has("--continue-measure-assembly-halvern")
	var continue_measure_assembly := OS.get_cmdline_user_args().has("--continue-measure-assembly") or continue_measure_mill or continue_measure_halvern
	var continue_side_banner_shield := OS.get_cmdline_user_args().has("--continue-side-banner-shield")
	var continue_side_outcome_reload := OS.get_cmdline_user_args().has("--continue-side-outcome-reload")
	var continue_undercroft_return_circuit := OS.get_cmdline_user_args().has("--continue-undercroft-return-circuit")
	var continue_banner_assembly_castle := OS.get_cmdline_user_args().has("--continue-banner-assembly-castle")
	var continue_banner_assembly_undercroft := OS.get_cmdline_user_args().has("--continue-banner-assembly-undercroft")
	var continue_banner_assembly := OS.get_cmdline_user_args().has("--continue-banner-assembly") or continue_banner_assembly_castle or continue_banner_assembly_undercroft
	var reload_snapshot: Dictionary = {}
	if continue_side_outcome_reload:
		var saved_slot: Dictionary = game.save_manager._read_slot(game.save_manager.SAVE_PATH)
		if not bool(saved_slot.get("ok", false)):
			_fail("Side-outcome reload requires an intact genuine manual save")
			reload_snapshot = {}
		else:
			reload_snapshot = saved_slot.get("data", {}).duplicate(true)
	var continue_side_quest := continue_side_widow or continue_side_iron or continue_side_empty_grave or continue_side_bitter or continue_side_black_dog or continue_side_oren or continue_side_candles or continue_side_candles_reload or continue_side_rook or continue_side_measure or continue_side_banner or continue_side_rook_destroy or continue_side_measure_healer or continue_side_banner_shield or continue_side_outcome_reload or continue_banner_assembly or continue_undercroft_return_circuit or continue_measure_assembly
	var continue_cemetery := OS.get_cmdline_user_args().has("--continue-cemetery") or continue_teeth
	var anwen_only := OS.get_cmdline_user_args().has("--anwen-only")
	var wychwood_only := OS.get_cmdline_user_args().has("--wychwood-only")
	var menu_label := "Continue" if continue_cemetery or continue_bog or continue_names or continue_names_greyfen or continue_names_farmstead or continue_names_mill or continue_rootbound or continue_rootbound_fight or continue_rootbound_defeated or continue_ash_shop or continue_ash_mill or continue_ash_mill_clue or continue_ashwing or continue_soldier_road or continue_senn or continue_castle_road or continue_castle_evidence or continue_record_hall or continue_record_ledger or continue_record_haunting or continue_edric or continue_undercroft or continue_halvern or continue_halvern_choice or continue_assembly or continue_assembly_choice or continue_hart_glade or continue_hart_choice or continue_side_quest else "New Game"
	var menu_button: Button = null
	for node in game.hud.menu_layer.find_children("*", "Button", true, false):
		if (node as Button).text == menu_label:
			menu_button = node as Button
			break
	var focused := root.gui_get_focus_owner() as Button
	for _index in range(8 if continue_cemetery or continue_bog or continue_names or continue_names_greyfen or continue_names_farmstead or continue_names_mill or continue_rootbound or continue_rootbound_fight or continue_rootbound_defeated or continue_ash_shop or continue_ash_mill or continue_ash_mill_clue or continue_ashwing or continue_soldier_road or continue_senn or continue_castle_road or continue_castle_evidence or continue_record_hall or continue_record_ledger or continue_record_haunting or continue_edric or continue_undercroft or continue_halvern or continue_halvern_choice or continue_assembly or continue_assembly_choice or continue_hart_glade or continue_hart_choice or continue_side_quest else 1):
		if focused != null and focused.text == menu_label:
			break
		_key(KEY_TAB, true)
		await _frames(2)
		_key(KEY_TAB, false)
		await _frames(3)
		focused = root.gui_get_focus_owner() as Button
	if menu_button == null or menu_button.disabled or focused == null or focused.text != menu_label or focused.disabled:
		_fail("%s was not keyboard-focusable; focused=%s" % [menu_label, focused.text if focused != null else "none"])
	else:
		_key(KEY_ENTER, true)
		await _frames(3)
		_key(KEY_ENTER, false)
	var deadline := Time.get_ticks_msec() + DEADLINE_MS
	var expected_zone := "hart_glade" if continue_hart_choice else ("assembly" if continue_assembly_choice or continue_hart_glade else ("undercroft" if continue_halvern or continue_halvern_choice or continue_assembly else ("record_hall" if continue_record_ledger or continue_record_haunting or continue_edric or continue_undercroft else ("vargan_court" if continue_record_hall else ("vargan_approach" if continue_castle_evidence else ("bandit_road" if continue_senn or continue_castle_road else ("old_mill" if continue_names_mill or continue_ash_mill_clue or continue_ashwing or continue_soldier_road else ("burned_farmstead" if continue_names_farmstead else ("deep_wood" if continue_bog or continue_names or continue_rootbound or continue_rootbound_fight or continue_rootbound_defeated or continue_ash_mill else "greyfen")))))))))
	if continue_side_banner or continue_side_banner_shield or continue_banner_assembly:
		expected_zone = "bandit_road"
	if continue_side_outcome_reload:
		expected_zone = str(reload_snapshot.get("zone", ""))
	if continue_banner_assembly_castle:
		expected_zone = "vargan_approach"
	if continue_banner_assembly_undercroft:
		expected_zone = "undercroft"
	if continue_undercroft_return_circuit:
		expected_zone = "assembly"
	if continue_measure_mill:
		expected_zone = "old_mill"
	if continue_measure_halvern:
		expected_zone = "undercroft"
	while Time.get_ticks_msec() < deadline and not (game.game_started and game.current_zone_id == expected_zone and not game.zone_transition_pending):
		await process_frame
	if OS.get_cmdline_user_args().has("--audio-sync-combat") and expected_zone == "greyfen":
		# This scope measures actual combat cue timing, not cold startup/travel.
		# Preserve the ordinary route's deadlines and record the readiness wait.
		var audio_ready_start := Time.get_ticks_msec()
		var audio_ready_deadline := audio_ready_start + 60000
		while game.opening_detail_pending and Time.get_ticks_msec() < audio_ready_deadline:
			await process_frame
		print("REAL_INPUT audio_scope_readiness_wait_ms=%d startup_acceptance=false" % (Time.get_ticks_msec() - audio_ready_start))
		if game.opening_detail_pending:
			_fail("Combat audio scope did not reach the complete opening scene")
	if not game.game_started or game.current_zone_id != expected_zone:
		_fail("Focused menu start did not reach controllable %s" % expected_zone)
	elif OS.get_cmdline_user_args().has("--audio-sync-only"):
		await _verify_audio_input_sync(game)
	elif continue_bog:
		await _complete_bog_wretch(game)
	elif continue_names:
		await _continue_names_they_burned(game)
	elif continue_names_greyfen:
		if OS.get_cmdline_user_args().has("--continue-names-choice"):
			await _resolve_names_choice(game)
		else:
			await _collect_greyfen_register_pages(game)
			if failures.is_empty():
				await _continue_register_rook(game)
	elif continue_names_farmstead:
		await _collect_farmstead_register_rook(game)
		if failures.is_empty():
			await _return_register_from_farmstead(game)
	elif continue_names_mill:
		await _return_register_to_deep_wood(game)
	elif continue_rootbound:
		await _verify_rootbound_reload(game)
	elif continue_rootbound_fight:
		await _fight_rootbound_real_input(game)
	elif continue_rootbound_defeated:
		await _return_from_rootbound(game)
	elif continue_ash_shop:
		await _prepare_for_ash_mill(game)
	elif continue_ash_mill:
		await _travel_to_ash_mill(game)
	elif continue_ash_mill_clue:
		await _inspect_ash_millstones(game)
	elif continue_ashwing:
		await _fight_ashwing_real_input(game)
	elif continue_soldier_road:
		if OS.get_cmdline_user_args().has("--wilds-composition-proof"):
			stabilize_route_bearing = true
			await _resume_saved_route(game)
		await _travel_to_bandit_road(game)
		if failures.is_empty() and OS.get_cmdline_user_args().has("--wilds-composition-proof"):
			await _resume_saved_route(game)
			await _fight_senn_guard(game)
	elif continue_senn:
		await _fight_senn_guard(game)
	elif continue_castle_road:
		await _travel_to_castle_approach(game)
	elif continue_castle_evidence:
		await _collect_castle_evidence(game)
	elif continue_record_hall:
		await _enter_record_hall(game)
	elif continue_record_ledger:
		await _resolve_record_ledger(game)
	elif continue_record_haunting:
		await _fight_record_haunting(game)
	elif continue_edric:
		await _confront_edric(game)
	elif continue_undercroft:
		await _enter_undercroft(game)
	elif continue_halvern:
		await _break_halvern_guard(game)
		if failures.is_empty() and OS.get_cmdline_user_args().has("--undercroft-composition-proof"):
			await _resume_saved_route(game)
			if failures.is_empty():
				await _resolve_halvern_witness(game)
			if failures.is_empty():
				await _resume_saved_route(game)
				if failures.is_empty():
					await _verify_undercroft_doorways(game)
				if failures.is_empty():
					await _travel_to_assembly(game)
	elif continue_halvern_choice:
		await _resolve_halvern_witness(game)
	elif continue_assembly:
		await _travel_to_assembly(game)
	elif continue_assembly_choice:
		if OS.get_cmdline_user_args().has("--finale-composition-proof"):
			stabilize_route_bearing = true
			await _hear_assembly_witnesses(game)
		await _choose_assembly_testimony(game)
		if failures.is_empty() and OS.get_cmdline_user_args().has("--finale-composition-proof"):
			await _travel_to_hart_glade(game)
			if failures.is_empty():
				await _resume_saved_route(game)
			if failures.is_empty():
				await _resolve_hart_witness(game)
	elif continue_hart_glade:
		await _travel_to_hart_glade(game)
	elif continue_hart_witness:
		await _resolve_hart_witness(game)
	elif continue_hart_mercy:
		await _resolve_hart_witness(game, 1, "mercy", "free")
	elif continue_hart_duty:
		await _resolve_hart_witness(game, 2, "duty", "bind")
	elif continue_hart_ash:
		await _resolve_hart_witness(game, 3, "ash", "kill")
	elif continue_side_widow:
		await _complete_widows_bell(game)
	elif continue_side_iron:
		await _complete_iron_remembers(game)
	elif continue_side_empty_grave:
		await _complete_empty_grave(game)
	elif continue_side_bitter:
		await _complete_bitter_roots(game)
	elif continue_side_black_dog:
		await _complete_black_dog(game)
	elif continue_side_oren:
		await _complete_oren_red_thread(game)
	elif continue_side_candles:
		await _complete_three_candles(game)
	elif continue_side_candles_reload:
		await _verify_three_candles_reload(game)
	elif continue_side_rook:
		await _complete_rooks_map(game)
	elif continue_side_measure:
		await _complete_millers_measure(game)
	elif continue_side_banner:
		await _complete_bannerless(game)
	elif continue_side_rook_destroy:
		await _resolve_rook_alternative(game)
	elif continue_side_measure_healer:
		await _resolve_measure_healer(game)
	elif continue_measure_assembly:
		stabilize_route_bearing = true
		await _carry_measure_to_assembly(game, "undercroft" if continue_measure_halvern else ("old_mill" if continue_measure_mill else "greyfen"))
	elif continue_side_banner_shield:
		await _resolve_banner_shield(game)
	elif continue_side_outcome_reload:
		await _verify_side_outcome_reload(game, reload_snapshot)
	elif continue_banner_assembly:
		stabilize_route_bearing = true
		await _carry_banner_to_assembly(game, "undercroft" if continue_banner_assembly_undercroft else ("vargan_approach" if continue_banner_assembly_castle else "bandit_road"))
	elif continue_undercroft_return_circuit:
		stabilize_route_bearing = true
		await _verify_undercroft_return_circuit(game)
	elif continue_cemetery:
		print("REAL_INPUT continue_to_greyfen=PASS position=%s" % game.player.global_position)
		if continue_teeth:
			await _continue_teeth_in_rain(game)
		elif game.quests.is_active("main_bell_beneath_greyfen") and game.quests.is_objective_done("main_bell_beneath_greyfen", "cemetery_ambush"):
			print("REAL_INPUT continue_cemetery_checkpoint=PASS beat=open_chapel")
			await _open_crow_chapel(game)
		elif not game.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
			_fail("Continued save is not the post-combat Greyfen return checkpoint")
		else:
			await _report_to_anwen(game)
			if failures.is_empty():
				await _meet_anwen_and_inspect_graves(game)
	else:
		print("REAL_INPUT menu_to_greyfen=PASS position=%s" % game.player.global_position)
		await _move_until(game, KEY_W, "bridge_south_lip", func(p: Vector3) -> bool: return p.z < 6.0, 6000)
		await _move_until(game, KEY_W, "bridge_north_bank", func(p: Vector3) -> bool: return p.z < 1.5, 6000)
		await _move_until(game, KEY_W, "anwen_lane", func(p: Vector3) -> bool: return p.z < -3.4, 6000)
		await _move_until(game, KEY_D, "anwen_offset", func(p: Vector3) -> bool: return p.x > 1.55, 4000)
		var focus_deadline := Time.get_ticks_msec() + 3000
		while Time.get_ticks_msec() < focus_deadline and (game.active_interactable == null or game.active_interactable.interaction_id != "sister_anwen"):
			await process_frame
		if game.active_interactable == null or game.active_interactable.interaction_id != "sister_anwen":
			_fail("Anwen was not focusable after physical route; position=%s focus=%s" % [game.player.global_position, game.active_interactable])
		else:
			_key(KEY_E, true)
			await _frames(3)
			_key(KEY_E, false)
			await _frames(5)
			if not game.hud.dialogue_layer.visible:
				_fail("Real E input did not open Anwen's dialogue")
			else:
				print("REAL_INPUT anwen_dialogue=PASS position=%s" % game.player.global_position)
				if absf(game.player.global_position.y) > 0.08:
					_fail("Kael is suspended above Greyfen during the paused Anwen conversation")
				if anwen_only:
					await RenderingServer.frame_post_draw
					var dialogue_image := root.get_texture().get_image()
					if dialogue_image == null or dialogue_image.get_size() != Vector2i(1280, 720) or dialogue_image.save_png("D:/Temp/AshenOath/world001_anwen_grounded_dialogue.png") != OK:
						_fail("Grounded real-input dialogue capture failed")
				for _page in range(16):
					if not game.hud.dialogue_layer.visible:
						break
					_key(KEY_ENTER, true)
					await _frames(3)
					_key(KEY_ENTER, false)
					await _frames(5)
				if game.hud.dialogue_layer.visible or paused:
					_fail("Anwen conversation did not release gameplay after focused input")
				else:
					print("REAL_INPUT anwen_conversation_closed=PASS")
					if not game.quests.is_objective_done("main_road_of_crows", "speak_anwen"):
						_fail("Anwen conversation did not advance the Road of Crows objective")
					if anwen_only:
						var anwen := game.zone_root.find_child("sister_anwen", true, false) as Node3D
						if anwen == null or game.player.global_position.distance_to(anwen.global_position) > 3.6:
							_fail("Dialogue staging displaced Kael away from Anwen: %s" % game.player.global_position)
						await _shutdown_game(game)
						_finish()
						return
					await _move_until(game, KEY_A, "north_road_center", func(p: Vector3) -> bool: return p.x < 0.45, 4000)
					if failures.is_empty():
						_key(KEY_W, true)
						var travel_deadline := Time.get_ticks_msec() + 12000
						while Time.get_ticks_msec() < travel_deadline and game.current_zone_id != "wychwood":
							await physics_frame
						_key(KEY_W, false)
						await _frames(5)
						if game.current_zone_id != "wychwood" or game.zone_transition_pending or game.player.transition_locked:
							_fail("Physical north-road travel did not reach playable Wychwood; zone=%s position=%s" % [game.current_zone_id, game.player.global_position])
						else:
							print("REAL_INPUT greyfen_to_wychwood=PASS position=%s" % game.player.global_position)
							await _move_until(game, KEY_W, "wychwood_first_layby", func(p: Vector3) -> bool: return p.z < 10.8, 4000)
							await _move_until(game, KEY_A, "bram_ledger_offset", func(p: Vector3) -> bool: return p.x < -0.7, 3000)
							if failures.is_empty():
								var clue_deadline := Time.get_ticks_msec() + 3000
								while Time.get_ticks_msec() < clue_deadline and (game.active_interactable == null or game.active_interactable.interaction_id != "corpse"):
									await process_frame
								if game.active_interactable == null or game.active_interactable.interaction_id != "corpse":
									_fail("Bram's ledger did not receive normal focus at its layby")
								else:
									_key(KEY_E, true)
									await _frames(3)
									_key(KEY_E, false)
									await _frames(7)
									if not game.quests.is_objective_done("main_road_of_crows", "bram"):
										_fail("Real E input did not record Bram's ledger evidence")
									else:
										print("REAL_INPUT bram_ledger=PASS position=%s" % game.player.global_position)
							await _use_south_bank_clue(game, "black_feathers", "sella", KEY_D, 0.75, 9.0)
							await _use_south_bank_clue(game, "claw_marks", "vargan_wire", KEY_A, -0.7, 7.3)
							if failures.is_empty() and not game.quests.is_objective_done("main_road_of_crows", "evidence_ready"):
								_fail("Three player-collected clues did not advance the evidence objective")
							await _move_until(game, KEY_D, "wychwood_bridge_centerline", func(p: Vector3) -> bool: return p.x > -0.25, 3000)
							await _move_until(game, KEY_W, "wychwood_north_bank", func(p: Vector3) -> bool: return p.z < -2.8, 7000)
							if failures.is_empty() and (game.current_zone_id != "wychwood" or game.player.health_component.health <= 0.0):
								_fail("Player did not survive a real-input Wychwood bridge crossing")
							await _fight_wychwood_pack(game)
							if failures.is_empty():
								await _return_wychwood_to_greyfen(game)
								if failures.is_empty():
									await _report_to_anwen(game)
									if failures.is_empty():
										if wychwood_only:
											print("REAL_INPUT wychwood_affected_route=PASS new_game=true clues=3 enemies=5 bridges=both return_report=true")
										else:
											await _meet_anwen_and_inspect_graves(game)
	await _shutdown_game(game)
	_finish()

func _return_wychwood_to_greyfen(game: Node) -> void:
	if not game.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
		_fail("Wychwood return requires the actual completed fight")
		return
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	if game.player.global_position.x > 0.35:
		await _move_until(game, KEY_A, "wychwood_return_centerline", func(p: Vector3) -> bool: return p.x < 0.35, 4000)
	elif game.player.global_position.x < -0.35:
		await _move_until(game, KEY_D, "wychwood_return_centerline", func(p: Vector3) -> bool: return p.x > -0.35, 4000)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_S, "wychwood_to_greyfen_boundary", func(_p: Vector3) -> bool: return game.current_zone_id == "greyfen", 12000)
	if not await _await_playable_zone(game, "greyfen", "wychwood_to_greyfen"):
		return
	# Walking has its own bounded deadline. Loading owns the existing strict
	# transition gate, measured from the runtime request, not this later await.
	var elapsed_ms := float(game.last_loading_metrics.get("to_playable_ms", INF))
	var reused := bool(game.zone_runtime_coordinator.last_activation.get("reused", false))
	var budget_ms := 350.0 if reused else 900.0
	if not is_finite(elapsed_ms) or elapsed_ms > budget_ms:
		_fail("Greyfen return transition exceeded %s budget: %.1f ms > %.1f ms" % ["warm" if reused else "cold", elapsed_ms, budget_ms])

func _shutdown_game(game: Node) -> void:
	for keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_key(keycode, false)
	print("VERIFIER_PHASE: SHUTDOWN")
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	await _frames(game.ZONE_RETIRE_FRAMES + 6)
	if game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
	await _frames(8)
	root.remove_child(game)
	game.free()
	RenderingServer.force_sync()
	await _frames(5)

func _move_until(game: Node, keycode: Key, label: String, arrived: Callable, timeout_ms: int, sprinting := false) -> void:
	if not failures.is_empty():
		return
	_key(keycode, true)
	if sprinting:
		_key(KEY_SHIFT, true)
	var deadline := Time.get_ticks_msec() + timeout_ms
	var reached_in_time := false
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		if Time.get_ticks_msec() >= deadline:
			break
		if arrived.call(game.player.global_position):
			reached_in_time = true
			break
		if stabilize_route_bearing:
			var bearing_error := wrapf(float(game.camera_rig.yaw) - route_camera_yaw, -PI, PI)
			_key(KEY_RIGHT, bearing_error > 0.04)
			_key(KEY_LEFT, bearing_error < -0.04)
	if stabilize_route_bearing:
		_key(KEY_RIGHT, false)
		_key(KEY_LEFT, false)
	_key(keycode, false)
	if sprinting:
		_key(KEY_SHIFT, false)
	var failure_state := "paused=%s can_control=%s transition_locked=%s zone=%s zone_pending=%s input=%s velocity=%s dialogue=%s focus=%s camera_yaw=%.3f" % [
		paused, game.player.can_control, game.player.transition_locked, game.current_zone_id,
		game.zone_transition_pending, game.input_router.movement_vector(), game.player.velocity,
		game.hud.dialogue_layer.visible,
		game.active_interactable.interaction_id if game.active_interactable != null else "none",
		game.camera_rig.yaw,
	]
	var collision_owners: Array[String] = []
	for collision_index in game.player.get_slide_collision_count():
		var contact: KinematicCollision3D = game.player.get_slide_collision(collision_index)
		var collider: Object = contact.get_collider()
		var shape_owner := "none"
		if collider is CollisionObject3D:
			var body := collider as CollisionObject3D
			var owner_id := body.shape_find_owner(contact.get_collider_shape_index())
			var owner_node: Object = body.shape_owner_get_owner(owner_id)
			if owner_node is CollisionShape3D:
				var shape_node := owner_node as CollisionShape3D
				shape_owner = "%s center=%s size=%s" % [shape_node.name, shape_node.global_position, (shape_node.shape as BoxShape3D).size if shape_node.shape is BoxShape3D else "non-box"]
		collision_owners.append("%s shape=%s point=%s normal=%s" % [str(collider.get_path()) if collider is Node else str(collider), shape_owner, contact.get_position(), contact.get_normal()])
	var ray_origin: Vector3 = game.player.global_position + Vector3.UP * 0.85
	var ray_direction: Vector3 = Vector3.RIGHT if keycode == KEY_D else (-Vector3.RIGHT if keycode == KEY_A else (Vector3.BACK if keycode == KEY_S else Vector3.FORWARD))
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 2.0)
	query.exclude = [game.player.get_rid()]
	query.collision_mask = game.player.collision_mask
	var forward_hit: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(query)
	failure_state += " slides=%s forward_hit=%s" % [collision_owners, {"collider": str((forward_hit.get("collider") as Node).get_path()) if forward_hit.get("collider") is Node else "none", "point": forward_hit.get("position", Vector3.INF), "normal": forward_hit.get("normal", Vector3.ZERO)}]
	await _frames(3)
	if not reached_in_time:
		_fail("Movement did not reach %s; position=%s %s" % [label, game.player.global_position, failure_state])
	else:
		print("REAL_INPUT %s=PASS position=%s" % [label, game.player.global_position])

func _turn_camera_north(game: Node) -> void:
	route_camera_yaw = 0.0
	var deadline := Time.get_ticks_msec() + 3500
	while Time.get_ticks_msec() < deadline:
		var error := wrapf(float(game.camera_rig.yaw), -PI, PI)
		if absf(error) <= 0.06:
			break
		_key(KEY_RIGHT, error > 0.0)
		_key(KEY_LEFT, error < 0.0)
		await process_frame
	_key(KEY_LEFT, false)
	_key(KEY_RIGHT, false)
	await _frames(3)
	if absf(wrapf(float(game.camera_rig.yaw), -PI, PI)) > 0.12:
		_fail("Keyboard camera turn did not restore a northward route bearing: %s" % game.camera_rig.yaw)

func _turn_camera_south(game: Node) -> void:
	route_camera_yaw = PI
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline:
		var error := wrapf(float(game.camera_rig.yaw) - PI, -PI, PI)
		if absf(error) <= 0.06:
			break
		_key(KEY_RIGHT, error > 0.0)
		_key(KEY_LEFT, error < 0.0)
		await process_frame
	_key(KEY_LEFT, false)
	_key(KEY_RIGHT, false)
	await _frames(3)
	if absf(absf(wrapf(float(game.camera_rig.yaw), -PI, PI)) - PI) > 0.12:
		_fail("Keyboard camera turn did not restore a southward route bearing: %s" % game.camera_rig.yaw)

func _use_south_bank_clue(game: Node, clue_id: String, objective_id: String, side_key: Key, target_x: float, approach_z: float) -> void:
	if not failures.is_empty():
		return
	if side_key == KEY_D:
		await _move_until(game, side_key, clue_id + "_offset", func(p: Vector3) -> bool: return p.x > target_x, 4000)
	else:
		await _move_until(game, side_key, clue_id + "_offset", func(p: Vector3) -> bool: return p.x < target_x, 4000)
	await _move_until(game, KEY_W, clue_id + "_layby", func(p: Vector3) -> bool: return p.z < approach_z, 4000)
	if not failures.is_empty():
		return
	var focus_deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < focus_deadline and (game.active_interactable == null or game.active_interactable.interaction_id != clue_id):
		await process_frame
	if game.active_interactable == null or game.active_interactable.interaction_id != clue_id:
		_fail("%s did not receive normal focus at its layby; position=%s focus=%s" % [clue_id, game.player.global_position, game.active_interactable])
		return
	_key(KEY_E, true)
	await _frames(3)
	_key(KEY_E, false)
	await _frames(7)
	if not game.quests.is_objective_done("main_road_of_crows", objective_id):
		_fail("Real E input did not record %s evidence" % objective_id)
	else:
		print("REAL_INPUT %s=PASS position=%s" % [objective_id, game.player.global_position])

func _advance_toward_combat_target(game: Node, enemy: Node3D) -> void:
	var offset: Vector3 = enemy.global_position - game.player.global_position
	offset.y = 0.0
	var direction := offset.normalized()
	var forward: float = game.camera_rig.get_flat_forward().dot(direction)
	var right: float = game.camera_rig.get_flat_right().dot(direction)
	_key(KEY_W, forward > 0.35)
	_key(KEY_S, forward < -0.35)
	_key(KEY_D, right > 0.35)
	_key(KEY_A, right < -0.35)
	await _frames(6)

func _fight_wychwood_pack(game: Node) -> void:
	if not failures.is_empty():
		return
	var audio_sync: Dictionary = {}
	if OS.get_cmdline_user_args().has("--audio-sync-combat"):
		audio_sync = _observe_enemy_audio_sync(game, game.active_enemies)
	await _move_until(game, KEY_W, "wychwood_clearing", func(p: Vector3) -> bool: return p.z < -4.5, 5000)
	if not failures.is_empty():
		return
	var deadline := Time.get_ticks_msec() + 150000
	var last_attack := 0
	var last_potion := 0
	var last_progress := -1
	var last_damage_progress := Time.get_ticks_msec()
	var observed_enemy_health := INF
	var captured_ghoulkin_states: Dictionary = {}
	while Time.get_ticks_msec() < deadline:
		if OS.get_cmdline_user_args().has("--ghoulkin-motion-proof"):
			for actor in game.active_enemies:
				if not is_instance_valid(actor) or actor.enemy_id != "ghoulkin" or actor.animation_driver == null:
					continue
				var state: String = actor.animation_driver.current_state
				if state not in ["walk", "run", "attack", "hit", "death"] or captured_ghoulkin_states.has(state):
					continue
				await RenderingServer.frame_post_draw
				var path := "D:/Temp/AshenOath/ghoulkin_authored_20260930/real_input_%s.png" % state
				if root.get_texture().get_image().save_png(path) != OK:
					_fail("Actual Ghoulkin %s frame could not be captured" % state)
				captured_ghoulkin_states[state] = true
				print("REAL_INPUT ghoulkin_motion=%s actor=%s grounded=%s frame=%s" % [state, actor.global_position, actor.is_on_floor(), path])
		if game.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
			for keycode in [KEY_W, KEY_S, KEY_D, KEY_A]:
				_key(keycode, false)
			print("REAL_INPUT five_enemy_fight=PASS kills=%d health=%.1f" % [game.wychwood_pack_kills, game.player.health_component.health])
			if not audio_sync.is_empty():
				if audio_sync.death != 5 or audio_sync.hit == 0 or audio_sync.windup == 0 or audio_sync.attack == 0:
					_fail("Five-enemy audio input coverage is incomplete: " + JSON.stringify(audio_sync))
				print("REAL_INPUT combat_audio_sync=%s %s" % ["PASS" if failures.is_empty() else "FAIL", JSON.stringify(audio_sync)])
			return
		if game.player.health_component.health <= 0.0:
			_fail("Kael died in the real-input five-enemy fight after %d kills" % game.wychwood_pack_kills)
			return
		if game.wychwood_pack_kills != last_progress:
			last_progress = game.wychwood_pack_kills
			observed_enemy_health = INF
			last_damage_progress = Time.get_ticks_msec()
			print("REAL_INPUT combat_progress kills=%d health=%.1f position=%s" % [last_progress, game.player.health_component.health, game.player.global_position])
		var enemy: Node3D = game.camera_rig.get_locked_combat_target()
		if enemy == null:
			_key(KEY_T, true)
			await _frames(2)
			_key(KEY_T, false)
			await _frames(10)
			enemy = game.camera_rig.get_locked_combat_target()
		if enemy == null:
			for keycode in [KEY_W, KEY_S, KEY_D, KEY_A]:
				_key(keycode, false)
			await _frames(5)
			if Time.get_ticks_msec() - last_damage_progress > 25000:
				_fail("No visible active target acquired during the five-enemy fight")
				return
			continue
		if not game.active_enemies.has(enemy) or enemy.dead or not enemy.is_encounter_active():
			_fail("Real lock-on selected an invalid encounter actor")
			return
		var total_health := 0.0
		for candidate in game.active_enemies:
			if is_instance_valid(candidate) and not candidate.dead:
				total_health += float(candidate.health_component.health)
		if total_health < observed_enemy_health:
			observed_enemy_health = total_health
			last_damage_progress = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_damage_progress > 25000:
			var stuck_offset: Vector3 = enemy.global_position - game.player.global_position
			stuck_offset.y = 0.0
			var stuck_lock: Node3D = game.camera_rig.get_locked_combat_target()
			_fail("Combat stalled after %d kills: player=%s enemy=%s enemy_health=%.1f distance=%.2f camera_yaw=%.2f locked=%s velocity=%s" % [game.wychwood_pack_kills, game.player.global_position, enemy.global_position, enemy.health_component.health, stuck_offset.length(), game.camera_rig.yaw, stuck_lock.name if stuck_lock != null else "none", game.player.velocity])
			return
		var separation: Vector3 = enemy.global_position - game.player.global_position
		separation.y = 0.0
		# The animation's measured blade sweep, not its broad candidate radius,
		# determines striking distance. Keep approaching until contact is reachable.
		if separation.length() > 1.1:
			await _advance_toward_combat_target(game, enemy)
		else:
			for keycode in [KEY_W, KEY_S, KEY_D, KEY_A]:
				_key(keycode, false)
			var now := Time.get_ticks_msec()
			if now - last_attack >= 430:
				# Neutral movement lets the normal attack edge face the live lock,
				# rather than overriding it with the camera's lagging forward yaw.
				await _frames(2)
				_mouse_button(MOUSE_BUTTON_LEFT, true)
				await _frames(2)
				_mouse_button(MOUSE_BUTTON_LEFT, false)
				last_attack = now
			if game.player.health_component.health < 65.0 and now - last_potion > 6000:
				_key(KEY_R, true)
				await _frames(2)
				_key(KEY_R, false)
				last_potion = now
		await _frames(3)
	_fail("Real-input Wychwood combat timed out; kills=%d health=%.1f position=%s" % [game.wychwood_pack_kills, game.player.health_component.health, game.player.global_position])

func _release_combat_movement() -> void:
	for keycode in [KEY_W, KEY_S, KEY_D, KEY_A]:
		_key(keycode, false)

func _melee_approach_radius(game: Node, enemy: Node3D) -> float:
	var radii := 0.0
	for actor in [game.player, enemy]:
		for child in actor.get_children():
			if child is CollisionShape3D and child.shape is CapsuleShape3D:
				radii += child.shape.radius
				break
	# Respect measured sword reach without interpenetrating large capsules.
	return maxf(1.1, radii + 0.06)

func _drive_contact_strike(game: Node, enemy: Node3D, last_attack: int, interval_ms: int) -> int:
	var offset: Vector3 = enemy.global_position - game.player.global_position
	offset.y = 0.0
	if offset.length() > _melee_approach_radius(game, enemy):
		await _advance_toward_combat_target(game, enemy)
		return last_attack
	_release_combat_movement()
	if Time.get_ticks_msec() - last_attack > interval_ms:
		await _frames(2)
		_mouse_button(MOUSE_BUTTON_LEFT, true)
		await _frames(2)
		_mouse_button(MOUSE_BUTTON_LEFT, false)
		return Time.get_ticks_msec()
	return last_attack

func _report_to_anwen(game: Node) -> void:
	if not game.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
		_fail("Returned before completing the five-enemy objective")
		return
	await _move_until(game, KEY_S, "anwen_report_north_approach", func(p: Vector3) -> bool: return p.z > -3.4, 7000)
	await _move_until(game, KEY_D, "anwen_report_offset", func(p: Vector3) -> bool: return p.x > 1.55, 4000)
	if not failures.is_empty():
		return
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline and (game.active_interactable == null or game.active_interactable.interaction_id != "sister_anwen"):
		await process_frame
	if game.active_interactable == null or game.active_interactable.interaction_id != "sister_anwen":
		_fail("Anwen report did not receive real focus; position=%s" % game.player.global_position)
		return
	_key(KEY_E, true)
	await _frames(3)
	_key(KEY_E, false)
	await _frames(5)
	if not game.hud.dialogue_layer.visible:
		_fail("Real E input did not open Anwen's return report")
		return
	for _page in range(24):
		if not game.hud.dialogue_layer.visible:
			break
		_key(KEY_ENTER, true)
		await _frames(3)
		_key(KEY_ENTER, false)
		await _frames(5)
	if not game.quests.is_completed("main_road_of_crows") or not game.quests.is_active("main_bell_beneath_greyfen"):
		_fail("Real Anwen report did not complete Road of Crows and start Bell Beneath Greyfen")
	else:
		var relocated_anwen := game.zone_root.find_child("sister_anwen", true, false) as Node3D
		print("REAL_INPUT anwen_report=PASS road_complete=true bell_active=true anwen_position=%s pending_relocation=%s dialogue_visible=%s" % [relocated_anwen.global_position if relocated_anwen != null else Vector3.INF, game.pending_anwen_relocation, game.hud.dialogue_layer.visible])

func _verify_audio_input_sync(game: Node) -> void:
	var ready_deadline := Time.get_ticks_msec() + 60000
	while game.opening_detail_pending and Time.get_ticks_msec() < ready_deadline:
		await process_frame
	if game.opening_detail_pending:
		_fail("Audio input check could not reach the complete opening scene")
		return
	await game.audio.wait_until_ready()
	var state := {"stage": "idle", "steps": {}, "light": 0, "heavy": 0, "phases": [], "releases": 0}
	var step_observer := func() -> void:
		var stage: String = state.stage
		state.steps[stage] = int(state.steps.get(stage, 0)) + 1
		if stage in ["idle", "paused"]:
			_fail("Footstep emitted while " + stage)
		if Vector2(game.player.velocity.x, game.player.velocity.z).length() < 0.25:
			_fail("Footstep emitted without physical movement")
		var recorded_step := false
		for event_name in ["step_road", "step_forest", "step_mud", "step_stone", "step_wood"]:
			if _latest_audio_event_matches(game.audio, event_name):
				recorded_step = true
				break
		if not recorded_step:
			_fail("Physical footfall did not start a recorded footstep in its signal frame")
	var blade_observer := func(contact: Dictionary) -> void:
		if not bool(contact.get("first_sample", false)):
			return
		var event_name := "heavy" if bool(contact.get("heavy", false)) else "swing"
		state[event_name if event_name == "heavy" else "light"] += 1
		if not _latest_audio_event_matches(game.audio, event_name):
			_fail("Blade contact did not start its " + event_name + " cue in the signal frame")
	var phase_observer := func(phase: String) -> void:
		var event_name: String = {"sheathing": "oathfire_sheathe", "charging": "oathfire_charge", "releasing": "oathfire_release"}.get(phase, "")
		if event_name.is_empty():
			return
		state.phases.append(phase)
		if not _latest_audio_event_matches(game.audio, event_name):
			_fail("Oathfire phase did not start its recorded cue: " + phase)
	var release_observer := func(_ratio: float, _direction: Vector3) -> void:
		state.releases += 1
		if not _latest_audio_event_matches(game.audio, "oathfire_release"):
			_fail("Oathfire release was overwritten by an unrelated cue")
	game.player.footstep.connect(step_observer)
	game.player.blade_contact_requested.connect(blade_observer)
	game.player.beam_phase_changed.connect(phase_observer)
	game.player.beam_requested.connect(release_observer)
	for movement in [["forward", KEY_W, false], ["backward", KEY_S, false], ["sprint", KEY_W, true]]:
		state.stage = str(movement[0])
		var start: Vector3 = game.player.global_position
		_key(KEY_SHIFT, bool(movement[2]))
		_key(movement[1], true)
		await _audio_input_wait(900)
		_key(movement[1], false)
		_key(KEY_SHIFT, false)
		await _audio_input_wait(180)
		if game.player.global_position.distance_to(start) < 0.15 or int(state.steps.get(state.stage, 0)) == 0:
			_fail("Real " + str(state.stage) + " movement did not produce physical footfalls")
	state.stage = "idle"
	await _audio_input_wait(700)
	_key(KEY_ESCAPE, true)
	await _frames(2)
	_key(KEY_ESCAPE, false)
	if not paused or not game.audio.game_paused:
		_fail("Pause input did not pause gameplay and audio")
	state.stage = "paused"
	await _frames(20)
	_key(KEY_ESCAPE, true)
	await _frames(2)
	_key(KEY_ESCAPE, false)
	await _frames(3)
	if paused or game.audio.game_paused:
		_fail("Resume input did not restore gameplay and audio")
	for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		_mouse_button(button, true)
		await _frames(3)
		_mouse_button(button, false)
		await _audio_input_wait(1400)
	_key(KEY_C, true)
	var charge_deadline := Time.get_ticks_msec() + 5000
	while game.player.beam_charge_time < 0.45 and Time.get_ticks_msec() < charge_deadline:
		await process_frame
	_key(KEY_C, false)
	await _audio_input_wait(1000)
	if state.light != 1 or state.heavy != 1 or state.releases != 1 \
			or state.phases != ["sheathing", "charging", "releasing"]:
		_fail("Real attack/Oathfire input did not complete the expected cue timeline: " + JSON.stringify(state))
	game.player.footstep.disconnect(step_observer)
	game.player.blade_contact_requested.disconnect(blade_observer)
	game.player.beam_phase_changed.disconnect(phase_observer)
	game.player.beam_requested.disconnect(release_observer)
	print("REAL_INPUT audio_sync=%s %s" % ["PASS" if failures.is_empty() else "FAIL", JSON.stringify(state)])

func _latest_audio_event_matches(audio: Node, event_name: String) -> bool:
	if audio.active_cue_order.is_empty():
		return false
	var cue: Node = audio.active_cue_order.back()
	return cue.playing and cue.stream is AudioStreamOggVorbis \
		and cue.stream in audio.recorded_variants.get(event_name, [])

func _audio_input_wait(duration_ms: int) -> void:
	var deadline := Time.get_ticks_msec() + duration_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame

func _observe_enemy_audio_sync(game: Node, enemies: Array) -> Dictionary:
	var state := {"windup": 0, "hit": 0, "attack": 0, "parry": 0, "death": 0}
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		enemy.windup_started.connect(func(actor: Node) -> void:
			_check_enemy_audio_sync(game, actor, "windup", state))
		enemy.damaged.connect(func(actor: Node, _health: float, _maximum: float) -> void:
			_check_enemy_audio_sync(game, actor, "hit", state))
		enemy.died.connect(func(actor: Node) -> void:
			_check_enemy_audio_sync(game, actor, "death", state))
		enemy.attack_resolved.connect(func(actor: Node, parried: bool, _contact: Vector3) -> void:
			_check_enemy_audio_sync(game, actor, "parry" if parried else "attack", state))
	return state

func _check_enemy_audio_sync(game: Node, enemy: Node, phase: String, state: Dictionary) -> void:
	state[phase] += 1
	var event_name: String = "parry" if phase == "parry" else game.audio.enemy_event_name(enemy.enemy_id, phase)
	var variants: Array = game.audio.recorded_variants.get(event_name, [])
	var max_age := 0.30 if phase == "windup" else (0.12 if phase == "parry" else 0.08)
	for cue in game.audio.active_cue_order:
		if is_instance_valid(cue) and cue.playing and cue.stream is AudioStreamOggVorbis \
				and cue.stream in variants and cue.get_playback_position() <= max_age:
			return
	_fail("Actual enemy %s event did not start/coalesce its recorded %s cue in the signal frame" % [phase, event_name])

func _mouse_button(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func _meet_anwen_and_inspect_graves(game: Node) -> void:
	await _move_until(game, KEY_A, "cemetery_bridge_centerline", func(p: Vector3) -> bool: return p.x < 0.45, 4000)
	await _move_until(game, KEY_S, "cemetery_south_bank", func(p: Vector3) -> bool: return p.z > 9.2, 7000)
	await _move_until(game, KEY_D, "cemetery_gate_lane", func(p: Vector3) -> bool: return p.x > 9.0, 7000)
	await _move_until(game, KEY_W, "cemetery_anwen_approach", func(p: Vector3) -> bool: return p.z < 8.8, 4000)
	if not failures.is_empty():
		return
	await _use_focused_interaction(game, "sister_anwen", "cemetery_anwen")
	if not failures.is_empty():
		return
	if not game.quests.is_objective_done("main_bell_beneath_greyfen", "meet_anwen_gate"):
		_fail("Real cemetery Anwen conversation did not complete meet_anwen_gate")
		return
	await _move_until(game, KEY_W, "harl_pier_clearance", func(p: Vector3) -> bool: return p.z < 8.5, 4000)
	await _move_until(game, KEY_D, "harl_grave_lane", func(p: Vector3) -> bool: return p.x > 11.0, 4000)
	await _use_focused_interaction(game, "grave_harl", "harl_grave")
	if not failures.is_empty():
		return
	await _move_until(game, KEY_S, "soldier_grave_south", func(p: Vector3) -> bool: return p.z > 8.8, 4000)
	await _move_until(game, KEY_D, "soldier_grave_lane", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "grave_soldier", 5000)
	await _use_focused_interaction(game, "grave_soldier", "soldier_grave")
	if failures.is_empty() and game.quests.is_objective_done("main_bell_beneath_greyfen", "grave_truth"):
		print("REAL_INPUT cemetery_grave_truth=PASS position=%s" % game.player.global_position)
		await _fight_cemetery_ambush(game)
		if failures.is_empty():
			await _open_crow_chapel(game)
	elif failures.is_empty():
		_fail("Two player-inspected graves did not complete grave_truth")

func _open_crow_chapel(game: Node) -> void:
	if not game.quests.is_objective_done("main_bell_beneath_greyfen", "open_chapel"):
		await _move_until(game, KEY_D, "chapel_door_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "chapel_door", 5000)
		await _use_focused_interaction(game, "chapel_door", "chapel_door")
		if not failures.is_empty():
			return
	else:
		print("REAL_INPUT chapel_saved_open=PASS position=%s" % game.player.global_position)
	if not game.quests.is_objective_done("main_bell_beneath_greyfen", "open_chapel"):
		_fail("Real chapel interaction did not complete open_chapel")
		return
	var shrine := game.zone_root.find_child("crow_shrine_choice", true, false) as Node3D
	var bell_eater: Node3D = null
	for candidate in game.active_enemies:
		if is_instance_valid(candidate) and candidate.enemy_id == "bell_eater" and not candidate.dead:
			bell_eater = candidate
			break
	if shrine == null or bell_eater == null:
		_fail("Opening the chapel did not stage both the Crow Shrine and Bell-Eater")
		return
	if shrine.global_position.distance_to(CemeterySection.CROW_SHRINE_INTERACTION_STAGE) > 0.25 or shrine.global_position.distance_to(CemeterySection.CROW_SHRINE_VISUAL_STAGE) > 1.5:
		_fail("Crow Shrine interaction was recovered away from its visible chapel stone: %s" % shrine.global_position)
		return
	print("REAL_INPUT chapel_open=PASS player=%s shrine=%s boss=%s" % [game.player.global_position, shrine.global_position, bell_eater.global_position])
	if OS.get_cmdline_user_args().has("--continue-cemetery"):
		var build_profile := str(game.zone_root.get_meta("opening_build_profile", "full"))
		if build_profile in ["opening_fast", "opening_boot"]:
			var stage_deadline := Time.get_ticks_msec() + 10000
			while Time.get_ticks_msec() < stage_deadline and game.opening_detail_stage_index == 0:
				await process_frame
			if game.opening_detail_stage_index == 0:
				_fail("Continued prewarmed Greyfen never hydrated its first gameplay stage")
				return
		var shrine_count := 0
		for candidate in game.zone_root.find_children("crow_shrine_choice", "", true, false):
			if is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
				shrine_count += 1
		var boss_count := 0
		for candidate in game.active_enemies:
			if is_instance_valid(candidate) and candidate.enemy_id == "bell_eater" and not candidate.dead:
				boss_count += 1
		var anwen := game.zone_root.find_child("sister_anwen", true, false) as Node3D
		var widow := game.zone_root.find_child("widow_elna", true, false) as Node3D
		print("REAL_INPUT chapel_reload_hydration profile=%s shrine_count=%d boss_count=%d anwen=%s widow=%s" % [
			build_profile, shrine_count, boss_count,
			anwen.global_position if anwen != null else "missing",
			widow.global_position if widow != null else "missing",
		])
		if shrine_count != 1 or boss_count != 1 or anwen == null:
			_fail("Continued chapel hydration duplicated or omitted a required encounter actor")
	if failures.is_empty():
		# Reach the facade opening before moving east past the solid south pier.
		await _align_chapel_entrance(game)
		await _move_until(game, KEY_D, "crow_shrine_west_approach", func(p: Vector3) -> bool: return p.x > 15.3, 5000)
		var outcome := "disturbed" if OS.get_cmdline_user_args().has("--shrine-disturbed") else ("bound" if OS.get_cmdline_user_args().has("--shrine-bound") else "cleansed")
		var choice := str({"cleansed": "Cleanse the shrine", "disturbed": "Disturb it for memory", "bound": "Bind it and leave"}[outcome])
		await _choose_focused_dialogue_action(game, "crow_shrine_choice", choice, "crow_shrine_choice")
		if failures.is_empty() and (not game.quests.is_objective_done("main_bell_beneath_greyfen", "crow_shrine_choice") or str(game.story_state.get_flag("crow_shrine_state", "")) != outcome):
			_fail("Real shrine choice did not complete Bell Beneath Greyfen")
		elif failures.is_empty():
			print("REAL_INPUT crow_shrine_choice=PASS state=%s" % game.story_state.get_flag("crow_shrine_state", ""))

func _align_chapel_entrance(game: Node) -> void:
	if not failures.is_empty():
		return
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	await _align_route_axis(game, 2, 8.29, KEY_W, KEY_S, "crow_shrine_entrance")

func _alignment_drive(error: float, velocity: float, braking: float, step: float) -> int:
	if absf(error) <= 0.08:
		return 0
	# Brake before arrival; reversing at full speed produces a limit cycle.
	if absf(velocity) > 0.2:
		if error * velocity < 0.0:
			return 0
		var stopping := velocity * velocity / (2.0 * maxf(braking, 0.01)) + absf(velocity) * step
		if absf(error) <= stopping + 0.08:
			return 0
	return 1 if error > 0.0 else -1

func _align_route_axis(game: Node, axis: int, target: float, negative_key: Key, positive_key: Key, label: String) -> void:
	if not failures.is_empty():
		return
	var deadline := Time.get_ticks_msec() + 4000
	var settled_ticks := 0
	while Time.get_ticks_msec() < deadline:
		var error: float = target - game.player.global_position[axis]
		var drive := _alignment_drive(error, game.player.velocity[axis], game.player.deceleration, game.player.get_physics_process_delta_time())
		_key(negative_key, drive < 0)
		_key(positive_key, drive > 0)
		await physics_frame
		if Time.get_ticks_msec() >= deadline:
			break
		if absf(game.player.global_position[axis] - target) <= 0.08 and absf(game.player.velocity[axis]) < 0.2:
			settled_ticks += 1
		else:
			settled_ticks = 0
		if settled_ticks >= 3:
			break
	_key(negative_key, false)
	_key(positive_key, false)
	if settled_ticks < 3:
		_fail("Physical %s alignment timed out; position=%s" % [label, game.player.global_position])
	else:
		print("REAL_INPUT %s=PASS position=%s" % [label, game.player.global_position])

func _leave_chapel_for_south_road(game: Node) -> void:
	await _align_chapel_entrance(game)
	if not failures.is_empty():
		return
	# Combat may end on either side of the gate cap. The x13.2 aisle clears
	# the gate at x10.6, headstones at x12.2/14 and bell posts at x15.15/16.35.
	await _align_route_axis(game, 0, 13.2, KEY_A, KEY_D, "chapel_west_doorway_exit")
	if not failures.is_empty():
		return
	# Cross the authored west gate before turning south. The inner south
	# lane contains graves/rubble; its wall is not a cemetery exit.
	await _move_until(game, KEY_A, "cemetery_west_gate_exit", func(p: Vector3) -> bool: return p.x < 9.4, 5000)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_S, "cemetery_exit_lane", func(p: Vector3) -> bool: return p.z > 10.4, 5000)

func _fight_bell_eater_real_input(game: Node) -> void:
	if bool(game.story_state.get_flag("bell_eater_defeated", false)):
		_fail("Bell fight must begin with an actual undefeated encounter")
		return
	var boss: Node3D = null
	for candidate in game.active_enemies:
		if is_instance_valid(candidate) and candidate.enemy_id == "bell_eater" and not candidate.dead:
			if boss != null:
				_fail("Bell route contains duplicate living bosses")
				return
			boss = candidate
	if boss == null:
		_fail("Genuine shrine save did not restore the living Bell-Eater")
		return
	await _align_chapel_entrance(game)
	# A chasing boss can occupy the waypoint. Engage it from reachable range
	# rather than asking the real capsule to walk through that living body.
	await _move_until(game, KEY_A, "bell_chapel_doorway", func(p: Vector3) -> bool:
		var offset: Vector3 = boss.global_position - p
		offset.y = 0.0
		return p.x < 13.7 or offset.length() <= 1.7
	, 5000)
	if not failures.is_empty():
		return
	_key(KEY_T, true)
	await _frames(2)
	_key(KEY_T, false)
	await _frames(8)
	if game.camera_rig.get_locked_combat_target() != boss:
		_fail("Real target-lock input did not acquire Bell-Eater outside the chapel")
		return
	_key(KEY_C, true)
	await _frames(100)
	_key(KEY_C, false)
	await _frames(22)
	var deadline := Time.get_ticks_msec() + 90000
	var last_progress := Time.get_ticks_msec()
	var observed_health: float = boss.health_component.health
	var last_attack := 0
	var last_potion := 0
	while Time.get_ticks_msec() < deadline:
		if bool(game.story_state.get_flag("bell_eater_defeated", false)):
			_mouse_button(MOUSE_BUTTON_RIGHT, false)
			_release_combat_movement()
			for flag in ["cemetery_bell_silent", "boss_reward_granted_bell_eater", "boss_reward_bell_iron", "boss_reward_chapel_key"]:
				if not bool(game.story_state.get_flag(flag, false)):
					_fail("Actual Bell-Eater death omitted %s" % flag)
			if failures.is_empty():
				print("REAL_INPUT bell_eater_fight=PASS health=%.1f phase=%d rewards=true aftermath=true position=%s" % [game.player.health_component.health, boss.boss_phase if is_instance_valid(boss) else 3, game.player.global_position])
				await _clear_bell_summons_real_input(game)
			return
		if game.player.health_component.health <= 0.0 or not is_instance_valid(boss):
			_fail("Bell-Eater fight ended without actual resolution")
			break
		var now := Time.get_ticks_msec()
		if boss.health_component.health < observed_health:
			observed_health = boss.health_component.health
			last_progress = now
		if now - last_progress > 25000:
			_fail("Bell combat stalled: player=%s boss=%s health=%.1f" % [game.player.global_position, boss.global_position, observed_health])
			break
		var separation: Vector3 = boss.global_position - game.player.global_position
		separation.y = 0.0
		var defending: bool = boss.pending_attack_time > 0.0 and separation.length() < 4.0
		_mouse_button(MOUSE_BUTTON_RIGHT, defending)
		if defending:
			_release_combat_movement()
		if not defending and game.player.health_component.health < 75.0 and game.player.attack_cooldown <= 0.01 and int(game.inventory.items.get("redroot_potion", 0)) > 0 and now - last_potion > 6000:
			_key(KEY_R, true)
			await _frames(2)
			_key(KEY_R, false)
			last_potion = now
		elif not defending:
			last_attack = await _drive_contact_strike(game, boss, last_attack, 430)
		await _frames(3)
	_mouse_button(MOUSE_BUTTON_RIGHT, false)
	_key(KEY_W, false)
	if failures.is_empty():
		_fail("Real-input Bell-Eater fight timed out")

func _clear_bell_summons_real_input(game: Node) -> void:
	var deadline := Time.get_ticks_msec() + 45000
	var last_attack := 0
	var last_potion := 0
	var observed: Node3D = null
	var observed_health := INF
	var last_progress := Time.get_ticks_msec()
	var defeated := 0
	while Time.get_ticks_msec() < deadline:
		var enemy: Node3D = null
		for candidate in game.active_enemies:
			if is_instance_valid(candidate) and bool(candidate.get_meta("bell_called_ghoulkin", false)) and not candidate.dead:
				enemy = candidate
				break
		if enemy == null:
			_release_combat_movement()
			print("REAL_INPUT bell_summons_cleared=PASS defeated=%d health=%.1f" % [defeated, game.player.health_component.health])
			return
		if game.player.health_component.health <= 0.0:
			_fail("Kael died fighting the actual bell summon")
			return
		if enemy != observed:
			observed = enemy
			observed_health = INF
			last_progress = Time.get_ticks_msec()
		if enemy.health_component.health < observed_health:
			observed_health = enemy.health_component.health
			last_progress = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_progress > 20000:
			_fail("Bell summon combat stalled: player=%s enemy=%s health=%.1f" % [game.player.global_position, enemy.global_position, observed_health])
			return
		if game.camera_rig.get_locked_combat_target() != enemy:
			if game.camera_rig.get_locked_combat_target() != null:
				_key(KEY_T, true)
				await _frames(2)
				_key(KEY_T, false)
				await _frames(3)
			_key(KEY_T, true)
			await _frames(2)
			_key(KEY_T, false)
			await _frames(8)
		var separation: Vector3 = enemy.global_position - game.player.global_position
		separation.y = 0.0
		var now := Time.get_ticks_msec()
		if game.player.health_component.health < 65.0 and game.player.attack_cooldown <= 0.01 and int(game.inventory.items.get("redroot_potion", 0)) > 0 and now - last_potion > 6000:
			_key(KEY_R, true)
			await _frames(2)
			_key(KEY_R, false)
			last_potion = now
		else:
			last_attack = await _drive_contact_strike(game, enemy, last_attack, 430)
		await _frames(3)
		if is_instance_valid(enemy) and enemy.dead:
			defeated += 1
	_fail("Real-input bell summon cleanup timed out")

func _continue_teeth_in_rain(game: Node) -> void:
	if not game.quests.is_active("main_teeth_in_rain") or not game.quests.is_completed("main_bell_beneath_greyfen"):
		_fail("Continue did not restore the completed Bell choice and Teeth in the Rain")
		return
	print("REAL_INPUT teeth_checkpoint=PASS choice=%s position=%s" % [game.story_state.get_flag("crow_shrine_state", ""), game.player.global_position])
	await _leave_chapel_for_south_road(game)
	await _move_until(game, KEY_A, "bridge_return_centerline", func(p: Vector3) -> bool: return p.x < 0.4, 10000)
	await _move_until(game, KEY_W, "village_north_bank", func(p: Vector3) -> bool: return p.z < 0.8, 7000)
	await _move_until(game, KEY_A, "mira_west_lane", func(p: Vector3) -> bool: return p.x < -5.8, 6000)
	await _move_until(game, KEY_W, "mira_frontage", func(p: Vector3) -> bool: return p.z < -0.65, 5000)
	await _use_focused_interaction(game, "mira", "mira_teeth_briefing")
	if failures.is_empty() and not game.quests.is_objective_done("main_teeth_in_rain", "speak_mira"):
		_fail("Mira's real dialogue did not complete the Teeth in the Rain briefing")
	var mira := game.zone_root.find_child("mira", true, false) as Node3D
	if failures.is_empty() and (mira == null or game.player.global_position.distance_to(mira.global_position) > 3.6):
		_fail("Dialogue staging moved Kael away from Mira's reachable frontage: %s" % game.player.global_position)
	elif failures.is_empty():
		print("REAL_INPUT speak_mira=PASS position=%s" % game.player.global_position)
	var objective: Dictionary = game.quest_presentation.get_objective_view_model()
	if failures.is_empty() and (str(objective.get("quest_id", "")) != "main_teeth_in_rain" or str(objective.get("objective_id", "")) != "read_chapel_names"):
		_fail("Mira's conversation left Greyfen tracking the wrong next beat: %s" % objective)
		return
	if failures.is_empty():
		await _turn_camera_north(game)
		await _move_until(game, KEY_S, "mira_to_bridge_lane", func(p: Vector3) -> bool: return p.z > 0.5, 5000)
		await _move_until(game, KEY_D, "mira_to_bridge_centerline", func(p: Vector3) -> bool: return p.x > -0.3, 6000)
		await _move_until(game, KEY_S, "chapel_south_bank", func(p: Vector3) -> bool: return p.z > 10.0, 7000)
		await _move_until(game, KEY_D, "chapel_names_east_lane", func(p: Vector3) -> bool: return p.x > 14.4, 10000)
		await _move_until(game, KEY_W, "chapel_names_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "chapel_names", 5000)
		await _use_focused_interaction(game, "chapel_names", "chapel_names")
		if failures.is_empty() and not game.quests.is_objective_done("main_teeth_in_rain", "read_chapel_names"):
			_fail("Real chapel-name inspection did not complete the next Teeth in the Rain beat")
		elif failures.is_empty():
			print("REAL_INPUT read_chapel_names=PASS position=%s" % game.player.global_position)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_S, "chapel_to_south_road", func(p: Vector3) -> bool: return p.z > 10.3, 4000)
	await _move_until(game, KEY_A, "chapel_to_bridge_centerline", func(p: Vector3) -> bool: return p.x < 0.35, 10000)
	await _move_until(game, KEY_W, "chapel_to_north_bank", func(p: Vector3) -> bool: return p.z < 0.8, 7000)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_W, "teeth_greyfen_to_wychwood", func(_p: Vector3) -> bool: return game.current_zone_id == "wychwood" and not game.zone_transition_pending and not game.player.transition_locked and game.player.can_control, 12000)
	if not failures.is_empty():
		return
	await _continue_wychwood_teeth(game)

func _continue_wychwood_teeth(game: Node) -> void:
	await _turn_camera_north(game)
	await _move_until(game, KEY_W, "teeth_wychwood_bridge_north", func(p: Vector3) -> bool: return p.z < -2.8, 7000)
	await _move_until(game, KEY_D, "ritual_stones_east_path", func(p: Vector3) -> bool: return p.x > 7.3, 6000)
	await _move_until(game, KEY_W, "ritual_stones_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "ritual_stones", 7000)
	await _use_focused_interaction(game, "ritual_stones", "ritual_stones")
	if failures.is_empty() and not game.quests.is_objective_done("main_teeth_in_rain", "name_the_dead"):
		_fail("Real ritual-stones interaction did not complete name_the_dead")
	elif failures.is_empty():
		print("REAL_INPUT name_the_dead=PASS position=%s" % game.player.global_position)
	if not failures.is_empty():
		return
	# Leave the west face of the physical ritual pillar before heading east.
	# Its south edge is z=-11.425; z=-10.5 clears the real player capsule.
	await _move_until(game, KEY_S, "ritual_stones_departure_lane", func(p: Vector3) -> bool: return p.z > -10.5, 4000)
	await _move_until(game, KEY_D, "deep_wood_gate_east_path", func(p: Vector3) -> bool: return p.x > 10.1, 5000)
	if not failures.is_empty():
		return
	_key(KEY_W, true)
	var crossing_deadline := Time.get_ticks_msec() + 7000
	while Time.get_ticks_msec() < crossing_deadline and game.current_zone_id == "wychwood":
		if game.active_interactable != null and game.active_interactable.interaction_id == "gate_deep_wood":
			break
		await physics_frame
	_key(KEY_W, false)
	await _frames(4)
	if game.current_zone_id == "wychwood":
		await _use_focused_interaction(game, "gate_deep_wood", "deep_wood_gate")
	if not failures.is_empty():
		return
	var arrival_deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < arrival_deadline and (game.current_zone_id != "deep_wood" or game.zone_transition_pending or game.player.transition_locked):
		await process_frame
	if game.current_zone_id != "deep_wood" or game.zone_transition_pending or game.player.transition_locked:
		_fail("Focused Deep Wood gate did not reach a controllable arrival; zone=%s position=%s" % [game.current_zone_id, game.player.global_position])
		return
	await _complete_bog_wretch(game)

func _complete_bog_wretch(game: Node) -> void:
	var bog_wretch: Node3D = null
	for enemy in game.active_enemies:
		if is_instance_valid(enemy) and enemy.enemy_id == "bog_wretch":
			bog_wretch = enemy
			break
	if bog_wretch == null:
		_fail("Deep Wood arrival omitted the quest-gated Bog Wretch")
	else:
		print("REAL_INPUT bog_wretch_arrival=PASS player=%s enemy=%s" % [game.player.global_position, bog_wretch.global_position])
		await _fight_bog_wretch(game, bog_wretch)
		if failures.is_empty():
			await _use_focused_interaction(game, "bog_core_choice", "bog_core_choice")
		if failures.is_empty() and not game.quests.is_completed("main_teeth_in_rain"):
			_fail("Real memory-core dialogue did not complete Teeth in the Rain")
		elif failures.is_empty() and (not game.quests.is_active("main_names_they_burned") or str(game.story_state.get_flag("bog_core_fate", "")) == ""):
			_fail("Memory-core choice did not start Names They Burned with a persisted fate")
		elif failures.is_empty():
			print("REAL_INPUT bog_core_choice=PASS fate=%s" % game.story_state.get_flag("bog_core_fate", ""))

func _continue_names_they_burned(game: Node) -> void:
	if not game.quests.is_active("main_names_they_burned") or str(game.story_state.get_flag("bog_core_fate", "")) == "":
		_fail("Continue lost the Names chapter or saved memory-core fate")
		return
	print("REAL_INPUT names_checkpoint=PASS position=%s fate=%s" % [game.player.global_position, game.story_state.get_flag("bog_core_fate", "")])
	await _turn_camera_north(game)
	await _move_until(game, KEY_S, "deep_wood_return_south", func(p: Vector3) -> bool: return p.z > 11.0, 9000)
	await _move_until(game, KEY_A, "deep_wood_return_west", func(p: Vector3) -> bool: return p.x < -6.5, 6000)
	if not failures.is_empty():
		return
	_key(KEY_S, true)
	var return_deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < return_deadline and game.current_zone_id == "deep_wood":
		if game.active_interactable != null and game.active_interactable.interaction_id == "gate_wychwood":
			break
		await physics_frame
	_key(KEY_S, false)
	await _frames(4)
	if game.current_zone_id == "deep_wood":
		await _use_focused_interaction(game, "gate_wychwood", "deep_wood_return_gate")
	if not failures.is_empty():
		return
	return_deadline = Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < return_deadline and (game.current_zone_id != "wychwood" or game.zone_transition_pending or game.player.transition_locked):
		await process_frame
	if game.current_zone_id != "wychwood" or game.player.transition_locked:
		_fail("Deep Wood return did not reach playable Wychwood")
		return
	print("REAL_INPUT names_deepwood_to_wychwood=PASS position=%s" % game.player.global_position)
	await _move_until(game, KEY_S, "wychwood_return_north_bank", func(p: Vector3) -> bool: return p.z > -3.7, 7000)
	await _move_until(game, KEY_A, "wychwood_return_centerline", func(p: Vector3) -> bool: return p.x < 0.35, 8000)
	if not failures.is_empty():
		return
	_key(KEY_S, true)
	return_deadline = Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < return_deadline and game.current_zone_id == "wychwood":
		await physics_frame
	_key(KEY_S, false)
	await _frames(4)
	if game.current_zone_id != "greyfen" or game.zone_transition_pending or game.player.transition_locked:
		_fail("Names return did not reach playable Greyfen; zone=%s position=%s" % [game.current_zone_id, game.player.global_position])
		return
	print("REAL_INPUT names_wychwood_to_greyfen=PASS position=%s" % game.player.global_position)
	await _collect_greyfen_register_pages(game)
	if failures.is_empty():
		await _continue_register_rook(game)

func _collect_greyfen_register_pages(game: Node) -> void:
	if not game.quests.is_active("main_names_they_burned"):
		_fail("Greyfen register route lost the active Names chapter")
		return
	await _move_until(game, KEY_S, "register_anwen_south_road", func(p: Vector3) -> bool: return p.z > -4.5, 6000)
	await _move_until(game, KEY_D, "register_anwen_east_lane", func(p: Vector3) -> bool: return p.x > 4.0, 5000)
	await _move_until(game, KEY_W, "register_anwen_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "register_anwen", 5000)
	await _use_focused_interaction(game, "register_anwen", "register_anwen")
	if failures.is_empty() and not game.quests.is_objective_done("main_names_they_burned", "fragment_anwen"):
		_fail("Anwen's register fragment did not advance through E")
	elif failures.is_empty():
		print("REAL_INPUT fragment_anwen=PASS position=%s" % game.player.global_position)
	await _move_until(game, KEY_A, "register_tor_center_road", func(p: Vector3) -> bool: return p.x < 0.4, 5000)
	await _move_until(game, KEY_S, "register_tor_south_road", func(p: Vector3) -> bool: return p.z > 1.4, 6000)
	await _move_until(game, KEY_D, "register_tor_east_lane", func(p: Vector3) -> bool: return p.x > 8.2, 5000)
	await _move_until(game, KEY_W, "register_tor_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "register_tor", 5000)
	await _use_focused_interaction(game, "register_tor", "register_tor")
	if failures.is_empty() and not game.quests.is_objective_done("main_names_they_burned", "fragment_tor"):
		_fail("Tor's forge register fragment did not advance through E")
	elif failures.is_empty():
		print("REAL_INPUT fragment_tor=PASS position=%s" % game.player.global_position)

func _continue_register_rook(game: Node) -> void:
	await _move_until(game, KEY_A, "register_west_centerline", func(p: Vector3) -> bool: return p.x < 0.35, 6000)
	await _move_until(game, KEY_W, "register_west_road", func(p: Vector3) -> bool: return p.z < -9.7, 7000)
	await _move_until(game, KEY_A, "register_greyfen_to_deep_wood", func(_p: Vector3) -> bool: return game.current_zone_id == "deep_wood", 12000)
	if not await _await_playable_zone(game, "deep_wood", "register_deep_wood_arrival"):
		return
	await _move_until(game, KEY_D, "register_deep_wood_east_lane", func(p: Vector3) -> bool: return p.x > 2.0, 6000)
	await _move_until(game, KEY_W, "register_deep_wood_north_road", func(p: Vector3) -> bool: return p.z < -11.0, 10000)
	await _move_until(game, KEY_D, "register_deep_wood_north_gate_lane", func(p: Vector3) -> bool: return p.x > 7.0, 5000)
	await _move_until(game, KEY_W, "register_deep_wood_to_mill", func(_p: Vector3) -> bool: return game.current_zone_id == "old_mill", 8000)
	if not await _await_playable_zone(game, "old_mill", "register_mill_arrival"):
		return
	await _move_until(game, KEY_D, "register_mill_east_lane", func(p: Vector3) -> bool: return p.x > 3.2, 6000)
	await _move_until(game, KEY_W, "register_mill_north_road", func(p: Vector3) -> bool: return p.z < -11.0, 10000)
	await _move_until(game, KEY_D, "register_mill_north_gate_lane", func(p: Vector3) -> bool: return p.x > 7.0, 5000)
	await _move_until(game, KEY_W, "register_mill_to_farmstead", func(_p: Vector3) -> bool: return game.current_zone_id == "burned_farmstead", 8000)
	if not await _await_playable_zone(game, "burned_farmstead", "register_farmstead_arrival"):
		return
	await _collect_farmstead_register_rook(game)
	if failures.is_empty():
		await _return_register_from_farmstead(game)

func _collect_farmstead_register_rook(game: Node) -> void:
	await _move_until(game, KEY_D, "register_farmstead_center_road", func(p: Vector3) -> bool: return p.x > -3.0, 5000)
	await _move_until(game, KEY_W, "register_farmstead_north_road", func(p: Vector3) -> bool: return p.z < -5.0, 9000)
	await _move_until(game, KEY_A, "register_rook_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "register_rook", 6000)
	await _use_focused_interaction(game, "register_rook", "register_rook")
	if failures.is_empty() and not game.quests.is_objective_done("main_names_they_burned", "fragment_rook"):
		_fail("Rook's register fragment did not advance through E")
	elif failures.is_empty():
		print("REAL_INPUT fragment_rook=PASS position=%s" % game.player.global_position)
	if failures.is_empty() and not game.quests.is_objective_done("main_names_they_burned", "reconstruct_register"):
		_fail("Three physically collected pages did not reconstruct the register")
	elif failures.is_empty():
		print("REAL_INPUT reconstruct_register=PASS")

func _return_register_from_farmstead(game: Node) -> void:
	await _move_until(game, KEY_D, "register_farmstead_return_lane", func(p: Vector3) -> bool: return p.x > -2.5, 5000)
	await _move_until(game, KEY_S, "register_farmstead_return_road", func(p: Vector3) -> bool: return p.z > 11.0, 9000)
	await _move_until(game, KEY_A, "register_farmstead_return_gate_lane", func(p: Vector3) -> bool: return p.x < -7.0, 5000)
	await _move_until(game, KEY_S, "register_farmstead_to_mill", func(_p: Vector3) -> bool: return game.current_zone_id == "old_mill", 8000)
	if not await _await_playable_zone(game, "old_mill", "register_mill_return"):
		return
	await create_timer(0.5).timeout
	var slot: Dictionary = game.save_manager._read_slot(game.save_manager.AUTOSAVE_PATH)
	var saved: Dictionary = slot.get("data", {})
	var objectives: Array = saved.get("quests", {}).get("active", {}).get("main_names_they_burned", {}).get("objectives", [])
	var saved_reconstruction := false
	for objective in objectives:
		if str(objective.get("id", "")) == "reconstruct_register":
			saved_reconstruction = bool(objective.get("done", false))
	if not bool(slot.get("ok", false)) or str(saved.get("zone", "")) != "old_mill" or not saved_reconstruction:
		_fail("Old Mill autosave lost the reconstructed register or return zone")
	else:
		print("REAL_INPUT register_mill_autosave=PASS zone=old_mill reconstructed=true")

func _return_register_to_deep_wood(game: Node) -> void:
	if not game.quests.is_objective_done("main_names_they_burned", "reconstruct_register"):
		_fail("Old Mill continuation lost the reconstructed register")
		return
	await _move_until(game, KEY_A, "register_mill_south_lane", func(p: Vector3) -> bool: return p.x < 3.3, 5000)
	await _move_until(game, KEY_S, "register_mill_south_road", func(p: Vector3) -> bool: return p.z > 11.0, 10000)
	await _move_until(game, KEY_A, "register_mill_south_gate_lane", func(p: Vector3) -> bool: return p.x < -7.0, 6000)
	await _move_until(game, KEY_S, "register_mill_to_deep_wood", func(_p: Vector3) -> bool: return game.current_zone_id == "deep_wood", 8000)
	if not await _await_playable_zone(game, "deep_wood", "register_rootbound_arrival"):
		return
	var rootbound: Node3D = null
	for enemy in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and str(enemy.get("enemy_id")) == "rootbound_colossus":
			rootbound = enemy
			break
	if rootbound == null or not rootbound.is_inside_tree():
		_fail("Reconstructed register did not stage the Rootbound Colossus on Deep Wood return")
		return
	print("REAL_INPUT rootbound_quest_handoff=PASS position=%s enemy=%s" % [game.player.global_position, rootbound.global_position])
	await create_timer(0.5).timeout
	var slot: Dictionary = game.save_manager._read_slot(game.save_manager.AUTOSAVE_PATH)
	if not bool(slot.get("ok", false)) or str((slot.get("data", {}) as Dictionary).get("zone", "")) != "deep_wood":
		_fail("Rootbound return autosave did not preserve Deep Wood")
	else:
		print("REAL_INPUT rootbound_autosave=PASS zone=deep_wood")

func _verify_rootbound_reload(game: Node) -> void:
	if not game.quests.is_objective_done("main_names_they_burned", "reconstruct_register"):
		_fail("Rootbound reload lost register reconstruction")
		return
	var rootbound: Node3D = null
	for enemy in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and str(enemy.get("enemy_id")) == "rootbound_colossus":
			rootbound = enemy
			break
	if rootbound == null:
		_fail("Undefeated Rootbound was absent at the actual chapter arrival")
	else:
		print("REAL_INPUT rootbound_stage=PASS enemy=%s continue_fixture=%s" % [rootbound.global_position, OS.get_cmdline_user_args().has("--continue-rootbound-fight")])

func _fight_rootbound_real_input(game: Node) -> void:
	await _verify_rootbound_reload(game)
	if not failures.is_empty():
		return
	var boss: Node3D = null
	for enemy in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and str(enemy.get("enemy_id")) == "rootbound_colossus":
			boss = enemy
			break
	_key(KEY_T, true)
	await _frames(2)
	_key(KEY_T, false)
	await _frames(8)
	if game.camera_rig.get_locked_combat_target() != boss:
		_fail("Real target-lock input did not acquire Rootbound")
		return
	_key(KEY_2, true)
	await _frames(2)
	_key(KEY_2, false)
	await _frames(5)
	if str(game.player.weapon_mode) != "bow":
		_fail("Real weapon-switch input did not equip bow")
		return
	var arrows_before := int(game.inventory.items.get("standard_arrow", 0))
	var potions_before := int(game.inventory.items.get("redroot_potion", 0))
	var potion_requests := 0
	var initial_health: float = boss.health_component.health
	_mouse_button(MOUSE_BUTTON_RIGHT, true)
	await _frames(15)
	var last_potion := 0
	for shot in range(arrows_before):
		if bool(boss.get("dead")) or bool(game.story_state.get_flag("rootbound_colossus_defeated", false)):
			break
		if game.player.health_component.health <= 0.0:
			break
		var now := Time.get_ticks_msec()
		if game.player.health_component.health < 70.0 and int(game.inventory.items.get("redroot_potion", 0)) > 0 and now - last_potion > 2000:
			_key(KEY_R, true)
			await _frames(2)
			_key(KEY_R, false)
			potion_requests += 1
			last_potion = now
		var draw_deadline := Time.get_ticks_msec() + 4000
		while game.player.bow_draw_time < game.player.BOW_MAX_DRAW and Time.get_ticks_msec() < draw_deadline and not bool(boss.get("dead")) and game.player.health_component.health > 0.0:
			await _frames(1)
		if bool(boss.get("dead")) or game.player.health_component.health <= 0.0:
			break
		if game.player.bow_draw_time < game.player.BOW_MAX_DRAW:
			_fail("Rootbound bow did not reach full draw through held aim input")
			break
		_mouse_button(MOUSE_BUTTON_LEFT, true)
		await _frames(2)
		_mouse_button(MOUSE_BUTTON_LEFT, false)
		await _frames(26)
	_mouse_button(MOUSE_BUTTON_RIGHT, false)
	print("REAL_INPUT rootbound_combat_observation arrows_used=%d boss_health=%.1f/%.1f player_health=%.1f potions=%d player=%s boss=%s" % [arrows_before - int(game.inventory.items.get("standard_arrow", 0)), boss.health_component.health if is_instance_valid(boss) else 0.0, initial_health, game.player.health_component.health, int(game.inventory.items.get("redroot_potion", 0)), game.player.global_position, boss.global_position if is_instance_valid(boss) else Vector3.INF])
	if potion_requests > 0 and int(game.inventory.items.get("redroot_potion", 0)) != potions_before - potion_requests:
		_fail("Bow-equipped potion input did not consume a carried Redroot Potion")
	print("REAL_INPUT rootbound_potion_input requests=%d consumed=%d not_exercised=%s" % [potion_requests, potions_before - int(game.inventory.items.get("redroot_potion", 0)), potion_requests == 0])
	if not bool(game.story_state.get_flag("rootbound_colossus_defeated", false)):
		_fail("Real-input Rootbound encounter did not resolve")
	else:
		print("REAL_INPUT rootbound_defeat=PASS")

func _return_from_rootbound(game: Node) -> void:
	if not bool(game.story_state.get_flag("rootbound_colossus_defeated", false)) or not game.quests.is_active("main_names_they_burned"):
		_fail("Rootbound defeat or Names chapter was lost on Continue")
		return
	for enemy in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and str(enemy.get("enemy_id")) == "rootbound_colossus" and not bool(enemy.get("dead")):
			_fail("Defeated Rootbound respawned on Continue")
			return
	await _move_until(game, KEY_A, "rootbound_return_center", func(p: Vector3) -> bool: return p.x < 2.2, 5000)
	await _move_until(game, KEY_S, "rootbound_return_south_road", func(p: Vector3) -> bool: return p.z > 11.0, 10000)
	await _move_until(game, KEY_A, "rootbound_return_wychwood_lane", func(p: Vector3) -> bool: return p.x < -7.0, 6000)
	await _move_until(game, KEY_S, "rootbound_return_wychwood", func(_p: Vector3) -> bool: return game.current_zone_id == "wychwood", 8000)
	if not await _await_playable_zone(game, "wychwood", "rootbound_wychwood_arrival"):
		return
	await _move_until(game, KEY_S, "names_return_wychwood_north_bank", func(p: Vector3) -> bool: return p.z > -3.7, 7000)
	await _move_until(game, KEY_A, "names_return_wychwood_bridge_lane", func(p: Vector3) -> bool: return p.x < 0.35, 8000)
	await _move_until(game, KEY_S, "names_return_greyfen", func(_p: Vector3) -> bool: return game.current_zone_id == "greyfen", 10000)
	if not await _await_playable_zone(game, "greyfen", "names_greyfen_arrival"):
		return
	await _resolve_names_choice(game)

func _resolve_names_choice(game: Node) -> void:
	var outcome := "withheld" if OS.get_cmdline_user_args().has("--names-withheld") else "published"
	var choice := "Use the names against the curse first" if outcome == "withheld" else "Publish every recovered name"
	if not game.quests.is_objective_done("main_names_they_burned", "reconstruct_register") or str(game.story_state.get_flag("names_policy", "")) != "":
		_fail("Names choice requires the genuine reconstructed pre-choice register")
		return
	await _move_until(game, KEY_S, "names_decision_south_road", func(p: Vector3) -> bool: return p.z > -4.5, 6000)
	await _move_until(game, KEY_D, "names_decision_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "names_decision", 6000)
	await _choose_focused_dialogue_action(game, "names_decision", choice, "names_decision")
	if not failures.is_empty():
		return
	if not game.quests.is_completed("main_names_they_burned") or not game.quests.is_active("main_ash_at_the_mill") or str(game.story_state.get_flag("names_policy", "")) != outcome:
		_fail("Real Names decision did not complete the chapter or activate Ash at the Mill")
		return
	print("REAL_INPUT names_decision_complete=PASS policy=%s ash_at_mill_active=true" % outcome)

func _prepare_for_ash_mill(game: Node) -> void:
	if not game.quests.is_active("main_ash_at_the_mill"):
		_fail("Ash at the Mill was not active on Continue")
		return
	await _move_until(game, KEY_A, "ash_shop_center_road", func(p: Vector3) -> bool: return p.x < 0.4, 5000)
	await _move_until(game, KEY_W, "ash_shop_north_road", func(p: Vector3) -> bool: return p.z < -4.3, 5000)
	await _move_until(game, KEY_D, "ash_shop_front_lane", func(p: Vector3) -> bool: return p.x > 10.0, 7000)
	await _move_until(game, KEY_S, "ash_shop_front_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "tor_forge", 5000)
	if not failures.is_empty():
		return
	_key(KEY_E, true)
	await _frames(3)
	_key(KEY_E, false)
	await _frames(8)
	if not game.hud.inventory_layer.visible or not paused:
		_fail("Focused Tor forge E input did not open its vendor menu")
		return
	var arrows_before := int(game.inventory.items.get("standard_arrow", 0))
	var coins_before := int(game.inventory.coin)
	if arrows_before < 0 or arrows_before > 24 or coins_before < 0:
		_fail("Actual carried ammunition/coins violate their inventory bounds")
		return
	if arrows_before < 5:
		if not await _focus_vendor_button("Claim Tor's free emergency arrows"):
			return
		_key(KEY_ENTER, true)
		await _frames(3)
		_key(KEY_ENTER, false)
		await _frames(5)
	var refilled_arrows := maxi(5, arrows_before)
	if int(game.inventory.items.get("standard_arrow", 0)) != refilled_arrows or int(game.inventory.coin) != coins_before:
		_fail("Tor's emergency policy changed paid coins or actual carried ammunition")
		return
	print("REAL_INPUT tor_supply_before_purchase=PASS arrows=%d coin=%d emergency_used=%s" % [refilled_arrows, coins_before, arrows_before < 5])
	var purchases := maxi(0, 20 - refilled_arrows)
	if coins_before < purchases:
		_fail("Actual campaign economy cannot fund twenty standard arrows")
		return
	if purchases > 0:
		if not await _focus_vendor_button("Buy Standard Arrow", true):
			return
		for _purchase in range(purchases):
			_key(KEY_ENTER, true)
			await _frames(2)
			_key(KEY_ENTER, false)
			await _frames(2)
	expected_ash_supply_arrows = refilled_arrows + purchases
	if int(game.inventory.items.get("standard_arrow", 0)) != expected_ash_supply_arrows or int(game.inventory.coin) != coins_before - purchases:
		_fail("Tor purchase violated exact quantity or one-coin-per-arrow payment")
		return
	print("REAL_INPUT tor_paid_arrows=PASS arrows=%d coin=%d purchases=%d" % [expected_ash_supply_arrows, coins_before - purchases, purchases])
	if not await _focus_vendor_button("Close"):
		return
	_key(KEY_ENTER, true)
	await _frames(3)
	_key(KEY_ENTER, false)
	await _frames(8)
	if paused or game.hud.inventory_layer.visible or not game.player.can_control:
		_fail("Closing Tor's shop did not restore gameplay control")
		return
	await _move_until(game, KEY_W, "ash_depart_forge_front", func(p: Vector3) -> bool: return p.z < -4.3, 5000)
	await _move_until(game, KEY_A, "ash_depart_center_road", func(p: Vector3) -> bool: return p.x < 0.4, 7000)
	await _move_until(game, KEY_W, "ash_depart_west_road", func(p: Vector3) -> bool: return p.z < -9.7, 7000)
	await _move_until(game, KEY_A, "ash_depart_deep_wood", func(_p: Vector3) -> bool: return game.current_zone_id == "deep_wood", 12000)
	if not await _await_playable_zone(game, "deep_wood", "ash_deep_wood_arrival"):
		return
	await create_timer(0.5).timeout
	var slot: Dictionary = game.save_manager._read_slot(game.save_manager.AUTOSAVE_PATH)
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or str(saved.get("zone", "")) != "deep_wood" or int((saved.get("inventory", {}) as Dictionary).get("items", {}).get("standard_arrow", 0)) != expected_ash_supply_arrows:
		_fail("Deep Wood autosave lost the vendor arrow purchase")
	else:
		print("REAL_INPUT ash_supply_autosave=PASS zone=deep_wood arrows=%d" % expected_ash_supply_arrows)

func _travel_to_ash_mill(game: Node) -> void:
	if not game.quests.is_active("main_ash_at_the_mill") or int(game.inventory.items.get("standard_arrow", 0)) != expected_ash_supply_arrows:
		_fail("Ash at the Mill continuation lost quest or Tor's purchased arrows")
		return
	await _move_until(game, KEY_D, "ash_deep_wood_east_lane", func(p: Vector3) -> bool: return p.x > 2.0, 6000)
	await _move_until(game, KEY_W, "ash_deep_wood_north_road", func(p: Vector3) -> bool: return p.z < -11.0, 10000)
	await _move_until(game, KEY_D, "ash_deep_wood_north_gate_lane", func(p: Vector3) -> bool: return p.x > 7.0, 5000)
	await _move_until(game, KEY_W, "ash_deep_wood_to_mill", func(_p: Vector3) -> bool: return game.current_zone_id == "old_mill", 8000)
	if not await _await_playable_zone(game, "old_mill", "ash_mill_arrival"):
		return
	if not game.quests.is_objective_done("main_ash_at_the_mill", "reach_mill"):
		_fail("Physical mill arrival did not complete reach_mill")
		return
	await create_timer(0.5).timeout
	var slot: Dictionary = game.save_manager._read_slot(game.save_manager.AUTOSAVE_PATH)
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or str(saved.get("zone", "")) != "old_mill" or int((saved.get("inventory", {}) as Dictionary).get("items", {}).get("standard_arrow", 0)) != expected_ash_supply_arrows:
		_fail("Mill arrival autosave lost zone or purchased arrows")
	else:
		print("REAL_INPUT ash_mill_autosave=PASS reach_mill=true arrows=%d" % expected_ash_supply_arrows)

func _inspect_ash_millstones(game: Node) -> void:
	if not game.quests.is_active("main_ash_at_the_mill") or not game.quests.is_objective_done("main_ash_at_the_mill", "reach_mill"):
		_fail("Mill continuation lost Ash at the Mill arrival beat")
		return
	await _move_until(game, KEY_D, "ash_mill_front_lane", func(p: Vector3) -> bool: return p.x > -5.2, 5000)
	await _move_until(game, KEY_W, "ash_mill_front_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "millstones", 10000)
	await _use_focused_interaction(game, "millstones", "ash_millstones")
	if failures.is_empty() and not game.quests.is_objective_done("main_ash_at_the_mill", "inspect_millstones"):
		_fail("Real millstones E interaction did not complete inspect_millstones")
	elif failures.is_empty():
		print("REAL_INPUT ash_millstones_clue=PASS position=%s" % game.player.global_position)
		await _clear_ash_mill_ghoulkin(game)

func _clear_ash_mill_ghoulkin(game: Node) -> void:
	_key(KEY_1, true)
	await _frames(2)
	_key(KEY_1, false)
	await _frames(5)
	if str(game.player.weapon_mode) != "sword":
		_fail("Sword input did not equip Kael for the mill clearing")
		return
	var deadline := Time.get_ticks_msec() + 90000
	var last_attack := 0
	var last_potion := 0
	var last_damage := Time.get_ticks_msec()
	var observed_health := INF
	while Time.get_ticks_msec() < deadline:
		if game.quests.is_objective_done("main_ash_at_the_mill", "mill_encounter"):
			_release_combat_movement()
			var ashwing_count := 0
			for candidate in game.active_enemies:
				if is_instance_valid(candidate) and str(candidate.get("enemy_id")) == "ashwing" and not candidate.dead:
					ashwing_count += 1
			if ashwing_count != 1:
				_fail("Mill victory staged %d living Ashwing bosses instead of one" % ashwing_count)
			else:
				print("REAL_INPUT ash_mill_cleared=PASS ashwing_count=1 player_health=%.1f" % game.player.health_component.health)
				await _save_ashwing_handoff(game)
			return
		if game.player.health_component.health <= 0.0:
			_fail("Kael died before clearing the ash-bound mill")
			return
		var enemy: Node3D = null
		for candidate in game.active_enemies:
			if is_instance_valid(candidate) and not candidate.dead and bool(candidate.get_meta("ash_mill_enemy", false)):
				enemy = candidate
				break
		if enemy == null:
			await _frames(5)
			continue
		if enemy.health_component.health < observed_health:
			observed_health = enemy.health_component.health
			last_damage = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_damage > 22000:
			_fail("Ash mill combat stalled: player=%s enemy=%s enemy_health=%.1f" % [game.player.global_position, enemy.global_position, enemy.health_component.health])
			return
		if game.camera_rig.get_locked_combat_target() != enemy:
			if game.camera_rig.get_locked_combat_target() != null:
				_key(KEY_T, true)
				await _frames(2)
				_key(KEY_T, false)
				await _frames(3)
			_key(KEY_T, true)
			await _frames(2)
			_key(KEY_T, false)
			await _frames(8)
		var separation: Vector3 = enemy.global_position - game.player.global_position
		separation.y = 0.0
		last_attack = await _drive_contact_strike(game, enemy, last_attack, 430)
		if game.player.health_component.health < 65.0 and int(game.inventory.items.get("redroot_potion", 0)) > 0 and Time.get_ticks_msec() - last_potion > 6000:
			_key(KEY_R, true)
			await _frames(2)
			_key(KEY_R, false)
			last_potion = Time.get_ticks_msec()
		await _frames(3)
	_fail("Ash mill combat timed out before the encounter handoff")

func _save_ashwing_handoff(game: Node) -> void:
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var saved: Dictionary = slot.get("data", {})
	var saved_flags: Dictionary = saved.get("story_state", {}).get("flags", {})
	if not bool(slot.get("ok", false)) or str(saved.get("zone", "")) != "old_mill" or not bool(saved_flags.get("ashwing_spawned", false)):
		_fail("Real pause-menu save did not retain the Ashwing mill handoff")
	else:
		print("REAL_INPUT ashwing_handoff_manual_save=PASS zone=old_mill")

func _save_campaign_checkpoint(game: Node) -> Dictionary:
	_release_combat_movement()
	_key(KEY_ESCAPE, true)
	await _frames(2)
	_key(KEY_ESCAPE, false)
	await _frames(5)
	if not paused or game.hud.active_menu != "pause":
		_fail("Pause input did not open the menu after Ashwing appeared")
		return {}
	var save_focused := false
	for _index in range(10):
		var focused := root.gui_get_focus_owner() as Button
		if focused != null and focused.text == "Save":
			save_focused = true
			break
		_key(KEY_TAB, true)
		await _frames(2)
		_key(KEY_TAB, false)
		await _frames(2)
	if not save_focused:
		_fail("Pause menu Save was not reachable by keyboard")
		return {}
	_key(KEY_ENTER, true)
	await _frames(2)
	_key(KEY_ENTER, false)
	await _frames(8)
	return game.save_manager._read_slot(game.save_manager.SAVE_PATH)

func _fight_ashwing_real_input(game: Node) -> void:
	if not game.quests.is_objective_done("main_ash_at_the_mill", "mill_encounter") or bool(game.story_state.get_flag("ashwing_defeated", false)):
		_fail("Ashwing Continue did not restore the undefeated mill encounter")
		return
	var boss: Node3D = null
	var boss_count := 0
	for candidate in game.active_enemies:
		if is_instance_valid(candidate) and str(candidate.get("enemy_id")) == "ashwing" and not candidate.dead:
			boss = candidate
			boss_count += 1
	if boss_count != 1:
		_fail("Ashwing Continue restored %d living bosses" % boss_count)
		return
	print("REAL_INPUT ashwing_reload=PASS boss=%s arrows=%d health=%.1f" % [boss.global_position, game.inventory.items.get("standard_arrow", 0), game.player.health_component.health])
	if not game.camera_rig._is_valid_combat_target(boss):
		await _turn_camera_north(game)
		await _move_until(game, KEY_S, "ashwing_south_frontage", func(p: Vector3) -> bool: return p.z > -1.4, 5000)
		await _move_until(game, KEY_D, "ashwing_clear_east_yard", func(p: Vector3) -> bool: return p.x > 1.3, 6500)
		if not failures.is_empty():
			return
	if game.camera_rig.get_locked_combat_target() != boss:
		if game.camera_rig.get_locked_combat_target() != null:
			_key(KEY_T, true)
			await _frames(2)
			_key(KEY_T, false)
			await _frames(10)
		_key(KEY_T, true)
		await _frames(2)
		_key(KEY_T, false)
		await _frames(10)
	if game.camera_rig.get_locked_combat_target() != boss:
		_fail("Real target-lock input did not acquire Ashwing")
		return
	await _before_ashwing_attack(game)
	if not failures.is_empty():
		return
	_key(KEY_C, true)
	await _frames(100)
	_key(KEY_C, false)
	await _frames(22)
	print("REAL_INPUT ashwing_oathfire_observation hits=%d boss_health=%.1f" % [int(game.get_meta("last_oathfire_hit_count", 0)), boss.health_component.health])
	_key(KEY_2, true)
	await _frames(2)
	_key(KEY_2, false)
	await _frames(5)
	if str(game.player.weapon_mode) != "bow":
		_fail("Bow input did not equip Kael for Ashwing")
		return
	var arrows_before := int(game.inventory.items.get("standard_arrow", 0))
	_mouse_button(MOUSE_BUTTON_RIGHT, true)
	await _frames(15)
	var last_potion := 0
	for _shot in range(arrows_before):
		if bool(boss.get("dead")) or bool(game.story_state.get_flag("ashwing_defeated", false)) or game.player.health_component.health <= 0.0:
			break
		if game.player.health_component.health < 70.0 and int(game.inventory.items.get("redroot_potion", 0)) > 0 and Time.get_ticks_msec() - last_potion > 2000:
			_key(KEY_R, true)
			await _frames(2)
			_key(KEY_R, false)
			last_potion = Time.get_ticks_msec()
		_mouse_button(MOUSE_BUTTON_LEFT, true)
		await _frames(2)
		_mouse_button(MOUSE_BUTTON_LEFT, false)
		await _frames(26)
	_mouse_button(MOUSE_BUTTON_RIGHT, false)
	print("REAL_INPUT ashwing_combat_observation arrows_used=%d boss_health=%.1f player_health=%.1f potions=%d player=%s boss=%s" % [arrows_before - int(game.inventory.items.get("standard_arrow", 0)), boss.health_component.health if is_instance_valid(boss) else 0.0, game.player.health_component.health, int(game.inventory.items.get("redroot_potion", 0)), game.player.global_position, boss.global_position if is_instance_valid(boss) else Vector3.INF])
	if not bool(game.story_state.get_flag("ashwing_defeated", false)):
		_fail("Real-input Ashwing encounter did not resolve")
	else:
		print("REAL_INPUT ashwing_defeat=PASS")
		await _choose_mill_record(game)

func _before_ashwing_attack(_game: Node) -> void:
	pass

func _choose_mill_record(game: Node) -> void:
	var outcome := "burned" if OS.get_cmdline_user_args().has("--mill-burned") else ("exposed" if OS.get_cmdline_user_args().has("--mill-exposed") else "preserved")
	var choice := str({"preserved": "Preserve the ledger", "burned": "Burn the ledger", "exposed": "Post copies in Greyfen"}[outcome])
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	if game.player.global_position.z < -1.4:
		await _move_until(game, KEY_S, "ash_record_clear_frontage", func(p: Vector3) -> bool: return p.z > -1.4, 6000)
	await _move_until(game, KEY_A, "ash_record_front_lane", func(p: Vector3) -> bool: return p.x < -6.8, 6000)
	await _move_until(game, KEY_W, "ash_record_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "miller_record", 7000)
	await _choose_focused_dialogue_action(game, "miller_record", choice, "ash_mill_ledger")
	if not failures.is_empty():
		return
	if not game.quests.is_completed("main_ash_at_the_mill") or not game.quests.is_active("main_soldier_without_banner") or str(game.story_state.get_flag("mill_fate", "")) != outcome:
		_fail("Real ledger choice did not retain %s and advance to Soldier Without a Banner" % outcome)
		return
	print("REAL_INPUT ash_mill_choice=PASS fate=%s soldier_active=true" % outcome)
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var saved: Dictionary = slot.get("data", {})
	var saved_quests: Dictionary = saved.get("quests", {})
	var saved_flags: Dictionary = saved.get("story_state", {}).get("flags", {})
	if not bool(slot.get("ok", false)) or str(saved.get("zone", "")) != "old_mill" or not saved_quests.get("active", {}).has("main_soldier_without_banner") or str(saved_flags.get("mill_fate", "")) != outcome:
		_fail("Real pause-menu save lost the %s ledger choice or Soldier chapter" % outcome)
	else:
		print("REAL_INPUT soldier_handoff_manual_save=PASS zone=old_mill fate=%s" % outcome)

func _travel_to_bandit_road(game: Node) -> void:
	if not game.quests.is_active("main_soldier_without_banner") or str(game.story_state.get_flag("mill_fate", "")) != "preserved":
		_fail("Soldier continuation lost the saved mill choice")
		return
	await _move_until(game, KEY_S, "soldier_mill_front_clearance", func(p: Vector3) -> bool: return p.z > -1.4, 5000)
	await _move_until(game, KEY_D, "soldier_mill_east_lane", func(p: Vector3) -> bool: return p.x > 3.2, 6000)
	await _move_until(game, KEY_W, "soldier_mill_north_road", func(p: Vector3) -> bool: return p.z < -11.0, 10000)
	await _move_until(game, KEY_D, "soldier_mill_north_gate_lane", func(p: Vector3) -> bool: return p.x > 7.0, 5000)
	await _move_until(game, KEY_W, "soldier_mill_to_farmstead", func(_p: Vector3) -> bool: return game.current_zone_id == "burned_farmstead", 8000)
	if not await _await_playable_zone(game, "burned_farmstead", "soldier_farmstead_arrival"):
		return
	await _move_until(game, KEY_D, "soldier_farmstead_east_lane", func(p: Vector3) -> bool: return p.x > 2.0, 6000)
	await _move_until(game, KEY_W, "soldier_farmstead_north_road", func(p: Vector3) -> bool: return p.z < -11.0, 10000)
	await _move_until(game, KEY_D, "soldier_farmstead_north_gate_lane", func(p: Vector3) -> bool: return p.x > 7.0, 5000)
	await _move_until(game, KEY_W, "soldier_farmstead_to_marsh", func(_p: Vector3) -> bool: return game.current_zone_id == "marsh_crossing", 8000)
	if not await _await_playable_zone(game, "marsh_crossing", "soldier_marsh_arrival"):
		return
	await _move_until(game, KEY_W, "soldier_marsh_boardwalk", func(p: Vector3) -> bool: return p.z < -11.0, 10000)
	await _move_until(game, KEY_W, "soldier_marsh_to_bandit_road", func(_p: Vector3) -> bool: return game.current_zone_id == "bandit_road", 8000)
	if not await _await_playable_zone(game, "bandit_road", "soldier_bandit_road_arrival"):
		return
	if not game.quests.is_objective_done("main_soldier_without_banner", "reach_bandit_road"):
		_fail("Physical Bandit Road arrival did not advance Soldier Without a Banner")
		return
	await create_timer(0.5).timeout
	var slot: Dictionary = game.save_manager._read_slot(game.save_manager.AUTOSAVE_PATH)
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or str(saved.get("zone", "")) != "bandit_road" or str(saved.get("story_state", {}).get("flags", {}).get("mill_fate", "")) != "preserved":
		_fail("Bandit Road autosave lost the zone or preserved mill evidence")
	else:
		print("REAL_INPUT soldier_road_autosave=PASS zone=bandit_road mill_fate=preserved")
		var manual_slot := await _save_campaign_checkpoint(game)
		if not failures.is_empty():
			return
		if not bool(manual_slot.get("ok", false)) or str(manual_slot.get("data", {}).get("zone", "")) != "bandit_road":
			_fail("Real pause-menu save did not retain Bandit Road arrival")
		else:
			print("REAL_INPUT soldier_road_manual_save=PASS zone=bandit_road")

func _fight_senn_guard(game: Node) -> void:
	if not game.quests.is_active("main_soldier_without_banner") or not game.quests.is_objective_done("main_soldier_without_banner", "reach_bandit_road"):
		_fail("Senn continuation lost the Soldier chapter or road arrival")
		return
	var guard_count := 0
	for candidate in game.active_enemies:
		if is_instance_valid(candidate) and bool(candidate.get_meta("senn_guard", false)) and not candidate.dead:
			guard_count += 1
	if guard_count != 2:
		_fail("Senn road restored %d guards, expected two" % guard_count)
		return
	print("REAL_INPUT senn_guard_reload=PASS guards=2 position=%s" % game.player.global_position)
	await _move_until(game, KEY_D, "senn_road_center", func(p: Vector3) -> bool: return p.x > -0.5, 6000)
	await _move_until(game, KEY_W, "senn_road_approach", func(p: Vector3) -> bool: return p.z < 2.0, 12000)
	if not failures.is_empty():
		return
	_key(KEY_1, true)
	await _frames(2)
	_key(KEY_1, false)
	await _frames(5)
	var deadline := Time.get_ticks_msec() + 90000
	var last_attack := 0
	var last_potion := 0
	var last_progress := Time.get_ticks_msec()
	var observed_health := INF
	while Time.get_ticks_msec() < deadline:
		if game.quests.is_objective_done("main_soldier_without_banner", "senn_confrontation"):
			_release_combat_movement()
			print("REAL_INPUT senn_guard_defeat=PASS player_health=%.1f" % game.player.health_component.health)
			await _confront_senn(game)
			return
		if game.player.health_component.health <= 0.0:
			_fail("Kael died during Senn's guard confrontation")
			return
		var enemy: Node3D = null
		for candidate in game.active_enemies:
			if is_instance_valid(candidate) and bool(candidate.get_meta("senn_guard", false)) and not candidate.dead:
				enemy = candidate
				break
		if enemy == null:
			await _frames(5)
			continue
		if enemy.health_component.health < observed_health:
			observed_health = enemy.health_component.health
			last_progress = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_progress > 22000:
			_fail("Senn guard combat stalled: player=%s enemy=%s enemy_health=%.1f" % [game.player.global_position, enemy.global_position, enemy.health_component.health])
			return
		if game.camera_rig.get_locked_combat_target() != enemy:
			if game.camera_rig.get_locked_combat_target() != null:
				_key(KEY_T, true)
				await _frames(2)
				_key(KEY_T, false)
				await _frames(3)
			_key(KEY_T, true)
			await _frames(2)
			_key(KEY_T, false)
			await _frames(8)
		var separation: Vector3 = enemy.global_position - game.player.global_position
		separation.y = 0.0
		last_attack = await _drive_contact_strike(game, enemy, last_attack, 430)
		if game.player.health_component.health < 65.0 and int(game.inventory.items.get("redroot_potion", 0)) > 0 and Time.get_ticks_msec() - last_potion > 6000:
			_key(KEY_R, true)
			await _frames(2)
			_key(KEY_R, false)
			last_potion = Time.get_ticks_msec()
		await _frames(3)
	_fail("Senn guard confrontation timed out")

func _confront_senn(game: Node) -> void:
	var outcome := "exile" if OS.get_cmdline_user_args().has("--senn-exile") else ("punished" if OS.get_cmdline_user_args().has("--senn-punished") else "testimony")
	var choice := str({"testimony": "Testify in Greyfen", "exile": "Leave and never return", "punished": "Answer for the dead"}[outcome])
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	if game.player.global_position.z > -2.0:
		await _move_until(game, KEY_W, "senn_dialogue_front_lane", func(p: Vector3) -> bool: return p.z < -2.0, 7000)
	elif game.player.global_position.z < -3.0:
		await _move_until(game, KEY_S, "senn_dialogue_front_lane", func(p: Vector3) -> bool: return p.z > -3.0, 7000)
	if not failures.is_empty():
		return
	var approach_key: Key = KEY_D if game.player.global_position.x < 8.7 else KEY_A
	await _move_until(game, approach_key, "senn_dialogue_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "captain_senn", 7000)
	await _choose_focused_dialogue_action(game, "captain_senn", choice, "senn_testimony")
	if not failures.is_empty():
		return
	if not game.quests.is_completed("main_soldier_without_banner") or not game.quests.is_active("main_blood_under_stone") or str(game.story_state.get_flag("senn_fate", "")) != outcome:
		_fail("Senn's %s decision did not complete Soldier and begin Blood Under Stone" % outcome)
		return
	print("REAL_INPUT senn_testimony_choice=PASS fate=%s blood_under_stone_active=true" % outcome)
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or str(saved.get("zone", "")) != "bandit_road" or str(saved.get("story_state", {}).get("flags", {}).get("senn_fate", "")) != outcome or not saved.get("quests", {}).get("active", {}).has("main_blood_under_stone"):
		_fail("Real pause-menu save lost Senn's %s decision or Castle quest" % outcome)
	else:
		print("REAL_INPUT castle_handoff_manual_save=PASS zone=bandit_road fate=%s" % outcome)

func _travel_to_castle_approach(game: Node) -> void:
	var expected_senn := "exile" if OS.get_cmdline_user_args().has("--senn-exile") else ("punished" if OS.get_cmdline_user_args().has("--senn-punished") else "testimony")
	if not game.quests.is_active("main_blood_under_stone") or str(game.story_state.get_flag("senn_fate", "")) != expected_senn:
		_fail("Castle road continuation lost Senn's testimony")
		return
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_A, "castle_road_clear_tent_lane", func(p: Vector3) -> bool: return p.x < 5.6, 5000)
	await _move_until(game, KEY_W, "castle_road_north_of_tent", func(p: Vector3) -> bool: return p.z < -11.5, 10000)
	await _move_until(game, KEY_D, "castle_road_vargan_trigger_lane", func(p: Vector3) -> bool: return p.x > 6.9, 4000)
	await _move_until(game, KEY_W, "castle_road_to_vargan_approach", func(_p: Vector3) -> bool: return game.current_zone_id == "vargan_approach", 14000)
	if not await _await_playable_zone(game, "vargan_approach", "castle_approach_arrival"):
		return
	if not game.quests.is_objective_done("main_blood_under_stone", "reach_castle"):
		_fail("Physical Vargan arrival did not advance Blood Under Stone")
		return
	await create_timer(0.5).timeout
	var slot: Dictionary = game.save_manager._read_slot(game.save_manager.AUTOSAVE_PATH)
	if not bool(slot.get("ok", false)) or str(slot.get("data", {}).get("zone", "")) != "vargan_approach":
		_fail("Castle approach autosave did not preserve the arrival zone")
		return
	print("REAL_INPUT castle_approach_autosave=PASS zone=vargan_approach")
	var manual_slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	if not bool(manual_slot.get("ok", false)) or str(manual_slot.get("data", {}).get("zone", "")) != "vargan_approach":
		_fail("Real pause-menu save did not retain Castle approach")
	else:
		print("REAL_INPUT castle_approach_manual_save=PASS zone=vargan_approach")

func _collect_castle_evidence(game: Node) -> void:
	if not game.quests.is_active("main_blood_under_stone") or not game.quests.is_objective_done("main_blood_under_stone", "reach_castle"):
		_fail("Castle evidence continuation lost the arrival beat")
		return
	await _move_until(game, KEY_D, "castle_mile_marker_lane", func(p: Vector3) -> bool: return p.x > -3.9, 10000)
	await _move_until(game, KEY_W, "castle_mile_marker_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "vargan_mile_marker", 8000)
	await _use_focused_interaction(game, "vargan_mile_marker", "castle_mile_marker")
	if not failures.is_empty():
		return
	await _move_until(game, KEY_W, "castle_cart_south_lane", func(p: Vector3) -> bool: return p.z < 3.5, 5000)
	await _move_until(game, KEY_D, "castle_cart_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "vargan_supply_cart", 7000)
	await _use_focused_interaction(game, "vargan_supply_cart", "castle_supply_cart")
	if not failures.is_empty():
		return
	await _move_until(game, KEY_A, "castle_gate_center_lane", func(p: Vector3) -> bool: return p.x < 0.5, 6000)
	await _move_until(game, KEY_W, "castle_courtyard_door_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "gate_vargan_court", 10000)
	await _use_focused_interaction(game, "gate_vargan_court", "castle_courtyard_door")
	if not await _await_playable_zone(game, "vargan_court", "castle_courtyard_arrival"):
		return
	if not game.quests.is_objective_done("main_blood_under_stone", "enter_courtyard"):
		_fail("Real Castle door travel did not complete enter_courtyard")
		return
	await _move_until(game, KEY_A, "castle_guard_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "vargan_gate_guard", 5000)
	await _use_focused_interaction(game, "vargan_gate_guard", "castle_gate_guard")
	if not failures.is_empty():
		return
	if not game.quests.is_objective_done("main_blood_under_stone", "speak_guard"):
		_fail("Real guard conversation did not complete speak_guard")
		return
	await _move_until(game, KEY_D, "castle_notice_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "vargan_gate_notice", 6000)
	await _use_focused_interaction(game, "vargan_gate_notice", "castle_gate_notice")
	if not failures.is_empty():
		return
	if not game.quests.is_objective_done("main_blood_under_stone", "castle_evidence_ready"):
		_fail("Three physically inspected Castle clues did not complete evidence threshold")
		return
	print("REAL_INPUT castle_three_clues=PASS court=true guard=true evidence_ready=true")
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	if not bool(slot.get("ok", false)) or str(slot.get("data", {}).get("zone", "")) != "vargan_court":
		_fail("Real pause-menu save did not retain Castle courtyard evidence")
	else:
		print("REAL_INPUT castle_evidence_manual_save=PASS zone=vargan_court")

func _enter_record_hall(game: Node) -> void:
	if not game.quests.is_objective_done("main_blood_under_stone", "castle_evidence_ready"):
		_fail("Castle Continue lost the three-clue evidence threshold")
		return
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	if game.player.global_position.x > 0.5:
		await _move_until(game, KEY_A, "record_hall_center_lane", func(p: Vector3) -> bool: return p.x < 0.5, 5000)
	elif game.player.global_position.x < -0.5:
		await _move_until(game, KEY_D, "record_hall_center_lane", func(p: Vector3) -> bool: return p.x > -0.5, 5000)
	await _move_until(game, KEY_W, "record_hall_door_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "gate_record_hall", 14000)
	await _use_focused_interaction(game, "gate_record_hall", "record_hall_door")
	if not await _await_playable_zone(game, "record_hall", "record_hall_arrival"):
		return
	if not game.quests.is_objective_done("main_blood_under_stone", "locate_record_hall"):
		_fail("Real Record Hall entry did not complete locate_record_hall")
		return
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	if not bool(slot.get("ok", false)) or str(slot.get("data", {}).get("zone", "")) != "record_hall":
		_fail("Real pause-menu save did not retain Record Hall arrival")
	else:
		print("REAL_INPUT record_hall_manual_save=PASS zone=record_hall")
	if failures.is_empty() and "--castle-return-proof" in OS.get_cmdline_user_args():
		await _return_castle_composition_route(game)

func _return_castle_composition_route(game: Node) -> void:
	await _resume_saved_route(game)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_A, "record_hall_return_door", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "gate_vargan_court", 6000)
	await _use_focused_interaction(game, "gate_vargan_court", "record_hall_return")
	if not await _await_playable_zone(game, "vargan_court", "record_hall_return_court"):
		return
	await _turn_camera_north(game)
	# Walk through the supported central arch before turning into the west
	# return lane; this avoids both the existing corner tower and masonry wing.
	await _move_until(game, KEY_S, "courtyard_south_arch_crossing", func(p: Vector3) -> bool: return p.z > 16.25, 12000)
	await _move_until(game, KEY_A, "courtyard_outer_return_door", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "gate_vargan_approach", 7000)
	await _use_focused_interaction(game, "gate_vargan_approach", "castle_outer_return")
	if not await _await_playable_zone(game, "vargan_approach", "castle_outer_return_arrival"):
		return
	var slot := await _save_campaign_checkpoint(game)
	if bool(slot.get("ok", false)) and str(slot.get("data", {}).get("zone", "")) == "vargan_approach":
		print("REAL_INPUT castle_composition_return_save=PASS zone=vargan_approach")
	else:
		_fail("Castle return manual save lost its genuine arrival")

func _resolve_record_ledger(game: Node) -> void:
	var selected_flag := "vargan_ledger_hidden" if OS.get_cmdline_user_args().has("--ledger-hidden") else ("vargan_ledger_left_copied" if OS.get_cmdline_user_args().has("--ledger-copied") else "vargan_ledger_taken_openly")
	var choice := str({"vargan_ledger_hidden": "Hide the fragment", "vargan_ledger_left_copied": "Leave it and copy the seal", "vargan_ledger_taken_openly": "Take the fragment openly"}[selected_flag])
	if not game.quests.is_objective_done("main_blood_under_stone", "locate_record_hall") or bool(game.story_state.get_flag("vargan_ledger_choice_made", false)):
		_fail("Record Hall Continue did not restore the unresolved ledger beat")
		return
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_W, "record_ledger_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "vargan_ledger_choice", 12000)
	await _choose_focused_dialogue_action(game, "vargan_ledger_choice", choice, "record_ledger_choice")
	if not failures.is_empty():
		return
	if not bool(game.story_state.get_flag("vargan_ledger_choice_made", false)) or not game.quests.is_objective_done("main_blood_under_stone", "ledger_choice") or not game.quests.is_objective_done("main_blood_under_stone", "recover_ledger"):
		_fail("Real ledger E/Enter did not resolve the ledger decision")
		return
	for flag in ["vargan_ledger_hidden", "vargan_ledger_left_copied", "vargan_ledger_taken_openly"]:
		if bool(game.story_state.get_flag(flag, false)) != (flag == selected_flag):
			_fail("Ledger decision did not retain an exclusive %s outcome" % selected_flag)
			return
	if not await _await_playable_zone(game, "record_hall", "record_hall_after_ledger"):
		return
	var haunting_count := 0
	for enemy in game.active_enemies:
		if is_instance_valid(enemy) and str(enemy.get("enemy_id")) == "wychwood_stalker" and not enemy.dead:
			haunting_count += 1
	if haunting_count != 1:
		_fail("Ledger decision staged %d living Record Hall hauntings" % haunting_count)
		return
	print("REAL_INPUT record_ledger_haunting_staged=PASS choice=%s" % selected_flag)
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var flags: Dictionary = slot.get("data", {}).get("story_state", {}).get("flags", {})
	if not bool(slot.get("ok", false)) or not bool(flags.get("vargan_ledger_choice_made", false)) or not bool(flags.get(selected_flag, false)) or str(slot.get("data", {}).get("zone", "")) != "record_hall":
		_fail("Real pause-menu save lost the Record Hall ledger or encounter state")
	else:
		print("REAL_INPUT record_ledger_manual_save=PASS zone=record_hall")

func _fight_record_haunting(game: Node) -> void:
	if not bool(game.story_state.get_flag("vargan_ledger_choice_made", false)) or bool(game.story_state.get_flag("castle_haunting_cleared", false)):
		_fail("Record Hall Continue lost the unresolved haunting")
		return
	var enemy: Node3D = null
	for candidate in game.active_enemies:
		if is_instance_valid(candidate) and str(candidate.get("enemy_id")) == "wychwood_stalker" and not candidate.dead:
			if enemy != null:
				_fail("Record Hall Continue restored more than one haunting")
				return
			enemy = candidate
	if enemy == null:
		_fail("Record Hall Continue did not restore its haunting")
		return
	print("REAL_INPUT record_haunting_reload=PASS player=%s enemy=%s health=%.1f" % [game.player.global_position, enemy.global_position, game.player.health_component.health])
	_key(KEY_1, true)
	await _frames(2)
	_key(KEY_1, false)
	_key(KEY_T, true)
	await _frames(2)
	_key(KEY_T, false)
	await _frames(8)
	var deadline := Time.get_ticks_msec() + 50000
	var last_progress := Time.get_ticks_msec()
	var last_attack := 0
	var last_potion := 0
	var observed_health: float = enemy.health_component.health
	while Time.get_ticks_msec() < deadline:
		if bool(game.story_state.get_flag("castle_haunting_cleared", false)) and game.quests.is_objective_done("main_blood_under_stone", "survive_haunting"):
			if not await _await_playable_zone(game, "record_hall", "record_hall_after_haunting"):
				return
			print("REAL_INPUT record_haunting_defeat=PASS health=%.1f" % game.player.health_component.health)
			var slot := await _save_campaign_checkpoint(game)
			if not failures.is_empty():
				return
			var flags: Dictionary = slot.get("data", {}).get("story_state", {}).get("flags", {})
			if not bool(slot.get("ok", false)) or not bool(flags.get("castle_haunting_cleared", false)):
				_fail("Real pause-menu save lost the cleared Record Hall haunting")
			else:
				print("REAL_INPUT record_haunting_manual_save=PASS zone=record_hall")
			return
		if game.player.health_component.health <= 0.0 or not is_instance_valid(enemy):
			_fail("Haunting ended before quest completion; player_health=%.1f" % game.player.health_component.health)
			return
		if enemy.health_component.health < observed_health:
			observed_health = enemy.health_component.health
			last_progress = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_progress > 18000:
			_fail("Haunting combat stalled: player=%s enemy=%s enemy_health=%.1f" % [game.player.global_position, enemy.global_position, enemy.health_component.health])
			return
		if game.camera_rig.get_locked_combat_target() != enemy:
			_key(KEY_T, true)
			await _frames(2)
			_key(KEY_T, false)
			await _frames(6)
		var separation: Vector3 = enemy.global_position - game.player.global_position
		separation.y = 0.0
		var now := Time.get_ticks_msec()
		if game.player.health_component.health < 65.0 and int(game.inventory.items.get("redroot_potion", 0)) > 0 and now - last_potion > 5000:
			_key(KEY_R, true)
			await _frames(2)
			_key(KEY_R, false)
			last_potion = now
		else:
			last_attack = await _drive_contact_strike(game, enemy, last_attack, 420)
		await _frames(3)
	_fail("Real-input Record Hall haunting timed out")

func _confront_edric(game: Node) -> void:
	var outcome := "exposed" if OS.get_cmdline_user_args().has("--edric-exposed") else ("compelled" if OS.get_cmdline_user_args().has("--edric-compelled") else "cooperate")
	if not bool(game.story_state.get_flag("castle_haunting_cleared", false)) or not game.quests.is_objective_done("main_blood_under_stone", "survive_haunting"):
		_fail("Record Hall Continue lost the cleared haunting")
		return
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_D, "edric_east_of_archive_tables", func(p: Vector3) -> bool: return p.x > 3.25, 5000)
	await _move_until(game, KEY_W, "edric_north_of_ledger_table_sprint", func(p: Vector3) -> bool: return p.z < -10.3, 8000, true)
	# A transient edge-of-range focus during sprint braking is not arrival.
	# This north aisle is clear of the archive tables and away from the gate.
	await _move_until(game, KEY_A, "edric_conversation_approach", func(p: Vector3) -> bool: return p.x < 1.5, 6000)
	var choice := "Expose him now" if outcome == "exposed" else ("Compel a confession" if outcome == "compelled" else "Testify under protection")
	await _choose_focused_dialogue_action(game, "edric_campaign", choice, "edric_testimony")
	if not failures.is_empty():
		return
	if not game.quests.is_completed("main_blood_under_stone") or not game.quests.is_active("main_last_witness") or str(game.story_state.get_flag("edric_stance", "")) != outcome:
		_fail("Real Edric choice did not complete Blood Under Stone and begin The Last Witness")
		return
	print("REAL_INPUT edric_testimony=PASS stance=%s last_witness_active=true" % outcome)
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or str(saved.get("zone", "")) != "record_hall" or str(saved.get("story_state", {}).get("flags", {}).get("edric_stance", "")) != outcome:
		_fail("Real pause-menu save lost Edric's choice or Record Hall zone")
	else:
		print("REAL_INPUT edric_manual_save=PASS zone=record_hall stance=%s" % outcome)

func _enter_undercroft(game: Node) -> void:
	var expected_edric := "exposed" if OS.get_cmdline_user_args().has("--edric-exposed") else ("compelled" if OS.get_cmdline_user_args().has("--edric-compelled") else "cooperate")
	if not game.quests.is_completed("main_blood_under_stone") or not game.quests.is_active("main_last_witness") or str(game.story_state.get_flag("edric_stance", "")) != expected_edric:
		_fail("Record Hall Continue lost Edric's testimony or The Last Witness")
		return
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_D, "undercroft_door_east_lane", func(p: Vector3) -> bool: return p.x > 5.4, 5000)
	await _move_until(game, KEY_W, "undercroft_door_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_type == "zone" and game.active_interactable.zone_target == "undercroft", 6000)
	if not failures.is_empty():
		return
	_key(KEY_E, true)
	await _frames(3)
	_key(KEY_E, false)
	if not await _await_playable_zone(game, "undercroft", "undercroft_arrival"):
		return
	if not game.quests.is_objective_done("main_last_witness", "reach_undercroft"):
		_fail("Real undercroft entry did not complete reach_undercroft")
		return
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	if not bool(slot.get("ok", false)) or str(slot.get("data", {}).get("zone", "")) != "undercroft":
		_fail("Real pause-menu save did not retain undercroft arrival")
	else:
		print("REAL_INPUT undercroft_manual_save=PASS zone=undercroft")

func _break_halvern_guard(game: Node) -> void:
	if not game.quests.is_active("main_last_witness") or not game.quests.is_objective_done("main_last_witness", "reach_undercroft"):
		_fail("Undercroft Continue lost The Last Witness arrival")
		return
	var boss: Node3D = null
	for candidate in game.active_enemies:
		if is_instance_valid(candidate) and str(candidate.get("enemy_id")) == "halvern_boss" and not candidate.dead:
			if boss != null:
				_fail("Undercroft Continue restored multiple Halverns")
				return
			boss = candidate
	if boss == null:
		_fail("Undercroft Continue did not restore Halvern")
		return
	var audio_sync: Dictionary = {}
	if OS.get_cmdline_user_args().has("--audio-sync-combat"):
		audio_sync = _observe_enemy_audio_sync(game, [boss])
	print("REAL_INPUT halvern_reload=PASS player=%s boss=%s" % [game.player.global_position, boss.global_position])
	await _turn_camera_north(game)
	await _move_until(game, KEY_W, "halvern_duel_approach", func(p: Vector3) -> bool: return p.distance_to(boss.global_position) < 2.4, 10000)
	if not failures.is_empty():
		return
	var deadline := Time.get_ticks_msec() + 18000
	var parry_attempts := 0
	while Time.get_ticks_msec() < deadline and not bool(game.story_state.get_flag("halvern_guard_broken", false)):
		if game.player.health_component.health <= 0.0 or not is_instance_valid(boss) or boss.dead:
			_fail("Halvern duel ended before a real-input guard break")
			return
		if float(boss.get("pending_attack_time")) > 0.0 and float(boss.get("pending_attack_time")) < game.player.get_parry_window_duration() * 0.75:
			_key(KEY_Q, true)
			await _frames(2)
			_key(KEY_Q, false)
			parry_attempts += 1
			await _frames(8)
		else:
			await physics_frame
	if not bool(game.story_state.get_flag("halvern_guard_broken", false)) or not game.quests.is_objective_done("main_last_witness", "break_halvern_guard"):
		_fail("Real Q parry did not break Halvern's guard; attempts=%d player=%s boss=%s health=%.1f" % [parry_attempts, game.player.global_position, boss.global_position if is_instance_valid(boss) else Vector3.INF, game.player.health_component.health])
		return
	print("REAL_INPUT halvern_guard_parry=PASS attempts=%d health=%.1f" % [parry_attempts, game.player.health_component.health])
	if not audio_sync.is_empty():
		if audio_sync.windup == 0 or audio_sync.parry == 0:
			_fail("Halvern audio input coverage is incomplete: " + JSON.stringify(audio_sync))
		print("REAL_INPUT parry_audio_sync=%s %s" % ["PASS" if failures.is_empty() else "FAIL", JSON.stringify(audio_sync)])
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	if not bool(slot.get("ok", false)) or not bool(slot.get("data", {}).get("story_state", {}).get("flags", {}).get("halvern_guard_broken", false)):
		_fail("Real pause-menu save did not retain Halvern guard break")
	else:
		print("REAL_INPUT halvern_parry_manual_save=PASS zone=undercroft")

func _resolve_halvern_witness(game: Node) -> void:
	var outcome := "released" if OS.get_cmdline_user_args().has("--halvern-released") else ("destroyed" if OS.get_cmdline_user_args().has("--halvern-destroyed") else "witness")
	var choice := str({"witness": "Stand as the last witness", "released": "Tell me everything, then rest", "destroyed": "End the grave oath"}[outcome])
	if not game.quests.is_objective_done("main_last_witness", "break_halvern_guard") or not bool(game.story_state.get_flag("halvern_guard_broken", false)) or str(game.story_state.get_flag("halvern_fate", "")) != "":
		_fail("Undercroft Continue lost the unresolved parried-Halvern state")
		return
	var boss: Node3D = null
	for candidate in game.active_enemies:
		if is_instance_valid(candidate) and str(candidate.get("enemy_id")) == "halvern_boss" and not candidate.dead:
			if boss != null:
				_fail("Parry Continue restored multiple living Halverns")
				return
			boss = candidate
	if boss == null:
		_fail("Parry Continue removed undefeated Halvern before the witness decision")
		return
	print("REAL_INPUT halvern_post_parry_state=PASS player=%s boss=%s" % [game.player.global_position, boss.global_position])
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_D, "halvern_witness_east_lane", func(p: Vector3) -> bool: return p.x > 5.6, 6000)
	await _move_until(game, KEY_W, "halvern_witness_north_lane", func(p: Vector3) -> bool: return p.z < -8.0, 8500)
	await _move_until(game, KEY_A, "halvern_witness_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "halvern", 7000)
	await _choose_focused_dialogue_action(game, "halvern", choice, "halvern_witness_choice")
	if not failures.is_empty():
		return
	var controller: Node = boss.get_node_or_null("BossEncounterController") if is_instance_valid(boss) else null
	if str(game.story_state.get_flag("halvern_fate", "")) != outcome or not game.quests.is_completed("main_last_witness") or not game.quests.is_active("main_crowns_without_mercy") or controller == null or str(controller.get("outcome")) != outcome:
		_fail("Real Halvern dialogue did not resolve %s; fate=%s controller=%s" % [outcome, game.story_state.get_flag("halvern_fate", ""), controller.get("outcome") if controller != null else "none"])
		return
	if not bool(game.story_state.get_flag("boss_reward_sealed_testimony", false)) or not bool(game.story_state.get_flag("halvern_testimony_available", false)):
		_fail("Peaceful Halvern decision did not grant reward and aftermath")
		return
	print("REAL_INPUT halvern_witness_choice=PASS fate=%s crowns_active=true" % outcome)
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var flags: Dictionary = slot.get("data", {}).get("story_state", {}).get("flags", {})
	if not bool(slot.get("ok", false)) or str(flags.get("halvern_fate", "")) != outcome or not bool(flags.get("boss_reward_sealed_testimony", false)):
		_fail("Real pause-menu save lost peaceful Halvern outcome")
	else:
		print("REAL_INPUT halvern_witness_manual_save=PASS zone=undercroft")

func _travel_to_assembly(game: Node) -> void:
	var expected_halvern := "released" if OS.get_cmdline_user_args().has("--halvern-released") else ("destroyed" if OS.get_cmdline_user_args().has("--halvern-destroyed") else "witness")
	if str(game.story_state.get_flag("halvern_fate", "")) != expected_halvern or not game.quests.is_active("main_crowns_without_mercy"):
		_fail("Undercroft Continue lost Halvern testimony or assembly chapter")
		return
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_D, "assembly_gate_east_lane", func(p: Vector3) -> bool: return p.x > 5.5, 5000)
	await _move_until(game, KEY_W, "assembly_gate_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_type == "zone" and game.active_interactable.zone_target == "assembly", 7000)
	if not failures.is_empty():
		return
	_key(KEY_E, true)
	await _frames(3)
	_key(KEY_E, false)
	if not await _await_playable_zone(game, "assembly", "assembly_arrival"):
		return
	if not game.quests.is_objective_done("main_crowns_without_mercy", "greyfen_assembly"):
		_fail("Real assembly entry did not complete greyfen_assembly")
		return
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	if not bool(slot.get("ok", false)) or str(slot.get("data", {}).get("zone", "")) != "assembly":
		_fail("Real pause-menu save did not retain assembly arrival")
	else:
		print("REAL_INPUT assembly_manual_save=PASS zone=assembly")

func _hear_assembly_witnesses(game: Node) -> void:
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	for id in ["witness_-7", "witness_-3", "witness_3", "witness_7"]:
		var actor: Node3D = game.zone_root.get_node_or_null(id)
		if actor == null:
			_fail("Assembly witness is missing: " + id)
			return
		var meshes := actor.find_children("*", "MeshInstance3D", true, false)
		print("ASSEMBLY_WITNESS id=%s position=%s visible=%s skeletons=%d meshes=%d" % [id, actor.global_position, actor.is_visible_in_tree(), actor.find_children("*", "Skeleton3D", true, false).size(), meshes.size()])
		if id != "witness_7" and actor.find_children("*", "Skeleton3D", true, false).is_empty():
			_fail("Assembly human is a proxy: " + id)
			return
	await _move_until(game, KEY_W, "assembly_testimony_front_aisle", func(p: Vector3) -> bool: return p.z < -1.45, 11000)
	for witness in [["witness_3", 4.0, "Sister Anwen"], ["witness_-3", -4.0, "Rook"], ["witness_-7", -8.0, "Mira Fen"], ["witness_7", 8.0, "The Record"]]:
		if not failures.is_empty():
			return
		await _turn_camera_north(game)
		if game.player.global_position.z > -1.45:
			await _move_until(game, KEY_W, "testimony_front_aisle", func(p: Vector3) -> bool: return p.z < -1.45, 5000)
		elif game.player.global_position.z < -2.0:
			await _move_until(game, KEY_S, "testimony_front_aisle", func(p: Vector3) -> bool: return p.z > -1.6, 5000)
		var x: float = witness[1]
		var moving_right: bool = game.player.global_position.x < x
		await _move_until(game, KEY_D if moving_right else KEY_A, "testimony_" + witness[0], func(p: Vector3) -> bool: return p.x >= x if moving_right else p.x <= x, 10000)
		if not failures.is_empty():
			return
		await _use_focused_interaction(game, witness[0], "hear_" + witness[0], witness[2])
	await _turn_camera_north(game)
	await _move_until(game, KEY_A, "assembly_records_centre", func(p: Vector3) -> bool: return p.x < 0.1, 10000)

func _choose_assembly_testimony(game: Node) -> void:
	var outcome := "kael" if OS.get_cmdline_user_args().has("--assembly-kael") else ("edric" if OS.get_cmdline_user_args().has("--assembly-edric") else "witnesses")
	var choice := str({"witnesses": "Let every witness speak", "kael": "Read the names yourself", "edric": "Make Edric confess"}[outcome])
	if not failures.is_empty():
		return
	if not game.quests.is_active("main_crowns_without_mercy") or not game.quests.is_objective_done("main_crowns_without_mercy", "greyfen_assembly"):
		_fail("Assembly Continue lost the active chapter or assembly arrival")
		return
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_W, "assembly_witness_records_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "witnesses_ready", 10000)
	await _use_focused_interaction(game, "witnesses_ready", "assembly_witness_records")
	if not failures.is_empty():
		return
	if not game.quests.is_objective_done("main_crowns_without_mercy", "gather_witnesses"):
		_fail("Real E on witness records did not complete gather_witnesses")
		return
	# The record table begins at x=6.8; use the aisle inside its capsule margin.
	await _move_until(game, KEY_D, "assembly_dais_east_lane", func(p: Vector3) -> bool: return p.x > 5.5, 6500)
	await _move_until(game, KEY_W, "assembly_dais_north_lane", func(p: Vector3) -> bool: return p.z < -8.5, 6000)
	await _move_until(game, KEY_A, "assembly_choice_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "assembly_choice", 6500)
	await _choose_focused_dialogue_action(game, "assembly_choice", choice, "assembly_public_testimony")
	if not failures.is_empty():
		return
	if str(game.story_state.get_flag("confession_method", "")) != outcome or not game.quests.is_completed("main_crowns_without_mercy") or not game.quests.is_active("main_hart_remembers"):
		_fail("Real assembly choice did not start The Hart Remembers")
		return
	print("REAL_INPUT assembly_testimony_choice=PASS confession=%s hart_active=true" % outcome)
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	if not bool(slot.get("ok", false)) or str(slot.get("data", {}).get("story_state", {}).get("flags", {}).get("confession_method", "")) != outcome:
		_fail("Real pause-menu save lost the public testimony")
		return
	print("REAL_INPUT assembly_testimony_manual_save=PASS zone=assembly")
	_key(KEY_ESCAPE, true)
	await _frames(2)
	_key(KEY_ESCAPE, false)
	await _frames(5)
	if paused:
		_fail("Pause menu did not release gameplay after saving assembly testimony")
		return
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_D, "hart_gate_east_lane", func(p: Vector3) -> bool: return p.x > 6.7, 5000)
	await _move_until(game, KEY_W, "hart_gate_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_type == "zone" and game.active_interactable.zone_target == "hart_glade", 6500)
	if failures.is_empty():
		print("REAL_INPUT hart_gate_live_after_assembly=PASS")

func _travel_to_hart_glade(game: Node) -> void:
	var expected_assembly := "kael" if OS.get_cmdline_user_args().has("--assembly-kael") else ("edric" if OS.get_cmdline_user_args().has("--assembly-edric") else "witnesses")
	if str(game.story_state.get_flag("confession_method", "")) != expected_assembly or not game.quests.is_active("main_hart_remembers"):
		_fail("Assembly Continue lost the Hart chapter or public testimony")
		return
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_D, "hart_road_east_lane", func(p: Vector3) -> bool: return p.x > 6.7, 5500)
	await _move_until(game, KEY_W, "hart_road_gate_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_type == "zone" and game.active_interactable.zone_target == "hart_glade", 6000)
	if not failures.is_empty():
		return
	_key(KEY_E, true)
	await _frames(3)
	_key(KEY_E, false)
	if not await _await_playable_zone(game, "hart_glade", "hart_glade_arrival"):
		return
	if not game.quests.is_objective_done("main_hart_remembers", "enter_glade"):
		_fail("Real Hart Glade entry did not complete enter_glade")
		return
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	if not bool(slot.get("ok", false)) or str(slot.get("data", {}).get("zone", "")) != "hart_glade":
		_fail("Real pause-menu save did not retain Hart Glade arrival")
	else:
		print("REAL_INPUT hart_glade_manual_save=PASS zone=hart_glade")

func _resolve_hart_witness(game: Node, _choice_index: int = 0, covenant: String = "witness", ending_id: String = "expose") -> void:
	if OS.get_cmdline_user_args().has("--hart-aftermath-only"):
		await _verify_hart_aftermath_return(game, covenant)
		return
	if not game.quests.is_active("main_hart_remembers") or not game.quests.is_objective_done("main_hart_remembers", "enter_glade") or str(game.story_state.get_flag("final_covenant", "")) != "":
		_fail("Hart Glade Continue lost the unresolved finale")
		return
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_W, "hart_witness_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "white_hart", 13000)
	if not failures.is_empty():
		return
	_key(KEY_E, true)
	await _frames(3)
	_key(KEY_E, false)
	await _frames(6)
	if not game.hud.dialogue_layer.visible:
		_fail("Real E at the White Hart did not open the final dialogue")
		return
	for _page in range(24):
		if game.hud.dialogue_page_index >= game.hud.dialogue_pages.size() - 1:
			break
		_key(KEY_ENTER, true)
		await _frames(3)
		_key(KEY_ENTER, false)
		await _frames(5)
	for _choice in range(12):
		var focused := root.gui_get_focus_owner() as Button
		if focused != null and focused.text.begins_with(covenant.capitalize() + ":"):
			break
		_key(KEY_TAB, true)
		await _frames(2)
		_key(KEY_TAB, false)
		await _frames(3)
	var chosen := root.gui_get_focus_owner() as Button
	if chosen == null or not chosen.text.begins_with(covenant.capitalize() + ":"):
		_fail("Hart dialogue did not focus the %s ending; focus=%s" % [covenant, chosen.text if chosen != null else "none"])
		return
	_key(KEY_ENTER, true)
	await _frames(3)
	_key(KEY_ENTER, false)
	await _frames(8)
	if ending_id in ["bind", "kill"]:
		if str(game.story_state.get_flag("final_covenant", "")) != covenant or str(game.quests.world_flags.get("ending", "")) != ending_id or str(game.pending_ending) != ending_id:
			_fail("Hart %s choice did not start its promised combat" % covenant)
			return
		await _fight_hart_ending(game, covenant)
		if not failures.is_empty():
			return
	if game.hud.dialogue_layer.visible or str(game.story_state.get_flag("final_covenant", "")) != covenant or str(game.quests.world_flags.get("ending", "")) != ending_id or not game.quests.is_completed("main_hart_remembers") or not bool(game.story_state.get_flag("final_choice_completed", false)):
		_fail("Real Hart dialogue did not complete the %s ending" % covenant)
		return
	if not paused or not game.hud.menu_layer.visible:
		_fail("%s outcome did not show the ending menu" % covenant)
		return
	var cards: Variant = game.story_state.get_flag("epilogue_cards", [])
	if not cards is Array or cards.is_empty():
		_fail("%s ending did not produce epilogue cards" % covenant)
		return
	print("REAL_INPUT hart_%s_ending=PASS cards=%d" % [covenant, cards.size()])
	var checkpoint: Dictionary = game.save_manager._read_slot(game.save_manager.CHECKPOINT_PATH)
	var flags: Dictionary = checkpoint.get("data", {}).get("story_state", {}).get("flags", {})
	if not bool(checkpoint.get("ok", false)) or str(flags.get("final_covenant", "")) != covenant or not bool(flags.get("final_choice_completed", false)):
		_fail("%s ending checkpoint did not retain final covenant" % covenant)
	else:
		print("REAL_INPUT hart_%s_checkpoint=PASS zone=hart_glade" % covenant)

func _verify_hart_aftermath_return(game: Node, covenant: String) -> void:
	if str(game.story_state.get_flag("final_covenant", "")) != covenant or not bool(game.story_state.get_flag("final_choice_completed", false)) or not game.quests.is_completed("main_hart_remembers"):
		_fail("Aftermath Continue is not the earned completed covenant")
		return
	var seal := game.zone_root.get_node_or_null("HartAftermathSeal") as MeshInstance3D
	if seal == null or seal.mesh.get_meta("covenant", "") != covenant or game.zone_root.find_child("white_hart", true, false) != null or not game.active_enemies.is_empty():
		_fail("Completed covenant did not restore its quiet authored aftermath")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_W, "hart_memorial_approach", func(p: Vector3) -> bool: return p.z < -8.7, 7000)
	if not failures.is_empty():
		return
	await RenderingServer.frame_post_draw
	var path := "user://hart_aftermath_%s_gameplay.png" % covenant
	if root.get_texture().get_image().save_png(path) != OK:
		_fail("Actual memorial approach capture failed")
		return
	print("REAL_INPUT hart_aftermath_approach=PASS covenant=%s capture=%s" % [covenant, ProjectSettings.globalize_path(path)])
	# Return along the clear central aisle before moving west to the gate;
	# ritual stones and trees occupy both lateral arena edges.
	await _move_until(game, KEY_S, "hart_memorial_south_return", func(p: Vector3) -> bool: return p.z > 12.0, 13000)
	await _move_until(game, KEY_A, "hart_memorial_return_gate_lane", func(p: Vector3) -> bool: return p.x < -6.8, 6000)
	await _turn_camera_south(game)
	await _move_until(game, KEY_W, "hart_memorial_return_focus", func(_p: Vector3) -> bool: return is_instance_valid(game.active_interactable) and game.active_interactable.zone_target == "assembly", 6000)
	if not failures.is_empty():
		return
	await _use_focused_interaction(game, "gate_assembly", "hart_aftermath_return")
	if not await _await_playable_zone(game, "assembly", "hart_aftermath_assembly"):
		return
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var flags: Dictionary = slot.get("data", {}).get("story_state", {}).get("flags", {})
	if not bool(slot.get("ok", false)) or slot.get("data", {}).get("zone", "") != "assembly" or flags.get("final_covenant", "") != covenant or not bool(flags.get("final_choice_completed", false)):
		_fail("Real return/manual save lost the completed covenant")
	else:
		print("REAL_INPUT hart_aftermath_return_save=PASS covenant=%s zone=assembly" % covenant)

func _fight_hart_ending(game: Node, covenant: String) -> void:
	var boss: Node3D = null
	for candidate in game.active_enemies:
		if is_instance_valid(candidate) and str(candidate.get("enemy_id")) == "white_hart_avatar" and not candidate.dead:
			if boss != null:
				_fail("Hart %s choice staged multiple living avatars" % covenant)
				return
			boss = candidate
	if boss == null:
		_fail("Hart %s choice did not stage the avatar" % covenant)
		return
	print("REAL_INPUT hart_%s_combat_started=PASS boss=%s health=%.1f" % [covenant, boss.global_position, boss.health_component.health])
	_key(KEY_1, true)
	await _frames(2)
	_key(KEY_1, false)
	_key(KEY_T, true)
	await _frames(2)
	_key(KEY_T, false)
	await _frames(8)
	var deadline := Time.get_ticks_msec() + 60000
	var last_attack := 0
	var last_potion := 0
	var observed_health: float = boss.health_component.health
	var last_progress := Time.get_ticks_msec()
	while Time.get_ticks_msec() < deadline:
		if bool(game.story_state.get_flag("final_choice_completed", false)):
			print("REAL_INPUT hart_%s_combat_defeat=PASS boss_health=%.1f player_health=%.1f" % [covenant, boss.health_component.health if is_instance_valid(boss) else 0.0, game.player.health_component.health])
			return
		if game.player.health_component.health <= 0.0 or not is_instance_valid(boss):
			_fail("Hart %s fight ended before the covenant resolved; player_health=%.1f" % [covenant, game.player.health_component.health])
			return
		if boss.health_component.health < observed_health:
			observed_health = boss.health_component.health
			last_progress = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_progress > 15000:
			_fail("Hart %s fight stalled; player=%s boss=%s health=%.1f" % [covenant, game.player.global_position, boss.global_position, boss.health_component.health])
			return
		if game.camera_rig.get_locked_combat_target() != boss:
			_key(KEY_T, true)
			await _frames(2)
			_key(KEY_T, false)
			await _frames(5)
		var now := Time.get_ticks_msec()
		var distance: float = game.player.global_position.distance_to(boss.global_position)
		if game.player.health_component.health < 65.0 and int(game.inventory.items.get("redroot_potion", 0)) > 0 and now - last_potion > 5000:
			_key(KEY_R, true)
			await _frames(2)
			_key(KEY_R, false)
			last_potion = now
		elif distance > 2.1:
			_key(KEY_W, true)
			await _frames(7)
			_key(KEY_W, false)
		elif float(boss.get("pending_attack_time")) > 0.0 and float(boss.get("pending_attack_time")) < game.player.get_parry_window_duration() * 0.75:
			_key(KEY_Q, true)
			await _frames(2)
			_key(KEY_Q, false)
		elif now - last_attack > 420:
			_mouse_button(MOUSE_BUTTON_LEFT, true)
			await _frames(2)
			_mouse_button(MOUSE_BUTTON_LEFT, false)
			last_attack = now
		await _frames(3)
	_fail("Hart %s fight exceeded its 60-second real-input deadline" % covenant)

func _complete_widows_bell(game: Node) -> void:
	if OS.get_cmdline_user_args().has("--side-alternative"):
		if not game.quests.is_active("side_widows_bell") or game.quests.is_objective_done("side_widows_bell", "find_bell") or str(game.story_state.get_flag("widow_truth", "")) != "":
			_fail("Widow alternative requires genuine active pre-clue save")
			return
		await _resolve_widows_bell(game, "comforted")
		return
	if not game.quests.is_unlocked("side_widows_bell") or game.quests.is_active("side_widows_bell") or game.quests.is_completed("side_widows_bell"):
		_fail("Greyfen Continue did not retain an available Widow's Bell contract")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_A, "widow_bridge_centerline", func(p: Vector3) -> bool: return p.x < 0.45, 7000)
	await _move_until(game, KEY_S, "widow_south_bank", func(p: Vector3) -> bool: return p.z > 9.2, 9000)
	await _move_until(game, KEY_D, "widow_cemetery_lane", func(p: Vector3) -> bool: return p.x > 9.0, 7000)
	await _move_until(game, KEY_W, "widow_north_approach", func(p: Vector3) -> bool: return p.z < 8.3, 4000)
	await _move_until(game, KEY_D, "widow_elna_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "widow_elna", 7000)
	await _use_focused_interaction(game, "widow_elna", "widow_accept_contract")
	if not failures.is_empty():
		return
	if not game.quests.is_active("side_widows_bell"):
		_fail("Elna's real dialogue did not start A Widow's Bell")
		return
	print("REAL_INPUT widow_contract=PASS")
	await _resolve_widows_bell(game, "told")

func _resolve_widows_bell(game: Node, outcome: String) -> void:
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_D, "widow_bell_east_lane", func(p: Vector3) -> bool: return p.x > 14.0, 6000)
	await _move_until(game, KEY_S, "widow_bell_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "grave_bell", 6000)
	await _use_focused_interaction(game, "grave_bell", "widow_bell_clue")
	if not failures.is_empty():
		return
	if not game.quests.is_objective_done("side_widows_bell", "find_bell"):
		_fail("Harl's focused bell did not complete the side-quest clue")
		return
	await _move_until(game, KEY_A, "widow_return_west", func(p: Vector3) -> bool: return p.x < 13.0, 5000)
	await _move_until(game, KEY_W, "widow_return_north", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "widow_elna", 5000)
	if outcome == "comforted":
		await _choose_focused_dialogue_action(game, "widow_elna", "The wind caught an old cord", "widow_comfort_choice")
	else:
		await _use_focused_interaction(game, "widow_elna", "widow_truth_choice")
	if not failures.is_empty():
		return
	if not game.quests.is_completed("side_widows_bell") or str(game.story_state.get_flag("widow_truth", "")) != outcome:
		_fail("Elna's real dialogue did not settle the truthful Widow's Bell outcome")
		return
	print("REAL_INPUT widow_truth_choice=PASS")
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var saved: Dictionary = slot.get("data", {})
	var saved_flags: Dictionary = saved.get("story_state", {}).get("flags", {})
	if not bool(slot.get("ok", false)) or not saved.get("quests", {}).get("completed", {}).has("side_widows_bell") or str(saved_flags.get("widow_truth", "")) != outcome:
		_fail("Manual save did not preserve Widow's Bell completion and truth choice")
	else:
		print("REAL_INPUT widow_manual_save=PASS zone=greyfen outcome=%s" % outcome)

func _complete_iron_remembers(game: Node) -> void:
	if OS.get_cmdline_user_args().has("--side-alternative"):
		if not game.quests.is_active("side_iron_remembers") or game.quests.is_objective_done("side_iron_remembers", "recover_iron") or str(game.story_state.get_flag("iron_fate", "")) != "":
			_fail("Iron alternative requires genuine active pre-clue save")
			return
		await _resolve_iron_remembers(game, "weapon")
		return
	if not game.quests.is_unlocked("side_iron_remembers") or game.quests.is_active("side_iron_remembers") or game.quests.is_completed("side_iron_remembers"):
		_fail("Greyfen Continue did not retain an available Iron Remembers contract")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_A, "iron_bridge_centerline", func(p: Vector3) -> bool: return p.x < 0.45, 7000)
	await _move_until(game, KEY_S, "iron_south_bank", func(p: Vector3) -> bool: return p.z > 9.2, 9000)
	await _move_until(game, KEY_A, "iron_request_board", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "side_contracts", 6000)
	await _choose_focused_dialogue_action(game, "side_contracts", "Iron Remembers", "iron_request")
	if not failures.is_empty():
		return
	if not game.quests.is_active("side_iron_remembers"):
		_fail("Village request board did not start Iron Remembers")
		return
	print("REAL_INPUT iron_contract=PASS")
	await _resolve_iron_remembers(game, "memorial")

func _resolve_iron_remembers(game: Node, outcome: String) -> void:
	await _turn_camera_north(game)
	await _move_until(game, KEY_D, "iron_cemetery_west_lane", func(p: Vector3) -> bool: return p.x > 9.0, 8000)
	await _move_until(game, KEY_W, "iron_cemetery_clear_lane", func(p: Vector3) -> bool: return p.z < 8.3, 5000)
	await _move_until(game, KEY_D, "iron_chapel_east_lane", func(p: Vector3) -> bool: return p.x > 14.0, 6000)
	await _move_until(game, KEY_S, "iron_chapel_clue", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "massacre_iron", 6000)
	await _use_focused_interaction(game, "massacre_iron", "iron_chapel_evidence")
	if not failures.is_empty():
		return
	if not game.quests.is_objective_done("side_iron_remembers", "recover_iron"):
		_fail("Focused chapel iron did not complete recover_iron")
		return
	print("REAL_INPUT iron_chapel_evidence=PASS")
	await _move_until(game, KEY_W, "iron_return_clear_lane", func(p: Vector3) -> bool: return p.z < 8.3, 5000)
	await _move_until(game, KEY_A, "iron_return_bridge_lane", func(p: Vector3) -> bool: return p.x < 0.45, 8000)
	await _move_until(game, KEY_W, "iron_return_north_bank", func(p: Vector3) -> bool: return p.z < -4.3, 9000)
	await _move_until(game, KEY_D, "iron_forge_east_lane", func(p: Vector3) -> bool: return p.x > 10.0, 7000)
	await _turn_camera_south(game)
	await _move_until(game, KEY_W, "iron_tor_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "blacksmith_tor", 6000)
	var choice := "Forge it into a weapon" if outcome == "weapon" else "Forge the victims' names"
	await _choose_focused_dialogue_action(game, "blacksmith_tor", choice, "iron_choice")
	if not failures.is_empty():
		return
	if not game.quests.is_completed("side_iron_remembers") or str(game.story_state.get_flag("iron_fate", "")) != outcome:
		_fail("Tor's real dialogue did not settle the memorial outcome")
		return
	print("REAL_INPUT iron_choice=PASS outcome=%s" % outcome)
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or not saved.get("quests", {}).get("completed", {}).has("side_iron_remembers") or str(saved.get("story_state", {}).get("flags", {}).get("iron_fate", "")) != outcome:
		_fail("Manual save did not preserve Iron Remembers and Tor's memorial")
	else:
		print("REAL_INPUT iron_manual_save=PASS zone=greyfen outcome=%s" % outcome)

func _complete_empty_grave(game: Node) -> void:
	if OS.get_cmdline_user_args().has("--side-alternative"):
		if not game.quests.is_active("side_empty_grave") or game.quests.is_objective_done("side_empty_grave", "follow_empty_grave") or str(game.story_state.get_flag("returned_soldier_fate", "")) != "":
			_fail("Empty Grave alternative requires genuine active pre-clue save")
			return
		await _resolve_empty_grave(game, "anonymous")
		return
	if not game.quests.is_unlocked("side_empty_grave") or game.quests.is_active("side_empty_grave") or game.quests.is_completed("side_empty_grave"):
		_fail("Greyfen Continue did not retain an available Empty Grave contract")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_A, "empty_bridge_centerline", func(p: Vector3) -> bool: return p.x < 0.45, 7000)
	await _move_until(game, KEY_S, "empty_south_bank", func(p: Vector3) -> bool: return p.z > 9.2, 9000)
	await _move_until(game, KEY_A, "empty_request_board", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "side_contracts", 6000)
	await _choose_focused_dialogue_action(game, "side_contracts", "The Man Who Walked Home", "empty_request")
	if not failures.is_empty():
		return
	if not game.quests.is_active("side_empty_grave"):
		_fail("Village request board did not start The Man Who Walked Home")
		return
	print("REAL_INPUT empty_contract=PASS")
	await _resolve_empty_grave(game, "named")

func _resolve_empty_grave(game: Node, outcome: String) -> void:
	await _turn_camera_north(game)
	await _move_until(game, KEY_D, "empty_cemetery_west_lane", func(p: Vector3) -> bool: return p.x > 9.0, 8000)
	await _move_until(game, KEY_W, "empty_cemetery_clear_lane", func(p: Vector3) -> bool: return p.z < 8.3, 5000)
	await _move_until(game, KEY_D, "empty_grave_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "empty_grave_tracks", 7000)
	await _use_focused_interaction(game, "empty_grave_tracks", "empty_grave_clue")
	if not failures.is_empty():
		return
	if not game.quests.is_objective_done("side_empty_grave", "follow_empty_grave"):
		_fail("Focused empty-grave tracks did not complete the side-quest clue")
		return
	print("REAL_INPUT empty_grave_clue=PASS")
	var publication_deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < publication_deadline and game.zone_root.find_child("returned_soldier", true, false) == null:
		await process_frame
	if game.zone_root.find_child("returned_soldier", true, false) == null:
		_fail("Returned soldier was not published after the real grave clue")
		return
	await _move_until(game, KEY_A, "empty_soldier_east_lane", func(p: Vector3) -> bool: return p.x < 12.0, 6000)
	await _turn_camera_south(game)
	await _move_until(game, KEY_W, "empty_soldier_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "returned_soldier", 6000)
	var choice := "Keep the name. Leave the grave empty" if outcome == "anonymous" else "Your name belongs among the witnesses"
	await _choose_focused_dialogue_action(game, "returned_soldier", choice, "empty_soldier_choice")
	if not failures.is_empty():
		return
	if not game.quests.is_completed("side_empty_grave") or str(game.story_state.get_flag("returned_soldier_fate", "")) != outcome:
		_fail("Returned soldier dialogue did not settle the named-witness outcome")
		return
	print("REAL_INPUT empty_soldier_choice=PASS")
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or not saved.get("quests", {}).get("completed", {}).has("side_empty_grave") or str(saved.get("story_state", {}).get("flags", {}).get("returned_soldier_fate", "")) != outcome:
		_fail("Manual save did not preserve returned-soldier testimony")
	else:
		print("REAL_INPUT empty_soldier_manual_save=PASS zone=greyfen outcome=%s" % outcome)

func _complete_bitter_roots(game: Node) -> void:
	if OS.get_cmdline_user_args().has("--continue-side-bitter-kept"):
		await _resolve_bitter_kept(game)
		return
	if not game.quests.is_unlocked("side_bitter_roots") or game.quests.is_active("side_bitter_roots") or game.quests.is_completed("side_bitter_roots"):
		_fail("Greyfen Continue did not retain an available Bitter Roots contract")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_A, "bitter_bridge_centerline", func(p: Vector3) -> bool: return p.x < 0.45, 7000)
	await _move_until(game, KEY_S, "bitter_south_bank", func(p: Vector3) -> bool: return p.z > 9.2, 9000)
	await _move_until(game, KEY_A, "bitter_request_board", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "side_contracts", 6000)
	await _choose_focused_dialogue_action(game, "side_contracts", "Bitter Roots", "bitter_request")
	if not failures.is_empty():
		return
	if not game.quests.is_active("side_bitter_roots"):
		_fail("Village request board did not start Bitter Roots")
		return
	print("REAL_INPUT bitter_contract=PASS")
	await _turn_camera_north(game)
	await _move_until(game, KEY_D, "bitter_return_centerline", func(p: Vector3) -> bool: return p.x > -0.25, 6000)
	_key(KEY_W, true)
	var travel_deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < travel_deadline and game.current_zone_id != "wychwood":
		await physics_frame
	_key(KEY_W, false)
	if not await _await_playable_zone(game, "wychwood", "bitter_wychwood_arrival"):
		return
	await _move_until(game, KEY_W, "bitter_wychwood_north_bank", func(p: Vector3) -> bool: return p.z < -2.8, 7000)
	await _move_until(game, KEY_D, "bitter_roots_east_path", func(p: Vector3) -> bool: return p.x > 7.3, 6000)
	await _move_until(game, KEY_W, "bitter_roots_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "bitter_roots", 7000)
	await _use_focused_interaction(game, "bitter_roots", "bitter_roots_clue")
	if not failures.is_empty():
		return
	if not game.quests.is_objective_done("side_bitter_roots", "collect_roots"):
		_fail("Focused Wychwood roots did not complete the collection objective")
		return
	print("REAL_INPUT bitter_roots_clue=PASS")
	await _move_until(game, KEY_S, "bitter_return_north_bank", func(p: Vector3) -> bool: return p.z > -3.7, 7000)
	await _move_until(game, KEY_A, "bitter_return_bridge_lane", func(p: Vector3) -> bool: return p.x < 0.35, 8000)
	await _move_until(game, KEY_S, "bitter_return_greyfen", func(_p: Vector3) -> bool: return game.current_zone_id == "greyfen", 10000)
	if not await _await_playable_zone(game, "greyfen", "bitter_greyfen_arrival"):
		return
	await _move_until(game, KEY_S, "bitter_mira_south_lane", func(p: Vector3) -> bool: return p.z > 0.8, 7000)
	await _move_until(game, KEY_A, "bitter_mira_west_lane", func(p: Vector3) -> bool: return p.x < -5.8, 7000)
	await _move_until(game, KEY_W, "bitter_mira_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "mira", 6000)
	await _choose_focused_dialogue_action(game, "mira", "Greyfen deserves the truth", "bitter_mira_choice")
	if not failures.is_empty():
		return
	if not game.quests.is_completed("side_bitter_roots") or str(game.story_state.get_flag("mira_truth", "")) != "confessed":
		_fail("Mira's real dialogue did not settle the confessed Bitter Roots outcome")
		return
	print("REAL_INPUT bitter_mira_choice=PASS")
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or not saved.get("quests", {}).get("completed", {}).has("side_bitter_roots") or str(saved.get("story_state", {}).get("flags", {}).get("mira_truth", "")) != "confessed":
		_fail("Manual save did not preserve Bitter Roots confession")
	else:
		print("REAL_INPUT bitter_manual_save=PASS zone=greyfen")

func _resolve_bitter_kept(game: Node) -> void:
	if not game.quests.is_active("side_bitter_roots") or not game.quests.is_objective_done("side_bitter_roots", "collect_roots") or str(game.story_state.get_flag("mira_truth", "")) != "":
		_fail("Bitter Roots alternative requires genuine collected, unresolved evidence")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_S, "bitter_kept_south_lane", func(p: Vector3) -> bool: return p.z > 0.8, 9000)
	await _move_until(game, KEY_A, "bitter_kept_west_lane", func(p: Vector3) -> bool: return p.x < -5.8, 7000)
	await _move_until(game, KEY_W, "bitter_kept_mira", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "mira", 6000)
	await _choose_focused_dialogue_action(game, "mira", "Keep the truth between us", "bitter_kept_choice")
	if not failures.is_empty():
		return
	if not game.quests.is_completed("side_bitter_roots") or str(game.story_state.get_flag("mira_truth", "")) != "kept":
		_fail("Mira's real dialogue did not preserve the private Bitter Roots outcome")
		return
	var slot := await _save_campaign_checkpoint(game)
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or not saved.get("quests", {}).get("completed", {}).has("side_bitter_roots") or str(saved.get("story_state", {}).get("flags", {}).get("mira_truth", "")) != "kept":
		_fail("Manual save did not preserve private Bitter Roots outcome")
	else:
		print("REAL_INPUT bitter_kept_manual_save=PASS zone=greyfen")

func _complete_black_dog(game: Node) -> void:
	if OS.get_cmdline_user_args().has("--continue-side-black-dog-hidden"):
		if not game.quests.is_active("side_black_dog") or not game.quests.is_objective_done("side_black_dog", "find_dog") or str(game.story_state.get_flag("black_dog_fate", "")) != "":
			_fail("Black Dog alternative requires genuine investigated, unresolved evidence")
			return
		await _turn_camera_north(game)
		await _report_black_dog(game, "hidden")
		return
	if not game.quests.is_unlocked("side_black_dog") or game.quests.is_active("side_black_dog") or game.quests.is_completed("side_black_dog"):
		_fail("Greyfen Continue did not retain an available Black Dog contract")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_A, "black_dog_bridge_centerline", func(p: Vector3) -> bool: return p.x < 0.45, 7000)
	await _move_until(game, KEY_S, "black_dog_south_bank", func(p: Vector3) -> bool: return p.z > 9.2, 9000)
	await _move_until(game, KEY_A, "black_dog_request_board", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "side_contracts", 6000)
	await _choose_focused_dialogue_action(game, "side_contracts", "The Black Dog Contract", "black_dog_request")
	if not failures.is_empty():
		return
	if not game.quests.is_active("side_black_dog"):
		_fail("Village request board did not start The Black Dog Contract")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_D, "black_dog_return_centerline", func(p: Vector3) -> bool: return p.x > -0.25, 6000)
	await _move_until(game, KEY_W, "black_dog_north_bank", func(p: Vector3) -> bool: return p.z < -3.0, 9000)
	await _move_until(game, KEY_W, "black_dog_north_path", func(p: Vector3) -> bool: return p.z < -7.0, 6000)
	await _move_until(game, KEY_W, "black_dog_shrine_back_path", func(p: Vector3) -> bool: return p.z < -12.2, 6000)
	await _move_until(game, KEY_D, "black_dog_fence_gap", func(p: Vector3) -> bool: return p.x > 10.9, 9000)
	await _move_until(game, KEY_D, "black_dog_sheepfold_east", func(p: Vector3) -> bool: return p.x > 14.2, 5000)
	await _turn_camera_south(game)
	await _move_until(game, KEY_W, "black_dog_sheepfold_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "sheepfold", 5000)
	await _use_focused_interaction(game, "sheepfold", "black_dog_sheepfold")
	if not failures.is_empty():
		return
	if game.quests.is_objective_done("side_black_dog", "find_dog"):
		_fail("Sheepfold alone prematurely completed the Black Dog investigation")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_S, "black_dog_back_path", func(p: Vector3) -> bool: return p.z > -12.2, 4000)
	await _move_until(game, KEY_A, "black_dog_wychwood_centerline", func(p: Vector3) -> bool: return p.x < 0.4, 10000)
	await _move_until(game, KEY_W, "black_dog_wychwood_travel", func(_p: Vector3) -> bool: return game.current_zone_id == "wychwood", 12000)
	if not await _await_playable_zone(game, "wychwood", "black_dog_wychwood_arrival"):
		return
	var bandits := 0
	for candidate in game.active_enemies:
		if is_instance_valid(candidate) and candidate.enemy_id == "bandit" and not candidate.dead:
			bandits += 1
	if bandits != 2 or game.quests.is_objective_done("side_black_dog", "find_dog"):
		_fail("Wychwood did not stage two bandits before Black Dog investigation; bandits=%d" % bandits)
		return
	print("REAL_INPUT black_dog_encounter_staged=PASS bandits=2")
	await _move_until(game, KEY_W, "black_dog_wychwood_north_bank", func(p: Vector3) -> bool: return p.z < -4.0, 7000)
	await _move_until(game, KEY_A, "black_dog_camp_west_lane", func(p: Vector3) -> bool: return p.x < -10.8, 9000)
	await _move_until(game, KEY_W, "black_dog_camp_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "bandit_camp", 7000)
	await _use_focused_interaction(game, "bandit_camp", "black_dog_camp")
	if not failures.is_empty():
		return
	if game.quests.is_objective_done("side_black_dog", "find_dog"):
		_fail("Camp evidence alone prematurely completed the Black Dog investigation")
		return
	_key(KEY_1, true)
	await _frames(2)
	_key(KEY_1, false)
	var deadline := Time.get_ticks_msec() + 90000
	var last_attack := 0
	var last_potion := 0
	var last_progress := Time.get_ticks_msec()
	var observed_health := INF
	while Time.get_ticks_msec() < deadline and not game.quests.is_objective_done("side_black_dog", "find_dog"):
		if game.player.health_component.health <= 0.0:
			_fail("Kael died during the Black Dog bandit encounter")
			return
		var enemy: Node3D = null
		for candidate in game.active_enemies:
			if is_instance_valid(candidate) and candidate.enemy_id == "bandit" and not candidate.dead:
				enemy = candidate
				break
		if enemy == null:
			await _frames(5)
			continue
		if enemy.health_component.health < observed_health:
			observed_health = enemy.health_component.health
			last_progress = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_progress > 22000:
			_fail("Black Dog combat stalled: player=%s enemy=%s health=%.1f" % [game.player.global_position, enemy.global_position, enemy.health_component.health])
			return
		if game.camera_rig.get_locked_combat_target() != enemy:
			if game.camera_rig.get_locked_combat_target() != null:
				_key(KEY_T, true)
				await _frames(2)
				_key(KEY_T, false)
				await _frames(3)
			_key(KEY_T, true)
			await _frames(2)
			_key(KEY_T, false)
			await _frames(8)
		var separation: Vector3 = enemy.global_position - game.player.global_position
		separation.y = 0.0
		last_attack = await _drive_contact_strike(game, enemy, last_attack, 430)
		if game.player.health_component.health < 65.0 and Time.get_ticks_msec() - last_potion > 6000:
			_key(KEY_R, true)
			await _frames(2)
			_key(KEY_R, false)
			last_potion = Time.get_ticks_msec()
		await _frames(3)
	if not game.quests.is_objective_done("side_black_dog", "find_dog"):
		_fail("Black Dog investigation did not complete after both bandits fell")
		return
	print("REAL_INPUT black_dog_bandits=PASS")
	if game.camera_rig.get_locked_combat_target() != null:
		_key(KEY_T, true)
		await _frames(2)
		_key(KEY_T, false)
	await _turn_camera_north(game)
	await _move_until(game, KEY_W, "black_dog_clear_return_tree", func(p: Vector3) -> bool: return p.z < -7.2, 5000)
	await _move_until(game, KEY_D, "black_dog_return_inner_lane", func(p: Vector3) -> bool: return p.x > -5.8, 6000)
	await _move_until(game, KEY_S, "black_dog_return_north_bank", func(p: Vector3) -> bool: return p.z > -3.7, 7000)
	await _move_until(game, KEY_D, "black_dog_return_bridge_lane", func(p: Vector3) -> bool: return p.x > -0.35, 9000)
	await _move_until(game, KEY_S, "black_dog_return_greyfen", func(_p: Vector3) -> bool: return game.current_zone_id == "greyfen", 10000)
	if not await _await_playable_zone(game, "greyfen", "black_dog_greyfen_arrival"):
		return
	await _report_black_dog(game, "spared")

func _report_black_dog(game: Node, outcome: String) -> void:
	await _move_until(game, KEY_D, "black_dog_toma_east_lane", func(p: Vector3) -> bool: return p.x > 11.5, 9000)
	await _turn_camera_south(game)
	var toma: Area3D = game.zone_root.find_child("farmer_toma", true, false) as Area3D
	var toma_deadline := Time.get_ticks_msec() + 5000
	while toma == null and Time.get_ticks_msec() < toma_deadline:
		await process_frame
		toma = game.zone_root.find_child("farmer_toma", true, false) as Area3D
	if toma == null:
		_fail("Toma did not publish in Greyfen after the Black Dog return")
		return
	print("REAL_INPUT black_dog_toma_published=PASS position=%s distance=%.2f visible=%s" % [toma.global_position, toma.global_position.distance_to(game.player.global_position), game.call("_interaction_target_valid", toma)])
	await _move_until(game, KEY_W, "black_dog_toma_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "farmer_toma", 9000)
	var choice := "Tell them it fled" if outcome == "hidden" else "The guardian protected the children"
	await _choose_focused_dialogue_action(game, "farmer_toma", choice, "black_dog_toma_choice")
	if not failures.is_empty():
		return
	if not game.quests.is_completed("side_black_dog") or str(game.story_state.get_flag("black_dog_fate", "")) != outcome:
		_fail("Toma's real dialogue did not resolve the guardian outcome")
		return
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or not saved.get("quests", {}).get("completed", {}).has("side_black_dog") or str(saved.get("story_state", {}).get("flags", {}).get("black_dog_fate", "")) != outcome:
		_fail("Manual save did not preserve the Black Dog guardian outcome")
	else:
		print("REAL_INPUT black_dog_manual_save=PASS zone=greyfen outcome=%s" % outcome)

func _complete_oren_red_thread(game: Node) -> void:
	if not bool(game.story_state.get_flag("chapel_names_read", false)) or not bool(game.story_state.get_flag("oren_name_spoken", false)):
		_fail("Genuine Greyfen save lacks the two Oren evidence beats")
		return
	if game.quests.is_active("side_childs_charm") or game.quests.is_completed("side_childs_charm"):
		_fail("Oren's Red Thread was already started in the source save")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_A, "oren_bridge_centerline", func(p: Vector3) -> bool: return p.x < 0.45, 7000)
	await _move_until(game, KEY_S, "oren_south_bank", func(p: Vector3) -> bool: return p.z > 9.2, 9000)
	await _move_until(game, KEY_A, "oren_request_board", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "side_contracts", 6000)
	await _choose_focused_dialogue_action(game, "side_contracts", "Oren's Red Thread", "oren_request")
	if not failures.is_empty():
		return
	if not game.quests.is_active("side_childs_charm") or not game.quests.is_objective_done("side_childs_charm", "trace_thread"):
		_fail("Oren's request did not recognize the already witnessed thread and chapel evidence")
		return
	var charm := game.zone_root.find_child("oren_charm_shrine", true, false) as Area3D
	if charm == null:
		_fail("Oren's charm clue was not published by the rebuilt Greyfen zone; active=%s trace=%s profile=%s" % [game.quests.is_active("side_childs_charm"), game.quests.is_objective_done("side_childs_charm", "trace_thread"), game.zone_root.get_meta("opening_build_profile", "full")])
		return
	print("REAL_INPUT oren_clue_published=PASS position=%s" % charm.global_position)
	print("REAL_INPUT oren_retroactive_evidence=PASS")
	await _turn_camera_north(game)
	await _move_until(game, KEY_D, "oren_cemetery_west_lane", func(p: Vector3) -> bool: return p.x > 9.0, 8000)
	await _move_until(game, KEY_W, "oren_cemetery_clear_lane", func(p: Vector3) -> bool: return p.z < 8.3, 5000)
	await _move_until(game, KEY_D, "oren_chapel_east_lane", func(p: Vector3) -> bool: return p.x > 11.0, 6000)
	await _move_until(game, KEY_S, "oren_grave_approach", func(p: Vector3) -> bool: return p.z > 9.8, 5000)
	await _turn_camera_south(game)
	var focus_deadline := Time.get_ticks_msec() + 3500
	while Time.get_ticks_msec() < focus_deadline and (game.active_interactable == null or game.active_interactable.interaction_id != "oren_charm_shrine"):
		await process_frame
	if game.active_interactable == null or game.active_interactable.interaction_id != "oren_charm_shrine":
		_fail("Oren's visible grave clue did not gain focus after Kael faced it")
		return
	await _use_focused_interaction(game, "oren_charm_shrine", "oren_charm_return")
	if not failures.is_empty():
		return
	if not game.quests.is_completed("side_childs_charm") or not bool(game.story_state.get_flag("oren_charm_returned", false)):
		_fail("The focused charm placement did not complete Oren's request")
		return
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or not saved.get("quests", {}).get("completed", {}).has("side_childs_charm") or not bool(saved.get("story_state", {}).get("flags", {}).get("oren_charm_returned", false)):
		_fail("Manual save did not preserve Oren's charm return")
	else:
		print("REAL_INPUT oren_charm_return=PASS saved=true")

func _complete_three_candles(game: Node) -> void:
	for flag_id in ["road_evidence_bram", "road_evidence_sella", "oren_name_spoken"]:
		if not bool(game.story_state.get_flag(flag_id, false)):
			_fail("Genuine Greyfen save lacks named-dead evidence: " + flag_id)
			return
	if game.quests.is_active("side_three_candles") or game.quests.is_completed("side_three_candles"):
		_fail("Three Candles Unlit was already started in the source save")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_A, "candles_bridge_centerline", func(p: Vector3) -> bool: return p.x < 0.45, 7000)
	await _move_until(game, KEY_S, "candles_south_bank", func(p: Vector3) -> bool: return p.z > 9.2, 9000)
	await _move_until(game, KEY_A, "candles_request_board", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "side_contracts", 6000)
	await _choose_focused_dialogue_action(game, "side_contracts", "Three Candles Unlit", "candles_request")
	if not failures.is_empty():
		return
	if not game.quests.is_active("side_three_candles"):
		_fail("Three Candles Unlit did not start at the request board")
		return
	for name_id in ["bram", "sella", "oren"]:
		if game.zone_root.find_child("memorial_candle_%s" % name_id, true, false) == null:
			_fail("Named memorial candle was not published: " + name_id)
			return
	print("REAL_INPUT candles_published=PASS count=3")
	await _turn_camera_north(game)
	await _move_until(game, KEY_D, "candles_roadside_lane", func(p: Vector3) -> bool: return p.x > 4.4, 8000)
	await _move_until(game, KEY_W, "candle_bram_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "memorial_candle_bram", 5000)
	await _use_focused_interaction(game, "memorial_candle_bram", "candle_bram")
	if not failures.is_empty():
		return
	await _turn_camera_south(game)
	var sella_deadline := Time.get_ticks_msec() + 3500
	while Time.get_ticks_msec() < sella_deadline and (game.active_interactable == null or game.active_interactable.interaction_id != "memorial_candle_sella"):
		await process_frame
	if game.active_interactable == null or game.active_interactable.interaction_id != "memorial_candle_sella":
		_fail("Sella's memorial candle did not gain camera-facing focus")
		return
	await _use_focused_interaction(game, "memorial_candle_sella", "candle_sella")
	if not failures.is_empty():
		return
	await _move_until(game, KEY_W, "candle_oren_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "memorial_candle_oren", 6000)
	await _use_focused_interaction(game, "memorial_candle_oren", "candle_oren")
	if not failures.is_empty():
		return
	if not game.quests.is_completed("side_three_candles") or not bool(game.story_state.get_flag("three_candles_lit", false)):
		_fail("Three focused candle interactions did not complete the named memorial")
		return
	for name_id in ["bram", "sella", "oren"]:
		var lit_visual := game.zone_root.find_child("LitMemorialCandle_%s" % name_id, true, false) as Node3D
		if lit_visual == null or lit_visual.get_node_or_null("Flame") == null or not lit_visual.get_node("Flame").visible:
			_fail("A lit memorial candle is not visible after interaction: " + name_id)
			return
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or not saved.get("quests", {}).get("completed", {}).has("side_three_candles") or not bool(saved.get("story_state", {}).get("flags", {}).get("three_candles_lit", false)):
		_fail("Manual save did not preserve the three lit candles")
	else:
		print("REAL_INPUT three_candles=PASS visible=3 saved=true")

func _verify_side_outcome_reload(game: Node, snapshot: Dictionary) -> void:
	var contracts := {
		"main_blood_under_stone": {"flag": "edric_stance", "values": ["cooperate", "exposed", "compelled"]},
		"side_bitter_roots": {"flag": "mira_truth", "values": ["confessed", "kept"]},
		"side_black_dog": {"flag": "black_dog_fate", "values": ["spared", "hidden"]},
		"side_widows_bell": {"flag": "widow_truth", "values": ["told", "comforted"]},
		"side_iron_remembers": {"flag": "iron_fate", "values": ["memorial", "weapon"]},
		"side_empty_grave": {"flag": "returned_soldier_fate", "values": ["named", "anonymous"]},
		"side_rooks_map": {"flag": "rook_map_fate", "values": ["preserved", "destroyed"]},
		"side_millers_measure": {"flag": "ash_measure_fate", "values": ["farmer", "healer", "assembly"]},
		"side_soldiers_debt": {"flag": "bannerless_fate", "values": ["testimony", "shielded", "assembly"]},
	}
	var completed: Dictionary = snapshot.get("quests", {}).get("completed", {})
	var saved_flags: Dictionary = snapshot.get("story_state", {}).get("flags", {})
	var checked := 0
	for quest_id in contracts:
		if not completed.has(quest_id):
			continue
		var contract: Dictionary = contracts[quest_id]
		var flag_id := str(contract.flag)
		var outcome := str(saved_flags.get(flag_id, ""))
		if outcome not in contract.values or not game.quests.is_completed(quest_id) or str(game.story_state.get_flag(flag_id, "")) != outcome:
			_fail("Continue lost completed side consequence: %s / %s=%s" % [quest_id, flag_id, outcome])
			return
		checked += 1
		print("REAL_INPUT side_outcome_reload=PASS quest=%s flag=%s outcome=%s" % [quest_id, flag_id, outcome])
	if checked == 0:
		_fail("Side-outcome fixture contains no completed target quest")
		return
	if game.zone_transition_pending or game.player.transition_locked or paused:
		_fail("Side-outcome Continue did not restore player control")
		return
	var saved_again := await _save_campaign_checkpoint(game)
	if not failures.is_empty() or not bool(saved_again.get("ok", false)):
		return
	var roundtrip_flags: Dictionary = saved_again.get("data", {}).get("story_state", {}).get("flags", {})
	for quest_id in contracts:
		if completed.has(quest_id):
			var flag_id := str(contracts[quest_id].flag)
			if roundtrip_flags.get(flag_id) != saved_flags.get(flag_id):
				_fail("Continue/manual-save round trip changed %s" % flag_id)
	print("REAL_INPUT side_outcome_roundtrip=PASS checked=%d zone=%s" % [checked, game.current_zone_id])

func _verify_three_candles_reload(game: Node) -> void:
	if not game.quests.is_completed("side_three_candles") or not bool(game.story_state.get_flag("three_candles_lit", false)):
		_fail("Continued save lost Three Candles completion or its consequence flag")
		return
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		var complete := true
		for name_id in ["bram", "sella", "oren"]:
			var lit_visual := game.zone_root.find_child("LitMemorialCandle_%s" % name_id, true, false) as Node3D
			if lit_visual == null or not lit_visual.visible or lit_visual.get_node_or_null("Flame") == null or not lit_visual.get_node("Flame").visible:
				complete = false
				break
		if complete:
			print("REAL_INPUT three_candles_reload=PASS visible=3")
			return
		await process_frame
	_fail("Continued save did not republish all three lit memorial candles")

func _complete_rooks_map(game: Node) -> void:
	if game.quests.is_active("side_rooks_map") or game.quests.is_completed("side_rooks_map"):
		_fail("The Road That Bends was already started in the source save")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_A, "rook_request_board", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "side_contracts", 7000)
	await _choose_focused_dialogue_action(game, "side_contracts", "The Road That Bends", "rook_request")
	if not failures.is_empty() or not game.quests.is_active("side_rooks_map"):
		_fail("Rook's request did not start at the board")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_D, "rook_bridge_center", func(p: Vector3) -> bool: return p.x > -0.4, 7000)
	await _move_until(game, KEY_W, "rook_north_bank", func(p: Vector3) -> bool: return p.z < -9.7, 12000)
	await _move_until(game, KEY_A, "rook_to_deep_wood", func(_p: Vector3) -> bool: return game.current_zone_id == "deep_wood", 14000)
	if not await _await_playable_zone(game, "deep_wood", "rook_deep_wood_arrival"):
		return
	var marker := game.zone_root.find_child("rooks_false_road", true, false) as Area3D
	if marker == null:
		_fail("The false-road waystone was not published after Deep Wood arrival")
		return
	await _move_until(game, KEY_D, "rook_false_road_east", func(p: Vector3) -> bool: return p.x > 3.2, 11000)
	await _move_until(game, KEY_W, "rook_false_road_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "rooks_false_road", 6000)
	await _use_focused_interaction(game, "rooks_false_road", "rook_false_road")
	if not failures.is_empty() or not game.quests.is_objective_done("side_rooks_map", "walk_false_road"):
		_fail("False-road comparison did not advance Rook's quest through focused E")
		return
	await _move_until(game, KEY_A, "rook_return_south_lane", func(p: Vector3) -> bool: return p.x < -6.8, 11000)
	await _move_until(game, KEY_S, "rook_to_wychwood", func(_p: Vector3) -> bool: return game.current_zone_id == "wychwood", 9000)
	if not await _await_playable_zone(game, "wychwood", "rook_wychwood_return"):
		return
	await _move_until(game, KEY_A, "rook_wychwood_bridge_lane", func(p: Vector3) -> bool: return p.x < 0.4, 10000)
	await _move_until(game, KEY_S, "rook_to_greyfen", func(_p: Vector3) -> bool: return game.current_zone_id == "greyfen", 14000)
	if not await _await_playable_zone(game, "greyfen", "rook_greyfen_return"):
		return
	await _move_until(game, KEY_S, "rook_south_bank", func(p: Vector3) -> bool: return p.z > 10.0, 12000)
	await _move_until(game, KEY_A, "rook_west_yard", func(p: Vector3) -> bool: return p.x < -7.4, 8500)
	await _move_until(game, KEY_W, "rook_dialogue_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "rook", 5500)
	await _choose_focused_dialogue_action(game, "rook", "Keep the older road", "rook_map_choice")
	if not failures.is_empty() or not game.quests.is_completed("side_rooks_map") or str(game.story_state.get_flag("rook_map_fate", "")) != "preserved":
		_fail("Rook's dialogue did not preserve the first road")
		return
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or not saved.get("quests", {}).get("completed", {}).has("side_rooks_map") or str(saved.get("story_state", {}).get("flags", {}).get("rook_map_fate", "")) != "preserved":
		_fail("Manual save did not retain Rook's road decision")
	else:
		print("REAL_INPUT rooks_map=PASS route=deep_wood saved=true")

func _complete_millers_measure(game: Node) -> void:
	if game.quests.is_active("side_millers_measure") or game.quests.is_completed("side_millers_measure"):
		_fail("A Measure of Ash was already started in the source save")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_D, "measure_request_board", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "side_contracts", 7000)
	await _choose_focused_dialogue_action(game, "side_contracts", "A Measure of Ash", "measure_request")
	if not failures.is_empty() or not game.quests.is_active("side_millers_measure"):
		_fail("Miller's measure request did not start at the board")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_D, "measure_bridge_center", func(p: Vector3) -> bool: return p.x > -0.4, 7000)
	await _move_until(game, KEY_W, "measure_north_bank", func(p: Vector3) -> bool: return p.z < -9.7, 12000)
	await _move_until(game, KEY_A, "measure_to_deep_wood", func(_p: Vector3) -> bool: return game.current_zone_id == "deep_wood", 14000)
	if not await _await_playable_zone(game, "deep_wood", "measure_deep_wood_arrival"):
		return
	await _move_until(game, KEY_D, "measure_deep_wood_east_lane", func(p: Vector3) -> bool: return p.x > 2.0, 7000)
	await _move_until(game, KEY_W, "measure_deep_wood_north_road", func(p: Vector3) -> bool: return p.z < -11.0, 12000)
	await _move_until(game, KEY_D, "measure_deep_wood_north_gate_lane", func(p: Vector3) -> bool: return p.x > 7.0, 6000)
	await _move_until(game, KEY_W, "measure_to_old_mill", func(_p: Vector3) -> bool: return game.current_zone_id == "old_mill", 9500)
	if not await _await_playable_zone(game, "old_mill", "measure_old_mill_arrival"):
		return
	if game.zone_root.find_child("hidden_ash_measure", true, false) == null:
		_fail("The miller's hidden measure was not published in the active Old Mill")
		return
	await _move_until(game, KEY_D, "measure_mill_east_lane", func(p: Vector3) -> bool: return p.x > -3.3, 6000)
	await _move_until(game, KEY_W, "measure_mill_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "hidden_ash_measure", 9000)
	await _use_focused_interaction(game, "hidden_ash_measure", "measure_clue")
	if not failures.is_empty() or not game.quests.is_objective_done("side_millers_measure", "weigh_ash") or not bool(game.story_state.get_flag("ash_measure_recovered", false)):
		_fail("Focused mill measure did not persist the recovered evidence")
		return
	await _move_until(game, KEY_S, "measure_mill_south_road", func(p: Vector3) -> bool: return p.z > 11.0, 11000)
	await _move_until(game, KEY_A, "measure_mill_south_gate_lane", func(p: Vector3) -> bool: return p.x < -7.0, 6000)
	await _move_until(game, KEY_S, "measure_return_deep_wood", func(_p: Vector3) -> bool: return game.current_zone_id == "deep_wood", 9000)
	if not await _await_playable_zone(game, "deep_wood", "measure_return_deep_wood_arrival"):
		return
	await _move_until(game, KEY_S, "measure_deep_wood_clearing", func(p: Vector3) -> bool: return p.z > -4.0, 7500)
	await _move_until(game, KEY_A, "measure_deep_wood_center_road", func(p: Vector3) -> bool: return p.x < 0.4, 8500)
	await _move_until(game, KEY_S, "measure_deep_wood_south_road", func(p: Vector3) -> bool: return p.z > 11.0, 12000)
	await _move_until(game, KEY_A, "measure_deep_wood_south_gate_lane", func(p: Vector3) -> bool: return p.x < -6.8, 7000)
	await _move_until(game, KEY_S, "measure_return_wychwood", func(_p: Vector3) -> bool: return game.current_zone_id == "wychwood", 9000)
	if not await _await_playable_zone(game, "wychwood", "measure_wychwood_return"):
		return
	await _move_until(game, KEY_S, "measure_wychwood_clear_ritual_stones", func(p: Vector3) -> bool: return p.z > -3.5, 7000)
	await _move_until(game, KEY_A, "measure_wychwood_bridge_lane", func(p: Vector3) -> bool: return p.x < 0.4, 10000)
	await _move_until(game, KEY_S, "measure_return_greyfen", func(_p: Vector3) -> bool: return game.current_zone_id == "greyfen", 14000)
	if not await _await_playable_zone(game, "greyfen", "measure_greyfen_return"):
		return
	await _move_until(game, KEY_D, "measure_toma_east_lane", func(p: Vector3) -> bool: return p.x > 11.5, 9500)
	await _turn_camera_south(game)
	await _move_until(game, KEY_W, "measure_toma_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "farmer_toma", 9000)
	await _choose_focused_dialogue_action(game, "farmer_toma", "Show the farmer what the mill weighed", "measure_farmer_choice")
	if not failures.is_empty() or not game.quests.is_completed("side_millers_measure") or str(game.story_state.get_flag("ash_measure_fate", "")) != "farmer":
		_fail("Farmer dialogue did not resolve the miller's measure")
		return
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or not saved.get("quests", {}).get("completed", {}).has("side_millers_measure") or str(saved.get("story_state", {}).get("flags", {}).get("ash_measure_fate", "")) != "farmer":
		_fail("Manual save did not retain the miller's measure decision")
	else:
		print("REAL_INPUT millers_measure=PASS route=old_mill saved=true")

func _complete_bannerless(game: Node) -> void:
	if str(game.story_state.get_flag("senn_fate", "")) != "testimony" or not game.quests.is_completed("main_soldier_without_banner"):
		_fail("Genuine bandit-road save lacks Senn's testimony outcome")
		return
	if game.quests.is_active("side_soldiers_debt") or game.quests.is_completed("side_soldiers_debt"):
		_fail("The Bannerless was already started in the source save")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_S, "banner_senn_south_approach", func(p: Vector3) -> bool: return p.z > 0.7, 5500)
	await _move_until(game, KEY_A, "banner_senn_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "captain_senn", 6000)
	await _choose_focused_dialogue_action(game, "captain_senn", "Find the soldiers who left", "banner_senn_request")
	if not failures.is_empty() or not game.quests.is_active("side_soldiers_debt"):
		_fail("Senn's request did not start The Bannerless")
		return
	if not await _await_playable_zone(game, "bandit_road", "banner_camp_rebuild"):
		return
	if game.zone_root.find_child("deserters_muster", true, false) == null:
		_fail("The deserters' muster roll was not published after Senn's request")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_W, "banner_camp_north_lane", func(p: Vector3) -> bool: return p.z < -2.8, 6000)
	await _move_until(game, KEY_A, "banner_camp_road_center", func(p: Vector3) -> bool: return p.x < 1.8, 9000)
	await _move_until(game, KEY_S, "banner_muster_south_approach", func(p: Vector3) -> bool: return p.z > 6.0, 8000)
	await _move_until(game, KEY_W, "banner_muster_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "deserters_muster", 5500)
	await _use_focused_interaction(game, "deserters_muster", "banner_muster")
	if not failures.is_empty() or not game.quests.is_objective_done("side_soldiers_debt", "find_deserters") or not bool(game.story_state.get_flag("deserters_muster_read", false)):
		_fail("Focused muster roll did not reveal the deserters")
		return
	await _move_until(game, KEY_D, "banner_senn_return_east", func(p: Vector3) -> bool: return p.x > 8.7, 8500)
	await _move_until(game, KEY_W, "banner_senn_return_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "captain_senn", 8000)
	await _choose_focused_dialogue_action(game, "captain_senn", "Carry the deserters' signed refusal", "banner_testimony_choice")
	if not failures.is_empty() or not game.quests.is_completed("side_soldiers_debt") or str(game.story_state.get_flag("bannerless_fate", "")) != "testimony":
		_fail("Senn did not carry the deserters' testimony")
		return
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or not saved.get("quests", {}).get("completed", {}).has("side_soldiers_debt") or str(saved.get("story_state", {}).get("flags", {}).get("bannerless_fate", "")) != "testimony":
		_fail("Manual save did not preserve the deserters' testimony")
	else:
		print("REAL_INPUT bannerless=PASS saved=true")

func _resolve_rook_alternative(game: Node) -> void:
	if not game.quests.is_active("side_rooks_map") or not game.quests.is_objective_done("side_rooks_map", "walk_false_road") or game.quests.is_objective_done("side_rooks_map", "map_choice"):
		_fail("Rook's copied save is not at the pre-choice beat")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_S, "rook_destroy_south_bank", func(p: Vector3) -> bool: return p.z > 10.0, 12000)
	await _move_until(game, KEY_A, "rook_destroy_west_yard", func(p: Vector3) -> bool: return p.x < -7.4, 8000)
	await _move_until(game, KEY_W, "rook_destroy_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "rook", 5500)
	await _choose_focused_dialogue_action(game, "rook", "Destroy the map", "rook_destroy_choice")
	if not failures.is_empty() or not game.quests.is_completed("side_rooks_map") or str(game.story_state.get_flag("rook_map_fate", "")) != "destroyed":
		_fail("Rook's destroyed-map outcome did not complete")
		return
	var slot := await _save_campaign_checkpoint(game)
	if not bool(slot.get("ok", false)) or str(slot.get("data", {}).get("story_state", {}).get("flags", {}).get("rook_map_fate", "")) != "destroyed":
		_fail("Manual save lost Rook's destroyed-map outcome")
	else:
		print("REAL_INPUT rook_destroy=PASS saved=true")

func _resolve_measure_healer(game: Node) -> void:
	if not game.quests.is_active("side_millers_measure") or not game.quests.is_objective_done("side_millers_measure", "weigh_ash") or game.quests.is_objective_done("side_millers_measure", "ash_choice"):
		_fail("Miller's copied save is not at the pre-choice beat")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_S, "measure_healer_frontage_lane", func(p: Vector3) -> bool: return p.z > 0.4, 9000)
	await _move_until(game, KEY_A, "measure_healer_west_lane", func(p: Vector3) -> bool: return p.x < -6.3, 8000)
	await _move_until(game, KEY_W, "measure_healer_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "mira", 6500)
	await _choose_focused_dialogue_action(game, "mira", "Use the miller's measure", "measure_healer_choice")
	if not failures.is_empty() or not game.quests.is_completed("side_millers_measure") or str(game.story_state.get_flag("ash_measure_fate", "")) != "healer":
		_fail("Mira's healer outcome did not complete")
		return
	var slot := await _save_campaign_checkpoint(game)
	if not bool(slot.get("ok", false)) or str(slot.get("data", {}).get("story_state", {}).get("flags", {}).get("ash_measure_fate", "")) != "healer":
		_fail("Manual save lost the healer outcome")
	else:
		print("REAL_INPUT measure_healer=PASS saved=true")

func _resume_saved_route(game: Node) -> void:
	if not paused:
		return
	if game.hud.active_menu != "pause":
		_fail("Continuous route is paused outside its manual-save menu")
		return
	_key(KEY_ESCAPE, true)
	await _frames(2)
	_key(KEY_ESCAPE, false)
	await _frames(5)
	if paused or game.hud.menu_layer.visible:
		_fail("Escape did not resume the saved continuous route")

func _verify_undercroft_return_circuit(game: Node) -> void:
	var snapshot: Dictionary = game.save_manager._read_slot(game.save_manager.SAVE_PATH).get("data", {}).duplicate(true)
	if str(game.story_state.get_flag("bannerless_fate", "")) != "assembly" or str(game.story_state.get_flag("halvern_fate", "")) != "witness":
		_fail("Return circuit lost the genuine assembly/witness outcomes")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_D, "assembly_return_outer_lane", func(p: Vector3) -> bool: return p.x > 11.0, 8000)
	await _move_until(game, KEY_S, "assembly_return_south_lane", func(p: Vector3) -> bool: return p.z > 11.0, 10000)
	await _move_until(game, KEY_A, "assembly_return_gate_lane", func(p: Vector3) -> bool: return p.x < -6.8, 10000)
	await _turn_camera_south(game)
	await _move_until(game, KEY_W, "assembly_return_gate_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.zone_target == "undercroft", 6000)
	await _use_focused_interaction(game, "gate_undercroft", "assembly_return_gate")
	if not await _await_playable_zone(game, "undercroft", "assembly_return_undercroft"):
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_S, "record_return_south_lane", func(p: Vector3) -> bool: return p.z > 10.9, 12000)
	await _move_until(game, KEY_A, "record_return_gate_lane", func(p: Vector3) -> bool: return p.x < -5.8, 6000)
	await _turn_camera_south(game)
	await _move_until(game, KEY_W, "record_return_gate_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.zone_target == "record_hall", 6000)
	if not failures.is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Temp/AshenOath/undercroft_record_door_gameplay.png")
	await _use_focused_interaction(game, "gate_record_hall", "record_return_gate")
	if not await _await_playable_zone(game, "record_hall", "record_return_arrival"):
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_D, "undercroft_reentry_east_lane", func(p: Vector3) -> bool: return p.x > 5.4, 6000)
	await _move_until(game, KEY_W, "undercroft_reentry_gate_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.zone_target == "undercroft", 6000)
	await _use_focused_interaction(game, "gate_undercroft", "undercroft_reentry_gate")
	if not await _await_playable_zone(game, "undercroft", "undercroft_reentry_arrival"):
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_W, "assembly_reentry_witness_lane", func(p: Vector3) -> bool: return p.z < -7.4, 11000)
	await _move_until(game, KEY_D, "assembly_reentry_east_lane", func(p: Vector3) -> bool: return p.x > 5.8, 6000)
	await _move_until(game, KEY_W, "assembly_reentry_gate_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.zone_target == "assembly", 6000)
	if not failures.is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Temp/AshenOath/undercroft_assembly_door_gameplay.png")
	await _use_focused_interaction(game, "gate_assembly", "assembly_reentry_gate")
	if not await _await_playable_zone(game, "assembly", "assembly_reentry_arrival"):
		return
	await _verify_side_outcome_reload(game, snapshot)
	if failures.is_empty():
		print("REAL_INPUT undercroft_return_circuit=PASS assembly_undercroft_record_hall_bidirectional=true")

func _verify_undercroft_doorways(game: Node) -> void:
	await _turn_camera_north(game)
	await _move_until(game, KEY_D, "undercroft_north_door_lane", func(p: Vector3) -> bool: return p.x > 5.8, 6000)
	await _move_until(game, KEY_W, "undercroft_north_door_out", func(p: Vector3) -> bool: return p.z < -15.2, 6500)
	await _move_until(game, KEY_S, "undercroft_north_door_in", func(p: Vector3) -> bool: return p.z > -11.0, 5000)
	await _move_until(game, KEY_A, "undercroft_center_lane", func(p: Vector3) -> bool: return p.x < 0.4, 6000)
	await _move_until(game, KEY_S, "undercroft_south_door_approach", func(p: Vector3) -> bool: return p.z > 11.0, 12000)
	await _move_until(game, KEY_A, "undercroft_south_door_lane", func(p: Vector3) -> bool: return p.x < -5.8, 6000)
	await _move_until(game, KEY_S, "undercroft_south_door_out", func(p: Vector3) -> bool: return p.z > 15.2, 5000)
	await _move_until(game, KEY_W, "undercroft_south_door_in", func(p: Vector3) -> bool: return p.z < 11.0, 5000)
	await _move_until(game, KEY_D, "undercroft_return_center", func(p: Vector3) -> bool: return p.x > -0.4, 6000)
	await _move_until(game, KEY_W, "undercroft_return_witness_lane", func(p: Vector3) -> bool: return p.z < -7.4, 11000)
	if failures.is_empty():
		print("REAL_INPUT undercroft_doorways=PASS both_directions=true jumped=false")

func _carry_measure_to_assembly(game: Node, checkpoint_zone := "greyfen") -> void:
	if not game.quests.is_active("side_millers_measure") or not game.quests.is_objective_done("side_millers_measure", "weigh_ash") or str(game.story_state.get_flag("ash_measure_fate", "")) != "":
		_fail("Assembly measure route requires genuine unresolved recovered evidence")
		return
	if checkpoint_zone == "greyfen":
		await _turn_camera_north(game)
		await _move_until(game, KEY_S, "measure_carry_forge_frontage", func(p: Vector3) -> bool: return p.z > -4.5, 7000)
	var legs: Array[Callable] = [
		_prepare_for_ash_mill, _travel_to_ash_mill, _inspect_ash_millstones,
		_fight_ashwing_real_input, _travel_to_bandit_road, _fight_senn_guard,
		_travel_to_castle_approach, _collect_castle_evidence, _enter_record_hall,
		_resolve_record_ledger, _fight_record_haunting, _confront_edric,
		_enter_undercroft, _break_halvern_guard, _resolve_halvern_witness,
		_travel_to_assembly,
	]
	if checkpoint_zone == "old_mill":
		legs = legs.slice(4)
	elif checkpoint_zone == "undercroft":
		legs = legs.slice(14)
	for leg in legs:
		await _resume_saved_route(game)
		if not failures.is_empty():
			return
		await _turn_camera_north(game)
		await leg.call(game)
		if not failures.is_empty():
			return
		if str(game.story_state.get_flag("ash_measure_fate", "")) != "":
			_fail("Carried miller evidence was resolved before reaching assembly")
			return
	await _resume_saved_route(game)
	await _turn_camera_north(game)
	await _move_until(game, KEY_W, "measure_record_witnesses", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "witnesses_ready", 10000)
	await _use_focused_interaction(game, "witnesses_ready", "measure_record_witnesses")
	await _move_until(game, KEY_D, "measure_record_dais_east", func(p: Vector3) -> bool: return p.x > 6.3, 6500)
	await _move_until(game, KEY_W, "measure_record_dais_north", func(p: Vector3) -> bool: return p.z < -8.5, 6000)
	await _move_until(game, KEY_A, "measure_record_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "assembly_choice", 6500)
	await _choose_focused_dialogue_action(game, "assembly_choice", "Place the miller's measure", "measure_public_record_choice")
	if not failures.is_empty() or not game.quests.is_completed("side_millers_measure") or str(game.story_state.get_flag("ash_measure_fate", "")) != "assembly":
		_fail("Assembly did not resolve the carried miller evidence")
		return
	var slot := await _save_campaign_checkpoint(game)
	if not bool(slot.get("ok", false)) or str(slot.get("data", {}).get("story_state", {}).get("flags", {}).get("ash_measure_fate", "")) != "assembly":
		_fail("Manual save lost the miller public-record outcome")
	else:
		print("REAL_INPUT measure_public_record=PASS from_checkpoint=%s saved=true" % checkpoint_zone)

func _carry_banner_to_assembly(game: Node, checkpoint_zone: String = "bandit_road") -> void:
	var from_castle := checkpoint_zone != "bandit_road"
	if not game.quests.is_active("side_soldiers_debt") or game.quests.is_objective_done("side_soldiers_debt", "find_deserters") != from_castle:
		_fail("Public-record route does not match its genuine saved muster beat")
		return
	if not from_castle:
		await _turn_camera_north(game)
		await _move_until(game, KEY_W, "banner_record_north_lane", func(p: Vector3) -> bool: return p.z < -2.8, 6000)
		await _move_until(game, KEY_A, "banner_record_road_center", func(p: Vector3) -> bool: return p.x < 1.8, 9000)
		await _move_until(game, KEY_S, "banner_record_south_approach", func(p: Vector3) -> bool: return p.z > 6.0, 8000)
		await _move_until(game, KEY_W, "banner_record_muster_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "deserters_muster", 5500)
		await _use_focused_interaction(game, "deserters_muster", "banner_record_muster")
		if not failures.is_empty() or not game.quests.is_objective_done("side_soldiers_debt", "find_deserters"):
			_fail("Public-record route did not collect the muster through E")
			return
		await _move_until(game, KEY_D, "banner_record_castle_road_lane", func(p: Vector3) -> bool: return p.x > 5.3, 6000)
		await _travel_to_castle_approach(game)
	var legs: Array[Callable] = [
		_collect_castle_evidence, _enter_record_hall,
		_resolve_record_ledger, _fight_record_haunting, _confront_edric,
		_enter_undercroft, _break_halvern_guard, _resolve_halvern_witness,
		_travel_to_assembly,
	]
	if checkpoint_zone == "undercroft":
		await _verify_undercroft_doorways(game)
		legs = [_travel_to_assembly]
	for leg in legs:
		await _resume_saved_route(game)
		if not failures.is_empty():
			return
		await leg.call(game)
	if not failures.is_empty():
		return
	await _resume_saved_route(game)
	if not game.quests.is_active("side_soldiers_debt") or not game.quests.is_objective_done("side_soldiers_debt", "find_deserters") or str(game.story_state.get_flag("bannerless_fate", "")) != "":
		_fail("Continuous Castle route lost or prematurely resolved the muster")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_W, "banner_record_witnesses", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "witnesses_ready", 10000)
	await _use_focused_interaction(game, "witnesses_ready", "banner_record_witnesses")
	await _move_until(game, KEY_D, "banner_record_dais_east", func(p: Vector3) -> bool: return p.x > 6.3, 6500)
	await _move_until(game, KEY_W, "banner_record_dais_north", func(p: Vector3) -> bool: return p.z < -8.5, 6000)
	await _move_until(game, KEY_A, "banner_record_assembly_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "assembly_choice", 6500)
	await _choose_focused_dialogue_action(game, "assembly_choice", "Read the deserters' refusal", "banner_public_record_choice")
	if not failures.is_empty() or not game.quests.is_completed("side_soldiers_debt") or str(game.story_state.get_flag("bannerless_fate", "")) != "assembly":
		_fail("Assembly did not resolve the carried deserter evidence")
		return
	var slot := await _save_campaign_checkpoint(game)
	if not bool(slot.get("ok", false)) or str(slot.get("data", {}).get("story_state", {}).get("flags", {}).get("bannerless_fate", "")) != "assembly":
		_fail("Manual save lost the public-record outcome")
	else:
		print("REAL_INPUT banner_public_record=PASS from_checkpoint=%s saved=true" % checkpoint_zone)

func _resolve_banner_shield(game: Node) -> void:
	if not game.quests.is_active("side_soldiers_debt") or game.quests.is_objective_done("side_soldiers_debt", "find_deserters"):
		_fail("Bannerless copied save is not at the muster beat")
		return
	await _turn_camera_north(game)
	await _move_until(game, KEY_W, "banner_shield_north_lane", func(p: Vector3) -> bool: return p.z < -2.8, 6000)
	await _move_until(game, KEY_A, "banner_shield_road_center", func(p: Vector3) -> bool: return p.x < 1.8, 9000)
	await _move_until(game, KEY_S, "banner_shield_south_approach", func(p: Vector3) -> bool: return p.z > 6.0, 8000)
	await _move_until(game, KEY_W, "banner_shield_muster_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "deserters_muster", 5500)
	await _use_focused_interaction(game, "deserters_muster", "banner_shield_muster")
	if not failures.is_empty() or not game.quests.is_objective_done("side_soldiers_debt", "find_deserters"):
		_fail("Shielding route did not inspect the muster")
		return
	await _move_until(game, KEY_D, "banner_shield_senn_east", func(p: Vector3) -> bool: return p.x > 8.7, 8500)
	await _move_until(game, KEY_W, "banner_shield_senn_focus", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "captain_senn", 8000)
	await _choose_focused_dialogue_action(game, "captain_senn", "Shield the deserters' names", "banner_shield_choice")
	if not failures.is_empty() or not game.quests.is_completed("side_soldiers_debt") or str(game.story_state.get_flag("bannerless_fate", "")) != "shielded":
		_fail("Senn's shielding outcome did not complete")
		return
	var slot := await _save_campaign_checkpoint(game)
	if not bool(slot.get("ok", false)) or str(slot.get("data", {}).get("story_state", {}).get("flags", {}).get("bannerless_fate", "")) != "shielded":
		_fail("Manual save lost the deserters' shielded outcome")
	else:
		print("REAL_INPUT banner_shield=PASS saved=true")

func _choose_focused_dialogue_action(game: Node, interaction_id: String, action_prefix: String, label: String) -> void:
	if not failures.is_empty():
		return
	if not await _await_focused_interaction(game, interaction_id, label):
		return
	_key(KEY_E, true)
	await _frames(3)
	_key(KEY_E, false)
	await _frames(5)
	if not game.hud.dialogue_layer.visible:
		_fail("%s did not open dialogue through E" % label)
		return
	for _page in range(24):
		if game.hud.dialogue_page_index >= game.hud.dialogue_pages.size() - 1:
			break
		_key(KEY_ENTER, true)
		await _frames(3)
		_key(KEY_ENTER, false)
		await _frames(5)
	var found := false
	for _choice in range(24):
		var focused := root.gui_get_focus_owner() as Button
		if focused != null and focused.text.begins_with(action_prefix):
			found = true
			break
		_key(KEY_TAB, true)
		await _frames(2)
		_key(KEY_TAB, false)
		await _frames(3)
	if not found:
		_fail("%s dialogue action was not keyboard reachable: %s" % [label, action_prefix])
		return
	_key(KEY_ENTER, true)
	await _frames(3)
	_key(KEY_ENTER, false)
	await _frames(8)
	if game.hud.dialogue_layer.visible:
		_fail("%s dialogue did not return control" % label)
	else:
		print("REAL_INPUT %s=PASS" % label)

func _focus_vendor_button(label_prefix: String, backwards: bool = false) -> bool:
	for _index in range(24):
		var focused := root.gui_get_focus_owner() as Button
		if focused != null and focused.text.begins_with(label_prefix) and not focused.disabled:
			return true
		var tab := InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.physical_keycode = KEY_TAB
		tab.shift_pressed = backwards
		tab.pressed = true
		Input.parse_input_event(tab)
		await _frames(2)
		tab.pressed = false
		Input.parse_input_event(tab)
		await _frames(2)
	_fail("Vendor menu could not focus %s through keyboard Tab" % label_prefix)
	return false

func _await_playable_zone(game: Node, zone_id: String, label: String) -> bool:
	if not failures.is_empty():
		return false
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline and (game.current_zone_id != zone_id or game.zone_transition_pending or game.player.transition_locked or not game.player.can_control):
		await process_frame
	if game.current_zone_id != zone_id or game.zone_transition_pending or game.player.transition_locked or not game.player.can_control:
		_fail("%s did not become playable; zone=%s" % [label, game.current_zone_id])
		return false
	print("REAL_INPUT %s=PASS position=%s" % [label, game.player.global_position])
	return true

func _fight_bog_wretch(game: Node, enemy: Node3D) -> void:
	await _move_until(game, KEY_D, "bog_arena_centerline", func(p: Vector3) -> bool: return p.x > -0.5, 6000)
	await _move_until(game, KEY_W, "bog_arena_approach", func(p: Vector3) -> bool: return p.z < -3.5, 8000)
	if not failures.is_empty():
		return
	var bombs_before := int(game.inventory.items.get("ash_bomb", 0))
	var health_before_bomb: float = enemy.health_component.health
	if bombs_before > 0:
		_key(KEY_F, true)
		await _frames(2)
		_key(KEY_F, false)
		await _frames(6)
		if int(game.inventory.items.get("ash_bomb", 0)) >= bombs_before or not bool(game.story_state.get_flag("bog_core_exposed", false)) or enemy.health_component.health >= health_before_bomb:
			_fail("Real Ash Bomb did not expose and damage the Bog Wretch; bombs=%d health=%.1f exposed=%s" % [game.inventory.items.get("ash_bomb", 0), enemy.health_component.health, game.story_state.get_flag("bog_core_exposed", false)])
			return
		print("REAL_INPUT bog_ash_weakness=PASS enemy_health=%.1f" % enemy.health_component.health)
	var deadline := Time.get_ticks_msec() + 90000
	var last_progress := Time.get_ticks_msec()
	var observed_health: float = enemy.health_component.health
	var last_attack := 0
	var last_potion := 0
	while Time.get_ticks_msec() < deadline:
		if game.quests.is_objective_done("main_teeth_in_rain", "fight_bog_wretch"):
			_release_combat_movement()
			print("REAL_INPUT bog_wretch_fight=PASS health=%.1f position=%s" % [game.player.health_component.health, game.player.global_position])
			return
		if game.player.health_component.health <= 0.0 or not is_instance_valid(enemy):
			_fail("Bog Wretch fight ended without the objective; player_health=%.1f enemy_health=%.1f player=%s enemy=%s" % [game.player.health_component.health, enemy.health_component.health if is_instance_valid(enemy) else -1.0, game.player.global_position, enemy.global_position if is_instance_valid(enemy) else Vector3.INF])
			return
		if enemy.health_component.health < observed_health:
			observed_health = enemy.health_component.health
			last_progress = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_progress > 25000:
			_fail("Bog Wretch combat stalled: player=%s enemy=%s enemy_health=%.1f" % [game.player.global_position, enemy.global_position, enemy.health_component.health])
			return
		if game.camera_rig.get_locked_combat_target() != enemy:
			_key(KEY_T, true)
			await _frames(2)
			_key(KEY_T, false)
			await _frames(9)
		var separation: Vector3 = enemy.global_position - game.player.global_position
		separation.y = 0.0
		var now := Time.get_ticks_msec()
		if game.player.health_component.health < 75.0 and game.player.attack_cooldown <= 0.01 and int(game.inventory.items.get("redroot_potion", 0)) > 0 and now - last_potion > 6000:
			_key(KEY_R, true)
			await _frames(2)
			_key(KEY_R, false)
			last_potion = now
		else:
			last_attack = await _drive_contact_strike(game, enemy, last_attack, 430)
		await _frames(3)
	_fail("Real-input Bog Wretch fight timed out; enemy_health=%.1f player_health=%.1f" % [enemy.health_component.health, game.player.health_component.health])

func _fight_cemetery_ambush(game: Node) -> void:
	var ambusher: Node3D = null
	for candidate in game.active_enemies:
		if is_instance_valid(candidate) and bool(candidate.get_meta("act_one_cemetery_ambush", false)) and not candidate.dead:
			ambusher = candidate
			break
	if ambusher == null:
		_fail("Two graves did not spawn the cemetery ambusher")
		return
	var spawn: Vector3 = ambusher.global_position
	if spawn.x < 10.0 or spawn.x > 18.0 or spawn.z < 7.0 or spawn.z > 11.2:
		_fail("Cemetery ambusher was relocated outside its authored arena: %s" % spawn)
		return
	print("REAL_INPUT cemetery_ambusher_spawn=PASS position=%s" % spawn)
	var deadline := Time.get_ticks_msec() + 45000
	var last_attack := 0
	var last_damage := Time.get_ticks_msec()
	var observed_health := INF
	while Time.get_ticks_msec() < deadline:
		if game.quests.is_objective_done("main_bell_beneath_greyfen", "cemetery_ambush"):
			_release_combat_movement()
			print("REAL_INPUT cemetery_ambush=PASS player=%s health=%.1f" % [game.player.global_position, game.player.health_component.health])
			return
		if game.player.health_component.health <= 0.0:
			_fail("Kael died in the real-input cemetery ambush")
			return
		if not is_instance_valid(ambusher):
			_fail("Cemetery ambusher vanished before quest completion")
			return
		if ambusher.health_component.health < observed_health:
			observed_health = ambusher.health_component.health
			last_damage = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_damage > 20000:
			_fail("Cemetery combat stalled: player=%s enemy=%s enemy_health=%.1f" % [game.player.global_position, ambusher.global_position, ambusher.health_component.health])
			return
		if game.camera_rig.get_locked_combat_target() != ambusher:
			_key(KEY_T, true)
			await _frames(2)
			_key(KEY_T, false)
			await _frames(8)
		var separation: Vector3 = ambusher.global_position - game.player.global_position
		separation.y = 0.0
		last_attack = await _drive_contact_strike(game, ambusher, last_attack, 430)
		await _frames(3)
	_fail("Cemetery combat timed out with enemy_health=%.1f" % ambusher.health_component.health)

func _await_focused_interaction(game: Node, interaction_id: String, label: String, timeout_ms: int = 3000) -> bool:
	if not failures.is_empty():
		return false
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if game.active_interactable != null and game.active_interactable.interaction_id == interaction_id and game.call("_interaction_target_valid", game.active_interactable) and Time.get_ticks_usec() >= game.interaction_input_block_until_usec:
			return true
		await process_frame
	_fail("%s did not receive real focus within %d ms; position=%s focus=%s" % [label, timeout_ms, game.player.global_position, game.active_interactable])
	return false

func _use_focused_interaction(game: Node, interaction_id: String, label: String, expected_speaker: String = "") -> void:
	if not await _await_focused_interaction(game, interaction_id, label):
		return
	var requires_dialogue: bool = game.active_interactable.interaction_type == "dialogue"
	_key(KEY_E, true)
	await _frames(3)
	_key(KEY_E, false)
	await _frames(5)
	if requires_dialogue and not game.hud.dialogue_layer.visible:
		_fail("%s real E input did not open its dialogue" % label)
		return
	if expected_speaker != "" and (not game.hud.dialogue_layer.visible or game.hud.dialogue_title.text != expected_speaker):
		_fail("%s did not show the actual %s conversation" % [label, expected_speaker])
		return
	if game.hud.dialogue_layer.visible:
		for _page in range(24):
			if not game.hud.dialogue_layer.visible:
				break
			_key(KEY_ENTER, true)
			await _frames(3)
			_key(KEY_ENTER, false)
			await _frames(5)
		if game.hud.dialogue_layer.visible:
			_fail("%s dialogue did not return control" % label)
			return
	print("REAL_INPUT %s=PASS position=%s" % [label, game.player.global_position])

func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _finish() -> void:
	print("OPENING REAL INPUT NATIVE: %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	quit(0 if failures.is_empty() else 1)
