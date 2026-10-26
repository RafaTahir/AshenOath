extends "res://scripts/hud/hud_component.gd"
## Hud input: explicit view operations; requests leave through typed signals.

func set_input_source(source: Node) -> void:
	input_source = source
	if is_instance_valid(source):
		_settings_source = source.get("settings_manager")
	if input_source != null:
		set_input_device(str(input_source.get("active_device")))

func set_gamepad_profile(profile: Dictionary) -> void:
	gamepad_profile = profile.duplicate(true)
	if input_device == "gamepad" and active_menu in ["controls", "remap"] and not remap_waiting:
		if active_menu == "controls":
			show_controls_menu(controls_back_target)
		else:
			show_remap_menu(remap_back_target, remap_page)

func restore_input_focus() -> void:
	if _journey_load_active:
		if not _journey_load_applying:
			_journey_cancel_button.grab_focus()
		return
	if dialogue_layer != null and dialogue_layer.visible:
		_restore_dialogue_reading_state()
		return
	if menu_layer != null and menu_layer.visible and input_source != null and input_source.has_method("focus_first_enabled"):
		navigation.restore(_rendered_screen, menu_layer)

func _set_ui_pointer(context: String = "menu") -> void:
	if input_source != null and input_source.has_method("set_ui_context"):
		input_source.set_ui_context(context)
	elif input_source != null and input_source.has_method("release_pointer"):
		input_source.release_pointer()

func _set_gameplay_pointer() -> void:
	if input_source != null and input_source.has_method("set_gameplay_context"):
		input_source.set_gameplay_context()
	elif input_source != null and input_source.has_method("restore_gameplay_pointer"):
		input_source.restore_gameplay_pointer()

func set_input_device(device: String) -> void:
	input_device = device if device in ["keyboard_mouse", "gamepad", "touch"] else "keyboard_mouse"
	_queue_responsive_layout()
	if raw_prompt != "":
		if not _interaction_prompt_model.is_empty():
			set_interaction_prompt(_interaction_prompt_model)
		else:
			set_prompt(raw_prompt)
	if raw_hint != "":
		hint_label.text = _format_input_text(raw_hint)
	update_equipment(last_potions, last_bombs, last_oil_name, last_arrow_count, last_arrow_type, last_weapon_name, last_remedy_id, last_tool_id, last_oil_seconds)
	_refresh_story_focus()

func _action_label(action: String) -> String:
	if input_source != null and input_source.has_method("action_label"):
		return "[%s]" % str(input_source.action_label(action))
	return "[%s]" % action.capitalize()

func _format_input_text(text: String) -> String:
	if input_source != null and input_source.has_method("describe_action"):
		var block: Dictionary = input_source.describe_action("block")
		var guard_verb := "Toggle" if str(block.get("mode", "hold")) == "toggle" else "Hold"
		var replacements := {
			"Left click": _action_label("light_attack"),
			"Left mouse": _action_label("light_attack"),
			"Right mouse": _action_label("heavy_attack"),
			"Space": _action_label("dodge"),
			"Tap Q": "Press " + _action_label("block"),
			"Hold Q": guard_verb + " " + _action_label("block"),
			"Hold C": "Hold " + _action_label("oathfire_beam"),
			"Press E": ("Tap " if input_device == "touch" else "Press ") + _action_label("interact")
		}
		var contextual_text := text
		for phrase in replacements:
			contextual_text = contextual_text.replace(str(phrase), str(replacements[phrase]))
		if contextual_text.begins_with("E - "):
			contextual_text = _action_label("interact") + " " + contextual_text.trim_prefix("E - ")
		elif contextual_text.begins_with("E  "):
			contextual_text = _action_label("interact") + " " + contextual_text.trim_prefix("E  ")
		return contextual_text
	if input_device == "touch":
		var touch_text := text
		touch_text = touch_text.replace("Left click", "[Strike]")
		touch_text = touch_text.replace("Left mouse", "[Strike]")
		touch_text = touch_text.replace("Right mouse", "[Heavy]")
		touch_text = touch_text.replace("Space", "[Dodge]")
		touch_text = touch_text.replace("Tap Q", "Tap [Guard]")
		touch_text = touch_text.replace("Hold Q", "Hold [Guard]")
		touch_text = touch_text.replace("Hold C", "Hold [Oath]")
		touch_text = touch_text.replace("Press E", "Tap [Use]")
		if touch_text.begins_with("E - "):
			touch_text = "[Use]  " + touch_text.trim_prefix("E - ")
		elif touch_text.begins_with("E  "):
			touch_text = "[Use]  " + touch_text.trim_prefix("E  ")
		return touch_text
	if input_device != "gamepad":
		return text
	var formatted := text
	formatted = formatted.replace("Left click", "[RB]")
	formatted = formatted.replace("Left mouse", "[RB]")
	formatted = formatted.replace("Right mouse", "[RT]")
	formatted = formatted.replace("Space", "[B]")
	formatted = formatted.replace("Tap Q", "Tap [LB]")
	formatted = formatted.replace("Hold Q", "Hold [LB]")
	formatted = formatted.replace("Hold C", "Hold [LT]")
	formatted = formatted.replace("Press E", "Press [A]")
	if formatted.begins_with("E - "):
		formatted = "[A]  " + formatted.trim_prefix("E - ")
	elif formatted.begins_with("E  "):
		formatted = "[A]  " + formatted.trim_prefix("E  ")
	return formatted

