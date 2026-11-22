extends CanvasLayer

signal opened(game_id: String)
signal closed
signal result(game_id: String, outcome: String)
signal state_changed

const Square = preload("res://scripts/board_square.gd")
const ChessRules = preload("res://scripts/third_party/chess/Chess.gd")
const ChessOpponent = preload("res://scripts/third_party/chess/ChessEngine.gd")

var overlay: PanelContainer
var title_label: Label
var status_label: Label
var board_grid: GridContainer
var active_game := ""
var ttt_board: Array[int] = []
var draughts_board: Array[int] = []
var draughts_selected := -1
var draughts_legal_targets: Array[int] = []
var finished := false
var world_control_locked := false
var input_source: Node
var rng := RandomNumberGenerator.new()
var opponent_id := "rook"
var sessions: Dictionary = {}
var chess
var chess_moves: Array[String] = []
var chess_selected := -1
var chess_targets: Array[int] = []
var thinking := false
var generation := 0
var promotion_from := -1
var promotion_to := -1
var promotion_actions: GridContainer
var game_picker: OptionButton
var resign_button: Button
var draughts_chain := -1
var draughts_quiet := 0
var _was_paused := false
var _display: Dictionary = {}
var _unit := 1.0
var _layout: Dictionary = {}
var _settings_source: Node

func set_display_metrics(metrics: Dictionary) -> void:
	_display = metrics.duplicate()
	if overlay != null: _apply_display()

func _apply_display() -> void:
	var scale := 1.0
	if is_instance_valid(_settings_source):
		scale = float(_settings_source.settings.get("subtitle_scale",1.0))
	_layout = preload("res://scripts/hud_layout_policy.gd").resolve(get_viewport().get_visible_rect().size,_display,scale,"touch" if bool(_display.get("coarse_pointer",false)) else "keyboard")
	_unit = float(_layout.unit_scale)
	var safe: Rect2 = _layout.safe_rect
	var margin := float(_layout.margin)
	overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	overlay.position = safe.position+Vector2.ONE*margin
	overlay.size = (safe.size-Vector2.ONE*margin*2.0).max(Vector2.ONE)
	var panel := overlay.get_theme_stylebox("panel") as StyleBoxFlat
	if panel != null: panel.set_content_margin_all(float(_layout.padding))
	title_label.add_theme_font_size_override("font_size",int(_layout.fonts.heading))
	title_label.visible = not bool(_layout.short_display)
	status_label.add_theme_font_size_override("font_size",int(_layout.fonts.caption))
	game_picker.custom_minimum_size.y = float(_layout.button_min_height)
	game_picker.add_theme_font_size_override("font_size",int(_layout.fonts.button))
	_apply_controls(overlay)

func _apply_controls(parent: Node) -> void:
	for child in parent.get_children():
		if child is Square:
			var cell := 96.0 if active_game == "tic_tac_toe" else (56.0 if active_game == "draughts" else 48.0)
			child.custom_minimum_size = Vector2.ONE*cell*_unit
		elif child is Button and child != game_picker:
			child.custom_minimum_size = Vector2(80.0*_unit,float(_layout.button_min_height))
			child.add_theme_font_size_override("font_size",int(_layout.fonts.button))
		if child is BoxContainer: child.add_theme_constant_override("separation",float(_layout.gap))
		_apply_controls(child)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 73191

func setup(router: Node, preferences: Node = null) -> void:
	input_source = router
	_settings_source = preferences

func open_game(game_id: String, person: String = "rook") -> void:
	if overlay == null:
		_build_ui()
	active_game = game_id
	opponent_id = person if person in ["rook", "blacksmith_tor"] else "rook"
	finished = false
	draughts_selected = -1
	draughts_legal_targets.clear()
	overlay.visible = true
	world_control_locked = true
	_set_ui_pointer()
	_was_paused = get_tree().paused
	get_tree().paused = true
	_open_session()
	_apply_display()
	call_deferred("_focus_first_board_button")
	opened.emit(game_id)

func close_game() -> void:
	if overlay == null:
		return
	_store_session()
	generation += 1
	thinking = false
	active_game = ""
	overlay.visible = false
	world_control_locked = false
	get_tree().paused = _was_paused
	_set_gameplay_pointer()
	closed.emit()

