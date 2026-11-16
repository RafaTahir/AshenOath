extends "res://scripts/hud/hud_component.gd"
func _build_evidence_content(quests: Variant, state: Variant, zone_id: String, sections: Array) -> void:
	var model: Dictionary = _journal_model("evidence:" + zone_id, [quests, state], func() -> Variant: return StoryJournalPresenter.evidence_model(quests, state, zone_id))
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
		detail = _journal_model("evidence_detail:" + str(_evidence_navigation.selected_id) + ":" + zone_id, [quests, state], func() -> Variant: return StoryJournalPresenter.evidence_detail(str(_evidence_navigation.selected_id), quests, state, zone_id))
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
			button.pressed.connect(func(reference: Dictionary = link) -> void: _open_evidence_reference(reference))
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
		button.pressed.connect(func(filter_id: String = id) -> void: _select_evidence_filter(filter_id))
	for entry: Dictionary in filtered:
		var id: String = str(entry.get("id", ""))
		var place: String = str(entry.get("place", ""))
		var text: String = str(entry.get("title", "Record")) + "\n" + str(entry.get("kind_label", "Account")) + (" · " + place if place != "" else "")
		var button: Button = _preparation_button(text, "evidence_entry:" + id, craft_buttons)
		button.toggle_mode = true
		button.button_pressed = id == str(_evidence_navigation.selected_id)
		button.pressed.connect(func(entry_id: String = id) -> void: _select_evidence_entry(entry_id))

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
		back.pressed.connect(func() -> void: _back_from_evidence_reading())
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
			var control_key: String = str(read_tag(control, "navigation_key", ""))
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
