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
signal vendor_purchase_requested(vendor_id: String, item_id: String, quantity: int)
signal upgrade_requested(upgrade_id: String)
signal dialogue_closed
signal dialogue_page_changed(speaker: String, speaker_id: String, page_index: int, total_pages: int)
signal menu_hovered
signal menu_clicked

const MENU_BUILD_LABEL = "ASHEN OATH · THE ROAD BETWEEN CROWNS"
const MENU_SIZE = Vector2(1920.0, 1080.0)
const GAMEPLAY_SIZE = Vector2i(1280, 720)
const SAVE_PATH = "user://ashen_oath_save.json"
const AUTOSAVE_PATH = "user://ashen_oath_autosave.json"
const CHECKPOINT_PATH = "user://ashen_oath_checkpoint.json"
const StoryJournalPresenter = preload("res://scripts/story_journal.gd")
const DialogueHistory = preload("res://scripts/dialogue_history.gd")
const SourceText = preload("res://scripts/source_text.gd")
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

func _ready() -> void:
	_build_hud()
	_build_menu_layer()
	_build_dialogue()
	_build_inventory()
	_build_loading_layer()
	_apply_theme()
	apply_accessibility(_current_settings())
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_hud_layout()
	_update_process_policy()

func _process(delta: float) -> void:
	if health_bar == null:
		return
	if loading_armed and loading_layer != null and not loading_layer.visible:
		loading_elapsed += delta
		if loading_elapsed >= 0.75:
			loading_layer.visible = true
			_update_process_policy()
	var health_ratio = last_health / max(last_health_max, 1.0)
	if health_ratio <= 0.28 and not reduced_motion and not flash_reduction:
		var pulse = 0.86 + 0.14 * sin(Time.get_ticks_msec() * 0.008)
		health_bar.modulate = Color(1.0, pulse, pulse, 1.0)
	elif health_bar.modulate != Color.WHITE:
		health_bar.modulate = Color.WHITE

func _update_process_policy() -> void:
	if health_bar == null:
		return
	var pulse_active := last_health / maxf(last_health_max, 1.0) <= 0.28 and not reduced_motion and not flash_reduction
	var loading_delay_active := loading_armed and loading_layer != null and not loading_layer.visible
	if not pulse_active and health_bar.modulate != Color.WHITE:
		health_bar.modulate = Color.WHITE
	set_process(pulse_active or loading_delay_active)

func show_main_menu() -> void:
	active_menu = "main"
	_set_internal_canvas(Vector2i(MENU_SIZE))
	_set_ui_pointer("menu")
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box("ASHEN OATH", "The Road Between Crowns", "contracts | curses | consequences", 680.0)
	_add_menu_text(box, "Greyfen waits under ash and oath-light.")
	_add_menu_button(box, "New Game", func(): new_game_requested.emit())
	new_game_status_label = _add_menu_text(box, new_game_status)
	_add_menu_button(box, "Continue", func(): continue_requested.emit(), not _has_continue_save())
	_add_menu_button(box, "Saved Journeys", func(): show_save_library("main"))
	_add_menu_text(box, _save_status_text())
	_add_menu_button(box, "Controls", func(): show_controls_menu("main"))
	_add_menu_button(box, "Settings", func(): show_settings_menu("main"))
	_add_menu_button(box, "Credits", func(): show_credits_menu())
	_add_menu_button(box, "Quit", func(): quit_requested.emit())
	call_deferred("_focus_first_enabled", menu_layer)

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
		call_deferred("_focus_first_enabled", menu_layer)

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

func show_pause_menu() -> void:
	active_menu = "pause"
	_set_internal_canvas(Vector2i(MENU_SIZE))
	_set_ui_pointer("pause")
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box("Paused", "", "the road holds its breath")
	_add_menu_button(box, "Resume", func(): resume_requested.emit())
	_add_menu_button(box, "Quick Save", func(): save_requested.emit())
	_add_menu_button(box, "Saved Journeys", func(): show_save_library("pause"))
	_add_menu_button(box, "Journal & Preparation", func(): journal_requested.emit())
	_add_menu_button(box, "Conversation History", func(): show_text_history("pause"))
	_add_menu_button(box, "Settings", func(): show_settings_menu())
	_add_menu_button(box, "Controls", func(): show_controls_menu("pause"))
	_add_menu_button(box, "Main Menu", func(): show_main_menu())

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
			)
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
		{"label": "Subtitle Background  %d%%" % int(round(float(s.get("subtitle_background_opacity", 0.92)) * 100.0)), "action": "subtitle_background_opacity"},
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
	if input_device == "gamepad":
		_add_menu_text(box, "Left Stick move | Right Stick look | D-Pad Up/Down zoom\nL3 run | B dodge | Y jump | X switch sword/bow\nRB light attack | RT heavy attack / fire bow | LT aim bow\nSword: hold LT Oathfire | Tap/Hold LB parry or block | A interact\nBow: D-Pad Up cycle arrows | D-Pad Left potion | D-Pad Right bomb | View journal | Menu pause")
	elif input_device == "touch":
		_add_menu_text(box, "Left thumb move | Drag right side to look\nStrike / Heavy attack | Dodge | Jump\nHold Guard to block or parry | Hold Oath to charge Oathfire\nUse interacts | Potion heals | Pause opens the menu\nLandscape orientation is required during gameplay")
	else:
		_add_menu_text(box, "WASD move | Mouse look | Wheel zoom | Page Up/Down zoom\nShift run | Space dodge | X jump | 1 sword | 2 bow\nLeft mouse light attack / fire bow | Right mouse heavy / aim bow\nHold C Oathfire Beam | Tap Q parry | Hold Q block | E interact\nZ cycle arrows | R potion | F bomb | Tab inventory | Esc pause")
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
		"weapon_cycle", "weapon_sword", "weapon_bow", "aim_bow", "fire_bow", "cycle_arrow", "target_lock", "target_next", "target_previous"]
	var page_count := maxi(1, ceili(float(actions.size()) / 6.0))
	remap_page = clampi(remap_page, 0, page_count - 1)
	_add_menu_text(box, "Page %d of %d" % [remap_page + 1, page_count])
	var first_entry := remap_page * 6
	var last_entry := mini(first_entry + 6, actions.size())
	for index in range(first_entry, last_entry):
		var action := str(actions[index])
		var label := action.replace("_", " ").capitalize()
		var binding := _binding_display(action)
		_add_menu_button(box, "%s     %s" % [label, binding], func(selected = action): _begin_remap(selected))
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
	if remap_back_target == "pause":
		show_pause_menu()
	else:
		show_controls_menu(remap_back_target)

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
	_add_menu_button(box, "Report a Problem", func(): show_problem_report("main"))
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
		loading_message.text = text
	loading_layer.visible = false
	_update_process_policy()

func hide_loading() -> void:
	loading_armed = false
	loading_elapsed = 0.0
	if loading_layer != null:
		loading_layer.visible = false
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
	card.name = "RoadCard"
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card.position = Vector2(-210, 34)
	card.size = Vector2(420, 62)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_layer.add_child(card)
	loading_message = Label.new()
	loading_message.name = "Message"
	loading_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading_message.add_theme_font_size_override("font_size", 18)
	loading_message.add_theme_color_override("font_color", Color(0.88, 0.76, 0.54))
	loading_message.text = "Following the road..."
	card.add_child(loading_message)

