extends CanvasLayer

signal opened(game_id: String)
signal closed
signal result(game_id: String, outcome: String)

var overlay: PanelContainer
var title_label: Label
var status_label: Label
var board_grid: GridContainer
var active_game := ""
var ttt_board: Array[int] = []
var draughts_board: Array[int] = []
var draughts_selected := -1
var finished := false
var world_control_locked := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 73191
	_build_ui()

func open_game(game_id: String) -> void:
	active_game = game_id
	finished = false
	draughts_selected = -1
	overlay.visible = true
	world_control_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_restart()
	opened.emit(game_id)

func close_game() -> void:
	active_game = ""
	overlay.visible = false
	world_control_locked = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()

func is_open() -> bool:
	return overlay != null and overlay.visible

func play_ttt(index: int) -> bool:
	if active_game != "tic_tac_toe" or finished or index < 0 or index >= 9 or ttt_board[index] != 0:
		return false
	ttt_board[index] = 1
	if _finish_ttt_if_needed(): return true
	var npc_move := _choose_ttt_move()
	if npc_move >= 0: ttt_board[npc_move] = 2
	_finish_ttt_if_needed()
	_render_ttt()
	return true

func play_draughts(from_index: int, to_index: int) -> bool:
	if active_game != "draughts" or finished:
		return false
	var legal := get_draughts_moves(1)
	var chosen: Dictionary = {}
	for move in legal:
		if int(move.from) == from_index and int(move.to) == to_index:
			chosen = move
			break
	if chosen.is_empty(): return false
	_apply_draughts_move(chosen)
	if _finish_draughts_if_needed(): return true
	var npc_moves := get_draughts_moves(-1)
	if not npc_moves.is_empty():
		var captures := npc_moves.filter(func(move): return int(move.capture) >= 0)
		var pool: Array = captures if not captures.is_empty() else npc_moves
		_apply_draughts_move(pool[rng.randi_range(0, pool.size() - 1)])
	_finish_draughts_if_needed()
	_render_draughts()
	return true

func get_draughts_moves(side: int) -> Array:
	var moves: Array = []
	for index in range(36):
		var piece := draughts_board[index]
		if piece == 0 or sign(piece) != side: continue
		var row := index / 6
		var col := index % 6
		var directions: Array = [side]
		if abs(piece) == 2: directions = [-1, 1]
		for row_step in directions:
			for col_step in [-1, 1]:
				var next_row: int = row + row_step
				var next_col: int = col + col_step
				if _inside(next_row, next_col):
					var next := next_row * 6 + next_col
					if draughts_board[next] == 0:
						moves.append({"from":index,"to":next,"capture":-1})
					elif sign(draughts_board[next]) == -side:
						var jump_row: int = row + row_step * 2
						var jump_col: int = col + col_step * 2
						if _inside(jump_row, jump_col) and draughts_board[jump_row * 6 + jump_col] == 0:
							moves.append({"from":index,"to":jump_row * 6 + jump_col,"capture":next})
	var captures := moves.filter(func(move): return int(move.capture) >= 0)
	return captures if not captures.is_empty() else moves

func save_state() -> Dictionary:
	return {}

func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or not event.pressed: return
	if event.is_action("pause"):
		get_viewport().set_input_as_handled()
		close_game()
	elif event is InputEventKey and event.keycode == KEY_R:
		get_viewport().set_input_as_handled()
		_restart()

func _build_ui() -> void:
	overlay = PanelContainer.new()
	overlay.name = "GreyfenMinigameOverlay"
	overlay.position = Vector2(300, 70)
	overlay.size = Vector2(680, 580)
	overlay.visible = false
	add_child(overlay)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.03,0.025,0.98)
	style.border_color = Color(0.48,0.34,0.18)
	style.set_border_width_all(2)
	overlay.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	overlay.add_child(box)
	title_label = Label.new(); title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title_label.add_theme_font_size_override("font_size",28); box.add_child(title_label)
	status_label = Label.new(); status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status_label.custom_minimum_size = Vector2(620,48); box.add_child(status_label)
	board_grid = GridContainer.new(); board_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; board_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(board_grid)
	var actions := HBoxContainer.new(); actions.alignment = BoxContainer.ALIGNMENT_CENTER; box.add_child(actions)
	var restart := Button.new(); restart.text = "Restart (R)"; restart.pressed.connect(_restart); actions.add_child(restart)
	var exit := Button.new(); exit.text = "Exit (Esc)"; exit.pressed.connect(close_game); actions.add_child(exit)

func _restart() -> void:
	finished = false
	if active_game == "tic_tac_toe":
		title_label.text = "Three Marks"
		status_label.text = "Rook: Three marks. No blood. Best game we have."
		ttt_board = [0,0,0,0,0,0,0,0,0]
		_render_ttt()
	elif active_game == "draughts":
		title_label.text = "Greyfen Draughts"
		status_label.text = "Tor: Old soldiers played this before the road closed."
		_setup_draughts()
		_render_draughts()

