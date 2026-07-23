extends CanvasLayer

signal new_game_requested
signal continue_requested
signal save_requested
signal load_requested
signal load_checkpoint_requested
signal resume_requested
signal launch_accepted
signal settings_requested(action: String)
signal action_selected(action: Dictionary)
signal craft_requested(item_id: String)
signal item_use_requested(item_id: String)
signal dialogue_closed
signal menu_hovered
signal menu_clicked

const MENU_BUILD_LABEL = "UI-001 | 1080P MENUS / NATIVE 720P WORLD | ASHENOATH.VERCEL.APP"
const MENU_SIZE = Vector2(1920.0, 1080.0)
const GAMEPLAY_SIZE = Vector2i(1280, 720)
const SAVE_PATH = "user://ashen_oath_save.json"
const AUTOSAVE_PATH = "user://ashen_oath_autosave.json"
const CHECKPOINT_PATH = "user://ashen_oath_checkpoint.json"

var health_bar: ProgressBar
var stamina_bar: ProgressBar
var health_value_label: Label
var stamina_value_label: Label
var enemy_bar: ProgressBar
var enemy_label: Label
var enemy_value_label: Label
var prompt_label: Label
var tracker_label: Label
var compass_label: Label
var toast_label: Label
var hint_label: Label
var status_label: Label
var equipment_label: Label
var menu_layer: Control
var dialogue_layer: PanelContainer
var dialogue_title: Label
var dialogue_text: RichTextLabel
var dialogue_actions: VBoxContainer
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
var dialogue_pages: Array[String] = []
var dialogue_page_index := 0
var dialogue_session_data: Dictionary = {}

func _ready() -> void:
	_build_hud()
	_build_menu_layer()
	_build_dialogue()
	_build_inventory()
	_apply_theme()
	set_process(true)

func _process(_delta: float) -> void:
	if health_bar == null:
		return
	var health_ratio = last_health / max(last_health_max, 1.0)
	if health_ratio <= 0.28:
		var pulse = 0.86 + 0.14 * sin(Time.get_ticks_msec() * 0.008)
		health_bar.modulate = Color(1.0, pulse, pulse, 1.0)
	else:
		health_bar.modulate = Color.WHITE

func show_main_menu() -> void:
	_set_internal_canvas(Vector2i(MENU_SIZE))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box("ASHEN OATH", "The Road Between Crowns", "contracts | curses | consequences")
	_add_menu_text(box, "Greyfen waits under ash and oath-light.")
	_add_menu_button(box, "New Game", func(): new_game_requested.emit())
	_add_menu_button(box, "Continue", func(): continue_requested.emit(), not _has_continue_save())
	_add_menu_button(box, "Controls", func(): show_controls_menu("main"))
	_add_menu_button(box, "Settings", func(): show_settings_menu("main"))
	_add_menu_button(box, "Credits", func(): show_credits_menu())
	_add_menu_button(box, "Exit Game", show_launch_screen)

func show_launch_screen() -> void:
	_set_internal_canvas(Vector2i(MENU_SIZE))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box("ASHEN OATH", "The Road Between Crowns", "click to wake the road")
	_add_menu_text(box, "Click once to enable audio and mouse capture.")
	_add_menu_button(box, "Enter", func():
		launch_accepted.emit()
		show_main_menu()
	)

func show_pause_menu() -> void:
	_set_internal_canvas(Vector2i(MENU_SIZE))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box("Paused", "", "the road holds its breath")
	_add_menu_button(box, "Resume", func(): resume_requested.emit())
	_add_menu_button(box, "Save", func(): save_requested.emit())
	_add_menu_button(box, "Load", func(): load_requested.emit())
	_add_menu_button(box, "Settings", func(): show_settings_menu())
	_add_menu_button(box, "Controls", func(): show_controls_menu("pause"))
	_add_menu_button(box, "Main Menu", func(): show_main_menu())