func _set_internal_canvas(size: Vector2i) -> void:
	var window := get_window()
	if window == null:
		return
	# UI coordinates must not reallocate the shared 3D render target. Preserve
	# the desktop's authored menu layout through its Control transform instead.
	if window.content_scale_size != GAMEPLAY_SIZE:
		window.content_scale_size = GAMEPLAY_SIZE
	if menu_layer != null:
		var layout_size := GAMEPLAY_SIZE if OS.has_feature("web") else size
		menu_layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		menu_layer.size = Vector2(layout_size)
		menu_layer.scale = Vector2(GAMEPLAY_SIZE) / Vector2(layout_size)

func update_health(current: float, maximum: float) -> void:
	var previous = last_health
	last_health = current
	last_health_max = maximum
	health_bar.max_value = maximum
	health_bar.value = current
	health_value_label.text = "%d / %d" % [int(round(current)), int(round(maximum))]
	if current < previous:
		_flash_bar(health_bar, Color(1.0, 0.32, 0.22))
		show_status_cue("Blood lost", "hurt")
	elif current > previous:
		_flash_bar(health_bar, Color(0.78, 0.24, 0.16))
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

func show_enemy(name: String, current: float, maximum: float) -> void:
	enemy_label.text = "Target: %s" % name
	enemy_bar.max_value = maximum
	enemy_bar.value = current
	enemy_value_label.text = "%d / %d" % [int(round(max(current, 0.0))), int(round(maximum))]
	enemy_bar.visible = current > 0.0
	enemy_label.visible = current > 0.0
	enemy_value_label.visible = current > 0.0
	if current > 0.0:
		_flash_bar(enemy_bar, Color(0.95, 0.62, 0.22))
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
	target_status_label.text = "LOCKED | %s | %.1fm" % [enemy_name, distance]
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
	prompt_label.visible = raw_prompt != "" and not dialogue_layer.visible

func set_tracker(text: String) -> void:
	tracker_label.text = _format_tracker_text(text)
	_fit_tracker_height.call_deferred()

func _fit_tracker_height() -> void:
	if not is_instance_valid(tracker_label) or not is_instance_valid(tracker_back):
		return
	var text_height := tracker_label.get_line_count() * tracker_label.get_line_height()
	tracker_label.size.y = maxf(56.0, float(text_height) + 16.0)
	tracker_back.size.y = tracker_label.size.y + 14.0
	for accent in tracker_back.get_children():
		if accent is ColorRect:
			accent.size.y = tracker_back.size.y

func set_compass(text: String) -> void:
	compass_label.text = text.replace(" | ", "   •   ")

func toast(text: String, seconds: float = 2.15) -> void:
	if toasts_suppressed or dialogue_layer.visible:
		return
	toast_label.text = text
	toast_label.visible = true
	if toast_tween != null and toast_tween.is_running():
		toast_tween.kill()
	toast_label.modulate = Color(1, 1, 1, 1)
	toast_tween = create_tween()
	toast_tween.tween_interval(clampf(seconds, 2.15, 8.0))
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.25)
	toast_tween.tween_callback(func():
		toast_label.visible = false
		toast_label.modulate = Color(1, 1, 1, 1)
	)

func set_toasts_suppressed(suppressed: bool) -> void:
	toasts_suppressed = suppressed
	if not suppressed or toast_label == null:
		return
	if toast_tween != null and toast_tween.is_running():
		toast_tween.kill()
	toast_label.visible = false
	toast_label.modulate = Color(1, 1, 1, 1)

func set_guidance_hint(text: String, seconds: float = 4.5) -> void:
	raw_hint = text
	hint_label.text = _format_input_text(text)
	hint_label.visible = text != ""
	hint_label.modulate = Color(1, 1, 1, 1)
	if hint_tween != null and hint_tween.is_running():
		hint_tween.kill()
	if text == "":
		return
	hint_tween = create_tween()
	hint_tween.tween_interval(seconds)
	hint_tween.tween_property(hint_label, "modulate:a", 0.0, 0.3)
	hint_tween.tween_callback(func():
		hint_label.visible = false
		hint_label.modulate = Color(1, 1, 1, 1)
	)

func show_status_cue(text: String, kind: String = "neutral") -> void:
	status_label.text = text
	status_label.visible = true
	status_label.modulate = _status_color(kind)
	if status_tween != null and status_tween.is_running():
		status_tween.kill()
	status_tween = create_tween()
	status_tween.tween_interval(1.0)
	status_tween.tween_property(status_label, "modulate:a", 0.0, 0.2)
	status_tween.tween_callback(func():
		status_label.visible = false
		status_label.modulate = Color(1, 1, 1, 1)
	)

func update_equipment(potions: int, bombs: int, oil_name: String, arrow_count: int = -1, arrow_type: String = "Standard") -> void:
	last_potions = potions
	last_bombs = bombs
	last_oil_name = oil_name
	last_arrow_count = arrow_count
	last_arrow_type = arrow_type
	var oil_text = oil_name if oil_name != "" else "No oil"
	var arrow_text := ""
	if arrow_count >= 0:
		arrow_text = "   Bow %s x%d" % [arrow_type, arrow_count]
	# Keep the quick-read compact at 720p; the second line prevents supply text
	# from pushing beyond the vitals column on narrow gameplay viewports.
	equipment_label.text = "%s Redroot x%d   %s Ash Bomb x%d\nOil: %s%s" % [
		_action_label("use_potion"), potions, _action_label("throw_bomb"), bombs, oil_text, arrow_text
	]

func mark_stamina_exhausted() -> void:
	_flash_bar(stamina_bar, Color(1.0, 0.32, 0.16))
	show_status_cue("Stamina spent", "stamina")

func show_dialogue(data: Dictionary) -> void:
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

