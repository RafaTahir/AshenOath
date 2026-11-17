extends "res://scripts/hud/hud_component.gd"
## Inventory panel: explicit view operations; requests leave through typed signals.

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
	if is_instance_valid(_world_atlas):
		_world_atlas.hide()
	inventory_text.show()
	_recycle_journal_buttons(_preparation_actions)
	_recycle_journal_buttons(craft_buttons)
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

func _recycle_journal_buttons(parent: Node) -> void:
	if _journal_pool_host == null:
		_journal_pool_host = Control.new()
		_journal_pool_host.hide()
		view.add_child(_journal_pool_host)
	for child in parent.get_children():
		if child is Button and child.has_meta("journal_pool_key"):
			var key := str(child.get_meta("journal_pool_key"))
			for connection: Dictionary in child.get_signal_connection_list("pressed"):
				child.disconnect("pressed", connection.callable)
			child.release_focus()
			parent.remove_child(child)
			_journal_pool_host.add_child(child)
			if _journal_buttons.has(key):
				_journal_buttons[key].queue_free()
			_journal_buttons[key] = child
		elif child is Container:
			_recycle_journal_buttons(child)
	while _journal_buttons.size() > 96:
		var key: String = _journal_buttons.keys()[0]
		_journal_buttons[key].queue_free()
		_journal_buttons.erase(key)

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
		view.get_viewport().set_input_as_handled()
		return true
	return false

func _build_growth_content(progression) -> void:
	var selected: Dictionary = _preparation_selection.get(_inventory_screen, {})
	var selected_id := str(selected.get("id", ""))
	inventory_text.text = _journal_model("growth", [progression], func(): return progression.get_summary_text())
	if progression.definitions.has(selected_id):
		var practice: Dictionary = progression.upgrade_status(selected_id)
		inventory_text.text = "LEVEL %d | %d OATH MARKS\n\n" % [progression.get_level(), int(progression.marks)] + PreparationPanel.practice_text(practice)
		var learn := _preparation_button("Already learned" if bool(practice.learned) else "Learn - 1 Oath Mark", "action:upgrade:" + selected_id, _preparation_actions, bool(practice.available))
		learn.pressed.connect(func(): upgrade_requested.emit(selected_id))
	var record := _preparation_button("Regional record", "growth:record", craft_buttons)
	record.pressed.connect(func(): _select_preparation_entry("growth", ""))
	for branch: String in progression.BRANCH_ORDER:
		_add_preparation_heading(branch.to_upper())
		for id: String in progression.ordered_upgrade_ids():
			var practice: Dictionary = progression.upgrade_status(id)
			if str(practice.branch) != branch:
				continue
			var suffix := " - Learned" if bool(practice.learned) else (" - 1 Mark" if bool(practice.available) else " - Locked")
			var button := _preparation_button(str(practice.title) + suffix, "upgrade:" + id, craft_buttons)
			button.toggle_mode = true
			button.button_pressed = selected_id == id
			button.pressed.connect(func(practice_id: String = id): _select_preparation_entry("upgrade", practice_id))
	var reason := str(_preparation_context.get("respec_reason", "Visit Greyfen's shrine bench."))
	var respec := _preparation_button("Redistribute all practices - free", "growth:respec", _preparation_actions, reason == "" and int(progression.progress_model().learned) > 0)
	respec.tooltip_text = reason if reason != "" else "Refund every learned practice. Keep your XP and equipment."
	respec.pressed.connect(func(): respec_requested.emit())
	if reason != "":
		inventory_text.text += "\n\nREDISTRIBUTION\n" + reason

func _build_preparation_content(inventory, progression, story_state, quests, notes: String) -> void:
	var category: String = str(inventory.kit_category)
	var entry_kind: String = {"equipment":"equipment", "supplies":"item", "ingredients":"ingredient"}.get(category, "item")
	var ids: Array = ["steel", "oathblade", "bow"] if category == "equipment" else (inventory.ordered_ingredient_ids() if category == "ingredients" else inventory.ordered_item_ids())
	if category == "supplies":
		ids = ids.filter(func(id: String) -> bool: return inventory.get_item_type(id) not in ["blade_upgrade", "keepsake"])
	if category == "equipment" and inventory.sort_mode == "name":
		ids = ["bow", "oathblade", "steel"]
	if category == "equipment":
		for id: String in inventory.ordered_item_ids():
			if inventory.get_item_type(id) == "keepsake" and inventory.owned_count(id) > 0:
				ids.append(id)
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
		var detail: Dictionary = _journal_model("item:" + selected_id + ":" + JSON.stringify(_preparation_context), [inventory, progression, story_state, quests], func(): return PreparationViewModel.item_detail(selected_id, inventory, progression, _preparation_context, story_state, quests))
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
			label = str({"steel":"Steel", "oathblade":"Oathblade", "bow":"Bow"}.get(item_id, inventory.get_item_name(item_id))) + (" - Equipped" if active_weapon == item_id else "")
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
		_add_preparation_heading("PRACTICE - %d OATH MARKS" % int(progression.marks))
		var growth := _preparation_button("Growth and regional record", "preparation:growth", craft_buttons)
		growth.pressed.connect(func(): _open_journal_section("growth"))
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

func _add_preparation_heading(text: String) -> void:
	var heading: Label = Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", int(round(13.0 * story_text_scale)))
	heading.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88) if high_contrast else Color(0.85, 0.77, 0.62))
	craft_buttons.add_child(heading)

func _preparation_button(text: String, key: String, parent: Container, available: bool = true) -> Button:
	var pool_key := _inventory_screen + ":" + key
	var button: Button = _journal_buttons.get(pool_key)
	if button != null:
		_journal_buttons.erase(pool_key)
		_journal_pool_host.remove_child(button)
	else:
		button = Button.new()
	button.set_meta("journal_pool_key", pool_key)
	button.text = text
	button.tooltip_text = text
	button.disabled = not available
	button.toggle_mode = false
	button.set_pressed_no_signal(false)
	button.modulate = Color.WHITE
	for side: String in ["left", "right", "top", "bottom", "next", "previous"]:
		button.set("focus_neighbor_" + side if side in ["left", "right", "top", "bottom"] else "focus_" + side, NodePath())
	for child in button.get_children():
		if child is Label:
			child.text = text
			child.add_theme_color_override("font_color", Color(0.50, 0.48, 0.43) if button.disabled else Color(0.94, 0.89, 0.77))
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.set_meta("navigation_key", key)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style_key: Array = [high_contrast, story_text_scale]
	if button.get_meta("journal_style_key", []) != style_key:
		_style_button(button)
		button.set_meta("journal_style_key", style_key)
	parent.add_child(button)
	return button

func _add_preparation_close() -> void:
	var close: Button = _preparation_button("Close", "close", craft_buttons)
	close.pressed.connect(func():
		dialogue_closed.emit()
		hide_menus()
		resume_requested.emit()
	)

func _build_inventory() -> void:
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

func _capture_inventory_state() -> void:
	if is_instance_valid(inventory_layer) and inventory_layer.visible:
		navigation.capture(_inventory_screen, "gameplay", inventory_layer)
		if _evidence_position_key != "" and _inventory_screen.begins_with("journal:"):
			_evidence_navigation.remember(_evidence_position_key, navigation.screens.get(_inventory_screen, {}))

func _restore_inventory_state(key: String, generation: int) -> void:
	await view.get_tree().process_frame
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
