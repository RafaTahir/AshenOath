extends CanvasLayer

signal new_game_requested
signal continue_requested
signal save_requested
signal load_requested
signal load_checkpoint_requested
signal resume_requested
signal journal_requested
signal launch_accepted
signal quit_requested
signal settings_requested(action: String)
signal audio_mix_requested(channel: String, value: float)
signal revisit_covenant_requested
signal action_selected(action: Dictionary)
signal craft_requested(item_id: String)
signal item_use_requested(item_id: String)
signal inventory_preference_requested(key: String, value: String)
signal vendor_purchase_requested(vendor_id: String, item_id: String, quantity: int)
signal upgrade_requested(upgrade_id: String)
signal dialogue_closed
signal dialogue_review_changed(open: bool)
signal dialogue_page_changed(speaker: String, speaker_id: String, page_index: int, total_pages: int)
signal menu_hovered
signal menu_clicked
signal journey_load_requested(selection: Dictionary)
signal journey_load_cancel_requested
signal journal_section_requested(section_id: String)
signal dialogue_topic_requested(context_id: String, topic_id: String, revision_key: String)
signal dialogue_speech_interrupted

const MENU_BUILD_LABEL = "ASHEN OATH · THE ROAD BETWEEN CROWNS"
const MENU_SIZE = Vector2(1920.0, 1080.0)
const GAMEPLAY_SIZE = Vector2i(1280, 720)
const SAVE_PATH = "user://ashen_oath_save.json"
const AUTOSAVE_PATH = "user://ashen_oath_autosave.json"
const CHECKPOINT_PATH = "user://ashen_oath_checkpoint.json"
const StoryJournalPresenter = preload("res://scripts/story_journal.gd")
const DialogueHistory = preload("res://scripts/dialogue_history.gd")
const SourceText = preload("res://scripts/source_text.gd")
const NavigationState = preload("res://scripts/hud_navigation_state.gd")
const NoticeQueue = preload("res://scripts/hud_notice_queue.gd")
const PreparationViewModel = preload("res://scripts/preparation_view_model.gd")
const PreparationPanel = preload("res://scripts/preparation_panel.gd")
const JourneyMenuPanel = preload("res://scripts/journey_menu_panel.gd")
const DialogueTopicNavigation = preload("res://scripts/dialogue_topic_navigation.gd")
const JournalEvidenceNavigation = preload("res://scripts/journal_evidence_navigation.gd")
const HudLayoutPolicy = preload("res://scripts/hud_layout_policy.gd")
const HudReflowState = preload("res://scripts/hud_reflow_state.gd")
const MobileTouchLayout = preload("res://scripts/mobile_touch_layout.gd")
const HudVisualStyle = preload("res://scripts/hud_visual_style.gd")
const HudEmblem = preload("res://scripts/hud_emblem.gd")
const HudNavigationDial = preload("res://scripts/hud_navigation_dial.gd")
var navigation = NavigationState.new()
var notices = NoticeQueue.new()
var _rendered_screen := ""
var _screen_generation := 0
var _dialogue_review_open := false
var _dialogue_reading_state: Dictionary = {}
var _dialogue_history_button: Button
var _menu_notice: Label
var _notice_active: Dictionary = {}
var _notice_remaining := 0.0
var _slot_operation_results: Dictionary = {}
var _library_refresh_pending := false
var _return_after_import := false
var _interaction_prompt_model: Dictionary = {}
var _inventory_screen := "journal"
var _inventory_generation := 0
var text_history = DialogueHistory.new()
var library_page := 0
var library_back_target := "pause"
var selected_slot := ""
var subtitle_speaker_names := true
var flash_reduction := false
var journal_art: TextureRect

var health_bar: ProgressBar
var stamina_bar: ProgressBar
var health_value_label: Label
var stamina_value_label: Label
var enemy_bar: ProgressBar
var enemy_label: Label
var enemy_value_label: Label
var target_status_label: Label
var prompt_label: Label
var tracker_label: Label
var compass_label: Label
var toast_label: Label
var hint_label: Label
var status_label: Label
var equipment_label: Label
var menu_layer: Control
var loading_layer: Control
var loading_message: Label
var loading_elapsed := 0.0
var loading_armed := false
var dialogue_layer: PanelContainer
var dialogue_title: Label
var dialogue_text: RichTextLabel
var dialogue_actions: VBoxContainer
var dialogue_choices_scroll: ScrollContainer
var dialogue_page_label: Label
var inventory_layer: PanelContainer
var inventory_text: RichTextLabel
var craft_buttons: VBoxContainer
var controls_back_target = "main"
var last_health = 125.0
var last_health_max = 125.0
var last_stamina = 100.0
var last_stamina_max = 100.0
var hint_tween: Tween
var status_tween: Tween
var toast_tween: Tween
var _subtitle_tween: Tween
var enemy_hide_tween: Tween
var dialogue_pages: Array = []
var dialogue_page_index := 0
var dialogue_session_data: Dictionary = {}
var dialogue_closing := false
var input_source: Node
var input_device := "keyboard_mouse"
var gamepad_profile: Dictionary = {}
var active_menu := ""
var settings_page := 0
var remap_page := 0
var remap_action_id := ""
var remap_back_target := "main"
var remap_waiting := false
var raw_prompt := ""
var raw_hint := ""
var last_potions := 0
var last_bombs := 0
var last_weapon_name := "Steel"
var last_remedy_id := "redroot_potion"
var last_tool_id := "ash_bomb"
var last_oil_name := ""
var last_arrow_count := -1
var last_arrow_type := "Standard"
var toasts_suppressed := false
var reduced_motion := false
var high_contrast := false
var story_text_scale := 1.0
var new_game_ready := true
var new_game_status := "Greyfen is ready."
var new_game_status_label: Label
var hud_root: Control
var tracker_back: Control
var compass_back: Control
var tracker_title_label: Label
var tracker_caption_label: Label
var tracker_footer_label: Label
var tracker_route_label: Label
var tracker_work_label: Label
var vitals_back: ColorRect
var vitals_box: VBoxContainer
var vitals_warning_label: Label
var supplies_grid: GridContainer
var supply_labels: Dictionary = {}
var supply_counts: Dictionary = {}
var notice_category_label: Label
var notice_back: ColorRect
var prompt_back: ColorRect
var _navigation_model: Dictionary = {}
var _tracker_source := ""
var _attention_remaining := 0.0
var _hint_remaining := 0.0
var _status_remaining := 0.0
var _status_kind := "neutral"
var _status_priority := 0
var _bar_tweens: Dictionary = {}
var _bar_name_labels: Array[Label] = []
var _journal_section_id := "return"
var _journal_context: Dictionary = {}
var inventory_notice_label: Label
var _preparation_actions: BoxContainer
var _preparation_context: Dictionary = {}
var _preparation_services: Object
var _preparation_selection: Dictionary = {}
var _preparation_results: Dictionary = {}
var _vendor_context: Dictionary = {}
var _decision_details: RichTextLabel
var _decision_selected_key := ""
var _dialogue_pending_button: Button
var _dialogue_pending_source := ""
var _dialogue_press_position := Vector2.ZERO
var _journey_models: Dictionary = {}
var _journey_card: RichTextLabel
var _journey_card_kind := ""
var _journey_primary_button: Button
var _journey_load_active := false
var _journey_load_applying := false
var _journey_load_origin: Dictionary = {}
var _journey_load_focus: Control
var _journey_cancel_button: Button
var _journey_return_pending: Dictionary = {}
var _journey_return_last_id := ""
var _save_slot_notice: Label
var _topic_navigation = DialogueTopicNavigation.new()
var _dialogue_view_generation := 0
var _evidence_navigation = JournalEvidenceNavigation.new()
var _evidence_position_key := ""
var _evidence_reference_section := ""
var _evidence_reference_entry := ""

var _display_metrics: Dictionary = {}
var _layout_policy: Dictionary = {}
var _layout_pending := false
var _layout_applying := false
var _layout_generation := 0
var _dialogue_header: HBoxContainer
var _dialogue_back_button: Button
var _dialogue_body_scroll: ScrollContainer
var _dialogue_body: VBoxContainer
var _inventory_root: VBoxContainer
var _inventory_columns: HBoxContainer
var _journal_column: VBoxContainer
var _journal_actions_scroll: ScrollContainer
var _preparation_actions_scroll: ScrollContainer
var _inventory_footer: GridContainer
var _inventory_read_button: Button
var _inventory_entries_button: Button
var _inventory_close_button: Button
var _inventory_panes: Dictionary = {}
var _inventory_pane_states: Dictionary = {}
var _menu_frame: Control
var _menu_shell: HBoxContainer
var _menu_title_stack: VBoxContainer
var _menu_title_label: Label
var _menu_title_spacer: Control
var _menu_panel: PanelContainer
var _menu_scroll: ScrollContainer
var _menu_content: VBoxContainer
var _menu_footer: HBoxContainer
var _menu_back_button: Button
var _loading_card: PanelContainer
var _touch_layout_reason := ""
var _touch_reason_label: Label
var _hart_emblem: Control
var _navigation_dial: Control
var _world_clock_label: Label
var _world_clock_text := ""
var _quick_slots: Dictionary = {}
var _quick_bindings: Dictionary = {}
var _quick_icons: Dictionary = {}
var _gameplay_bindings: Label
var _quest_rule: ColorRect
var _quest_marker: Label
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_build_menu_layer()
	_build_dialogue()
	_build_inventory()
	_build_loading_layer()
	for surface: Control in [menu_layer, dialogue_layer, inventory_layer, loading_layer]:
		surface.visibility_changed.connect(_on_hud_surface_visibility_changed)
	_apply_theme()
	apply_accessibility(_current_settings())
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_hud_layout()
	_on_hud_surface_visibility_changed()
	_update_process_policy()

func _process(delta: float) -> void:
	if health_bar == null:
		return
	_advance_notices(delta)
	if loading_armed and loading_layer != null and not loading_layer.visible:
		loading_elapsed += delta
		if loading_elapsed >= 0.75:
			loading_layer.visible = true
			_update_process_policy()
	if _attention_remaining > 0.0:
		_attention_remaining = maxf(0.0, _attention_remaining - delta)
		if _attention_remaining <= 0.0:
			_refresh_resource_attention()
	if _hint_remaining > 0.0:
		_hint_remaining = maxf(0.0, _hint_remaining - delta)
		if _hint_remaining <= 0.0:
			raw_hint = ""
			hint_label.visible = false
	if _status_remaining > 0.0:
		_status_remaining = maxf(0.0, _status_remaining - delta)
		if _status_remaining <= 0.0:
			status_label.visible = false
	_update_process_policy()

func _update_process_policy() -> void:
	if health_bar == null:
		return
	var loading_delay_active := loading_armed and loading_layer != null and not loading_layer.visible
	set_process(loading_delay_active or notices.has_pending() or not _notice_active.is_empty() or _attention_remaining > 0.0 or _hint_remaining > 0.0 or _status_remaining > 0.0)

func _gameplay_surface_blocked() -> bool:
	return loading_armed or _dialogue_review_open or (menu_layer != null and menu_layer.visible) or (dialogue_layer != null and dialogue_layer.visible) or (inventory_layer != null and inventory_layer.visible)

func _on_hud_surface_visibility_changed() -> void:
	if hud_root == null:
		return
	var blocked := _gameplay_surface_blocked()
	hud_root.visible = not blocked
	if not blocked:
		call_deferred("_present_pending_journey_return")
	if blocked:
		raw_hint = ""
		_hint_remaining = 0.0
		_status_remaining = 0.0
		hint_label.visible = false
		status_label.visible = false
		if hint_tween != null and hint_tween.is_valid():
			hint_tween.kill()
		if status_tween != null and status_tween.is_valid():
			status_tween.kill()
	else:
		prompt_label.visible = raw_prompt != ""
		prompt_back.visible = prompt_label.visible
	_present_notice()
	_update_process_policy()

func _draw_resource_attention(seconds: float = 4.0) -> void:
	_attention_remaining = maxf(_attention_remaining, seconds)
	_refresh_resource_attention()
	_update_process_policy()

func _refresh_resource_attention() -> void:
	if vitals_back == null or vitals_warning_label == null:
		return
	var low_health := last_health > 0.0 and last_health / maxf(last_health_max, 1.0) <= 0.28
	var spent: bool = last_stamina <= 0.0
	vitals_warning_label.text = "Low health · stamina spent" if low_health and spent else ("Low health" if low_health else ("Stamina spent — let it recover" if spent else ""))
	var emphasized := _attention_remaining > 0.0 or low_health or spent
	vitals_back.color = Color(0.008, 0.012, 0.015, 0.94 if high_contrast else (0.12 if emphasized else 0.0))
	vitals_warning_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.68) if high_contrast else Color(0.96, 0.74, 0.50))

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
	_journey_card.visible = true
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
		_add_journey_load_button(box, "Recovery: " + str(summary.get("title", "Recorded journey")), option, "recovery_option:%d" % index)

func begin_journey_load(model: Dictionary) -> void:
	if not _journey_load_active:
		_capture_menu_state()
		_capture_inventory_state()
		if dialogue_layer.visible:
			_capture_dialogue_reading_state()
		_journey_load_origin = {"menu":menu_layer.visible, "dialogue":dialogue_layer.visible, "inventory":inventory_layer.visible}
		_journey_load_focus = get_viewport().gui_get_focus_owner()
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
			call_deferred("_restore_menu_state", _rendered_screen, _screen_generation)
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

func set_journey_load_applying() -> void:
	if not _journey_load_active:
		return
	_journey_load_applying = true
	_journey_cancel_button.disabled = true
	_journey_cancel_button.visible = false
	loading_message.text = "Returning to the recorded journey…\nPlacing Kael on the road."

func present_journey_return(model: Dictionary) -> void:
	var id: String = str(model.get("id", ""))
	if id == "" or id == _journey_return_last_id:
		return
	_journey_return_last_id = id
	_journey_return_pending = model.duplicate(true) if bool(model.get("announce", true)) else {}
	call_deferred("_present_pending_journey_return")

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
	_journey_primary_button = _add_journey_load_button(box, JourneyMenuPanel.load_label(model), model, "continue")
	_journey_primary_button.set_meta("journey_model_kind", "continue")
	_add_journey_recovery_options(box, model)
	_add_menu_button(box, "New Journey", func(): new_game_requested.emit(), false, "new_journey")
	new_game_status_label = _add_menu_text(box, new_game_status)
	_add_menu_button(box, "Saved Journeys", func(): show_save_library("main"), false, "saved_journeys")
	_add_menu_button(box, "Controls", func(): show_controls_menu("main"))
	_add_menu_button(box, "Settings", func(): show_settings_menu("main"))
	_add_menu_button(box, "Credits", func(): show_credits_menu())
	_add_menu_button(box, "Quit", func(): quit_requested.emit())
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

