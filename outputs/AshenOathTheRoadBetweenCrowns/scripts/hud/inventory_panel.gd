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

func _journal_source_key(source) -> String:
	if not is_instance_valid(source):
		return "none"
	var id: int = source.get_instance_id()
	if not _journal_source_revisions.has(id):
		_journal_source_revisions[id] = 0
		if source.has_signal("changed"):
			source.connect("changed", _journal_source_changed.bind(id))
	return "%d:%d" % [id, int(_journal_source_revisions[id])]

func _journal_source_changed(id: int) -> void:
	_journal_source_revisions[id] = int(_journal_source_revisions.get(id, 0)) + 1

func _journal_model(key: String, sources: Array, build: Callable) -> Variant:
	for source in sources:
		key += "|" + _journal_source_key(source)
	if not _journal_models.has(key):
		if _journal_models.size() >= 32:
			_journal_models.erase(_journal_models.keys()[0])
		_journal_models[key] = build.call()
	var model: Variant = _journal_models[key]
	return model.duplicate(true) if model is Array or model is Dictionary else model

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

func show_inventory(inventory, quests, story_state = null, progression = null, requested_section: String = "") -> void:
	prepare_gameplay_ui()
	if is_instance_valid(_game_owner): preload("res://scripts/greyfen_guidance.gd").learn(_game_owner, "journal")
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
	var sections: Array[Dictionary] = _journal_model("sections:" + zone_id, [quests, story_state], func(): return StoryJournalPresenter.sections(quests, story_state, zone_id))
	if progression != null:
		sections.append({"id":"growth", "title":"Growth", "body":_journal_model("growth", [progression], func(): return progression.get_summary_text()), "entries":[]})
	sections.append({"id":"quest_record", "title":"Quest Record", "body":_journal_model("quest_record", [quests], func(): return str(quests.get_journal_text())), "entries":[]})
	if story_state != null:
		sections.append({"id":"greyfen_guide", "title":"Before the Road", "body":preload("res://scripts/greyfen_guidance.gd").journal(story_state), "entries":[]})
	sections.append({"id":"atlas","title":"Road Atlas","body":"","entries":[]})
	var current_section: Dictionary = {}
	for section: Dictionary in sections:
		if str(section.get("id", "")) == _journal_section_id:
			current_section = section
	if current_section.is_empty() and not sections.is_empty():
		current_section = sections[0]
		_journal_section_id = str(current_section.get("id", "return"))
		_inventory_screen = "journal:" + _journal_section_id
	var preparing: bool = _journal_section_id == "preparation"
	var growing: bool = _journal_section_id == "growth" and progression != null
	var evidence: bool = _journal_section_id == "evidence"
	var reference: Dictionary = {}
	if _evidence_reference_section == _journal_section_id and _evidence_reference_entry != "":
		reference = _journal_entry_from_sections(sections, _evidence_reference_section, _evidence_reference_entry)
		if reference.is_empty():
			_evidence_reference_section = ""
			_evidence_reference_entry = ""
			_evidence_navigation.clear_returns()
	var linked: bool = not reference.is_empty()
	_prepare_inventory_surface(preparing or growing or evidence or linked)
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
	elif growing:
		_build_growth_content(progression)
	elif _journal_section_id == "atlas":
		inventory_text.hide()
		if is_instance_valid(_world_atlas):
			_journal_column.remove_child(_world_atlas); _world_atlas.queue_free()
		_world_atlas = preload("res://scripts/world_atlas.gd").new()
		_world_atlas.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_journal_column.add_child(_world_atlas)
		_journal_column.move_child(_world_atlas,inventory_text.get_index()+1)
		var known: Dictionary = _game_owner.seamless_world.discovered_sectors if is_instance_valid(_game_owner) and _game_owner.seamless_world != null else {}
		_world_atlas.configure(zone_id,known)
	elif not evidence:
		inventory_text.text = reading
	_add_preparation_heading("JOURNAL")
	if _journal_section_id == "greyfen_guide" and story_state != null and is_instance_valid(_game_owner):
		var guide_active := str(story_state.get_flag("greyfen_guide", "")) == "active"
		var guide_button := _preparation_button("Pause village guidance" if guide_active else "Resume village guidance", "guide_mode", craft_buttons)
		guide_button.pressed.connect(func(): preload("res://scripts/greyfen_guidance.gd").set_mode(_game_owner,"paused" if guide_active else "active"))
	if current_section.has("meter"):
		var honor_meter := ProgressBar.new()
		honor_meter.min_value = -100
		honor_meter.max_value = 100
		honor_meter.value = int(current_section.meter)
		honor_meter.show_percentage = false
		honor_meter.custom_minimum_size.y = 12
		honor_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		craft_buttons.add_child(honor_meter)
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
	view.call_deferred("_restore_inventory_state", _inventory_screen, _inventory_generation)