func _render_dialogue_page() -> void:
	var page = dialogue_pages[dialogue_page_index]
	var page_speaker := str(dialogue_session_data.get("name", "Unknown"))
	var page_speaker_id := ""
	if typeof(page) == TYPE_DICTIONARY:
		page_speaker = str(page.get("speaker", dialogue_session_data.get("name", "Unknown")))
		page_speaker_id = str(page.get("speaker_id", ""))
		dialogue_title.text = page_speaker
		dialogue_text.text = SourceText.localize(str(page.get("text", "...")))
	else:
		dialogue_title.text = page_speaker
		dialogue_text.text = str(page)
	dialogue_title.visible = subtitle_speaker_names
	text_history.record(page_speaker, dialogue_text.get_parsed_text(), "speech", str(page.get("text_id", "")) if typeof(page) == TYPE_DICTIONARY else "")
	if dialogue_page_label != null:
		dialogue_page_label.text = "%02d / %02d" % [dialogue_page_index + 1, dialogue_pages.size()]
	dialogue_page_changed.emit(page_speaker, page_speaker_id, dialogue_page_index, dialogue_pages.size())
	for child in dialogue_actions.get_children():
		dialogue_actions.remove_child(child)
		child.queue_free()
	if dialogue_page_index < dialogue_pages.size()-1:
		var advance := Button.new()
		advance.text = "Continue"
		advance.process_mode = Node.PROCESS_MODE_ALWAYS
		advance.focus_mode = Control.FOCUS_ALL
		advance.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		_style_button(advance)
		advance.pressed.connect(func():
			dialogue_page_index += 1
			_render_dialogue_page()
		)
		dialogue_actions.add_child(advance)
		_focus_after_rebuild(dialogue_actions)
		return
	var actions: Array = dialogue_session_data.get("actions",[])
	for action in actions:
		var committing := str(action.get("type", "")) in ["story_choice", "ending", "final_choice"]
		var preview := StoryJournalPresenter.decision_preview(action) if committing else ""
		if preview != "":
			var stakes := Label.new()
			stakes.text = "On commitment: " + preview
			stakes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stakes.custom_minimum_size = Vector2(720, 0)
			stakes.add_theme_font_size_override("font_size", int(round(18.0 * story_text_scale)))
			stakes.add_theme_constant_override("outline_size", 4 if high_contrast else 2)
			stakes.add_theme_color_override("font_outline_color", Color.BLACK)
			dialogue_actions.add_child(stakes)
		var button = Button.new()
		button.text = ("Commit: " if committing else "") + str(action.get("label", "Continue"))
		button.tooltip_text = preview
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.focus_mode = Control.FOCUS_ALL
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		_style_button(button)
		button.pressed.connect(func(action_data = action):
			if not _close_dialogue_surface():
				return
			var is_commitment := str(action_data.get("type", "")) in ["story_choice", "ending", "final_choice"]
			text_history.record("Kael — committed choice" if is_commitment else "Kael", str(action_data.get("label", "Continue")), "choice" if is_commitment else "question", str(action_data.get("choice_id", "")))
			dialogue_closed.emit()
			action_selected.emit(action_data)
		)
		dialogue_actions.add_child(button)
	if dialogue_choices_scroll != null:
		dialogue_choices_scroll.custom_minimum_size.y = 154.0 if actions.size() > 2 else 96.0
	if actions.is_empty():
		_add_dialogue_close()
	_focus_after_rebuild(dialogue_actions)

func show_inventory(inventory, quests, story_state = null, progression = null) -> void:
	_set_ui_pointer("journal")
	inventory_layer.visible = true
	_show_journal_art(quests, story_state)
	var oil_name = "None"
	if inventory.active_oil != "":
		oil_name = inventory.get_item_name(inventory.active_oil)
	var summary: Dictionary = inventory.get_preparation_summary()
	var text = StoryJournalPresenter.build_from_state(quests, story_state) + "\n\nPREPARATION\nCoin: %d\nBlade Oil: %s\nPotions: %d  Bombs: %d  Traps: %d\n\nPACK\n" % [
		inventory.coin, oil_name, summary.potions, summary.bombs, summary.traps
	]
	for id in inventory.ordered_item_ids():
		var definition: Dictionary = inventory.item_defs.get(id, {})
		text += "- %s x%d — %s\n" % [
			inventory.get_item_name(id),
			int(inventory.items.get(id, 0)),
			str(definition.get("description", ""))
		]
	text += "\nIngredients\n"
	var ingredient_ids: Array = inventory.ingredients.keys()
	ingredient_ids.sort()
	for id in ingredient_ids:
		text += "- %s x%d\n" % [id.capitalize(), int(inventory.ingredients[id])]
	text += "\nRECIPES\n"
	for id in inventory.ordered_item_ids():
		var status: Dictionary = inventory.recipe_status(id)
		var parts: Array[String] = []
		for ingredient in status.required.keys():
			parts.append("%s %d/%d" % [
				str(ingredient).capitalize(),
				int(inventory.ingredients.get(ingredient, 0)),
				int(status.required[ingredient])
			])
		text += "- %s: %s%s\n" % [
			inventory.get_item_name(id),
			", ".join(parts),
			" [READY]" if bool(status.craftable) else ""
		]
	text += "\n\n%s" % quests.get_journal_text()
	text += "\n\nBESTIARY\n"
	text += "Ghoulkin — Fast cursed remains. Parry the lunge; Moon Oil bites deep.\n"
	if quests.is_completed("main_teeth_in_rain") or quests.is_active("main_teeth_in_rain"):
		text += "Bog Wretch — Rot-bound memory given flesh. Ash Bombs break its approach.\n"
	if quests.is_completed("main_blood_under_stone") or quests.is_active("main_blood_under_stone"):
		text += "Gravebound Knight — A disciplined witness. Read the windup; do not trade blows.\n"
	if story_state != null:
		text += _physical_story_journal(story_state)
		text += "\nCONSEQUENCES\n"
		var trust := int(story_state.values.get("anwen_trust", 0))
		var fear := int(story_state.values.get("greyfen_fear", 0))
		var debt := int(story_state.values.get("hart_debt", 0))
		text += "Anwen %s.\n" % ("trusts Kael with what the shrine concealed" if trust > 0 else ("guards her words around Kael" if trust < 0 else "has not decided what Kael will do with the truth"))
		text += "Greyfen %s.\n" % ("is close to panic" if fear >= 4 else ("whispers about the reopened road" if fear > 0 else "still believes its old silence will hold"))
		text += "The White Hart %s.\n" % ("is owed a reckoning" if debt > 1 else ("has felt Kael disturb the covenant" if debt != 0 else "has not yet named its price"))
	if progression != null:
		text += "\n\nPROGRESSION\n%s" % progression.get_summary_text()
	inventory_text.text = text
	for child in craft_buttons.get_children():
		craft_buttons.remove_child(child)
		child.queue_free()
	for id in inventory.ordered_item_ids():
		var button = Button.new()
		var recipe: Dictionary = inventory.recipe_status(id)
		button.text = "Craft %s%s" % [
			inventory.get_item_name(id),
			"" if bool(recipe.craftable) else " — ingredients needed"
		]
		button.disabled = not inventory.can_craft(id)
		_style_button(button)
		button.pressed.connect(func(item_id = id): craft_requested.emit(item_id))
		craft_buttons.add_child(button)
	for id in inventory.ordered_item_ids():
		if int(inventory.items[id]) <= 0:
			continue
		var use_button = Button.new()
		var verb := "Apply" if inventory.get_item_type(id) == "oil" else ("Set" if inventory.get_item_type(id) == "trap" else "Use")
		use_button.text = "%s %s" % [verb, inventory.get_item_name(id)]
		_style_button(use_button)
		use_button.pressed.connect(func(item_id = id): item_use_requested.emit(item_id))
		craft_buttons.add_child(use_button)
	if progression != null:
		for id in progression.ordered_upgrade_ids():
			if not progression.can_unlock(id):
				continue
			var upgrade_button := Button.new()
			upgrade_button.text = "Learn %s — 1 Mark" % progression.definitions[id].get("name", id)
			_style_button(upgrade_button)
			upgrade_button.pressed.connect(func(upgrade_id = id): upgrade_requested.emit(upgrade_id))
			craft_buttons.add_child(upgrade_button)
	var close = Button.new()
	close.text = "Close"
	_style_button(close)
	close.pressed.connect(func():
		dialogue_closed.emit()
		get_tree().paused = false
		hide_menus()
	)
	craft_buttons.add_child(close)
	_focus_after_rebuild(craft_buttons)

