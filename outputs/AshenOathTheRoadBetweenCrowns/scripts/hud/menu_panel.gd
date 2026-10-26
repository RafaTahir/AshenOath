extends "res://scripts/hud/hud_component.gd"
## Menu panel: explicit view operations; requests leave through typed signals.

func set_journey_models(models: Dictionary) -> void:
	for key: Variant in models.keys():
		_journey_models[str(key)] = models[key]
	_refresh_journey_card()
	if is_instance_valid(_journey_primary_button):
		var kind: String = str(_journey_primary_button.get_meta("journey_model_kind", ""))
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
	var button: Button = _add_menu_button(box, label, func(): _request_journey_selection(key), not bool(model.get("available", false)), key)
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.set_meta("journey_selection", Dictionary(model.get("selection", {})).duplicate(true))
	return button

func _request_journey_selection(key: String) -> void:
	if _journey_load_active:
		return
	for raw: Node in menu_layer.find_children("*", "Button", true, false):
		var button: Button = raw as Button
		if str(button.get_meta("navigation_key", "")) != key or button.disabled:
			continue
		var selection: Dictionary = button.get_meta("journey_selection", {})
		if not selection.is_empty():
			journey_load_requested.emit(selection.duplicate(true))
		return

func _update_journey_load_button(button: Button, model: Dictionary, label: String) -> void:
	button.disabled = not bool(model.get("available", false))
	button.set_meta("journey_selection", Dictionary(model.get("selection", {})).duplicate(true))
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
		var label := "Recovery: %s\n%s | %s\n%s" % [str(option.get("source_label", summary.get("title", "Recorded journey"))), str(summary.get("place", "Location not recorded")), str(summary.get("chapter", "")), str(summary.get("time_label", "Time not recorded"))]
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
	var progress := " %d%%" % mini(99, int(fraction * 100.0)) if fraction >= 0.0 else ""
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

func show_main_menu() -> void:
	active_menu = "main"
	_set_internal_canvas(Vector2i(MENU_SIZE))
	_set_ui_pointer("menu")
	_clear_menu()
	menu_layer.visible = true
	var box: VBoxContainer = _menu_box("ASHEN OATH", "The Road Between Crowns", "contracts | curses | consequences", 680.0)
	_show_journey_card("continue")
	var model: Dictionary = _journey_models.get("continue", {})
	_add_menu_button(box, "New Game", func(): new_game_requested.emit(), false, "new_journey")
	_journey_primary_button = _add_journey_load_button(box, JourneyMenuPanel.load_label(model), model, "continue")
	_journey_primary_button.set_meta("journey_model_kind", "continue")
	_add_journey_recovery_options(box, model)
	_add_opening_progress(box)
	_add_menu_button(box, "Saved Journeys", func(): show_save_library("main"), false, "saved_journeys")
	_add_menu_button(box, "Controls", func(): show_controls_menu("main"))
	_add_menu_button(box, "Settings", func(): show_settings_menu("main"))
	_add_menu_button(box, "Credits", func(): show_credits_menu())
	_add_menu_button(box, "Quit", func(): quit_requested.emit())
	if not reduced_motion:
		_menu_frame.modulate.a = 0.0
		_menu_reveal_tween = view.create_tween()
		_menu_reveal_tween.tween_property(_menu_frame, "modulate:a", 1.0, 0.18)

func show_startup_loading(message: String = "Preparing the road...", fraction: float = -1.0, failed: bool = false) -> void:
	if active_menu != "startup" or not is_instance_valid(_startup_view):
		active_menu = "startup"
		_set_ui_pointer("menu")
		_clear_menu()
		_screen_generation += 1
		_rendered_screen = ""
		menu_layer.visible = true
		_startup_view = StartupLoadingView.new()
		menu_layer.add_child(_startup_view)
		_startup_view.retry_requested.connect(func(): launch_accepted.emit())
		_queue_responsive_layout()
	_startup_view.apply_accessibility(reduced_motion, high_contrast)
	_startup_view.update_progress(message, fraction, failed)

func set_new_game_ready(value: bool) -> void:
	if new_game_ready == value:
		return
	new_game_ready = value

