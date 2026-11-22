extends SceneTree

var failures := 0

func _initialize() -> void:
	var scene = load("res://scenes/main.tscn")
	check(scene != null,"Main scene is missing")
	if scene == null: quit(1); return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _settle(4)
	check(game.current_zone_id == "greyfen","New Game did not load Greyfen")
	var life = game.zone_root.find_child("GreyfenLifeController",true,false)
	check(life != null,"Greyfen life controller is missing")
	if life != null:
		check(life.actor_count() >= 7,"Balanced Greyfen needs four ambient plus three named routine actors")
		for id in ["walker_well","walker_board","shrine_pilgrim","forge_helper"]:
			check(id in life.routine_ids(),"Missing routine: %s" % id)
		check(life.AMBIENT_LINES.size() >= 8,"Ambient dialogue pool is too small")
		for line_id in ["greyfen_road_quiet","greyfen_bell_dawn","greyfen_shrine_voice","greyfen_anwen_sleep"]:
			check(life.AMBIENT_LINES.has(line_id),"Missing ambient line ID: %s" % line_id)
	for id in ["village_well","notice_board","forge_corner","shrine_prayer","common_table","barrel_board"]:
		check(game.zone_root.find_child(id,true,false) != null,"Missing interactive place: %s" % id)

	var mini = game.minigames
	check(mini != null and mini.has_method("play_ttt") and mini.has_method("play_draughts"),"Minigame APIs are missing")
	mini.open_game("tic_tac_toe")
	check(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Tic-tac-toe did not lock world input")
	mini.ttt_board.clear()
	for value in [1,1,0,2,0,0,0,0,0]: mini.ttt_board.append(value)
	check(mini.play_ttt(2) and mini.finished,"Tic-tac-toe win detection failed")
	game.call("_on_minigame_result","tic_tac_toe","win")
	check(int(game.story_state.get_flag("tic_tac_toe_wins",0)) >= 1,"Tic-tac-toe win was not saved")
	check(bool(game.story_state.get_flag("rook_road_hint",false)),"Rook reward hint was not granted")
	mini.close_game()
	check(not paused and not mini.world_control_locked and not mini.is_open(),"Tic-tac-toe exit did not restore world input")

	mini.open_game("draughts")
	mini.draughts_board.fill(0)
	mini.draughts_board[8] = 1
	mini.draughts_board[15] = -1
	check(mini.play_draughts(8,22),"Draughts legal capture failed")
	check(mini.finished,"Draughts win detection failed")
	game.call("_on_minigame_result","draughts","win")
	check(int(game.story_state.get_flag("draughts_wins",0)) >= 1,"Draughts win was not saved")
	check(bool(game.story_state.get_flag("tor_iron_hint",false)),"Tor reward hint was not granted")
	mini.close_game()

	var saved: Dictionary = game.story_state.save_state()
	game.story_state.load_state(saved)
	check(bool(game.story_state.get_flag("tic_tac_toe_reward_claimed",false)),"Minigame reward did not round-trip")

	game.settings.set_quality_preset("potato")
	game.call("_load_zone","greyfen",Vector3(0,1,7))
	await _settle(3)
	life = game.zone_root.find_child("GreyfenLifeController",true,false)
	check(life != null and life.actor_count() >= 7,"Potato Greyfen lost required routine actors")
	check(game.zone_root.find_child("common_table",true,false) != null and game.zone_root.find_child("barrel_board",true,false) != null,"Potato mode removed minigames")

	print("GREYFEN LIFE VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _settle(count: int) -> void:
	for i in range(count): await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
