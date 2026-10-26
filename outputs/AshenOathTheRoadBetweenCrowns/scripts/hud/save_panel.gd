extends "res://scripts/hud/hud_component.gd"
## Save panel: explicit view operations; requests leave through typed signals.

func _save_service():
	var service = _save_manager if is_instance_valid(_save_manager) else null
	if service != null:
		if not service.library_changed.is_connected(_refresh_save_library):
			service.library_changed.connect(_refresh_save_library)
		if service.has_signal("operation_finished") and not service.operation_finished.is_connected(_on_save_operation_finished):
			service.operation_finished.connect(_on_save_operation_finished)
		if service.has_signal("durability_changed") and not service.durability_changed.is_connected(_on_save_durability_changed):
			service.durability_changed.connect(_on_save_durability_changed)
	return service

func _on_save_durability_changed(state: String, detail: String) -> void:
	if not is_instance_valid(_save_durability_notice):
		return
	_save_durability_notice.text = detail
	_save_durability_notice.visible = state != "idle" and not detail.is_empty()
	_save_durability_notice.add_theme_color_override("font_color", Color(1.0, 0.65, 0.5) if state == "failed" else Color.WHITE if high_contrast else HudVisualStyle.GOLD)

func _on_save_operation_finished(slot_id: String, operation: String, success: bool, text: String) -> void:
	if slot_id != "":
		_slot_operation_results[slot_id] = text
	if success and operation in ["import", "restore"] and active_menu == "save_slot" and selected_slot == slot_id:
		var field := menu_layer.find_child("SaveSlotName", true, false) as LineEdit
		for slot in _save_service().list_slots():
			if str(slot.id) == slot_id and field != null:
				field.text = str(slot.title)
	if active_menu != "save_slot" or selected_slot != slot_id:
		post_notice(text, "save" if success else "error", 5.0, "save_operation:" + operation + ":" + slot_id)
	elif is_instance_valid(_save_slot_notice):
		_save_slot_notice.text = text
	if success and operation == "import" and active_menu == "save_import":
		_return_after_import = true
	_refresh_save_library()

func show_save_library(back_target: String = "pause", requested_page: int = 0) -> void:
	library_back_target = back_target
	library_page = maxi(0, requested_page)
	active_menu = "save_library"
	_set_internal_canvas(Vector2i(MENU_SIZE))
	_set_ui_pointer("pause")
	_clear_menu()
	menu_layer.visible = true
	var box: VBoxContainer = _menu_box("Saved Journeys", "The road you remember", "manual saves and protected checkpoints")
	box.set_meta("compact_buttons", true)
	var service = _save_service()
	if service == null:
		_add_menu_text(box, "Save storage is preparing.")
		_add_menu_button(box, "Back", _return_from_library)
		return
	var slots: Array = service.list_slots()
	var pages: int = maxi(1, ceili(float(slots.size()) / 4.0))
	library_page = clampi(requested_page, 0, pages - 1)
	_add_menu_text(box, "Page %d of %d. Open a journey to read its recorded promise and next step." % [library_page + 1, pages])
	for index: int in range(library_page * 4, mini(slots.size(), library_page * 4 + 4)):
		var slot: Dictionary = slots[index]
		_add_menu_button(box, JourneyMenuPanel.slot_row(slot), func(id: String = str(slot.get("id", ""))): show_save_slot(id), false, "slot:" + str(slot.get("id", "")))
	_add_menu_button(box, "Previous Page", func(): show_save_library(library_back_target, library_page - 1), library_page <= 0, "previous_page")
	_add_menu_button(box, "Next Page", func(): show_save_library(library_back_target, library_page + 1), library_page >= pages - 1, "next_page")
	_add_menu_text(box, "Browser saves belong to this browser and device. Export a JSON copy to keep or move a journey.")
	_add_menu_button(box, "Import a Save File", func(): service.request_import_file(), false, "import_file")
	_add_menu_button(box, "Paste a Save", show_save_import)
	_add_menu_button(box, "Chapter Replay", show_chapter_replays, service.chapter_replays().is_empty())
	_add_menu_button(box, "Back", _return_from_library)

func _refresh_save_library() -> void:
	if _library_refresh_pending:
		return
	_library_refresh_pending = true
	view.call_deferred("_flush_library_refresh")