func show_vendor(vendor_id: String, vendor_service, inventory, quests = null, story_state = null) -> void:
	_set_ui_pointer("journal")
	inventory_layer.visible = true
	if journal_art != null:
		journal_art.visible = false
	var vendor: Dictionary = vendor_service.get_vendor(vendor_id)
	var vendor_name := str(vendor.get("name", "Vendor"))
	var vendor_subtitle := str(vendor.get("subtitle", "A practical Greyfen exchange."))
	var text := "%s\n%s\n\nCoin: %d\n\nSTOCK\n" % [vendor_name.to_upper(), vendor_subtitle, int(inventory.coin)]
	var stock: Array[Dictionary] = vendor_service.list_stock(vendor_id, inventory, story_state, quests)
	for entry in stock:
		var item_id := str(entry.get("item_id", ""))
		var item_name: String = str(inventory.get_item_name(item_id))
		var owned := int(entry.get("owned", 0))
		var cap := int(entry.get("cap", 999))
		var price := int(entry.get("price", 0))
		text += "- %s  %d/%d  |  %d coin\n  %s\n" % [item_name, owned, cap, price, str(inventory.item_defs.get(item_id, {}).get("description", ""))]
		if str(entry.get("supply_note", "")) != "":
			text += "  Supply: %s\n" % entry.supply_note
	text += "\nBasic arrows and medicine stay available after restitution. Ask for the emergency reserve when you have none."
	inventory_text.text = text
	for child in craft_buttons.get_children():
		craft_buttons.remove_child(child)
		child.queue_free()
	for entry in stock:
		var item_id := str(entry.get("item_id", ""))
		var owned := int(entry.get("owned", 0))
		var cap := int(entry.get("cap", 999))
		var price := int(entry.get("price", 0))
		var buy_button := Button.new()
		buy_button.text = "Buy %s — %d coin" % [inventory.get_item_name(item_id), price]
		buy_button.disabled = owned >= cap or int(inventory.coin) < price
		_style_button(buy_button)
		buy_button.pressed.connect(func(id = item_id): vendor_purchase_requested.emit(vendor_id, id, 1))
		craft_buttons.add_child(buy_button)
	if vendor_id == "tor_forge" and int(inventory.items.get("standard_arrow", 0)) < 5:
		var refill := Button.new()
		refill.text = "Claim Tor's free emergency arrows"
		_style_button(refill)
		refill.pressed.connect(func(): vendor_purchase_requested.emit(vendor_id, "__emergency_arrows__", 1))
		craft_buttons.add_child(refill)
	if vendor_id == "mira_apothecary" and int(inventory.items.get("redroot_potion", 0)) == 0:
		var care := Button.new()
		care.text = "Ask Mira for emergency medicine"
		care.disabled = bool(vendor_service.emergency_healing_claimed)
		_style_button(care)
		care.pressed.connect(func(): vendor_purchase_requested.emit(vendor_id, "__emergency_healing__", 1))
		craft_buttons.add_child(care)
	var close := Button.new()
	close.text = "Close"
	_style_button(close)
	close.pressed.connect(func():
		dialogue_closed.emit()
		get_tree().paused = false
		hide_menus()
	)
	craft_buttons.add_child(close)
	_focus_after_rebuild(craft_buttons)

func show_ending(title: String, body: String) -> void:
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
	_set_ui_pointer("death")
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box("Kael Falls")
	var label = Label.new()
	label.text = body
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	_add_menu_button(box, "Load Last Checkpoint", func(): load_checkpoint_requested.emit())
	_add_menu_button(box, "Begin Again", func(): new_game_requested.emit())
	_add_menu_button(box, "Return to Main Menu", func(): show_main_menu())

func _build_hud() -> void:
	hud_root = Control.new()
	var root := hud_root
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.018, 0.015, 0.08)
	root.add_child(shade)
	var bars_back = ColorRect.new()
	bars_back.name = "VitalsBackdrop"
	bars_back.position = Vector2(16, 16)
	bars_back.size = Vector2(230, 82)
	bars_back.color = Color(0.018, 0.016, 0.014, 0.62)
	root.add_child(bars_back)
	_add_hud_accent(bars_back, Vector2.ZERO, Vector2(3, 82))
	var bars = VBoxContainer.new()
	bars.position = Vector2(23, 20)
	bars.custom_minimum_size = Vector2(214, 72)
	bars.add_theme_constant_override("separation", 2)
	root.add_child(bars)
	health_bar = ProgressBar.new()
	health_bar.max_value = 125
	health_bar.value = 125
	health_bar.show_percentage = false
	health_value_label = Label.new()
	bars.add_child(_labeled_bar("Blood", health_bar, health_value_label))
	stamina_bar = ProgressBar.new()
	stamina_bar.max_value = 100
	stamina_bar.value = 100
	stamina_bar.show_percentage = false
	stamina_value_label = Label.new()
	bars.add_child(_labeled_bar("Stamina", stamina_bar, stamina_value_label))
	equipment_label = Label.new()
	equipment_label.name = "EquipmentQuickRead"
	equipment_label.text = "[R] Redroot x0   [F] Ash Bomb x0\nOil: No oil"
	equipment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_label.clip_text = true
	equipment_label.custom_minimum_size = Vector2(214, 30)
	equipment_label.add_theme_font_size_override("font_size", 12)
	bars.add_child(equipment_label)
	enemy_label = Label.new()
	enemy_label.name = "EnemyFocusLabel"
	enemy_label.position = Vector2(474, 44)
	enemy_label.size = Vector2(334, 22)
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_label.visible = false
	root.add_child(enemy_label)
	enemy_bar = ProgressBar.new()
	enemy_bar.name = "EnemyFocusHealth"
	enemy_bar.position = Vector2(500, 75)
	enemy_bar.size = Vector2(280, 16)
	enemy_bar.show_percentage = false
	enemy_bar.visible = false
	root.add_child(enemy_bar)
	enemy_value_label = Label.new()
	enemy_value_label.position = Vector2(812, 71)
	enemy_value_label.size = Vector2(90, 24)
	enemy_value_label.visible = false
	root.add_child(enemy_value_label)
	target_status_label = Label.new()
	target_status_label.name = "TargetLockStatus"
	target_status_label.position = Vector2(474, 98)
	target_status_label.size = Vector2(334, 20)
	target_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_status_label.visible = false
	root.add_child(target_status_label)
	prompt_label = Label.new()
	prompt_label.name = "InteractionPrompt"
	prompt_label.position = Vector2(390, 660)
	prompt_label.size = Vector2(500, 30)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.visible = false
	root.add_child(prompt_label)
	tracker_back = ColorRect.new()
	tracker_back.name = "QuestTrackerBackdrop"
	tracker_back.position = Vector2(980, 14)
	tracker_back.size = Vector2(284, 70)
	tracker_back.color = Color(0.018, 0.016, 0.014, 0.62)
	root.add_child(tracker_back)
	_add_hud_accent(tracker_back, Vector2(281, 0), Vector2(3, 70))
	tracker_label = Label.new()
	tracker_label.name = "QuestTrackerObjective"
	tracker_label.position = Vector2(990, 20)
	tracker_label.size = Vector2(258, 56)
	tracker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tracker_label.clip_text = true
	root.add_child(tracker_label)
	compass_back = ColorRect.new()
	compass_back.name = "CompassBackdrop"
	compass_back.position = Vector2(430, 14)
	compass_back.size = Vector2(420, 26)
	compass_back.color = Color(0.018, 0.016, 0.014, 0.46)
	compass_back.visible = false
	root.add_child(compass_back)
	compass_label = Label.new()
	compass_label.name = "LocationAndObjectiveCompass"
	compass_label.position = Vector2(430, 15)
	compass_label.size = Vector2(420, 24)
	compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(compass_label)
	toast_label = Label.new()
	toast_label.position = Vector2(22, 626)
	toast_label.size = Vector2(420, 84)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.visible = false
	root.add_child(toast_label)
	hint_label = Label.new()
	hint_label.name = "ContextualCombatHint"
	hint_label.position = Vector2(430, 82)
	hint_label.size = Vector2(420, 30)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.visible = false
	root.add_child(hint_label)
	status_label = Label.new()
	status_label.name = "CombatStatusCue"
	status_label.position = Vector2(470, 602)
	status_label.size = Vector2(340, 26)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.visible = false
	root.add_child(status_label)

