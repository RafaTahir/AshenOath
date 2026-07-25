extends SceneTree

const BanditRoad = preload("res://scripts/zones/bandit_road_section.gd")
const Castle = preload("res://scripts/zones/castle_vargan_section.gd")
var failures := 0

func _initialize() -> void:
	check(BanditRoad.ZONES == ["bandit_road"], "WORLD-005 bandit-road registry is invalid")
	check(Castle.CASTLE_ZONES == ["vargan_approach", "vargan_court", "record_hall"], "Castle route registry is incomplete")
	var road := FileAccess.get_file_as_string("res://scripts/zones/bandit_road_section.gd")
	for required in ["AuthoredBanditRoad", "CommandTent", "captain_senn", "senn_guard", "Follow the Vargan road"]:
		check(required in road, "Missing bandit-road feature: %s" % required)
	check(road.count("context.make_zone_gate") == 2, "Bandit road must have one bidirectional gate pair")
	var castle := FileAccess.get_file_as_string("res://scripts/zones/castle_vargan_section.gd")
	for required in ["CastleVargan_%s", "\"Approach\"", "\"OuterCourtyard\"", "\"RecordHall\"", "vargan_gate_guard", "vargan_ledger_choice", "RecordHallHaunting"]:
		check(required in castle, "Missing Castle Vargan feature: %s" % required)
	var campaign := FileAccess.get_file_as_string("res://scripts/zones/campaign_section.gd")
	check("BanditRoadSection.new().build(context)" in campaign, "Campaign router does not dispatch WORLD-005")
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	check("bandit_road_section.gd" in preset, "WORLD-005 builder is omitted from Web export")
	print("WORLD-005 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