func set_new_game_status(text: String) -> void:
	new_game_status = text.strip_edges()
	if new_game_status == "":
		new_game_status = "Greyfen is ready."
	if active_menu == "main" and is_instance_valid(new_game_status_label):
		new_game_status_label.text = new_game_status

func set_opening_preparation(state: String, message: String, progress: float = -1.0, requested: bool = false) -> void:
	_opening_preparation = {"state": state, "message": message, "progress": progress, "requested": requested}
	set_new_game_status(message)
	if not is_instance_valid(_opening_progress):
		return
	_opening_progress.visible = state not in ["ready", "failed", "idle"]
	_opening_progress.indeterminate = progress < 0.0 and not reduced_motion
	_opening_progress.value = clampf(progress * 100.0, 0.0, 99.0)
	_opening_retry.visible = state == "failed"
	_opening_cancel.visible = requested

func _add_opening_progress(box: VBoxContainer) -> void:
	new_game_status_label = Label.new()
	new_game_status_label.name = "OpeningPreparationStatus"
	new_game_status_label.set_meta("layout_font_role", "caption")
	new_game_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	new_game_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(new_game_status_label)
	_opening_progress = ProgressBar.new()
	_opening_progress.name = "OpeningPreparationProgress"
	_opening_progress.custom_minimum_size.y = 4.0
	_opening_progress.show_percentage = false
	_opening_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.8, 0.8, 0.8, 0.2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = HudVisualStyle.GOLD
	_opening_progress.add_theme_stylebox_override("background", track)
	_opening_progress.add_theme_stylebox_override("fill", fill)
	box.add_child(_opening_progress)
	_opening_retry = _add_menu_button(box, "Retry preparation", func(): launch_accepted.emit(), false, "opening_retry")
	_opening_cancel = _add_menu_button(box, "Cancel New Game", func(): new_game_cancel_requested.emit(), false, "opening_cancel")
	set_opening_preparation(str(_opening_preparation.state), str(_opening_preparation.message), float(_opening_preparation.progress), bool(_opening_preparation.requested))

func set_boot_shell_cover_active(_active: bool) -> void:
	# Compatibility for historical callers; startup no longer has an external cover.
	pass

func show_launch_screen() -> void:
	active_menu = "launch"
	_set_internal_canvas(Vector2i(MENU_SIZE))
	_set_ui_pointer("menu")
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box("ASHEN OATH", "The Road Between Crowns", "click to wake the road", 300.0)
	_add_menu_text(box, "Click once to enable audio and mouse capture.")
	_add_menu_button(box, "Enter", func():
		launch_accepted.emit()
		# Rebuild the main menu after the current accept event has finished. If it
		# happens synchronously, the newly focused New Game button can consume the
		# same ui_accept and start a run without a deliberate second click.
		call_deferred("show_main_menu")
	)
	view.call_deferred("_focus_first_enabled", menu_layer)

func set_touch_layout_reason(reason: String) -> void:
	_touch_layout_reason = reason.strip_edges()
	if active_menu != "pause":
		return
	if is_instance_valid(_touch_reason_label):
		_touch_reason_label.text = _touch_layout_reason
		_touch_reason_label.visible = _touch_layout_reason != ""
	if is_instance_valid(_menu_back_button):
		_menu_back_button.disabled = _touch_layout_reason != ""
	if is_instance_valid(_menu_content):
		for child: Node in _menu_content.get_children():
			if child is Button and str(child.get_meta("navigation_key", "")) == "resume":
				(child as Button).disabled = _touch_layout_reason != ""
	_queue_responsive_layout()

