extends "res://scripts/hud/hud_component.gd"
## Hud style: explicit view operations; requests leave through typed signals.

func _style_button(button: Button) -> void:
	if button.text != "" and not button.has_meta("wrapped_label"):
		var label := Label.new()
		label.text = button.text
		if button.tooltip_text == "":
			button.tooltip_text = button.text
		button.clip_text = true
		button.set_meta("wrapped_label", true)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", int(22.0 * minf(story_text_scale, 1.2)))
		label.add_theme_color_override("font_color", Color(0.50, 0.48, 0.43) if button.disabled else Color(0.94, 0.89, 0.77))
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.offset_left = 16
		label.offset_right = -16
		label.offset_top = 10
		label.offset_bottom = -10
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 52.0)
		button.add_child(label)
		button.resized.connect(func():
			button.custom_minimum_size.y = maxf(float(button.get_meta("layout_button_height", 52.0)), float(maxi(1, label.get_line_count()) * label.get_line_height()) + float(button.get_meta("layout_button_padding", 20.0)))
		)
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.046, 0.037, 0.72)
	normal.border_color = Color(0.50, 0.37, 0.19, 0.82)
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3
	normal.corner_radius_bottom_right = 3
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.16, 0.105, 0.052, 0.94)
	hover.border_color = Color(0.95, 0.66, 0.28, 0.96)
	hover.set_border_width_all(1)
	hover.set_border_width(SIDE_BOTTOM, 3)
	hover.corner_radius_top_left = 3
	hover.corner_radius_top_right = 3
	hover.corner_radius_bottom_left = 3
	hover.corner_radius_bottom_right = 3
	hover.content_margin_left = 16
	hover.content_margin_right = 16
	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(0.23, 0.135, 0.058, 1.0)
	pressed.border_color = Color(1.0, 0.74, 0.32, 1.0)
	pressed.set_border_width_all(1)
	pressed.set_border_width(SIDE_BOTTOM, 3)
	pressed.corner_radius_top_left = 3
	pressed.corner_radius_top_right = 3
	pressed.corner_radius_bottom_left = 3
	pressed.corner_radius_bottom_right = 3
	var disabled = StyleBoxFlat.new()
	disabled.bg_color = Color(0.032, 0.030, 0.028, 0.54)
	disabled.border_color = Color(0.25, 0.23, 0.20, 0.62)
	disabled.set_border_width_all(1)
	disabled.corner_radius_top_left = 3
	disabled.corner_radius_top_right = 3
	disabled.corner_radius_bottom_left = 3
	disabled.corner_radius_bottom_right = 3
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color.WHITE if high_contrast else Color(1.0, 0.86, 0.52)
	focus.set_border_width_all(3)
	focus.expand_margin_left = 2
	focus.expand_margin_right = 2
	focus.expand_margin_top = 2
	focus.expand_margin_bottom = 2
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.86, 0.78, 0.60))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.56))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.88, 0.56))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.74, 0.36))
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.39, 0.34))
	button.add_theme_font_size_override("font_size", 23)
	if button.has_meta("dialogue_focus_key"):
		for key: String in ["normal", "hover", "pressed", "disabled"]:
			var choice_style: StyleBoxFlat = (button.get_theme_stylebox(key).duplicate() as StyleBoxFlat)
			choice_style.bg_color = Color(0.028, 0.032, 0.035, 0.9 if high_contrast else (0.76 if key in ["hover", "pressed"] else 0.32))
			choice_style.border_color = Color.WHITE if high_contrast else HudVisualStyle.GOLD
			choice_style.set_border_width_all(0)
			choice_style.border_width_left = 3 if key in ["hover", "pressed"] else 0
			choice_style.border_width_bottom = 1
			choice_style.corner_radius_top_left = 0
			choice_style.corner_radius_top_right = 0
			choice_style.corner_radius_bottom_left = 0
			choice_style.corner_radius_bottom_right = 0
			button.add_theme_stylebox_override(key, choice_style)
		HudVisualStyle.dialogue_choice(button, high_contrast)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	if button.has_meta("wrapped_label"):
		_hide_native_button_text(button)
	if button.has_meta("menu_text_action"):
		_style_menu_action(button)

func _style_menu_action(button: Button) -> void:
	if not button.has_meta("menu_text_action"):
		button.set_meta("menu_text_action", true)
		for interaction_signal in [button.mouse_entered, button.mouse_exited, button.focus_entered, button.focus_exited, button.button_down, button.button_up]:
			interaction_signal.connect(func(): _refresh_menu_action(button))
	for key in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(key, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color.WHITE if high_contrast else HudVisualStyle.GOLD
	focus.border_width_bottom = 2
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_font_override("font", MENU_FONT)
	_refresh_menu_action(button)

func _refresh_menu_action(button: Button) -> void:
	var selected := button.has_focus() or button.is_hovered() or button.is_pressed()
	var color := (Color.WHITE if high_contrast else HudVisualStyle.GOLD) if selected else HudVisualStyle.IVORY
	if button.disabled:
		color = Color("88877f")
	for child in button.get_children():
		if child is Label:
			child.add_theme_font_override("font", MENU_FONT)
			child.add_theme_color_override("font_color", color)
			child.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
			child.add_theme_constant_override("shadow_offset_y", 1)

func _hide_native_button_text(button: Button) -> void:
	# Keep the actual Button text for accessible names and existing callers.
	# Its wrapped child label owns only the visual presentation.
	for color_key in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_disabled_color", "font_hover_pressed_color", "font_shadow_color", "font_outline_color"]:
		button.add_theme_color_override(color_key, Color(0, 0, 0, 0))
