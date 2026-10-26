extends "res://scripts/hud/hud_component.gd"
## Settings panel: explicit view operations; requests leave through typed signals.

func show_settings_menu(back_target: String = "pause", requested_page: int = -1) -> void:
	if active_menu == "startup" and not new_game_ready:
		return
	active_menu = "settings"
	_set_internal_canvas(Vector2i(MENU_SIZE))
	controls_back_target = back_target
	if requested_page >= 0:
		settings_page = requested_page
	_set_ui_pointer("settings")
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box("Settings", "Play, Sound & Controls", "tune the lantern")
	box.set_meta("compact_buttons", true)
	var s = _current_settings()
	var entries := _settings_entries(s)
	var page_count := maxi(1, ceili(float(entries.size()) / 6.0))
	settings_page = clampi(settings_page, 0, page_count - 1)
	_add_menu_text(box, "Page %d of %d  |  Select an option to cycle it" % [settings_page + 1, page_count])
	var first_entry := settings_page * 6
	var last_entry := mini(first_entry + 6, entries.size())
	for index in range(first_entry, last_entry):
		var entry: Dictionary = entries[index]
		var action := str(entry.get("action", ""))
		if entry.has("mix_channel"):
			var volume_label := Label.new()
			volume_label.text = str(entry.label)
			volume_label.add_theme_font_size_override("font_size", 18)
			box.add_child(volume_label)
			var slider := HSlider.new()
			slider.set_meta("navigation_key", "mix:" + str(entry.mix_channel))
			slider.min_value = 0.0
			slider.max_value = 1.0
			slider.step = 0.05
			slider.value = float(entry.get("value", 1.0))
			slider.custom_minimum_size = Vector2(320, 28)
			slider.focus_mode = Control.FOCUS_ALL
			slider.tooltip_text = "Use Left and Right to adjust; zero mutes this channel."
			slider.value_changed.connect(func(value: float, channel = str(entry.mix_channel), heading = volume_label):
				heading.text = "%s Volume  %d%%" % [channel.capitalize(), int(round(value * 100.0))]
				audio_mix_requested.emit(channel, value)
			)
			box.add_child(slider)
		elif action == "":
			_add_menu_text(box, str(entry.get("label", "")))
		else:
			_add_menu_button(box, str(entry.get("label", "")), func(setting_action = action):
				var manager = _settings_source
				if manager != null and manager.has_method("cycle_accessibility") and manager.cycle_accessibility(setting_action):
					show_settings_menu(controls_back_target, settings_page)
				else:
					settings_requested.emit(setting_action)
			, false, "setting:" + action)
	if page_count > 1:
		_add_menu_button(box, "Previous Page", func(): show_settings_menu(controls_back_target, settings_page - 1), settings_page <= 0)
		_add_menu_button(box, "Next Page", func(): show_settings_menu(controls_back_target, settings_page + 1), settings_page >= page_count - 1)
	_add_menu_button(box, "Back", _return_from_controls)