func show_pause_menu() -> void:
	active_menu = "pause"
	_set_internal_canvas(Vector2i(MENU_SIZE))
	_set_ui_pointer("pause")
	_clear_menu()
	menu_layer.visible = true
	var box: VBoxContainer = _menu_box("Paused", "", "the road holds its breath")
	_show_journey_card("current")
	_add_menu_button(box, "Resume", func(): resume_requested.emit(), _touch_layout_reason != "", "resume")
	_touch_reason_label = _add_menu_text(box, _touch_layout_reason)
	_touch_reason_label.visible = _touch_layout_reason != ""
	_menu_back_button.disabled = _touch_layout_reason != ""
	_add_menu_button(box, "On Return", func(): journal_section_requested.emit("return"), false, "on_return")
	_add_menu_button(box, "Quick Save", func(): save_requested.emit(), false, "quick_save")
	_add_menu_button(box, "Saved Journeys", func(): show_save_library("pause"), false, "saved_journeys")
	_add_menu_button(box, "Journal & Preparation", func(): journal_requested.emit())
	if input_source != null and input_source.companion_available:
		_add_menu_button(box, "Bracken", func(): action_selected.emit({"type":"companion_menu"}), false, "companion")
	_add_menu_button(box, "Conversation History", func(): show_text_history("pause"))
	_add_menu_button(box, "Settings", func(): show_settings_menu())
	_add_menu_button(box, "Controls", func(): show_controls_menu("pause"))
	_add_menu_button(box, "Main Menu", func(): show_main_menu())

func show_companion_commands(travel: Dictionary) -> void:
	active_menu = "companion"
	_set_internal_canvas(Vector2i(MENU_SIZE))
	_set_ui_pointer("pause")
	_clear_menu()
	menu_layer.visible = true
	var place: String = str(travel.get("zone", "greyfen")).replace("_", " ").capitalize()
	var box := _menu_box("Bracken", "Waiting in " + place if str(travel.get("command", "follow")) == "wait" else "Along the road with Kael")
	for entry: Array in [["follow", "Walk with me"], ["wait", "Wait here" if bool(travel.get("present", false)) else "Keep waiting in " + place], ["recall", "Come, Bracken"]]:
		var command: String = str(entry[0])
		_add_menu_button(box, str(entry[1]), func(selected: String = command): action_selected.emit({"type":"companion_command", "command":selected}), false, "companion:" + command)
	_add_menu_button(box, "Return", func(): resume_requested.emit(), false, "resume")

func show_touch_actions(weapon_name: String, drawn: bool) -> void:
	active_menu = "touch_actions"
	_set_internal_canvas(Vector2i(MENU_SIZE))
	_set_ui_pointer("pause")
	_clear_menu()
	menu_layer.visible = true
	var box := _menu_box("More", weapon_name + (" drawn" if drawn else " sheathed"))
	var options := [
		["weapon_sword", "Steel"], ["weapon_oathblade", "Oathblade"], ["weapon_bow", "Bow"],
		["weapon_sheath", "Sheathe" if drawn else "Draw"],
		["use_potion", "%s  (%d)" % [_item_short_name(last_remedy_id), last_potions]],
		["throw_bomb", "%s  (%d)" % [_item_short_name(last_tool_id), last_bombs]],
		["target_lock", "Lock / Release Target"], ["target_previous", "Previous Target"], ["target_next", "Next Target"],
		["cycle_arrow", "Arrows: " + last_arrow_type],
		["camera_zoom_in", "Zoom In"], ["camera_zoom_out", "Zoom Out"]
	]
	for option: Array in options:
		var action: String = str(option[0])
		var disabled := (action == "use_potion" and last_potions <= 0) or (action == "throw_bomb" and last_bombs <= 0)
		_add_menu_button(box, str(option[1]), func(selected: String = action): touch_quick_action_requested.emit(selected), disabled, "touch:" + action)
	if input_source != null and input_source.companion_available:
		_add_menu_button(box, "Bracken", func(): touch_quick_action_requested.emit("companion_command"), false, "touch:companion")
	_add_menu_button(box, "Resume", func(): resume_requested.emit(), false, "resume")

func _item_short_name(id: String) -> String:
	return str({"redroot_potion":"Redroot", "bitterleaf_tonic":"Bitterleaf", "ash_bomb":"Ash Bomb", "iron_trap":"Iron Trap"}.get(id, id.replace("_", " ").capitalize()))