func show_settings_menu(back_target: String = "pause") -> void:
	_set_internal_canvas(Vector2i(MENU_SIZE))
	controls_back_target = back_target
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box("Settings", "Display & Controls", "tune the lantern")
	box.set_meta("compact_buttons", true)
	var s = _current_settings()
	_add_menu_button(box, "Visual Preset     %s" % str(s.get("quality_preset", "balanced")).capitalize(), func(): settings_requested.emit("visual_preset"))
	_add_menu_button(box, "3D Resolution     Native 720p", func(): settings_requested.emit("render_scale"))
	_add_menu_button(box, "Shadows           %s" % _shadow_label(int(s.get("shadow_quality", 1))), func(): settings_requested.emit("shadows"))
	_add_menu_button(box, "Mouse Sensitivity %s" % _sensitivity_label(float(s.get("mouse_sensitivity", 0.003))), func(): settings_requested.emit("mouse_sensitivity"))
	_add_menu_button(box, "Invert Y Axis     %s" % _on_off(bool(s.get("invert_y", false))), func(): settings_requested.emit("invert_y"))
	_add_menu_button(box, "Master Volume     %d%%" % int(round(float(s.get("master_volume", 0.85)) * 100.0)), func(): settings_requested.emit("volume"))
	_add_menu_button(box, "VSync             %s" % _on_off(bool(s.get("vsync", true))), func(): settings_requested.emit("vsync"))
	_add_menu_button(box, "Fullscreen        %s" % _on_off(bool(s.get("fullscreen", false))), func(): settings_requested.emit("fullscreen"))
	_add_menu_button(box, "Subtitle Size     %d%%" % int(round(float(s.get("subtitle_scale", 1.0)) * 100.0)), func(): settings_requested.emit("subtitle_scale"))
	_add_menu_button(box, "Camera Shake      %d%%" % int(round(float(s.get("camera_shake", 1.0)) * 100.0)), func(): settings_requested.emit("camera_shake"))
	_add_menu_button(box, "Reduced Motion    %s" % _on_off(bool(s.get("reduced_motion", false))), func(): settings_requested.emit("reduced_motion"))
	_add_menu_button(box, "Back", _return_from_controls)

func show_controls_menu(back_target: String = "main") -> void:
	controls_back_target = back_target
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box("Controls", "", "blade | breath | road")
	_add_menu_text(box, "WASD move | Mouse look | Shift run | Space dodge | X jump\nLeft mouse light attack | Right mouse heavy attack\nHold C Oathfire Beam | Tap Q parry | Hold Q block | E interact\nR potion | F bomb | Tab inventory | Esc pause")
	_add_menu_button(box, "Back", _return_from_controls)

func show_credits_menu() -> void:
	_set_internal_canvas(Vector2i(MENU_SIZE))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box("Credits", "", "made under an ashen moon")
	_add_menu_text(box, "Ashen Oath vertical slice.\nExternal art/audio/UI assets are tracked under assets_external/licenses.\nPublish public builds with those license notes included.")
	_add_menu_button(box, "Back", func(): show_main_menu())

func hide_menus() -> void:
	_set_internal_canvas(GAMEPLAY_SIZE)
	menu_layer.visible = false
	dialogue_layer.visible = false
	inventory_layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _set_internal_canvas(size: Vector2i) -> void:
	var window := get_window()
	if window != null and window.content_scale_size != size:
		window.content_scale_size = size

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

func set_prompt(text: String) -> void:
	var clean := text.strip_edges()
	if clean.begins_with("E  "):
		clean = "[E]  " + clean.trim_prefix("E  ")
	elif clean.begins_with("E - "):
		clean = "[E]  " + clean.trim_prefix("E - ")
	prompt_label.text = clean
	prompt_label.visible = text != ""

func set_tracker(text: String) -> void:
	tracker_label.text = _format_tracker_text(text)

func set_compass(text: String) -> void:
	compass_label.text = text.replace(" | ", "   •   ")

func toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	if toast_tween != null and toast_tween.is_running():
		toast_tween.kill()
	toast_label.modulate = Color(1, 1, 1, 1)
	toast_tween = create_tween()
	toast_tween.tween_interval(2.15)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.25)
	toast_tween.tween_callback(func():
		toast_label.visible = false
		toast_label.modulate = Color(1, 1, 1, 1)
	)

func set_guidance_hint(text: String, seconds: float = 4.5) -> void:
	hint_label.text = text
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

func update_equipment(potions: int, bombs: int, oil_name: String) -> void:
	var oil_text = oil_name if oil_name != "" else "No oil"
	equipment_label.text = "R Redroot x%d   F Ash Bomb x%d   Oil: %s" % [potions, bombs, oil_text]

