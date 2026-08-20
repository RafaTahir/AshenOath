extends SceneTree

var failures := 0

func _initialize() -> void:
	var castle := FileAccess.get_file_as_string("res://scripts/zones/castle_vargan_section.gd")
	var finale := FileAccess.get_file_as_string("res://scripts/zones/campaign_finale_section.gd")
	for zone_id in ["vargan_approach", "vargan_court", "record_hall"]:
		check(zone_id in castle, "Castle section is missing: %s" % zone_id)
	for zone_id in ["undercroft", "assembly", "hart_glade"]:
		check(zone_id in finale, "Finale section is missing: %s" % zone_id)
	check("RecordHallCeiling" in castle and "LedgerTableLight" in castle, "Record Hall authored interior contract is missing")
	check("AuthoredWhiteHartGlade" in finale and "WhiteHartWitnessDisplay" in finale, "Hart Glade authored focal composition is missing")
	check("make_zone_gate" in castle and "make_zone_gate" in finale, "Castle/finale route gates are incomplete")
	check("halvern_boss" in finale, "Undercroft boss hook is missing")
	print("WORLD-016 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