func show_credits_menu() -> void:
	active_menu = "credits"
	_set_internal_canvas(Vector2i(MENU_SIZE))
	_set_ui_pointer("menu")
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box("Credits", "", "made under an ashen moon")
	_add_menu_text(box, "Ashen Oath: The Road Between Crowns\nA game by RafaTahir.\nExternal art/audio/UI asset credits are distributed with the game under assets_external/licenses.")
	_add_menu_text(box, "Chess rules and opponent search: thearst3rd, MIT License. Ashen Oath adds bounded search and table presentation. Full notice: data/chess_license.json.")
	_add_menu_text(box, "Yo Frankie! ambience by Blender Foundation (CC-BY 3.0).\nDark Ambience Loop by Iwan Gabovitch, qubodup.net (CC-BY 3.0).")
	var production_credits: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/production_credits.json")) if FileAccess.file_exists("res://data/production_credits.json") else {}
	if typeof(production_credits) == TYPE_DICTIONARY:
		for section in production_credits.get("sections", []):
			if typeof(section) != TYPE_DICTIONARY:
				continue
			_add_menu_text(box, "%s\n%s" % [str(section.get("title", "")), str(section.get("body", ""))])
			for link in section.get("links", []):
				if typeof(link) == TYPE_DICTIONARY:
					_add_menu_button(box, str(link.get("label", "Source")), func(url = str(link.get("url", ""))): OS.shell_open(url))
	_add_menu_button(box, "Report a Problem", func(): show_problem_report("credits"))
	_add_menu_button(box, "Back", func(): show_main_menu())

func show_exit_notice() -> void:
	active_menu = "quit"
	_set_internal_canvas(Vector2i(MENU_SIZE))
	_set_ui_pointer("menu")
	_clear_menu()
	menu_layer.visible = true
	var box := _menu_box("Leave the Road", "", "browser departure")
	_add_menu_text(box, "Ashen Oath cannot close a browser tab by itself.")
	_add_menu_text(box, "Your last checkpoint remains safe. Close this tab when you are ready.")
	_add_menu_button(box, "Back to Menu", func(): show_main_menu())

func hide_menus() -> void:
	if _game_owner != null and not bool(_game_owner.get("game_started")):
		return
	_topic_navigation.reset()
	_dialogue_view_generation += 1
	_cancel_dialogue_press()
	_capture_menu_state()
	_capture_inventory_state()
	if _dialogue_review_open:
		_dialogue_review_open = false
		dialogue_review_changed.emit(false)
	active_menu = ""
	_set_internal_canvas(GAMEPLAY_SIZE)
	if input_source != null and input_source.has_method("clear_focus"):
		input_source.clear_focus()
	else:
		var focus_owner := view.get_viewport().gui_get_focus_owner()
		if focus_owner != null and is_instance_valid(focus_owner):
			focus_owner.release_focus()
	menu_layer.visible = false
	dialogue_layer.visible = false
	inventory_layer.visible = false
	_set_gameplay_pointer()

func show_loading(text: String = "Preparing Greyfen...") -> void:
	arm_loading(text)

func arm_loading(text: String = "Following the road...") -> void:
	if loading_layer == null:
		return
	loading_armed = true
	loading_elapsed = 0.0
	if loading_message != null:
		if not _journey_load_active:
			loading_message.text = text
	loading_layer.visible = _journey_load_active
	_on_hud_surface_visibility_changed()
	_update_process_policy()

func hide_loading() -> void:
	if _journey_load_active:
		return
	loading_armed = false
	loading_elapsed = 0.0
	if loading_layer != null:
		loading_layer.visible = false
	_on_hud_surface_visibility_changed()
	_update_process_policy()

func _build_loading_layer() -> void:
	loading_layer = Control.new()
	loading_layer.name = "LoadingLayer"
	loading_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	loading_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_layer.visible = false
	view.add_child(loading_layer)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.008, 0.010, 0.012, 0.28)
	loading_layer.add_child(shade)
	var card := PanelContainer.new()
	_loading_card = card
	card.name = "RoadCard"
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card.position = Vector2(-260, 34)
	card.custom_minimum_size = Vector2(520, 62)
	card.size = Vector2(520, 62)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_layer.add_child(card)
	_style_panel(card, Color(0.025, 0.025, 0.022, 0.97), Color(0.58, 0.42, 0.20, 0.86))
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)
	loading_message = Label.new()
	loading_message.name = "Message"
	loading_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading_message.add_theme_font_size_override("font_size", 18)
	loading_message.add_theme_color_override("font_color", Color(0.88, 0.76, 0.54))
	loading_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loading_message.custom_minimum_size = Vector2(460, 40)
	loading_message.text = "Following the road..."
	content.add_child(loading_message)
	_journey_cancel_button = Button.new()
	_journey_cancel_button.text = "Cancel and Return"
	_journey_cancel_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_style_button(_journey_cancel_button)
	_journey_cancel_button.pressed.connect(_cancel_journey_load)
	_journey_cancel_button.visible = false
	content.add_child(_journey_cancel_button)

