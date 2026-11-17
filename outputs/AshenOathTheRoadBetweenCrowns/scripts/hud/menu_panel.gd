extends "res://scripts/hud/hud_component.gd"
## Menu panel: explicit view operations; requests leave through typed signals.

func show_main_menu() -> void:
	if not new_game_ready and (not is_instance_valid(_game_owner) or not bool(_game_owner.get("game_started"))):
		show_startup_loading(str(_opening_preparation.get("message", "Loading Greyfen...")), float(_opening_preparation.get("progress", -1.0)), str(_opening_preparation.get("state", "")) == "failed")
		return
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
		_set_internal_canvas(Vector2i(MENU_SIZE))
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
	if active_menu == "main" and is_instance_valid(new_game_status_label):
		new_game_status_label.text = new_game_status

func set_opening_preparation(state: String, message: String, progress: float = -1.0, requested: bool = false) -> void:
	_opening_preparation = {"state": state, "message": message, "progress": progress, "requested": requested}
	if state != "ready":
		var phases := {"preparing":"Loading Greyfen...", "downloading":"Downloading opening content", "services":"Preparing the journey...", "resources":"Preparing characters and materials...", "building":"Building Greyfen", "finalizing":"Finishing the village...", "first_view":"Preparing the first view..."}
		var phase: String = message if state == "failed" else str(phases.get(state, "Preparing the road..."))
		if progress >= 0.0 and state != "failed":
			phase += "  %d%%" % clampi(int(progress * 100.0), 0, 99)
		show_startup_loading(phase, progress, state == "failed")
		return
	if active_menu == "startup" and new_game_ready:
		if input_source != null:
			input_source.reset_transient_input("opening_menu_ready")
		show_main_menu()
	# Internal construction prose remains in diagnostics, not the loading UI.
	var label := message if state == "failed" else ("100%" if state == "ready" else ("%d%%" % clampi(int(progress * 100.0), 0, 99) if progress >= 0.0 else ""))
	set_new_game_status(label)
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
	menu_layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_layer.size = Vector2(GAMEPLAY_SIZE)
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

func _activate_menu_action(callback: Callable, screen_generation: int) -> void:
	if screen_generation != _screen_generation:
		return
	if input_source != null:
		input_source.reset_transient_input("menu_action")
	callback.call()
