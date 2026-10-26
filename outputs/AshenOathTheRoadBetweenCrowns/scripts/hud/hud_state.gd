extends RefCounted
## Shared presentation state; no gameplay ownership or persistence format changes.

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
const StartupLoadingView = preload("res://scripts/startup_loading_view.gd")
const MENU_FONT = preload("res://assets/ui/fonts/Spectral-Medium.ttf")

var _startup_view: StartupLoadingView
var _menu_reveal_tween: Tween
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
var _journal_models: Dictionary = {}
var _journal_source_revisions: Dictionary = {}
var _journal_buttons: Dictionary = {}
var _journal_pool_host: Control
var _last_progression_model: Dictionary = {}
var _equipment_view_key: Array = []
var library_back_target := "pause"
var selected_slot := ""
var subtitle_speaker_names := true
var flash_reduction := false
var journal_art: TextureRect
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var xp_bar: ProgressBar
var xp_label: Label
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
var _gameplay_ui_ready := false
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
var last_oil_seconds := -1
var last_arrow_count := -1
var last_arrow_type := "Standard"
var toasts_suppressed := false
var reduced_motion := false
var high_contrast := false
var story_text_scale := 1.0
var new_game_ready := false
var new_game_status := "Greyfen is ready."
var new_game_status_label: Label
var _opening_progress: ProgressBar
var _opening_retry: Button
var _opening_cancel: Button
var _opening_preparation: Dictionary = {"state": "preparing", "message": "Preparing Greyfen...", "progress": -1.0, "requested": false}
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
var _world_atlas: Control
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
var _save_durability_notice: Label
var _topic_navigation = DialogueTopicNavigation.new()
var _dialogue_view_generation := 0
var _evidence_navigation = JournalEvidenceNavigation.new()
var _evidence_position_key := ""
var _evidence_reference_section := ""
var _evidence_reference_entry := ""
var _display_metrics: Dictionary = {}
var _layout_policy: Dictionary = {}
var _touch_shared_prompt := false
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
var _pointer_pause_button: Button
var _compact_menu_title: Label
var _game_owner: Node
var _save_manager: Node
var _ambient_panel: PanelContainer
var _ambient_words: Label
var _ambient_owner := 0
var _ambient_remaining := 0.0
var _honor_source: Node
var _menu_frame_box: VBoxContainer
var _settings_source: Node
