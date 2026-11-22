extends "res://scripts/hud/hud_component.gd"
## Hud layout: explicit view operations; requests leave through typed signals.

var _pending_reflow_restore: Callable

func _hud_label(parent: Node, node_name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _hud_text_height(label: Label, reserved_lines: int = -1) -> float:
	var lines: int = label.get_line_count()
	if reserved_lines > 0:
		lines = reserved_lines
	# Label's visible-line budget includes theme spacing and style padding.
	var spacing: float = maxf(0.0, float(label.get_theme_constant("line_spacing")))
	var paragraphs: float = maxf(0.0, float(label.get_theme_constant("paragraph_spacing")))
	var style: StyleBox = label.get_theme_stylebox("normal")
	var padding: float = style.get_minimum_size().y if style != null else 0.0
	return ceilf(lines * label.get_line_height() + maxi(0, lines - 1) * (spacing + paragraphs) + padding)

func set_display_metrics(metrics: Dictionary) -> void:
	if metrics == _display_metrics:
		return
	_display_metrics = metrics.duplicate()
	_queue_responsive_layout()

func _on_viewport_resized() -> void:
	_queue_responsive_layout()

func _apply_hud_layout() -> void:
	_queue_responsive_layout()

func _queue_responsive_layout() -> void:
	if _layout_pending or _layout_applying:
		return
	_layout_pending = true
	view.call_deferred("_apply_responsive_layout")

func _responsive_surface_key() -> String:
	if _journey_load_active:
		return "loading:" + str(_journey_load_applying)
	if is_instance_valid(menu_layer) and menu_layer.visible:
		return "menu:%s:%d" % [_rendered_screen, _screen_generation]
	if is_instance_valid(inventory_layer) and inventory_layer.visible:
		return "inventory:%s:%d" % [_inventory_screen, _inventory_generation]
	if is_instance_valid(dialogue_layer) and dialogue_layer.visible:
		return "dialogue:%d:%d:%s" % [_dialogue_view_generation, dialogue_page_index, str(_topic_navigation.mode)]
	return "gameplay"

func _apply_responsive_layout() -> void:
	_layout_pending = false
	if not view.is_inside_tree() or not is_instance_valid(inventory_layer):
		return
	var display: Dictionary = _display_metrics
	if display.is_empty():
		var window: Window = get_window()
		var window_size: Vector2 = Vector2(window.size) if window != null else Vector2(GAMEPLAY_SIZE)
		display = {"width":window_size.x, "height":window_size.y, "coarse_pointer":input_device == "touch"}
	var policy: Dictionary = HudLayoutPolicy.resolve(Vector2(GAMEPLAY_SIZE), display, story_text_scale, input_device)
	if not bool(policy.get("valid", false)):
		return
	var snapshot: Dictionary = HudReflowState.capture(view)
	var surface_key: String = _responsive_surface_key()
	_layout_generation += 1
	var generation: int = _layout_generation
	_layout_applying = true
	_layout_policy = policy
	_cancel_dialogue_press()
	if is_instance_valid(menu_layer):
		menu_layer.scale = Vector2.ONE
		menu_layer.size = Vector2(GAMEPLAY_SIZE)
	var fonts: Dictionary = policy.get("fonts", {})
	for surface: Control in [dialogue_layer, inventory_layer, menu_layer, loading_layer]:
		if is_instance_valid(surface):
			_apply_responsive_typography(surface, fonts, float(policy.button_min_height), float(policy.unit_scale))
	if _gameplay_ui_ready: _apply_responsive_journal(policy)
	if is_instance_valid(_world_atlas) and _world_atlas.visible:
		_world_atlas.apply_layout(policy)
	if _gameplay_ui_ready: _apply_responsive_dialogue(policy)
	_apply_responsive_menu(policy)
	if is_instance_valid(_startup_view):
		_startup_view.apply_layout(policy)
	_apply_responsive_loading(policy)
	_apply_responsive_gameplay(policy)
	_wire_responsive_inventory_focus()
	_layout_applying = false
	view.call_deferred("_restore_reflow_state", snapshot, generation, surface_key)

func _restore_reflow_state(snapshot: Dictionary, generation: int, surface_key: String) -> void:
	if not is_instance_valid(view) or not view.is_inside_tree():
		return
	# An owned method connection is removed when this panel is freed. An await
	# would leave a suspended function trying to resume after HUD destruction.
	var next_frame: Signal = view.get_tree().process_frame
	if _pending_reflow_restore.is_valid() and next_frame.is_connected(_pending_reflow_restore):
		next_frame.disconnect(_pending_reflow_restore)
	_pending_reflow_restore = _finish_reflow_restore.bind(snapshot, generation, surface_key)
	next_frame.connect(_pending_reflow_restore, CONNECT_ONE_SHOT)

func _finish_reflow_restore(snapshot: Dictionary, generation: int, surface_key: String) -> void:
	_pending_reflow_restore = Callable()
	if not is_instance_valid(view) or not view.is_inside_tree():
		return
	if generation != _layout_generation or surface_key != _responsive_surface_key():
		return
	var restored: bool = HudReflowState.restore(snapshot, view)
	if restored:
		_reveal_menu_focus()
		return
	if inventory_layer.visible:
		if bool(_layout_policy.get("compact", false)) and str(_inventory_panes.get(_inventory_screen, "reader")) == "entries":
			_focus_first_enabled(craft_buttons)
		else:
			if _journal_section_id == "atlas" and is_instance_valid(_world_atlas) and _world_atlas.visible:
				_world_atlas.focus_current()
			else:
				inventory_text.grab_focus()
	elif dialogue_layer.visible:
		_focus_first_enabled(dialogue_actions)
	elif menu_layer.visible and _rendered_screen != "":
		navigation.restore(_rendered_screen, menu_layer)
		_reveal_menu_focus()

func _reveal_menu_focus() -> void:
	if not is_instance_valid(_menu_scroll) or not _menu_scroll.is_visible_in_tree():
		return
	var focused: Control = view.get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and _menu_scroll.is_ancestor_of(focused):
		_menu_scroll.ensure_control_visible(focused)

func _apply_responsive_typography(node: Node, fonts: Dictionary, button_height: float, unit: float) -> void:
	if node is Control:
		var control: Control = node as Control
		var role: String = str(control.get_meta("layout_font_role", "body"))
		if node is Button:
			role = str(control.get_meta("layout_font_role", "button"))
		var font_size: int = int(fonts.get(role, fonts.get("body", 20)))
		if node is RichTextLabel:
			var reader: RichTextLabel = node as RichTextLabel
			_set_responsive_font(reader, "normal_font_size", font_size)
			_set_responsive_font(reader, "bold_font_size", int(fonts.get("subtitle_bold", font_size)) if role == "subtitle" else font_size)
			reader.add_theme_constant_override("line_separation", int(round(4.0 * unit)))
			reader.custom_minimum_size.x = 0.0
		elif node is Label or node is LineEdit or node is TextEdit or node is Button:
			_set_responsive_font(control, "font_size", font_size)
			control.custom_minimum_size.x = 0.0
		if node is Button:
			var button: Button = node as Button
			button.set_meta("layout_button_height", button_height)
			button.set_meta("layout_button_padding", 20.0 * unit)
			button.custom_minimum_size.y = button_height
			for child: Node in button.get_children():
				if child is Label:
					var label: Label = child as Label
					label.text = button.text
					label.set_meta("layout_font_role", role)
					label.add_theme_color_override("font_color", Color(0.50, 0.48, 0.43) if button.disabled else (Color.WHITE if high_contrast else Color(0.94, 0.89, 0.77)))
					label.offset_left = 12.0 * unit
					label.offset_right = -12.0 * unit
					label.offset_top = 10.0 * unit
					label.offset_bottom = -10.0 * unit
			if button.has_meta("menu_text_action"):
				_refresh_menu_action(button)
		elif node is LineEdit:
			control.custom_minimum_size.y = button_height
		elif node is TextEdit:
			control.custom_minimum_size.y = maxf(button_height * 2.0, 140.0 * unit)
		if node is Slider:
			control.custom_minimum_size.x = 0.0
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			control.custom_minimum_size.y = maxf(32.0 * unit, button_height * 0.75)
		if node is Button and bool(node.get_meta("wrapped_label", false)):
			_hide_native_button_text(node as Button)
	for child: Node in node.get_children():
		if not child.is_queued_for_deletion():
			_apply_responsive_typography(child, fonts, button_height, unit)

func _set_responsive_font(control: Control, name: StringName, value: int) -> void:
	if not control.has_theme_font_size_override(name) or control.get_theme_font_size(name) != value:
		control.add_theme_font_size_override(name, value)

func _set_responsive_panel_padding(panel: PanelContainer, padding: float) -> void:
	var source: StyleBox = panel.get_theme_stylebox("panel")
	if source == null:
		return
	if source.content_margin_left == padding and source.content_margin_right == padding and source.content_margin_top == padding and source.content_margin_bottom == padding:
		return
	var style: StyleBox = source.duplicate() as StyleBox
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	panel.add_theme_stylebox_override("panel", style)

func _apply_responsive_journal(policy: Dictionary) -> void:
	var model: Dictionary = policy.journal
	var frame: Rect2 = model.frame
	var compact: bool = bool(model.compact)
	var gap: float = float(policy.gap)
	var pane: String = str(_inventory_panes.get(_inventory_screen, "reader"))
	if not _inventory_panes.has(_inventory_screen):
		pane = "entries" if _journal_section_id == "evidence" and str(_evidence_navigation.selected_id) == "" and _inventory_screen.begins_with("journal:") else "reader"
		_inventory_panes[_inventory_screen] = pane
	_set_responsive_panel_padding(inventory_layer, float(policy.padding))
	inventory_layer.custom_minimum_size = Vector2.ZERO
	inventory_layer.position = frame.position
	inventory_layer.size = frame.size
	_inventory_root.add_theme_constant_override("separation", int(round(gap)))
	_inventory_columns.add_theme_constant_override("separation", int(round(gap)))
	_inventory_columns.custom_minimum_size = Vector2(0.0, float(model.content_height))
	_journal_column.visible = not compact or pane == "reader"
	_journal_actions_scroll.visible = not compact or pane == "entries"
	_journal_column.custom_minimum_size = Vector2.ZERO
	_journal_column.add_theme_constant_override("separation", int(round(gap)))
	_journal_actions_scroll.custom_minimum_size = Vector2(float(model.sidebar_width) if not compact else 0.0, 0.0)
	_journal_actions_scroll.size_flags_horizontal = Control.SIZE_FILL if not compact else Control.SIZE_EXPAND_FILL
	craft_buttons.custom_minimum_size = Vector2.ZERO
	craft_buttons.add_theme_constant_override("separation", int(round(gap)))
	journal_art.custom_minimum_size = Vector2(0.0, float(model.art_height))
	journal_art.visible = float(model.art_height) > 0.0 and journal_art.texture != null and not _preparation_actions.visible and _evidence_position_key == "" and _journal_section_id != "atlas"
	inventory_notice_label.custom_minimum_size = Vector2(0.0, float(model.notice_height))
	var has_actions: bool = _preparation_actions.visible and _preparation_actions.get_child_count() > 0
	var action_height: float = minf(float(model.reader_height), maxf(float(policy.button_min_height), float(model.action_height))) if has_actions else 0.0
	_preparation_actions_scroll.visible = has_actions
	_preparation_actions_scroll.custom_minimum_size = Vector2(0.0, action_height)
	_preparation_actions.add_theme_constant_override("separation", int(round(gap)))
	inventory_text.custom_minimum_size = Vector2(0.0, maxf(0.0, float(model.reader_height) - action_height - (gap if has_actions else 0.0)))
	_inventory_footer.columns = 2 if int(model.footer_rows) > 1 else 3
	_inventory_footer.add_theme_constant_override("h_separation", int(round(gap)))
	_inventory_footer.add_theme_constant_override("v_separation", int(round(gap)))
	_inventory_footer.custom_minimum_size = Vector2(0.0, float(model.footer_height))
	_inventory_read_button.visible = compact
	_inventory_entries_button.visible = compact
	_inventory_read_button.button_pressed = pane == "reader"
	_inventory_entries_button.button_pressed = pane == "entries"
	_inventory_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child: Node in craft_buttons.get_children():
		if child is GridContainer:
			(child as GridContainer).columns = 1 if compact else 2

func _set_inventory_pane(pane: String, focus_content: bool = false) -> void:
	if pane not in ["reader", "entries"]:
		return
	_capture_inventory_state()
	var previous: String = str(_inventory_panes.get(_inventory_screen, "reader"))
	var previous_root: Control = _journal_column if previous == "reader" else _journal_actions_scroll
	_inventory_pane_states[_inventory_pane_state_key(previous)] = HudReflowState.capture(previous_root)
	_inventory_panes[_inventory_screen] = pane
	_queue_responsive_layout()
	if focus_content:
		view.call_deferred("_focus_inventory_pane", pane, _inventory_generation)

func _focus_inventory_pane(pane: String, generation: int) -> void:
	await view.get_tree().process_frame
	if not inventory_layer.visible or generation != _inventory_generation:
		return
	if pane == "reader":
		inventory_text.grab_focus()
	else:
		_focus_first_enabled(craft_buttons)
	var pane_root: Control = _journal_column if pane == "reader" else _journal_actions_scroll
	var snapshot: Dictionary = _inventory_pane_states.get(_inventory_pane_state_key(pane), {})
	if not snapshot.is_empty():
		HudReflowState.restore(snapshot, pane_root)

func _inventory_pane_state_key(pane: String) -> String:
	var selection: Dictionary = _preparation_selection.get(_inventory_screen, {})
	var reading_key: String = _evidence_position_key if _evidence_position_key != "" else str(selection.get("kind", "")) + ":" + str(selection.get("id", ""))
	return _inventory_screen + ":" + pane + ":" + (reading_key if pane == "reader" else "list")

func _close_inventory() -> void:
	dialogue_closed.emit()
	hide_menus()
	resume_requested.emit()

func _wire_responsive_inventory_focus() -> void:
	if not inventory_layer.visible:
		return
	var controls: Array[Control] = []
	_collect_inventory_focus(inventory_layer, controls)
	if controls.is_empty():
		return
	for index: int in range(controls.size()):
		var control: Control = controls[index]
		control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_previous = control.get_path_to(controls[posmod(index - 1, controls.size())])
		if control != inventory_text:
			control.focus_neighbor_top = control.focus_previous
			control.focus_neighbor_bottom = control.focus_next
			control.focus_neighbor_left = NodePath() if bool(_layout_policy.get("compact", false)) else control.get_path_to(inventory_text)

func _apply_responsive_dialogue(policy: Dictionary) -> void:
	var initial: Dictionary = HudLayoutPolicy.dialogue_layout(policy, _decision_details.visible, dialogue_actions.get_child_count())
	var fonts: Dictionary = policy.fonts
	var line_count := HudVisualStyle.subtitle_lines(dialogue_text.get_parsed_text(), dialogue_text.get_theme_font("normal_font"), int(fonts.subtitle), float(initial.content_width))
	var model: Dictionary = HudLayoutPolicy.dialogue_layout(policy, _decision_details.visible, dialogue_actions.get_child_count(), line_count)
	var frame: Rect2 = model.frame
	var gap: float = float(model.gap)
	var outer_scroll: bool = bool(model.outer_scroll)
	_set_responsive_panel_padding(dialogue_layer, float(model.padding))
	dialogue_layer.custom_minimum_size = Vector2.ZERO
	dialogue_layer.position = frame.position
	dialogue_layer.size = frame.size
	_dialogue_header.custom_minimum_size = Vector2(0.0, float(model.header_height))
	_dialogue_header.add_theme_constant_override("separation", int(round(gap * 0.5)))
	_dialogue_body.add_theme_constant_override("separation", int(round(gap)))
	(dialogue_layer.get_child(0) as VBoxContainer).add_theme_constant_override("separation", int(round(gap)))
	_dialogue_body_scroll.custom_minimum_size = Vector2(0.0, float(model.body_height))
	_dialogue_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if outer_scroll else ScrollContainer.SCROLL_MODE_DISABLED
	dialogue_text.custom_minimum_size = Vector2(0.0, float(model.reader_height))
	_decision_details.custom_minimum_size = Vector2(0.0, float(model.stakes_height))
	dialogue_choices_scroll.custom_minimum_size = Vector2(0.0, float(model.choices_height))
	dialogue_actions.add_theme_constant_override("separation", int(round(gap)))
	_dialogue_back_button.text = "Back" if str(_topic_navigation.mode) != "primary" else "Close"
	dialogue_title.tooltip_text = dialogue_title.text
	for button: Button in [_dialogue_history_button, _dialogue_back_button]:
		HudVisualStyle.dialogue_choice(button, high_contrast)
	for child in dialogue_actions.get_children():
		if child is Button: HudVisualStyle.dialogue_choice(child, high_contrast)

func _apply_responsive_menu(policy: Dictionary) -> void:
	if active_menu == "startup":
		return
	if not is_instance_valid(_menu_frame) or not is_instance_valid(_menu_content):
		return
	var model: Dictionary = policy.menu
	var compact: bool = bool(model.compact)
	var short_display: bool = bool(policy.get("short_display", false))
	var primary_surface: bool = active_menu in ["main", "pause", "death", "ending"]
	var frame: Rect2 = model.frame
	var gap: float = float(policy.gap)
	var padding: float = float(policy.padding)
	_menu_frame.position = frame.position
	_menu_frame.size = frame.size
	_menu_frame_box.add_theme_constant_override("separation", int(round(gap)))
	_menu_shell.add_theme_constant_override("separation", int(round(gap)))
	_menu_title_stack.add_theme_constant_override("separation", int(round(gap)))
	_menu_content.add_theme_constant_override("separation", int(round(gap)))
	_menu_content.custom_minimum_size = Vector2.ZERO
	_menu_title_stack.custom_minimum_size = Vector2.ZERO
	_menu_title_spacer.visible = not compact
	_menu_title_stack.visible = not (compact and primary_surface)
	_compact_menu_title.visible = compact and primary_surface
	_compact_menu_title.add_theme_font_size_override("font_size", int(Dictionary(policy.fonts).get("heading", 26)))
	_menu_title_spacer.custom_minimum_size.y = 24.0 * float(policy.unit_scale)
	if compact and not _menu_content.get_children().has(_menu_title_stack):
		_menu_title_stack.reparent(_menu_content)
		_menu_content.move_child(_menu_title_stack, 0)
	elif not compact and not _menu_shell.get_children().has(_menu_title_stack):
		_menu_title_stack.reparent(_menu_shell)
		_menu_shell.move_child(_menu_title_stack, 0)
	_menu_title_stack.size_flags_vertical = Control.SIZE_FILL if compact else Control.SIZE_EXPAND_FILL
	_menu_title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
	_menu_panel.custom_minimum_size = Vector2(0.0 if compact else float(model.panel_width), 0.0)
	# The scroll container, not the title/card's minimum height, owns overflow.
	_menu_shell.custom_minimum_size = Vector2.ZERO
	_set_responsive_panel_padding(_menu_panel, padding)
	_menu_content.set_meta("menu_button_width", 0.0)
	_menu_content.set_meta("menu_button_height", float(policy.button_min_height))
	_menu_content.set_meta("menu_font_size", int(Dictionary(policy.fonts).get("button", 20)))
	_menu_content.set_meta("compact_buttons", compact)
	_menu_footer.custom_minimum_size.y = float(model.footer_height)
	_menu_footer.add_theme_constant_override("separation", int(round(gap)))
	_menu_notice.custom_minimum_size = Vector2.ZERO
	_menu_notice.visible = _menu_notice.text != ""
	for child: Node in _menu_title_stack.get_children():
		if child is Control and bool(child.get_meta("menu_secondary_heading", false)):
			(child as Control).visible = not (short_display and active_menu in ["main", "pause"])
	if is_instance_valid(_journey_card):
		_journey_card.visible = _journey_card_kind != "" and not (compact and primary_surface)
		_journey_card.custom_minimum_size = Vector2(0.0, minf(180.0 * float(policy.unit_scale), maxf(float(policy.button_min_height), frame.size.y * (0.3 if compact else 0.45))))
	for child: Node in _menu_content.get_children():
		if child is RichTextLabel:
			(child as RichTextLabel).custom_minimum_size.y = maxf(float(policy.button_min_height) * 2.0, minf(360.0 * float(policy.unit_scale), frame.size.y * 0.5))

func _apply_responsive_loading(policy: Dictionary) -> void:
	if not is_instance_valid(_loading_card):
		_loading_card = loading_layer.get_node_or_null("RoadCard") as PanelContainer
	if not is_instance_valid(_loading_card):
		return
	var model: Dictionary = policy.loading
	var frame: Rect2 = model.frame
	_loading_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_set_responsive_panel_padding(_loading_card, float(policy.padding))
	_loading_card.custom_minimum_size = Vector2.ZERO
	_loading_card.position = frame.position
	_loading_card.size = frame.size
	loading_message.custom_minimum_size = Vector2.ZERO
	loading_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loading_message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_journey_cancel_button.custom_minimum_size.y = float(policy.button_min_height)

func _apply_responsive_gameplay(policy: Dictionary) -> void:
	_touch_shared_prompt = false
	var safe: Rect2 = policy.safe_rect
	var usable: Vector2 = policy.display_usable_size
	var unit: float = float(policy.unit_scale)
	var compact: bool = bool(policy.compact)
	var gap: float = float(policy.gap)
	var fonts: Dictionary = policy.fonts
	var touch: bool = input_device == "touch"
	prompt_label.max_lines_visible = 3 if touch else 2
	var touch_model: Dictionary = MobileTouchLayout.build(Vector2(GAMEPLAY_SIZE), _display_metrics) if touch else {}
	var reserved_bottom: float = float(touch_model.get("bottom_reserved_display", 0.0)) * unit
	var margin: float = (12.0 if compact else 24.0) * unit
	var left: float = safe.position.x + margin
	var right: float = safe.end.x - margin
	var top: float = safe.position.y + margin
	var bottom: float = safe.end.y - margin
	var center: float = safe.get_center().x
	var touch_center: Rect2 = touch_model.get("center_rect", Rect2())
	var center_channel: float = touch_center.size.x if touch and bool(touch_model.get("playable", false)) else safe.size.x - margin * 2.0
	var crest_size: float = (62.0 if compact else 84.0) * unit
	var vitals_width: float = minf(228.0 * unit, safe.size.x * 0.27) if touch else minf(470.0 * unit, safe.size.x * (0.48 if compact else 0.42))
	var bar_left: float = left + crest_size * 0.79
	var bar_width: float = maxf(0.0, vitals_width - crest_size * 0.79)
	_hart_emblem.position = Vector2(left, top + 4.0 * unit)
	_hart_emblem.size = Vector2.ONE * crest_size
	health_bar.position = Vector2(bar_left, top + 25.0 * unit)
	health_bar.size = Vector2(bar_width, (21.0 if compact else 25.0) * unit)
	stamina_bar.position = Vector2(bar_left + 3.0 * unit, top + 56.0 * unit)
	stamina_bar.size = Vector2(maxf(0.0, bar_width * 0.79 - 3.0 * unit), 9.0 * unit)
	for label: Label in [health_value_label, stamina_value_label, vitals_warning_label]:
		label.add_theme_font_size_override("font_size", int(fonts.caption))
	health_value_label.position = Vector2(bar_left, top + 2.0 * unit)
	health_value_label.size = Vector2(bar_width - 16.0 * unit, 23.0 * unit)
	stamina_value_label.position = Vector2(bar_left + bar_width * 0.73, top + 48.0 * unit)
	stamina_value_label.size = Vector2(bar_width * 0.27, 23.0 * unit)
	_bar_name_labels[0].position = Vector2(bar_left + 3.0 * unit, top + 2.0 * unit)
	_bar_name_labels[0].size = Vector2(bar_width * 0.46, 23.0 * unit)
	_bar_name_labels[0].visible = bar_width >= 190.0 * float(policy.text_scale) * unit
	_bar_name_labels[1].position = Vector2(bar_left + 3.0 * unit, top + 70.0 * unit)
	_bar_name_labels[1].size = Vector2(bar_width, 23.0 * unit)
	for label: Label in _bar_name_labels:
		label.add_theme_font_size_override("font_size", int(fonts.caption))
	_bar_name_labels[1].visible = not compact
	vitals_warning_label.position = Vector2(left + 4.0 * unit, top + (77.0 if compact else 100.0) * unit)
	vitals_warning_label.size = Vector2(vitals_width, 25.0 * unit)
	vitals_warning_label.custom_minimum_size = Vector2.ZERO
	vitals_back.position = Vector2(left - 5.0 * unit, top - 3.0 * unit)
	vitals_back.size = Vector2(vitals_width + 10.0 * unit, (102.0 if compact else 122.0) * unit)
	xp_label.position = Vector2(left + 4.0 * unit, top + (104.0 if compact else 126.0) * unit)
	xp_label.size = Vector2(vitals_width, 52.0 * unit)
	xp_label.add_theme_font_size_override("font_size", int(fonts.caption))
	xp_bar.position = Vector2(left + 4.0 * unit, top + (158.0 if compact else 180.0) * unit)
	xp_bar.size = Vector2(vitals_width, 4.0 * unit)
	var dial_visible: bool = usable.x >= 820.0 and usable.y >= 500.0
	var dial_size: float = (146.0 if compact else 174.0) * unit
	var dial_top: float = top + (66.0 if touch else 22.0) * unit
	_pointer_pause_button.visible = not touch
	_pointer_pause_button.position = Vector2(right - (dial_size + 58.0 * unit if dial_visible else 48.0 * unit), top)
	_pointer_pause_button.size = Vector2.ONE * 48.0 * unit
	_pointer_pause_button.custom_minimum_size = Vector2.ONE * 48.0 * unit
	_navigation_dial.visible = dial_visible
	_navigation_dial.position = Vector2(right - dial_size, dial_top)
	_navigation_dial.size = Vector2.ONE * dial_size
	_world_clock_label.visible = dial_visible
	_world_clock_label.position = Vector2(right - 230.0 * unit, dial_top - 24.0 * unit)
	_world_clock_label.size = Vector2(230.0 * unit, 24.0 * unit)
	_world_clock_label.add_theme_font_size_override("font_size", int(fonts.caption))
	var quest_width: float = minf((290.0 if compact else 308.0) * unit, safe.size.x * (0.45 if compact else 0.30))
	var quest_x: float = right - quest_width
	var location_y: float = dial_top + dial_size + 3.0 * unit
	compass_label.visible = dial_visible
	compass_label.position = Vector2(quest_x, location_y)
	compass_label.size = Vector2(quest_width, 26.0 * unit)
	compass_label.add_theme_font_size_override("font_size", int(fonts.caption))
	compass_back.position = compass_label.position - Vector2(4, 2) * unit
	compass_back.size = compass_label.size + Vector2(8, 4) * unit
	compass_back.visible = high_contrast and dial_visible
	var quest_y: float = location_y + 34.0 * unit if dial_visible else top + (66.0 if touch else 56.0) * unit
	var room_below: float = maxf(0.0, (safe.end.y - reserved_bottom - gap if touch else bottom - 136.0 * unit) - quest_y)
	tracker_title_label.add_theme_font_size_override("font_size", int(fonts.body))
	tracker_title_label.size.x = quest_width
	var title_height: float = maxf((42.0 if not compact else 25.0) * unit, _hud_text_height(tracker_title_label, 2) + 2.0 * unit)
	var show_title: bool = not compact or room_below >= 140.0 * unit
	tracker_title_label.visible = show_title
	tracker_title_label.position = Vector2(quest_x, quest_y)
	tracker_title_label.size = Vector2(quest_width, title_height)
	tracker_caption_label.visible = false
	_quest_rule.visible = show_title
	_quest_rule.position = Vector2(quest_x, quest_y + title_height + 2.0 * unit)
	_quest_rule.size = Vector2(minf(90.0 * unit, quest_width), maxf(1.0, unit))
	var action_y: float = quest_y + title_height + 13.0 * unit if show_title else quest_y
	tracker_label.add_theme_font_size_override("font_size", int(fonts.body))
	tracker_label.size.x = maxf(0.0, quest_width - 22.0 * unit)
	var action_needed: float = _hud_text_height(tracker_label) + 2.0 * unit
	var action_height: float = minf(maxf((78.0 if not compact else 66.0) * unit, action_needed), maxf(32.0 * unit, room_below - (action_y - quest_y)))
	_quest_marker.position = Vector2(quest_x - 2.0 * unit, action_y + 2.0 * unit)
	_quest_marker.size = Vector2(20.0 * unit, 24.0 * unit)
	_quest_marker.add_theme_font_size_override("font_size", int(fonts.caption))
	tracker_label.position = Vector2(quest_x + 22.0 * unit, action_y)
	tracker_label.size = Vector2(maxf(0.0, quest_width - 22.0 * unit), action_height)
	var route_y: float = action_y + action_height + 5.0 * unit
	for label: Label in [tracker_route_label, tracker_work_label, tracker_footer_label]:
		label.add_theme_font_size_override("font_size", int(fonts.caption))
	# Reserve complete caption lines, including the active font's metrics and spacing.
	var route_height: float = maxf(42.0 * unit, _hud_text_height(tracker_route_label, 2) + 2.0 * unit)
	var work_height: float = maxf(38.0 * unit, _hud_text_height(tracker_work_label, 2) + 2.0 * unit)
	var work_y: float = route_y + route_height + 2.0 * unit
	var footer_y: float = work_y + work_height + 4.0 * unit
	var footer_height: float = maxf(24.0 * unit, _hud_text_height(tracker_footer_label, 1) + 2.0 * unit)
	tracker_route_label.position = Vector2(quest_x + 22.0 * unit, route_y)
	tracker_route_label.size = Vector2(quest_width - 22.0 * unit, route_height)
	tracker_route_label.visible = not compact and route_y + route_height <= quest_y + room_below
	tracker_work_label.position = Vector2(quest_x + 22.0 * unit, work_y)
	tracker_work_label.size = Vector2(quest_width - 22.0 * unit, work_height)
	tracker_work_label.visible = not compact and work_y + work_height <= quest_y + room_below
	tracker_footer_label.position = Vector2(quest_x + 22.0 * unit, footer_y)
	tracker_footer_label.size = Vector2(quest_width - 22.0 * unit, footer_height)
	tracker_footer_label.visible = not compact and not touch and footer_y + footer_height <= quest_y + room_below
	tracker_back.position = Vector2(quest_x - 8.0 * unit, quest_y - 6.0 * unit)
	tracker_back.size = Vector2(quest_width + 16.0 * unit, minf(room_below, (258.0 if not compact else 118.0) * unit))
	var slot_width: float = (86.0 if compact else 94.0) * unit
	var slot_height: float = 116.0 * unit
	var slots_visible: bool = not (touch and compact)
	supplies_grid.visible = slots_visible
	supplies_grid.position = Vector2(left, bottom - reserved_bottom - slot_height - (gap if touch else 0.0))
	supplies_grid.add_theme_constant_override("h_separation", int(round(8.0 * unit)))
	supplies_grid.size = Vector2(slot_width * 3.0 + 16.0 * unit, slot_height)
	for id: String in ["potions", "bombs", "arrows"]:
		var slot: Control = _quick_slots[id]
		slot.custom_minimum_size = Vector2(slot_width, slot_height)
		var icon: Control = _quick_icons[id]
		icon.position = Vector2((slot_width - 62.0 * unit) * 0.5, 0.0)
		icon.size = Vector2.ONE * 62.0 * unit
		var count: Label = supply_counts[id]
		count.position = Vector2(slot_width * 0.48, 3.0 * unit)
		count.size = Vector2(slot_width * 0.48, 24.0 * unit)
		count.add_theme_font_size_override("font_size", int(fonts.body))
		var name_label: Label = supply_labels[id]
		name_label.position = Vector2(0, 62.0 * unit)
		name_label.size = Vector2(slot_width, 23.0 * unit)
		name_label.add_theme_font_size_override("font_size", int(fonts.caption))
		var key: Label = _quick_bindings[id]
		key.position = Vector2(0, 86.0 * unit)
		key.size = Vector2(slot_width, 30.0 * unit)
		key.add_theme_font_size_override("font_size", int(fonts.caption))
	equipment_label.visible = slots_visible
	equipment_label.position = Vector2(left + 6.0 * unit, supplies_grid.position.y - 28.0 * unit)
	equipment_label.size = Vector2(supplies_grid.size.x, 24.0 * unit)
	equipment_label.add_theme_font_size_override("font_size", int(fonts.caption))
	_gameplay_bindings.visible = not touch and not compact
	_gameplay_bindings.position = Vector2(right - 290.0 * unit, bottom - (90.0 if not compact else 48.0) * unit)
	_gameplay_bindings.size = Vector2(290.0 * unit, (90.0 if not compact else 48.0) * unit)
	_gameplay_bindings.max_lines_visible = 4 if not compact else 2
	_gameplay_bindings.add_theme_font_size_override("font_size", int(fonts.caption))
	var enemy_width: float = minf(320.0 * unit, center_channel if touch else safe.size.x * 0.37)
	var target_y: float = top + (150.0 if touch and compact else (160.0 if compact else 8.0)) * unit
	enemy_label.position = Vector2(center - enemy_width * 0.5, target_y)
	enemy_label.size = Vector2(enemy_width, 25.0 * unit)
	enemy_label.add_theme_font_size_override("font_size", int(fonts.body))
	enemy_bar.position = Vector2(center - enemy_width * 0.5, target_y + 29.0 * unit)
	enemy_bar.size = Vector2(enemy_width - 72.0 * unit, 10.0 * unit)
	enemy_value_label.position = Vector2(center + enemy_width * 0.5 - 68.0 * unit, target_y + 23.0 * unit)
	enemy_value_label.size = Vector2(68.0 * unit, 24.0 * unit)
	enemy_value_label.add_theme_font_size_override("font_size", int(fonts.caption))
	target_status_label.position = Vector2(center - enemy_width * 0.5, target_y + 47.0 * unit)
	target_status_label.size = Vector2(enemy_width, 24.0 * unit)
	target_status_label.add_theme_font_size_override("font_size", int(fonts.caption))
	var prompt_width: float = minf(430.0 * unit, center_channel)
	prompt_label.add_theme_font_size_override("font_size", int(fonts.body))
	var prompt_height: float = maxf(55.0 * unit, _hud_text_height(prompt_label, 2) + 2.0 * unit)
	prompt_label.position = Vector2(center - prompt_width * 0.5, bottom - prompt_height - 14.0 * unit)
	prompt_label.size = Vector2(prompt_width, prompt_height)
	prompt_back.position = prompt_label.position - Vector2(6, 2) * unit
	prompt_back.size = prompt_label.size + Vector2(12, 4) * unit
	var status_width: float = minf(360.0 * unit, center_channel)
	status_label.add_theme_font_size_override("font_size", int(fonts.caption))
	var status_height: float = maxf(28.0 * unit, _hud_text_height(status_label, 1) + 2.0 * unit)
	status_label.position = Vector2(center - status_width * 0.5, prompt_label.position.y - status_height - 9.0 * unit)
	status_label.size = Vector2(status_width, status_height)
	hint_label.position = Vector2(center - status_width * 0.5, target_y + 77.0 * unit)
	hint_label.add_theme_font_size_override("font_size", int(fonts.caption))
	hint_label.size = Vector2(status_width, maxf(48.0 * unit, _hud_text_height(hint_label, 2) + 2.0 * unit))
	var notice_width: float = minf(330.0 * unit, center_channel if touch else safe.size.x - margin * 2.0)
	var notice_x: float = center - notice_width * 0.5 if touch else left
	var notice_y: float = bottom - 250.0 * unit if touch else supplies_grid.position.y - 166.0 * unit
	notice_back.position = Vector2(notice_x - 6.0 * unit, notice_y - 4.0 * unit)
	notice_back.size = Vector2(notice_width + 12.0 * unit, 122.0 * unit)
	notice_category_label.position = Vector2(notice_x, notice_y)
	notice_category_label.size = Vector2(notice_width, 24.0 * unit)
	notice_category_label.add_theme_font_size_override("font_size", int(fonts.caption))
	toast_label.position = Vector2(notice_x, notice_y + 28.0 * unit)
	toast_label.size = Vector2(notice_width, 85.0 * unit)
	toast_label.add_theme_font_size_override("font_size", int(fonts.body))
	if compact and not touch:
		_touch_shared_prompt = true
		var message_x := center - notice_width * 0.5
		var message_y := bottom - 110.0 * unit
		notice_back.position = Vector2(message_x - 6.0 * unit, message_y - 4.0 * unit)
		notice_category_label.position = Vector2(message_x, message_y)
		toast_label.position = Vector2(message_x, message_y + 24.0 * unit)
		toast_label.max_lines_visible = 3
		hint_label.position = Vector2(message_x, message_y)
		hint_label.size = Vector2(notice_width, 64.0 * unit)
		status_label.position = hint_label.position
		status_label.size = hint_label.size
	if touch and bool(touch_model.get("playable", false)):
		_apply_touch_gameplay_regions(touch_model, unit)
	else:
		_refresh_touch_message_visibility()
	_apply_hud_visual_colors()

func _apply_touch_gameplay_regions(model: Dictionary, unit: float) -> void:
	_touch_shared_prompt = bool(model.get("shared_message_prompt", false))
	var corridor: Rect2 = model.center_rect
	var prompt: Rect2 = model.prompt_rect
	var messages: Rect2 = model.message_rect
	prompt_label.position = prompt.position
	prompt_label.size = prompt.size
	prompt_label.max_lines_visible = 3
	prompt_back.position = prompt.position - Vector2(4, 2) * unit
	prompt_back.size = prompt.size + Vector2(8, 4) * unit
	var width := minf(320.0 * unit, corridor.size.x)
	var x := corridor.get_center().x - width * 0.5
	var top := corridor.position.y + 12.0 * unit
	enemy_label.position = Vector2(x, top)
	enemy_label.size = Vector2(width, 24.0 * unit)
	enemy_bar.position = Vector2(x, top + 28.0 * unit)
	enemy_bar.size = Vector2(maxf(0.0, width - 60.0 * unit), 9.0 * unit)
	enemy_value_label.position = Vector2(x + width - 56.0 * unit, top + 22.0 * unit)
	enemy_value_label.size = Vector2(56.0 * unit, 24.0 * unit)
	target_status_label.position = Vector2(x, top + 44.0 * unit)
	target_status_label.size = Vector2(width, 24.0 * unit)
	status_label.position = messages.position
	status_label.size = messages.size
	hint_label.position = messages.position
	hint_label.size = messages.size
	notice_category_label.position = messages.position
	notice_category_label.size = Vector2(messages.size.x, 20.0 * unit)
	toast_label.position = messages.position + Vector2(0, 22.0 * unit)
	toast_label.size = Vector2(messages.size.x, maxf(0.0, messages.size.y - 22.0 * unit))
	notice_back.position = messages.position - Vector2(4, 2) * unit
	notice_back.size = messages.size + Vector2(8, 4) * unit
	_refresh_touch_message_visibility()

func _refresh_touch_message_visibility() -> void:
	if hint_label == null or status_label == null:
		return
	var notice_visible := toast_label != null and toast_label.visible
	var blocked := _gameplay_surface_blocked()
	var shared: bool = input_device == "touch" or _touch_shared_prompt
	hint_label.visible = not blocked and (not shared or not notice_visible) and _hint_remaining > 0.0 and raw_hint != ""
	status_label.visible = not blocked and (not shared or (not notice_visible and not hint_label.visible)) and _status_remaining > 0.0
	var message_visible: bool = notice_visible or hint_label.visible or status_label.visible
	prompt_label.visible = not blocked and raw_prompt != "" and not (_touch_shared_prompt and message_visible)
	if prompt_back != null:
		prompt_back.visible = prompt_label.visible

func _apply_theme() -> void:
	_apply_hud_visual_identity()
	_style_panel(inventory_layer, Color(0.035, 0.038, 0.04, 0.97), Color(0.49, 0.47, 0.39, 0.75))

func _apply_hud_visual_identity() -> void:
	HudVisualStyle.apply_bar(health_bar, "blood", high_contrast)
	HudVisualStyle.apply_bar(stamina_bar, "stamina", high_contrast)
	HudVisualStyle.apply_bar(enemy_bar, "enemy", high_contrast)
	if is_instance_valid(_hart_emblem):
		_hart_emblem.call("configure", "hart", high_contrast)
	if is_instance_valid(_navigation_dial):
		_navigation_dial.call("set_high_contrast", high_contrast)
	for id: String in _quick_icons:
		(_quick_icons[id] as Control).call("configure", str((_quick_icons[id] as Control).get_meta("quick_motif", id)), high_contrast)
	var settings: Dictionary = _current_settings()
	var opacity: float = clampf(float(settings.get("subtitle_background_opacity", 0.55)), 0.0, 1.0)
	dialogue_layer.add_theme_stylebox_override("panel", HudVisualStyle.dialogue_panel(high_contrast, opacity))
	if _gameplay_ui_ready:
		dialogue_title.add_theme_color_override("font_color", Color.WHITE if high_contrast else HudVisualStyle.GOLD)
		dialogue_text.add_theme_color_override("default_color", Color.WHITE if high_contrast else HudVisualStyle.IVORY)
		_dialogue_history_button.add_theme_color_override("font_color", Color.WHITE if high_contrast else HudVisualStyle.MUTED)
		_dialogue_back_button.add_theme_color_override("font_color", Color.WHITE if high_contrast else HudVisualStyle.MUTED)
	_apply_hud_visual_colors()

func _apply_hud_visual_colors() -> void:
	for label: Label in _hud_text_labels():
		if label != null: HudVisualStyle.label_color(label, HudVisualStyle.IVORY, high_contrast)
	for label: Label in [tracker_title_label, _quest_marker, notice_category_label]:
		HudVisualStyle.label_color(label, HudVisualStyle.GOLD, high_contrast)
	for label: Label in [tracker_route_label, tracker_work_label, tracker_footer_label, compass_label, _world_clock_label, _gameplay_bindings, equipment_label, stamina_value_label]:
		HudVisualStyle.label_color(label, HudVisualStyle.MUTED, high_contrast)
	for label: Label in _bar_name_labels:
		HudVisualStyle.label_color(label, HudVisualStyle.SILVER, high_contrast)
	for raw: Variant in _quick_bindings.values():
		HudVisualStyle.label_color(raw as Label, HudVisualStyle.MUTED, high_contrast)
	var danger: bool = last_health > 0.0 and float(last_health) / maxf(float(last_health_max), 1.0) <= 0.28
	HudVisualStyle.label_color(vitals_warning_label, Color("edb397") if danger else HudVisualStyle.GOLD, high_contrast)
	status_label.add_theme_color_override("font_color", _status_color(_status_kind))
	vitals_back.color = Color(0.008, 0.012, 0.015, 0.94 if high_contrast else (0.12 if _attention_remaining > 0.0 or danger else 0.0))
	(tracker_back as ColorRect).color = Color(0.008, 0.012, 0.015, 0.93 if high_contrast else 0.0)
	(compass_back as ColorRect).color = Color(0.008, 0.012, 0.015, 0.94 if high_contrast else 0.0)
	prompt_back.color = Color(0.008, 0.012, 0.015, 0.95 if high_contrast else 0.0)
	notice_back.color = Color(0.008, 0.012, 0.015, 0.94 if high_contrast else 0.0)
	_quest_rule.color = Color.WHITE if high_contrast else Color(0.66, 0.59, 0.38, 0.62)

func _hud_text_labels() -> Array[Label]:
	var labels: Array[Label] = [enemy_label, enemy_value_label, target_status_label, prompt_label, tracker_label, compass_label, toast_label, hint_label, status_label, equipment_label, health_value_label, stamina_value_label, tracker_title_label, tracker_caption_label, tracker_route_label, tracker_work_label, tracker_footer_label, vitals_warning_label, notice_category_label, inventory_notice_label]
	labels.append_array(_bar_name_labels)
	labels.append_array([_world_clock_label, _gameplay_bindings, _quest_marker, xp_label])
	for raw: Variant in supply_labels.values():
		labels.append(raw as Label)
	for raw: Variant in supply_counts.values():
		labels.append(raw as Label)
	return labels

func _style_panel(panel: PanelContainer, bg_color: Color, border_color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 28
	style.content_margin_top = 28
	style.content_margin_right = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)

func _add_hud_accent(parent: Control, position: Vector2, size: Vector2) -> void:
	var accent := ColorRect.new()
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent.position = position
	accent.size = size
	accent.color = Color(0.62, 0.42, 0.18, 0.88)
	parent.add_child(accent)
