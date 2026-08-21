extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main scene is unavailable")
	if packed == null:
		_finish()
		return
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _frames(8)
	for id in ["common_table", "barrel_board"]:
		var area: Node = game.zone_root.find_child(id, true, false)
		_check(area != null, "physical board table is missing: %s" % id)
		if area == null:
			continue
		var chairs: Array = []
		for candidate in area.find_children("*", "", true, false):
			if str(candidate.name).begins_with("BoardGameChair"):
				chairs.append(candidate)
		_check(chairs.size() >= 2, "board table lacks two chairs: %s" % id)
		_check(area.find_child("%s_Opponent" % id, true, false) != null, "board table lacks its opponent: %s" % id)
		_check(area.find_child("BoardGameBeckoningGesture", true, false) != null, "board table lacks proximity gesture: %s" % id)
	var minigames: Node = game.minigames
	minigames.open_game("draughts")
	await _frames(2)
	_check(minigames.board_grid.get_child_count() == 36, "draughts board did not render 36 squares")
	minigames.call("_on_draughts_square", 6)
	_check(not minigames.draughts_legal_targets.is_empty(), "draughts selection has no highlighted legal destinations")
	minigames.close_game()
	game.queue_free()
	await process_frame
	_finish()

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)

func _finish() -> void:
	print("MINIGAME PRESENTATION VERIFIER: %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	quit(0 if failures.is_empty() else 1)
