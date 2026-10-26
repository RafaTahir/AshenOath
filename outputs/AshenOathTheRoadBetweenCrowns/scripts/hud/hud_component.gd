extends Node
## Typed compatibility bindings used by the extracted panels.
## The injected CanvasLayer retains control, tween and deferred-call ownership.

signal new_game_requested
signal new_game_cancel_requested
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
signal vendor_sale_requested(vendor_id: String, item_id: String, quantity: int)
signal upgrade_requested(upgrade_id: String)
signal respec_requested
signal dialogue_closed
signal pause_requested
signal dialogue_review_changed(open: bool)
signal dialogue_page_changed(speaker: String, speaker_id: String, page_index: int, total_pages: int)
signal menu_hovered
signal menu_clicked
signal journey_load_requested(selection: Dictionary)
signal journey_load_cancel_requested
signal journal_section_requested(section_id: String)
signal dialogue_topic_requested(context_id: String, topic_id: String, revision_key: String)
signal dialogue_speech_interrupted
signal interaction_prompt_changed(model: Dictionary)
signal touch_quick_action_requested(action: String)

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

const HudState = preload("res://scripts/hud/hud_state.gd")
var view: CanvasLayer
var state: HudState

func configure(owner_view: CanvasLayer, presentation: HudState) -> void:
	view = owner_view
	state = presentation

var _startup_view: StartupLoadingView:
	get: return state._startup_view
	set(value): state._startup_view = value
var _menu_reveal_tween: Tween:
	get: return state._menu_reveal_tween
	set(value): state._menu_reveal_tween = value
var navigation: NavigationState:
	get: return state.navigation
	set(value): state.navigation = value
var notices: NoticeQueue:
	get: return state.notices
	set(value): state.notices = value
var _rendered_screen: String:
	get: return state._rendered_screen
	set(value): state._rendered_screen = value
var _screen_generation: int:
	get: return state._screen_generation
	set(value): state._screen_generation = value
var _dialogue_review_open: bool:
	get: return state._dialogue_review_open
	set(value): state._dialogue_review_open = value
var _dialogue_reading_state: Dictionary:
	get: return state._dialogue_reading_state
	set(value): state._dialogue_reading_state = value
var _dialogue_history_button: Button:
	get: return state._dialogue_history_button
	set(value): state._dialogue_history_button = value
var _menu_notice: Label:
	get: return state._menu_notice
	set(value): state._menu_notice = value
var _notice_active: Dictionary:
	get: return state._notice_active
	set(value): state._notice_active = value
var _notice_remaining: float:
	get: return state._notice_remaining
	set(value): state._notice_remaining = value
var _slot_operation_results: Dictionary:
	get: return state._slot_operation_results
	set(value): state._slot_operation_results = value
var _library_refresh_pending: bool:
	get: return state._library_refresh_pending
	set(value): state._library_refresh_pending = value
var _return_after_import: bool:
	get: return state._return_after_import
	set(value): state._return_after_import = value
var _interaction_prompt_model: Dictionary:
	get: return state._interaction_prompt_model
	set(value): state._interaction_prompt_model = value
var _inventory_screen: String:
	get: return state._inventory_screen
	set(value): state._inventory_screen = value
var _inventory_generation: int:
	get: return state._inventory_generation
	set(value): state._inventory_generation = value
var text_history: DialogueHistory:
	get: return state.text_history
	set(value): state.text_history = value
var library_page: int:
	get: return state.library_page
	set(value): state.library_page = value
var _journal_models: Dictionary:
	get: return state._journal_models
	set(value): state._journal_models = value
var _journal_source_revisions: Dictionary:
	get: return state._journal_source_revisions
	set(value): state._journal_source_revisions = value
var _journal_buttons: Dictionary:
	get: return state._journal_buttons
	set(value): state._journal_buttons = value
var _journal_pool_host: Control:
	get: return state._journal_pool_host
	set(value): state._journal_pool_host = value
var _last_progression_model: Dictionary:
	get: return state._last_progression_model
	set(value): state._last_progression_model = value
var _equipment_view_key: Array:
	get: return state._equipment_view_key
	set(value): state._equipment_view_key = value
var library_back_target: String:
	get: return state.library_back_target
	set(value): state.library_back_target = value
var selected_slot: String:
	get: return state.selected_slot
	set(value): state.selected_slot = value
var subtitle_speaker_names: bool:
	get: return state.subtitle_speaker_names
	set(value): state.subtitle_speaker_names = value
var flash_reduction: bool:
	get: return state.flash_reduction
	set(value): state.flash_reduction = value
var journal_art: TextureRect:
	get: return state.journal_art
	set(value): state.journal_art = value
var health_bar: ProgressBar:
	get: return state.health_bar
	set(value): state.health_bar = value
var stamina_bar: ProgressBar:
	get: return state.stamina_bar
	set(value): state.stamina_bar = value
var xp_bar: ProgressBar:
	get: return state.xp_bar
	set(value): state.xp_bar = value
var xp_label: Label:
	get: return state.xp_label
	set(value): state.xp_label = value
var health_value_label: Label:
	get: return state.health_value_label
	set(value): state.health_value_label = value
var stamina_value_label: Label:
	get: return state.stamina_value_label
	set(value): state.stamina_value_label = value
var enemy_bar: ProgressBar:
	get: return state.enemy_bar
	set(value): state.enemy_bar = value
var enemy_label: Label:
	get: return state.enemy_label
	set(value): state.enemy_label = value
var enemy_value_label: Label:
	get: return state.enemy_value_label
	set(value): state.enemy_value_label = value
var target_status_label: Label:
	get: return state.target_status_label
	set(value): state.target_status_label = value
var prompt_label: Label:
	get: return state.prompt_label
	set(value): state.prompt_label = value
var tracker_label: Label:
	get: return state.tracker_label
	set(value): state.tracker_label = value
var compass_label: Label:
	get: return state.compass_label
	set(value): state.compass_label = value
var toast_label: Label:
	get: return state.toast_label
	set(value): state.toast_label = value
