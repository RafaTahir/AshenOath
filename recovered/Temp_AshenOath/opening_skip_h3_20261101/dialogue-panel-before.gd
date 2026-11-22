extends "res://scripts/hud/hud_component.gd"
## Dialogue panel: explicit view operations; requests leave through typed signals.

func _build_ambient_subtitles() -> void:
	_ambient_panel = PanelContainer.new()
	_ambient_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(_ambient_panel)
	_ambient_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_ambient_panel.anchor_left = 0.16
	_ambient_panel.anchor_right = 0.84
	_ambient_panel.offset_left = 0
	_ambient_panel.offset_right = 0
	_ambient_panel.offset_top = -156
	_ambient_panel.offset_bottom = -74
	_ambient_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ambient_words = Label.new()
	_ambient_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ambient_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ambient_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ambient_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ambient_panel.add_child(_ambient_words)
	_ambient_panel.hide()

func ambient_subtitle_available(owner_id: int) -> bool:
	return not _gameplay_surface_blocked() and not view.get_tree().paused and (_ambient_owner == 0 or _ambient_owner == owner_id)

func show_ambient_subtitle(owner_id: int, speaker: String, words: String, duration: float) -> bool:
	if not is_instance_valid(_ambient_panel) or not ambient_subtitle_available(owner_id):
		return false
	var current := _current_settings()
	_ambient_owner = owner_id
	_ambient_remaining = maxf(1.0, duration)
	_ambient_words.text = (speaker + ": " if bool(current.get("subtitle_speaker_names", true)) else "") + words
	_ambient_words.add_theme_font_size_override("font_size", int(20 * clampf(float(current.get("subtitle_scale", 1.0)), 0.9, 1.5)))
	_ambient_panel.add_theme_stylebox_override("panel", HudVisualStyle.dialogue_panel(bool(current.get("high_contrast", false)), clampf(float(current.get("subtitle_background_opacity", 0.55)), 0, 1)))
	_ambient_panel.show()
	_update_process_policy()
	return true

func clear_ambient_subtitle(owner_id: int) -> void:
	if _ambient_owner != owner_id:
		return
	_ambient_remaining = 0.0
	_ambient_owner = 0
	if is_instance_valid(_ambient_panel):
		_ambient_panel.hide()
	_update_process_policy()

func show_opening_scene_skip(skip: Callable) -> void:
	hide_opening_scene_skip()
	var button := Button.new()
	button.name = "OpeningSceneSkip"
	button.text = "Skip introduction"
	button.custom_minimum_size = Vector2(176, 48)
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -204
	button.offset_right = -24
	button.offset_top = 24
	button.offset_bottom = 80
	button.pressed.connect(skip)
	hud_root.add_child(button)
	button.grab_focus()

func hide_opening_scene_skip() -> void:
	if not is_instance_valid(hud_root): return
	var button := hud_root.get_node_or_null("OpeningSceneSkip")
	if button != null:
		hud_root.remove_child(button)
		button.queue_free()

func get_dialogue_topic_seen_keys() -> Array[String]:
	return DialogueTopicNavigation.seen_keys(text_history.entries)

func _has_optional_topics() -> bool:
	var rows: Array = dialogue_session_data.get("optional_topics", [])
	return str(dialogue_session_data.get("topic_context_id", "")) != "" and not rows.is_empty()

func _open_dialogue_topics() -> void:
	if str(_topic_navigation.mode) == "primary":
		_capture_dialogue_reading_state()
		var detail: Dictionary = {"key":_decision_selected_key, "text":_decision_details.text, "visible":_decision_details.visible}
		_topic_navigation.remember_primary(dialogue_session_data, dialogue_pages, dialogue_page_index, _dialogue_reading_state, detail)
	if _topic_navigation.primary.is_empty():
		return
	dialogue_speech_interrupted.emit()
	_cancel_dialogue_press()
	_topic_navigation.mode = "list"
	_topic_navigation.requested_id = ""
	_topic_navigation.requested_revision = ""
	_render_dialogue_topic_list()