func mark_stamina_exhausted() -> void:
	_flash_bar(stamina_bar, Color(1.0, 0.32, 0.16))
	show_status_cue("Stamina spent", "stamina")

func show_dialogue(data: Dictionary) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	dialogue_layer.visible = true
	dialogue_session_data = data.duplicate(true)
	dialogue_pages.clear()
	var greeting := str(data.get("greeting","")).strip_edges()
	if greeting != "": dialogue_pages.append(greeting)
	for line in data.get("lines",[]):
		var line_text := str(line).strip_edges()
		if line_text != "": dialogue_pages.append(line_text)
	if dialogue_pages.is_empty(): dialogue_pages.append("...")
	dialogue_page_index = 0
	_render_dialogue_page()

func _render_dialogue_page() -> void:
	dialogue_title.text = str(dialogue_session_data.get("name","Unknown"))
	dialogue_text.text = dialogue_pages[dialogue_page_index]
	if dialogue_page_label != null:
		dialogue_page_label.text = "%02d / %02d" % [dialogue_page_index + 1, dialogue_pages.size()]
	for child in dialogue_actions.get_children():
		child.queue_free()
	if dialogue_page_index < dialogue_pages.size()-1:
		var advance := Button.new()
		advance.text = "Continue"
		_style_button(advance)
		advance.pressed.connect(func():
			dialogue_page_index += 1
			_render_dialogue_page()
		)
		dialogue_actions.add_child(advance)
		return
	var actions: Array = dialogue_session_data.get("actions",[])
	for action in actions:
		var button = Button.new()
		button.text = action.get("label", "Continue")
		_style_button(button)
		button.pressed.connect(func(action_data = action):
			dialogue_closed.emit()
			action_selected.emit(action_data)
		)
		dialogue_actions.add_child(button)
	if actions.is_empty():
		_add_dialogue_close()

func show_inventory(inventory, quests, story_state = null) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	inventory_layer.visible = true
	var oil_name = "None"
	if inventory.active_oil != "":
		oil_name = inventory.get_item_name(inventory.active_oil)
	var text = "INVENTORY\nCoin: %d\nBlade Oil: %s\n\nItems\n" % [inventory.coin, oil_name]
	for id in inventory.items.keys():
		text += "- %s x%d\n" % [inventory.get_item_name(id), int(inventory.items[id])]
	text += "\nIngredients\n"
	for id in inventory.ingredients.keys():
		text += "- %s x%d\n" % [id.capitalize(), int(inventory.ingredients[id])]
	text += "\n\n%s" % quests.get_journal_text()
	text += "\n\nBESTIARY\n"
	text += "Ghoulkin — Fast cursed remains. Parry the lunge; Moon Oil bites deep.\n"
	if quests.is_completed("main_teeth_in_rain") or quests.is_active("main_teeth_in_rain"):
		text += "Bog Wretch — Rot-bound memory given flesh. Ash Bombs break its approach.\n"
	if quests.is_completed("main_blood_under_stone") or quests.is_active("main_blood_under_stone"):
		text += "Gravebound Knight — A disciplined witness. Read the windup; do not trade blows.\n"
	if story_state != null:
		text += "\nCONSEQUENCES\n"
		var trust := int(story_state.values.get("anwen_trust", 0))
		var fear := int(story_state.values.get("greyfen_fear", 0))
		var debt := int(story_state.values.get("hart_debt", 0))
		text += "Anwen %s.\n" % ("trusts Kael with what the shrine concealed" if trust > 0 else ("guards her words around Kael" if trust < 0 else "has not decided what Kael will do with the truth"))
		text += "Greyfen %s.\n" % ("is close to panic" if fear >= 4 else ("whispers about the reopened road" if fear > 0 else "still believes its old silence will hold"))
		text += "The White Hart %s.\n" % ("is owed a reckoning" if debt > 1 else ("has felt Kael disturb the covenant" if debt != 0 else "has not yet named its price"))
	inventory_text.text = text
	for child in craft_buttons.get_children():
		child.queue_free()
	for id in inventory.item_defs.keys():
		var button = Button.new()
		button.text = "Craft %s" % inventory.get_item_name(id)
		button.disabled = not inventory.can_craft(id)
		_style_button(button)
		button.pressed.connect(func(item_id = id): craft_requested.emit(item_id))
		craft_buttons.add_child(button)
	for id in inventory.items.keys():
		if int(inventory.items[id]) <= 0:
			continue
		var use_button = Button.new()
		use_button.text = "Use %s" % inventory.get_item_name(id)
		_style_button(use_button)
		use_button.pressed.connect(func(item_id = id): item_use_requested.emit(item_id))
		craft_buttons.add_child(use_button)
	var close = Button.new()
	close.text = "Close"
	_style_button(close)
	close.pressed.connect(func():
		dialogue_closed.emit()
		get_tree().paused = false
		hide_menus()
	)
	craft_buttons.add_child(close)