var hint_label: Label:
	get: return state.hint_label
	set(value): state.hint_label = value
var status_label: Label:
	get: return state.status_label
	set(value): state.status_label = value
var equipment_label: Label:
	get: return state.equipment_label
	set(value): state.equipment_label = value
var menu_layer: Control:
	get: return state.menu_layer
	set(value): state.menu_layer = value
var loading_layer: Control:
	get: return state.loading_layer
	set(value): state.loading_layer = value
var loading_message: Label:
	get: return state.loading_message
	set(value): state.loading_message = value
var loading_elapsed: float:
	get: return state.loading_elapsed
	set(value): state.loading_elapsed = value
var loading_armed: bool:
	get: return state.loading_armed
	set(value): state.loading_armed = value
var dialogue_layer: PanelContainer:
	get: return state.dialogue_layer
	set(value): state.dialogue_layer = value
var dialogue_title: Label:
	get: return state.dialogue_title
	set(value): state.dialogue_title = value
var dialogue_text: RichTextLabel:
	get: return state.dialogue_text
	set(value): state.dialogue_text = value
var dialogue_actions: VBoxContainer:
	get: return state.dialogue_actions
	set(value): state.dialogue_actions = value
var dialogue_choices_scroll: ScrollContainer:
	get: return state.dialogue_choices_scroll
	set(value): state.dialogue_choices_scroll = value
var dialogue_page_label: Label:
	get: return state.dialogue_page_label
	set(value): state.dialogue_page_label = value
var inventory_layer: PanelContainer:
	get: return state.inventory_layer
	set(value): state.inventory_layer = value
var _gameplay_ui_ready: bool:
	get: return state._gameplay_ui_ready
	set(value): state._gameplay_ui_ready = value
var inventory_text: RichTextLabel:
	get: return state.inventory_text
	set(value): state.inventory_text = value
var craft_buttons: VBoxContainer:
	get: return state.craft_buttons
	set(value): state.craft_buttons = value
var controls_back_target: String:
	get: return state.controls_back_target
	set(value): state.controls_back_target = value
var last_health: float:
	get: return state.last_health
	set(value): state.last_health = value
var last_health_max: float:
	get: return state.last_health_max
	set(value): state.last_health_max = value
var last_stamina: float:
	get: return state.last_stamina
	set(value): state.last_stamina = value
var last_stamina_max: float:
	get: return state.last_stamina_max
	set(value): state.last_stamina_max = value
var hint_tween: Tween:
	get: return state.hint_tween
	set(value): state.hint_tween = value
var status_tween: Tween:
	get: return state.status_tween
	set(value): state.status_tween = value
var toast_tween: Tween:
	get: return state.toast_tween
	set(value): state.toast_tween = value
var _subtitle_tween: Tween:
	get: return state._subtitle_tween
	set(value): state._subtitle_tween = value
var enemy_hide_tween: Tween:
	get: return state.enemy_hide_tween
	set(value): state.enemy_hide_tween = value
var dialogue_pages: Array:
	get: return state.dialogue_pages
	set(value): state.dialogue_pages = value
var dialogue_page_index: int:
	get: return state.dialogue_page_index
	set(value): state.dialogue_page_index = value
var dialogue_session_data: Dictionary:
	get: return state.dialogue_session_data
	set(value): state.dialogue_session_data = value
var dialogue_closing: bool:
	get: return state.dialogue_closing
	set(value): state.dialogue_closing = value
var input_source: Node:
	get: return state.input_source
	set(value): state.input_source = value
var input_device: String:
	get: return state.input_device
	set(value): state.input_device = value
var gamepad_profile: Dictionary:
	get: return state.gamepad_profile
	set(value): state.gamepad_profile = value
var active_menu: String:
	get: return state.active_menu
	set(value): state.active_menu = value
var settings_page: int:
	get: return state.settings_page
	set(value): state.settings_page = value
var remap_page: int:
	get: return state.remap_page
	set(value): state.remap_page = value
var remap_action_id: String:
	get: return state.remap_action_id
	set(value): state.remap_action_id = value
var remap_back_target: String:
	get: return state.remap_back_target
	set(value): state.remap_back_target = value
var remap_waiting: bool:
	get: return state.remap_waiting
	set(value): state.remap_waiting = value
var raw_prompt: String:
	get: return state.raw_prompt
	set(value): state.raw_prompt = value
var raw_hint: String:
	get: return state.raw_hint
	set(value): state.raw_hint = value
var last_potions: int:
	get: return state.last_potions
	set(value): state.last_potions = value
var last_bombs: int:
	get: return state.last_bombs
	set(value): state.last_bombs = value
var last_weapon_name: String:
	get: return state.last_weapon_name
	set(value): state.last_weapon_name = value
var last_remedy_id: String:
	get: return state.last_remedy_id
	set(value): state.last_remedy_id = value
var last_tool_id: String:
	get: return state.last_tool_id
	set(value): state.last_tool_id = value
var last_oil_name: String:
	get: return state.last_oil_name
	set(value): state.last_oil_name = value
var last_oil_seconds: int:
	get: return state.last_oil_seconds
	set(value): state.last_oil_seconds = value
var last_arrow_count: int:
	get: return state.last_arrow_count
	set(value): state.last_arrow_count = value
var last_arrow_type: String:
	get: return state.last_arrow_type
	set(value): state.last_arrow_type = value
var toasts_suppressed: bool:
	get: return state.toasts_suppressed
	set(value): state.toasts_suppressed = value
var reduced_motion: bool:
	get: return state.reduced_motion
	set(value): state.reduced_motion = value
var high_contrast: bool:
	get: return state.high_contrast
	set(value): state.high_contrast = value
var story_text_scale: float:
	get: return state.story_text_scale
	set(value): state.story_text_scale = value
var new_game_ready: bool:
	get: return state.new_game_ready
	set(value): state.new_game_ready = value
var new_game_status: String:
	get: return state.new_game_status
	set(value): state.new_game_status = value
var new_game_status_label: Label:
	get: return state.new_game_status_label
	set(value): state.new_game_status_label = value