func _render_dialogue_topic_list() -> void:
	_dialogue_view_generation += 1
	_dialogue_reading_state.clear()
	_decision_selected_key = ""
	_decision_details.visible = false
	var primary: Dictionary = _topic_navigation.primary.get("session", {})
	dialogue_title.text = str(primary.get("name", "Conversation")) + " — Ask more"
	dialogue_title.visible = true
	dialogue_page_label.text = "Optional conversation"
	dialogue_text.text = "Ask about what has already happened."
	if str(_topic_navigation.list_message) != "":
		dialogue_text.text += "\n\n" + str(_topic_navigation.list_message)
	for child in dialogue_actions.get_children():
		dialogue_actions.remove_child(child)
		child.queue_free()
	var seen: Array[String] = get_dialogue_topic_seen_keys()
	var rows: Array = _topic_navigation.rows()
	for raw: Variant in rows:
		if not raw is Dictionary:
			continue
		var row: Dictionary = raw
		var id: String = str(row.get("id", ""))
		if id == "":
			continue
		var recorded: bool = seen.has(str(row.get("history_key", "")))
		var label: String = str(row.get("title", "Ask a question")) + ("\nIn History" if recorded else "")
		var button: Button = _add_topic_navigation_button(label, "topic:" + id, func(topic: Dictionary = row): _request_dialogue_topic(topic))
		button.focus_entered.connect(func(topic: Dictionary = row): _show_dialogue_topic_summary(topic))
		button.mouse_entered.connect(func(topic: Dictionary = row): _show_dialogue_topic_summary(topic))
	_add_topic_navigation_button("Back to Conversation", "topics_back", _return_to_primary_dialogue)
	dialogue_choices_scroll.custom_minimum_size.y = 180.0 if rows.size() > 2 else 154.0
	view.call_deferred("_restore_topic_list_reading", _dialogue_view_generation)
	view.call_deferred("_apply_hud_layout")

func _show_dialogue_topic_summary(row: Dictionary) -> void:
	if str(_topic_navigation.mode) != "list":
		return
	var text: String = str(row.get("title", "")) + "\n\n" + str(row.get("summary", ""))
	if str(_topic_navigation.list_message) != "":
		text += "\n\n" + str(_topic_navigation.list_message)
	if dialogue_text.text != text:
		dialogue_text.text = text
		dialogue_text.scroll_to_line(0)

func _request_dialogue_topic(row: Dictionary) -> void:
	if str(_topic_navigation.mode) != "list" or str(_topic_navigation.requested_id) != "":
		return
	_capture_dialogue_reading_state()
	_topic_navigation.list_reading = _dialogue_reading_state.duplicate(true)
	_topic_navigation.requested_id = str(row.get("id", ""))
	_topic_navigation.requested_revision = str(row.get("revision_key", ""))
	_topic_navigation.list_message = ""
	dialogue_speech_interrupted.emit()
	dialogue_topic_requested.emit(str(_topic_navigation.context_id()), str(_topic_navigation.requested_id), str(_topic_navigation.requested_revision))

func show_dialogue_topic(scene: Dictionary) -> void:
	if str(_topic_navigation.mode) != "list" or _topic_navigation.primary.is_empty():
		return
	if str(scene.get("topic_context_id", "")) != str(_topic_navigation.context_id()):
		return
	if str(scene.get("topic_id", "")) != str(_topic_navigation.requested_id) or str(scene.get("topic_revision", "")) != str(_topic_navigation.requested_revision):
		return
	if not bool(scene.get("read_only", false)):
		dialogue_topic_unavailable(str(_topic_navigation.context_id()))
		return
	var pages: Array = []
	for raw: Variant in scene.get("pages", []):
		if raw is Dictionary and str(raw.get("text", "")).strip_edges() != "":
			var page: Dictionary = raw.duplicate(true)
			page["read_only"] = true
			pages.append(page)
	if pages.is_empty():
		dialogue_topic_unavailable(str(_topic_navigation.context_id()))
		return
	var topic_title: String = "Ask more"
	for raw: Variant in _topic_navigation.rows():
		if raw is Dictionary and str(raw.get("id", "")) == str(scene.get("topic_id", "")):
			topic_title = str(raw.get("title", topic_title))
	# The visible topic heading separates a repeated line from the preceding
	# conversation, so displayed page IDs remain represented in History.
	text_history.record("Ask more", topic_title, "topic", str(scene.get("topic_history_key", "")) + ":heading")
	dialogue_speech_interrupted.emit()
	_cancel_dialogue_press()
	_topic_navigation.mode = "topic"
	dialogue_session_data = scene.duplicate(true)
	dialogue_session_data["actions"] = []
	dialogue_pages = pages
	dialogue_page_index = 0
	_render_dialogue_page()

