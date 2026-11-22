extends SceneTree

const ZoneCompositionRouter = preload("res://scripts/zone_composition_router.gd")

const RELEASED_BUILDERS: Array[String] = [
	"res://scripts/zones/greyfen_section.gd",
	"res://scripts/zones/wychwood_section.gd",
	"res://scripts/zones/cemetery_section.gd",
	"res://scripts/zones/river_section.gd",
	"res://scripts/zones/ruins_section.gd",
	"res://scripts/zones/campaign_section.gd",
	"res://scripts/zones/castle_vargan_section.gd",
]

var failures := 0

func _initialize() -> void:
	_verify_static_contract()
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "Main scene is unavailable")
	if scene == null:
		_finish()
		return
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(3)
	game.call("_new_game")
	await _wait_for_zone(game, "greyfen")
	await _verify_registered_zone_contracts(game)
	_finish()

func _verify_static_contract() -> void:
	var context_source := FileAccess.get_file_as_string("res://scripts/zone_build_context.gd")
	check(context_source.contains("class_name ZoneBuildContext"), "ZoneBuildContext is not a named typed contract")
	check(context_source.contains("func validate() -> Dictionary"), "ZoneBuildContext lacks runtime contract validation")
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	check(game_source.contains("ZoneCompositionRouter.build_core"), "Core composition does not route through ZoneCompositionRouter")
	check(game_source.contains("ZoneCompositionRouter.build_campaign"), "Campaign composition does not route through ZoneCompositionRouter")
	for obsolete in ["func _build_greyfen", "func _build_wychwood", "func _build_ruins"]:
		check(not game_source.contains(obsolete), "game.gd still owns extracted zone construction: %s" % obsolete)
	for path in RELEASED_BUILDERS:
		var source := FileAccess.get_file_as_string(path)
		check(source != "", "Unable to read released zone builder: %s" % path)
		check(source.contains("ZoneBuildContext"), "Builder does not use the typed context: %s" % path)
		for forbidden in [".call(\"_", "host.call(", "h.call(", "callv(", "context: Dictionary", "func build(host", "func build(h"]:
			check(not source.contains(forbidden), "Reflective or untyped dispatch '%s' remains in %s" % [forbidden, path])

func _verify_registered_zone_contracts(game) -> void:
	var zones := ZoneCompositionRouter.registered_zones()
	check(zones.size() == 14, "Unexpected registered zone count: %d" % zones.size())
	for zone_id in zones:
		game.call("_load_zone", zone_id, Vector3(0, 1, 10))
		await _wait_for_zone(game, zone_id)
		check(str(game.current_zone_id) == zone_id, "Router did not activate %s" % zone_id)
		var zone := game.zone_root as Node3D
		check(zone != null and is_instance_valid(zone), "%s root is missing" % zone_id)
		if zone == null:
			continue
		check(str(zone.name) == zone_id, "%s root identity changed" % zone_id)
		var contract: Dictionary = zone.get_meta("zone_build_contract", {})
		check(not contract.is_empty(), "%s has no build-contract evidence" % zone_id)
		check(bool(contract.get("ok", false)), "%s build contract failed: %s" % [zone_id, contract.get("errors", [])])
		check(int(contract.get("ground_count", 0)) >= 1, "%s omitted ground construction" % zone_id)
		check(int(contract.get("bounds_count", 0)) >= 1, "%s omitted play-area bounds" % zone_id)
		check(int(contract.get("gate_count", 0)) >= 1, "%s omitted a return gate" % zone_id)
		_verify_preserved_landmarks(zone_id, zone)

func _verify_preserved_landmarks(zone_id: String, zone: Node3D) -> void:
	match zone_id:
		"greyfen":
			check(zone.find_child("AuthoredGreyfenSection", true, false) != null, "Greyfen authored root changed")
			check(zone.find_child("GreyfenCemeterySection", true, false) != null, "Greyfen cemetery section changed")
			check(zone.find_child("LivingRiverSection", true, false) != null, "Greyfen river section changed")
			check(zone.find_child("gate_wychwood", true, false) != null, "Greyfen Wychwood gate changed")
			check(zone.find_child("gate_vargan_approach", true, false) != null, "Greyfen Castle gate changed")
		"wychwood":
			check(zone.find_child("AuthoredWychwoodSection", true, false) != null, "Wychwood authored root changed")
			check(zone.find_child("AuthoredWychwoodCombatArena", true, false) != null, "Wychwood combat arena changed")
			check(zone.find_child("LivingRiverSection", true, false) != null, "Wychwood river section changed")
			check(zone.find_child("gate_greyfen", true, false) != null, "Wychwood return gate changed")
		"ruins":
			check(zone.find_child("gate_greyfen", true, false) != null, "Ruins return gate changed")
		"vargan_approach", "vargan_court", "record_hall":
			check(zone.find_child("CastleVargan_*", true, false) != null, "%s Castle marker changed" % zone_id)
		_:
			check(zone.find_child("CampaignSection_%s" % zone_id, true, false) != null, "%s campaign marker changed" % zone_id)

func _wait_for_zone(game, zone_id: String) -> void:
	for _i in range(30):
		await process_frame
		if str(game.current_zone_id) == zone_id and game.zone_root != null:
			return
	check(false, "Timed out waiting for zone: %s" % zone_id)

func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame

func _finish() -> void:
	print("ENGINE-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