func set_boot_shell_cover_active(active: bool) -> void:
	# The HTML Crow Flight shell can cover the canvas while Godot compiles the
	# first real gameplay frame. Hide only the in-engine menu during that frame;
	# the already-built menu is restored atomically when Greyfen is render-ready.
	if menu_layer == null:
		return
	if active:
		menu_layer.visible = false
	elif active_menu == "main":
		menu_layer.visible = true
		call_deferred("_restore_menu_state", _rendered_screen, _screen_generation)

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
	call_deferred("_focus_first_enabled", menu_layer)

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

func show_settings_menu(back_target: String = "pause", requested_page: int = -1) -> void:
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
				var manager = get_tree().root.find_child("Settings", true, false)
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
		_add_menu_text(box, "Left Stick move | Right Stick look | D-Pad Up/Down zoom\nL3 run | B dodge | Y jump | Tap X cycle weapons | Hold X draw/sheath\nRB light attack | RT heavy attack / fire bow | LT aim bow\nSword: hold LT Oathfire | Tap/Hold LB parry or block | A interact\nBow: D-Pad Up cycle arrows | D-Pad Left potion | D-Pad Right bomb | View journal | Menu pause")
	elif input_device == "touch":
		_add_menu_text(box, "Left thumb move | Drag right side to look\nStrike / Heavy attack | Dodge | Jump\nHold Guard to block or parry | Hold Oath to charge Oathfire\nUse interacts | Potion heals | Pause opens the menu\nLandscape orientation is required during gameplay")
	else:
		_add_menu_text(box, "WASD move | Mouse look | Wheel zoom | Page Up/Down zoom\nShift run | Space dodge | X jump | 1 Steel | 2 Bow | 3 Oathblade | H draw/sheath\nLeft mouse light attack / fire bow | Right mouse heavy / aim bow\nHold C Oathfire Beam | Tap Q parry | Hold Q block | E interact\nZ cycle arrows | R potion | F bomb | Tab inventory | Esc pause")
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
	get_viewport().set_input_as_handled()
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

func show_credits_menu() -> void:
	active_menu = "credits"
	_set_internal_canvas(Vector2i(MENU_SIZE))
	_set_ui_pointer("menu")
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box("Credits", "", "made under an ashen moon")
	_add_menu_text(box, "Ashen Oath: The Road Between Crowns\nA game by RafaTahir.\nExternal art/audio/UI asset credits are distributed with the game under assets_external/licenses.")
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
		var focus_owner := get_viewport().gui_get_focus_owner()
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
	add_child(loading_layer)
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
func update_health(current: float, maximum: float) -> void:
	var previous = last_health
	last_health = current
	last_health_max = maximum
	health_bar.max_value = maximum
	health_bar.value = current
	health_value_label.text = "%d / %d" % [int(round(current)), int(round(maximum))]
	if current < previous:
		_flash_bar(health_bar, Color(1.0, 0.32, 0.22))
		_draw_resource_attention(5.0)
	elif current > previous:
		_flash_bar(health_bar, Color(0.78, 0.24, 0.16))
		_draw_resource_attention(3.0)
	_refresh_resource_attention()
	_update_process_policy()

func update_stamina(current: float, maximum: float) -> void:
	var previous = last_stamina
	last_stamina = current
	last_stamina_max = maximum
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	stamina_value_label.text = "%d / %d" % [int(round(current)), int(round(maximum))]
	if current < previous - 5.0:
		_flash_bar(stamina_bar, Color(1.0, 0.75, 0.22))
		_draw_resource_attention(3.0)
	_refresh_resource_attention()

func show_enemy(name: String, current: float, maximum: float) -> void:
	enemy_label.text = "Target: %s" % name
	enemy_bar.max_value = maximum
	enemy_bar.value = current
	enemy_value_label.text = "%d / %d" % [int(round(max(current, 0.0))), int(round(maximum))]
	enemy_bar.visible = current > 0.0
	enemy_label.visible = current > 0.0
	enemy_value_label.visible = current > 0.0
	if current > 0.0:
		_draw_resource_attention(4.0)
		if enemy_hide_tween != null and enemy_hide_tween.is_running():
			enemy_hide_tween.kill()
		enemy_hide_tween = create_tween()
		enemy_hide_tween.tween_interval(5.0)
		enemy_hide_tween.tween_callback(hide_enemy)

func hide_enemy() -> void:
	enemy_bar.visible = false
	enemy_label.visible = false
	enemy_value_label.visible = false

func set_target_lock_status(enemy_name: String, distance: float) -> void:
	if target_status_label == null:
		return
	target_status_label.text = "Locked · %s · %d m" % [enemy_name, int(round(distance))]
	target_status_label.visible = true

func clear_target_lock_status() -> void:
	if target_status_label != null:
		target_status_label.visible = false

func set_prompt(text: String) -> void:
	raw_prompt = text
	var clean := _format_input_text(text.strip_edges())
	if clean.begins_with("E  "):
		clean = "[E]  " + clean.trim_prefix("E  ")
	elif clean.begins_with("E - "):
		clean = "[E]  " + clean.trim_prefix("E - ")
	prompt_label.text = clean
	prompt_label.visible = raw_prompt != "" and not _gameplay_surface_blocked()
	if prompt_back != null:
		prompt_back.visible = prompt_label.visible

func set_interaction_prompt(model: Dictionary) -> void:
	_interaction_prompt_model = model.duplicate(true)
	if model.is_empty():
		set_prompt("")
		return
	var fallback := str(model.get("fallback_text", model.get("fallback", model.get("text", ""))))
	if not bool(model.get("available", true)):
		set_prompt(fallback if fallback != "" else str(model.get("subject", "")))
		return
	var binding := str(model.get("binding", ""))
	if input_source != null and input_source.has_method("describe_action"):
		var descriptor: Dictionary = input_source.describe_action("interact")
		binding = str(descriptor.get("binding", binding))
	var verb := str(model.get("verb", ""))
	var subject := str(model.get("subject", ""))
	if verb == "":
		set_prompt(fallback)
		return
	set_prompt("%s%s%s" % ["[" + binding + "] " if binding != "" else "", verb, " " + subject if subject != "" else ""])

func set_tracker(text: String) -> void:
	_tracker_source = text
	_refresh_story_focus()

func set_navigation_model(model: Dictionary) -> void:
	if model == _navigation_model:
		return
	_navigation_model = model.duplicate(true)
	_refresh_story_focus()

func _refresh_story_focus() -> void:
	if tracker_title_label == null:
		return
	var formatted := _format_tracker_text(_tracker_source)
	var lines: PackedStringArray = formatted.split("\n", false)
	tracker_title_label.text = str(lines[0]).to_upper() if not lines.is_empty() else "THE ROAD AHEAD"
	var action := str(_navigation_model.get("action", ""))
	if action == "":
		action = str(lines[1]) if lines.size() > 1 else "Consult your journal for the next known lead."
	tracker_label.text = action
	tracker_label.tooltip_text = action
	tracker_caption_label.text = "Next step"
	tracker_footer_label.text = "%s  JOURNAL" % _action_label("open_inventory")
	var route := str(_navigation_model.get("route_hint", ""))
	var distance := int(_navigation_model.get("distance_m", -1))
	var scope := str(_navigation_model.get("scope", "exploration"))
	if distance >= 0 and scope in ["local", "aftermath"]:
		route = "%d m%s" % [distance, " · " + route if route != "" else " to the next step"]
	tracker_route_label.text = route
	var purpose := str(_navigation_model.get("purpose", ""))
	tracker_route_label.tooltip_text = route + ("\n" + purpose if purpose != "" else "")
	var work_lines: Array[String] = []
	var work: Array = _navigation_model.get("nearby_work", [])
	for index in range(mini(work.size(), 2)):
		var entry: Dictionary = work[index] if typeof(work[index]) == TYPE_DICTIONARY else {}
		var title := str(entry.get("title", ""))
		if title != "":
			work_lines.append(title)
	tracker_work_label.text = "Nearby: " + " · ".join(work_lines) if not work_lines.is_empty() else ""
	var primary := str(_navigation_model.get("primary", ""))
	if primary != "":
		compass_label.text = primary
	tracker_back.visible = action != ""

func _fit_tracker_height() -> void:
	# The story card owns a reserved reading region; changing objectives never
	# moves guidance or neighbouring controls.
	_apply_hud_layout()

func set_compass(text: String) -> void:
	if _navigation_model.is_empty():
		compass_label.text = text.replace(" | ", "   ·   ")

func toast(text: String, seconds: float = 2.15) -> void:
	post_notice(text, "info", seconds, "")

func post_notice(text: String, category: String = "info", duration: float = 3.0, dedupe_key: String = "") -> void:
	var key := dedupe_key if dedupe_key != "" else category + ":" + text.strip_edges()
	if not _notice_active.is_empty() and str(_notice_active.get("key", "")) == key:
		_notice_active["text"] = text
		_notice_remaining = maxf(_notice_remaining, duration)
		_present_notice()
		return
	if not _notice_active.is_empty() and notices.priority(category) > int(_notice_active.get("priority", 0)):
		notices.push(str(_notice_active.text), str(_notice_active.category), _notice_remaining, str(_notice_active.key))
		_notice_active.clear()
	notices.push(text, category, duration, key)
	_advance_notices(0.0)
	_update_process_policy()

func _advance_notices(delta: float) -> void:
	var reading := dialogue_layer != null and (dialogue_layer.visible or _dialogue_review_open)
	var menu_open := (menu_layer != null and menu_layer.visible) or (inventory_layer != null and inventory_layer.visible)
	if menu_open and str(_notice_active.get("category", "")) == "combat":
		_notice_active.clear()
	if reading:
		if str(_notice_active.get("category", "")) == "combat":
			_notice_active.clear()
		if toast_label != null:
			toast_label.visible = false
		if notice_back != null:
			notice_back.visible = false
		if notice_category_label != null:
			notice_category_label.visible = false
		return
	if toasts_suppressed and not _notice_active.is_empty() and str(_notice_active.get("category", "")) not in ["error", "unavailable"]:
		return
	if not _notice_active.is_empty():
		_notice_remaining -= delta
		if _notice_remaining <= 0.0:
			_notice_active.clear()
	if _notice_active.is_empty():
		_notice_active = notices.take(false, toasts_suppressed, menu_open)
		if not _notice_active.is_empty():
			_notice_remaining = float(_notice_active.duration)
	_present_notice()
	_update_process_policy()

func _present_notice() -> void:
	if toast_label == null:
		return
	var text := str(_notice_active.get("text", ""))
	var menu_open := (menu_layer != null and menu_layer.visible) or (inventory_layer != null and inventory_layer.visible)
	var reading := dialogue_layer != null and (dialogue_layer.visible or _dialogue_review_open)
	var may_show := not toasts_suppressed or str(_notice_active.get("category", "")) in ["error", "unavailable"]
	toast_label.visible = text != "" and not menu_open and not reading and may_show
	toast_label.text = text
	var notice_alpha := 1.0
	if not reduced_motion and not flash_reduction and not _notice_active.is_empty():
		var duration := float(_notice_active.get("duration", 2.2))
		notice_alpha = minf(smoothstep(0.0, 0.20, duration - _notice_remaining), smoothstep(0.0, 0.30, _notice_remaining))
	toast_label.modulate = Color(1, 1, 1, notice_alpha)
	if notice_category_label != null:
		var category := str(_notice_active.get("category", "info"))
		notice_category_label.text = str({"story":"Story", "inventory":"Supplies", "save":"Saved", "error":"Unable to complete", "unavailable":"Unavailable", "combat":"In the fight", "info":"On the road"}.get(category, "On the road"))
		notice_category_label.visible = toast_label.visible
		notice_category_label.modulate.a = notice_alpha
	if notice_back != null:
		notice_back.visible = toast_label.visible
		notice_back.modulate.a = notice_alpha
	if inventory_notice_label != null:
		inventory_notice_label.text = text if inventory_layer.visible and not reading else ""
		inventory_notice_label.tooltip_text = text
		if inventory_layer.visible and not reading and str(_notice_active.get("category", "")) not in ["error", "unavailable"]:
			_present_preparation_notice()
	if is_instance_valid(_menu_notice):
		_menu_notice.text = text
		_menu_notice.visible = text != "" and not reading
		_menu_notice.add_theme_color_override("font_color", Color(1.0, 0.78, 0.53) if str(_notice_active.get("category", "")) in ["error", "unavailable"] else Color(0.86, 0.83, 0.70))

func set_toasts_suppressed(suppressed: bool) -> void:
	toasts_suppressed = suppressed
	_present_notice()
	_update_process_policy()

func set_guidance_hint(text: String, seconds: float = 4.5) -> void:
	raw_hint = "" if _gameplay_surface_blocked() else text
	hint_label.text = _format_input_text(text)
	hint_label.visible = raw_hint != ""
	hint_label.modulate = Color(1, 1, 1, 1)
	if hint_tween != null and hint_tween.is_running():
		hint_tween.kill()
	_hint_remaining = maxf(seconds, 2.2) if raw_hint != "" else 0.0
	_update_process_policy()

func show_status_cue(text: String, kind: String = "neutral") -> void:
	if _gameplay_surface_blocked() or text.strip_edges() == "":
		return
	var priority := int({"neutral":0, "hurt":1, "item":2, "block":2, "stamina":3, "parry":3, "danger":4, "victory":4}.get(kind, 1))
	if _status_remaining > 0.7 and priority < _status_priority:
		return
	if _status_remaining > 0.0 and status_label.text == text and kind == _status_kind:
		return
	_status_kind = kind
	_status_priority = priority
	_status_remaining = 1.8 if priority >= 3 else 1.35
	status_label.text = text
	status_label.visible = true
	status_label.modulate = _status_color(kind)
	if status_tween != null and status_tween.is_running():
		status_tween.kill()
	_draw_resource_attention(3.0)