func _set_ui_pointer() -> void:
	if input_source != null and input_source.has_method("set_ui_context"):
		input_source.set_ui_context("minigame")
	elif input_source != null and input_source.has_method("release_pointer"):
		input_source.release_pointer()

func _set_gameplay_pointer() -> void:
	if input_source != null and input_source.has_method("set_gameplay_context"):
		input_source.set_gameplay_context()
	elif input_source != null and input_source.has_method("restore_gameplay_pointer"):
		input_source.restore_gameplay_pointer()

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
	_store_session()
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
	draughts_chain = int(chosen.to) if int(chosen.capture) >= 0 and not bool(chosen.get("crowned", false)) else -1
	if draughts_chain >= 0:
		var continuation := _piece_captures(draughts_chain, 1)
		if not continuation.is_empty():
			draughts_selected = draughts_chain
			draughts_legal_targets.assign(continuation.map(func(move): return int(move.to)))
			status_label.text = "Continue the capture."
			_render_draughts(); _store_session(); return true
	draughts_chain = -1
	if _finish_draughts_if_needed(): return true
	var npc_moves := get_draughts_moves(-1)
	while not npc_moves.is_empty():
		var move: Dictionary = _choose_draughts_move(npc_moves)
		_apply_draughts_move(move)
		npc_moves = _piece_captures(int(move.to), -1) if int(move.capture) >= 0 and not bool(move.get("crowned", false)) else []
	_finish_draughts_if_needed()
	_render_draughts()
	_store_session()
	return true

func get_draughts_moves(side: int) -> Array:
	var moves: Array = []
	for index in range(36):
		if side == 1 and draughts_chain >= 0 and index != draughts_chain: continue
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
	_capture_session()
	return {"sessions": sessions.duplicate(true)}

func load_state(data: Dictionary) -> void:
	generation += 1
	thinking = false
	sessions.clear()
	var raw: Variant = data.get("sessions", {})
	if raw is Dictionary:
		for person in ["rook", "blacksmith_tor"]:
			for mode in ["tic_tac_toe", "draughts", "chess"]:
				var key: String = str(person) + ":" + str(mode)
				if raw.get(key) is Dictionary:
					sessions[key] = raw[key].duplicate(true)
	if overlay != null: overlay.hide()
	active_game = ""
	world_control_locked = false

func _session_key() -> String:
	return opponent_id + ":" + active_game

func _capture_session() -> void:
	if active_game.is_empty(): return
	sessions[_session_key()] = {"ttt": ttt_board.duplicate(), "draughts": draughts_board.duplicate(), "chain": draughts_chain, "quiet": draughts_quiet, "moves": chess_moves.duplicate(), "finished": finished}

func _store_session() -> void:
	_capture_session()
	state_changed.emit()

func _open_session() -> void:
	generation += 1
	thinking = false
	chess_selected = -1; chess_targets.clear(); promotion_from = -1
	promotion_actions.hide()
	game_picker.select(["tic_tac_toe", "draughts", "chess"].find(active_game))
	title_label.text = ("Three Marks" if active_game == "tic_tac_toe" else "Greyfen Draughts - 6 x 6") + " - " + ("Rook" if opponent_id == "rook" else "Tor")
	resign_button.visible = active_game != "tic_tac_toe"
	var saved: Dictionary = sessions.get(_session_key(), {})
	if saved.is_empty():
		_restart(); return
	finished = bool(saved.get("finished", false))
	if active_game == "chess":
		chess = ChessRules.new()
		chess_moves.clear()
		var history: Variant = saved.get("moves", [])
		if not history is Array or history.size() > 512:
			_restart(); status_label.text = "The saved board could not be restored."; return
		for raw in history:
			var found = null
			if raw is String:
				for move in chess.generate_legal_moves():
					if _move_key(move) == raw: found = move; break
			if found == null:
				_restart(); status_label.text = "The saved board contained an invalid move. A new board is ready."; return
			chess.play_move(found); chess_moves.append(str(raw))
		finished = finished or chess.get_data() != ChessRules.RESULT.ONGOING
		if finished: status_label.text = "Finished board. Start another when you are ready."
		_render_chess()
		if chess.turn and not finished: _chess_reply()
	else:
		var raw: Variant = saved.get("ttt" if active_game == "tic_tac_toe" else "draughts", [])
		var count := 9 if active_game == "tic_tac_toe" else 36
		if not raw is Array or raw.size() != count:
			_restart(); return
		for cell in raw:
			if typeof(cell) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(cell)) or float(cell) != float(int(cell)) or int(cell) not in ([0,1,2] if count == 9 else [-2,-1,0,1,2]):
				_restart(); return
		if count == 9:
			ttt_board.assign(raw); _render_ttt()
		else:
			draughts_board.assign(raw)
			draughts_chain = clampi(int(saved.get("chain", -1)), -1, 35)
			draughts_quiet = clampi(int(saved.get("quiet", 0)), 0, 80)
			_render_draughts()
		status_label.text = "Finished board. Start another when you are ready." if finished else "Your unfinished board is restored."

