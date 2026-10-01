extends SceneTree

var failures := 0

func _initialize() -> void:
	var castle := FileAccess.get_file_as_string("res://scripts/zones/castle_vargan_section.gd")
	var finale := FileAccess.get_file_as_string("res://scripts/zones/campaign_finale_section.gd")
	for zone_id in ["vargan_approach", "vargan_court", "record_hall"]:
		check(zone_id in castle, "Castle section is missing: %s" % zone_id)
	for zone_id in ["undercroft", "assembly", "hart_glade"]:
		check(zone_id in finale, "Finale section is missing: %s" % zone_id)
	check("_make_authored_record_hall_dressing" in castle and "LedgerTableLight" in castle, "Record Hall authored interior contract is missing")
	check("RecordHallVaultShell" in castle and "RecordHallStoneFloor" in castle and "castle_bookcase" in castle, "Record Hall archive composition is missing")
	check("AuthoredWhiteHartGlade" in finale and "WhiteHartWitnessDisplay" in finale, "Hart Glade authored focal composition is missing")
	check("HartGladeMossGround" in finale and "HartWitnessMoss" in finale, "Hart Glade moss terrain is missing")
	check("Three low witness rings" in finale and "forest_rock" in finale and "forest_bush" in finale, "Hart Glade witness-circle composition is missing")
	check("make_zone_gate" in castle and "make_zone_gate" in finale, "Castle/finale route gates are incomplete")
	check("halvern_boss" in finale, "Undercroft boss hook is missing")
	check("_make_authored_undercroft_dressing" in finale, "Undercroft accepted environment dressing is missing")
	check("UndercroftStoneRear" in finale and "UndercroftStoneFloor" in finale and "UndercroftStoneCeiling" in finale, "Undercroft stone enclosure is incomplete")
	check("make_collision_box" in finale, "Undercroft collision and visual ownership are not separated")
	check("context.make_pillar" not in finale, "Undercroft still uses primitive pillar geometry")
	for role in ["castle_arch", "castle_bench", "castle_lantern"]:
		check(role in finale, "Undercroft is missing accepted environment role: %s" % role)
	print("WORLD-016 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
