extends RefCounted

static func apply(hud: Node, origin: Vector2, quest_width: float, room_below: float, unit: float, fonts: Dictionary, compact: bool, touch: bool) -> void:
	var quest_x: float = origin.x
	var quest_y: float = origin.y
	hud.tracker_title_label.add_theme_font_size_override("font_size", int(fonts.body))
	hud.tracker_title_label.size.x = quest_width
	var title_height: float = maxf((42.0 if not compact else 25.0) * unit, hud._hud_text_height(hud.tracker_title_label, 2) + 2.0 * unit)
	hud.tracker_label.add_theme_font_size_override("font_size", int(fonts.body))
	hud.tracker_label.size.x = maxf(0.0, quest_width - 22.0 * unit)
	hud.tracker_label.max_lines_visible = -1
	var minimum_line: float = hud._hud_text_height(hud.tracker_label, 1)
	var action_needed: float = hud._hud_text_height(hud.tracker_label) + 2.0 * unit
	var show_title := (not compact or room_below >= 140.0 * unit) and title_height + 13.0 * unit + action_needed <= room_below
	hud.tracker_title_label.visible = show_title
	hud.tracker_title_label.position = Vector2(quest_x, quest_y)
	hud.tracker_title_label.size = Vector2(quest_width, title_height)
	hud.tracker_caption_label.visible = false
	hud._quest_rule.visible = show_title
	hud._quest_rule.position = Vector2(quest_x, quest_y + title_height + 2.0 * unit)
	hud._quest_rule.size = Vector2(minf(90.0 * unit, quest_width), maxf(1.0, unit))
	var action_y: float = quest_y + title_height + 13.0 * unit if show_title else quest_y
	var action_room := maxf(0.0, quest_y + room_below - action_y)
	var action_lines: int = hud._fit_hud_lines(hud.tracker_label, action_room, hud.tracker_label.get_line_count())
	var action_height := minf(action_room, hud._hud_text_height(hud.tracker_label, action_lines) + 2.0 * unit)
	hud.tracker_label.visible = action_room >= minimum_line and hud.tracker_label.text != ""
	hud.tracker_label.max_lines_visible = action_lines
	hud._quest_marker.visible = hud.tracker_label.visible
	hud._quest_marker.position = Vector2(quest_x - 2.0 * unit, action_y + 2.0 * unit)
	hud._quest_marker.size = Vector2(20.0 * unit, 24.0 * unit)
	hud._quest_marker.add_theme_font_size_override("font_size", int(fonts.caption))
	hud.tracker_label.position = Vector2(quest_x + 22.0 * unit, action_y)
	hud.tracker_label.size = Vector2(maxf(0.0, quest_width - 22.0 * unit), action_height)
	var route_y: float = action_y + action_height + 5.0 * unit
	for label: Label in [hud.tracker_route_label, hud.tracker_work_label, hud.tracker_footer_label]:
		label.add_theme_font_size_override("font_size", int(fonts.caption))
	# Reserve complete caption lines, including the active font's metrics and spacing.
	hud.tracker_route_label.text = hud.view.quest_panel.route_caption(compact)
	hud.tracker_route_label.max_lines_visible = 1 if compact else 2
	var route_height: float = hud._hud_text_height(hud.tracker_route_label, hud.tracker_route_label.max_lines_visible) + 2.0 * unit
	var work_height: float = hud._hud_text_height(hud.tracker_work_label, 2) + 2.0 * unit
	var footer_height: float = hud._hud_text_height(hud.tracker_footer_label, 1) + 2.0 * unit
	var panel_end := action_y + action_height
	hud.tracker_route_label.position = Vector2(quest_x + 22.0 * unit, route_y)
	hud.tracker_route_label.size = Vector2(quest_width - 22.0 * unit, route_height)
	hud.tracker_route_label.visible = hud.tracker_label.visible and hud.tracker_route_label.text != "" and route_y + route_height <= quest_y + room_below
	if hud.tracker_route_label.visible: panel_end = route_y + route_height
	var work_y := panel_end + 2.0 * unit
	hud.tracker_work_label.position = Vector2(quest_x + 22.0 * unit, work_y)
	hud.tracker_work_label.size = Vector2(quest_width - 22.0 * unit, work_height)
	hud.tracker_work_label.visible = hud.tracker_label.visible and not compact and hud.tracker_work_label.text != "" and work_y + work_height <= quest_y + room_below
	if hud.tracker_work_label.visible: panel_end = work_y + work_height
	var footer_y := panel_end + 4.0 * unit
	hud.tracker_footer_label.position = Vector2(quest_x + 22.0 * unit, footer_y)
	hud.tracker_footer_label.size = Vector2(quest_width - 22.0 * unit, footer_height)
	hud.tracker_footer_label.visible = hud.tracker_label.visible and not compact and not touch and footer_y + footer_height <= quest_y + room_below
	if hud.tracker_footer_label.visible: panel_end = footer_y + footer_height
	hud.tracker_back.position = Vector2(quest_x - 8.0 * unit, quest_y - 6.0 * unit)
	hud.tracker_back.size = Vector2(quest_width + 16.0 * unit, panel_end - quest_y + 6.0 * unit)
	hud.tracker_back.visible = hud.tracker_label.visible

static func caption(model: Dictionary, compact: bool) -> String:
	var route := str(model.get("route_hint", ""))
	var destination := str(model.get("destination", ""))
	if destination != "":
		if compact: return str(model.get("route_short", destination))
		return "To " + destination + ("\n" + route if route != "" else "")
	var distance := int(model.get("distance_m", -1))
	var scope := str(model.get("scope", "exploration"))
	if distance >= 0 and scope in ["local", "aftermath"]:
		if compact: return "%d m" % distance
		return "%d m%s" % [distance, " · " + route if route != "" else " to the next step"]
	return route