func _settings_entries(s: Dictionary) -> Array:
	return [
		{"label": "Difficulty        %s" % str(s.get("difficulty", "standard")).capitalize(), "action": "difficulty"},
		{"label": "Story: gentler damage and wider parries. Standard: original balance. Veteran: less room for mistakes. Endings remain available in every profile.", "action": ""},
		{"label": "Visual Preset     %s" % str(s.get("quality_preset", "balanced")).capitalize(), "action": "visual_preset"},
		{"label": "3D Resolution     Native 720p (fixed for Web stability)", "action": ""},
		{"label": "Shadows           %s" % _shadow_label(int(s.get("shadow_quality", 1))), "action": "shadows"},
		{"label": "Mouse Sensitivity %s" % _sensitivity_label(float(s.get("mouse_sensitivity", 0.003))), "action": "mouse_sensitivity"},
		{"label": "Controller Look   %s" % _controller_sensitivity_label(float(s.get("gamepad_look_sensitivity", 1.0))), "action": "gamepad_sensitivity"},
		{"label": "Controller Rumble %s" % _on_off(bool(s.get("gamepad_vibration", true))), "action": "gamepad_vibration"},
		{"label": "Touch Controls    %s" % str(s.get("touch_controls", "auto")).capitalize(), "action": "touch_controls"},
		{"label": "Touch Look        %s" % _controller_sensitivity_label(float(s.get("touch_look_sensitivity", 1.0))), "action": "touch_sensitivity"},
		{"label": "Touch Aim         %s" % str(s.get("touch_aim_mode", "toggle")).capitalize(), "action": "touch_aim_mode"},
		{"label": "Invert Y Axis     %s" % _on_off(bool(s.get("invert_y", false))), "action": "invert_y"},
		{"label": "Master Volume     %d%%" % int(round(float(s.get("master_volume", 0.85)) * 100.0)), "action": "volume"},
		{"label": "Music Volume      %d%%" % int(round(float(s.get("music_volume", 0.8)) * 100.0)), "mix_channel": "music", "value": float(s.get("music_volume", 0.8))},
		{"label": "Effects Volume    %d%%" % int(round(float(s.get("sfx_volume", 1.0)) * 100.0)), "mix_channel": "sfx", "value": float(s.get("sfx_volume", 1.0))},
		{"label": "Voice Volume      %d%%" % int(round(float(s.get("voice_volume", 1.0)) * 100.0)), "mix_channel": "voice", "value": float(s.get("voice_volume", 1.0))},
		{"label": "Pause on Focus Loss  %s" % _on_off(bool(s.get("pause_on_focus_loss", true))), "action": "focus_pause"},
		{"label": "VSync             %s" % _on_off(bool(s.get("vsync", true))), "action": "vsync"},
		{"label": "Fullscreen        %s" % _on_off(bool(s.get("fullscreen", false))), "action": "fullscreen"},
		{"label": "Subtitle Size     %d%%" % int(round(float(s.get("subtitle_scale", 1.0)) * 100.0)), "action": "subtitle_scale"},
		{"label": "Subtitle Shade  %d%%" % int(round(float(s.get("subtitle_background_opacity", 0.55)) * 100.0)), "action": "subtitle_background_opacity"},
		{"label": "Speaker Names     %s" % _on_off(bool(s.get("subtitle_speaker_names", true))), "action": "subtitle_speaker_names"},
		{"label": "Block             %s" % str(s.get("block_mode", "hold")).capitalize(), "action": "block_mode"},
		{"label": "Sprint            %s" % str(s.get("sprint_mode", "hold")).capitalize(), "action": "sprint_mode"},
		{"label": "Target Assistance %s" % _on_off(bool(s.get("targeting_assist", true))), "action": "targeting_assist"},
		{"label": "Reduce Flashes    %s" % _on_off(bool(s.get("flash_reduction", false))), "action": "flash_reduction"},
		{"label": "Blood Effects     %s" % _on_off(bool(s.get("blood_effects", true))), "action": "blood_effects"},
		{"label": "Camera Shake      %d%%" % int(round(float(s.get("camera_shake", 1.0)) * 100.0)), "action": "camera_shake"},
		{"label": "Reduced Motion    %s" % _on_off(bool(s.get("reduced_motion", false))), "action": "reduced_motion"},
		{"label": "High Contrast     %s" % _on_off(bool(s.get("high_contrast", false))), "action": "high_contrast"},
		{"label": "Control Layout    %s" % str(s.get("control_preset", "standard")).replace("_", " ").capitalize(), "action": "control_preset"}
	]