func _set_internal_canvas(_requested_size: Vector2i) -> void:
	var window: Window = get_window()
	if window == null:
		return
	if window.content_scale_size != GAMEPLAY_SIZE:
		window.content_scale_size = GAMEPLAY_SIZE
	if menu_layer != null:
		menu_layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		menu_layer.size = Vector2(GAMEPLAY_SIZE)
		menu_layer.scale = Vector2.ONE
	_queue_responsive_layout()

func show_ending(title: String, body: String) -> void:
	active_menu = "ending"
	_set_ui_pointer("menu")
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box(title)
	_add_menu_button(box, "Walk the road home", func(): resume_requested.emit())
	if FileAccess.file_exists("user://ashen_oath_before_covenant.json"):
		_add_menu_button(box, "Return to before the covenant", func(): revisit_covenant_requested.emit())
	var aftermath_scroll := ScrollContainer.new()
	aftermath_scroll.custom_minimum_size = Vector2(0, 260)
	aftermath_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aftermath_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	aftermath_scroll.follow_focus = true
	box.add_child(aftermath_scroll)
	var label = Label.new()
	label.text = body
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", int(round(18.0 * story_text_scale)))
	label.add_theme_constant_override("outline_size", 4 if high_contrast else 0)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.focus_mode = Control.FOCUS_ALL
	aftermath_scroll.add_child(label)
	_add_menu_button(box, "Return to Main Menu", func(): show_main_menu())
	_add_menu_button(box, "Return to Launch Screen", show_launch_screen)

func show_death_screen(body: String) -> void:
	active_menu = "death"
	_set_internal_canvas(Vector2i(MENU_SIZE))
	_set_ui_pointer("death")
	_clear_menu()
	menu_layer.visible = true
	var box: VBoxContainer = _menu_box("Kael Falls", "A recorded road remains", "return to the journey")
	_show_journey_card("recovery")
	var model: Dictionary = _journey_models.get("recovery", {})
	_add_menu_text(box, body if body != "" else "Loading returns the story and supplies recorded in this save. Changes made afterward are not included.")
	_journey_primary_button = _add_journey_load_button(box, JourneyMenuPanel.load_label(model, true), model, "recover_journey")
	_journey_primary_button.set_meta("journey_model_kind", "recovery")
	_add_journey_recovery_options(box, model)
	_add_menu_button(box, "Saved Journeys", func(): show_save_library("death"), false, "saved_journeys")
	_add_menu_button(box, "Begin a New Journey", func(): new_game_requested.emit(), false, "new_journey")
	_add_menu_button(box, "Return to Main Menu", func(): show_main_menu())

func _build_menu_layer() -> void:
	menu_layer = Control.new()
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.visible = false
	view.add_child(menu_layer)

func _clear_menu() -> void:
	_capture_menu_state()
	if _menu_reveal_tween != null and _menu_reveal_tween.is_valid():
		_menu_reveal_tween.kill()
	_startup_view = null
	_touch_reason_label = null
	_menu_notice = null
	_journey_card = null
	_journey_card_kind = ""
	_journey_primary_button = null
	_save_slot_notice = null
	_save_durability_notice = null
	new_game_status_label = null
	_opening_progress = null
	_opening_retry = null
	_opening_cancel = null
	for child in menu_layer.get_children():
		menu_layer.remove_child(child)
		child.queue_free()

