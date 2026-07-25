extends SceneTree

const Wilderness = preload("res://scripts/zones/campaign_wilderness_section.gd")
var failures := 0

func _initialize() -> void:
	check(Wilderness.ZONES == ["deep_wood", "old_mill", "burned_farmstead", "marsh_crossing"], "WORLD-004 zone registry is incomplete")
	var source := FileAccess.get_file_as_string("res://scripts/zones/campaign_wilderness_section.gd")
	for required in [
		"AuthoredDeepWood",
		"AuthoredAshMill",
		"AuthoredBurnedFarmstead",
		"AuthoredMarshCrossing",
		"millstones",
		"register_rook",
		"register_mira",
		"bog_core_choice"
	]:
		check(required in source, "Missing wilderness content: %s" % required)
	check(source.count("context.make_zone_gate") == 2, "Wilderness route does not use one bidirectional gate pair")
	var campaign := FileAccess.get_file_as_string("res://scripts/zones/campaign_section.gd")
	check("CampaignWildernessSection.new().build(context)" in campaign, "Campaign router does not dispatch to WORLD-004")
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	check("campaign_wilderness_section.gd" in preset, "WORLD-004 builder is omitted from Web export")
	print("WORLD-004 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