func show_controls_menu(back_target: String = "main") -> void:
	active_menu = "controls"
	controls_back_target = back_target
	_set_ui_pointer("controls")
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box("Controls", "", "blade | breath | road")
	if input_source != null and input_source.has_method("describe_action"):
		var instructions: Array[String] = []
		for action in ["interact", "run", "block", "dodge", "jump", "light_attack", "heavy_attack", "aim_bow", "weapon_sheath", "oathfire_beam", "use_potion", "throw_bomb", "open_inventory", "pause"]:
			var descriptor: Dictionary = input_source.describe_action(action)
			instructions.append("%s: %s" % [str(action).replace("_", " ").capitalize(), str(descriptor.get("instruction", descriptor.get("binding", "Unbound")))])
		instructions.append("%s: tap to cycle weapons; hold to draw or sheath" % input_source.action_label("weapon_cycle"))
		_add_menu_text(box, "Move with the movement keys, left stick or touch pad; look with the mouse, right stick or touch look area.\n\n" + "\n".join(instructions))
	elif input_device == "gamepad":
		_add_menu_text(box, "Left Stick move | Right Stick look | D-Pad Up/Down zoom\nL3 run | B dodge | Y jump | Tap X cycle weapons | Hold X draw/sheath\nRB light attack | RT heavy attack | LT aim bow\nBow: aim, hold RT to draw, release RT to loose; lower aim to cancel\nSword: hold LT Oathfire | Tap/Hold LB parry or block | A interact\nBow: D-Pad Up cycle arrows | D-Pad Left potion | D-Pad Right bomb | View journal | Menu pause")
	elif input_device == "touch":
		_add_menu_text(box, "Left thumb move | Drag right side to look\nSword: Strike, Heavy, Guard, Dodge, Jump, Oath\nBow: Aim, hold Draw, lift to loose; lower Aim to cancel\nLock, Arrows, Dodge, Jump remain available\nUse the displayed object with Use\nMore: weapons, draw/sheath, supplies, targets, camera, Bracken\nPause and Book open their menus\nLandscape orientation is required during gameplay")
	else:
		_add_menu_text(box, "WASD move | Mouse look | Wheel zoom | Page Up/Down zoom\nShift run | Space dodge | X jump | 1 Steel | 2 Bow | 3 Oathblade | H draw/sheath\nLeft mouse light attack | Right mouse heavy / aim bow\nBow: aim, hold left mouse to draw, release to loose; lower aim to cancel\nHold C Oathfire Beam | Tap Q parry | Hold Q block | E interact\nZ cycle arrows | R potion | F bomb | Tab inventory | Esc pause")
	_add_menu_button(box, "Customize Controls", func(): show_remap_menu(back_target))
	_add_menu_button(box, "Back", _return_from_controls)

func show_remap_menu(back_target: String = "main", requested_page: int = -1) -> void:
	active_menu = "remap"
	remap_back_target = back_target
	remap_waiting = false
	if requested_page >= 0:
		remap_page = requested_page
	_set_ui_pointer("remap")
	_clear_menu()
	menu_layer.visible = true
	var box := _menu_box("Customize Controls", "Bindings", "choose an action, then press a key or button")
	box.set_meta("compact_buttons", true)
	var detected := "Keyboard and mouse"
	if input_source != null and str(input_source.get("active_device")) == "gamepad":
		var profile: Dictionary = input_source.get_gamepad_profile() if input_source.has_method("get_gamepad_profile") else {}
		detected = "Detected: %s (%s)" % [str(profile.get("name", "Controller")), str(profile.get("glyph_theme", "generic")).capitalize()]
	_add_menu_text(box, detected)
	var actions := ["interact", "dodge", "jump", "run", "block", "light_attack", "heavy_attack", "oathfire_beam", "use_potion", "throw_bomb", "open_inventory", "pause",
		"move_forward", "move_back", "move_left", "move_right", "camera_left", "camera_right", "camera_up", "camera_down", "camera_zoom_in", "camera_zoom_out",
		"weapon_cycle", "weapon_sword", "weapon_bow", "weapon_oathblade", "weapon_sheath", "aim_bow", "fire_bow", "cycle_arrow", "target_lock", "target_next", "target_previous", "companion_command"]
	var page_count := maxi(1, ceili(float(actions.size()) / 6.0))
	remap_page = clampi(remap_page, 0, page_count - 1)
	_add_menu_text(box, "Page %d of %d" % [remap_page + 1, page_count])
	var first_entry := remap_page * 6
	var last_entry := mini(first_entry + 6, actions.size())
	for index in range(first_entry, last_entry):
		var action := str(actions[index])
		var label := action.replace("_", " ").capitalize()
		if action == "weapon_sword":
			label = "Steel sword"
		elif action == "weapon_sheath":
			label = "Draw / sheath"
		var binding := _binding_display(action)
		_add_menu_button(box, "%s     %s" % [label, binding], func(selected = action): _begin_remap(selected), false, "binding:" + action)
	if page_count > 1:
		_add_menu_button(box, "Previous Page", func(): show_remap_menu(remap_back_target, remap_page - 1), remap_page <= 0)
		_add_menu_button(box, "Next Page", func(): show_remap_menu(remap_back_target, remap_page + 1), remap_page >= page_count - 1)
	_add_menu_button(box, "Reset Defaults", func(): _reset_bindings())
	_add_menu_button(box, "Back", _return_from_remap)

