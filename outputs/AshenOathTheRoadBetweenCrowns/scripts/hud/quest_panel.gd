extends "res://scripts/hud/hud_component.gd"
## Quest panel: explicit view operations; requests leave through typed signals.

func set_prompt(text: String) -> void:
	raw_prompt = text
	var clean := _format_input_text(text.strip_edges())
	if clean.begins_with("E  "):
		clean = "[E]  " + clean.trim_prefix("E  ")
	elif clean.begins_with("E - "):
		clean = "[E]  " + clean.trim_prefix("E - ")
	if prompt_label.text != clean:
		prompt_label.text = clean
	prompt_label.visible = raw_prompt != "" and not _gameplay_surface_blocked()
	if prompt_back != null:
		prompt_back.visible = prompt_label.visible
	_refresh_touch_message_visibility()

func set_interaction_prompt(model: Dictionary) -> void:
	var changed_model := model != _interaction_prompt_model
	_interaction_prompt_model = model.duplicate(true)
	if changed_model:
		interaction_prompt_changed.emit(_interaction_prompt_model.duplicate(true))
	if model.is_empty():
		set_prompt("")
		return
	var fallback := str(model.get("fallback_text", model.get("fallback", model.get("text", ""))))
	if not bool(model.get("available", true)):
		set_prompt(fallback if fallback != "" else str(model.get("subject", "")))
		return
	var binding := str(model.get("binding", ""))
	if input_source != null and input_source.has_method("describe_action"):
		var descriptor: Dictionary = input_source.describe_action("interact")
		binding = str(descriptor.get("binding", binding))
	if input_device == "touch":
		binding = ""
	var verb := str(model.get("verb", ""))
	var subject := str(model.get("subject", ""))
	if verb == "":
		set_prompt(fallback)
		return
	set_prompt("%s%s%s" % ["[" + binding + "] " if binding != "" else "", verb, " " + subject if subject != "" else ""])

func get_interaction_prompt_model() -> Dictionary:
	return _interaction_prompt_model.duplicate(true)

func set_tracker(text: String) -> void:
	if _tracker_source == text:
		return
	_tracker_source = text
	_refresh_story_focus()

func set_navigation_model(model: Dictionary) -> void:
	if model == _navigation_model:
		return
	_navigation_model = model.duplicate(true)
	_refresh_story_focus()

func _refresh_story_focus() -> void:
	if tracker_title_label == null:
		return
	var formatted := _format_tracker_text(_tracker_source)
	var lines: PackedStringArray = formatted.split("\n", false)
	var story_title := str(lines[0]).to_upper() if not lines.is_empty() else "THE ROAD AHEAD"
	var action := str(_navigation_model.get("action", ""))
	if action == "":
		action = str(lines[1]) if lines.size() > 1 else "Consult your journal for the next known lead."
	var changed_reading_size := tracker_title_label.text != story_title or tracker_label.text != action
	tracker_title_label.text = story_title
	tracker_label.text = action
	tracker_label.tooltip_text = action
	tracker_caption_label.text = "Next step"
	tracker_footer_label.text = "%s  JOURNAL" % _action_label("open_inventory")
	var route := str(_navigation_model.get("route_hint", ""))
	var destination := str(_navigation_model.get("destination", ""))
	if destination != "":
		route = "To " + destination + ("\n" + route if route != "" else "")
	var distance := int(_navigation_model.get("distance_m", -1))
	var scope := str(_navigation_model.get("scope", "exploration"))
	if distance >= 0 and scope in ["local", "aftermath"]:
		route = "%d m%s" % [distance, " · " + route if route != "" else " to the next step"]
	tracker_route_label.text = route
	var purpose := str(_navigation_model.get("purpose", ""))
	tracker_route_label.tooltip_text = route + ("\n" + purpose if purpose != "" else "")
	var work_lines: Array[String] = []
	var work: Array = _navigation_model.get("nearby_work", [])
	for index in range(mini(work.size(), 2)):
		var entry: Dictionary = work[index] if typeof(work[index]) == TYPE_DICTIONARY else {}
		var title := str(entry.get("title", ""))
		if title != "":
			work_lines.append(title)
	tracker_work_label.text = "Nearby: " + " · ".join(work_lines) if not work_lines.is_empty() else ""
	var primary := str(_navigation_model.get("primary", ""))
	if primary != "":
		compass_label.text = primary
	tracker_back.visible = action != ""
	if changed_reading_size:
		_queue_responsive_layout()

func _fit_tracker_height() -> void:
	# Preserve primary reading text; secondary guidance uses the remaining room.
	_apply_hud_layout()

func set_compass(text: String) -> void:
	if _navigation_model.is_empty():
		compass_label.text = text.replace(" | ", "   ·   ")

func set_world_navigation(snapshot: Dictionary) -> void:
	if is_instance_valid(_navigation_dial):
		_navigation_dial.call("set_snapshot", snapshot)

func set_world_clock(minutes: float, phase: String, _day_count: int = 0) -> void:
	var clock_minutes: int = posmod(int(floor(minutes)), 1440)
	var text: String = "%02d:%02d · %s" % [floori(float(clock_minutes) / 60.0), clock_minutes % 60, phase.capitalize()]
	if text == _world_clock_text:
		return
	_world_clock_text = text
	if is_instance_valid(_world_clock_label):
		_world_clock_label.text = text

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