var _opening_progress: ProgressBar:
	get: return state._opening_progress
	set(value): state._opening_progress = value
var _opening_retry: Button:
	get: return state._opening_retry
	set(value): state._opening_retry = value
var _opening_cancel: Button:
	get: return state._opening_cancel
	set(value): state._opening_cancel = value
var _opening_preparation: Dictionary:
	get: return state._opening_preparation
	set(value): state._opening_preparation = value
var hud_root: Control:
	get: return state.hud_root
	set(value): state.hud_root = value
var tracker_back: Control:
	get: return state.tracker_back
	set(value): state.tracker_back = value
var compass_back: Control:
	get: return state.compass_back
	set(value): state.compass_back = value
var tracker_title_label: Label:
	get: return state.tracker_title_label
	set(value): state.tracker_title_label = value
var tracker_caption_label: Label:
	get: return state.tracker_caption_label
	set(value): state.tracker_caption_label = value
var tracker_footer_label: Label:
	get: return state.tracker_footer_label
	set(value): state.tracker_footer_label = value
var tracker_route_label: Label:
	get: return state.tracker_route_label
	set(value): state.tracker_route_label = value
var tracker_work_label: Label:
	get: return state.tracker_work_label
	set(value): state.tracker_work_label = value
var vitals_back: ColorRect:
	get: return state.vitals_back
	set(value): state.vitals_back = value
var vitals_box: VBoxContainer:
	get: return state.vitals_box
	set(value): state.vitals_box = value
var vitals_warning_label: Label:
	get: return state.vitals_warning_label
	set(value): state.vitals_warning_label = value
var supplies_grid: GridContainer:
	get: return state.supplies_grid
	set(value): state.supplies_grid = value
var supply_labels: Dictionary:
	get: return state.supply_labels
	set(value): state.supply_labels = value
var supply_counts: Dictionary:
	get: return state.supply_counts
	set(value): state.supply_counts = value
var notice_category_label: Label:
	get: return state.notice_category_label
	set(value): state.notice_category_label = value
var notice_back: ColorRect:
	get: return state.notice_back
	set(value): state.notice_back = value
var prompt_back: ColorRect:
	get: return state.prompt_back
	set(value): state.prompt_back = value
var _navigation_model: Dictionary:
	get: return state._navigation_model
	set(value): state._navigation_model = value
var _tracker_source: String:
	get: return state._tracker_source
	set(value): state._tracker_source = value
var _attention_remaining: float:
	get: return state._attention_remaining
	set(value): state._attention_remaining = value
var _hint_remaining: float:
	get: return state._hint_remaining
	set(value): state._hint_remaining = value
var _status_remaining: float:
	get: return state._status_remaining
	set(value): state._status_remaining = value
var _status_kind: String:
	get: return state._status_kind
	set(value): state._status_kind = value
var _status_priority: int:
	get: return state._status_priority
	set(value): state._status_priority = value
var _bar_tweens: Dictionary:
	get: return state._bar_tweens
	set(value): state._bar_tweens = value
var _bar_name_labels: Array[Label]:
	get: return state._bar_name_labels
	set(value): state._bar_name_labels = value
var _journal_section_id: String:
	get: return state._journal_section_id
	set(value): state._journal_section_id = value
var _world_atlas: Control:
	get: return state._world_atlas
	set(value): state._world_atlas = value
var _journal_context: Dictionary:
	get: return state._journal_context
	set(value): state._journal_context = value
var inventory_notice_label: Label:
	get: return state.inventory_notice_label
	set(value): state.inventory_notice_label = value
var _preparation_actions: BoxContainer:
	get: return state._preparation_actions
	set(value): state._preparation_actions = value
var _preparation_context: Dictionary:
	get: return state._preparation_context
	set(value): state._preparation_context = value
var _preparation_services: Object:
	get: return state._preparation_services
	set(value): state._preparation_services = value
var _preparation_selection: Dictionary:
	get: return state._preparation_selection
	set(value): state._preparation_selection = value
var _preparation_results: Dictionary:
	get: return state._preparation_results
	set(value): state._preparation_results = value
var _vendor_context: Dictionary:
	get: return state._vendor_context
	set(value): state._vendor_context = value
var _decision_details: RichTextLabel:
	get: return state._decision_details
	set(value): state._decision_details = value
var _decision_selected_key: String:
	get: return state._decision_selected_key
	set(value): state._decision_selected_key = value
var _dialogue_pending_button: Button:
	get: return state._dialogue_pending_button
	set(value): state._dialogue_pending_button = value
var _dialogue_pending_source: String:
	get: return state._dialogue_pending_source
	set(value): state._dialogue_pending_source = value
var _dialogue_press_position: Vector2:
	get: return state._dialogue_press_position
	set(value): state._dialogue_press_position = value
var _journey_models: Dictionary:
	get: return state._journey_models
	set(value): state._journey_models = value
var _journey_card: RichTextLabel:
	get: return state._journey_card
	set(value): state._journey_card = value
var _journey_card_kind: String:
	get: return state._journey_card_kind
	set(value): state._journey_card_kind = value
var _journey_primary_button: Button:
	get: return state._journey_primary_button
	set(value): state._journey_primary_button = value
var _journey_load_active: bool:
	get: return state._journey_load_active
	set(value): state._journey_load_active = value
var _journey_load_applying: bool:
	get: return state._journey_load_applying
	set(value): state._journey_load_applying = value
var _journey_load_origin: Dictionary:
	get: return state._journey_load_origin
	set(value): state._journey_load_origin = value
var _journey_load_focus: Control:
	get: return state._journey_load_focus
	set(value): state._journey_load_focus = value
var _journey_cancel_button: Button:
	get: return state._journey_cancel_button
	set(value): state._journey_cancel_button = value
var _journey_return_pending: Dictionary:
	get: return state._journey_return_pending
	set(value): state._journey_return_pending = value
var _journey_return_last_id: String:
	get: return state._journey_return_last_id
	set(value): state._journey_return_last_id = value
var _save_slot_notice: Label:
	get: return state._save_slot_notice
	set(value): state._save_slot_notice = value
