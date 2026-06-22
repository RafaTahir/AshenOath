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

const MENU_BUILD_LABEL = "UI-001 | 2026-06-22 | ashenoath.vercel.app"
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
	_add_menu_button(box, "Quit", func(): get_tree().quit())

func show_launch_screen() -> void:
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
	controls_back_target = back_target
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box("Settings", "", "tune the lantern")
	_add_menu_button(box, "Cycle Render Scale", func(): settings_requested.emit("render_scale"))
	_add_menu_button(box, "Cycle Shadows", func(): settings_requested.emit("shadows"))
	_add_menu_button(box, "Mouse Sensitivity", func(): settings_requested.emit("mouse_sensitivity"))
	_add_menu_button(box, "Invert Y Axis", func(): settings_requested.emit("invert_y"))
	_add_menu_button(box, "Master Volume", func(): settings_requested.emit("volume"))
	_add_menu_button(box, "Toggle VSync", func(): settings_requested.emit("vsync"))
	_add_menu_button(box, "Toggle Fullscreen", func(): settings_requested.emit("fullscreen"))
	_add_menu_button(box, "Potato Mode", func(): settings_requested.emit("potato"))
	_add_menu_button(box, "Back", _return_from_controls)

func show_controls_menu(back_target: String = "main") -> void:
	controls_back_target = back_target
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box("Controls", "", "blade | breath | road")
	_add_menu_text(box, "WASD move | Mouse look | Shift run | Space dodge\nLeft mouse light attack | Right mouse heavy attack\nQ block/parry | E interact | R potion | F bomb\nTab inventory | Esc pause | Arrow keys camera fallback")
	_add_menu_button(box, "Back", _return_from_controls)

func show_credits_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_menu()
	menu_layer.visible = true
	var box = _menu_box("Credits", "", "made under an ashen moon")
	_add_menu_text(box, "Ashen Oath vertical slice.\nExternal art/audio/UI assets are tracked under assets_external/licenses.\nPublish public builds with those license notes included.")
	_add_menu_button(box, "Back", func(): show_main_menu())

func hide_menus() -> void:
	menu_layer.visible = false
	dialogue_layer.visible = false
	inventory_layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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
	prompt_label.text = text
	prompt_label.visible = text != ""

func set_tracker(text: String) -> void:
	tracker_label.text = _format_tracker_text(text)

func set_compass(text: String) -> void:
	compass_label.text = text

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
	dialogue_title.text = data.get("name", "Unknown")
	var lines: Array = data.get("lines", [])
	var line_text = ""
	for line in lines:
		line_text += str(line) + "\n\n"
	dialogue_text.text = "[b]%s[/b]\n\n%s" % [data.get("greeting", ""), line_text.strip_edges()]
	for child in dialogue_actions.get_children():
		child.queue_free()
	for action in data.get("actions", []):
		var button = Button.new()
		button.text = action.get("label", "Continue")
		_style_button(button)
		button.pressed.connect(func(action_data = action):
			dialogue_closed.emit()
			action_selected.emit(action_data)
		)
		dialogue_actions.add_child(button)
	_add_dialogue_close()