func _flush_library_refresh() -> void:
	_library_refresh_pending = false
	if _return_after_import:
		_return_after_import = false
		show_save_library(library_back_target, 0)
	elif active_menu == "save_library":
		show_save_library(library_back_target, library_page)
	elif active_menu == "save_slot":
		show_save_slot(selected_slot)

func show_save_slot(slot_id: String) -> void:
	selected_slot = slot_id
	active_menu = "save_slot"
	_clear_menu()
	var service = _save_service()
	var slot: Dictionary = {}
	for candidate: Dictionary in service.list_slots():
		if str(candidate.get("id", "")) == slot_id:
			slot = candidate
	if slot.is_empty():
		show_save_library(library_back_target, library_page)
		return
	var box: VBoxContainer = _menu_box(str(slot.get("title", "Journey")), JourneyMenuPanel.status_text(str(slot.get("status", "empty"))), "recorded journey")
	box.set_meta("compact_buttons", true)
	_set_journey_card_text(JourneyMenuPanel.card(slot))
	var title: LineEdit = LineEdit.new()
	if not bool(slot.get("protected", false)):
		title.text = str(slot.get("title", "Journey"))
		title.name = "SaveSlotName"
		_register_field(title, "slot_name", title.text)
		title.max_length = 48
		title.placeholder_text = "Name this journey"
		title.custom_minimum_size = Vector2(320, 52)
		title.focus_mode = Control.FOCUS_ALL
		box.add_child(title)
	else:
		title.queue_free()
	_save_slot_notice = _add_menu_text(box, str(_slot_operation_results.get(slot_id, "")))
	_save_slot_notice.custom_minimum_size.y = 62.0
	_add_journey_load_button(box, "Load Previous Copy" if str(slot.get("status", "")) == "recoverable" else "Load This Journey", slot, "load_slot:" + slot_id)
	_add_journey_recovery_options(box, slot)
	if not bool(slot.get("protected", false)):
		var can_save: bool = is_instance_valid(_game_owner) and _game_owner.get("game_started") == true and is_instance_valid(_game_owner.get("player"))
		_add_menu_button(box, "Replace With Current Journey" if bool(slot.get("exists", false)) else "Save Current Journey Here", func(): service.save_named(_game_owner, slot_id, title.text), not can_save, "save_current")
		_add_menu_button(box, "Rename", func(): service.rename_slot(slot_id, title.text), not bool(slot.get("valid", false)), "rename")
		_add_menu_button(box, "Restore Previous Slot Copy", func(): service.restore_previous_slot(slot_id), not bool(slot.get("backup_available", false)), "restore_previous")
		_add_menu_button(box, "Import File Into This Slot", func(): service.request_import_file(slot_id), false, "import_slot")
		_add_menu_text(box, "Replacing or importing here retains the previous slot copy. Export first to keep more than one earlier version.")
	else:
		_add_menu_text(box, "This protected record can be loaded or exported. The game manages when it is written.")
	_add_menu_button(box, "Export This Journey", func(): service.export_slot(slot_id), not bool(slot.get("valid", false)), "export_slot")
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
	_register_field(input, "import_json", "")
	box.add_child(input)
	_add_menu_button(box, "Import Into an Empty Slot", func():
		_save_service().import_save_text(input.text)
	)
	_add_menu_button(box, "Back", func(): show_save_library(library_back_target, library_page))

func show_chapter_replays() -> void:
	active_menu = "chapter_replay"
	_clear_menu()
	var box: VBoxContainer = _menu_box("Return to a Chapter", "A copied journey", "your completed outcome is preserved")
	_add_menu_text(box, "Replay begins from a recorded chapter checkpoint. It uses separate automatic saves; a manual save can preserve it as another journey.")
	for chapter: Dictionary in _save_service().chapter_replays():
		_add_journey_load_button(box, JourneyMenuPanel.slot_row(chapter), chapter, "replay:" + str(chapter.get("id", "")))
		if not bool(chapter.get("available", false)):
			_add_menu_text(box, str(chapter.get("reason", "This chapter record is unavailable.")))
	_add_menu_button(box, "Back", func(): show_save_library(library_back_target, library_page))

func _return_from_library() -> void:
	_return_to_parent()

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
	_register_field(description, "problem_description", "")
	box.add_child(description)
	_add_menu_button(box, "Download Problem Report", func(): _download_problem_report(description.text))
	_add_menu_button(box, "Back", _return_from_library)

func _download_problem_report(description: String) -> void:
	var game = _game_owner
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