var _save_durability_notice: Label:
	get: return state._save_durability_notice
	set(value): state._save_durability_notice = value
var _topic_navigation: DialogueTopicNavigation:
	get: return state._topic_navigation
	set(value): state._topic_navigation = value
var _dialogue_view_generation: int:
	get: return state._dialogue_view_generation
	set(value): state._dialogue_view_generation = value
var _evidence_navigation: JournalEvidenceNavigation:
	get: return state._evidence_navigation
	set(value): state._evidence_navigation = value
var _evidence_position_key: String:
	get: return state._evidence_position_key
	set(value): state._evidence_position_key = value
var _evidence_reference_section: String:
	get: return state._evidence_reference_section
	set(value): state._evidence_reference_section = value
var _evidence_reference_entry: String:
	get: return state._evidence_reference_entry
	set(value): state._evidence_reference_entry = value
var _display_metrics: Dictionary:
	get: return state._display_metrics
	set(value): state._display_metrics = value
var _layout_policy: Dictionary:
	get: return state._layout_policy
	set(value): state._layout_policy = value
var _touch_shared_prompt: bool:
	get: return state._touch_shared_prompt
	set(value): state._touch_shared_prompt = value
var _layout_pending: bool:
	get: return state._layout_pending
	set(value): state._layout_pending = value
var _layout_applying: bool:
	get: return state._layout_applying
	set(value): state._layout_applying = value
var _layout_generation: int:
	get: return state._layout_generation
	set(value): state._layout_generation = value
var _dialogue_header: HBoxContainer:
	get: return state._dialogue_header
	set(value): state._dialogue_header = value
var _dialogue_back_button: Button:
	get: return state._dialogue_back_button
	set(value): state._dialogue_back_button = value
var _dialogue_body_scroll: ScrollContainer:
	get: return state._dialogue_body_scroll
	set(value): state._dialogue_body_scroll = value
var _dialogue_body: VBoxContainer:
	get: return state._dialogue_body
	set(value): state._dialogue_body = value
var _inventory_root: VBoxContainer:
	get: return state._inventory_root
	set(value): state._inventory_root = value
var _inventory_columns: HBoxContainer:
	get: return state._inventory_columns
	set(value): state._inventory_columns = value
var _journal_column: VBoxContainer:
	get: return state._journal_column
	set(value): state._journal_column = value
var _journal_actions_scroll: ScrollContainer:
	get: return state._journal_actions_scroll
	set(value): state._journal_actions_scroll = value
var _preparation_actions_scroll: ScrollContainer:
	get: return state._preparation_actions_scroll
	set(value): state._preparation_actions_scroll = value
var _inventory_footer: GridContainer:
	get: return state._inventory_footer
	set(value): state._inventory_footer = value
var _inventory_read_button: Button:
	get: return state._inventory_read_button
	set(value): state._inventory_read_button = value
var _inventory_entries_button: Button:
	get: return state._inventory_entries_button
	set(value): state._inventory_entries_button = value
var _inventory_close_button: Button:
	get: return state._inventory_close_button
	set(value): state._inventory_close_button = value
var _inventory_panes: Dictionary:
	get: return state._inventory_panes
	set(value): state._inventory_panes = value
var _inventory_pane_states: Dictionary:
	get: return state._inventory_pane_states
	set(value): state._inventory_pane_states = value
var _menu_frame: Control:
	get: return state._menu_frame
	set(value): state._menu_frame = value
var _menu_shell: HBoxContainer:
	get: return state._menu_shell
	set(value): state._menu_shell = value
var _menu_title_stack: VBoxContainer:
	get: return state._menu_title_stack
	set(value): state._menu_title_stack = value
var _menu_title_label: Label:
	get: return state._menu_title_label
	set(value): state._menu_title_label = value
var _menu_title_spacer: Control:
	get: return state._menu_title_spacer
	set(value): state._menu_title_spacer = value
var _menu_panel: PanelContainer:
	get: return state._menu_panel
	set(value): state._menu_panel = value
var _menu_scroll: ScrollContainer:
	get: return state._menu_scroll
	set(value): state._menu_scroll = value
var _menu_content: VBoxContainer:
	get: return state._menu_content
	set(value): state._menu_content = value
var _menu_footer: HBoxContainer:
	get: return state._menu_footer
	set(value): state._menu_footer = value
var _menu_back_button: Button:
	get: return state._menu_back_button
	set(value): state._menu_back_button = value
var _loading_card: PanelContainer:
	get: return state._loading_card
	set(value): state._loading_card = value
var _touch_layout_reason: String:
	get: return state._touch_layout_reason
	set(value): state._touch_layout_reason = value
var _touch_reason_label: Label:
	get: return state._touch_reason_label
	set(value): state._touch_reason_label = value
var _hart_emblem: Control:
	get: return state._hart_emblem
	set(value): state._hart_emblem = value
var _navigation_dial: Control:
	get: return state._navigation_dial
	set(value): state._navigation_dial = value
var _world_clock_label: Label:
	get: return state._world_clock_label
	set(value): state._world_clock_label = value
var _world_clock_text: String:
	get: return state._world_clock_text
	set(value): state._world_clock_text = value
var _quick_slots: Dictionary:
	get: return state._quick_slots
	set(value): state._quick_slots = value
var _quick_bindings: Dictionary:
	get: return state._quick_bindings
	set(value): state._quick_bindings = value
var _quick_icons: Dictionary:
	get: return state._quick_icons
	set(value): state._quick_icons = value
var _gameplay_bindings: Label:
	get: return state._gameplay_bindings
	set(value): state._gameplay_bindings = value
var _quest_rule: ColorRect:
	get: return state._quest_rule
	set(value): state._quest_rule = value
var _quest_marker: Label:
	get: return state._quest_marker
	set(value): state._quest_marker = value
var _pointer_pause_button: Button:
	get: return state._pointer_pause_button
	set(value): state._pointer_pause_button = value
var _compact_menu_title: Label:
	get: return state._compact_menu_title
	set(value): state._compact_menu_title = value