func _on_viewport_resized() -> void:
	call_deferred("_apply_hud_layout")

func _apply_hud_layout() -> void:
	if hud_root == null or get_viewport() == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x < 320.0 or viewport_size.y < 240.0:
		return
	var center_x := viewport_size.x * 0.5
	if tracker_back != null:
		tracker_back.position = Vector2(maxf(viewport_size.x - 300.0, 12.0), 14.0)
	if tracker_label != null:
		tracker_label.position = Vector2(maxf(viewport_size.x - 290.0, 24.0), 20.0)
	if compass_back != null:
		compass_back.position = Vector2(center_x - 210.0, 14.0)
	if compass_label != null:
		compass_label.position = Vector2(center_x - 210.0, 15.0)
	if enemy_label != null:
		enemy_label.position = Vector2(center_x - 166.0, 44.0)
	if enemy_bar != null:
		enemy_bar.position = Vector2(center_x - 140.0, 75.0)
	if enemy_value_label != null:
		enemy_value_label.position = Vector2(center_x + 172.0, 71.0)
	if target_status_label != null:
		target_status_label.position = Vector2(center_x - 166.0, 98.0)
	if prompt_label != null:
		prompt_label.position = Vector2(center_x - 250.0, maxf(viewport_size.y - 60.0, 170.0))
	if hint_label != null:
		hint_label.position = Vector2(center_x - 210.0, 82.0)
	if status_label != null:
		status_label.position = Vector2(center_x - 170.0, maxf(viewport_size.y - 118.0, 220.0))
	if toast_label != null:
		toast_label.position = Vector2(22.0, maxf(viewport_size.y - 152.0, 170.0))
		toast_label.size.x = minf(420.0, viewport_size.x - 44.0)
	if dialogue_layer != null:
		dialogue_layer.position = Vector2(maxf((viewport_size.x - 840.0) * 0.5, 20.0), maxf(viewport_size.y - dialogue_layer.size.y - 34.0, 110.0))
	if inventory_layer != null:
		inventory_layer.position = Vector2(maxf((viewport_size.x - 996.0) * 0.5, 20.0), maxf((viewport_size.y - 584.0) * 0.5, 20.0))

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
	dialogue_layer.position = Vector2(220, 474)
	dialogue_layer.size = Vector2(840, 212)
	dialogue_layer.visible = false
	add_child(dialogue_layer)
	dialogue_layer.resized.connect(_on_viewport_resized)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	dialogue_layer.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	dialogue_title = Label.new()
	dialogue_title.name = "DialogueSpeakerName"
	dialogue_title.add_theme_font_size_override("font_size", 22)
	dialogue_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(dialogue_title)
	dialogue_page_label = Label.new()
	dialogue_page_label.name = "DialoguePageCounter"
	dialogue_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dialogue_page_label.add_theme_font_size_override("font_size", 12)
	dialogue_page_label.add_theme_color_override("font_color", Color(0.62, 0.54, 0.40))
	heading.add_child(dialogue_page_label)
	var history_button := Button.new()
	history_button.text = "History"
	history_button.focus_mode = Control.FOCUS_ALL
	history_button.pressed.connect(func(): show_text_history("dialogue"))
	heading.add_child(history_button)
	var rule := ColorRect.new()
	rule.name = "DialogueGoldRule"
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = Color(0.58, 0.40, 0.18, 0.82)
	box.add_child(rule)
	dialogue_text = RichTextLabel.new()
	dialogue_text.name = "DialogueSubtitleText"
	dialogue_text.bbcode_enabled = true
	dialogue_text.fit_content = false
	dialogue_text.custom_minimum_size = Vector2(784, 78)
	box.add_child(dialogue_text)
	dialogue_actions = VBoxContainer.new()
	dialogue_actions.name = "DialogueChoices"
	dialogue_actions.process_mode = Node.PROCESS_MODE_ALWAYS
	dialogue_actions.add_theme_constant_override("separation", 8)
	dialogue_choices_scroll = ScrollContainer.new()
	dialogue_choices_scroll.custom_minimum_size = Vector2(0, 96)
	dialogue_choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialogue_choices_scroll.follow_focus = true
	dialogue_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(dialogue_choices_scroll)
	dialogue_choices_scroll.add_child(dialogue_actions)

func _build_inventory() -> void:
	inventory_layer = PanelContainer.new()
	inventory_layer.position = Vector2(142, 68)
	inventory_layer.size = Vector2(996, 584)
	inventory_layer.visible = false
	add_child(inventory_layer)
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	inventory_layer.add_child(columns)
	var journal_column := VBoxContainer.new()
	journal_column.custom_minimum_size = Vector2(560, 520)
	journal_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(journal_column)
	journal_art = TextureRect.new()
	journal_art.custom_minimum_size = Vector2(560, 112)
	journal_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	journal_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	journal_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	journal_art.visible = false
	journal_column.add_child(journal_art)
	inventory_text = RichTextLabel.new()
	inventory_text.custom_minimum_size = Vector2(560, 396)
	inventory_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_text.scroll_active = true
	inventory_text.focus_mode = Control.FOCUS_ALL
	inventory_text.add_theme_constant_override("line_separation", 5)
	inventory_text.add_theme_font_size_override("normal_font_size", 17)
	journal_column.add_child(inventory_text)
	var actions_scroll := ScrollContainer.new()
	actions_scroll.name = "PreparationActionsScroll"
	actions_scroll.custom_minimum_size = Vector2(320, 520)
	actions_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	actions_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	actions_scroll.follow_focus = true
	columns.add_child(actions_scroll)
	craft_buttons = VBoxContainer.new()
	craft_buttons.custom_minimum_size = Vector2(320, 0)
	craft_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_scroll.add_child(craft_buttons)

func _labeled_bar(label_text: String, bar: ProgressBar, value_label: Label) -> HBoxContainer:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(48, 18)
	row.add_child(label)
	bar.custom_minimum_size = Vector2(112, 16)
	row.add_child(bar)
	value_label.text = "%d / %d" % [int(bar.value), int(bar.max_value)]
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(54, 20)
	value_label.add_theme_font_size_override("font_size", 12)
	row.add_child(value_label)
	return row

func _clear_menu() -> void:
	new_game_status_label = null
	for child in menu_layer.get_children():
		child.queue_free()