func _menu_box(title: String, subtitle: String = "", omen_text: String = "", _height_limit: float = 760.0) -> VBoxContainer:
	_rendered_screen = _screen_key()
	_screen_generation += 1
	navigation.set_parent(_rendered_screen, _screen_parent())
	view.call_deferred("_restore_menu_state", _rendered_screen, _screen_generation)
	_build_menu_background()
	_menu_frame = Control.new()
	_menu_frame.name = "ResponsiveMenuFrame"
	_menu_frame.clip_contents = true
	menu_layer.add_child(_menu_frame)
	var frame_box: VBoxContainer = VBoxContainer.new()
	_menu_frame_box = frame_box
	frame_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_frame.add_child(frame_box)
	_compact_menu_title = Label.new()
	_compact_menu_title.text = title
	_compact_menu_title.add_theme_font_override("font", MENU_FONT)
	_compact_menu_title.set_meta("layout_font_role", "heading")
	_compact_menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_compact_menu_title.add_theme_color_override("font_color", HudVisualStyle.GOLD)
	_compact_menu_title.visible = false
	frame_box.add_child(_compact_menu_title)
	_menu_shell = HBoxContainer.new()
	_menu_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_box.add_child(_menu_shell)
	_menu_title_stack = VBoxContainer.new()
	_menu_title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_title_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_shell.add_child(_menu_title_stack)
	_menu_title_spacer = Control.new()
	_menu_title_stack.add_child(_menu_title_spacer)
	_menu_title_label = Label.new()
	_menu_title_label.text = title
	_menu_title_label.add_theme_font_override("font", MENU_FONT)
	_menu_title_label.set_meta("layout_font_role", "title")
	_menu_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_title_label.add_theme_color_override("font_color", Color(0.93, 0.78, 0.47))
	_menu_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	_menu_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_menu_title_label.add_theme_constant_override("shadow_offset_y", 4)
	_menu_title_stack.add_child(_menu_title_label)
	if subtitle != "":
		var subtitle_label: Label = Label.new()
		subtitle_label.text = subtitle
		subtitle_label.set_meta("menu_secondary_heading", true)
		subtitle_label.set_meta("layout_font_role", "caption")
		subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.70, 0.56))
		_menu_title_stack.add_child(subtitle_label)
	if omen_text != "":
		var omen: Label = Label.new()
		omen.text = omen_text.to_upper()
		omen.set_meta("menu_secondary_heading", true)
		omen.set_meta("layout_font_role", "caption")
		omen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		omen.add_theme_color_override("font_color", Color(0.56, 0.50, 0.40))
		_menu_title_stack.add_child(omen)
	_journey_card = RichTextLabel.new()
	_journey_card.name = "JourneyContextCard"
	_journey_card.set_meta("navigation_key", "journey_card")
	_journey_card.set_meta("navigation_scroll", "journey_card")
	_journey_card.set_meta("layout_font_role", "body")
	_journey_card.focus_mode = Control.FOCUS_ALL
	_journey_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_journey_card.scroll_active = true
	_journey_card.fit_content = false
	_journey_card.add_theme_constant_override("line_separation", 4)
	_journey_card.add_theme_color_override("default_color", Color.WHITE if high_contrast else Color(0.89, 0.84, 0.72))
	var card_focus: StyleBoxFlat = StyleBoxFlat.new()
	card_focus.bg_color = Color(0, 0, 0, 0)
	card_focus.border_color = Color.WHITE if high_contrast else Color(1.0, 0.86, 0.52)
	card_focus.set_border_width_all(3)
	_journey_card.add_theme_stylebox_override("focus", card_focus)
	_journey_card.visible = false
	_menu_title_stack.add_child(_journey_card)
	_menu_notice = Label.new()
	_menu_notice.name = "MenuOperationStatus"
	_menu_notice.set_meta("layout_font_role", "caption")
	_menu_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_title_stack.add_child(_menu_notice)
	_present_notice()
	var build: Label = Label.new()
	build.text = MENU_BUILD_LABEL
	build.set_meta("menu_secondary_heading", true)
	build.set_meta("layout_font_role", "caption")
	build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build.add_theme_color_override("font_color", Color(0.50, 0.46, 0.38))
	_menu_title_stack.add_child(build)
	_menu_panel = PanelContainer.new()
	_menu_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(_menu_panel, Color(0.030, 0.026, 0.022, 0.88), Color(0.58, 0.42, 0.20, 0.86))
	if active_menu == "main":
		_menu_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_menu_shell.add_child(_menu_panel)
	_menu_scroll = ScrollContainer.new()
	_menu_scroll.name = "MenuScroll"
	_menu_scroll.set_meta("navigation_scroll", "menu")
	_menu_scroll.follow_focus = true
	_menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_menu_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_panel.add_child(_menu_scroll)
	_menu_content = VBoxContainer.new()
	_menu_content.name = "MenuContent"
	_menu_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_content.set_meta("compact_buttons", true)
	_menu_content.set_meta("menu_button_width", 0.0)
	_menu_content.set_meta("menu_button_height", 48.0)
	_menu_content.set_meta("menu_font_size", 20)
	_menu_scroll.add_child(_menu_content)
	if active_menu in ["main", "pause", "settings", "remap", "save_library", "save_slot", "save_import"]:
		_save_durability_notice = Label.new()
		_save_durability_notice.name = "SaveDurabilityStatus"
		_save_durability_notice.set_meta("layout_font_role", "caption")
		_save_durability_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_save_durability_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame_box.add_child(_save_durability_notice)
		var storage = _save_service()
		if storage != null:
			_on_save_durability_changed(str(storage.durability_state), str(storage.durability_detail))
	_menu_footer = HBoxContainer.new()
	frame_box.add_child(_menu_footer)
	_menu_back_button = Button.new()
	_menu_back_button.set_meta("navigation_key", "surface_back")
	_menu_back_button.text = "Resume" if active_menu == "pause" else "Back"
	_menu_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_back_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_style_button(_menu_back_button)
	_style_menu_action(_menu_back_button)
	_menu_back_button.pressed.connect(request_back)
	_menu_footer.add_child(_menu_back_button)
	_menu_footer.visible = active_menu not in ["main", "launch", "death", "ending", ""]
	_queue_responsive_layout()
	return _menu_content

