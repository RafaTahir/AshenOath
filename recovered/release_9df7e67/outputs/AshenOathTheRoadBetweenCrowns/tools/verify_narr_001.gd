extends SceneTree

var failures := 0

func _initialize() -> void:
	var contract = JSON.parse_string(FileAccess.get_file_as_string("res://narrative_aftermath_contract.json"))
	check(typeof(contract) == TYPE_DICTIONARY, "Narrative aftermath contract is invalid")
	check(contract.get("evidence_flags", []).size() == 5, "All five Road of Crows evidence states are not registered")
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	for required in [
		"road_evidence_bram",
		"road_evidence_sella",
		"road_evidence_oren",
		"road_evidence_vargan_wire",
		"road_evidence_drag_marks",
		"wychwood_pack_cleared",
		"func _make_narrative_aftermath",
		"WychwoodPackAshResidue",
		"GreyfenReportedNotice",
		"CemeterySettledEarth"
	]:
		check(required in game_source, "Missing persistent narrative state: %s" % required)
	var context_source := FileAccess.get_file_as_string("res://scripts/zone_build_context.gd")
	check("func make_narrative_aftermath" in context_source, "Zone context cannot apply narrative aftermath")
	for builder_path in ["res://scripts/zones/greyfen_section.gd", "res://scripts/zones/wychwood_section.gd"]:
		var builder_source := FileAccess.get_file_as_string(builder_path)
		check("context.make_narrative_aftermath()" in builder_source, "%s does not restore visible aftermath" % builder_path)
	print("NARR-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