func update_equipment(potions: int, bombs: int, oil_name: String, arrow_count: int = -1, arrow_type: String = "Standard", weapon_name: String = "Steel", remedy_id: String = "redroot_potion", tool_id: String = "ash_bomb") -> void:
	var supplies_changed := potions != last_potions or bombs != last_bombs or arrow_count != last_arrow_count or oil_name != last_oil_name
	last_potions = potions
	last_bombs = bombs
	last_oil_name = oil_name
	last_arrow_count = arrow_count
	last_arrow_type = arrow_type
	last_weapon_name = weapon_name
	last_remedy_id = remedy_id
	last_tool_id = tool_id
	var oil_text = oil_name if oil_name != "" else "No oil"
	equipment_label.text = weapon_name + " | " + oil_text
	equipment_label.tooltip_text = "Selected weapon: %s. Active blade oil: %s" % [weapon_name, oil_text]
	if supply_labels.has("potions"):
		(supply_labels["potions"] as Label).text = "Bitterleaf" if remedy_id == "bitterleaf_tonic" else "Redroot"
		(supply_labels["bombs"] as Label).text = "Iron Trap" if tool_id == "iron_trap" else "Ash Bomb"
		_set_quick_motif("potions", "tonic" if remedy_id == "bitterleaf_tonic" else "potions")
		_set_quick_motif("bombs", "trap" if tool_id == "iron_trap" else "bombs")
		(supply_labels["arrows"] as Label).text = arrow_type
		(supply_labels["arrows"] as Label).tooltip_text = arrow_type + " arrows"
		(_quick_bindings["potions"] as Label).text = _action_label("use_potion")
		(_quick_bindings["bombs"] as Label).text = _action_label("throw_bomb")
		(_quick_bindings["arrows"] as Label).text = _action_label("fire_bow")
		_gameplay_bindings.text = "%s  Strike\n%s  Guard\n%s  Dodge\n%s  Journal" % [_action_label("light_attack"), _action_label("block"), _action_label("dodge"), _action_label("open_inventory")]
		(supply_counts["potions"] as Label).text = str(maxi(potions, 0))
		(supply_counts["bombs"] as Label).text = str(maxi(bombs, 0))
		(supply_counts["arrows"] as Label).text = str(arrow_count) if arrow_count >= 0 else "—"
	if supplies_changed:
		_draw_resource_attention(3.5)

func _set_quick_motif(slot: String, motif: String) -> void:
	var icon: Control = _quick_icons[slot]
	if str(icon.get_meta("quick_motif", slot)) != motif:
		icon.set_meta("quick_motif", motif)
		icon.call("configure", motif, high_contrast)

func mark_stamina_exhausted() -> void:
	_flash_bar(stamina_bar, Color(1.0, 0.32, 0.16))
	show_status_cue("Stamina spent", "stamina")

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
	call_deferred("_restore_topic_list_reading", _dialogue_view_generation)
	call_deferred("_apply_hud_layout")

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
	call_deferred("_restore_primary_topic_return", _dialogue_view_generation)
	call_deferred("_apply_hud_layout")

func _restore_primary_topic_return(generation: int) -> void:
	await get_tree().process_frame
	if generation == _dialogue_view_generation and str(_topic_navigation.mode) == "primary" and dialogue_layer.visible:
		_restore_dialogue_reading_state()

func _restore_topic_list_reading(generation: int) -> void:
	await get_tree().process_frame
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
	_subtitle_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
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
		call_deferred("_apply_hud_layout")
		return
	if reading_topic:
		_add_topic_navigation_button("Back to Topics", "topic_back", _open_dialogue_topics)
		_add_topic_navigation_button("Back to Conversation", "topics_back", _return_to_primary_dialogue)
		dialogue_choices_scroll.custom_minimum_size.y = 128.0
		if focus_page:
			_focus_after_rebuild(dialogue_actions)
		call_deferred("_apply_hud_layout")
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
		button.disabled = not bool(model.get("available", true))
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.focus_mode = Control.FOCUS_ALL
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		_style_button(button)
		if committing:
			button.focus_entered.connect(func(detail: Dictionary = model): _show_decision_detail(detail))
			button.mouse_entered.connect(func(detail: Dictionary = model): _show_decision_detail(detail))
		button.pressed.connect(func(action_data: Dictionary = action, is_commitment: bool = committing):
			if not _close_dialogue_surface():
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
			call_deferred("_focus_decision_reader", dialogue_page_index, _dialogue_view_generation)
	elif focus_page:
		_focus_after_rebuild(dialogue_actions)
	call_deferred("_apply_hud_layout")
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
	await get_tree().process_frame
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
func set_preparation_context(snapshot: Dictionary) -> void:
	_preparation_context = snapshot.duplicate(true)

func set_preparation_services(crafting) -> void:
	_preparation_services = crafting

func preparation_screen_key() -> String:
	return _inventory_screen if inventory_layer != null and inventory_layer.visible else ""

func show_preparation_result(result: Dictionary) -> bool:
	if preparation_screen_key() != "journal:preparation" and not preparation_screen_key().begins_with("vendor:"):
		return false
	_preparation_results[_inventory_screen] = result.duplicate(true)
	_present_preparation_notice()
	return true

func _present_preparation_notice() -> void:
	if inventory_notice_label == null:
		return
	var result: Dictionary = _preparation_results.get(_inventory_screen, {})
	if result.is_empty():
		return
	inventory_notice_label.text = ("Done: " if bool(result.get("ok", false)) else "Unavailable: ") + str(result.get("message", ""))
	inventory_notice_label.tooltip_text = inventory_notice_label.text
	inventory_notice_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88) if high_contrast else Color(0.91, 0.84, 0.68))

func _prepare_inventory_surface(preparation: bool) -> void:
	for child in _preparation_actions.get_children():
		_preparation_actions.remove_child(child)
		child.queue_free()
	_preparation_actions.visible = preparation
	inventory_text.custom_minimum_size.y = 0.0
	if preparation and journal_art != null:
		journal_art.visible = false
	inventory_notice_label.text = ""
	_present_preparation_notice()
	for child in craft_buttons.get_children():
		craft_buttons.remove_child(child)
		child.queue_free()

func show_inventory(inventory, quests, story_state = null, progression = null, requested_section: String = "") -> void:
	_capture_inventory_state()
	if requested_section != "":
		_journal_section_id = requested_section
		if requested_section not in ["evidence", _evidence_reference_section]:
			_evidence_reference_section = ""
			_evidence_reference_entry = ""
			_evidence_navigation.clear_returns()
	_inventory_screen = "journal:" + _journal_section_id
	_inventory_generation += 1
	_journal_context = {"inventory":inventory, "quests":quests, "state":story_state, "progression":progression}
	_set_ui_pointer("journal")
	inventory_layer.visible = true
	_show_journal_art(quests, story_state)
	var zone_id: String = _journal_zone_id()
	var sections: Array[Dictionary] = StoryJournalPresenter.sections(quests, story_state, zone_id)
	sections.append({"id":"quest_record", "title":"Quest Record", "body":str(quests.get_journal_text()), "entries":[]})
	var current_section: Dictionary = {}
	for section: Dictionary in sections:
		if str(section.get("id", "")) == _journal_section_id:
			current_section = section
	if current_section.is_empty() and not sections.is_empty():
		current_section = sections[0]
		_journal_section_id = str(current_section.get("id", "return"))
		_inventory_screen = "journal:" + _journal_section_id
	var preparing: bool = _journal_section_id == "preparation"
	var evidence: bool = _journal_section_id == "evidence"
	var reference: Dictionary = {}
	if _evidence_reference_section == _journal_section_id and _evidence_reference_entry != "":
		reference = _journal_entry_from_sections(sections, _evidence_reference_section, _evidence_reference_entry)
		if reference.is_empty():
			_evidence_reference_section = ""
			_evidence_reference_entry = ""
			_evidence_navigation.clear_returns()
	var linked: bool = not reference.is_empty()
	_prepare_inventory_surface(preparing or evidence or linked)
	var section_entries: Array = current_section.get("entries", [])
	var reading: String = str(current_section.get("title", "Journal")).to_upper() + "\n\n" + str(current_section.get("body", ""))
	var paragraph_by_entry: Dictionary = {}
	for raw_entry: Variant in section_entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		reading += "\n\n"
		paragraph_by_entry[str(entry.get("id", ""))] = reading.count("\n")
		reading += str(entry.get("title", "")) + "\n" + str(entry.get("body", ""))
	_evidence_position_key = ""
	if linked:
		inventory_text.text = str(current_section.get("title", "Journal")).to_upper() + "\n\n" + str(reference.get("title", "")) + "\n\n" + str(reference.get("body", ""))
		_evidence_position_key = "reference:" + _evidence_reference_section + ":" + _evidence_reference_entry
		_add_evidence_return_controls()
		for link: Dictionary in reference.get("links", []):
			var source: Button = _preparation_button(str(link.get("label", "Source account")), "reference:" + str(link.get("entry_id", "")), _preparation_actions)
			source.pressed.connect(func(target: Dictionary = link): _open_evidence_reference(target))
	elif preparing:
		_build_preparation_content(inventory, progression, story_state, quests, reading)
	elif not evidence:
		inventory_text.text = reading
	_add_preparation_heading("JOURNAL")
	var section_parent: Container = craft_buttons
	if evidence or linked:
		var section_grid: GridContainer = GridContainer.new()
		section_grid.columns = 2
		section_grid.add_theme_constant_override("h_separation", 8)
		section_grid.add_theme_constant_override("v_separation", 8)
		section_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		craft_buttons.add_child(section_grid)
		section_parent = section_grid
	for section: Dictionary in sections:
		var section_id: String = str(section.get("id", ""))
		var section_button: Button = _preparation_button(str(section.get("title", "")), "section:" + section_id, section_parent)
		section_button.toggle_mode = true
		section_button.button_pressed = section_id == _journal_section_id
		section_button.pressed.connect(func(id_value: String = section_id): _open_journal_section(id_value))
	if evidence:
		_build_evidence_content(quests, story_state, zone_id, sections)
	elif not preparing and not linked and not section_entries.is_empty():
		_add_preparation_heading("IN THIS SECTION")
		for raw_entry: Variant in section_entries:
			if not raw_entry is Dictionary:
				continue
			var entry: Dictionary = raw_entry
			var entry_id: String = str(entry.get("id", ""))
			var entry_button: Button = _preparation_button(str(entry.get("title", "Read entry")), "entry:" + entry_id, craft_buttons)
			if _journal_section_id == "creatures":
				entry_button.pressed.connect(func(id_value: String = entry_id): _open_evidence_reference({"section_id":"creatures", "entry_id":id_value}))
				continue
			entry_button.pressed.connect(func(paragraph: int = int(paragraph_by_entry.get(entry_id, 0))):
				_set_inventory_pane("reader")
				inventory_text.scroll_to_paragraph(paragraph)
				inventory_text.grab_focus()
			)
	_add_preparation_close()
	if _evidence_position_key != "":
		var memory: Dictionary = _evidence_navigation.position(_evidence_position_key)
		if memory.is_empty():
			memory = {"focus":"journal_text" if linked or str(_evidence_navigation.selected_id) != "" else "evidence_filter:" + str(_evidence_navigation.filter_id), "index":0, "scrolls":{"journal_text":0, "journal_actions":0}}
		navigation.screens[_inventory_screen] = memory
	_queue_responsive_layout()
	call_deferred("_restore_inventory_state", _inventory_screen, _inventory_generation)
func _journal_zone_id() -> String:
	var zone_id: String = str(_preparation_context.get("zone_id", ""))
	if get_parent() != null:
		zone_id = str(get_parent().get("current_zone_id"))
	return zone_id

func _journal_entry_from_sections(sections: Array, section_id: String, entry_id: String) -> Dictionary:
	for raw_section: Variant in sections:
		if not raw_section is Dictionary or str(raw_section.get("id", "")) != section_id:
			continue
		for raw_entry: Variant in raw_section.get("entries", []):
			if raw_entry is Dictionary and str(raw_entry.get("id", "")) == entry_id:
				return raw_entry
	return {}

func _build_evidence_content(quests, state, zone_id: String, sections: Array) -> void:
	var model: Dictionary = StoryJournalPresenter.evidence_model(quests, state, zone_id)
	var entries: Array = model.get("entries", [])
	var filters: Array = model.get("filters", [])
	var filter_found: bool = false
	for raw: Variant in filters:
		if raw is Dictionary and str(raw.get("id", "")) == str(_evidence_navigation.filter_id):
			filter_found = true
	if not filter_found:
		_evidence_navigation.filter_id = "all"
	var detail: Dictionary = {}
	if str(_evidence_navigation.selected_id) != "":
		detail = StoryJournalPresenter.evidence_detail(str(_evidence_navigation.selected_id), quests, state, zone_id)
		if detail.is_empty():
			_evidence_navigation.selected_id = ""
	var filtered: Array[Dictionary] = []
	for raw: Variant in entries:
		if raw is Dictionary and (str(_evidence_navigation.filter_id) == "all" or str(raw.get("kind", "")) == str(_evidence_navigation.filter_id)):
			filtered.append(raw)
	if detail.is_empty():
		_evidence_position_key = "list:" + str(_evidence_navigation.filter_id)
		inventory_text.text = "EVIDENCE\n\n" + str(model.get("body", ""))
		inventory_text.text += "\n\n%d recorded · %d shown\n\nSelect a record to read its source, account and known relevance." % [entries.size(), filtered.size()]
		if filtered.is_empty() and not entries.is_empty():
			inventory_text.text += "\n\nNo recorded accounts match this filter. Choose All records to return to the full list."
		_preparation_actions.visible = bool(_evidence_navigation.has_return())
		if _evidence_navigation.has_return():
			_add_evidence_return_controls()
	else:
		_evidence_position_key = "record:" + str(detail.get("id", ""))
		inventory_text.text = _evidence_detail_text(detail)
		_add_evidence_return_controls()
		var links: Array = detail.get("links", [])
		var heading_added: bool = false
		for raw: Variant in links:
			if not raw is Dictionary:
				continue
			var link: Dictionary = raw
			var target: Dictionary = _resolve_evidence_reference(link, sections)
			if target.is_empty():
				continue
			if not heading_added:
				_add_preparation_heading("RELATED JOURNAL ENTRIES")
				heading_added = true
			var link_key: String = str(link.get("section_id", "")) + ":" + str(link.get("entry_id", ""))
			var button: Button = _preparation_button(str(link.get("label", target.get("title", "Read entry"))), "evidence_link:" + link_key, craft_buttons)
			button.pressed.connect(func(reference: Dictionary = link): _open_evidence_reference(reference))
	_add_preparation_heading("RECORDED ACCOUNTS · %d" % entries.size())
	var filter_grid: GridContainer = GridContainer.new()
	filter_grid.columns = 2
	filter_grid.add_theme_constant_override("h_separation", 8)
	filter_grid.add_theme_constant_override("v_separation", 8)
	filter_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_buttons.add_child(filter_grid)
	for raw: Variant in filters:
		if not raw is Dictionary:
			continue
		var filter: Dictionary = raw
		var id: String = str(filter.get("id", "all"))
		var button: Button = _preparation_button("%s · %d" % [str(filter.get("label", "All records")), int(filter.get("count", 0))], "evidence_filter:" + id, filter_grid)
		button.toggle_mode = true
		button.button_pressed = id == str(_evidence_navigation.filter_id)
		button.pressed.connect(func(filter_id: String = id): _select_evidence_filter(filter_id))
	for entry: Dictionary in filtered:
		var id: String = str(entry.get("id", ""))
		var place: String = str(entry.get("place", ""))
		var text: String = str(entry.get("title", "Record")) + "\n" + str(entry.get("kind_label", "Account")) + (" · " + place if place != "" else "")
		var button: Button = _preparation_button(text, "evidence_entry:" + id, craft_buttons)
		button.toggle_mode = true
		button.button_pressed = id == str(_evidence_navigation.selected_id)
		button.pressed.connect(func(entry_id: String = id): _select_evidence_entry(entry_id))

