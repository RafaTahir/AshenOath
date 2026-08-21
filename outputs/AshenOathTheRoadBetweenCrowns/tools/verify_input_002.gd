extends SceneTree

const InputRouter = preload("res://scripts/input_router.gd")
const SettingsManager = preload("res://scripts/settings_manager.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var settings := SettingsManager.new()
	settings.name = "Settings"
	root.add_child(settings)
	var router := InputRouter.new()
	router.name = "InputRouter"
	root.add_child(router)
	router.set_settings_manager(settings)
	await process_frame
	router.apply_settings(settings.settings)

	_verify_context_contract(router)
	_verify_pointer_contexts(router)
	await _verify_focus_contract(router)
	_verify_binding_persistence_contract(router, settings)

	var passed := failures.is_empty()
	print("INPUT-002 VERIFIER: %s" % ("PASS - centralized input contexts, pointer ownership, focus, and remap persistence" if passed else "FAIL (%d)" % failures.size()))
	for failure in failures:
		print("- %s" % failure)
	if is_instance_valid(router):
		router.free()
	if is_instance_valid(settings):
		settings.free()
	quit(0 if passed else 1)

func _verify_context_contract(router: Node) -> void:
	for method in ["set_context", "set_gameplay_context", "set_ui_context", "get_context", "focus_first_enabled", "clear_focus"]:
		_check(router.has_method(method), "InputRouter lacks %s" % method)
	_check(router.get_context() == "menu", "router does not start in menu context")
	_check(router.has_signal("input_context_changed"), "context change signal is missing")

func _verify_pointer_contexts(router: Node) -> void:
	router.set_ui_context("dialogue")
	_check(router.get_context() == "dialogue", "dialogue context was not recorded")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "UI context did not release the pointer")
	router.set_context("pause")
	_check(router.get_context() == "pause", "pause context was not recorded")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "pause context did not keep the pointer visible")
	router.set_gameplay_context()
	_check(router.get_context() == "gameplay", "gameplay context was not restored")
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "gameplay context did not capture the pointer")
	router.set_context("not-a-real-context")
	_check(router.get_context() == "menu", "invalid context did not fall back to menu")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "invalid context fallback did not release the pointer")

func _verify_focus_contract(router: Node) -> void:
	var panel := VBoxContainer.new()
	panel.name = "FocusPanel"
	root.add_child(panel)
	var label := Label.new()
	label.text = "not focusable"
	panel.add_child(label)
	var disabled := Button.new()
	disabled.text = "Disabled"
	disabled.disabled = true
	panel.add_child(disabled)
	var active := Button.new()
	active.text = "Active"
	active.focus_mode = Control.FOCUS_ALL
	panel.add_child(active)
	await process_frame
	var focused: Control = router.focus_first_enabled(panel)
	_check(focused == active, "focus helper did not choose the first enabled action")
	_check(root.get_viewport().gui_get_focus_owner() == active, "focus helper did not move controller focus")
	router.clear_focus()
	_check(root.get_viewport().gui_get_focus_owner() == null, "clear_focus left a stale focus owner")
	panel.free()

func _verify_binding_persistence_contract(router: Node, settings: Node) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_O
	var result: Dictionary = router.remap_action("interact", key)
	_check(bool(result.get("ok", false)), "keyboard remap was not accepted through the centralized router")
	_check(typeof(settings.settings.get("custom_bindings", {})) == TYPE_DICTIONARY, "remap did not preserve a dictionary settings shape")
	_check(str(router.action_label("interact")) == "O", "remapped action label was not exposed")
	router.reset_bindings()
	_check(str(router.action_label("interact")) == "E", "reset did not restore the default action")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
