extends SceneTree

## Real native GUI touch/keyboard dispatch against the authored dialogue panel.
## No game world, story choices, actors, save files or browser are constructed.
const DialoguePanel = preload("res://scripts/hud/dialogue_panel.gd")
const HudState = preload("res://scripts/hud/hud_state.gd")

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

var failures: Array[String] = []
var checks := 0
var activations := 0
var choice_activations := 0
var replace_during_press := false
var panel: Node
var state: RefCounted
var view: CanvasLayer

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var error_log := ErrorLog.new()
	OS.add_logger(error_log)
	Input.emulate_mouse_from_touch = true
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = Vector2i(1280, 720)
	view = CanvasLayer.new()
	root.add_child(view)
	state = HudState.new()
	state.hud_root = Control.new()
	state.hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	state.hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(state.hud_root)
	panel = DialoguePanel.new()
	view.add_child(panel)
	panel.configure(view, state)
	var choice := Button.new()
	choice.name = "UnrelatedStoryChoice"
	choice.text = "Unrelated story choice"
	choice.position = Vector2(100, 300)
	choice.size = Vector2(300, 80)
	choice.pressed.connect(func(): choice_activations += 1)
	state.hud_root.add_child(choice)
	for display: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = display
		await _frames(3)
		for method: String in ["touch", "keyboard"]:
			panel.show_opening_scene_skip(_skip)
			await _frames(2)
			var button: Button = state.hud_root.get_node("OpeningSceneSkip")
			_check(button.text == "Skip introduction", "Authored Skip label changed")
			_check(button.get_global_rect() == Rect2(1076, 24, 180, 56), "Authored Skip canvas rectangle changed")
			_check(root.gui_get_focus_owner() == button, "Authored Skip did not receive focus")
			var before := activations
			await _activate(method, button, Vector2(display))
			_check(activations == before + 1, "%s/%s did not activate Skip exactly once through native input" % [display, method])
			_check(state.hud_root.get_node_or_null("OpeningSceneSkip") == null, "Activated Skip retained its live identity")
			_check(root.gui_get_focus_owner() == null, "Activated Skip retained stale focus")
	# The same callback may replace an introduction immediately. The retiring
	# native control must not take the replacement's stable name or focus.
	replace_during_press = true
	panel.show_opening_scene_skip(_skip)
	await _frames(2)
	var old: Button = state.hud_root.get_node("OpeningSceneSkip")
	var before := activations
	await _activate("touch", old, Vector2(root.size))
	var replacement: Button = state.hud_root.get_node_or_null("OpeningSceneSkip")
	_check(activations == before + 1 and replacement != null, "Pressed callback could not install a replacement Skip")
	_check(replacement != null and root.gui_get_focus_owner() == replacement and replacement.text == "Skip introduction", "Replacement Skip lost its stable identity, label or focus")
	replace_during_press = false
	panel.hide_opening_scene_skip()
	panel.hide_opening_scene_skip()
	await _frames(2)
	_check(state.hud_root.get_node_or_null("OpeningSceneSkip") == null, "Repeated Skip removal was not idempotent")
	_check(choice_activations == 0, "Skip input activated an unrelated story choice")
	view.free()
	await _frames(2)
	OS.remove_logger(error_log)
	_check(error_log.errors.is_empty(), "Native Skip dispatch emitted engine diagnostics: " + str(error_log.errors))
	for failure: String in failures:
		printerr("OPENING SKIP INPUT: " + failure)
	print("OPENING SKIP INPUT: %s checks=%d activations=%d (actual touch and focused Enter; 1280x720 canvas, 1280/960 display; no world/choices)" % ["PASS" if failures.is_empty() else "FAIL", checks, activations])
	quit(0 if failures.is_empty() else 1)

func _skip() -> void:
	activations += 1
	panel.hide_opening_scene_skip()
	if replace_during_press:
		panel.show_opening_scene_skip(_skip)

func _activate(method: String, button: Button, display: Vector2) -> void:
	if method == "touch":
		var position := button.get_global_rect().get_center() * display / Vector2(1280, 720)
		for pressed: bool in [true, false]:
			var event := InputEventScreenTouch.new()
			event.index = 3
			event.position = position
			event.pressed = pressed
			Input.parse_input_event(event)
			await _frames(2)
	else:
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
			event.pressed = pressed
			Input.parse_input_event(event)
			await _frames(2)
	await _frames(2)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(valid: bool, detail: String) -> void:
	checks += 1
	if not valid:
		failures.append(detail)