func show_ending(title: String, body: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box(title)
	var label = Label.new()
	label.text = body
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	_add_menu_button(box, "Return to Main Menu", func(): show_main_menu())
	_add_menu_button(box, "Exit Game", show_launch_screen)

func show_death_screen(body: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.018, 0.015, 0.08)
	root.add_child(shade)
	var bars_back = ColorRect.new()
	bars_back.name = "VitalsBackdrop"
	bars_back.position = Vector2(16, 16)
	bars_back.size = Vector2(260, 90)
	bars_back.color = Color(0.018, 0.016, 0.014, 0.72)
	root.add_child(bars_back)
	_add_hud_accent(bars_back, Vector2.ZERO, Vector2(3, 90))
	var bars = VBoxContainer.new()
	bars.position = Vector2(26, 23)
	bars.custom_minimum_size = Vector2(238, 76)
	bars.add_theme_constant_override("separation", 3)
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
	equipment_label.text = "R Redroot x0   F Ash Bomb x0   Oil: No oil"
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
	prompt_label = Label.new()
	prompt_label.name = "InteractionPrompt"
	prompt_label.position = Vector2(420, 650)
	prompt_label.size = Vector2(440, 32)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.visible = false
	root.add_child(prompt_label)
	var tracker_back = ColorRect.new()
	tracker_back.name = "QuestTrackerBackdrop"
	tracker_back.position = Vector2(926, 16)
	tracker_back.size = Vector2(334, 104)
	tracker_back.color = Color(0.018, 0.016, 0.014, 0.72)
	root.add_child(tracker_back)
	_add_hud_accent(tracker_back, Vector2(331, 0), Vector2(3, 104))
	tracker_label = Label.new()
	tracker_label.name = "QuestTrackerObjective"
	tracker_label.position = Vector2(940, 25)
	tracker_label.size = Vector2(304, 88)
	tracker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tracker_label.clip_text = true
	root.add_child(tracker_label)
	var compass_back = ColorRect.new()
	compass_back.name = "CompassBackdrop"
	compass_back.position = Vector2(362, 16)
	compass_back.size = Vector2(556, 30)
	compass_back.color = Color(0.018, 0.016, 0.014, 0.58)
	root.add_child(compass_back)
	compass_label = Label.new()
	compass_label.name = "LocationAndObjectiveCompass"
	compass_label.position = Vector2(362, 19)
	compass_label.size = Vector2(556, 30)
	compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(compass_label)
	toast_label = Label.new()
	toast_label.position = Vector2(22, 616)
	toast_label.size = Vector2(590, 42)
	toast_label.visible = false
	root.add_child(toast_label)
	hint_label = Label.new()
	hint_label.name = "ContextualCombatHint"
	hint_label.position = Vector2(415, 92)
	hint_label.size = Vector2(450, 34)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.visible = false
	root.add_child(hint_label)
	status_label = Label.new()
	status_label.name = "CombatStatusCue"
	status_label.position = Vector2(472, 584)
	status_label.size = Vector2(340, 28)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.visible = false
	root.add_child(status_label)

func _build_menu_layer() -> void:
	menu_layer = Control.new()
	menu_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.visible = false
	add_child(menu_layer)

func _build_dialogue() -> void:
	dialogue_layer = PanelContainer.new()
	dialogue_layer.name = "DialogueLowerThird"
	dialogue_layer.position = Vector2(190, 438)
	dialogue_layer.size = Vector2(900, 248)
	dialogue_layer.visible = false
	add_child(dialogue_layer)
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
	var rule := ColorRect.new()
	rule.name = "DialogueGoldRule"
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = Color(0.58, 0.40, 0.18, 0.82)
	box.add_child(rule)
	dialogue_text = RichTextLabel.new()
	dialogue_text.name = "DialogueSubtitleText"
	dialogue_text.bbcode_enabled = true
	dialogue_text.fit_content = false
	dialogue_text.custom_minimum_size = Vector2(844, 98)
	box.add_child(dialogue_text)
	dialogue_actions = VBoxContainer.new()
	dialogue_actions.name = "DialogueChoices"
	dialogue_actions.add_theme_constant_override("separation", 5)
	box.add_child(dialogue_actions)

func _build_inventory() -> void:
	inventory_layer = PanelContainer.new()
	inventory_layer.position = Vector2(142, 68)
	inventory_layer.size = Vector2(996, 584)
	inventory_layer.visible = false
	add_child(inventory_layer)
	var columns = HBoxContainer.new()
	inventory_layer.add_child(columns)
	inventory_text = RichTextLabel.new()
	inventory_text.custom_minimum_size = Vector2(560, 520)
	columns.add_child(inventory_text)
	craft_buttons = VBoxContainer.new()
	craft_buttons.custom_minimum_size = Vector2(320, 520)
	columns.add_child(craft_buttons)

func _labeled_bar(label_text: String, bar: ProgressBar, value_label: Label) -> HBoxContainer:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(56, 18)
	row.add_child(label)
	bar.custom_minimum_size = Vector2(142, 16)
	row.add_child(bar)
	value_label.text = "%d / %d" % [int(bar.value), int(bar.max_value)]
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(64, 20)
	value_label.add_theme_font_size_override("font_size", 12)
	row.add_child(value_label)
	return row

func _clear_menu() -> void:
	for child in menu_layer.get_children():
		child.queue_free()

func _menu_box(title: String, subtitle: String = "", omen_text: String = "") -> VBoxContainer:
	_build_menu_background()
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 112)
	margin.add_theme_constant_override("margin_top", 72)
	margin.add_theme_constant_override("margin_right", 112)
	margin.add_theme_constant_override("margin_bottom", 64)
	menu_layer.add_child(margin)
	var shell = HBoxContainer.new()
	shell.add_theme_constant_override("separation", 84)
	margin.add_child(shell)
	var title_stack = VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 14)
	shell.add_child(title_stack)
	var title_spacer = Control.new()
	title_spacer.custom_minimum_size = Vector2(1, 142)
	title_stack.add_child(title_spacer)
	var title_label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.add_theme_font_size_override("font_size", 92)
	title_label.add_theme_color_override("font_color", Color(0.93, 0.78, 0.47))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 4)
	title_stack.add_child(title_label)
	if subtitle != "":
		var subtitle_label = Label.new()
		subtitle_label.text = subtitle
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		subtitle_label.add_theme_font_size_override("font_size", 34)
		subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.70, 0.56))
		title_stack.add_child(subtitle_label)
	if omen_text != "":
		var omen = Label.new()
		omen.text = omen_text.to_upper()
		omen.add_theme_font_size_override("font_size", 16)
		omen.add_theme_color_override("font_color", Color(0.56, 0.50, 0.40))
		title_stack.add_child(omen)
	var title_fill = Control.new()
	title_fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_stack.add_child(title_fill)
	var build = Label.new()
	build.text = MENU_BUILD_LABEL
	build.add_theme_font_size_override("font_size", 15)
	build.add_theme_color_override("font_color", Color(0.50, 0.46, 0.38))
	title_stack.add_child(build)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(570, 760 if title == "Settings" else 610)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_panel(panel, Color(0.030, 0.026, 0.022, 0.88), Color(0.58, 0.42, 0.20, 0.86))
	shell.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return box