func _render_ttt() -> void:
	_clear_board(); board_grid.columns = 3
	for index in range(9):
		var button := Button.new(); button.custom_minimum_size = Vector2(130,110); button.add_theme_font_size_override("font_size",42)
		var square := StyleBoxFlat.new(); square.bg_color = Color(0.11,0.095,0.075); square.border_color = Color(0.38,0.28,0.16); square.set_border_width_all(1); button.add_theme_stylebox_override("normal",square)
		button.add_theme_color_override("font_color",Color(0.92,0.75,0.40))
		button.text = ["","X","O"][ttt_board[index]]; button.disabled = finished or ttt_board[index] != 0
		button.pressed.connect(func(): play_ttt(index)); board_grid.add_child(button)

func _choose_ttt_move() -> int:
	for side in [2,1]:
		for index in range(9):
			if ttt_board[index] != 0: continue
			ttt_board[index] = side
			var wins: bool = _ttt_winner() == side
			ttt_board[index] = 0
			if wins: return index
	if ttt_board[4] == 0: return 4
	var corners := [0,2,6,8].filter(func(index): return ttt_board[index] == 0)
	if not corners.is_empty(): return corners[rng.randi_range(0,corners.size()-1)]
	var open: Array = range(9).filter(func(index): return ttt_board[index] == 0)
	return -1 if open.is_empty() else open[rng.randi_range(0,open.size()-1)]

func _finish_ttt_if_needed() -> bool:
	var winner := _ttt_winner()
	if winner != 0:
		finished = true; status_label.text = "Rook: You win. Tell no one." if winner == 1 else "Rook: Board took my side. Happens."
		result.emit("tic_tac_toe", "win" if winner == 1 else "loss"); _render_ttt(); return true
	if not ttt_board.has(0):
		finished = true; status_label.text = "Rook: Draw. Even the board refuses judgment."; result.emit("tic_tac_toe","draw"); _render_ttt(); return true
	return false

func _ttt_winner() -> int:
	for line in [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]]:
		if ttt_board[line[0]] != 0 and ttt_board[line[0]] == ttt_board[line[1]] and ttt_board[line[1]] == ttt_board[line[2]]: return ttt_board[line[0]]
	return 0

func _setup_draughts() -> void:
	draughts_board.resize(36); draughts_board.fill(0); draughts_selected = -1
	for row in range(2):
		for col in range(6):
			if (row + col) % 2 == 1: draughts_board[row*6+col] = 1
	for row in range(4,6):
		for col in range(6):
			if (row + col) % 2 == 1: draughts_board[row*6+col] = -1

func _render_draughts() -> void:
	_clear_board(); board_grid.columns = 6
	for index in range(36):
		var button := Button.new(); button.custom_minimum_size = Vector2(66,58); button.add_theme_font_size_override("font_size",32)
		button.text = {0:"",1:"●",2:"♛",-1:"○",-2:"♕"}.get(draughts_board[index],"")
		var square := StyleBoxFlat.new(); square.bg_color = Color(0.48,0.35,0.21) if ((index/6)+(index%6))%2 == 0 else Color(0.10,0.075,0.055); square.border_color = Color(0.30,0.21,0.12); square.set_border_width_all(1); button.add_theme_stylebox_override("normal",square)
		button.add_theme_color_override("font_color",Color(0.94,0.70,0.28) if draughts_board[index] > 0 else Color(0.86,0.86,0.80))
		button.pressed.connect(func(): _on_draughts_square(index)); board_grid.add_child(button)

func _on_draughts_square(index: int) -> void:
	if finished: return
	if draughts_selected < 0:
		if draughts_board[index] > 0: draughts_selected = index; status_label.text = "Choose where the piece should go."
	else:
		if not play_draughts(draughts_selected,index): status_label.text = "That piece cannot move there."
		draughts_selected = -1

func _apply_draughts_move(move: Dictionary) -> void:
	var piece := draughts_board[int(move.from)]; draughts_board[int(move.from)] = 0; draughts_board[int(move.to)] = piece
	if int(move.capture) >= 0: draughts_board[int(move.capture)] = 0
	var row := int(move.to) / 6
	if piece == 1 and row == 5: draughts_board[int(move.to)] = 2; status_label.text = "Tor: Crowned. Lucky thing."
	elif piece == -1 and row == 0: draughts_board[int(move.to)] = -2

func _finish_draughts_if_needed() -> bool:
	var player_moves := get_draughts_moves(1); var npc_moves := get_draughts_moves(-1)
	if not player_moves.is_empty() and not npc_moves.is_empty(): return false
	finished = true
	var player_won := npc_moves.is_empty() and not player_moves.is_empty()
	status_label.text = "Tor: You saw the trap before it closed." if player_won else "Tor: Forward is not always out."
	result.emit("draughts","win" if player_won else "loss"); _render_draughts(); return true

func _inside(row: int, col: int) -> bool:
	return row >= 0 and row < 6 and col >= 0 and col < 6

func _clear_board() -> void:
	for child in board_grid.get_children(): child.queue_free()
