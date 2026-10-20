extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var beats = load("res://scripts/quest_beat_director.gd")
	_check("clues" in str(beats.BEATS.main_road_of_crows.evidence_ready.next).to_lower(), "Investigation beat must request clues before combat")
	var hud = load("res://scripts/hud.gd").new()
	root.add_child(hud)
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport_size
		hud.set_tracker("ROAD OF CROWS\n- Inspect the clues along the Wychwood road and identify what happened to the missing villagers.")
		await process_frame
		await process_frame
		var label: Label = hud.tracker_label
		var needed := label.get_line_count() * label.get_line_height()
		_check(label.size.y >= needed and label.get_visible_line_count() == label.get_line_count(), "Wrapped objective clipped at %s: %d/%d visible, %s < %s" % [viewport_size, label.get_visible_line_count(), label.get_line_count(), label.size.y, needed])
		_check(hud.tracker_back.get_global_rect().encloses(label.get_global_rect()), "Tracker backdrop does not contain objective")
		_check(label.get_global_rect().end.x <= viewport_size.x, "Tracker extends beyond viewport")
		for text_scale in [1.0, 1.5]:
			hud.apply_accessibility({"subtitle_scale": text_scale})
			hud.set_navigation_model({"action": "Explore Greyfen or choose a known promise in the journal", "route_hint": "Marked wayposts remember the roads you have walked.", "nearby_work": [{"title": "The Baker's Last Sack"}]})
			hud.set_prompt("E  Visit the changed work at Deep Woods and the Mill")
			hud._apply_hud_layout()
			await process_frame
			await process_frame
			var route: Label = hud.tracker_route_label
			if route.visible:
				var route_needed := mini(route.get_line_count(), route.max_lines_visible) * route.get_line_height()
				_check(route.size.y >= route_needed, "Route caption clips complete lines at %s / %s: %s < %s" % [viewport_size, text_scale, route.size.y, route_needed])
				_check(route.get_visible_line_count() == mini(route.get_line_count(), route.max_lines_visible), "Route caption loses its second line")
			if hud.tracker_work_label.visible:
				_check(route.get_global_rect().end.y <= hud.tracker_work_label.get_global_rect().position.y, "Route caption overlaps nearby work")
			if hud.tracker_footer_label.visible:
				_check(hud.tracker_work_label.get_global_rect().end.y <= hud.tracker_footer_label.get_global_rect().position.y, "Nearby work overlaps journal binding")
			_check(hud.prompt_label.get_visible_line_count() == mini(2, hud.prompt_label.get_line_count()), "Interaction prompt clips a reserved line")
			_check(hud.prompt_label.get_global_rect().end.y <= viewport_size.y, "Interaction prompt leaves the viewport")
			_check(hud.status_label.get_global_rect().end.y <= hud.prompt_label.get_global_rect().position.y, "Combat status overlaps the interaction prompt")
		hud.apply_accessibility({"subtitle_scale": 1.0})
		hud.set_navigation_model({})
	hud.queue_free()
	await process_frame
	if failures.is_empty():
		print("QUEST TRACKER LAYOUT: PASS")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