func _build_menu_background() -> void:
	var base = ColorRect.new()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.color = Color(0.006, 0.008, 0.010, 1.0)
	menu_layer.add_child(base)
	var moon = ColorRect.new()
	moon.set_anchors_preset(Control.PRESET_FULL_RECT)
	moon.color = Color(0.030, 0.045, 0.060, 0.72)
	menu_layer.add_child(moon)
	_add_menu_glow(Vector2(340, 720), Vector2(780, 240), Color(0.95, 0.44, 0.16, 0.20))
	_add_menu_glow(Vector2(1260, 250), Vector2(630, 180), Color(0.32, 0.44, 0.58, 0.18))
	_add_menu_silhouette([Vector2(0, 1080), Vector2(0, 714), Vector2(177, 657), Vector2(315, 711), Vector2(477, 630), Vector2(682, 696), Vector2(930, 627), Vector2(1230, 708), Vector2(1560, 645), Vector2(1920, 738), Vector2(1920, 1080)], Color(0.010, 0.014, 0.014, 0.94))
	_add_menu_silhouette([Vector2(0, 1080), Vector2(0, 879), Vector2(285, 834), Vector2(585, 882), Vector2(963, 810), Vector2(1350, 876), Vector2(1920, 822), Vector2(1920, 1080)], Color(0.018, 0.020, 0.018, 0.98))
	for i in range(38):
		_add_ash_particle(i)

