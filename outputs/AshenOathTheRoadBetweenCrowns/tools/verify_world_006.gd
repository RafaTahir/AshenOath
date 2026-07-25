extends SceneTree

const Finale = preload("res://scripts/zones/campaign_finale_section.gd")
var failures := 0

func _initialize() -> void:
	check(Finale.ZONES == ["undercroft", "assembly", "hart_glade"], "WORLD-006 zone registry is invalid")
	var source := FileAccess.get_file_as_string("res://scripts/zones/campaign_finale_section.gd")
	for required in [
		"AuthoredVarganUndercroft", "HalvernGuard", "halvern",
		"AuthoredGreyfenAssembly", "witnesses_ready", "assembly_choice",
		"AuthoredWhiteHartGlade", "HartWitnessLight", "white_hart"
	]:
		check(required in source, "Missing WORLD-006 feature: %s" % required)
	check(source.count("context.make_zone_gate") >= 5, "WORLD-006 route links are incomplete")
	var campaign := FileAccess.get_file_as_string("res://scripts/zones/campaign_section.gd")
	check("CampaignFinaleSection.new().build(context)" in campaign, "Campaign router does not dispatch WORLD-006")
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	check("campaign_finale_section.gd" in preset, "WORLD-006 builder is omitted from Web export")
	print("WORLD-006 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