func _switch_game(index: int) -> void:
	_store_session()
	active_game = ["tic_tac_toe", "draughts", "chess"][index]
	_open_session()

func _resign() -> void:
	if finished: return
	generation += 1; thinking = false
	_finish("loss", "You concede this board. No wager or relationship is lost.")
	if active_game == "chess": _render_chess()
	else: _render_draughts()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or not event.pressed: return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_game()
	elif event is InputEventKey and event.keycode == KEY_R:
		get_viewport().set_input_as_handled()
		_restart()

func _build_ui() -> void:
	overlay = PanelContainer.new()
	overlay.name = "GreyfenMinigameOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 12; overlay.offset_top = 12
	overlay.offset_right = -12; overlay.offset_bottom = -12
	overlay.visible = false
	add_child(overlay)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018,0.020,0.022,0.98)
	style.border_color = Color(0.62,0.43,0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	overlay.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	overlay.add_child(box)
	title_label = Label.new(); title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title_label.add_theme_font_size_override("font_size",22); box.add_child(title_label)
	game_picker = OptionButton.new(); game_picker.custom_minimum_size.y = 48
	for mode in ["Three Marks", "Greyfen Draughts - 6 x 6", "Chess"]: game_picker.add_item(mode)
	game_picker.item_selected.connect(_switch_game); box.add_child(game_picker)
	status_label = Label.new(); status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(status_label)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_child(scroll)
	var center := CenterContainer.new(); center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; center.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.add_child(center)
	board_grid = GridContainer.new(); board_grid.add_theme_constant_override("h_separation",0); board_grid.add_theme_constant_override("v_separation",0); center.add_child(board_grid)
	promotion_actions = GridContainer.new(); promotion_actions.columns = 2; promotion_actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; box.add_child(promotion_actions); promotion_actions.hide()
	for kind in ["q", "r", "b", "n"]:
		var choice := Button.new(); choice.text = {"q":"Queen", "r":"Rook", "b":"Bishop", "n":"Knight"}[kind]; _style_action_button(choice); choice.pressed.connect(_promote.bind(kind)); promotion_actions.add_child(choice)
	var actions := HBoxContainer.new(); actions.alignment = BoxContainer.ALIGNMENT_CENTER; box.add_child(actions)
	var restart := Button.new(); restart.text = "New board"; _style_action_button(restart); restart.pressed.connect(_restart); actions.add_child(restart)
	resign_button = Button.new(); resign_button.text = "Resign"; _style_action_button(resign_button); resign_button.pressed.connect(_resign); actions.add_child(resign_button)
	var exit := Button.new(); exit.text = "Return"; _style_action_button(exit); exit.pressed.connect(close_game); actions.add_child(exit)

func _restart() -> void:
	generation += 1; thinking = false
	chess_selected = -1; chess_targets.clear(); promotion_from = -1
	promotion_actions.hide()
	finished = false
	if active_game == "tic_tac_toe":
		title_label.text = "Three Marks - " + ("Rook, casual" if opponent_id == "rook" else "Tor, considered")
		status_label.text = "Three in a row. No wager is required."
		ttt_board = [0,0,0,0,0,0,0,0,0]
		_render_ttt()
	elif active_game == "draughts":
		title_label.text = "Greyfen Draughts - 6 x 6 - " + ("Rook, casual" if opponent_id == "rook" else "Tor, considered")
		status_label.text = "Captures are compulsory; continue a jumping piece. Crowning ends that turn."
		_setup_draughts()
		_render_draughts()
	elif active_game == "chess":
		chess = ChessRules.new(); chess_moves.clear()
		_render_chess()
	_store_session()

func _render_ttt() -> void:
	_clear_board(); board_grid.columns = 3
	for index in range(9):
		var button := Square.new(); button.custom_minimum_size = Vector2(96,96)
		var square := StyleBoxFlat.new(); square.bg_color = Color(0.11,0.095,0.075); square.border_color = Color(0.38,0.28,0.16); square.set_border_width_all(1); button.add_theme_stylebox_override("normal",square)
		button.add_theme_color_override("font_color",Color(0.92,0.75,0.40))
		_style_board_button(button, square)
		button.piece = "mark" if ttt_board[index] != 0 else ""; button.brass = ttt_board[index] == 1
		button.tooltip_text = "Square %d: %s" % [index+1,["empty","your mark","opponent's mark"][ttt_board[index]]]; button.disabled = finished or ttt_board[index] != 0
		button.pressed.connect(func(): play_ttt(index)); board_grid.add_child(button)
	call_deferred("_focus_first_board_button")
	if not _layout.is_empty(): _apply_controls(board_grid)

func _choose_ttt_move() -> int:
	if opponent_id == "rook" and rng.randf() < 0.4:
		var empty: Array = range(9).filter(func(index): return ttt_board[index] == 0)
		return -1 if empty.is_empty() else int(empty.pick_random())
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
		finished = true; status_label.text = "You win. A well-kept line." if winner == 1 else "Your opponent has three in a row."
		_finish("win" if winner == 1 else "loss", status_label.text); _render_ttt(); return true
	if not ttt_board.has(0):
		_finish("draw", "Draw. Even the board refuses judgment."); _render_ttt(); return true
	return false

func _ttt_winner() -> int:
	for line in [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]]:
		if ttt_board[line[0]] != 0 and ttt_board[line[0]] == ttt_board[line[1]] and ttt_board[line[1]] == ttt_board[line[2]]: return ttt_board[line[0]]
	return 0