func dialogue_topic_unavailable(context_id: String) -> void:
	if str(_topic_navigation.mode) != "list" or context_id != str(_topic_navigation.context_id()):
		return
	var available_rows: Array = []
	for raw: Variant in _topic_navigation.rows():
		if raw is Dictionary and str(raw.get("id", "")) != str(_topic_navigation.requested_id):
			available_rows.append(raw)
	var session: Dictionary = _topic_navigation.primary.get("session", {})
	session["optional_topics"] = available_rows
	_topic_navigation.primary["session"] = session
	_topic_navigation.requested_id = ""
	_topic_navigation.requested_revision = ""
	_topic_navigation.list_message = "That topic is no longer available in this conversation."
	_render_dialogue_topic_list()

func _return_to_primary_dialogue() -> void:
	if _topic_navigation.primary.is_empty():
		return
	var snapshot: Dictionary = _topic_navigation.primary.duplicate(true)
	dialogue_speech_interrupted.emit()
	_cancel_dialogue_press()
	_topic_navigation.reset()
	dialogue_session_data = snapshot.get("session", {})
	dialogue_pages = snapshot.get("pages", [])
	dialogue_page_index = int(snapshot.get("page", 0))
	_render_dialogue_page(false, false, false)
	var detail: Dictionary = snapshot.get("detail", {})
	_decision_selected_key = str(detail.get("key", ""))
	_decision_details.text = str(detail.get("text", ""))
	_decision_details.visible = bool(detail.get("visible", false))
	_dialogue_reading_state = Dictionary(snapshot.get("reading", {})).duplicate(true)
	view.call_deferred("_restore_primary_topic_return", _dialogue_view_generation)
	view.call_deferred("_apply_hud_layout")

func _restore_primary_topic_return(generation: int) -> void:
	await view.get_tree().process_frame
	if generation == _dialogue_view_generation and str(_topic_navigation.mode) == "primary" and dialogue_layer.visible:
		_restore_dialogue_reading_state()

func _restore_topic_list_reading(generation: int) -> void:
	await view.get_tree().process_frame
	if generation != _dialogue_view_generation or str(_topic_navigation.mode) != "list" or not dialogue_layer.visible:
		return
	var reading: Dictionary = _topic_navigation.list_reading
	var focus_key: String = str(reading.get("focus", ""))
	var restored: bool = false
	for control: Control in _dialogue_focus_controls():
		if str(control.get_meta("dialogue_focus_key", "")) == focus_key:
			control.grab_focus()
			restored = true
			break
	if not restored:
		_focus_first_enabled(dialogue_actions)
	dialogue_choices_scroll.scroll_vertical = int(reading.get("choices_scroll", 0))
	_dialogue_body_scroll.scroll_vertical = int(reading.get("body_scroll", 0))
	dialogue_text.get_v_scroll_bar().value = float(reading.get("subtitle_scroll", 0.0))

