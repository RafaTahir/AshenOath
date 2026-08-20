extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_file("res://scripts/combat_manager.gd")
	_check_file("res://scripts/combat_feedback.gd")
	var manager := FileAccess.get_file_as_string("res://scripts/combat_manager.gd")
	var feedback := FileAccess.get_file_as_string("res://scripts/combat_feedback.gd")
	_require(manager, "signal contact_resolved", "combat manager must expose an authoritative contact signal")
	_require(manager, "previous_base", "blade contact must retain the previous base transform")
	_require(manager, "previous_tip", "blade contact must retain the previous tip transform")
	_require(manager, "contact_point", "blade contact must return the resolved point")
	_require(manager, "blade_contact_distance", "blade contact must report distance from the measured sweep")
	_require(manager, "sweep_length", "blade contact must report measured blade travel")
	_require(manager, "contact_phase", "blade contact must preserve the animation contact phase")
	_require(feedback, "weapon_contact", "combat feedback must be driven by the measured blade contact")
	_require(feedback, "BladeContactFlash", "contact feedback must create a named readable effect")
	_require(feedback, "BladeSweepRibbon", "combat feedback must show the measured blade travel")
	_require(feedback, "contact_override", "parry feedback must be placeable at the weapon contact point")
	_report("COMBAT-005")

func _check_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		failures.append("missing %s" % path)

func _require(text: String, needle: String, message: String) -> void:
	if not text.contains(needle):
		failures.append(message)

func _report(label: String) -> void:
	if failures.is_empty():
		print("PASS %s: contact-driven sword contract present" % label)
		quit(0)
	else:
		for failure in failures:
			push_error("%s: %s" % [label, failure])
		quit(1)
