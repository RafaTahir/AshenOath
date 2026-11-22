extends CanvasLayer
## Typed presentation API retained for runtime and save-facing callers.
## No view construction, input handling or gameplay logic lives here.

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
var state := HudState.new()
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