func _setup_draughts() -> void:
	draughts_chain = -1; draughts_quiet = 0
	draughts_board.resize(36); draughts_board.fill(0); draughts_selected = -1; draughts_legal_targets.clear()
	for row in range(2):
		for col in range(6):
			if (row + col) % 2 == 1: draughts_board[row*6+col] = 1
	for row in range(4,6):
		for col in range(6):
			if (row + col) % 2 == 1: draughts_board[row*6+col] = -1

func _render_draughts() -> void:
	_clear_board(); board_grid.columns = 6
	for index in range(36):
		var button := Square.new(); button.custom_minimum_size = Vector2(56,56)
		button.piece = "" if draughts_board[index] == 0 else ("crown" if absi(draughts_board[index]) == 2 else "disc"); button.brass = draughts_board[index] > 0
		button.tooltip_text = "Square %d" % (index + 1)
		var square := StyleBoxFlat.new(); square.bg_color = Color(0.48,0.35,0.21) if ((index/6)+(index%6))%2 == 0 else Color(0.10,0.075,0.055); square.border_color = Color(0.30,0.21,0.12); square.set_border_width_all(1)
		if index == draughts_selected:
			square.bg_color = Color(0.42, 0.24, 0.08)
			square.border_color = Color(1.0, 0.76, 0.30)
			square.set_border_width_all(3)
		elif index in draughts_legal_targets:
			square.bg_color = Color(0.24, 0.34, 0.20)
			square.border_color = Color(0.64, 0.82, 0.42)
			square.set_border_width_all(2)
		_style_board_button(button, square)
		button.add_theme_color_override("font_color",Color(0.94,0.70,0.28) if draughts_board[index] > 0 else Color(0.86,0.86,0.80))
		button.pressed.connect(func(): _on_draughts_square(index)); board_grid.add_child(button)
	call_deferred("_focus_first_board_button")
	if not _layout.is_empty(): _apply_controls(board_grid)

func _focus_first_board_button() -> void:
	if board_grid == null or not is_instance_valid(board_grid):
		return
	for child in board_grid.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			return

func _on_draughts_square(index: int) -> void:
	if finished: return
	if draughts_board[index] > 0 and draughts_chain < 0: draughts_selected = -1
	if draughts_selected < 0:
		if draughts_board[index] > 0:
			draughts_selected = index
			draughts_legal_targets.clear()
			for move in get_draughts_moves(1):
				if int(move.from) == index:
					draughts_legal_targets.append(int(move.to))
			status_label.text = "Choose a highlighted destination."
			_render_draughts()
	else:
		var from_index := draughts_selected
		if not play_draughts(from_index,index):
			status_label.text = "That piece cannot move there."
		else:
			if draughts_chain < 0:
				draughts_selected = -1
				draughts_legal_targets.clear()
			_render_draughts()