func _add_topic_navigation_button(label: String, key: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.set_meta("dialogue_focus_key", key)
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.focus_mode = Control.FOCUS_ALL
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_style_button(button)
	button.pressed.connect(callback)
	dialogue_actions.add_child(button)
	return button

func show_dialogue(data: Dictionary) -> void:
	prepare_gameplay_ui()
	view.get_tree().paused = true
	_topic_navigation.reset()
	if _dialogue_review_open:
		_dialogue_review_open = false
		dialogue_review_changed.emit(false)
	_dialogue_reading_state.clear()
	_set_ui_pointer("dialogue")
	dialogue_closing = false
	dialogue_layer.visible = true
	prompt_label.visible = false
	hint_label.visible = false
	if toast_tween != null and toast_tween.is_running():
		toast_tween.kill()
	toast_label.visible = false
	toast_label.modulate = Color(1, 1, 1, 1)
	dialogue_session_data = data.duplicate(true)
	dialogue_pages.clear()
	for page in data.get("pages", []):
		if typeof(page) == TYPE_DICTIONARY and str(page.get("text", "")).strip_edges() != "":
			dialogue_pages.append(page)
	if dialogue_pages.is_empty():
		dialogue_pages.append({"speaker": str(data.get("name", "Unknown")), "text": "..."})
	dialogue_page_index = 0
	_render_dialogue_page()

func _reveal_subtitle() -> void:
	if _subtitle_tween != null:
		_subtitle_tween.kill()
	dialogue_text.modulate = Color.WHITE
	dialogue_title.modulate = Color.WHITE
	if reduced_motion or flash_reduction: return
	dialogue_text.modulate.a = 0.0
	dialogue_title.modulate.a = 0.0
	_subtitle_tween = view.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_subtitle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_subtitle_tween.tween_property(dialogue_text, "modulate:a", 1.0, 0.15)
	_subtitle_tween.tween_property(dialogue_title, "modulate:a", 1.0, 0.15)

func _render_dialogue_page(record_history: bool = true, announce_page: bool = true, focus_page: bool = true) -> void:
	if announce_page:
		dialogue_speech_interrupted.emit()
	if focus_page:
		_dialogue_body_scroll.scroll_vertical = 0
		dialogue_text.scroll_to_line(0)
	_dialogue_view_generation += 1
	_dialogue_reading_state.clear()
	_cancel_dialogue_press()
	_decision_selected_key = ""
	_decision_details.visible = false
	var page: Variant = dialogue_pages[dialogue_page_index]
	var page_speaker: String = str(dialogue_session_data.get("name", "Unknown"))
	var page_speaker_id: String = ""
	if page is Dictionary:
		page_speaker = str(page.get("speaker", dialogue_session_data.get("name", "Unknown")))
		page_speaker_id = str(page.get("speaker_id", ""))
		dialogue_title.text = page_speaker
		dialogue_text.text = SourceText.localize(str(page.get("text", "...")))
	else:
		dialogue_title.text = page_speaker
		dialogue_text.text = str(page)
	dialogue_title.visible = subtitle_speaker_names
	if record_history:
		text_history.record(page_speaker, dialogue_text.get_parsed_text(), "speech", str(page.get("text_id", "")) if page is Dictionary else "")
	var reading_topic: bool = str(_topic_navigation.mode) == "topic"
	dialogue_page_label.text = "%d / %d" % [dialogue_page_index + 1, dialogue_pages.size()]
	dialogue_page_label.visible = false
	if announce_page:
		_reveal_subtitle()
	if announce_page:
		dialogue_page_changed.emit(page_speaker, page_speaker_id, dialogue_page_index, dialogue_pages.size())
	for child in dialogue_actions.get_children():
		dialogue_actions.remove_child(child)
		child.queue_free()
	if dialogue_page_index < dialogue_pages.size() - 1:
		_add_topic_navigation_button("Continue", "continue", func():
			dialogue_page_index += 1
			_render_dialogue_page()
		)
		if reading_topic:
			_add_topic_navigation_button("Back to Topics", "topic_back", _open_dialogue_topics)
		dialogue_choices_scroll.custom_minimum_size.y = 128.0 if reading_topic else 96.0
		if focus_page:
			_focus_after_rebuild(dialogue_actions)
		view.call_deferred("_apply_hud_layout")
		return
	if reading_topic:
		_add_topic_navigation_button("Back to Topics", "topic_back", _open_dialogue_topics)
		_add_topic_navigation_button("Back to Conversation", "topics_back", _return_to_primary_dialogue)
		dialogue_choices_scroll.custom_minimum_size.y = 128.0
		if focus_page:
			_focus_after_rebuild(dialogue_actions)
		view.call_deferred("_apply_hud_layout")
		return
	var actions: Array = dialogue_session_data.get("actions", [])
	var first_decision: Dictionary = {}
	for raw_action: Variant in actions:
		if not raw_action is Dictionary:
			continue
		var action: Dictionary = raw_action
		var model: Dictionary = action.get("decision_model", {})
		var committing: bool = not model.is_empty() or str(action.get("type", "")) in ["story_choice", "ending", "final_choice", "resolve_side_quest"]
		if committing and model.is_empty():
			model = {"label":str(action.get("label", "This choice")), "commitment":StoryJournalPresenter.decision_preview(action), "available":true}
		if committing and first_decision.is_empty():
			first_decision = model
		var button: Button = Button.new()
		var choice_key: String = str(model.get("option_key", action.get("choice_id", action.get("label", "continue"))))
		button.set_meta("dialogue_focus_key", "action:" + choice_key)
		button.text = ("Commit: " if committing else "") + str(action.get("label", "Continue"))
		button.tooltip_text = PreparationPanel.decision_text(model) if committing else button.text
		button.disabled = not bool(model.get("available", true)) or not bool(action.get("available", true))
		if not bool(action.get("available", true)):
			var reason := str(action.get("unavailable_reason", "Complete the current step first."))
			button.text += "\n" + reason
			button.tooltip_text = reason
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.focus_mode = Control.FOCUS_ALL
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		_style_button(button)
		if committing:
			button.focus_entered.connect(func(detail: Dictionary = model): _show_decision_detail(detail))
			button.mouse_entered.connect(func(detail: Dictionary = model): _show_decision_detail(detail))
		button.pressed.connect(func(action_data: Dictionary = action, is_commitment: bool = committing):
			if not _close_dialogue_surface(false):
				return
			if not is_commitment:
				text_history.record("Kael", str(action_data.get("label", "Continue")), "question", str(action_data.get("choice_id", "")))
			dialogue_closed.emit()
			action_selected.emit(action_data)
		)
		dialogue_actions.add_child(button)
	if actions.is_empty():
		_add_dialogue_close()
	if _has_optional_topics():
		_add_topic_navigation_button("Ask more", "ask_more", _open_dialogue_topics)
	dialogue_choices_scroll.custom_minimum_size.y = 154.0 if dialogue_actions.get_child_count() > 2 else 112.0
	if not first_decision.is_empty():
		_show_decision_detail(first_decision)
		if focus_page:
			_focus_after_rebuild(dialogue_actions)
	elif focus_page:
		_focus_after_rebuild(dialogue_actions)
	view.call_deferred("_apply_hud_layout")

func _show_decision_detail(model: Dictionary) -> void:
	if _decision_details == null or model.is_empty():
		return
	var key: String = str(model.get("option_key", model.get("label", "")))
	if key == _decision_selected_key and _decision_details.visible:
		return
	_decision_selected_key = key
	_decision_details.text = "BEFORE YOU COMMIT\n" + PreparationPanel.decision_text(model)
	_decision_details.visible = true
	_decision_details.scroll_to_line(0)

func _focus_decision_reader(page_index: int, generation: int = -1) -> void:
	await view.get_tree().process_frame
	if (generation < 0 or generation == _dialogue_view_generation) and dialogue_layer.visible and dialogue_page_index == page_index and _decision_details.visible:
		_decision_details.grab_focus()

func show_decision_result(receipt: Dictionary) -> void:
	var receipt_id: String = str(receipt.get("id", ""))
	if receipt_id == "":
		return
	var source_id: String = "decision:" + receipt_id + ":" + str(receipt.get("stage", "recorded"))
	for raw: Variant in text_history.entries:
		if raw is Dictionary and str(raw.get("source_id", "")) == source_id:
			return
	var title: String = str(receipt.get("title", "Commitment recorded"))
	var body: String = str(receipt.get("body", ""))
	var next_action: String = str(receipt.get("next_action", ""))
	var recorded: String = title + "\n" + body
	if next_action != "":
		recorded += "\nNext: " + next_action
	text_history.record("Kael — recorded decision", recorded, "choice", source_id)
	post_notice(title + ("\n" + body if body != "" else ""), "story", 6.0, source_id)

func _build_dialogue() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	dialogue_layer.add_child(box)
	_dialogue_header = HBoxContainer.new()
	box.add_child(_dialogue_header)
	dialogue_title = Label.new()
	dialogue_title.name = "DialogueSpeakerName"
	dialogue_title.set_meta("layout_font_role", "caption")
	dialogue_title.clip_text = true
	dialogue_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_header.add_child(dialogue_title)
	dialogue_page_label = Label.new()
	dialogue_page_label.name = "DialoguePageCounter"
	dialogue_page_label.set_meta("layout_font_role", "caption")
	dialogue_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dialogue_page_label.add_theme_color_override("font_color", Color(0.62, 0.54, 0.40))
	_dialogue_header.add_child(dialogue_page_label)
	_dialogue_history_button = Button.new()
	_dialogue_history_button.text = "History"
	_dialogue_history_button.set_meta("dialogue_focus_key", "history")
	_dialogue_history_button.set_meta("layout_font_role", "caption")
	_dialogue_history_button.focus_mode = Control.FOCUS_ALL
	_dialogue_history_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_dialogue_history_button.pressed.connect(func(): show_text_history("dialogue"))
	_dialogue_header.add_child(_dialogue_history_button)
	_dialogue_back_button = Button.new()
	_dialogue_back_button.text = "Back"
	_dialogue_back_button.set_meta("dialogue_focus_key", "back")
	_dialogue_back_button.set_meta("layout_font_role", "caption")
	_dialogue_back_button.focus_mode = Control.FOCUS_ALL
	_dialogue_back_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_dialogue_back_button.pressed.connect(request_back)
	_dialogue_header.add_child(_dialogue_back_button)
	_dialogue_body_scroll = ScrollContainer.new()
	_dialogue_body_scroll.name = "ConversationBodyScroll"
	_dialogue_body_scroll.set_meta("navigation_scroll", "dialogue_body")
	_dialogue_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dialogue_body_scroll.follow_focus = true
	_dialogue_body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_dialogue_body_scroll)
	_dialogue_body = VBoxContainer.new()
	_dialogue_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_body.add_theme_constant_override("separation", 8)
	_dialogue_body_scroll.add_child(_dialogue_body)
	dialogue_text = RichTextLabel.new()
	dialogue_text.name = "DialogueSubtitleText"
	dialogue_text.set_meta("layout_font_role", "subtitle")
	dialogue_text.bbcode_enabled = true
	dialogue_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	dialogue_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	dialogue_text.add_theme_constant_override("outline_size", 2)
	dialogue_text.add_theme_constant_override("shadow_offset_y", 2)
	dialogue_text.focus_mode = Control.FOCUS_ALL
	dialogue_text.set_meta("dialogue_focus_key", "text")
	dialogue_text.scroll_active = true
	dialogue_text.fit_content = false
	_dialogue_body.add_child(dialogue_text)
	_decision_details = RichTextLabel.new()
	_decision_details.name = "KnownDecisionStakes"
	_decision_details.set_meta("layout_font_role", "body")
	_decision_details.focus_mode = Control.FOCUS_ALL
	_decision_details.set_meta("dialogue_focus_key", "decision_details")
	_decision_details.scroll_active = true
	_decision_details.fit_content = false
	_decision_details.add_theme_constant_override("line_separation", 4)
	_decision_details.visible = false
	_dialogue_body.add_child(_decision_details)
	dialogue_actions = VBoxContainer.new()
	dialogue_actions.name = "DialogueChoices"
	dialogue_actions.process_mode = Node.PROCESS_MODE_ALWAYS
	dialogue_actions.add_theme_constant_override("separation", 8)
	dialogue_choices_scroll = ScrollContainer.new()
	dialogue_choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialogue_choices_scroll.follow_focus = true
	dialogue_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_body.add_child(dialogue_choices_scroll)
	dialogue_choices_scroll.add_child(dialogue_actions)

