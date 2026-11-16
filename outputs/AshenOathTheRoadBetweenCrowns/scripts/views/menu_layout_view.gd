extends "res://scripts/hud/hud_component.gd"
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
	write_tag(_compact_menu_title, "layout_font_role", "heading")
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
	write_tag(_menu_title_label, "layout_font_role", "title")
	_menu_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_title_label.add_theme_color_override("font_color", Color(0.93, 0.78, 0.47))
	_menu_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	_menu_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_menu_title_label.add_theme_constant_override("shadow_offset_y", 4)
	_menu_title_stack.add_child(_menu_title_label)
	if subtitle != "":
		var subtitle_label: Label = Label.new()
		subtitle_label.text = subtitle
		write_tag(subtitle_label, "menu_secondary_heading", true)
		write_tag(subtitle_label, "layout_font_role", "caption")
		subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.70, 0.56))
		_menu_title_stack.add_child(subtitle_label)
	if omen_text != "":
		var omen: Label = Label.new()
		omen.text = omen_text.to_upper()
		write_tag(omen, "menu_secondary_heading", true)
		write_tag(omen, "layout_font_role", "caption")
		omen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		omen.add_theme_color_override("font_color", Color(0.56, 0.50, 0.40))
		_menu_title_stack.add_child(omen)
	_journey_card = RichTextLabel.new()
	_journey_card.name = "JourneyContextCard"
	write_tag(_journey_card, "navigation_key", "journey_card")
	write_tag(_journey_card, "navigation_scroll", "journey_card")
	write_tag(_journey_card, "layout_font_role", "body")
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
	write_tag(_menu_notice, "layout_font_role", "caption")
	_menu_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_title_stack.add_child(_menu_notice)
	_present_notice()
	var build: Label = Label.new()
	build.text = MENU_BUILD_LABEL
	write_tag(build, "menu_secondary_heading", true)
	write_tag(build, "layout_font_role", "caption")
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
	write_tag(_menu_scroll, "navigation_scroll", "menu")
	_menu_scroll.follow_focus = true
	_menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_menu_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_panel.add_child(_menu_scroll)
	_menu_content = VBoxContainer.new()
	_menu_content.name = "MenuContent"
	_menu_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	write_tag(_menu_content, "compact_buttons", true)
	write_tag(_menu_content, "menu_button_width", 0.0)
	write_tag(_menu_content, "menu_button_height", 48.0)
	write_tag(_menu_content, "menu_font_size", 20)
	_menu_scroll.add_child(_menu_content)
	if active_menu in ["main", "pause", "settings", "remap", "save_library", "save_slot", "save_import"]:
		_save_durability_notice = Label.new()
		_save_durability_notice.name = "SaveDurabilityStatus"
		write_tag(_save_durability_notice, "layout_font_role", "caption")
		_save_durability_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_save_durability_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame_box.add_child(_save_durability_notice)
		var storage = _save_service()
		if storage != null:
			_on_save_durability_changed(str(storage.durability_state), str(storage.durability_detail))
	_menu_footer = HBoxContainer.new()
	frame_box.add_child(_menu_footer)
	_menu_back_button = Button.new()
	write_tag(_menu_back_button, "navigation_key", "surface_back")
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
	var backdrop: Variant = TextureRect.new()
	backdrop.name = "GreyfenMenuBackdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture = preload("res://assets_external/ui/greyfen_menu_stylized.png")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(backdrop)
	var shade: Variant = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.015, 0.018, 0.66 if high_contrast else 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(shade)

func _add_menu_button(box: VBoxContainer, text: String, callback: Callable, disabled: bool = false, focus_key: String = "") -> Button:
	var screen_generation: Variant = _screen_generation
	var is_first_button: Variant = true
	for child in box.get_children():
		if child is Button:
			is_first_button = false
			break
	var button = Button.new()
	button.text = ""
	button.tooltip_text = text
	write_tag(button, "navigation_key", focus_key if focus_key != "" else text.split("\n", false)[0].strip_edges())
	button.disabled = disabled
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.custom_minimum_size = Vector2(float(read_tag(box, "menu_button_width", 510.0)), float(read_tag(box, "menu_button_height", 62.0)))
	_style_button(button)
	button.add_theme_font_size_override("font_size", int(read_tag(box, "menu_font_size", 23)))
	var row_label: Variant = Label.new()
	row_label.name = "MenuButtonText"
	row_label.text = text
	row_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_label.add_theme_font_size_override("font_size", int(float(read_tag(box, "menu_font_size", 23)) * minf(story_text_scale, 1.25)))
	row_label.add_theme_color_override("font_color", Color(0.49, 0.47, 0.42) if disabled else Color(0.91, 0.85, 0.72))
	row_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row_label.offset_left = 16
	row_label.offset_right = -16
	row_label.offset_top = 12
	row_label.offset_bottom = -12
	button.add_child(row_label)
	button.text = text
	button.clip_text = true
	write_tag(button, "wrapped_label", true)
	_style_menu_action(button)
	_hide_native_button_text(button)
	button.resized.connect(func() -> void:
		var row_height: float = float(maxi(1, row_label.get_line_count()) * row_label.get_line_height()) + float(read_tag(button, "layout_button_padding", 24.0))
		button.custom_minimum_size.y = maxf(float(read_tag(button, "layout_button_height", read_tag(box, "menu_button_height", 62.0))), row_height)
	)
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			menu_hovered.emit()
	)
	button.focus_entered.connect(func() -> void:
		if not button.disabled:
			menu_hovered.emit()
	)
	button.pressed.connect(func() -> void:
		if screen_generation != _screen_generation or not button.is_visible_in_tree() or button.disabled:
			return
		_capture_menu_state()
		menu_clicked.emit()
		view.call_deferred("_activate_menu_action", callback, screen_generation)
	)
	box.add_child(button)
	return button

func _add_menu_text(box: VBoxContainer, text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(float(read_tag(box, "menu_button_width", 510.0)), 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color", Color(0.72, 0.66, 0.54))
	label.add_theme_font_size_override("font_size", int((17.0 if bool(read_tag(box, "compact_buttons", false)) else 20.0) * minf(story_text_scale, 1.25)))
	box.add_child(label)
	return label

func _menu_viewport_size() -> Vector2:
	if menu_layer != null and menu_layer.size.x >= 320.0 and menu_layer.size.y >= 240.0:
		return menu_layer.size
	if view.get_viewport() == null:
		return MENU_SIZE
	var size: Variant = view.get_viewport().get_visible_rect().size
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
		var reader: Variant = menu_layer.find_child("HistoryReader", true, false) as RichTextLabel
		if reader != null and not navigation.screens.get(key, {}).has("scrolls"):
			reader.get_v_scroll_bar().value = reader.get_v_scroll_bar().max_value
	navigation.restore(key, menu_layer)
	_reveal_menu_focus()

func _register_field(control: Control, field_key: String, fallback: String) -> void:
	write_tag(control, "navigation_key", "field:" + field_key)
	write_tag(control, "navigation_draft", field_key)
	control.set("text", navigation.draft(_rendered_screen, field_key, fallback))

func _return_to_parent() -> void:
	_capture_menu_state()
	_open_screen(navigation.parent_of(_rendered_screen, _screen_parent()))

func _open_screen(key: String) -> void:
	var parts: Variant = key.split(":", true, 1)
	var page: Variant = int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else 0
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