func _evidence_detail_text(detail: Dictionary) -> String:
	var lines: Array[String] = [str(detail.get("title", "Record")).to_upper(), str(detail.get("kind_label", "Account"))]
	var source: String = str(detail.get("source", ""))
	var place: String = str(detail.get("place", ""))
	if source != "":
		lines.append("Source: " + source)
	if place != "":
		lines.append(str(detail.get("place_label", "Associated place")) + ": " + place)
	var recorded_text: String = str(detail.get("recorded_text", ""))
	if recorded_text != "":
		lines.append("\n" + str(detail.get("text_label", "Recorded account")) + "\n" + recorded_text)
	for raw: Variant in detail.get("blocks", []):
		if not raw is Dictionary or str(raw.get("body", "")) == "":
			continue
		var kind: String = str(raw.get("kind", ""))
		var label: String = str({"observation":"Observation", "testimony":"Testimony", "interpretation":"Interpretation", "limit":"Limit of the record", "relevance":"Known relevance"}.get(kind, "Recorded account"))
		var title: String = str(raw.get("title", ""))
		lines.append("\n" + label + (" — " + title if title != "" and title != label else "") + "\n" + str(raw.get("body", "")))
	var relevance: Array = detail.get("known_relevance", [])
	for raw: Variant in relevance.slice(0, 1):
		if raw is Dictionary:
			lines.append("\n" + str(raw.get("title", "Current known lead")) + "\n" + str(raw.get("body", "")))
	return "\n".join(lines)

func _add_evidence_return_controls() -> void:
	_preparation_actions.visible = true
	if _evidence_navigation.has_return():
		var back: Button = _preparation_button("Back", "evidence_back", _preparation_actions)
		back.pressed.connect(func(): _back_from_evidence_reading())
	var list_button: Button = _preparation_button("Back to Evidence", "evidence_list", _preparation_actions)
	list_button.pressed.connect(_show_evidence_list)

func _select_evidence_filter(filter_id: String) -> void:
	_inventory_panes["journal:evidence"] = "entries"
	_capture_inventory_state()
	_evidence_navigation.filter_id = filter_id
	_evidence_navigation.selected_id = ""
	_evidence_navigation.clear_returns()
	_evidence_reference_section = ""
	_evidence_reference_entry = ""
	_refresh_evidence_journal("evidence")

func _select_evidence_entry(entry_id: String) -> void:
	_inventory_panes["journal:evidence"] = "reader"
	var detail: Dictionary = StoryJournalPresenter.evidence_detail(entry_id, _journal_context.get("quests"), _journal_context.get("state"), _journal_zone_id())
	if detail.is_empty():
		return
	_capture_inventory_state()
	_evidence_navigation.selected_id = str(detail.get("id", entry_id))
	_evidence_reference_section = ""
	_evidence_reference_entry = ""
	_refresh_evidence_journal("evidence")

func _show_evidence_list() -> void:
	_inventory_panes["journal:evidence"] = "entries"
	_capture_inventory_state()
	_evidence_navigation.selected_id = ""
	_evidence_navigation.clear_returns()
	_evidence_reference_section = ""
	_evidence_reference_entry = ""
	_refresh_evidence_journal("evidence")

func _refresh_evidence_journal(section_id: String) -> void:
	if section_id != "evidence" or str(_evidence_navigation.selected_id) != "":
		_inventory_panes["journal:" + section_id] = "reader"
	show_inventory(_journal_context.get("inventory"), _journal_context.get("quests"), _journal_context.get("state"), _journal_context.get("progression"), section_id)

func _resolve_evidence_reference(link: Dictionary, sections: Array = []) -> Dictionary:
	var section_id: String = str(link.get("section_id", ""))
	var entry_id: String = str(link.get("entry_id", ""))
	if section_id not in ["evidence", "people", "preparation", "creatures"] or entry_id == "":
		return {}
	if section_id == "evidence":
		return StoryJournalPresenter.evidence_detail(entry_id, _journal_context.get("quests"), _journal_context.get("state"), _journal_zone_id())
	if sections.is_empty():
		sections = StoryJournalPresenter.sections(_journal_context.get("quests"), _journal_context.get("state"), _journal_zone_id())
	return _journal_entry_from_sections(sections, section_id, entry_id)

func _open_evidence_reference(link: Dictionary) -> void:
	var target: Dictionary = _resolve_evidence_reference(link)
	if target.is_empty():
		return
	_capture_inventory_state()
	_evidence_navigation.push_return({"section_id":_journal_section_id, "entry_id":str(_evidence_navigation.selected_id) if _journal_section_id == "evidence" else _evidence_reference_entry, "filter_id":str(_evidence_navigation.filter_id), "position_key":_evidence_position_key})
	var section_id: String = str(link.get("section_id", ""))
	var entry_id: String = str(target.get("id", link.get("entry_id", "")))
	if section_id == "evidence":
		_evidence_navigation.selected_id = entry_id
		_evidence_navigation.filter_id = "all"
		_evidence_reference_section = ""
		_evidence_reference_entry = ""
	else:
		_evidence_reference_section = section_id
		_evidence_reference_entry = entry_id
	_refresh_evidence_journal(section_id)

func _back_from_evidence_reading() -> bool:
	if not _inventory_screen.begins_with("journal:"):
		return false
	_capture_inventory_state()
	while _evidence_navigation.has_return():
		var origin: Dictionary = _evidence_navigation.pop_return()
		var section_id: String = str(origin.get("section_id", "evidence"))
		var entry_id: String = str(origin.get("entry_id", ""))
		if entry_id != "" and _resolve_evidence_reference({"section_id":section_id, "entry_id":entry_id}).is_empty():
			continue
		_evidence_navigation.filter_id = str(origin.get("filter_id", "all"))
		_evidence_navigation.selected_id = entry_id if section_id == "evidence" else ""
		_evidence_reference_section = section_id if section_id != "evidence" else ""
		_evidence_reference_entry = entry_id if section_id != "evidence" else ""
		_refresh_evidence_journal(section_id)
		return true
	if (_journal_section_id == "evidence" and str(_evidence_navigation.selected_id) != "") or _evidence_reference_entry != "":
		_show_evidence_list()
		return true
	return false
func _evidence_focus_target() -> String:
	if _evidence_reference_entry != "":
		return "evidence_back" if _evidence_navigation.has_return() else "evidence_list"
	if str(_evidence_navigation.selected_id) != "":
		return "evidence_entry:" + str(_evidence_navigation.selected_id)
	return "evidence_filter:" + str(_evidence_navigation.filter_id)

func _handle_evidence_direction(event: InputEvent) -> bool:
	if bool(_layout_policy.get("compact", false)) or _evidence_position_key == "" or not is_instance_valid(inventory_layer) or not inventory_layer.visible or not _inventory_screen.begins_with("journal:"):
		return false
	var direction: int = 0
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		var code: int = key_event.keycode if key_event.keycode != KEY_NONE else key_event.physical_keycode
		if key_event.pressed and not key_event.echo:
			if code == KEY_LEFT:
				direction = -1
			elif code == KEY_RIGHT:
				direction = 1
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event.is_action_pressed("ui_left"):
			direction = -1
		elif event.is_action_pressed("ui_right"):
			direction = 1
	if direction == 0:
		return false
	var focused: Control = get_viewport().gui_get_focus_owner()
	if direction < 0 and focused != inventory_text and focused != null and inventory_layer.is_ancestor_of(focused):
		inventory_text.grab_focus()
		get_viewport().set_input_as_handled()
		return true
	if direction > 0 and focused == inventory_text:
		var controls: Array[Control] = []
		_collect_inventory_focus(inventory_layer, controls)
		var target_key: String = _evidence_focus_target()
		var fallback_key: String = "evidence_filter:" + str(_evidence_navigation.filter_id)
		var fallback: Control = null
		for control: Control in controls:
			var control_key: String = str(control.get_meta("navigation_key", ""))
			if control_key == target_key:
				control.grab_focus()
				get_viewport().set_input_as_handled()
				return true
			if control_key == fallback_key:
				fallback = control
		if fallback != null:
			fallback.grab_focus()
			get_viewport().set_input_as_handled()
			return true
	return false

func _handle_compact_journal_direction(event: InputEvent) -> bool:
	if not bool(_layout_policy.get("compact", false)) or not inventory_layer.visible:
		return false
	var direction: int = 0
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		var code: int = key.keycode if key.keycode != KEY_NONE else key.physical_keycode
		if key.pressed and not key.echo:
			direction = -1 if code == KEY_LEFT else (1 if code == KEY_RIGHT else 0)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event.is_action_pressed("ui_left"):
			direction = -1
		elif event.is_action_pressed("ui_right"):
			direction = 1
	var pane: String = str(_inventory_panes.get(_inventory_screen, "reader"))
	if (direction < 0 and pane == "reader") or (direction > 0 and pane == "entries"):
		_set_inventory_pane("entries" if direction < 0 else "reader", true)
		get_viewport().set_input_as_handled()
		return true
	return false

func _build_preparation_content(inventory, progression, story_state, quests, notes: String) -> void:
	var category: String = str(inventory.kit_category)
	var entry_kind: String = {"equipment":"equipment", "supplies":"item", "ingredients":"ingredient"}.get(category, "item")
	var ids: Array = ["steel", "oathblade", "bow"] if category == "equipment" else (inventory.ordered_ingredient_ids() if category == "ingredients" else inventory.ordered_item_ids())
	if category == "supplies":
		ids = ids.filter(func(id: String) -> bool: return inventory.get_item_type(id) != "blade_upgrade")
	if category == "equipment" and inventory.sort_mode == "name":
		ids = ["bow", "oathblade", "steel"]
	var selection: Dictionary = _preparation_selection.get(_inventory_screen, {})
	if str(selection.get("kind", "")) not in [entry_kind, "notes", "upgrade", "service"] or (str(selection.get("kind", "")) == entry_kind and str(selection.get("id", "")) not in ids):
		selection = {}
	if selection.is_empty() and not ids.is_empty():
		selection = {"kind":entry_kind, "id":str(ids[0])}
	_preparation_selection[_inventory_screen] = selection
	var kind: String = str(selection.get("kind", "notes"))
	var selected_id: String = str(selection.get("id", ""))
	_build_kit_controls(inventory)
	var heading: String = "%s\nCoin: %d\nRemedy: %s | Field tool: %s\n\n" % [category.to_upper(), int(inventory.coin), inventory.get_item_name(inventory.quick_item("use_potion")), inventory.get_item_name(inventory.quick_item("throw_bomb"))]
	if kind == "item" and inventory.item_defs.has(selected_id):
		var detail: Dictionary = PreparationViewModel.item_detail(selected_id, inventory, progression, _preparation_context, story_state, quests)
		inventory_text.text = heading + PreparationPanel.item_text(detail)
		var actions: Array = detail.get("actions", [])
		for raw: Variant in actions:
			if not raw is Dictionary:
				continue
			var action: Dictionary = raw
			var operation: String = str(action.get("id", "use"))
			var button: Button = _preparation_button(str(action.get("verb", "Use")), "action:" + operation + ":" + selected_id, _preparation_actions, bool(action.get("available", false)))
			button.tooltip_text = str(action.get("reason", button.text))
			button.pressed.connect(func(item_id: String = selected_id): item_use_requested.emit(item_id))
		var quick_slot: String = str(detail.get("quick_slot", ""))
		if quick_slot != "":
			var assigned: bool = bool(detail.get("quick_assigned", false))
			var assign: Button = _preparation_button("Assigned to quick slot" if assigned else "Assign " + ("remedy" if quick_slot == "use_potion" else "field tool"), "action:quick:" + selected_id, _preparation_actions, not assigned)
			assign.tooltip_text = _action_label(quick_slot)
			assign.pressed.connect(func(): inventory_preference_requested.emit("quick:" + quick_slot, selected_id))
		var recipe: Dictionary = inventory.recipe_status(selected_id)
		var requirements: Dictionary = recipe.get("required", {})
		if not requirements.is_empty() and _preparation_services != null:
			var quote: Dictionary = _preparation_services.call("quote", selected_id)
			inventory_text.text += "\n" + PreparationPanel.craft_text(quote)
			var craft_button: Button = _preparation_button("Craft %d" % int(quote.get("output_quantity", 1)), "action:craft:" + selected_id, _preparation_actions, bool(quote.get("ok", false)))
			craft_button.pressed.connect(func(item_id: String = selected_id): craft_requested.emit(item_id))
	elif kind == "equipment":
		inventory_text.text = heading + PreparationViewModel.equipment_text(selected_id, inventory, _preparation_context)
	elif kind == "ingredient":
		inventory_text.text = heading + PreparationViewModel.ingredient_text(selected_id, inventory)
	elif kind == "service":
		inventory_text.text = PreparationViewModel.service_text(selected_id, inventory, _preparation_context)
	elif kind == "item":
		inventory_text.text = heading + selected_id.replace("_", " ").capitalize() + "\nCarrying %d\n\nThis retained item has no field-use recipe." % int(inventory.items.get(selected_id, 0))
	elif kind == "upgrade" and progression != null:
		var upgrade: Dictionary = progression.upgrade_status(selected_id)
		inventory_text.text = heading + PreparationPanel.practice_text(upgrade)
		var learn: Button = _preparation_button("Already learned" if bool(upgrade.get("learned", false)) else "Learn · %d Mark%s" % [int(upgrade.get("cost", 1)), "s" if int(upgrade.get("cost", 1)) != 1 else ""], "action:upgrade:" + selected_id, _preparation_actions, bool(upgrade.get("available", false)))
		learn.pressed.connect(func(upgrade_id: String = selected_id): upgrade_requested.emit(upgrade_id))
	else:
		inventory_text.text = PreparationViewModel.knowledge_summary(inventory, quests, story_state, _preparation_context) + "\n\n" + notes
		var objective: Button = _preparation_button("Current objective", "preparation:objective", _preparation_actions)
		objective.pressed.connect(func(): _open_journal_section("return"))
		var knowledge: Button = _preparation_button("Known creatures", "preparation:creatures", _preparation_actions)
		knowledge.pressed.connect(func(): _open_journal_section("creatures"))
		for vendor_id: String in ["tor_forge", "mira_apothecary"]:
			var service: Button = _preparation_button("Tor's Forge" if vendor_id == "tor_forge" else "Mira's Apothecary", "preparation:service:" + vendor_id, _preparation_actions)
			service.pressed.connect(func(id_value: String = vendor_id): _select_preparation_entry("service", id_value))
	_add_preparation_heading(category.to_upper())
	var equipment: Dictionary = _preparation_context.get("equipment", {})
	var active_weapon: String = "bow" if str(equipment.get("active_weapon", "sword")) == "bow" else str(equipment.get("selected_blade_id", "steel"))
	var carried: int = 0
	for raw_id: Variant in ids:
		var item_id: String = str(raw_id)
		var label: String
		if category == "equipment":
			label = str({"steel":"Steel", "oathblade":"Oathblade", "bow":"Bow"}.get(item_id, item_id)) + (" - Equipped" if active_weapon == item_id else "")
			carried += 1
		else:
			var quantity: int = int(inventory.ingredients.get(item_id, 0)) if category == "ingredients" else int(inventory.items.get(item_id, 0))
			carried += quantity
			label = "%s · %d" % [item_id.replace("_", " ").capitalize() if category == "ingredients" else inventory.get_item_name(item_id), quantity]
		var item_button: Button = _preparation_button(label, entry_kind + ":" + item_id, craft_buttons)
		item_button.toggle_mode = true
		item_button.button_pressed = kind == entry_kind and selected_id == item_id
		item_button.pressed.connect(func(id_value: String = item_id): _select_preparation_entry(entry_kind, id_value))
	if carried == 0:
		var empty: Label = Label.new()
		empty.text = "No ingredients carried." if category == "ingredients" else "No supplies carried. Known recipes remain available."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		craft_buttons.add_child(empty)
		if ids.is_empty():
			inventory_text.text = heading + empty.text
	if progression != null:
		_add_preparation_heading("PRACTICE")
		for raw_id: Variant in progression.ordered_upgrade_ids():
			var upgrade_id: String = str(raw_id)
			var upgrade: Dictionary = progression.upgrade_status(upgrade_id)
			var practice_button: Button = _preparation_button(str(upgrade.get("title", upgrade_id)) + (" · Learned" if bool(upgrade.get("learned", false)) else ""), "upgrade:" + upgrade_id, craft_buttons)
			practice_button.toggle_mode = true
			practice_button.button_pressed = kind == "upgrade" and selected_id == upgrade_id
			practice_button.pressed.connect(func(id_value: String = upgrade_id): _select_preparation_entry("upgrade", id_value))
	var notes_button: Button = _preparation_button("Preparation notes", "notes", craft_buttons)
	notes_button.pressed.connect(func(): _select_preparation_entry("notes", ""))