func _cancel_dialogue_press() -> void:
	_dialogue_pending_button = null
	_dialogue_pending_source = ""

func _dialogue_pointer_hits(button: Button, point: Vector2) -> bool:
	if not button.get_global_rect().has_point(point):
		return false
	for ancestor: Control in dialogue_layer.find_children("*", "Control", true, false):
		if ancestor != button and ancestor.is_ancestor_of(button) and ancestor.clip_contents and not ancestor.get_global_rect().has_point(point):
			return false
	return true

func _add_dialogue_close() -> void:
	var close = Button.new()
	close.text = "Close"
	close.set_meta("dialogue_focus_key", "close")
	close.process_mode = Node.PROCESS_MODE_ALWAYS
	close.focus_mode = Control.FOCUS_ALL
	close.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_style_button(close)
	close.pressed.connect(func():
		if not _close_dialogue_surface():
			return
		dialogue_closed.emit()
	)
	dialogue_actions.add_child(close)

func _close_dialogue_surface(resume_world: bool = true) -> bool:
	if _dialogue_review_open:
		_dialogue_review_open = false
		dialogue_review_changed.emit(false)
	# Hide the surface before notifying game logic so a delayed browser event
	# cannot activate a stale button while the zone is being rebuilt.
	if dialogue_closing or dialogue_layer == null or not dialogue_layer.visible:
		return false
	dialogue_closing = true
	hide_menus()
	view.get_tree().paused = not resume_world
	return true