func _menu_box(title: String, subtitle: String = "", omen_text: String = "", height_limit: float = 760.0) -> VBoxContainer:
	var viewport_size := _menu_viewport_size()
	var compact := viewport_size.y <= 800.0 or viewport_size.x <= 1366.0
	var horizontal_margin := clampf(viewport_size.x * 0.055, 24.0, 112.0)
	var vertical_margin := clampf(viewport_size.y * 0.060, 24.0, 72.0)
	var shell_separation := 30.0 if compact else 84.0
	var panel_width := clampf(viewport_size.x * 0.42, 420.0, 570.0)
	# Give ordinary menus enough vertical breathing room to show their full
	# action list at 1080p. Long settings/remap pages still use the same
	# container's scrollbar when the available viewport is shorter.
	var panel_height := minf(height_limit, maxf(260.0, viewport_size.y - vertical_margin * 2.0))
	var content_width := maxf(panel_width - 56.0, 320.0)
	_build_menu_background()
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(horizontal_margin))
	margin.add_theme_constant_override("margin_top", int(vertical_margin))
	margin.add_theme_constant_override("margin_right", int(horizontal_margin))
	margin.add_theme_constant_override("margin_bottom", int(vertical_margin))
	menu_layer.add_child(margin)
	var shell = HBoxContainer.new()
	shell.add_theme_constant_override("separation", int(shell_separation))
	margin.add_child(shell)
	var title_stack = VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 14)
	shell.add_child(title_stack)
	var title_spacer = Control.new()
	title_spacer.custom_minimum_size = Vector2(1, 54.0 if compact else 142.0)
	title_stack.add_child(title_spacer)
	var title_label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 56 if compact else 92)
	title_label.add_theme_color_override("font_color", Color(0.93, 0.78, 0.47))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 4)
	title_stack.add_child(title_label)
	if subtitle != "":
		var subtitle_label = Label.new()
		subtitle_label.text = subtitle
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle_label.add_theme_font_size_override("font_size", 22 if compact else 34)
		subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.70, 0.56))
		title_stack.add_child(subtitle_label)
	if omen_text != "":
		var omen = Label.new()
		omen.text = omen_text.to_upper()
		omen.add_theme_font_size_override("font_size", 12 if compact else 16)
		omen.add_theme_color_override("font_color", Color(0.56, 0.50, 0.40))
		title_stack.add_child(omen)
	var title_fill = Control.new()
	title_fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_stack.add_child(title_fill)
	var build = Label.new()
	build.text = MENU_BUILD_LABEL
	build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build.add_theme_font_size_override("font_size", 10 if compact else 15)
	build.add_theme_color_override("font_color", Color(0.50, 0.46, 0.38))
	title_stack.add_child(build)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_panel(panel, Color(0.030, 0.026, 0.022, 0.88), Color(0.58, 0.42, 0.20, 0.86))
	shell.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.name = "MenuScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.name = "MenuContent"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(content_width, 0.0)
	box.set_meta("compact_buttons", compact)
	box.set_meta("menu_button_width", content_width)
	box.set_meta("menu_button_height", 46.0 if compact else 62.0)
	box.set_meta("menu_font_size", 18 if compact else 23)
	box.add_theme_constant_override("separation", 10 if compact else 14)
	scroll.add_child(box)
	return box

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

func _add_menu_button(box: VBoxContainer, text: String, callback: Callable, disabled: bool = false) -> void:
	var is_first_button := true
	for child in box.get_children():
		if child is Button:
			is_first_button = false
			break
	var button = Button.new()
	button.text = text
	button.disabled = disabled
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.custom_minimum_size = Vector2(float(box.get_meta("menu_button_width", 510.0)), float(box.get_meta("menu_button_height", 62.0)))
	_style_button(button)
	button.add_theme_font_size_override("font_size", int(box.get_meta("menu_font_size", 23)))
	button.mouse_entered.connect(func():
		if not button.disabled:
			menu_hovered.emit()
	)
	button.focus_entered.connect(func():
		if not button.disabled:
			menu_hovered.emit()
	)
	button.pressed.connect(func():
		menu_clicked.emit()
		callback.call()
	)
	box.add_child(button)
	if is_first_button and not disabled:
		button.call_deferred("grab_focus")

func _add_menu_text(box: VBoxContainer, text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(float(box.get_meta("menu_button_width", 510.0)), 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.72, 0.66, 0.54))
	label.add_theme_font_size_override("font_size", 16 if bool(box.get_meta("compact_buttons", false)) else 20)
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
	if menu_layer != null and menu_layer.visible and input_source != null and input_source.has_method("focus_first_enabled"):
		input_source.focus_first_enabled(menu_layer)

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
	if dialogue_text != null:
		dialogue_title.visible = subtitle_speaker_names
		_style_panel(dialogue_layer, Color(0.045, 0.04, 0.035, clampf(float(current.get("subtitle_background_opacity", 0.92)), 0.25, 1.0)), Color(0.44, 0.32, 0.18, 0.92))
		dialogue_text.add_theme_font_size_override("normal_font_size", int(round(24.0 * subtitle_scale)))
		dialogue_text.add_theme_font_size_override("bold_font_size", int(round(26.0 * subtitle_scale)))
		dialogue_text.custom_minimum_size.y = 78.0 if subtitle_scale <= 1.0 else 116.0
	for label in [tracker_label, compass_label, prompt_label, hint_label, toast_label]:
		if label == null:
			continue
		label.add_theme_constant_override("outline_size", 5 if high_contrast else (4 if label == compass_label else 2))
		label.add_theme_color_override("font_outline_color", Color.BLACK if high_contrast else Color(0.01, 0.01, 0.01, 0.78))
	_update_process_policy()

func set_input_device(device: String) -> void:
	input_device = device if device in ["keyboard_mouse", "gamepad", "touch"] else "keyboard_mouse"
	if raw_prompt != "":
		set_prompt(raw_prompt)
	if raw_hint != "":
		hint_label.text = _format_input_text(raw_hint)
	update_equipment(last_potions, last_bombs, last_oil_name, last_arrow_count, last_arrow_type)

func _action_label(action: String) -> String:
	if input_source != null and input_source.has_method("action_label"):
		return "[%s]" % str(input_source.action_label(action))
	return "[%s]" % action.capitalize()