func _add_menu_glow(pos: Vector2, size: Vector2, color: Color) -> void:
	for i in range(4):
		var glow = ColorRect.new()
		glow.position = pos - size * (0.5 + float(i) * 0.16)
		glow.size = size * (1.0 + float(i) * 0.32)
		glow.color = Color(color.r, color.g, color.b, color.a / float(i + 1))
		menu_layer.add_child(glow)

func _add_menu_silhouette(points: PackedVector2Array, color: Color) -> void:
	var poly = Polygon2D.new()
	poly.polygon = points
	poly.color = color
	menu_layer.add_child(poly)

func _add_ash_particle(index: int) -> void:
	var ash = ColorRect.new()
	var x = float((index * 127) % 1860) + 28.0
	var y = float((index * 73) % 980) + 34.0
	ash.position = Vector2(x, y)
	ash.size = Vector2(2.0 + float(index % 3), 2.0 + float((index + 1) % 3))
	ash.color = Color(0.72, 0.64, 0.48, 0.18)
	menu_layer.add_child(ash)
	var tween = create_tween()
	tween.tween_property(ash, "position", ash.position + Vector2(24.0 + float(index % 5) * 5.0, -34.0), 5.0 + float(index % 7) * 0.45)
	tween.parallel().tween_property(ash, "modulate:a", 0.28, 2.0)
	tween.tween_property(ash, "modulate:a", 0.08, 1.4)

func _add_menu_button(box: VBoxContainer, text: String, callback: Callable, disabled: bool = false) -> void:
	var is_first_button := true
	for child in box.get_children():
		if child is Button:
			is_first_button = false
			break
	var button = Button.new()
	button.text = text
	button.disabled = disabled
	button.custom_minimum_size = Vector2(510, 46 if bool(box.get_meta("compact_buttons", false)) else 62)
	_style_button(button)
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

func _add_menu_text(box: VBoxContainer, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.72, 0.66, 0.54))
	label.add_theme_font_size_override("font_size", 20)
	box.add_child(label)

func _current_settings() -> Dictionary:
	var settings_node = get_tree().root.find_child("SettingsManager", true, false)
	if settings_node != null:
		return settings_node.settings
	return {}

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

func _return_from_controls() -> void:
	if controls_back_target == "pause":
		show_pause_menu()
	else:
		show_main_menu()

func _add_dialogue_close() -> void:
	var close = Button.new()
	close.text = "Close"
	_style_button(close)
	close.pressed.connect(func():
		dialogue_closed.emit()
		get_tree().paused = false
		hide_menus()
	)
	dialogue_actions.add_child(close)

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
	for label in [enemy_label, enemy_value_label, prompt_label, tracker_label, compass_label, toast_label, hint_label, status_label, equipment_label, health_value_label, stamina_value_label]:
		label.add_theme_color_override("font_color", Color(0.86, 0.81, 0.69))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
	tracker_label.add_theme_font_size_override("font_size", 15)
	compass_label.add_theme_font_size_override("font_size", 16)
	toast_label.add_theme_font_size_override("font_size", 17)
	prompt_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_font_size_override("font_size", 16)
	_style_panel(dialogue_layer, Color(0.045, 0.04, 0.035, 0.96), Color(0.44, 0.32, 0.18, 0.92))
	_style_panel(inventory_layer, Color(0.045, 0.04, 0.035, 0.97), Color(0.44, 0.32, 0.18, 0.92))

func apply_accessibility(subtitle_scale: float) -> void:
	if dialogue_text != null:
		dialogue_text.add_theme_font_size_override("normal_font_size", int(round(18.0 * subtitle_scale)))
		dialogue_text.add_theme_font_size_override("bold_font_size", int(round(20.0 * subtitle_scale)))

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