func _style_action_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(80, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.046, 0.037, 0.92)
	normal.border_color = Color(0.50, 0.37, 0.19)
	normal.set_border_width_all(1)
	var focus := normal.duplicate()
	focus.bg_color = Color(0.18, 0.11, 0.05, 0.98)
	focus.border_color = Color(1.0, 0.72, 0.28)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", focus)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("pressed", focus)
	button.add_theme_color_override("font_color", Color(0.88, 0.80, 0.64))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.56))

func _style_board_button(button: Button, normal: StyleBoxFlat) -> void:
	var focus := normal.duplicate()
	focus.border_color = Color(1.0, 0.74, 0.28)
	focus.set_border_width_all(3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", focus)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("pressed", focus)
	button.focus_mode = Control.FOCUS_ALL

func _apply_draughts_move(move: Dictionary) -> void:
	var piece := draughts_board[int(move.from)]; draughts_board[int(move.from)] = 0; draughts_board[int(move.to)] = piece
	if int(move.capture) >= 0: draughts_board[int(move.capture)] = 0
	draughts_quiet = 0 if int(move.capture) >= 0 or abs(piece) == 1 else draughts_quiet + 1
	var row := int(move.to) / 6
	if piece == 1 and row == 5: draughts_board[int(move.to)] = 2
	elif piece == -1 and row == 0: draughts_board[int(move.to)] = -2
	move["crowned"] = absi(draughts_board[int(move.to)]) != absi(piece)

func _finish_draughts_if_needed() -> bool:
	if draughts_quiet >= 80:
		_finish("draw", "Draw by forty quiet moves each."); _render_draughts(); return true
	var player_moves := get_draughts_moves(1); var npc_moves := get_draughts_moves(-1)
	if not player_moves.is_empty() and not npc_moves.is_empty(): return false
	finished = true
	var player_won := npc_moves.is_empty() and not player_moves.is_empty()
	status_label.text = "You win. You saw the trap before it closed." if player_won else "Your opponent wins. Forward is not always out."
	_finish("win" if player_won else "loss", status_label.text); _render_draughts(); return true

func _inside(row: int, col: int) -> bool:
	return row >= 0 and row < 6 and col >= 0 and col < 6

func _clear_board() -> void:
	for child in board_grid.get_children():
		board_grid.remove_child(child); child.queue_free()

func _piece_captures(index: int, side: int) -> Array:
	return get_draughts_moves(side).filter(func(move): return int(move.from) == index and int(move.capture) >= 0)

func _choose_draughts_move(moves: Array) -> Dictionary:
	if opponent_id == "rook": return moves[rng.randi_range(0, moves.size()-1)]
	var best: Dictionary = moves[0]
	var score := -10000
	for move: Dictionary in moves:
		var before := draughts_board.duplicate(); var quiet := draughts_quiet
		_apply_draughts_move(move)
		var risk := 0
		for reply: Dictionary in get_draughts_moves(1):
			if int(reply.capture) == int(move.to): risk = 4
		var value := (5 if int(move.capture) >= 0 else 0) + (3 if bool(move.get("crowned",false)) else 0) - risk
		draughts_board = before; draughts_quiet = quiet
		if value > score: score = value; best = move
	return best

func _finish(outcome: String, text: String) -> void:
	finished = true
	status_label.text = text
	_store_session()
	result.emit(active_game, outcome)

func _move_key(move) -> String:
	return "%02d%02d%s" % [move.from_square, move.to_square, str(move.promotion).to_lower() if move.promotion != null else ""]

func _render_chess() -> void:
	_clear_board(); board_grid.columns = 8
	title_label.text = "Chess - " + ("Rook, casual" if opponent_id == "rook" else "Tor, considered")
	if not finished:
		status_label.text = "Choose a promotion." if promotion_from >= 0 else ("%s is considering the board." % ("Rook" if opponent_id == "rook" else "Tor") if thinking or chess.turn else ("Your king is in check." if chess.in_check() else "Your move. You hold the brass pieces."))
	for index in range(64):
		var square := Square.new(); square.custom_minimum_size = Vector2(48,48)
		var piece: Variant = chess.pieces[index]
		square.piece = "" if piece == null else str(piece)
		square.brass = piece != null and not ChessRules.piece_color(str(piece))
		square.tooltip_text = ChessRules.square_get_name(index) + ": " + ("empty" if piece == null else (("brass " if square.brass else "silver ") + {"p":"pawn","r":"rook","n":"knight","b":"bishop","q":"queen","k":"king"}.get(str(piece).to_lower(), "piece")))
		var style := StyleBoxFlat.new(); style.bg_color = Color(0.12,0.075,0.045) if ChessRules.square_is_dark(index) else Color(0.42,0.29,0.15)
		style.border_color = Color(0.20,0.15,0.09); style.set_border_width_all(1)
		if index == chess_selected: style.bg_color = Color(0.62,0.40,0.12)
		elif index in chess_targets: style.bg_color = Color(0.22,0.39,0.29)
		_style_board_button(square,style)
		square.disabled = finished or thinking or chess.turn or promotion_from >= 0
		square.pressed.connect(_on_chess_square.bind(index)); board_grid.add_child(square)
	call_deferred("_focus_first_board_button")
	if not _layout.is_empty(): _apply_controls(board_grid)

func _on_chess_square(index: int) -> void:
	if finished or thinking or chess.turn or promotion_from >= 0: return
	if index in chess_targets:
		var promotions: Array = chess.generate_legal_moves().filter(func(move): return move.from_square == chess_selected and move.to_square == index and move.promotion != null)
		if not promotions.is_empty():
			promotion_from = chess_selected; promotion_to = index
			promotion_actions.show(); _render_chess(); promotion_actions.get_child(0).grab_focus(); return
		_play_chess_move(chess_selected,index,""); return
	chess_selected = index
	chess_targets.clear()
	for move in chess.generate_legal_moves():
		if move.from_square == index and not chess_targets.has(move.to_square): chess_targets.append(move.to_square)
	_render_chess()

func _promote(kind: String) -> void:
	if promotion_from < 0: return
	var from := promotion_from; var to := promotion_to
	promotion_from = -1; promotion_actions.hide()
	_play_chess_move(from,to,kind)

func _play_chess_move(from: int, to: int, promotion: String) -> void:
	for move in chess.generate_legal_moves():
		if move.from_square != from or move.to_square != to: continue
		if ("" if move.promotion == null else str(move.promotion).to_lower()) != promotion: continue
		chess.play_move(move); chess_moves.append(_move_key(move))
		chess_selected = -1; chess_targets.clear()
		if not _finish_chess_if_needed(): _chess_reply()
		_store_session(); _render_chess(); return

func _chess_reply() -> void:
	if thinking or finished: return
	thinking = true; _render_chess()
	var token := generation
	var position = chess.duplicate()
	var legal: Array = position.generate_legal_moves()
	var chosen = null
	if opponent_id == "rook":
		await get_tree().create_timer(0.3,true).timeout
		if not legal.is_empty(): chosen = legal[rng.randi_range(0,legal.size()-1)]
	else:
		var engine = ChessOpponent.new(); engine.search_depth = 3; engine.quiescence_depth = 3
		engine.cancelled = func(): return generation != token or not is_open()
		var answer: Array = await engine.get_move(position)
		chosen = answer[1]
	if generation != token or not is_open(): return
	thinking = false
	if chosen != null:
		for move in chess.generate_legal_moves():
			if _move_key(move) == _move_key(chosen):
				chess.play_move(move); chess_moves.append(_move_key(move)); break
	_finish_chess_if_needed(); _store_session(); _render_chess()

func _finish_chess_if_needed() -> bool:
	var ending: int = chess.get_data()
	if ending == ChessRules.RESULT.ONGOING: return false
	if ending == ChessRules.RESULT.CHECKMATE:
		_finish("win" if chess.turn else "loss", "Checkmate. " + ("You win." if chess.turn else "Your opponent wins."))
	else:
		_finish("draw", "Draw - " + {ChessRules.RESULT.STALEMATE:"stalemate",ChessRules.RESULT.INSUFFICIENT:"insufficient material",ChessRules.RESULT.FIFTY_MOVE:"fifty-move rule",ChessRules.RESULT.THREEFOLD:"threefold repetition"}.get(ending,"drawn position") + ".")
	return true