func _begin_remap(action: String) -> void:
	remap_action_id = action
	remap_waiting = true
	view.get_viewport().set_input_as_handled()
	toast("Press a key, mouse button, or controller input for %s. Escape cancels." % action.replace("_", " "))

func _reset_bindings() -> void:
	if input_source != null and input_source.has_method("reset_bindings"):
		input_source.reset_bindings()
	toast("Controls restored to defaults.")
	show_remap_menu(remap_back_target, remap_page)

func _binding_display(action: String) -> String:
	if input_source == null:
		return "Unbound"
	if input_source.has_method("action_label"):
		return str(input_source.action_label(action))
	return action.capitalize()

func _return_from_remap() -> void:
	remap_waiting = false
	_return_to_parent()

func _current_settings() -> Dictionary:
	var settings_node = _settings_source
	if settings_node != null:
		return settings_node.settings
	return {}

func apply_accessibility(current: Dictionary) -> void:
	reduced_motion = bool(current.get("reduced_motion", false))
	if is_instance_valid(_opening_progress):
		_opening_progress.indeterminate = float(_opening_preparation.progress) < 0.0 and not reduced_motion
	flash_reduction = bool(current.get("flash_reduction", false))
	subtitle_speaker_names = bool(current.get("subtitle_speaker_names", true))
	high_contrast = bool(current.get("high_contrast", false))
	var subtitle_scale := clampf(float(current.get("subtitle_scale", 1.0)), 0.9, 1.5)
	story_text_scale = subtitle_scale
	if inventory_text != null:
		inventory_text.add_theme_font_size_override("normal_font_size", int(round(17.0 * story_text_scale)))
		if journal_art != null:
			journal_art.custom_minimum_size.y = 64.0 if story_text_scale > 1.2 else 84.0
			inventory_text.custom_minimum_size.y = 520.0 - journal_art.custom_minimum_size.y - 48.0
	if dialogue_text != null:
		dialogue_title.visible = subtitle_speaker_names
		dialogue_layer.add_theme_stylebox_override("panel", HudVisualStyle.dialogue_panel(high_contrast, clampf(float(current.get("subtitle_background_opacity", 0.55)), 0.0, 1.0)))
		dialogue_text.add_theme_font_size_override("normal_font_size", int(round(24.0 * subtitle_scale)))
		dialogue_text.add_theme_font_size_override("bold_font_size", int(round(26.0 * subtitle_scale)))
		dialogue_text.custom_minimum_size.y = 78.0 if subtitle_scale <= 1.0 else 116.0
	if _decision_details != null:
		_decision_details.add_theme_font_size_override("normal_font_size", int(round(18.0 * story_text_scale)))
		_decision_details.add_theme_color_override("default_color", Color(0.98, 0.96, 0.88) if high_contrast else Color(0.88, 0.82, 0.70))
	var reader_focus: StyleBoxFlat = StyleBoxFlat.new()
	reader_focus.bg_color = Color(0, 0, 0, 0)
	reader_focus.border_color = Color.WHITE if high_contrast else Color(1.0, 0.86, 0.52)
	reader_focus.set_border_width_all(3)
	for reader: RichTextLabel in [inventory_text, _decision_details]:
		if reader != null:
			reader.add_theme_stylebox_override("focus", reader_focus)
	if inventory_text != null:
		inventory_text.add_theme_color_override("default_color", Color(0.98, 0.96, 0.88) if high_contrast else Color(0.88, 0.82, 0.70))
		if _preparation_actions != null and _preparation_actions.visible:
			inventory_text.custom_minimum_size.y = 320.0
	for label: Label in _hud_text_labels():
		if label == null:
			continue
		label.add_theme_constant_override("outline_size", 5 if high_contrast else (4 if label == compass_label else 2))
		label.add_theme_color_override("font_outline_color", Color.BLACK if high_contrast else Color(0.01, 0.01, 0.01, 0.78))
		label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88) if high_contrast else Color(0.86, 0.83, 0.74))
	if reduced_motion or flash_reduction:
		for raw: Variant in _bar_tweens.values():
			var tween := raw as Tween
			if tween != null and tween.is_valid():
				tween.kill()
		_bar_tweens.clear()
		for bar: ProgressBar in [health_bar, stamina_bar, enemy_bar]:
			bar.modulate = Color.WHITE
		for tween: Tween in [hint_tween, status_tween, toast_tween, _subtitle_tween]:
			if tween != null and tween.is_valid():
				tween.kill()
		hint_label.modulate = Color.WHITE
		if dialogue_text != null: dialogue_text.modulate = Color.WHITE
		if dialogue_title != null: dialogue_title.modulate = Color.WHITE
		status_label.modulate = _status_color(_status_kind)
	if tracker_back != null:
		(tracker_back as ColorRect).color = Color(0.018, 0.016, 0.014, 0.94 if high_contrast else 0.70)
	if prompt_back != null:
		prompt_back.color = Color(0.018, 0.016, 0.014, 0.95 if high_contrast else 0.72)
	if notice_back != null:
		notice_back.color = Color(0.018, 0.016, 0.014, 0.96 if high_contrast else 0.78)
	if compass_back != null:
		compass_back.visible = high_contrast
		(compass_back as ColorRect).color = Color(0.018, 0.016, 0.014, 0.95)
	for bar: ProgressBar in [health_bar, stamina_bar, enemy_bar]:
		var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill != null:
			fill.bg_color = (Color(0.84, 0.40, 0.30) if high_contrast else Color(0.52, 0.11, 0.08)) if bar != stamina_bar else (Color(0.91, 0.77, 0.42) if high_contrast else Color(0.72, 0.54, 0.18))
	_apply_hud_visual_identity()
	_refresh_resource_attention()
	_update_process_policy()
	view.call_deferred("_apply_hud_layout")

