extends "res://scripts/hud/hud_component.gd"
func set_journey_models(models: Dictionary) -> void:
	for key: Variant in models.keys():
		_journey_models[str(key)] = models[key]
	_refresh_journey_card()
	if is_instance_valid(_journey_primary_button):
		var kind: String = str(read_tag(_journey_primary_button, "journey_model_kind", ""))
		if kind in ["continue", "recovery"]:
			var model: Dictionary = _journey_models.get(kind, {})
			_update_journey_load_button(_journey_primary_button, model, JourneyMenuPanel.load_label(model, kind == "recovery"))

func _refresh_journey_card() -> void:
	if not is_instance_valid(_journey_card) or _journey_card_kind == "":
		return
	var model: Dictionary = _journey_models.get(_journey_card_kind, {})
	_set_journey_card_text(JourneyMenuPanel.card(model, _journey_card_kind == "current"))

func _set_journey_card_text(text: String) -> void:
	if not is_instance_valid(_journey_card):
		return
	_journey_card.visible = not (bool(_layout_policy.get("short_display", false)) and active_menu in ["main", "pause"])
	if _journey_card.text == text:
		return
	var scroll: float = _journey_card.get_v_scroll_bar().value
	_journey_card.text = text
	_journey_card.get_v_scroll_bar().set_deferred("value", scroll)

func _show_journey_card(kind: String) -> void:
	_journey_card_kind = kind
	_refresh_journey_card()

func _add_journey_load_button(box: VBoxContainer, label: String, model: Dictionary, key: String) -> Button:
	var button: Button = _add_menu_button(box, label, func() -> void: _request_journey_selection(key), not bool(model.get("available", false)), key)
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	write_tag(button, "journey_selection", Dictionary(model.get("selection", {})).duplicate(true))
	return button

func _request_journey_selection(key: String) -> void:
	if _journey_load_active:
		return
	for raw: Node in menu_layer.find_children("*", "Button", true, false):
		var button: Button = raw as Button
		if str(read_tag(button, "navigation_key", "")) != key or button.disabled:
			continue
		var selection: Dictionary = read_tag(button, "journey_selection", {})
		if not selection.is_empty():
			journey_load_requested.emit(selection.duplicate(true))
		return

func _update_journey_load_button(button: Button, model: Dictionary, label: String) -> void:
	button.disabled = not bool(model.get("available", false))
	write_tag(button, "journey_selection", Dictionary(model.get("selection", {})).duplicate(true))
	button.text = label
	button.tooltip_text = label
	var row: Label = button.get_node_or_null("MenuButtonText") as Label
	if row != null:
		row.text = label
		row.add_theme_color_override("font_color", Color(0.62, 0.60, 0.55) if button.disabled else (Color.WHITE if high_contrast else Color(0.91, 0.85, 0.72)))

func _add_journey_recovery_options(box: VBoxContainer, model: Dictionary) -> void:
	if bool(model.get("available", false)):
		return
	var recovery: Array = model.get("recovery", [])
	for index: int in range(mini(recovery.size(), 2)):
		var option: Dictionary = recovery[index]
		if not bool(option.get("available", false)):
			continue
		var summary: Dictionary = option.get("summary", {})
		var label: Variant = "Recovery: %s\n%s | %s\n%s" % [str(option.get("source_label", summary.get("title", "Recorded journey"))), str(summary.get("place", "Location not recorded")), str(summary.get("chapter", "")), str(summary.get("time_label", "Time not recorded"))]
		_add_journey_load_button(box, label, option, "recovery_option:%d" % index)

func begin_journey_load(model: Dictionary) -> void:
	if not _journey_load_active:
		_capture_menu_state()
		_capture_inventory_state()
		if dialogue_layer.visible:
			_capture_dialogue_reading_state()
		_journey_load_origin = {"menu":menu_layer.visible, "dialogue":dialogue_layer.visible, "inventory":inventory_layer.visible}
		_journey_load_focus = view.get_viewport().gui_get_focus_owner()
	_journey_load_active = true
	_journey_load_applying = false
	_cancel_dialogue_press()
	menu_layer.visible = false
	dialogue_layer.visible = false
	inventory_layer.visible = false
	var summary: Dictionary = model.get("summary", {})
	var title: String = str(summary.get("title", "Saved journey"))
	var place: String = str(summary.get("place", ""))
	loading_message.text = "Preparing " + title + ("\n" + place if place != "" else "") + "\nYour current journey remains in place until the road is ready."
	loading_armed = true
	loading_elapsed = 0.0
	loading_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	loading_layer.visible = true
	_journey_cancel_button.visible = true
	_journey_cancel_button.disabled = false
	_journey_cancel_button.grab_focus()
	_on_hud_surface_visibility_changed()
	_update_process_policy()

