extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var boss_script := FileAccess.file_exists("res://scripts/boss_encounter.gd")
	if not boss_script:
		failures.append("boss encounter coordinator missing")
	else:
		var text := FileAccess.get_file_as_string("res://scripts/boss_encounter.gd")
		for needle in ["phase_changed", "checkpoint_saved", "resolve_peaceful", "save_state", "load_state"]:
			if not text.contains(needle):
				failures.append("boss coordinator missing %s" % needle)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses.json"))
	if typeof(parsed) != TYPE_DICTIONARY or parsed.size() < 5:
		failures.append("boss definitions are incomplete")
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var enemy_source := FileAccess.get_file_as_string("res://scripts/enemy_ai.gd")
	var feedback_source := FileAccess.get_file_as_string("res://scripts/combat_feedback.gd")
	for needle in ["boss_saved_states", "boss_states", "boss_defs", "boss_definition.merge", "special_attack_resolved"]:
		if not game_source.contains(needle) and not enemy_source.contains(needle):
			failures.append("runtime boss integration missing %s" % needle)
	if not feedback_source.contains("boss_attack_release"):
		failures.append("boss attack release feedback is missing")
	if failures.is_empty():
		print("PASS BOSS-002: phase, checkpoint, peaceful-resolution, and save contracts present")
		quit(0)
	else:
		for failure in failures:
			push_error("BOSS-002: %s" % failure)
		quit(1)