func _build_menu_background() -> void:
	var backdrop := TextureRect.new()
	backdrop.name = "GreyfenMenuBackdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture = preload("res://assets_external/ui/greyfen_menu_stylized.png")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(backdrop)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.015, 0.018, 0.66 if high_contrast else 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(shade)

func _add_menu_button(box: VBoxContainer, text: String, callback: Callable, disabled: bool = false, focus_key: String = "") -> Button:
	var screen_generation := _screen_generation
	var is_first_button := true
	for child in box.get_children():
		if child is Button:
			is_first_button = false
			break
	var button = Button.new()
	button.text = ""
	button.tooltip_text = text
	button.set_meta("navigation_key", focus_key if focus_key != "" else text.split("\n", false)[0].strip_edges())
	button.disabled = disabled
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.custom_minimum_size = Vector2(float(box.get_meta("menu_button_width", 510.0)), float(box.get_meta("menu_button_height", 62.0)))
	_style_button(button)
	button.add_theme_font_size_override("font_size", int(box.get_meta("menu_font_size", 23)))
	var row_label := Label.new()
	row_label.name = "MenuButtonText"
	row_label.text = text
	row_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_label.add_theme_font_size_override("font_size", int(float(box.get_meta("menu_font_size", 23)) * minf(story_text_scale, 1.25)))
	row_label.add_theme_color_override("font_color", Color(0.49, 0.47, 0.42) if disabled else Color(0.91, 0.85, 0.72))
	row_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row_label.offset_left = 16
	row_label.offset_right = -16
	row_label.offset_top = 12
	row_label.offset_bottom = -12
	button.add_child(row_label)
	button.text = text
	button.clip_text = true
	button.set_meta("wrapped_label", true)
	_style_menu_action(button)
	_hide_native_button_text(button)
	button.resized.connect(func():
		var row_height: float = float(maxi(1, row_label.get_line_count()) * row_label.get_line_height()) + float(button.get_meta("layout_button_padding", 24.0))
		button.custom_minimum_size.y = maxf(float(button.get_meta("layout_button_height", box.get_meta("menu_button_height", 62.0))), row_height)
	)
	button.mouse_entered.connect(func():
		if not button.disabled:
			menu_hovered.emit()
	)
	button.focus_entered.connect(func():
		if not button.disabled:
			menu_hovered.emit()
	)
	button.pressed.connect(func():
		if screen_generation != _screen_generation or not button.is_visible_in_tree() or button.disabled:
			return
		_capture_menu_state()
		menu_clicked.emit()
		view.call_deferred("_activate_menu_action", callback, screen_generation)
	)
	box.add_child(button)
	return button