func _focused_dialogue_button() -> Button:
	if dialogue_actions == null:
		return null
	for child in dialogue_actions.get_children():
		if child is Button and not (child as Button).disabled:
			return child as Button
	return null

func get_current_dialogue_page() -> Dictionary:
	if str(_topic_navigation.mode) == "list":
		return {}
	if dialogue_page_index < 0 or dialogue_page_index >= dialogue_pages.size():
		return {}
	var page: Variant = dialogue_pages[dialogue_page_index]
	return page.duplicate(true) if typeof(page) == TYPE_DICTIONARY else {"speaker": dialogue_title.text, "text": str(page)}

func save_text_history() -> Array:
	return text_history.save_state()

func load_text_history(raw: Variant) -> void:
	text_history.load_state(raw)

func show_text_history(back_target: String = "pause") -> void:
	if back_target == "dialogue":
		_capture_dialogue_reading_state()
		_dialogue_review_open = true
		dialogue_review_changed.emit(true)
	library_back_target = back_target
	active_menu = "text_history"
	dialogue_layer.visible = false
	_set_internal_canvas(Vector2i(MENU_SIZE))
	_set_ui_pointer("pause")
	_clear_menu()
	menu_layer.visible = true
	var box := _menu_box("Conversation History", "Words and promises", "most recent 400 entries")
	var log := RichTextLabel.new()
	log.name = "HistoryReader"
	log.set_meta("navigation_key", "history_text")
	log.set_meta("navigation_scroll", "history_text")
	log.text = text_history.text()
	log.bbcode_enabled = false
	log.custom_minimum_size = Vector2(340, 410)
	log.add_theme_font_size_override("normal_font_size", int(20 * story_text_scale))
	log.focus_mode = Control.FOCUS_ALL
	log.scroll_active = true
	log.scroll_following = false
	box.add_child(log)
	_add_menu_button(box, "Back to Conversation" if back_target == "dialogue" else "Back", _return_from_history)

