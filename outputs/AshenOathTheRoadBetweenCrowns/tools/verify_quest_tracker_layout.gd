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