func _build_kit_controls(inventory) -> void:
	var categories: GridContainer = GridContainer.new()
	categories.columns = 2
	categories.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_buttons.add_child(categories)
	for id: String in ["equipment", "supplies", "ingredients", "evidence"]:
		var button: Button = _preparation_button("Quest evidence" if id == "evidence" else id.capitalize(), "kit:" + id, categories)
		button.toggle_mode = true
		button.button_pressed = id == str(inventory.kit_category)
		button.pressed.connect(func(category: String = id):
			if category == "evidence":
				_open_journal_section("evidence")
			else:
				_preparation_selection.erase(_inventory_screen)
				inventory_preference_requested.emit("category", category)
		)
	var sort: OptionButton = OptionButton.new()
	sort.add_item("Sort: type")
	sort.add_item("Sort: name")
	sort.selected = 1 if str(inventory.sort_mode) == "name" else 0
	sort.fit_to_longest_item = false
	sort.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sort.set_meta("navigation_key", "kit_sort")
	sort.tooltip_text = "Inventory order"
	_style_button(sort)
	for child: Node in sort.get_children():
		if child is Label:
			(child as Label).offset_right = -42
	craft_buttons.add_child(sort)
	sort.item_selected.connect(func(index: int): inventory_preference_requested.emit("sort", "name" if index == 1 else "type"))

func _select_preparation_entry(kind: String, id: String) -> void:
	_inventory_panes[_inventory_screen] = "reader"
	_preparation_selection[_inventory_screen] = {"kind":kind, "id":id}
	_preparation_results.erase(_inventory_screen)
	if _inventory_screen.begins_with("vendor:"):
		show_vendor(str(_vendor_context.get("id", "")), _vendor_context.get("service"), _vendor_context.get("inventory"), _vendor_context.get("quests"), _vendor_context.get("state"))
	else:
		show_inventory(_journal_context.get("inventory"), _journal_context.get("quests"), _journal_context.get("state"), _journal_context.get("progression"), _journal_section_id)
	inventory_text.scroll_to_line(0)
	var memory: Dictionary = navigation.screens.get(_inventory_screen, {})
	var scrolls: Dictionary = memory.get("scrolls", {})
	scrolls["journal_text"] = 0
	memory["scrolls"] = scrolls
	navigation.screens[_inventory_screen] = memory

func _open_journal_section(section_id: String) -> void:
	_inventory_panes["journal:" + section_id] = "entries" if section_id == "evidence" and str(_evidence_navigation.selected_id) == "" else "reader"
	if _journal_context.is_empty() or (section_id == _journal_section_id and _evidence_reference_entry == ""):
		return
	_capture_inventory_state()
	_evidence_navigation.clear_returns()
	_evidence_reference_section = ""
	_evidence_reference_entry = ""
	show_inventory(_journal_context.get("inventory"), _journal_context.get("quests"), _journal_context.get("state"), _journal_context.get("progression"), section_id)
func show_vendor(vendor_id: String, vendor_service, inventory, quests = null, story_state = null) -> void:
	_capture_inventory_state()
	_evidence_position_key = ""
	_inventory_screen = "vendor:" + vendor_id
	_inventory_generation += 1
	_vendor_context = {"id":vendor_id, "service":vendor_service, "inventory":inventory, "quests":quests, "state":story_state}
	_set_ui_pointer("journal")
	inventory_layer.visible = true
	_prepare_inventory_surface(true)
	var vendor: Dictionary = vendor_service.get_vendor(vendor_id)
	var heading: String = "%s\n%s\nCoin: %d\n\n" % [str(vendor.get("name", "Vendor")).to_upper(), str(vendor.get("subtitle", "")), int(inventory.coin)]
	var stock: Array[Dictionary] = vendor_service.list_stock(vendor_id, inventory, story_state, quests, true)
	var request_ids: Array[String] = []
	for entry: Dictionary in stock:
		request_ids.append(str(entry.get("item_id", "")))
	if vendor_id == "tor_forge":
		request_ids.append("__emergency_arrows__")
	elif vendor_id == "mira_apothecary":
		request_ids.append("__emergency_healing__")
	var selection: Dictionary = _preparation_selection.get(_inventory_screen, {})
	var selected_id: String = str(selection.get("id", ""))
	if not request_ids.has(selected_id) and not request_ids.is_empty():
		selected_id = request_ids[0]
		_preparation_selection[_inventory_screen] = {"kind":"item", "id":selected_id}
	inventory_text.text = heading + "Supplies and fittings"
	if selected_id != "":
		var quote: Dictionary = vendor_service.quote(vendor_id, selected_id, 1, inventory, story_state, quests)
		var received_id: String = str(quote.get("item_id", selected_id))
		var preparation_progression: Variant = _journal_context.get("progression")
		if get_parent() != null:
			preparation_progression = get_parent().get("progression")
		var detail: Dictionary = PreparationViewModel.item_detail(received_id, inventory, preparation_progression, _preparation_context, story_state, quests)
		detail["actions"] = []
		inventory_text.text = heading + PreparationPanel.item_text(detail) + "\n" + PreparationPanel.purchase_text(quote)
		var emergency: bool = selected_id.begins_with("__emergency")
		var purchase_label: String = "Claim emergency reserve" if emergency else ("Fit · %d coin" % int(quote.get("total_price", 0)) if bool(quote.get("upgrade", false)) else "Buy %d · %d coin" % [int(quote.get("quantity", 1)), int(quote.get("total_price", 0))])
		if not bool(quote.get("ok", false)):
			purchase_label = "Already fitted" if bool(quote.get("upgrade", false)) and int(quote.get("owned", 0)) > 0 else "Unavailable"
		var buy: Button = _preparation_button(purchase_label, "action:buy:" + selected_id, _preparation_actions, bool(quote.get("ok", false)))
		buy.pressed.connect(func(id_value: String = selected_id): vendor_purchase_requested.emit(vendor_id, id_value, 1))
	_add_preparation_heading("SUPPLIES AND SERVICES")
	for request_id: String in request_ids:
		var title: String = "Emergency arrows" if request_id == "__emergency_arrows__" else ("Emergency medicine" if request_id == "__emergency_healing__" else str(inventory.get_item_name(request_id)))
		var entry_button: Button = _preparation_button(title, "item:" + request_id, craft_buttons)
		entry_button.toggle_mode = true
		entry_button.button_pressed = selected_id == request_id
		entry_button.pressed.connect(func(id_value: String = request_id): _select_preparation_entry("item", id_value))
	_add_preparation_close()
	_queue_responsive_layout()
	call_deferred("_restore_inventory_state", _inventory_screen, _inventory_generation)

func _add_preparation_heading(text: String) -> void:
	var heading: Label = Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", int(round(13.0 * story_text_scale)))
	heading.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88) if high_contrast else Color(0.85, 0.77, 0.62))
	craft_buttons.add_child(heading)

func _preparation_button(text: String, key: String, parent: Container, available: bool = true) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.disabled = not available
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.set_meta("navigation_key", key)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(button)
	parent.add_child(button)
	return button