func _return_from_history() -> void:
	_capture_menu_state()
	if library_back_target == "dialogue":
		menu_layer.visible = false
		active_menu = ""
		_set_internal_canvas(GAMEPLAY_SIZE)
		_set_ui_pointer("dialogue")
		dialogue_layer.visible = true
		_dialogue_review_open = false
		dialogue_review_changed.emit(false)
		view.call_deferred("_restore_dialogue_reading_state")
	else:
		_return_from_library()

func _capture_dialogue_reading_state() -> void:
	var focused := view.get_viewport().gui_get_focus_owner()
	_dialogue_reading_state = {"page": dialogue_page_index, "subtitle_scroll": dialogue_text.get_v_scroll_bar().value, "choices_scroll": dialogue_choices_scroll.scroll_vertical, "focus": str(focused.get_meta("dialogue_focus_key", "history")) if focused != null else "history"}
	_dialogue_reading_state["decision_scroll"] = _decision_details.get_v_scroll_bar().value
	_dialogue_reading_state["body_scroll"] = _dialogue_body_scroll.scroll_vertical

func _restore_dialogue_reading_state() -> void:
	if not dialogue_layer.visible:
		return
	if not _dialogue_reading_state.is_empty() and int(_dialogue_reading_state.get("page", -1)) == dialogue_page_index:
		dialogue_text.get_v_scroll_bar().value = float(_dialogue_reading_state.get("subtitle_scroll", 0.0))
		_decision_details.get_v_scroll_bar().value = float(_dialogue_reading_state.get("decision_scroll", 0.0))
		dialogue_choices_scroll.scroll_vertical = int(_dialogue_reading_state.get("choices_scroll", 0))
		_dialogue_body_scroll.scroll_vertical = int(_dialogue_reading_state.get("body_scroll", 0))
		for control in _dialogue_focus_controls():
			if str(control.get_meta("dialogue_focus_key", "")) == str(_dialogue_reading_state.get("focus", "")):
				control.grab_focus()
				return
	_focus_first_enabled(dialogue_actions)

func _dialogue_focus_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if is_instance_valid(_dialogue_history_button) and _dialogue_history_button.is_visible_in_tree():
		controls.append(_dialogue_history_button)
	if is_instance_valid(_dialogue_back_button) and _dialogue_back_button.is_visible_in_tree():
		controls.append(_dialogue_back_button)
	if is_instance_valid(dialogue_text) and dialogue_text.is_visible_in_tree():
		controls.append(dialogue_text)
	if is_instance_valid(_decision_details) and _decision_details.is_visible_in_tree():
		controls.append(_decision_details)
	for child in dialogue_actions.get_children():
		if child is Button and not child.is_queued_for_deletion() and not child.disabled and child.is_visible_in_tree():
			controls.append(child)
	return controls