func show_inventory(inventory, quests) -> void:
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
	_add_menu_button(box, "Quit", func(): get_tree().quit())

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
	bars_back.position = Vector2(14, 14)
	bars_back.size = Vector2(330, 106)
	bars_back.color = Color(0.025, 0.022, 0.019, 0.56)
	root.add_child(bars_back)
	var bars = VBoxContainer.new()
	bars.position = Vector2(24, 22)
	bars.custom_minimum_size = Vector2(302, 92)
	bars.add_theme_constant_override("separation", 5)
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
	bars.add_child(_labeled_bar("Breath", stamina_bar, stamina_value_label))
	equipment_label = Label.new()
	equipment_label.name = "EquipmentQuickRead"
	equipment_label.text = "R Redroot x0   F Ash Bomb x0   Oil: No oil"
	equipment_label.add_theme_font_size_override("font_size", 12)
	bars.add_child(equipment_label)
	enemy_label = Label.new()
	enemy_label.name = "EnemyFocusLabel"
	enemy_label.position = Vector2(474, 48)
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
	prompt_label.position = Vector2(440, 626)
	prompt_label.size = Vector2(360, 34)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.visible = false
	root.add_child(prompt_label)
	var tracker_back = ColorRect.new()
	tracker_back.position = Vector2(892, 16)
	tracker_back.size = Vector2(358, 132)
	tracker_back.color = Color(0.025, 0.022, 0.019, 0.58)
	root.add_child(tracker_back)
	tracker_label = Label.new()
	tracker_label.name = "QuestTrackerObjective"
	tracker_label.position = Vector2(902, 24)
	tracker_label.size = Vector2(340, 124)
	tracker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(tracker_label)
	compass_label = Label.new()
	compass_label.position = Vector2(406, 22)
	compass_label.size = Vector2(468, 34)
	compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(compass_label)
	toast_label = Label.new()
	toast_label.position = Vector2(24, 634)
	toast_label.size = Vector2(620, 48)
	toast_label.visible = false
	root.add_child(toast_label)
	hint_label = Label.new()
	hint_label.name = "ContextualCombatHint"
	hint_label.position = Vector2(415, 104)
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
	dialogue_layer.position = Vector2(218, 342)
	dialogue_layer.size = Vector2(844, 326)
	dialogue_layer.visible = false
	add_child(dialogue_layer)
	var box = VBoxContainer.new()
	dialogue_layer.add_child(box)
	dialogue_title = Label.new()
	dialogue_title.add_theme_font_size_override("font_size", 22)
	box.add_child(dialogue_title)
	dialogue_text = RichTextLabel.new()
	dialogue_text.bbcode_enabled = true
	dialogue_text.custom_minimum_size = Vector2(790, 156)
	box.add_child(dialogue_text)
	dialogue_actions = VBoxContainer.new()
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
	label.custom_minimum_size = Vector2(62, 20)
	row.add_child(label)
	bar.custom_minimum_size = Vector2(164, 18)
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
	margin.add_theme_constant_override("margin_left", 70)
	margin.add_theme_constant_override("margin_top", 46)
	margin.add_theme_constant_override("margin_right", 70)
	margin.add_theme_constant_override("margin_bottom", 42)
	menu_layer.add_child(margin)
	var shell = HBoxContainer.new()
	shell.add_theme_constant_override("separation", 44)
	margin.add_child(shell)
	var title_stack = VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 10)
	shell.add_child(title_stack)
	var title_spacer = Control.new()
	title_spacer.custom_minimum_size = Vector2(1, 86)
	title_stack.add_child(title_spacer)
	var title_label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.add_theme_font_size_override("font_size", 58)
	title_label.add_theme_color_override("font_color", Color(0.93, 0.78, 0.47))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 4)
	title_stack.add_child(title_label)
	if subtitle != "":
		var subtitle_label = Label.new()
		subtitle_label.text = subtitle
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		subtitle_label.add_theme_font_size_override("font_size", 24)
		subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.70, 0.56))
		title_stack.add_child(subtitle_label)
	if omen_text != "":
		var omen = Label.new()
		omen.text = omen_text.to_upper()
		omen.add_theme_font_size_override("font_size", 12)
		omen.add_theme_color_override("font_color", Color(0.56, 0.50, 0.40))
		title_stack.add_child(omen)
	var title_fill = Control.new()
	title_fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_stack.add_child(title_fill)
	var build = Label.new()
	build.text = MENU_BUILD_LABEL
	build.add_theme_font_size_override("font_size", 12)
	build.add_theme_color_override("font_color", Color(0.50, 0.46, 0.38))
	title_stack.add_child(build)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 520)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_panel(panel, Color(0.030, 0.026, 0.022, 0.88), Color(0.58, 0.42, 0.20, 0.86))
	shell.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box

func _build_menu_background() -> void:
	var base = ColorRect.new()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.color = Color(0.006, 0.008, 0.010, 1.0)
	menu_layer.add_child(base)
	var moon = ColorRect.new()
	moon.position = Vector2(0, 0)
	moon.size = Vector2(1280, 720)
	moon.color = Color(0.030, 0.045, 0.060, 0.72)
	menu_layer.add_child(moon)
	_add_menu_glow(Vector2(228, 478), Vector2(520, 160), Color(0.95, 0.44, 0.16, 0.22))
	_add_menu_glow(Vector2(760, 168), Vector2(420, 120), Color(0.32, 0.44, 0.58, 0.18))
	_add_menu_silhouette([Vector2(0, 720), Vector2(0, 476), Vector2(118, 438), Vector2(210, 474), Vector2(318, 420), Vector2(455, 464), Vector2(620, 418), Vector2(820, 472), Vector2(1040, 430), Vector2(1280, 492), Vector2(1280, 720)], Color(0.010, 0.014, 0.014, 0.94))
	_add_menu_silhouette([Vector2(0, 720), Vector2(0, 586), Vector2(190, 556), Vector2(390, 588), Vector2(642, 540), Vector2(900, 584), Vector2(1280, 548), Vector2(1280, 720)], Color(0.018, 0.020, 0.018, 0.98))
	for i in range(26):
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
	var x = float((index * 83) % 1240) + 18.0
	var y = float((index * 47) % 650) + 22.0
	ash.position = Vector2(x, y)
	ash.size = Vector2(2.0 + float(index % 3), 2.0 + float((index + 1) % 3))
	ash.color = Color(0.72, 0.64, 0.48, 0.18)
	menu_layer.add_child(ash)
	var tween = create_tween()
	tween.tween_property(ash, "position", ash.position + Vector2(24.0 + float(index % 5) * 5.0, -34.0), 5.0 + float(index % 7) * 0.45)
	tween.parallel().tween_property(ash, "modulate:a", 0.28, 2.0)
	tween.tween_property(ash, "modulate:a", 0.08, 1.4)

func _add_menu_button(box: VBoxContainer, text: String, callback: Callable, disabled: bool = false) -> void:
	var button = Button.new()
	button.text = text
	button.disabled = disabled
	button.custom_minimum_size = Vector2(360, 44)
	_style_button(button)
	button.mouse_entered.connect(func():
		if not button.disabled:
			menu_hovered.emit()
	)
	button.pressed.connect(func():
		menu_clicked.emit()
		callback.call()
	)
	box.add_child(button)

func _add_menu_text(box: VBoxContainer, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.72, 0.66, 0.54))
	label.add_theme_font_size_override("font_size", 15)
	box.add_child(label)

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
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 18
	style.content_margin_top = 18
	style.content_margin_right = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)

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
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.86, 0.78, 0.60))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.56))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.74, 0.36))
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.39, 0.34))
	button.add_theme_font_size_override("font_size", 18)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
