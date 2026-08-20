extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var text := FileAccess.get_file_as_string("res://scripts/enemy_ai.gd")
	var failures: Array[String] = []
	for needle in ["_crowd_separation", "_attack_lane_clear", "_navigation_direction", "_claim_attack_token", "is_boss", "parry_exposed_time"]:
		if not text.contains(needle):
			failures.append("missing tactical control %s" % needle)
	if failures.is_empty():
		print("PASS AI-003: navigation, spacing, reservations, parry exposure, and boss profiles present")
		quit(0)
	else:
		for failure in failures:
			push_error("AI-003: %s" % failure)
		quit(1)