func _controller_sensitivity_label(value: float) -> String:
	if value < 0.8:
		return "Low"
	if value > 1.2:
		return "High"
	return "Medium"

func _capture_remap_input(event: InputEvent) -> bool:
	# Capture before GUI navigation consumes arrows, accept keys or clicks.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1:
		return false
	if active_menu == "remap" and remap_waiting:
		if event.is_action_pressed("ui_cancel"):
			remap_waiting = false
			toast("Binding cancelled.")
			view.get_viewport().set_input_as_handled()
			return true
		var is_binding_event := event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion
		var pressed := true
		if event is InputEventKey:
			pressed = (event as InputEventKey).pressed and not (event as InputEventKey).echo
		elif event is InputEventMouseButton:
			pressed = (event as InputEventMouseButton).pressed
		elif event is InputEventJoypadButton:
			pressed = (event as InputEventJoypadButton).pressed
		elif event is InputEventJoypadMotion:
			pressed = absf((event as InputEventJoypadMotion).axis_value) > 0.45
		if is_binding_event and pressed and input_source != null and input_source.has_method("remap_action"):
			var result: Dictionary = input_source.remap_action(remap_action_id, event)
			remap_waiting = false
			if bool(result.get("ok", false)):
				var conflict := str(result.get("conflict", ""))
				toast("Binding saved%s." % ("; swapped %s" % conflict if conflict != "" else ""))
			else:
				post_notice(str(result.get("message", "That input cannot be assigned.")), "unavailable", 5.0, "binding")
			show_remap_menu(remap_back_target, remap_page)
			view.get_viewport().set_input_as_handled()
			return true
	return false

func _on_off(value: bool) -> String:
	return "On" if value else "Off"

func _shadow_label(value: int) -> String:
	return ["Off", "Balanced", "High"][clampi(value, 0, 2)]

func _sensitivity_label(value: float) -> String:
	if value <= 0.002:
		return "Low"
	if value >= 0.004:
		return "High"
	return "Medium"

func _has_continue_save() -> bool:
	var model: Dictionary = _journey_models.get("continue", {})
	return bool(model.get("available", false))

func _save_status_text() -> String:
	var model: Dictionary = _journey_models.get("continue", {})
	return str(model.get("reason", "No recorded journey is available."))

func _return_from_controls() -> void:
	_return_to_parent()

func set_settings_source(source: Node) -> void:
	_settings_source = source
