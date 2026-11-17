extends "res://scripts/hud/hud_component.gd"
func _journal_source_key(source: Variant) -> String:
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
		_journal_models[key] = build.callv([])
	var model: Variant = _journal_models[key]
	return model.duplicate(true) if model is Array or model is Dictionary else model

func show_inventory(inventory: Variant, quests: Variant, story_state: Variant = null, progression: Variant = null, requested_section: String = "") -> void:
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
	var sections: Array[Dictionary] = _journal_model("sections:" + zone_id, [quests, story_state], func() -> Variant: return StoryJournalPresenter.sections(quests, story_state, zone_id))
	if progression != null:
		sections.append({"id":"growth", "title":"Growth", "body":_journal_model("growth", [progression], func() -> Variant: return progression.get_summary_text()), "entries":[]})
	sections.append({"id":"quest_record", "title":"Quest Record", "body":_journal_model("quest_record", [quests], func() -> Variant: return str(quests.get_journal_text())), "entries":[]})
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
			source.pressed.connect(func(target: Dictionary = link) -> void: _open_evidence_reference(target))
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
		_world_atlas.configure(zone_id,known,preload("res://scripts/campaign_revision.gd").from_state(story_state))
	elif not evidence:
		inventory_text.text = reading
	_add_preparation_heading("JOURNAL")
	if _journal_section_id == "greyfen_guide" and story_state != null and is_instance_valid(_game_owner):
		var guide_active: Variant = str(story_state.get_flag("greyfen_guide", "")) == "active"
		var guide_button: Variant = _preparation_button("Pause village guidance" if guide_active else "Resume village guidance", "guide_mode", craft_buttons)
		guide_button.pressed.connect(func() -> void: preload("res://scripts/greyfen_guidance.gd").set_mode(_game_owner,"paused" if guide_active else "active"))
	if current_section.has("meter"):
		var honor_meter: Variant = ProgressBar.new()
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
		section_button.pressed.connect(func(id_value: String = section_id) -> void: _open_journal_section(id_value))
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
				entry_button.pressed.connect(func(id_value: String = entry_id) -> void: _open_evidence_reference({"section_id":"creatures", "entry_id":id_value}))
				continue
			entry_button.pressed.connect(func(paragraph: int = int(paragraph_by_entry.get(entry_id, 0))) -> void:
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

func _show_journal_art(quests: Variant, state: Variant) -> void:
	if journal_art == null:
		return
	var path: Variant = "res://assets_external/ui/greyfen_menu_stylized.png"
	if not ResourceLoader.exists(path):
		journal_art.visible = false
		return
	var image: Variant = load(path) as Texture2D
	if image == null:
		return
	journal_art.texture = image
	journal_art.visible = true
