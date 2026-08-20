extends SceneTree

var failures := 0

func _initialize() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/zones/campaign_wilderness_section.gd")
	check("class_name" not in source or "build(context" in source, "Deep Woods builder contract is missing")
	for zone_id in ["deep_wood", "old_mill", "burned_farmstead", "marsh_crossing"]:
		check(zone_id in source, "Missing wilderness zone: %s" % zone_id)
	check("rootbound_colossus" in source, "Rootbound Colossus route hook is missing")
	check("ashwing" in source, "Ashwing route hook is missing")
	check("make_zone_gate" in source and "make_play_area_bounds" in source, "Wilderness route safety contract is incomplete")
	var section := FileAccess.get_file_as_string("res://scripts/zones/campaign_section.gd")
	check("deep_wood" in section and "old_mill" in section and "bandit_road" in section, "Campaign route topology is incomplete")
	print("WORLD-015 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