func _add_preparation_close() -> void:
	var close: Button = _preparation_button("Close", "close", craft_buttons)
	close.pressed.connect(func():
		dialogue_closed.emit()
		hide_menus()
		resume_requested.emit()
	)
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
func _build_hud() -> void:
	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)
	vitals_back = ColorRect.new()
	vitals_back.name = "VitalityShadow"
	vitals_back.color = Color(0.01, 0.012, 0.014, 0.0)
	hud_root.add_child(vitals_back)
	vitals_box = VBoxContainer.new()
	vitals_box.visible = false
	hud_root.add_child(vitals_box)
	_hart_emblem = HudEmblem.new()
	_hart_emblem.name = "HartMedallion"
	_hart_emblem.call("configure", "hart", high_contrast)
	hud_root.add_child(_hart_emblem)
	health_bar = ProgressBar.new()
	health_bar.name = "BloodRibbon"
	health_bar.max_value = 125
	health_bar.value = 125
	health_bar.show_percentage = false
	hud_root.add_child(health_bar)
	stamina_bar = ProgressBar.new()
	stamina_bar.name = "StaminaRibbon"
	stamina_bar.max_value = 100
	stamina_bar.value = 100
	stamina_bar.show_percentage = false
	hud_root.add_child(stamina_bar)
	health_value_label = _hud_label(hud_root, "BloodValue", 16)
	health_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamina_value_label = _hud_label(hud_root, "StaminaValue", 16)
	stamina_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var blood_name: Label = _hud_label(hud_root, "BloodCaption", 16)
	blood_name.text = "BLOOD"
	var stamina_name: Label = _hud_label(hud_root, "StaminaCaption", 16)
	stamina_name.text = "STAMINA"
	_bar_name_labels = [blood_name, stamina_name]
	vitals_warning_label = _hud_label(hud_root, "ResourceCondition", 16)
	vitals_warning_label.max_lines_visible = 1
	supplies_grid = GridContainer.new()
	supplies_grid.name = "QuickSupplies"
	supplies_grid.columns = 3
	hud_root.add_child(supplies_grid)
	for id: String in ["potions", "bombs", "arrows"]:
		var slot: Control = Control.new()
		slot.name = id.capitalize() + "QuickSlot"
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		supplies_grid.add_child(slot)
		_quick_slots[id] = slot
		var icon: Control = HudEmblem.new()
		icon.call("configure", id, high_contrast)
		slot.add_child(icon)
		_quick_icons[id] = icon
		var count: Label = _hud_label(slot, id + "Count", 18)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		supply_counts[id] = count
		var item: Label = _hud_label(slot, id + "Name", 16)
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.max_lines_visible = 1
		supply_labels[id] = item
		var binding: Label = _hud_label(slot, id + "Binding", 16)
		binding.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		binding.max_lines_visible = 2
		_quick_bindings[id] = binding
	equipment_label = _hud_label(hud_root, "ActiveBladeOil", 16)
	equipment_label.max_lines_visible = 1
	_gameplay_bindings = _hud_label(hud_root, "CurrentControlHints", 16)
	_gameplay_bindings.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gameplay_bindings.max_lines_visible = 4
	_navigation_dial = HudNavigationDial.new()
	_navigation_dial.name = "RoadNavigator"
	_navigation_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(_navigation_dial)
	_world_clock_label = _hud_label(hud_root, "WorldClock", 16)
	_world_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_world_clock_label.max_lines_visible = 1
	_world_clock_label.text = _world_clock_text
	tracker_back = ColorRect.new()
	tracker_back.name = "ObjectiveShadow"
	(tracker_back as ColorRect).color = Color(0.01, 0.012, 0.014, 0.0)
	hud_root.add_child(tracker_back)
	tracker_title_label = _hud_label(hud_root, "TrackedStoryTitle", 18)
	tracker_title_label.max_lines_visible = 2
	tracker_caption_label = _hud_label(hud_root, "NextStepCaption", 16)
	tracker_caption_label.visible = false
	_quest_rule = ColorRect.new()
	_quest_rule.color = Color(0.69, 0.61, 0.4, 0.62)
	hud_root.add_child(_quest_rule)
	_quest_marker = _hud_label(hud_root, "ObjectiveMarker", 16)
	_quest_marker.text = "◆"
	tracker_label = _hud_label(hud_root, "QuestTrackerObjective", 20)
	tracker_label.max_lines_visible = 3
	tracker_route_label = _hud_label(hud_root, "StoryRouteHint", 16)
	tracker_route_label.max_lines_visible = 2
	tracker_work_label = _hud_label(hud_root, "NearbyStoryWork", 16)
	tracker_work_label.max_lines_visible = 2
	tracker_footer_label = _hud_label(hud_root, "JournalBinding", 16)
	tracker_footer_label.max_lines_visible = 1
	compass_back = ColorRect.new()
	compass_back.color = Color(0.01, 0.012, 0.014, 0.0)
	hud_root.add_child(compass_back)
	compass_label = _hud_label(hud_root, "CurrentLocation", 16)
	compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	compass_label.max_lines_visible = 1
	enemy_label = _hud_label(hud_root, "EnemyFocusLabel", 18)
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_label.max_lines_visible = 1
	enemy_label.visible = false
	enemy_bar = ProgressBar.new()
	enemy_bar.name = "EnemyVitalityRibbon"
	enemy_bar.show_percentage = false
	enemy_bar.visible = false
	hud_root.add_child(enemy_bar)
	enemy_value_label = _hud_label(hud_root, "EnemyVitalityValue", 16)
	enemy_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_value_label.visible = false
	target_status_label = _hud_label(hud_root, "TargetLockStatus", 16)
	target_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_status_label.visible = false
	prompt_back = ColorRect.new()
	prompt_back.name = "InteractionShadow"
	prompt_back.color = Color(0.01, 0.012, 0.014, 0.24)
	prompt_back.visible = false
	hud_root.add_child(prompt_back)
	prompt_label = _hud_label(hud_root, "InteractionPrompt", 20)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.max_lines_visible = 2
	prompt_label.visible = false
	notice_back = ColorRect.new()
	notice_back.name = "NoticeShadow"
	notice_back.color = Color(0.01, 0.012, 0.014, 0.2)
	notice_back.visible = false
	hud_root.add_child(notice_back)
	notice_category_label = _hud_label(hud_root, "NoticeCategory", 16)
	notice_category_label.visible = false
	toast_label = _hud_label(hud_root, "StoryNotice", 20)
	toast_label.max_lines_visible = 3
	toast_label.visible = false
	hint_label = _hud_label(hud_root, "ContextualCombatHint", 16)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.max_lines_visible = 2
	hint_label.visible = false
	status_label = _hud_label(hud_root, "CombatStatusCue", 18)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.visible = false
	for node: Node in hud_root.get_children():
		if node is Control:
			(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	update_equipment(0, 0, "", -1)
	_refresh_story_focus()

func set_world_navigation(snapshot: Dictionary) -> void:
	if is_instance_valid(_navigation_dial):
		_navigation_dial.call("set_snapshot", snapshot)

func set_world_clock(minutes: float, phase: String, _day_count: int = 0) -> void:
	var clock_minutes: int = posmod(int(floor(minutes)), 1440)
	var text: String = "%02d:%02d · %s" % [floori(float(clock_minutes) / 60.0), clock_minutes % 60, phase.capitalize()]
	if text == _world_clock_text:
		return
	_world_clock_text = text
	if is_instance_valid(_world_clock_label):
		_world_clock_label.text = text
func _hud_label(parent: Node, node_name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func set_display_metrics(metrics: Dictionary) -> void:
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
	call_deferred("_apply_responsive_layout")

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
	if not is_inside_tree() or not is_instance_valid(inventory_layer):
		return
	var display: Dictionary = _display_metrics
	if display.is_empty():
		var window: Window = get_window()
		var window_size: Vector2 = Vector2(window.size) if window != null else Vector2(GAMEPLAY_SIZE)
		display = {"width":window_size.x, "height":window_size.y, "coarse_pointer":input_device == "touch"}
	var policy: Dictionary = HudLayoutPolicy.resolve(Vector2(GAMEPLAY_SIZE), display, story_text_scale, input_device)
	if not bool(policy.get("valid", false)):
		return
	var snapshot: Dictionary = HudReflowState.capture(self)
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
	_apply_responsive_journal(policy)
	_apply_responsive_dialogue(policy)
	_apply_responsive_menu(policy)
	_apply_responsive_loading(policy)
	_apply_responsive_gameplay(policy)
	_wire_responsive_inventory_focus()
	_layout_applying = false
	call_deferred("_restore_reflow_state", snapshot, generation, surface_key)

func _restore_reflow_state(snapshot: Dictionary, generation: int, surface_key: String) -> void:
	await get_tree().process_frame
	if generation != _layout_generation or surface_key != _responsive_surface_key():
		return
	var restored: bool = HudReflowState.restore(snapshot, self)
	if restored:
		return
	if inventory_layer.visible:
		if bool(_layout_policy.get("compact", false)) and str(_inventory_panes.get(_inventory_screen, "reader")) == "entries":
			_focus_first_enabled(craft_buttons)
		else:
			inventory_text.grab_focus()
	elif dialogue_layer.visible:
		_dialogue_history_button.grab_focus()
	elif menu_layer.visible and _rendered_screen != "":
		navigation.restore(_rendered_screen, menu_layer)

func _apply_responsive_typography(node: Node, fonts: Dictionary, button_height: float, unit: float) -> void:
	if node is Control:
		var control: Control = node as Control
		var role: String = str(control.get_meta("layout_font_role", "body"))
		if node is Button:
			role = str(control.get_meta("layout_font_role", "button"))
		var font_size: int = int(fonts.get(role, fonts.get("body", 20)))
		if node is RichTextLabel:
			var reader: RichTextLabel = node as RichTextLabel
			reader.add_theme_font_size_override("normal_font_size", font_size)
			reader.add_theme_font_size_override("bold_font_size", int(fonts.get("subtitle_bold", font_size)) if role == "subtitle" else font_size)
			reader.add_theme_constant_override("line_separation", int(round(4.0 * unit)))
			reader.custom_minimum_size.x = 0.0
		elif node is Label or node is LineEdit or node is TextEdit or node is Button:
			control.add_theme_font_size_override("font_size", font_size)
			control.custom_minimum_size.x = 0.0
		if node is Button:
			var button: Button = node as Button
			button.set_meta("layout_button_height", button_height)
			button.set_meta("layout_button_padding", 20.0 * unit)
			button.custom_minimum_size.y = button_height
			for child: Node in button.get_children():
				if child is Label:
					var label: Label = child as Label
					label.set_meta("layout_font_role", role)
					label.add_theme_color_override("font_color", Color(0.50, 0.48, 0.43) if button.disabled else (Color.WHITE if high_contrast else Color(0.94, 0.89, 0.77)))
					label.offset_left = 12.0 * unit
					label.offset_right = -12.0 * unit
					label.offset_top = 10.0 * unit
					label.offset_bottom = -10.0 * unit
		elif node is LineEdit:
			control.custom_minimum_size.y = button_height
		elif node is TextEdit:
			control.custom_minimum_size.y = maxf(button_height * 2.0, 140.0 * unit)
		if node is Slider:
			control.custom_minimum_size.x = 0.0
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			control.custom_minimum_size.y = maxf(32.0 * unit, button_height * 0.75)
	for child: Node in node.get_children():
		if not child.is_queued_for_deletion():
			_apply_responsive_typography(child, fonts, button_height, unit)

func _set_responsive_panel_padding(panel: PanelContainer, padding: float) -> void:
	var source: StyleBox = panel.get_theme_stylebox("panel")
	if source == null:
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
	journal_art.visible = float(model.art_height) > 0.0 and journal_art.texture != null and not _preparation_actions.visible and _evidence_position_key == ""
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
		call_deferred("_focus_inventory_pane", pane, _inventory_generation)

func _focus_inventory_pane(pane: String, generation: int) -> void:
	await get_tree().process_frame
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
	if not is_instance_valid(_menu_frame) or not is_instance_valid(_menu_content):
		return
	var model: Dictionary = policy.menu
	var compact: bool = bool(model.compact)
	var frame: Rect2 = model.frame
	var gap: float = float(policy.gap)
	var padding: float = float(policy.padding)
	_menu_frame.position = frame.position
	_menu_frame.size = frame.size
	_menu_shell.add_theme_constant_override("separation", int(round(gap)))
	_menu_title_stack.add_theme_constant_override("separation", int(round(gap)))
	_menu_content.add_theme_constant_override("separation", int(round(gap)))
	_menu_content.custom_minimum_size = Vector2.ZERO
	_menu_title_stack.custom_minimum_size = Vector2.ZERO
	_menu_title_spacer.visible = not compact
	_menu_title_spacer.custom_minimum_size.y = 24.0 * float(policy.unit_scale)
	if compact and _menu_title_stack.get_parent() != _menu_content:
		_menu_title_stack.reparent(_menu_content)
		_menu_content.move_child(_menu_title_stack, 0)
	elif not compact and _menu_title_stack.get_parent() != _menu_shell:
		_menu_title_stack.reparent(_menu_shell)
		_menu_shell.move_child(_menu_title_stack, 0)
	_menu_title_stack.size_flags_vertical = Control.SIZE_FILL if compact else Control.SIZE_EXPAND_FILL
	_menu_title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
	_menu_panel.custom_minimum_size = Vector2(0.0 if compact else float(model.panel_width), 0.0)
	_menu_shell.custom_minimum_size.y = maxf(0.0, frame.size.y - (float(model.footer_height) + gap if _menu_footer.visible else 0.0))
	_set_responsive_panel_padding(_menu_panel, padding)
	_menu_content.set_meta("menu_button_width", 0.0)
	_menu_content.set_meta("menu_button_height", float(policy.button_min_height))
	_menu_content.set_meta("menu_font_size", int(Dictionary(policy.fonts).get("button", 20)))
	_menu_content.set_meta("compact_buttons", compact)
	_menu_footer.custom_minimum_size.y = float(model.footer_height)
	_menu_footer.add_theme_constant_override("separation", int(round(gap)))
	_menu_notice.custom_minimum_size = Vector2.ZERO
	_menu_notice.visible = _menu_notice.text != ""
	if is_instance_valid(_journey_card):
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
	var safe: Rect2 = policy.safe_rect
	var usable: Vector2 = policy.display_usable_size
	var unit: float = float(policy.unit_scale)
	var compact: bool = bool(policy.compact)
	var gap: float = float(policy.gap)
	var fonts: Dictionary = policy.fonts
	var touch: bool = input_device == "touch"
	var touch_model: Dictionary = MobileTouchLayout.build(Vector2(GAMEPLAY_SIZE), _display_metrics) if touch else {}
	var reserved_bottom: float = float(touch_model.get("bottom_reserved_display", 0.0)) * unit
	var margin: float = (12.0 if compact else 24.0) * unit
	var left: float = safe.position.x + margin
	var right: float = safe.end.x - margin
	var top: float = safe.position.y + margin
	var bottom: float = safe.end.y - margin
	var center: float = safe.get_center().x
	var center_channel: float = maxf(0.0, safe.size.x - reserved_bottom * 2.0 - gap * 2.0) if touch and reserved_bottom > 0.0 else safe.size.x - margin * 2.0
	var crest_size: float = (62.0 if compact else 84.0) * unit
	var vitals_width: float = minf(470.0 * unit, safe.size.x * (0.48 if compact else 0.42))
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
	var dial_visible: bool = usable.x >= 820.0 and usable.y >= 500.0
	var dial_size: float = (146.0 if compact else 174.0) * unit
	var dial_top: float = top + (66.0 if touch else 22.0) * unit
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
	var quest_y: float = location_y + 34.0 * unit if dial_visible else top + (66.0 if touch else 0.0) * unit
	var room_below: float = maxf(0.0, (safe.end.y - reserved_bottom - gap if touch else bottom - 136.0 * unit) - quest_y)
	var title_height: float = (42.0 if not compact else 25.0) * unit
	var show_title: bool = not (touch and compact and room_below < 95.0 * unit)
	tracker_title_label.visible = show_title
	tracker_title_label.position = Vector2(quest_x, quest_y)
	tracker_title_label.size = Vector2(quest_width, title_height)
	tracker_title_label.add_theme_font_size_override("font_size", int(fonts.body))
	tracker_caption_label.visible = false
	_quest_rule.visible = show_title
	_quest_rule.position = Vector2(quest_x, quest_y + title_height + 2.0 * unit)
	_quest_rule.size = Vector2(minf(90.0 * unit, quest_width), maxf(1.0, unit))
	var action_y: float = quest_y + title_height + 13.0 * unit if show_title else quest_y
	var action_height: float = minf((78.0 if not compact else 66.0) * unit, maxf(32.0 * unit, room_below - (action_y - quest_y)))
	_quest_marker.position = Vector2(quest_x - 2.0 * unit, action_y + 2.0 * unit)
	_quest_marker.size = Vector2(20.0 * unit, 24.0 * unit)
	_quest_marker.add_theme_font_size_override("font_size", int(fonts.caption))
	tracker_label.position = Vector2(quest_x + 22.0 * unit, action_y)
	tracker_label.size = Vector2(maxf(0.0, quest_width - 22.0 * unit), action_height)
	tracker_label.add_theme_font_size_override("font_size", int(fonts.body))
	var route_y: float = action_y + action_height + 5.0 * unit
	tracker_route_label.position = Vector2(quest_x + 22.0 * unit, route_y)
	tracker_route_label.size = Vector2(quest_width - 22.0 * unit, 42.0 * unit)
	tracker_route_label.visible = not compact and route_y + 42.0 * unit <= quest_y + room_below
	tracker_work_label.position = Vector2(quest_x + 22.0 * unit, route_y + 44.0 * unit)
	tracker_work_label.size = Vector2(quest_width - 22.0 * unit, 38.0 * unit)
	tracker_work_label.visible = not compact and route_y + 82.0 * unit <= quest_y + room_below
	tracker_footer_label.position = Vector2(quest_x + 22.0 * unit, route_y + 86.0 * unit)
	tracker_footer_label.size = Vector2(quest_width - 22.0 * unit, 24.0 * unit)
	tracker_footer_label.visible = not compact and not touch
	for label: Label in [tracker_route_label, tracker_work_label, tracker_footer_label]:
		label.add_theme_font_size_override("font_size", int(fonts.caption))
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
	_gameplay_bindings.visible = not touch
	_gameplay_bindings.position = Vector2(right - 290.0 * unit, bottom - (90.0 if not compact else 48.0) * unit)
	_gameplay_bindings.size = Vector2(290.0 * unit, (90.0 if not compact else 48.0) * unit)
	_gameplay_bindings.max_lines_visible = 4 if not compact else 2
	_gameplay_bindings.add_theme_font_size_override("font_size", int(fonts.caption))
	var enemy_width: float = minf(320.0 * unit, center_channel if touch else safe.size.x * 0.37)
	var target_y: float = top + (150.0 if touch and compact else (110.0 if compact else 8.0)) * unit
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
	prompt_label.position = Vector2(center - prompt_width * 0.5, bottom - 69.0 * unit)
	prompt_label.size = Vector2(prompt_width, 55.0 * unit)
	prompt_label.add_theme_font_size_override("font_size", int(fonts.body))
	prompt_back.position = prompt_label.position - Vector2(6, 2) * unit
	prompt_back.size = prompt_label.size + Vector2(12, 4) * unit
	var status_width: float = minf(360.0 * unit, center_channel)
	status_label.position = Vector2(center - status_width * 0.5, bottom - 106.0 * unit)
	status_label.size = Vector2(status_width, 28.0 * unit)
	status_label.add_theme_font_size_override("font_size", int(fonts.caption))
	hint_label.position = Vector2(center - status_width * 0.5, target_y + 77.0 * unit)
	hint_label.size = Vector2(status_width, 48.0 * unit)
	hint_label.add_theme_font_size_override("font_size", int(fonts.caption))
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
	_apply_hud_visual_colors()
func _build_menu_layer() -> void:
	menu_layer = Control.new()
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.visible = false
	add_child(menu_layer)

func _build_dialogue() -> void:
	dialogue_layer = PanelContainer.new()
	dialogue_layer.name = "DialogueLowerThird"
	dialogue_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	dialogue_layer.visible = false
	add_child(dialogue_layer)
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

func _build_inventory() -> void:
	inventory_layer = PanelContainer.new()
	inventory_layer.visible = false
	add_child(inventory_layer)
	_inventory_root = VBoxContainer.new()
	inventory_layer.add_child(_inventory_root)
	_inventory_columns = HBoxContainer.new()
	_inventory_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_root.add_child(_inventory_columns)
	_journal_column = VBoxContainer.new()
	_journal_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_journal_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_columns.add_child(_journal_column)
	journal_art = TextureRect.new()
	journal_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	journal_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	journal_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	journal_art.visible = false
	_journal_column.add_child(journal_art)
	inventory_notice_label = Label.new()
	inventory_notice_label.name = "JournalOperationStatus"
	inventory_notice_label.set_meta("layout_font_role", "caption")
	inventory_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_notice_label.max_lines_visible = 2
	inventory_notice_label.clip_text = true
	_journal_column.add_child(inventory_notice_label)
	inventory_text = RichTextLabel.new()
	inventory_text.set_meta("navigation_key", "journal_text")
	inventory_text.set_meta("navigation_scroll", "journal_text")
	inventory_text.set_meta("layout_font_role", "body")
	inventory_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_text.scroll_active = true
	inventory_text.focus_mode = Control.FOCUS_ALL
	inventory_text.add_theme_constant_override("line_separation", 5)
	_journal_column.add_child(inventory_text)
	_preparation_actions_scroll = ScrollContainer.new()
	_preparation_actions_scroll.name = "SelectedSupplyActionScroll"
	_preparation_actions_scroll.set_meta("navigation_scroll", "selected_actions")
	_preparation_actions_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_preparation_actions_scroll.follow_focus = true
	_journal_column.add_child(_preparation_actions_scroll)
	_preparation_actions = VBoxContainer.new()
	_preparation_actions.name = "SelectedSupplyActions"
	_preparation_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preparation_actions.visible = false
	_preparation_actions_scroll.add_child(_preparation_actions)
	_journal_actions_scroll = ScrollContainer.new()
	_journal_actions_scroll.name = "PreparationActionsScroll"
	_journal_actions_scroll.set_meta("navigation_scroll", "journal_actions")
	_journal_actions_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_journal_actions_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_journal_actions_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_journal_actions_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_journal_actions_scroll.follow_focus = true
	_inventory_columns.add_child(_journal_actions_scroll)
	craft_buttons = VBoxContainer.new()
	craft_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_journal_actions_scroll.add_child(craft_buttons)
	_inventory_footer = GridContainer.new()
	_inventory_root.add_child(_inventory_footer)
	_inventory_read_button = _preparation_button("Read", "journal_pane:reader", _inventory_footer)
	_inventory_read_button.toggle_mode = true
	_inventory_read_button.pressed.connect(func(): _set_inventory_pane("reader", true))
	_inventory_entries_button = _preparation_button("Entries", "journal_pane:entries", _inventory_footer)
	_inventory_entries_button.toggle_mode = true
	_inventory_entries_button.pressed.connect(func(): _set_inventory_pane("entries", true))
	_inventory_close_button = _preparation_button("Close", "journal_close", _inventory_footer)
	_inventory_close_button.pressed.connect(_close_inventory)
func _labeled_bar(label_text: String, bar: ProgressBar, value_label: Label) -> HBoxContainer:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(58, 20)
	label.add_theme_font_size_override("font_size", 12)
	_bar_name_labels.append(label)
	row.add_child(label)
	bar.custom_minimum_size = Vector2(122, 16)
	row.add_child(bar)
	value_label.text = "%d / %d" % [int(bar.value), int(bar.max_value)]
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(72, 20)
	value_label.add_theme_font_size_override("font_size", 12)
	row.add_child(value_label)
	return row

func _clear_menu() -> void:
	_capture_menu_state()
	_touch_reason_label = null
	_menu_notice = null
	_journey_card = null
	_journey_card_kind = ""
	_journey_primary_button = null
	_save_slot_notice = null
	new_game_status_label = null
	for child in menu_layer.get_children():
		menu_layer.remove_child(child)
		child.queue_free()

func _menu_box(title: String, subtitle: String = "", omen_text: String = "", _height_limit: float = 760.0) -> VBoxContainer:
	_rendered_screen = _screen_key()
	_screen_generation += 1
	navigation.set_parent(_rendered_screen, _screen_parent())
	call_deferred("_restore_menu_state", _rendered_screen, _screen_generation)
	_build_menu_background()
	_menu_frame = Control.new()
	_menu_frame.name = "ResponsiveMenuFrame"
	menu_layer.add_child(_menu_frame)
	var frame_box: VBoxContainer = VBoxContainer.new()
	frame_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_frame.add_child(frame_box)
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
		subtitle_label.set_meta("layout_font_role", "caption")
		subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.70, 0.56))
		_menu_title_stack.add_child(subtitle_label)
	if omen_text != "":
		var omen: Label = Label.new()
		omen.text = omen_text.to_upper()
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
	build.set_meta("layout_font_role", "caption")
	build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build.add_theme_color_override("font_color", Color(0.50, 0.46, 0.38))
	_menu_title_stack.add_child(build)
	_menu_panel = PanelContainer.new()
	_menu_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(_menu_panel, Color(0.030, 0.026, 0.022, 0.88), Color(0.58, 0.42, 0.20, 0.86))
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
	_menu_footer = HBoxContainer.new()
	frame_box.add_child(_menu_footer)
	_menu_back_button = Button.new()
	_menu_back_button.set_meta("navigation_key", "surface_back")
	_menu_back_button.text = "Resume" if active_menu == "pause" else "Back"
	_menu_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_back_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_style_button(_menu_back_button)
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
	backdrop.texture = preload("res://assets_external/ui/greyfen_menu_runtime.jpg")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(backdrop)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.015, 0.018, 0.28)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(shade)