func _activate_menu_action(callback: Callable, screen_generation: int) -> void:
	if screen_generation != _screen_generation:
		return
	if input_source != null:
		input_source.reset_transient_input("menu_action")
	callback.call()

func _add_menu_text(box: VBoxContainer, text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(float(box.get_meta("menu_button_width", 510.0)), 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color", Color(0.72, 0.66, 0.54))
	label.add_theme_font_size_override("font_size", int((17.0 if bool(box.get_meta("compact_buttons", false)) else 20.0) * minf(story_text_scale, 1.25)))
	box.add_child(label)
	return label

func _menu_viewport_size() -> Vector2:
	if menu_layer != null and menu_layer.size.x >= 320.0 and menu_layer.size.y >= 240.0:
		return menu_layer.size
	if view.get_viewport() == null:
		return MENU_SIZE
	var size := view.get_viewport().get_visible_rect().size
	return MENU_SIZE if size.x < 320.0 or size.y < 240.0 else size

func _screen_key() -> String:
	match active_menu:
		"settings": return "settings:%d" % settings_page
		"remap": return "remap:%d" % remap_page
		"save_library": return "save_library:%d" % library_page
		"save_slot": return "save_slot:" + selected_slot
		_: return active_menu

func _screen_parent() -> String:
	match active_menu:
		"settings", "controls": return controls_back_target
		"remap": return "controls"
		"save_library": return library_back_target
		"save_slot", "save_import", "chapter_replay": return "save_library:%d" % library_page
		"text_history", "problem_report": return library_back_target
		"credits", "quit": return "main"
		"pause", "companion": return "gameplay"
		_: return "main"

func _capture_menu_state() -> void:
	if is_instance_valid(menu_layer) and _rendered_screen != "":
		navigation.capture(_rendered_screen, navigation.parent_of(_rendered_screen, _screen_parent()), menu_layer)

func _restore_menu_state(key: String, generation: int) -> void:
	await view.get_tree().process_frame
	if _journey_load_active or generation != _screen_generation or key != _rendered_screen or not is_instance_valid(menu_layer) or not menu_layer.visible:
		return
	var state: Dictionary = navigation.screens.get(key, {})
	if str(state.get("focus", "")) == "":
		match active_menu:
			"main": state["focus"] = "continue" if bool(Dictionary(_journey_models.get("continue", {})).get("available", false)) else "new_journey"
			"pause": state["focus"] = "resume"
			"death": state["focus"] = "recover_journey" if bool(Dictionary(_journey_models.get("recovery", {})).get("available", false)) else "saved_journeys"
		navigation.screens[key] = state
	if _dialogue_review_open:
		var reader := menu_layer.find_child("HistoryReader", true, false) as RichTextLabel
		if reader != null and not navigation.screens.get(key, {}).has("scrolls"):
			reader.get_v_scroll_bar().value = reader.get_v_scroll_bar().max_value
	navigation.restore(key, menu_layer)
	_reveal_menu_focus()

func _register_field(control: Control, field_key: String, fallback: String) -> void:
	control.set_meta("navigation_key", "field:" + field_key)
	control.set_meta("navigation_draft", field_key)
	control.set("text", navigation.draft(_rendered_screen, field_key, fallback))

func _return_to_parent() -> void:
	_capture_menu_state()
	_open_screen(navigation.parent_of(_rendered_screen, _screen_parent()))

func _open_screen(key: String) -> void:
	var parts := key.split(":", true, 1)
	var page := int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else 0
	match parts[0]:
		"gameplay": resume_requested.emit()
		"main": show_main_menu()
		"pause": show_pause_menu()
		"death": show_death_screen("")
		"controls": show_controls_menu(controls_back_target)
		"settings": show_settings_menu(controls_back_target, page)
		"remap": show_remap_menu(remap_back_target, page)
		"credits": show_credits_menu()
		"save_library": show_save_library(library_back_target, page)
		"save_slot": show_save_slot(parts[1] if parts.size() > 1 else selected_slot)
		"dialogue": _return_from_history()
		_: show_pause_menu()