func end_journey_load(success: bool, reason: String = "") -> void:
	if not _journey_load_active:
		if reason != "":
			post_notice(reason, "save" if success else "error", 6.0, "journey_load_result")
		return
	_journey_load_active = false
	_journey_load_applying = false
	_journey_cancel_button.visible = false
	loading_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide_loading()
	if not success:
		menu_layer.visible = bool(_journey_load_origin.get("menu", false))
		dialogue_layer.visible = bool(_journey_load_origin.get("dialogue", false))
		inventory_layer.visible = bool(_journey_load_origin.get("inventory", false))
		if is_instance_valid(_journey_load_focus) and _journey_load_focus.is_visible_in_tree():
			_journey_load_focus.call_deferred("grab_focus")
		elif menu_layer.visible:
			view.call_deferred("_restore_menu_state", _rendered_screen, _screen_generation)
		if reason != "":
			post_notice(reason, "error", 6.0, "journey_load_result")
	_journey_load_origin.clear()
	_journey_load_focus = null
	_on_hud_surface_visibility_changed()

func _cancel_journey_load() -> void:
	if not _journey_load_active or _journey_load_applying or _journey_cancel_button.disabled:
		return
	_journey_cancel_button.disabled = true
	journey_load_cancel_requested.emit()

func set_journey_load_applying(message: String = "Returning to the recorded journey…\nPlacing Kael on the road.") -> void:
	if not _journey_load_active:
		return
	_journey_load_applying = true
	_journey_cancel_button.disabled = true
	_journey_cancel_button.visible = false
	loading_message.text = message

func update_journey_load_progress(zone_id: String, fraction: float, phase: String = "Loading destination content...") -> void:
	if not _journey_load_active or _journey_load_applying:
		return
	var progress: Variant = " %d%%" % mini(99, int(fraction * 100.0)) if fraction >= 0.0 else ""
	loading_message.text = phase + progress + "\n" + zone_id.replace("_", " ").capitalize() + "\nYour selected journey is unchanged until preparation finishes."

func present_journey_return(model: Dictionary) -> void:
	var id: String = str(model.get("id", ""))
	if id == "" or id == _journey_return_last_id:
		return
	_journey_return_last_id = id
	_journey_return_pending = model.duplicate(true) if bool(model.get("announce", true)) else {}
	view.call_deferred("_present_pending_journey_return")

func _present_pending_journey_return() -> void:
	if _journey_return_pending.is_empty() or _gameplay_surface_blocked():
		return
	var model: Dictionary = _journey_return_pending
	_journey_return_pending = {}
	var current: Dictionary = _journey_models.get("current", {})
	var next_action: String = str(_navigation_model.get("action", current.get("next_action", model.get("next_action", ""))))
	var title: String = str(model.get("title", "Back on the road"))
	post_notice(title + ("\n" + next_action if next_action != "" else ""), "story", 6.0, "arrival:" + str(model.get("id", "")))

func clear_journey_transients(new_timeline: bool) -> void:
	_cancel_dialogue_press()
	_journey_return_pending.clear()
	if new_timeline:
		_evidence_navigation.reset()
		_inventory_panes.clear()
		_inventory_pane_states.clear()
		_evidence_position_key = ""
		_evidence_reference_section = ""
		_evidence_reference_entry = ""
		_journey_return_last_id = ""
		_preparation_results.clear()
		_slot_operation_results.clear()
	raw_prompt = ""
	raw_hint = ""
	_interaction_prompt_model.clear()
	interaction_prompt_changed.emit({"available":false})
	_hint_remaining = 0.0
	_status_remaining = 0.0
	prompt_label.visible = false
	prompt_back.visible = false
	hint_label.visible = false
	status_label.visible = false
	enemy_label.visible = false
	enemy_bar.visible = false
	enemy_value_label.visible = false
	target_status_label.visible = false
	notices.retire_journey(new_timeline)
	if NoticeQueue.is_journey_transient(_notice_active, new_timeline):
		_notice_active.clear()
		_notice_remaining = 0.0
	_present_notice()
	_update_process_policy()
