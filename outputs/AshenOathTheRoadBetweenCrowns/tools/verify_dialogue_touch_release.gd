extends SceneTree
## Exercise Godot's real touch and emulated mouse dispatch against replacing
## dialogue choices. Removing a pressed control synchronously trips Node.can_process.
const Dispatch = preload("res://scripts/views/dialogue_button_dispatch.gd")
class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, path: String, line: int, code: String, _rationale: String, _notify: bool, kind: int, _traces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s" % [path, line, code])

var log_capture := ErrorLog.new()
var choices := VBoxContainer.new()
var activations := 0
var failures: Array[String] = []

func _initialize() -> void:
	OS.add_logger(log_capture)
	verify.call_deferred()

func replace_choice() -> void:
	for old in choices.get_children():
		choices.remove_child(old)
		old.queue_free()
	var button := Button.new()
	button.text = "Continue"
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.custom_minimum_size = Vector2(180, 65)
	Dispatch.bind_pressed(button, advance_page)
	choices.add_child(button)

func advance_page() -> void:
	activations += 1
	replace_choice()

func verify() -> void:
	Input.emulate_mouse_from_touch = true
	root.size = Vector2i(1280, 720)
	root.add_child(choices)
	replace_choice()
	for tap in 4:
		await process_frame
		for pressed: bool in [true, false]:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.pressed = pressed
			event.position = Vector2(8, 8)
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			await process_frame
		if activations != tap + 1: failures.append("Touch did not advance exactly once: " + str(tap))
	var button := choices.get_child(0) as Button
	button.pressed.emit()
	button.pressed.emit()
	await process_frame
	await process_frame
	if activations != 5: failures.append("Duplicate release crossed dialogue generations")
	button = choices.get_child(0) as Button
	button.pressed.emit()
	button.hide()
	await process_frame
	await process_frame
	if activations != 5: failures.append("A hidden choice committed after its dialogue closed")
	button.show()
	button.pressed.emit()
	replace_choice()
	await process_frame
	await process_frame
	if activations != 5: failures.append("A discarded choice committed after replacement")
	choices.free()
	OS.remove_logger(log_capture)
	print(JSON.stringify({"touch_releases":4,"activations":activations,"failures":failures,"engine_errors":log_capture.errors}))
	quit(0 if failures.is_empty() and log_capture.errors.is_empty() else 1)
