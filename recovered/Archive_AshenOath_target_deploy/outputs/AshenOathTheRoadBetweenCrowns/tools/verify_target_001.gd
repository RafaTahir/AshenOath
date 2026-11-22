extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var camera := FileAccess.get_file_as_string("res://scripts/camera_controller.gd")
	var input := FileAccess.get_file_as_string("res://scripts/input_router.gd")
	for needle in [
		"_locked_combat_target", "_cycle_combat_target", "_target_is_visible",
		"_target_query_exclusions", "TARGET_OBSTRUCTION_GRACE",
		"_soft_frame_locked_target", "get_locked_combat_target", "clear_target_lock",
		"target_lock_changed"
	]:
		if not camera.contains(needle):
			failures.append("camera missing %s" % needle)
	for needle in [
		"target_lock", "JOY_BUTTON_RIGHT_STICK", "target_next", "target_previous",
		"JOY_AXIS_RIGHT_X"
	]:
		if not input.contains(needle):
			failures.append("input router missing %s" % needle)
	if not camera.contains("is_encounter_active"):
		failures.append("camera does not filter dormant encounter actors")
	if not input.contains("gamepad_action_label"):
		failures.append("input router does not expose controller target labels")
	if failures.is_empty():
		print("PASS TARGET-001: optional lock-on and controller target selection present")
		quit(0)
	else:
		for failure in failures:
			push_error("TARGET-001: %s" % failure)
		quit(1)