func _add_menu_button(box: VBoxContainer, text: String, callback: Callable, disabled: bool = false, focus_key: String = "") -> Button:
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
		_capture_menu_state()
		menu_clicked.emit()
		callback.call()
	)
	box.add_child(button)
	return button

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
	if get_viewport() == null:
		return MENU_SIZE
	var size := get_viewport().get_visible_rect().size
	return MENU_SIZE if size.x < 320.0 or size.y < 240.0 else size

func _current_settings() -> Dictionary:
	var settings_node = get_tree().root.find_child("Settings", true, false)
	if settings_node != null:
		return settings_node.settings
	return {}

func set_input_source(source: Node) -> void:
	input_source = source
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

func apply_accessibility(current: Dictionary) -> void:
	reduced_motion = bool(current.get("reduced_motion", false))
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
		dialogue_text.modulate = Color.WHITE
		dialogue_title.modulate = Color.WHITE
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
	call_deferred("_apply_hud_layout")

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
	update_equipment(last_potions, last_bombs, last_oil_name, last_arrow_count, last_arrow_type, last_weapon_name, last_remedy_id, last_tool_id)
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

func _controller_sensitivity_label(value: float) -> String:
	if value < 0.8:
		return "Low"
	if value > 1.2:
		return "High"
	return "Medium"

func _focus_after_rebuild(container: Node) -> void:
	await get_tree().process_frame
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

func _input(event: InputEvent) -> void:
	if _journey_load_active:
		if event.is_action_pressed("ui_cancel"):
			_cancel_journey_load()
			get_viewport().set_input_as_handled()
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
	var focused_control: Control = get_viewport().gui_get_focus_owner()
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
		get_viewport().set_input_as_handled()
		return
	if navigation_direction != 0:
		_cancel_dialogue_press()
		var controls: Array[Control] = _dialogue_focus_controls()
		if not controls.is_empty():
			var next_index: int = posmod(controls.find(focused_control) + navigation_direction, controls.size())
			controls[next_index].grab_focus()
		get_viewport().set_input_as_handled()
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
			get_viewport().set_input_as_handled()
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
			get_viewport().set_input_as_handled()
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
			get_viewport().set_input_as_handled()
		elif not pointer:
			get_viewport().set_input_as_handled()
		return
	if source != _dialogue_pending_source:
		return
	var target: Button = _dialogue_pending_button
	_cancel_dialogue_press()
	get_viewport().set_input_as_handled()
	if not is_instance_valid(target) or target.disabled or not target.is_visible_in_tree() or not dialogue_layer.is_ancestor_of(target):
		return
	if pointer and not _dialogue_pointer_hits(target, point):
		return
	if not pointer and get_viewport().gui_get_focus_owner() != target:
		return
	target.pressed.emit()

func _cancel_dialogue_press() -> void:
	_dialogue_pending_button = null
	_dialogue_pending_source = ""
func _dialogue_pointer_hits(button: Button, point: Vector2) -> bool:
	if not button.get_global_rect().has_point(point):
		return false
	var ancestor := button.get_parent()
	while ancestor != null and ancestor != dialogue_layer:
		if ancestor is Control and ancestor.clip_contents and not ancestor.get_global_rect().has_point(point):
			return false
		ancestor = ancestor.get_parent()
	return true

func _capture_remap_input(event: InputEvent) -> bool:
	# Capture before GUI navigation consumes arrows, accept keys or clicks.
	if active_menu == "remap" and remap_waiting:
		if event.is_action_pressed("ui_cancel"):
			remap_waiting = false
			toast("Binding cancelled.")
			get_viewport().set_input_as_handled()
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
			get_viewport().set_input_as_handled()
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _journey_load_active:
		_cancel_journey_load()
		get_viewport().set_input_as_handled()
		return
	if input_source != null and input_source.has_method("accept_event") and not input_source.accept_event(event, "ui_cancel", input_source.get_context()):
		get_viewport().set_input_as_handled()
		return
	if request_back():
		get_viewport().set_input_as_handled()

func request_back() -> bool:
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
	elif active_menu == "pause":
		resume_requested.emit()
		return true
	elif active_menu == "main":
		return true
	elif active_menu != "":
		_return_to_parent()
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

func _close_dialogue_surface() -> bool:
	if _dialogue_review_open:
		_dialogue_review_open = false
		dialogue_review_changed.emit(false)
	# Hide the surface before notifying game logic so a delayed browser event
	# cannot activate a stale button while the zone is being rebuilt.
	if dialogue_closing or dialogue_layer == null or not dialogue_layer.visible:
		return false
	dialogue_closing = true
	hide_menus()
	get_tree().paused = false
	return true

func _focused_dialogue_button() -> Button:
	if dialogue_actions == null:
		return null
	for child in dialogue_actions.get_children():
		if child is Button and not (child as Button).disabled:
			return child as Button
	return null

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
	dialogue_title.add_theme_color_override("font_color", Color.WHITE if high_contrast else HudVisualStyle.GOLD)
	dialogue_text.add_theme_color_override("default_color", Color.WHITE if high_contrast else HudVisualStyle.IVORY)
	_dialogue_history_button.add_theme_color_override("font_color", Color.WHITE if high_contrast else HudVisualStyle.MUTED)
	_dialogue_back_button.add_theme_color_override("font_color", Color.WHITE if high_contrast else HudVisualStyle.MUTED)
	_apply_hud_visual_colors()

func _apply_hud_visual_colors() -> void:
	for label: Label in _hud_text_labels():
		HudVisualStyle.label_color(label, HudVisualStyle.IVORY, high_contrast)
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
	labels.append_array([_world_clock_label, _gameplay_bindings, _quest_marker])
	for raw: Variant in supply_labels.values():
		labels.append(raw as Label)
	for raw: Variant in supply_counts.values():
		labels.append(raw as Label)
	return labels

func _format_tracker_text(text: String) -> String:
	if text == "":
		return ""
	var lines = text.split("\n", false)
	if lines.size() <= 1:
		return text
	var title = str(lines[0]).to_upper()
	var objective = str(lines[1]).replace("- ", "").strip_edges()
	return "%s\n%s" % [title, _objective_with_verb(objective)]

func _objective_with_verb(objective: String) -> String:
	if objective.begins_with("Speak") or objective.begins_with("Follow") or objective.begins_with("Inspect") or objective.begins_with("Survive") or objective.begins_with("Return"):
		return objective
	if objective.begins_with("Investigate"):
		return "Inspect " + objective.trim_prefix("Investigate ")
	if objective.begins_with("Find"):
		return objective
	if objective.begins_with("Kill") or objective.begins_with("Defeat"):
		return "Survive: " + objective
	return objective