func _format_input_text(text: String) -> String:
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
	if _capture_remap_input(event):
		return
	if dialogue_layer == null or not dialogue_layer.visible:
		return
	if event is InputEventKey:
		var navigation_key := event as InputEventKey
		var navigation_code := navigation_key.keycode if navigation_key.keycode != KEY_NONE else navigation_key.physical_keycode
		if navigation_key.pressed and not navigation_key.echo and navigation_code in [KEY_TAB, KEY_UP, KEY_DOWN]:
			var buttons: Array[Button] = []
			for child in dialogue_actions.get_children():
				if child is Button and not child.is_queued_for_deletion() and not child.disabled:
					buttons.append(child)
			if buttons.size() > 1:
				var focused_button := get_viewport().gui_get_focus_owner()
				var current_index := buttons.find(focused_button)
				var direction := -1 if navigation_code == KEY_UP or (navigation_code == KEY_TAB and navigation_key.shift_pressed) else 1
				var next_index := posmod(current_index + direction, buttons.size())
				get_viewport().set_input_as_handled()
				buttons[next_index].grab_focus()
				return
	var accepted := event.is_action_pressed("ui_accept")
	var pointer_button: Button
	if event is InputEventKey:
		var key_event := event as InputEventKey
		# Browser backends can populate either the logical or physical key field.
		# Accept both so a focused dialogue button remains usable while the tree is paused.
		accepted = key_event.pressed and not key_event.echo and (
			key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
			or key_event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and dialogue_actions != null:
			# Press activation remains reliable on paused Web frames, but the
			# pointer's actual button must win over unrelated keyboard focus.
			for child in dialogue_actions.get_children():
				if child is Button and not child.is_queued_for_deletion() and not child.disabled and child.get_global_rect().has_point(mouse_event.position):
					pointer_button = child
					break
			accepted = pointer_button != null
	if not accepted:
		return
	var focused := pointer_button if pointer_button != null else get_viewport().gui_get_focus_owner()
	if not (focused is Button) or (focused as Button).disabled or not dialogue_actions.is_ancestor_of(focused):
		var fallback_button := _focused_dialogue_button()
		if fallback_button != null:
			fallback_button.grab_focus()
		focused = get_viewport().gui_get_focus_owner()
	if focused is Button and not (focused as Button).disabled:
		(focused as Button).pressed.emit()
		get_viewport().set_input_as_handled()

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
				toast("That input cannot be assigned.")
			show_remap_menu(remap_back_target, remap_page)
			get_viewport().set_input_as_handled()
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if dialogue_layer != null and dialogue_layer.visible and event.is_action_pressed("ui_accept"):
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if dialogue_layer != null and dialogue_layer.visible:
		if not _close_dialogue_surface():
			return
		dialogue_closed.emit()
	elif inventory_layer != null and inventory_layer.visible:
		dialogue_closed.emit()
		get_tree().paused = false
		hide_menus()
	elif active_menu in ["settings", "controls"]:
		_return_from_controls()
	elif active_menu == "remap":
		_return_from_remap()
	elif active_menu == "credits":
		show_main_menu()
	elif active_menu == "text_history":
		_return_from_history()
	elif active_menu in ["save_library", "save_slot", "save_import", "chapter_replay", "text_history", "problem_report"]:
		if active_menu in ["save_slot", "save_import", "chapter_replay"]:
			show_save_library(library_back_target, library_page)
		elif library_back_target == "main":
			show_main_menu()
		else:
			show_pause_menu()
	elif active_menu == "pause":
		resume_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()

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
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(AUTOSAVE_PATH) or FileAccess.file_exists(CHECKPOINT_PATH)

func _save_status_text() -> String:
	if FileAccess.file_exists(SAVE_PATH):
		return "Continue source: manual save"
	if FileAccess.file_exists(AUTOSAVE_PATH):
		return "Continue source: latest autosave"
	if FileAccess.file_exists(CHECKPOINT_PATH):
		return "Continue source: safe checkpoint"
	return "No journey has been saved on this device."

func _return_from_controls() -> void:
	if controls_back_target == "pause":
		show_pause_menu()
	else:
		show_main_menu()

func _add_dialogue_close() -> void:
	var close = Button.new()
	close.text = "Close"
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
	for bar in [health_bar, stamina_bar, enemy_bar]:
		var bg = StyleBoxFlat.new()
		bg.bg_color = Color(0.035, 0.032, 0.028, 0.88)
		bg.border_color = Color(0.35, 0.30, 0.22)
		bg.set_border_width_all(1)
		var fill = StyleBoxFlat.new()
		fill.bg_color = Color(0.52, 0.11, 0.08) if bar == health_bar or bar == enemy_bar else Color(0.72, 0.54, 0.18)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
	for label in [enemy_label, enemy_value_label, target_status_label, prompt_label, tracker_label, compass_label, toast_label, hint_label, status_label, equipment_label, health_value_label, stamina_value_label]:
		label.add_theme_color_override("font_color", Color(0.86, 0.81, 0.69))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
	tracker_label.add_theme_font_size_override("font_size", 15)
	compass_label.add_theme_font_size_override("font_size", 16)
	target_status_label.add_theme_font_size_override("font_size", 13)
	toast_label.add_theme_font_size_override("font_size", 17)
	prompt_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_font_size_override("font_size", 16)
	_style_panel(dialogue_layer, Color(0.045, 0.04, 0.035, 0.96), Color(0.44, 0.32, 0.18, 0.92))
	_style_panel(inventory_layer, Color(0.045, 0.04, 0.035, 0.97), Color(0.44, 0.32, 0.18, 0.92))

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
	bar.modulate = color
	var tween = create_tween()
	tween.tween_property(bar, "modulate", Color.WHITE, 0.18)

func _status_color(kind: String) -> Color:
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

func get_current_dialogue_page() -> Dictionary:
	if dialogue_page_index < 0 or dialogue_page_index >= dialogue_pages.size():
		return {}
	var page: Variant = dialogue_pages[dialogue_page_index]
	return page.duplicate(true) if typeof(page) == TYPE_DICTIONARY else {"speaker": dialogue_title.text, "text": str(page)}

func _physical_story_journal(state) -> String:
	var lines: Array[String] = []
	var facts := {
		"mill_workers_rescued": "Mill workers reached safety with Kael's escort.",
		"mill_records_saved": "The mill records were carried clear of the fire.",
		"root_testimony_protected": "The roots' testimony was protected during the confrontation.",
		"root_testimony_recovered": "Kael recovered the testimony after the roots were damaged.",
		"root_landscape_released": "Two roots were redirected, opening the ground again.",
		"bell_rhythm_learned": "Kael learned the bell's rhythm; its warning can be read as well as heard.",
		"bell_rope_released": "The bell rope was released.",
		"relief_deliveries_completed": "Both households received their relief supplies in person.",
		"aftermath_names_returned": "The recovered names were returned to Greyfen.",
		"aftermath_work_promised": "Kael promised to take part in the work that follows.",
		"aftermath_walk_completed": "Kael walked the road home and saw the covenant's consequences."
	}
	for flag in facts:
		if bool(state.get_flag(flag, false)):
			lines.append(str(facts[flag]))
	var damage := str(state.get_flag("mill_damage_state", ""))
	if damage != "":
		lines.append("The mill fire was contained." if damage == "contained" else "The mill bears fire damage; recovery will take material and labor.")
	if int(state.get_flag("mill_smoke_exposure", 0)) >= 3:
		lines.append("Workers inhaled too much smoke during the rescue and need care.")
	if bool(state.get_flag("root_testimony_damaged", false)) and not bool(state.get_flag("root_testimony_recovered", false)):
		lines.append("The roots' testimony was damaged. Search the disturbed ground for a recoverable record.")
	if bool(state.get_flag("assembly_relief_ready", false)) and not bool(state.get_flag("relief_deliveries_completed", false)):
		lines.append("Relief supplies are ready; the two households still need their deliveries.")
	if bool(state.get_flag("final_choice_completed", false)) and not bool(state.get_flag("aftermath_walk_completed", false)):
		lines.append("Return to Greyfen: hear the households, return the names and decide what work Kael will share.")
	return "\nWORK THAT CHANGED THE ROAD\n" + "\n".join(lines) + "\n" if not lines.is_empty() else ""

func save_text_history() -> Array:
	return text_history.save_state()

func load_text_history(raw: Variant) -> void:
	text_history.load_state(raw)

func _save_service():
	return get_parent().get("save_manager")

func show_save_library(back_target: String = "pause", requested_page: int = 0) -> void:
	library_back_target = back_target
	active_menu = "save_library"
	_set_internal_canvas(Vector2i(MENU_SIZE))
	_set_ui_pointer("pause")
	_clear_menu()
	menu_layer.visible = true
	var box := _menu_box("Saved Journeys", "The road you remember", "manual saves and protected checkpoints")
	box.set_meta("compact_buttons", true)
	var service = _save_service()
	if service == null:
		_add_menu_text(box, "Save storage is preparing.")
		return
	var slots: Array = service.list_slots()
	var pages := maxi(1, ceili(float(slots.size()) / 4.0))
	library_page = clampi(requested_page, 0, pages - 1)
	_add_menu_text(box, "Page %d of %d. Browser saves belong to this browser and device. Export a JSON copy to keep or move a journey." % [library_page + 1, pages])
	for index in range(library_page * 4, mini(slots.size(), library_page * 4 + 4)):
		var slot: Dictionary = slots[index]
		var summary := str(slot.title)
		if bool(slot.valid):
			summary += "\n%s · %s%s" % [slot.zone, str(slot.saved_at).replace("T", " "), " · replay" if bool(slot.replay) else ""]
		else:
			summary += " — unreadable" if bool(slot.exists) else " — empty"
		_add_menu_button(box, summary, func(id = str(slot.id)): show_save_slot(id))
	_add_menu_button(box, "Previous Page", func(): show_save_library(library_back_target, library_page - 1), library_page <= 0)
	_add_menu_button(box, "Next Page", func(): show_save_library(library_back_target, library_page + 1), library_page >= pages - 1)
	_add_menu_button(box, "Import a Save File", func():
		service.request_import_file()
		if not service.library_changed.is_connected(_refresh_save_library):
			service.library_changed.connect(_refresh_save_library)
	)
	_add_menu_button(box, "Paste a Save", show_save_import)
	_add_menu_button(box, "Chapter Replay", show_chapter_replays, service.chapter_replays().is_empty())
	_add_menu_button(box, "Back", _return_from_library)

func _refresh_save_library() -> void:
	if active_menu == "save_library":
		show_save_library(library_back_target, library_page)
	elif active_menu == "save_slot":
		show_save_slot(selected_slot)

func show_save_slot(slot_id: String) -> void:
	selected_slot = slot_id
	active_menu = "save_slot"
	_clear_menu()
	var service = _save_service()
	var slot: Dictionary = {}
	for candidate in service.list_slots():
		if str(candidate.id) == slot_id:
			slot = candidate
	if slot.is_empty():
		show_save_library(library_back_target, library_page)
		return
	var box := _menu_box(str(slot.title), str(slot.zone) if bool(slot.valid) else "Empty journey", "save library")
	box.set_meta("compact_buttons", true)
	var title := LineEdit.new()
	title.text = str(slot.title)
	title.max_length = 48
	title.placeholder_text = "Name this journey"
	title.custom_minimum_size = Vector2(320, 44)
	title.focus_mode = Control.FOCUS_ALL
	title.editable = not bool(slot.protected)
	box.add_child(title)
	if bool(slot.valid):
		_add_menu_text(box, "Saved %s UTC" % str(slot.saved_at).replace("T", " "))
	_add_menu_button(box, "Load This Journey", func():
		if service.load_slot(get_parent(), slot_id):
			hide_menus()
	, not bool(slot.valid))
	if not bool(slot.protected):
		var can_save := get_parent().get("game_started") == true and is_instance_valid(get_parent().get("player"))
		_add_menu_button(box, "Replace With Current Journey" if bool(slot.exists) else "Save Current Journey Here", func():
			if service.save_named(get_parent(), slot_id, title.text):
				show_save_slot(slot_id)
		, not can_save)
		_add_menu_button(box, "Rename", func():
			if service.rename_slot(slot_id, title.text):
				show_save_slot(slot_id)
		, not bool(slot.valid))
		_add_menu_button(box, "Restore Previous Slot Copy", func():
			if service.restore_previous_slot(slot_id):
				show_save_slot(slot_id)
		, not service.has_previous_slot(slot_id))
		_add_menu_button(box, "Import File Into This Slot", func():
			service.request_import_file(slot_id)
			if not service.library_changed.is_connected(_refresh_save_library):
				service.library_changed.connect(_refresh_save_library)
		)
	_add_menu_button(box, "Export This Journey", func(): service.export_slot(slot_id), not bool(slot.valid))
	_add_menu_text(box, "Replacing or importing into this manual save retains its previous copy. Export a copy first to keep more than one earlier version. Automatic checkpoints cannot be overwritten from this menu.")
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
	box.add_child(input)
	_add_menu_button(box, "Import Into an Empty Slot", func():
		if _save_service().import_save_text(input.text):
			show_save_library(library_back_target, 0)
	)
	_add_menu_button(box, "Back", func(): show_save_library(library_back_target, library_page))

func show_chapter_replays() -> void:
	active_menu = "chapter_replay"
	_clear_menu()
	var box := _menu_box("Return to a Chapter", "A copied journey", "your completed outcome is preserved")
	_add_menu_text(box, "Replay begins from the first checkpoint recorded in each chapter of this journey. Replay autosaves and decisions use separate files. Manual saves can preserve a replay as a new journey.")
	for chapter in _save_service().chapter_replays():
		_add_menu_button(box, str(chapter.title), func(id = str(chapter.id)):
			if _save_service().replay_chapter(get_parent(), id):
				hide_menus()
		)
	_add_menu_button(box, "Back", func(): show_save_library(library_back_target, library_page))

func _return_from_library() -> void:
	if library_back_target == "main":
		show_main_menu()
	else:
		show_pause_menu()

func show_text_history(back_target: String = "pause") -> void:
	library_back_target = back_target
	active_menu = "text_history"
	dialogue_layer.visible = false
	_set_internal_canvas(Vector2i(MENU_SIZE))
	_set_ui_pointer("pause")
	_clear_menu()
	menu_layer.visible = true
	var box := _menu_box("Conversation History", "Words and promises", "most recent 400 entries")
	var log := RichTextLabel.new()
	log.text = text_history.text()
	log.bbcode_enabled = false
	log.custom_minimum_size = Vector2(340, 410)
	log.add_theme_font_size_override("normal_font_size", int(20 * story_text_scale))
	log.focus_mode = Control.FOCUS_ALL
	log.scroll_active = true
	log.scroll_following = true
	box.add_child(log)
	_add_menu_button(box, "Back to Conversation" if back_target == "dialogue" else "Back", _return_from_history)

func _return_from_history() -> void:
	if library_back_target == "dialogue":
		menu_layer.visible = false
		active_menu = ""
		_set_internal_canvas(GAMEPLAY_SIZE)
		_set_ui_pointer("dialogue")
		dialogue_layer.visible = true
		_focus_after_rebuild(dialogue_actions)
	else:
		_return_from_library()

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
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.86, 0.78, 0.60))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.56))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.88, 0.56))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.74, 0.36))
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.39, 0.34))
	button.add_theme_font_size_override("font_size", 23)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