var _game_owner: Node:
	get: return state._game_owner
	set(value): state._game_owner = value
var _save_manager: Node:
	get: return state._save_manager
	set(value): state._save_manager = value
var _ambient_panel: PanelContainer:
	get: return state._ambient_panel
	set(value): state._ambient_panel = value
var _ambient_words: Label:
	get: return state._ambient_words
	set(value): state._ambient_words = value
var _ambient_owner: int:
	get: return state._ambient_owner
	set(value): state._ambient_owner = value
var _ambient_remaining: float:
	get: return state._ambient_remaining
	set(value): state._ambient_remaining = value
var _honor_source: Node:
	get: return state._honor_source
	set(value): state._honor_source = value
var _menu_frame_box: VBoxContainer:
	get: return state._menu_frame_box
	set(value): state._menu_frame_box = value
var _settings_source: Node:
	get: return state._settings_source
	set(value): state._settings_source = value
func set_runtime_services(owner: Node, saves: Node) -> void: view.set_runtime_services(owner, saves)
func initialize_view() -> void: view._ready()
func prepare_gameplay_ui() -> void: view.prepare_gameplay_ui()
func advance_view(delta: float) -> void: view._process(delta)
func _update_process_policy() -> void: view._update_process_policy()
func _build_ambient_subtitles() -> void: view._build_ambient_subtitles()
func ambient_subtitle_available(owner_id: int) -> bool: return view.ambient_subtitle_available(owner_id)
func show_ambient_subtitle(owner_id: int, speaker: String, words: String, duration: float) -> bool: return view.show_ambient_subtitle(owner_id, speaker, words, duration)
func clear_ambient_subtitle(owner_id: int) -> void: view.clear_ambient_subtitle(owner_id)
func show_opening_scene_skip(skip: Callable) -> void: view.show_opening_scene_skip(skip)
func hide_opening_scene_skip() -> void: view.hide_opening_scene_skip()
func _on_honor_changed(entry: Dictionary) -> void: view._on_honor_changed(entry)
func _gameplay_surface_blocked() -> bool: return view._gameplay_surface_blocked()
func _on_hud_surface_visibility_changed() -> void: view._on_hud_surface_visibility_changed()
func _draw_resource_attention(seconds: float = 4.0) -> void: view._draw_resource_attention(seconds)
func _refresh_resource_attention() -> void: view._refresh_resource_attention()
func set_journey_models(models: Dictionary) -> void: view.set_journey_models(models)
func _refresh_journey_card() -> void: view._refresh_journey_card()
func _set_journey_card_text(text: String) -> void: view._set_journey_card_text(text)
func _show_journey_card(kind: String) -> void: view._show_journey_card(kind)
func _add_journey_load_button(box: VBoxContainer, label: String, model: Dictionary, key: String) -> Button: return view._add_journey_load_button(box, label, model, key)
func _request_journey_selection(key: String) -> void: view._request_journey_selection(key)
func _update_journey_load_button(button: Button, model: Dictionary, label: String) -> void: view._update_journey_load_button(button, model, label)
func _add_journey_recovery_options(box: VBoxContainer, model: Dictionary) -> void: view._add_journey_recovery_options(box, model)
func begin_journey_load(model: Dictionary) -> void: view.begin_journey_load(model)
func end_journey_load(success: bool, reason: String = "") -> void: view.end_journey_load(success, reason)
func _cancel_journey_load() -> void: view._cancel_journey_load()
func set_journey_load_applying(message: String = "Returning to the recorded journey…\nPlacing Kael on the road.") -> void: view.set_journey_load_applying(message)
func update_journey_load_progress(zone_id: String, fraction: float, phase: String = "Loading destination content...") -> void: view.update_journey_load_progress(zone_id, fraction, phase)
func present_journey_return(model: Dictionary) -> void: view.present_journey_return(model)
func _present_pending_journey_return() -> void: view._present_pending_journey_return()
func clear_journey_transients(new_timeline: bool) -> void: view.clear_journey_transients(new_timeline)
func show_main_menu() -> void: view.show_main_menu()
func show_startup_loading(message: String = "Preparing the road...", fraction: float = -1.0, failed: bool = false) -> void: view.show_startup_loading(message, fraction, failed)
func set_new_game_ready(value: bool) -> void: view.set_new_game_ready(value)
func set_new_game_status(text: String) -> void: view.set_new_game_status(text)
func set_opening_preparation(state: String, message: String, progress: float = -1.0, requested: bool = false) -> void: view.set_opening_preparation(state, message, progress, requested)
func _add_opening_progress(box: VBoxContainer) -> void: view._add_opening_progress(box)
func set_boot_shell_cover_active(_active: bool) -> void: view.set_boot_shell_cover_active(_active)
func show_launch_screen() -> void: view.show_launch_screen()
func set_touch_layout_reason(reason: String) -> void: view.set_touch_layout_reason(reason)
func show_pause_menu() -> void: view.show_pause_menu()
func show_companion_commands(travel: Dictionary) -> void: view.show_companion_commands(travel)
func show_touch_actions(weapon_name: String, drawn: bool) -> void: view.show_touch_actions(weapon_name, drawn)
func _item_short_name(id: String) -> String: return view._item_short_name(id)
func show_settings_menu(back_target: String = "pause", requested_page: int = -1) -> void: view.show_settings_menu(back_target, requested_page)
func _settings_entries(s: Dictionary) -> Array: return view._settings_entries(s)
func show_controls_menu(back_target: String = "main") -> void: view.show_controls_menu(back_target)
func show_remap_menu(back_target: String = "main", requested_page: int = -1) -> void: view.show_remap_menu(back_target, requested_page)
func _begin_remap(action: String) -> void: view._begin_remap(action)
func _reset_bindings() -> void: view._reset_bindings()
func _binding_display(action: String) -> String: return view._binding_display(action)
func _return_from_remap() -> void: view._return_from_remap()
func show_credits_menu() -> void: view.show_credits_menu()
func show_exit_notice() -> void: view.show_exit_notice()
func hide_menus() -> void: view.hide_menus()
func show_loading(text: String = "Preparing Greyfen...") -> void: view.show_loading(text)
func arm_loading(text: String = "Following the road...") -> void: view.arm_loading(text)
func hide_loading() -> void: view.hide_loading()
func _build_loading_layer() -> void: view._build_loading_layer()
func _set_internal_canvas(_requested_size: Vector2i) -> void: view._set_internal_canvas(_requested_size)
func update_health(current: float, maximum: float) -> void: view.update_health(current, maximum)
func update_stamina(current: float, maximum: float) -> void: view.update_stamina(current, maximum)
func update_progression(model: Dictionary) -> void: view.update_progression(model)
func show_enemy(name: String, current: float, maximum: float) -> void: view.show_enemy(name, current, maximum)
func hide_enemy() -> void: view.hide_enemy()
func set_target_lock_status(enemy_name: String, distance: float) -> void: view.set_target_lock_status(enemy_name, distance)
func clear_target_lock_status() -> void: view.clear_target_lock_status()
func set_prompt(text: String) -> void: view.set_prompt(text)
func set_interaction_prompt(model: Dictionary) -> void: view.set_interaction_prompt(model)
func get_interaction_prompt_model() -> Dictionary: return view.get_interaction_prompt_model()
func set_tracker(text: String) -> void: view.set_tracker(text)
func set_navigation_model(model: Dictionary) -> void: view.set_navigation_model(model)
func _refresh_story_focus() -> void: view._refresh_story_focus()
func _fit_tracker_height() -> void: view._fit_tracker_height()
func set_compass(text: String) -> void: view.set_compass(text)
func toast(text: String, seconds: float = 2.15) -> void: view.toast(text, seconds)
func post_notice(text: String, category: String = "info", duration: float = 3.0, dedupe_key: String = "") -> void: view.post_notice(text, category, duration, dedupe_key)
func _advance_notices(delta: float) -> void: view._advance_notices(delta)
func _present_notice() -> void: view._present_notice()
func set_toasts_suppressed(suppressed: bool) -> void: view.set_toasts_suppressed(suppressed)
func set_guidance_hint(text: String, seconds: float = 4.5) -> void: view.set_guidance_hint(text, seconds)
func show_status_cue(text: String, kind: String = "neutral") -> void: view.show_status_cue(text, kind)
func update_equipment(potions: int, bombs: int, oil_name: String, arrow_count: int = -1, arrow_type: String = "Standard", weapon_name: String = "Steel", remedy_id: String = "redroot_potion", tool_id: String = "ash_bomb", oil_seconds: int = -1) -> void: view.update_equipment(potions, bombs, oil_name, arrow_count, arrow_type, weapon_name, remedy_id, tool_id, oil_seconds)
func _set_quick_motif(slot: String, motif: String) -> void: view._set_quick_motif(slot, motif)
func mark_stamina_exhausted() -> void: view.mark_stamina_exhausted()
func get_dialogue_topic_seen_keys() -> Array[String]: return view.get_dialogue_topic_seen_keys()
func _has_optional_topics() -> bool: return view._has_optional_topics()
func _open_dialogue_topics() -> void: view._open_dialogue_topics()
func _render_dialogue_topic_list() -> void: view._render_dialogue_topic_list()
func _show_dialogue_topic_summary(row: Dictionary) -> void: view._show_dialogue_topic_summary(row)
func _request_dialogue_topic(row: Dictionary) -> void: view._request_dialogue_topic(row)
func show_dialogue_topic(scene: Dictionary) -> void: view.show_dialogue_topic(scene)
func dialogue_topic_unavailable(context_id: String) -> void: view.dialogue_topic_unavailable(context_id)
func _return_to_primary_dialogue() -> void: view._return_to_primary_dialogue()
func _restore_primary_topic_return(generation: int) -> void: await view._restore_primary_topic_return(generation)
func _restore_topic_list_reading(generation: int) -> void: await view._restore_topic_list_reading(generation)
func _add_topic_navigation_button(label: String, key: String, callback: Callable) -> Button: return view._add_topic_navigation_button(label, key, callback)
func show_dialogue(data: Dictionary) -> void: view.show_dialogue(data)
func _reveal_subtitle() -> void: view._reveal_subtitle()
func _render_dialogue_page(record_history: bool = true, announce_page: bool = true, focus_page: bool = true) -> void: view._render_dialogue_page(record_history, announce_page, focus_page)
func _show_decision_detail(model: Dictionary) -> void: view._show_decision_detail(model)
func _focus_decision_reader(page_index: int, generation: int = -1) -> void: await view._focus_decision_reader(page_index, generation)
func show_decision_result(receipt: Dictionary) -> void: view.show_decision_result(receipt)
func set_preparation_context(snapshot: Dictionary) -> void: view.set_preparation_context(snapshot)
func set_preparation_services(crafting) -> void: view.set_preparation_services(crafting)
func preparation_screen_key() -> String: return view.preparation_screen_key()
func show_preparation_result(result: Dictionary) -> bool: return view.show_preparation_result(result)
func _present_preparation_notice() -> void: view._present_preparation_notice()
func _prepare_inventory_surface(preparation: bool) -> void: view._prepare_inventory_surface(preparation)
func _journal_source_key(source) -> String: return view._journal_source_key(source)
func _journal_source_changed(id: int) -> void: view._journal_source_changed(id)
func _journal_model(key: String, sources: Array, build: Callable) -> Variant: return view._journal_model(key, sources, build)
func _recycle_journal_buttons(parent: Node) -> void: view._recycle_journal_buttons(parent)
func show_inventory(inventory, quests, story_state = null, progression = null, requested_section: String = "") -> void: view.show_inventory(inventory, quests, story_state, progression, requested_section)
func _journal_zone_id() -> String: return view._journal_zone_id()
func _journal_entry_from_sections(sections: Array, section_id: String, entry_id: String) -> Dictionary: return view._journal_entry_from_sections(sections, section_id, entry_id)
func _build_evidence_content(quests, state, zone_id: String, sections: Array) -> void: view._build_evidence_content(quests, state, zone_id, sections)
func _evidence_detail_text(detail: Dictionary) -> String: return view._evidence_detail_text(detail)
func _add_evidence_return_controls() -> void: view._add_evidence_return_controls()
func _select_evidence_filter(filter_id: String) -> void: view._select_evidence_filter(filter_id)
func _select_evidence_entry(entry_id: String) -> void: view._select_evidence_entry(entry_id)
func _show_evidence_list() -> void: view._show_evidence_list()
func _refresh_evidence_journal(section_id: String) -> void: view._refresh_evidence_journal(section_id)
func _resolve_evidence_reference(link: Dictionary, sections: Array = []) -> Dictionary: return view._resolve_evidence_reference(link, sections)
func _open_evidence_reference(link: Dictionary) -> void: view._open_evidence_reference(link)
func _back_from_evidence_reading() -> bool: return view._back_from_evidence_reading()
func _evidence_focus_target() -> String: return view._evidence_focus_target()
func _handle_evidence_direction(event: InputEvent) -> bool: return view._handle_evidence_direction(event)
func _handle_compact_journal_direction(event: InputEvent) -> bool: return view._handle_compact_journal_direction(event)
func _build_growth_content(progression) -> void: view._build_growth_content(progression)
func _build_preparation_content(inventory, progression, story_state, quests, notes: String) -> void: view._build_preparation_content(inventory, progression, story_state, quests, notes)
func _build_kit_controls(inventory) -> void: view._build_kit_controls(inventory)
func _select_preparation_entry(kind: String, id: String) -> void: view._select_preparation_entry(kind, id)
func _open_journal_section(section_id: String) -> void: view._open_journal_section(section_id)
func show_vendor(vendor_id: String, vendor_service, inventory, quests = null, story_state = null) -> void: view.show_vendor(vendor_id, vendor_service, inventory, quests, story_state)
func _add_preparation_heading(text: String) -> void: view._add_preparation_heading(text)
func _preparation_button(text: String, key: String, parent: Container, available: bool = true) -> Button: return view._preparation_button(text, key, parent, available)
func _add_preparation_close() -> void: view._add_preparation_close()
func show_ending(title: String, body: String) -> void: view.show_ending(title, body)
func show_death_screen(body: String) -> void: view.show_death_screen(body)
func _build_hud() -> void: view._build_hud()
func set_world_navigation(snapshot: Dictionary) -> void: view.set_world_navigation(snapshot)
func set_world_clock(minutes: float, phase: String, _day_count: int = 0) -> void: view.set_world_clock(minutes, phase, _day_count)
func _hud_label(parent: Node, node_name: String, font_size: int) -> Label: return view._hud_label(parent, node_name, font_size)
func _hud_text_height(label: Label, reserved_lines: int = -1) -> float: return view._hud_text_height(label, reserved_lines)
func set_display_metrics(metrics: Dictionary) -> void: view.set_display_metrics(metrics)
func _on_viewport_resized() -> void: view._on_viewport_resized()
func _apply_hud_layout() -> void: view._apply_hud_layout()
func _queue_responsive_layout() -> void: view._queue_responsive_layout()
func _responsive_surface_key() -> String: return view._responsive_surface_key()
func _apply_responsive_layout() -> void: view._apply_responsive_layout()
func _restore_reflow_state(snapshot: Dictionary, generation: int, surface_key: String) -> void: await view._restore_reflow_state(snapshot, generation, surface_key)
func _reveal_menu_focus() -> void: view._reveal_menu_focus()
func _apply_responsive_typography(node: Node, fonts: Dictionary, button_height: float, unit: float) -> void: view._apply_responsive_typography(node, fonts, button_height, unit)
func _set_responsive_font(control: Control, name: StringName, value: int) -> void: view._set_responsive_font(control, name, value)
func _set_responsive_panel_padding(panel: PanelContainer, padding: float) -> void: view._set_responsive_panel_padding(panel, padding)
func _apply_responsive_journal(policy: Dictionary) -> void: view._apply_responsive_journal(policy)
func _set_inventory_pane(pane: String, focus_content: bool = false) -> void: view._set_inventory_pane(pane, focus_content)
func _focus_inventory_pane(pane: String, generation: int) -> void: await view._focus_inventory_pane(pane, generation)
func _inventory_pane_state_key(pane: String) -> String: return view._inventory_pane_state_key(pane)
func _close_inventory() -> void: view._close_inventory()
func _wire_responsive_inventory_focus() -> void: view._wire_responsive_inventory_focus()
func _apply_responsive_dialogue(policy: Dictionary) -> void: view._apply_responsive_dialogue(policy)
func _apply_responsive_menu(policy: Dictionary) -> void: view._apply_responsive_menu(policy)
func _apply_responsive_loading(policy: Dictionary) -> void: view._apply_responsive_loading(policy)
func _apply_responsive_gameplay(policy: Dictionary) -> void: view._apply_responsive_gameplay(policy)
func _apply_touch_gameplay_regions(model: Dictionary, unit: float) -> void: view._apply_touch_gameplay_regions(model, unit)
func _refresh_touch_message_visibility() -> void: view._refresh_touch_message_visibility()
func _build_menu_layer() -> void: view._build_menu_layer()
func _build_dialogue() -> void: view._build_dialogue()
func _build_inventory() -> void: view._build_inventory()
func _labeled_bar(label_text: String, bar: ProgressBar, value_label: Label) -> HBoxContainer: return view._labeled_bar(label_text, bar, value_label)
func _clear_menu() -> void: view._clear_menu()
func _menu_box(title: String, subtitle: String = "", omen_text: String = "", _height_limit: float = 760.0) -> VBoxContainer: return view._menu_box(title, subtitle, omen_text, _height_limit)
func _build_menu_background() -> void: view._build_menu_background()
func _add_menu_button(box: VBoxContainer, text: String, callback: Callable, disabled: bool = false, focus_key: String = "") -> Button: return view._add_menu_button(box, text, callback, disabled, focus_key)
func _activate_menu_action(callback: Callable, screen_generation: int) -> void: view._activate_menu_action(callback, screen_generation)
func _add_menu_text(box: VBoxContainer, text: String) -> Label: return view._add_menu_text(box, text)
func _menu_viewport_size() -> Vector2: return view._menu_viewport_size()
func _current_settings() -> Dictionary: return view._current_settings()
func set_input_source(source: Node) -> void: view.set_input_source(source)
func set_gamepad_profile(profile: Dictionary) -> void: view.set_gamepad_profile(profile)
func restore_input_focus() -> void: view.restore_input_focus()
func _set_ui_pointer(context: String = "menu") -> void: view._set_ui_pointer(context)
func _set_gameplay_pointer() -> void: view._set_gameplay_pointer()
func apply_accessibility(current: Dictionary) -> void: view.apply_accessibility(current)
func set_input_device(device: String) -> void: view.set_input_device(device)
func _action_label(action: String) -> String: return view._action_label(action)
func _format_input_text(text: String) -> String: return view._format_input_text(text)
func _controller_sensitivity_label(value: float) -> String: return view._controller_sensitivity_label(value)
func _focus_after_rebuild(container: Node) -> void: await view._focus_after_rebuild(container)
func _focus_first_enabled(container: Node) -> void: view._focus_first_enabled(container)
func handle_input(event: InputEvent) -> void: view._input(event)
func _cancel_dialogue_press() -> void: view._cancel_dialogue_press()
func _dialogue_pointer_hits(button: Button, point: Vector2) -> bool: return view._dialogue_pointer_hits(button, point)
func _capture_remap_input(event: InputEvent) -> bool: return view._capture_remap_input(event)
func handle_unhandled_input(event: InputEvent) -> void: view._unhandled_input(event)
func request_back() -> bool: return view.request_back()
func _on_off(value: bool) -> String: return view._on_off(value)
func _shadow_label(value: int) -> String: return view._shadow_label(value)
func _sensitivity_label(value: float) -> String: return view._sensitivity_label(value)
func _has_continue_save() -> bool: return view._has_continue_save()
func _save_status_text() -> String: return view._save_status_text()
func _return_from_controls() -> void: view._return_from_controls()
func _add_dialogue_close() -> void: view._add_dialogue_close()
func _close_dialogue_surface(resume_world: bool = true) -> bool: return view._close_dialogue_surface(resume_world)
func _focused_dialogue_button() -> Button: return view._focused_dialogue_button()
func _apply_theme() -> void: view._apply_theme()
func _apply_hud_visual_identity() -> void: view._apply_hud_visual_identity()
func _apply_hud_visual_colors() -> void: view._apply_hud_visual_colors()
func _hud_text_labels() -> Array[Label]: return view._hud_text_labels()
func _format_tracker_text(text: String) -> String: return view._format_tracker_text(text)
func _objective_with_verb(objective: String) -> String: return view._objective_with_verb(objective)
func _flash_bar(bar: ProgressBar, color: Color) -> void: view._flash_bar(bar, color)
func _status_color(kind: String) -> Color: return view._status_color(kind)
func _style_panel(panel: PanelContainer, bg_color: Color, border_color: Color) -> void: view._style_panel(panel, bg_color, border_color)
func _add_hud_accent(parent: Control, position: Vector2, size: Vector2) -> void: view._add_hud_accent(parent, position, size)
func _capture_inventory_state() -> void: view._capture_inventory_state()
func _restore_inventory_state(key: String, generation: int) -> void: await view._restore_inventory_state(key, generation)
func _collect_inventory_focus(node: Node, controls: Array[Control]) -> void: view._collect_inventory_focus(node, controls)
func _screen_key() -> String: return view._screen_key()
func _screen_parent() -> String: return view._screen_parent()
func _capture_menu_state() -> void: view._capture_menu_state()
func _restore_menu_state(key: String, generation: int) -> void: await view._restore_menu_state(key, generation)
func _register_field(control: Control, field_key: String, fallback: String) -> void: view._register_field(control, field_key, fallback)
func _return_to_parent() -> void: view._return_to_parent()
func _open_screen(key: String) -> void: view._open_screen(key)
func get_current_dialogue_page() -> Dictionary: return view.get_current_dialogue_page()
func save_text_history() -> Array: return view.save_text_history()
func load_text_history(raw: Variant) -> void: view.load_text_history(raw)
func _save_service(): return view._save_service()
func _on_save_durability_changed(state: String, detail: String) -> void: view._on_save_durability_changed(state, detail)
func _on_save_operation_finished(slot_id: String, operation: String, success: bool, text: String) -> void: view._on_save_operation_finished(slot_id, operation, success, text)
func show_save_library(back_target: String = "pause", requested_page: int = 0) -> void: view.show_save_library(back_target, requested_page)
func _refresh_save_library() -> void: view._refresh_save_library()
func _flush_library_refresh() -> void: view._flush_library_refresh()
func show_save_slot(slot_id: String) -> void: view.show_save_slot(slot_id)
func show_save_import() -> void: view.show_save_import()
func show_chapter_replays() -> void: view.show_chapter_replays()
func _return_from_library() -> void: view._return_from_library()
func show_text_history(back_target: String = "pause") -> void: view.show_text_history(back_target)
func _return_from_history() -> void: view._return_from_history()
func _capture_dialogue_reading_state() -> void: view._capture_dialogue_reading_state()
func _restore_dialogue_reading_state() -> void: view._restore_dialogue_reading_state()
func _dialogue_focus_controls() -> Array[Control]: return view._dialogue_focus_controls()
func _show_journal_art(quests, state) -> void: view._show_journal_art(quests, state)
func show_problem_report(back_target: String = "pause") -> void: view.show_problem_report(back_target)
func _download_problem_report(description: String) -> void: view._download_problem_report(description)
func _style_button(button: Button) -> void: view._style_button(button)
func _style_menu_action(button: Button) -> void: view._style_menu_action(button)
func _refresh_menu_action(button: Button) -> void: view._refresh_menu_action(button)
func _hide_native_button_text(button: Button) -> void: view._hide_native_button_text(button)