func _flash_bar(bar: ProgressBar, color: Color) -> void:
	if flash_reduction or reduced_motion:
		return
	var previous := _bar_tweens.get(bar) as Tween
	if previous != null and previous.is_valid():
		previous.kill()
	bar.modulate = color
	var tween = create_tween()
	_bar_tweens[bar] = tween
	tween.tween_property(bar, "modulate", Color.WHITE, 0.18)

func _status_color(kind: String) -> Color:
	if high_contrast:
		return Color(1.0, 0.96, 0.84)
	if kind == "parry":
		return Color(0.66, 0.88, 1.0, 1.0)
	if kind == "block" or kind == "stamina":
		return Color(1.0, 0.74, 0.28, 1.0)
	if kind == "hurt":
		return Color(1.0, 0.34, 0.22, 1.0)
	if kind == "victory":
		return Color(0.76, 0.90, 0.58, 1.0)
	if kind == "item":
		return Color(0.82, 0.70, 0.45, 1.0)
	return Color(0.86, 0.81, 0.69, 1.0)

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

func _capture_inventory_state() -> void:
	if is_instance_valid(inventory_layer) and inventory_layer.visible:
		navigation.capture(_inventory_screen, "gameplay", inventory_layer)
		if _evidence_position_key != "" and _inventory_screen.begins_with("journal:"):
			_evidence_navigation.remember(_evidence_position_key, navigation.screens.get(_inventory_screen, {}))
func _restore_inventory_state(key: String, generation: int) -> void:
	await get_tree().process_frame
	if generation == _inventory_generation and key == _inventory_screen and inventory_layer.visible:
		var controls: Array[Control] = []
		_collect_inventory_focus(inventory_layer, controls)
		var state: Dictionary = navigation.screens.get(key, {})
		var desired: String = str(state.get("focus", ""))
		var desired_available: bool = false
		var current_selection: Dictionary = _preparation_selection.get(key, {})
		var selection_key: String = str(current_selection.get("kind", "item")) + ":" + str(current_selection.get("id", ""))
		if _evidence_position_key != "":
			selection_key = _evidence_focus_target()
		for control: Control in controls:
			if str(control.get_meta("navigation_key", "")) == desired:
				desired_available = true
			if str(control.get_meta("navigation_key", "")) == selection_key:
				inventory_text.focus_neighbor_right = inventory_text.get_path_to(control)
		if desired.begins_with("action:") and not desired_available:
			var selection: Dictionary = _preparation_selection.get(key, {})
			state["focus"] = str(selection.get("kind", "item")) + ":" + str(selection.get("id", ""))
			navigation.screens[key] = state
		for index: int in range(controls.size()):
			var control: Control = controls[index]
			control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
			control.focus_previous = control.get_path_to(controls[posmod(index - 1, controls.size())])
			if control != inventory_text:
				control.focus_neighbor_top = control.focus_previous
				control.focus_neighbor_bottom = control.focus_next
				control.focus_neighbor_left = control.get_path_to(inventory_text)
		navigation.restore(key, inventory_layer)

func _collect_inventory_focus(node: Node, controls: Array[Control]) -> void:
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Control and child.is_visible_in_tree() and child.focus_mode != Control.FOCUS_NONE and child.has_meta("navigation_key"):
			if not (child is BaseButton and child.disabled):
				controls.append(child as Control)
		_collect_inventory_focus(child, controls)

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
	await get_tree().process_frame
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

func _save_service():
	var service = get_parent().get("save_manager")
	if service != null:
		if not service.library_changed.is_connected(_refresh_save_library):
			service.library_changed.connect(_refresh_save_library)
		if service.has_signal("operation_finished") and not service.operation_finished.is_connected(_on_save_operation_finished):
			service.operation_finished.connect(_on_save_operation_finished)
	return service

func _on_save_operation_finished(slot_id: String, operation: String, success: bool, text: String) -> void:
	if slot_id != "":
		_slot_operation_results[slot_id] = text
	if success and operation in ["import", "restore"] and active_menu == "save_slot" and selected_slot == slot_id:
		var field := menu_layer.find_child("SaveSlotName", true, false) as LineEdit
		for slot in _save_service().list_slots():
			if str(slot.id) == slot_id and field != null:
				field.text = str(slot.title)
	if active_menu != "save_slot" or selected_slot != slot_id:
		post_notice(text, "save" if success else "error", 5.0, "save_operation:" + operation + ":" + slot_id)
	elif is_instance_valid(_save_slot_notice):
		_save_slot_notice.text = text
	if success and operation == "import" and active_menu == "save_import":
		_return_after_import = true
	_refresh_save_library()

func show_save_library(back_target: String = "pause", requested_page: int = 0) -> void:
	library_back_target = back_target
	library_page = maxi(0, requested_page)
	active_menu = "save_library"
	_set_internal_canvas(Vector2i(MENU_SIZE))
	_set_ui_pointer("pause")
	_clear_menu()
	menu_layer.visible = true
	var box: VBoxContainer = _menu_box("Saved Journeys", "The road you remember", "manual saves and protected checkpoints")
	box.set_meta("compact_buttons", true)
	var service = _save_service()
	if service == null:
		_add_menu_text(box, "Save storage is preparing.")
		_add_menu_button(box, "Back", _return_from_library)
		return
	var slots: Array = service.list_slots()
	var pages: int = maxi(1, ceili(float(slots.size()) / 4.0))
	library_page = clampi(requested_page, 0, pages - 1)
	_add_menu_text(box, "Page %d of %d. Open a journey to read its recorded promise and next step." % [library_page + 1, pages])
	for index: int in range(library_page * 4, mini(slots.size(), library_page * 4 + 4)):
		var slot: Dictionary = slots[index]
		_add_menu_button(box, JourneyMenuPanel.slot_row(slot), func(id: String = str(slot.get("id", ""))): show_save_slot(id), false, "slot:" + str(slot.get("id", "")))
	_add_menu_button(box, "Previous Page", func(): show_save_library(library_back_target, library_page - 1), library_page <= 0, "previous_page")
	_add_menu_button(box, "Next Page", func(): show_save_library(library_back_target, library_page + 1), library_page >= pages - 1, "next_page")
	_add_menu_text(box, "Browser saves belong to this browser and device. Export a JSON copy to keep or move a journey.")
	_add_menu_button(box, "Import a Save File", func(): service.request_import_file(), false, "import_file")
	_add_menu_button(box, "Paste a Save", show_save_import)
	_add_menu_button(box, "Chapter Replay", show_chapter_replays, service.chapter_replays().is_empty())
	_add_menu_button(box, "Back", _return_from_library)
func _refresh_save_library() -> void:
	if _library_refresh_pending:
		return
	_library_refresh_pending = true
	call_deferred("_flush_library_refresh")

func _flush_library_refresh() -> void:
	_library_refresh_pending = false
	if _return_after_import:
		_return_after_import = false
		show_save_library(library_back_target, 0)
	elif active_menu == "save_library":
		show_save_library(library_back_target, library_page)
	elif active_menu == "save_slot":
		show_save_slot(selected_slot)

func show_save_slot(slot_id: String) -> void:
	selected_slot = slot_id
	active_menu = "save_slot"
	_clear_menu()
	var service = _save_service()
	var slot: Dictionary = {}
	for candidate: Dictionary in service.list_slots():
		if str(candidate.get("id", "")) == slot_id:
			slot = candidate
	if slot.is_empty():
		show_save_library(library_back_target, library_page)
		return
	var box: VBoxContainer = _menu_box(str(slot.get("title", "Journey")), JourneyMenuPanel.status_text(str(slot.get("status", "empty"))), "recorded journey")
	box.set_meta("compact_buttons", true)
	_set_journey_card_text(JourneyMenuPanel.card(slot))
	var title: LineEdit = LineEdit.new()
	if not bool(slot.get("protected", false)):
		title.text = str(slot.get("title", "Journey"))
		title.name = "SaveSlotName"
		_register_field(title, "slot_name", title.text)
		title.max_length = 48
		title.placeholder_text = "Name this journey"
		title.custom_minimum_size = Vector2(320, 52)
		title.focus_mode = Control.FOCUS_ALL
		box.add_child(title)
	else:
		title.queue_free()
	_save_slot_notice = _add_menu_text(box, str(_slot_operation_results.get(slot_id, "")))
	_save_slot_notice.custom_minimum_size.y = 62.0
	_add_journey_load_button(box, "Load Previous Copy" if str(slot.get("status", "")) == "recoverable" else "Load This Journey", slot, "load_slot:" + slot_id)
	_add_journey_recovery_options(box, slot)
	if not bool(slot.get("protected", false)):
		var can_save: bool = get_parent().get("game_started") == true and is_instance_valid(get_parent().get("player"))
		_add_menu_button(box, "Replace With Current Journey" if bool(slot.get("exists", false)) else "Save Current Journey Here", func(): service.save_named(get_parent(), slot_id, title.text), not can_save, "save_current")
		_add_menu_button(box, "Rename", func(): service.rename_slot(slot_id, title.text), not bool(slot.get("valid", false)), "rename")
		_add_menu_button(box, "Restore Previous Slot Copy", func(): service.restore_previous_slot(slot_id), not bool(slot.get("backup_available", false)), "restore_previous")
		_add_menu_button(box, "Import File Into This Slot", func(): service.request_import_file(slot_id), false, "import_slot")
		_add_menu_text(box, "Replacing or importing here retains the previous slot copy. Export first to keep more than one earlier version.")
	else:
		_add_menu_text(box, "This protected record can be loaded or exported. The game manages when it is written.")
	_add_menu_button(box, "Export This Journey", func(): service.export_slot(slot_id), not bool(slot.get("valid", false)), "export_slot")
	_add_menu_button(box, "Back", func(): show_save_library(library_back_target, library_page))
func show_save_import() -> void:
	active_menu = "save_import"
	_clear_menu()
	var box := _menu_box("Import a Journey", "Paste an exported JSON save", "imports use an empty manual slot")
	_add_menu_text(box, "Paste the complete save below. The game checks its format and location before creating a new slot. Existing journeys stay in place.")
	var input := TextEdit.new()
	input.custom_minimum_size = Vector2(340, 280)
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input.placeholder_text = "Paste Ashen Oath save JSON"
	_register_field(input, "import_json", "")
	box.add_child(input)
	_add_menu_button(box, "Import Into an Empty Slot", func():
		_save_service().import_save_text(input.text)
	)
	_add_menu_button(box, "Back", func(): show_save_library(library_back_target, library_page))

func show_chapter_replays() -> void:
	active_menu = "chapter_replay"
	_clear_menu()
	var box: VBoxContainer = _menu_box("Return to a Chapter", "A copied journey", "your completed outcome is preserved")
	_add_menu_text(box, "Replay begins from a recorded chapter checkpoint. It uses separate automatic saves; a manual save can preserve it as another journey.")
	for chapter: Dictionary in _save_service().chapter_replays():
		_add_journey_load_button(box, JourneyMenuPanel.slot_row(chapter), chapter, "replay:" + str(chapter.get("id", "")))
		if not bool(chapter.get("available", false)):
			_add_menu_text(box, str(chapter.get("reason", "This chapter record is unavailable.")))
	_add_menu_button(box, "Back", func(): show_save_library(library_back_target, library_page))
func _return_from_library() -> void:
	_return_to_parent()

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
		call_deferred("_restore_dialogue_reading_state")
	else:
		_return_from_library()

func _capture_dialogue_reading_state() -> void:
	var focused := get_viewport().gui_get_focus_owner()
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

func _show_journal_art(quests, state) -> void:
	if journal_art == null:
		return
	var path := "res://assets/ui/story_chapters_atlas.png"
	if not ResourceLoader.exists(path):
		journal_art.visible = false
		return
	var image := load(path) as Texture2D
	if image == null:
		return
	var cell := 0
	if state != null and (bool(state.get_flag("final_choice_completed", false)) or quests.is_active("main_hart_remembers")):
		cell = 3
	elif quests.is_completed("main_names_they_burned"):
		cell = 2
	elif quests.is_completed("main_road_of_crows"):
		cell = 1
	var atlas := AtlasTexture.new()
	atlas.atlas = image
	atlas.region = Rect2(float(cell % 2) * image.get_width() / 2.0, floorf(float(cell) / 2.0) * image.get_height() / 2.0, image.get_width() / 2.0, image.get_height() / 2.0)
	journal_art.texture = atlas
	journal_art.visible = true

func show_problem_report(back_target: String = "pause") -> void:
	library_back_target = back_target
	active_menu = "problem_report"
	_clear_menu()
	var box := _menu_box("Report a Problem", "Keep a useful record", "nothing is sent automatically")
	_add_menu_text(box, "Describe what happened, what you expected, and the last choice you made. Download the report and share it with the project when you choose. Export a save separately if it helps reproduce the problem.")
	var description := TextEdit.new()
	description.custom_minimum_size = Vector2(340, 240)
	description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	description.placeholder_text = "What happened?"
	_register_field(description, "problem_description", "")
	box.add_child(description)
	_add_menu_button(box, "Download Problem Report", func(): _download_problem_report(description.text))
	_add_menu_button(box, "Back", _return_from_library)

func _download_problem_report(description: String) -> void:
	var game = get_parent()
	var report := {"game": "Ashen Oath", "created_utc": Time.get_datetime_string_from_system(true), "description": description.left(16000), "zone": str(game.get("current_zone_id")), "engine": Engine.get_version_info().get("string", ""), "platform": OS.get_name(), "input": input_device, "settings": _current_settings().duplicate(true)}
	report.settings.erase("gamepad_profiles")
	report.settings.erase("custom_bindings")
	var content := JSON.stringify(report, "\t")
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(content.to_utf8_buffer(), "ashen-oath-problem-report.json", "application/json")
		toast("Problem report download requested. Nothing was sent.")
	else:
		var path := "user://ashen-oath-problem-report.json"
		var output := FileAccess.open(path, FileAccess.WRITE)
		if output != null:
			output.store_string(content)
			output.close()
			toast("Report saved to " + ProjectSettings.globalize_path(path))

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

func _hide_native_button_text(button: Button) -> void:
	# Keep the actual Button text for accessible names and existing callers.
	# Its wrapped child label owns only the visual presentation.
	for color_key in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_disabled_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color_key, Color(0, 0, 0, 0))