func _focus_after_rebuild(container: Node) -> void:
	await view.get_tree().process_frame
	_focus_first_enabled(container)

func _focus_first_enabled(container: Node) -> void:
	if container == null or not is_instance_valid(container):
		return
	if input_source != null and input_source.has_method("focus_first_enabled"):
		if input_source.focus_first_enabled(container) != null:
			return
	for child in container.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			return

func handle_input(event: InputEvent) -> void:
	if _journey_load_active:
		if event.is_action_pressed("ui_cancel"):
			_cancel_journey_load()
			view.get_viewport().set_input_as_handled()
		return
	if _capture_remap_input(event):
		return
	if _handle_compact_journal_direction(event):
		return
	if _handle_evidence_direction(event):
		return
	if dialogue_layer == null or not dialogue_layer.visible:
		_cancel_dialogue_press()
		return
	# Native Buttons and ScrollContainers own touch press/release and drag
	# cancellation. Intercepting those contacts here prevented choice scrolling.
	if event is InputEventScreenTouch or event is InputEventScreenDrag or ((event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1):
		_cancel_dialogue_press()
		return
	var focused_control: Control = view.get_viewport().gui_get_focus_owner()
	var reader_focused: bool = focused_control == dialogue_text or focused_control == _decision_details
	var navigation_direction: int = 0
	var leave_reader: bool = false
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		var code: int = key_event.keycode if key_event.keycode != KEY_NONE else key_event.physical_keycode
		if key_event.pressed and not key_event.echo:
			if code == KEY_TAB:
				navigation_direction = -1 if key_event.shift_pressed else 1
			elif code in [KEY_UP, KEY_DOWN] and not reader_focused:
				navigation_direction = -1 if code == KEY_UP else 1
			elif code == KEY_RIGHT and reader_focused:
				leave_reader = true
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event.is_action_pressed("ui_right") and reader_focused:
			leave_reader = true
		elif not reader_focused and event.is_action_pressed("ui_up"):
			navigation_direction = -1
		elif not reader_focused and event.is_action_pressed("ui_down"):
			navigation_direction = 1
	if leave_reader:
		_cancel_dialogue_press()
		_focus_first_enabled(dialogue_actions)
		view.get_viewport().set_input_as_handled()
		return
	if navigation_direction != 0:
		_cancel_dialogue_press()
		var controls: Array[Control] = _dialogue_focus_controls()
		if not controls.is_empty():
			var next_index: int = posmod(controls.find(focused_control) + navigation_direction, controls.size())
			controls[next_index].grab_focus()
		view.get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		if _dialogue_pending_source.begins_with("touch:") and (event as InputEventScreenDrag).position.distance_to(_dialogue_press_position) > 12.0:
			_cancel_dialogue_press()
		return
	if event is InputEventMouseMotion:
		if _dialogue_pending_source == "mouse" and (event as InputEventMouseMotion).position.distance_to(_dialogue_press_position) > 12.0:
			_cancel_dialogue_press()
		return
	var source: String = ""
	var pressed: bool = false
	var pointer: bool = false
	var point: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		source = "mouse"
		pressed = mouse.pressed
		pointer = true
		point = mouse.position
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		source = "touch:%d" % touch.index
		pressed = touch.pressed
		pointer = true
		point = touch.position
		if touch.canceled:
			_cancel_dialogue_press()
			return
	elif event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		var code: int = key.keycode if key.keycode != KEY_NONE else key.physical_keycode
		if code not in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			return
		if key.echo:
			view.get_viewport().set_input_as_handled()
			return
		source = "key:%d" % code
		pressed = key.pressed
	elif event.is_action("ui_accept"):
		source = "accept:%d" % event.device
		pressed = event.is_pressed()
	else:
		return
	if pressed:
		if not pointer and input_source != null and input_source.has_method("accept_event") and not input_source.accept_event(event, "ui_accept", input_source.get_context()):
			view.get_viewport().set_input_as_handled()
			return
		var candidate: Button
		if pointer:
			for control: Control in _dialogue_focus_controls():
				if control is Button and _dialogue_pointer_hits(control as Button, point):
					candidate = control as Button
					break
		elif focused_control is Button and dialogue_layer.is_ancestor_of(focused_control):
			candidate = focused_control as Button
		if candidate != null and not candidate.disabled:
			_cancel_dialogue_press()
			candidate.grab_focus()
			_dialogue_pending_button = candidate
			_dialogue_pending_source = source
			_dialogue_press_position = point
			view.get_viewport().set_input_as_handled()
		elif not pointer:
			view.get_viewport().set_input_as_handled()
		return
	if source != _dialogue_pending_source:
		return
	var target: Button = _dialogue_pending_button
	_cancel_dialogue_press()
	view.get_viewport().set_input_as_handled()
	if not is_instance_valid(target) or target.disabled or not target.is_visible_in_tree() or not dialogue_layer.is_ancestor_of(target):
		return
	if pointer and not _dialogue_pointer_hits(target, point):
		return
	if not pointer and view.get_viewport().gui_get_focus_owner() != target:
		return
	target.pressed.emit()

func handle_unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# Gameplay owns Escape when no actual GUI surface is open.
	if not _journey_load_active and not menu_layer.visible and not inventory_layer.visible and not dialogue_layer.visible:
		return
	if _journey_load_active:
		_cancel_journey_load()
		view.get_viewport().set_input_as_handled()
		return
	if input_source != null and input_source.has_method("accept_event") and not input_source.accept_event(event, "ui_cancel", input_source.get_context()):
		view.get_viewport().set_input_as_handled()
		return
	if request_back():
		view.get_viewport().set_input_as_handled()

func request_back() -> bool:
	if active_menu == "startup":
		return true
	if _journey_load_active:
		_cancel_journey_load()
		return true
	if remap_waiting:
		remap_waiting = false
		post_notice("Binding cancelled.", "info", 2.5, "binding")
		return true
	if active_menu in ["death", "ending", "launch"]:
		return true
	if active_menu == "text_history":
		_return_from_history()
		return true
	if dialogue_layer != null and dialogue_layer.visible and str(_topic_navigation.mode) == "topic":
		_open_dialogue_topics()
		return true
	if dialogue_layer != null and dialogue_layer.visible and str(_topic_navigation.mode) == "list":
		_return_to_primary_dialogue()
		return true
	if dialogue_layer != null and dialogue_layer.visible:
		if not _close_dialogue_surface():
			return true
		dialogue_closed.emit()
		return true
	elif inventory_layer != null and inventory_layer.visible:
		if _back_from_evidence_reading():
			return true
		if bool(_layout_policy.get("compact", false)) and str(_inventory_panes.get(_inventory_screen, "reader")) == "reader":
			_set_inventory_pane("entries", true)
			return true
		_close_inventory()
		return true
	elif active_menu in ["pause", "touch_actions"]:
		resume_requested.emit()
		return true
	elif active_menu == "main":
		return true
	elif active_menu != "":
		_return_to_parent()
		return true
	return false