func _journal_zone_id() -> String:
	var zone_id: String = str(_preparation_context.get("zone_id", ""))
	if is_instance_valid(_game_owner):
		zone_id = str(_game_owner.get("current_zone_id"))
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
	var model: Dictionary = _journal_model("evidence:" + zone_id, [quests, state], func(): return StoryJournalPresenter.evidence_model(quests, state, zone_id))
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
		detail = _journal_model("evidence_detail:" + str(_evidence_navigation.selected_id) + ":" + zone_id, [quests, state], func(): return StoryJournalPresenter.evidence_detail(str(_evidence_navigation.selected_id), quests, state, zone_id))
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
	var focused: Control = view.get_viewport().gui_get_focus_owner()
	if direction < 0 and focused != inventory_text and focused != null and inventory_layer.is_ancestor_of(focused):
		inventory_text.grab_focus()
		view.get_viewport().set_input_as_handled()
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
				view.get_viewport().set_input_as_handled()
				return true
			if control_key == fallback_key:
				fallback = control
		if fallback != null:
			fallback.grab_focus()
			view.get_viewport().set_input_as_handled()
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

func show_vendor(vendor_id: String, vendor_service, inventory, quests = null, story_state = null) -> void:
	prepare_gameplay_ui()
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
	var stock: Array[Dictionary] = _journal_model("vendor:" + vendor_id, [vendor_service, inventory, story_state, quests], func(): return vendor_service.list_stock(vendor_id, inventory, story_state, quests, true))
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
		if is_instance_valid(_game_owner):
			preparation_progression = _game_owner.get("progression") if is_instance_valid(_game_owner) else null
		var detail: Dictionary = PreparationViewModel.item_detail(received_id, inventory, preparation_progression, _preparation_context, story_state, quests)
		detail["actions"] = []
		inventory_text.text = heading + PreparationPanel.item_text(detail) + "\n" + PreparationPanel.purchase_text(quote)
		var emergency: bool = selected_id.begins_with("__emergency")
		var purchase_label: String = "Claim emergency reserve" if emergency else ("Fit · %d coin" % int(quote.get("total_price", 0)) if bool(quote.get("upgrade", false)) else "Buy %d · %d coin" % [int(quote.get("quantity", 1)), int(quote.get("total_price", 0))])
		if not bool(quote.get("ok", false)):
			purchase_label = "Already fitted" if bool(quote.get("upgrade", false)) and int(quote.get("owned", 0)) > 0 else "Unavailable"
		var buy: Button = _preparation_button(purchase_label, "action:buy:" + selected_id, _preparation_actions, bool(quote.get("ok", false)))
		buy.pressed.connect(func(id_value: String = selected_id): vendor_purchase_requested.emit(vendor_id, id_value, 1))
		if not emergency and not bool(quote.get("upgrade",false)):
			var five: Dictionary = vendor_service.quote(vendor_id,selected_id,5,inventory,story_state,quests)
			if bool(five.get("ok",false)) and int(five.get("quantity",0)) == 5:
				var bundle := _preparation_button("Buy 5 · %d coin" % int(five.total_price),"action:buy5:"+selected_id,_preparation_actions)
				bundle.pressed.connect(func(id_value: String = selected_id): vendor_purchase_requested.emit(vendor_id,id_value,5))
	_add_preparation_heading("SUPPLIES AND SERVICES")
	for request_id: String in request_ids:
		var title: String = "Emergency arrows" if request_id == "__emergency_arrows__" else ("Emergency medicine" if request_id == "__emergency_healing__" else str(inventory.get_item_name(request_id)))
		var entry_button: Button = _preparation_button(title, "item:" + request_id, craft_buttons)
		entry_button.toggle_mode = true
		entry_button.button_pressed = selected_id == request_id
		entry_button.pressed.connect(func(id_value: String = request_id): _select_preparation_entry("item", id_value))
	var surplus: Array[Dictionary] = vendor_service.list_surplus(vendor_id,inventory)
	if not surplus.is_empty():
		_add_preparation_heading("SELL SURPLUS · ROAD RESERVES RETAINED")
		for offer: Dictionary in surplus:
			var item_id: String = str(offer.item_id)
			var sale := _preparation_button("Sell 1 %s · +%d coin" % [inventory.get_item_name(item_id),int(offer.unit_price)],"action:sell:"+item_id,craft_buttons)
			sale.tooltip_text = str(offer.message)
			sale.pressed.connect(func(id_value: String = item_id): vendor_sale_requested.emit(vendor_id,id_value,1))
	_add_preparation_close()
	_queue_responsive_layout()
	view.call_deferred("_restore_inventory_state", _inventory_screen, _inventory_generation)

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

func _show_journal_art(quests, state) -> void:
	if journal_art == null:
		return
	var path := "res://assets_external/ui/greyfen_menu_stylized.png"
	if not ResourceLoader.exists(path):
		journal_art.visible = false
		return
	var image := load(path) as Texture2D
	if image == null:
		return
	journal_art.texture = image
	journal_art.visible = true
