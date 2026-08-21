extends RefCounted

const ZONES: Array[String] = ["deep_wood", "old_mill", "burned_farmstead", "marsh_crossing"]
const LINKS := {
	"deep_wood": ["wychwood", "old_mill"],
	"old_mill": ["deep_wood", "burned_farmstead"],
	"burned_farmstead": ["old_mill", "marsh_crossing"],
	"marsh_crossing": ["burned_farmstead", "bandit_road"]
}

func build(context: ZoneBuildContext) -> void:
	match context.zone_id:
		"deep_wood":
			_build_deep_wood(context)
		"old_mill":
			_build_old_mill(context)
		"burned_farmstead":
			_build_farmstead(context)
		"marsh_crossing":
			_build_marsh(context)
	_add_route_gates(context)

func _base(context: ZoneBuildContext, color: Color, road_color: Color) -> void:
	var compatibility_marker := Node3D.new()
	compatibility_marker.name = "CampaignSection_%s" % context.zone_id
	compatibility_marker.set_meta("authored_builder", "WORLD-004")
	context.add_node(compatibility_marker)
	context.make_ground(Vector3(0, -0.08, 0), Vector3(40, 0.16, 32), color)
	context.make_play_area_bounds(40.0, 32.0, color.darkened(0.38))
	context.make_road(Vector3(0, 0.018, 0), Vector3(3.35, 0.035, 28), road_color)
	_make_route_surface(context, road_color)
	# The route is a compact, readable ribbon rather than a raised-looking slab.
	# Terrain patches and edge stones carry the transition into the surrounding
	# ground while keeping all dressing non-blocking.
	context.make_terrain_patch("WildernessRouteShoulderLeft", Vector3(-2.12, 0.012, 0), Vector3(0.72, 0.028, 27.5), color.lightened(0.10))
	context.make_terrain_patch("WildernessRouteShoulderRight", Vector3(2.12, 0.013, 0), Vector3(0.72, 0.030, 27.5), color.lightened(0.06))
	for z in [-12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.0]:
		context.make_path_stone(Vector3(-2.02 + sin(z * 0.33) * 0.10, 0, z), 0.34)
		context.make_path_stone(Vector3(2.02 + cos(z * 0.29) * 0.10, 0, z + 0.18), 0.30)
	context.make_grass_tufts([
		Vector3(-5.8, 0, -12.0), Vector3(5.7, 0, -10.0),
		Vector3(-6.2, 0, -5.2), Vector3(6.0, 0, -2.5),
		Vector3(-5.5, 0, 2.8), Vector3(5.8, 0, 6.2),
		Vector3(-6.5, 0, 10.2), Vector3(6.4, 0, 12.0)
	], color.lightened(0.15))
	_make_waystones(context, color)
	# A few near-edge silhouettes give the route a foreground without forming a
	# wall or stealing the reserved gate and combat corridors.
	for x in [-10.5, 10.5]:
		for z in [-9.0, -1.5, 6.0]:
			context.make_loose_role("forest_tree_variant", Vector3(x, 0, z + sin(x + z) * 0.25), Vector3(1.12, 1.05, 1.12), (x + z) * 3.0)

func _make_route_surface(context: ZoneBuildContext, road_color: Color) -> void:
	var rut := road_color.darkened(0.30)
	var damp_edge := road_color.lightened(0.10)
	for z in [-11.5, -8.0, -4.5, -1.0, 2.5, 6.0, 9.5, 12.5]:
		var drift := sin(z * 0.42) * 0.16
		context.make_visual_box("WildernessRoadRutLeft", Vector3(-0.91 + drift, 0.046, z), Vector3(0.10, 0.014, 1.85), rut)
		context.make_visual_box("WildernessRoadRutRight", Vector3(0.87 - drift, 0.047, z + 0.18), Vector3(0.08, 0.015, 1.55), rut.darkened(0.08))
		context.make_visual_box("WildernessDampRoadEdge", Vector3(-1.52, 0.048, z + 0.34), Vector3(0.16, 0.012, 1.05), damp_edge.darkened(0.18))
		context.make_visual_box("WildernessDampRoadEdge", Vector3(1.52, 0.049, z - 0.22), Vector3(0.16, 0.012, 0.92), damp_edge.darkened(0.24))

func _build_deep_wood(context: ZoneBuildContext) -> void:
	_base(context, Color(0.040, 0.072, 0.047), Color(0.070, 0.083, 0.058))
	var marker := Node3D.new()
	marker.name = "AuthoredDeepWood"
	marker.set_meta("route_width", 3.0)
	context.add_node(marker)
	context.make_fog_sheet(Vector3(0, 0.9, -4), Vector3(28, 1, 13), Color(0.12, 0.19, 0.15, 0.20))
	for x in [-17.0, -13.5, -10.0, 10.0, 13.5, 17.0]:
		for z in [-13.0, -7.0, 0.0, 7.0, 13.0]:
			context.make_tree(Vector3(x, 0, z + sin(x + z) * 0.7))
	for rock in [Vector3(-6.6, 0, -10.0), Vector3(6.8, 0, -7.2), Vector3(-7.4, 0, 2.2), Vector3(7.3, 0, 9.0)]:
		context.make_loose_role("forest_rock", rock, Vector3.ONE * 0.75, sin(rock.z) * 18.0)
	_make_memory_altar(context, Vector3(0, 0, -9.6), Color(0.28, 0.54, 0.46))
	for pos in [Vector3(-7,0,6), Vector3(7,0,1), Vector3(-7,0,-5), Vector3(7,0,-10)]:
		context.make_deadfall(pos)
	for pos in [Vector3(-5.8,0,-7.5), Vector3(5.9,0,-8.4), Vector3(0,0,-10.5)]:
		context.make_ritual_stone(pos)
	context.make_light("Deep Wood Memory Glow", Vector3(0, 4.5, -8.5), Color(0.34, 0.56, 0.48), 2.0)
	if context.is_quest_active("main_teeth_in_rain") and context.is_objective_done("main_teeth_in_rain", "name_the_dead"):
		if not context.is_objective_done("main_teeth_in_rain", "fight_bog_wretch"):
			context.spawn_enemy("bog_wretch", Vector3(0, 0.8, -8))
		elif not context.is_objective_done("main_teeth_in_rain", "bog_core_choice"):
			context.make_named_interactable("bog_core_choice", "dialogue", "Choose the memory core's fate", Vector3(0,0,-8), Color(0.35,0.58,0.52), Vector3(0.4,0.4,0.4))
	if context.is_quest_active("main_names_they_burned") and context.is_objective_done("main_names_they_burned", "reconstruct_register") and not bool(context.get_story_flag("rootbound_colossus_defeated", false)):
		if not context.get_story_flag("rootbound_colossus_spawned", false):
			context.set_story_flag("rootbound_colossus_spawned", true)
			context.spawn_enemy("rootbound_colossus", Vector3(0, 0.8, -10.5))

func _build_old_mill(context: ZoneBuildContext) -> void:
	_base(context, Color(0.115, 0.094, 0.066), Color(0.125, 0.105, 0.075))
	var marker := Node3D.new()
	marker.name = "AuthoredAshMill"
	marker.set_meta("wheel_clearance", 3.2)
	context.add_node(marker)
	context.make_road(Vector3(-5.2, 0.025, -5.5), Vector3(8.0, 0.04, 3.0), Color(0.105, 0.083, 0.058))
	_make_mill_shell(context)
	context.make_world_wheel("AshMillWaterWheel", Vector3(-9.25, 1.55, -5.25), 1.55, 0.28, Color(0.16, 0.09, 0.045), Vector3(90, 0, 0))
	var mill_roof_left = context.make_visual_box("AshMillRoofTiles", Vector3(-7.25, 3.12, -5.4), Vector3(4.5, 0.20, 5.9), Color(0.12, 0.062, 0.040))
	var mill_roof_right = context.make_visual_box("AshMillRoofTiles", Vector3(-3.15, 3.12, -5.4), Vector3(4.5, 0.20, 5.9), Color(0.12, 0.062, 0.040))
	mill_roof_left.rotation_degrees.z = -12.0
	mill_roof_right.rotation_degrees.z = 12.0
	# Broken timber braces and a warm, readable opening keep the mill from
	# reading as an untextured rectangular shell at route distance.
	for x in [-8.0, -5.9, -3.7, -1.8]:
		var brace: MeshInstance3D = context.make_visual_box("AshMillTimberBrace", Vector3(x, 1.45, -8.10), Vector3(0.16, 2.25, 0.18), Color(0.10, 0.055, 0.030))
		brace.rotation_degrees.z = -12.0 if int(absf(x * 10.0)) % 2 == 0 else 12.0
	context.make_visual_box("AshMillWindowWarmth", Vector3(-2.0, 1.25, -7.96), Vector3(0.90, 0.75, 0.035), Color(0.56, 0.24, 0.07))
	context.make_loose_role("barrel", Vector3(-0.4, 0, -4.2), Vector3.ONE * 0.72, 0.0)
	context.make_loose_role("crate", Vector3(-0.3, 0, -3.3), Vector3.ONE * 0.62, -8.0)
	context.make_loose_role("cart", Vector3(6.6, 0, 2.8), Vector3.ONE * 0.72, -22.0)
	for pos in [Vector3(5.2,0,-5), Vector3(8.0,0,-3), Vector3(7.2,0,5)]:
		context.make_rubble(pos)
	var mill_fate := str(context.get_story_flag("mill_fate", ""))
	if mill_fate == "preserved":
		context.make_visual_box("PreservedMillLedgerSeal", Vector3(-6.95, 1.12, -7.18), Vector3(0.72, 0.18, 0.06), Color(0.52, 0.40, 0.20))
	elif mill_fate == "burned":
		context.make_visual_box("BurnedMillLedgerAsh", Vector3(-6.95, 0.14, -7.18), Vector3(0.90, 0.08, 0.42), Color(0.10, 0.065, 0.040))
	elif mill_fate == "exposed":
		context.make_visual_box("PostedMillLedgerCopies", Vector3(-6.95, 1.18, -7.18), Vector3(1.25, 0.95, 0.05), Color(0.44, 0.30, 0.16))
	context.make_clue("millstones", "Inspect ash-caked millstones", Vector3(-5.0,0,-5), "main_ash_at_the_mill", "inspect_millstones", Color(0.4,0.35,0.3))
	if context.is_quest_active("main_ash_at_the_mill") and not context.is_objective_done("main_ash_at_the_mill", "mill_encounter"):
		for position in [Vector3(-3.2,0.8,-7.0), Vector3(-7.2,0.8,-6.2)]:
			var enemy = context.spawn_enemy("ghoulkin", position)
			if enemy != null:
				enemy.set_meta("ash_mill_enemy", true)
	elif context.is_objective_done("main_ash_at_the_mill", "mill_encounter") and not bool(context.get_story_flag("ashwing_defeated", false)):
		if not context.get_story_flag("ashwing_spawned", false):
			context.set_story_flag("ashwing_spawned", true)
			context.spawn_enemy("ashwing", Vector3(0, 1.0, -9.0))
	elif context.is_objective_done("main_ash_at_the_mill", "mill_encounter") and not context.is_objective_done("main_ash_at_the_mill", "mill_choice"):
		context.make_named_interactable("miller_record", "dialogue", "Read the miller's record", Vector3(-7.0,0,-7), Color(0.5,0.4,0.25))

func _build_farmstead(context: ZoneBuildContext) -> void:
	_base(context, Color(0.115, 0.070, 0.043), Color(0.135, 0.092, 0.058))
	var marker := Node3D.new()
	marker.name = "AuthoredBurnedFarmstead"
	context.add_node(marker)
	_make_burned_home(context, Vector3(-8, 0, -5), "West")
	_make_burned_home(context, Vector3(7, 0, 2), "East")
	for pos in [Vector3(-10,0,-8), Vector3(9,0,-4), Vector3(-8,0,7)]:
		context.make_loose_role("cart", pos, Vector3.ONE * 0.62, 18.0)
	for pos in [Vector3(-4,0,-3), Vector3(4,0,5), Vector3(10,0,7), Vector3(-11,0,2)]:
		context.make_rubble(pos)
	for x in [-12.0, -8.0, 6.0, 10.0]:
		context.make_fence(Vector3(x, 0.35, 10.5), false)
	context.make_fog_sheet(Vector3(0, 0.7, -2), Vector3(22, 1, 9), Color(0.24, 0.12, 0.07, 0.14))
	_make_burned_yard(context, Vector3(0, 0, 6.5))
	for x in [-10.2, -7.8, 6.2, 9.8]:
		context.make_visual_box("FarmsteadCharredPost", Vector3(x, 1.05, 9.9), Vector3(0.22, 2.1, 0.22), Color(0.06, 0.034, 0.020))
	context.make_visual_box("FarmsteadAshWindrow", Vector3(0, 0.065, 4.3), Vector3(4.8, 0.014, 0.32), Color(0.045, 0.027, 0.020))
	context.make_light("FarmsteadEmberGlow", Vector3(0, 0.55, 6.0), Color(0.82, 0.20, 0.06), 0.55)
	context.make_clue("register_rook", "Recover charred names", Vector3(-7,0,-5), "main_names_they_burned", "fragment_rook", Color(0.45,0.25,0.12))

func _build_marsh(context: ZoneBuildContext) -> void:
	_base(context, Color(0.045, 0.077, 0.068), Color(0.090, 0.092, 0.068))
	var marker := Node3D.new()
	marker.name = "AuthoredMarshCrossing"
	marker.set_meta("boardwalk_width", 3.2)
	context.add_node(marker)
	for pool in [
		[Vector3(-8,0.00,-6), Vector3(8.0,0.025,7.0)],
		[Vector3(8,0.00,2), Vector3(9.0,0.025,8.0)],
		[Vector3(-9,0.00,9), Vector3(7.0,0.025,5.0)]
	]:
		context.make_water_patch("MarshStillWater", pool[0], pool[1], Color(0.035, 0.16, 0.16, 0.92))
	for z in range(-12, 13, 2):
		context.make_prop_box("MarshBoardwalk", Vector3(0,0.12,float(z)), Vector3(3.4,0.20,1.55), Color(0.20,0.14,0.085))
	for pos in [Vector3(-5,0,-9), Vector3(6,0,-6), Vector3(-7,0,1), Vector3(7,0,8), Vector3(-5,0,11)]:
		context.make_visual_box("MarshReedClump", pos + Vector3(0,0.45,0), Vector3(0.45,0.9,0.45), Color(0.16,0.24,0.12))
	for pos in [Vector3(-7.2,0.05,-5.5), Vector3(7.2,0.05,1.0), Vector3(-8.0,0.05,8.4)]:
		context.make_visual_box("MarshWaterStreak", pos, Vector3(2.2, 0.012, 0.10), Color(0.12, 0.34, 0.31))
		context.make_visual_box("MarshWaterStreak", pos + Vector3(0.8, 0.008, 0.18), Vector3(1.1, 0.010, 0.06), Color(0.19, 0.43, 0.37))
	context.make_light("MarshColdReflection", Vector3(0, 1.3, 4.0), Color(0.12, 0.40, 0.34), 0.45)
	for pos in [Vector3(-5.2, 0, -3.5), Vector3(5.7, 0, 3.7), Vector3(-6.3, 0, 8.7), Vector3(6.8, 0, 10.7)]:
		context.make_loose_role("forest_rock", pos, Vector3.ONE * 0.58, 0.0)
	context.make_fog_sheet(Vector3(0,0.55,0), Vector3(30,1,14), Color(0.17,0.24,0.21,0.22))
	context.make_clue("register_mira", "Recover the healer's fragment", Vector3(3,0,-7), "main_names_they_burned", "fragment_mira", Color(0.35,0.3,0.2))

func _make_waystones(context: ZoneBuildContext, color: Color) -> void:
	for pos in [Vector3(-4.8, 0, -11.0), Vector3(4.8, 0, 10.8)]:
		context.make_prop_box("WildernessWaystone", pos + Vector3(0, 0.55, 0), Vector3(0.62, 1.10, 0.34), color.lightened(0.55))
		context.make_visual_box("WildernessWaystoneRune", pos + Vector3(0, 0.72, -0.19), Vector3(0.06, 0.34, 0.025), color.lightened(0.78))

func _make_memory_altar(context: ZoneBuildContext, pos: Vector3, glow: Color) -> void:
	context.make_prop_box("MemoryAltarBase", pos + Vector3(0, 0.16, 0), Vector3(1.8, 0.32, 1.25), Color(0.16, 0.20, 0.16))
	context.make_prop_box("MemoryAltarStone", pos + Vector3(0, 0.78, 0), Vector3(0.44, 1.22, 0.30), Color(0.25, 0.31, 0.28))
	context.make_visual_box("MemoryAltarRune", pos + Vector3(0, 0.82, -0.17), Vector3(0.07, 0.46, 0.025), glow.lightened(0.42))
	context.make_light("MemoryAltarLight", pos + Vector3(0, 1.65, 0), glow, 1.3)

func _make_mill_shell(context: ZoneBuildContext) -> void:
	context.make_prop_box("AshMillFoundation", Vector3(-5.2, 0.24, -5.4), Vector3(8.8, 0.48, 5.6), Color(0.22, 0.19, 0.15))
	context.make_prop_box("AshMillBackWall", Vector3(-5.2, 1.45, -7.85), Vector3(8.1, 2.45, 0.42), Color(0.22, 0.19, 0.15))
	context.make_prop_box("AshMillLeftWall", Vector3(-9.15, 1.45, -5.25), Vector3(0.42, 2.45, 5.2), Color(0.20, 0.17, 0.14))
	context.make_prop_box("AshMillRightWall", Vector3(-1.25, 1.45, -5.25), Vector3(0.42, 2.45, 5.2), Color(0.20, 0.17, 0.14))
	for x in [-8.6, -6.8, -4.9, -3.0, -1.8]:
		context.make_visual_box("AshMillCharredBeam", Vector3(x, 2.75, -7.62), Vector3(0.28, 3.0, 0.28), Color(0.105, 0.067, 0.038))
	context.make_visual_box("AshMillLintel", Vector3(-5.2, 2.48, -7.62), Vector3(7.2, 0.26, 0.30), Color(0.105, 0.067, 0.038))
	context.make_prop_box("AshMillDoor", Vector3(-5.2, 0.85, -7.64), Vector3(1.20, 1.70, 0.12), Color(0.08, 0.045, 0.025))
	context.make_light("AshMillForgeGlow", Vector3(-5.2, 1.5, -7.15), Color(0.72, 0.22, 0.08), 1.1)

func _make_burned_home(context: ZoneBuildContext, origin: Vector3, suffix: String) -> void:
	context.make_prop_box("%sHomeFoundation" % suffix, origin + Vector3(0, 0.20, 0), Vector3(6.2, 0.40, 4.8), Color(0.16, 0.105, 0.070))
	context.make_prop_box("%sHomeBackWall" % suffix, origin + Vector3(0, 1.25, 1.95), Vector3(5.8, 2.1, 0.38), Color(0.19, 0.11, 0.065))
	context.make_prop_box("%sHomeLeftWall" % suffix, origin + Vector3(-2.72, 1.25, 0), Vector3(0.38, 2.1, 4.0), Color(0.18, 0.10, 0.058))
	context.make_prop_box("%sHomeRightWall" % suffix, origin + Vector3(2.72, 1.25, 0), Vector3(0.38, 2.1, 4.0), Color(0.18, 0.10, 0.058))
	context.make_prop_box("%sHomeDoor" % suffix, origin + Vector3(0, 0.80, -1.98), Vector3(0.88, 1.42, 0.12), Color(0.075, 0.040, 0.022))
	context.make_visual_box("%sHomeBurnedBeam" % suffix, origin + Vector3(0.0, 2.25, -1.92), Vector3(5.8, 0.26, 0.30), Color(0.065, 0.035, 0.018))
	var roof_left = context.make_visual_box("%sHomeRoofTiles" % suffix, origin + Vector3(-1.48, 2.50, 0), Vector3(3.25, 0.20, 5.15), Color(0.13, 0.060, 0.036))
	var roof_right = context.make_visual_box("%sHomeRoofTiles" % suffix, origin + Vector3(1.48, 2.50, 0), Vector3(3.25, 0.20, 5.15), Color(0.13, 0.060, 0.036))
	roof_left.rotation_degrees.z = -15.0
	roof_right.rotation_degrees.z = 15.0

func _make_burned_yard(context: ZoneBuildContext, origin: Vector3) -> void:
	for pos in [origin + Vector3(-3.2, 0, 0), origin + Vector3(0, 0, 0.6), origin + Vector3(3.0, 0, -0.3)]:
		context.make_visual_box("BurnedYardAsh", pos + Vector3(0, 0.055, 0), Vector3(1.4, 0.016, 0.72), Color(0.055, 0.032, 0.024))
	context.make_prop_box("BurnedYardFirepit", origin + Vector3(0, 0.22, -0.8), Vector3(1.1, 0.44, 0.72), Color(0.12, 0.075, 0.045))

func _add_route_gates(context: ZoneBuildContext) -> void:
	var links: Array = LINKS[context.zone_id]
	context.make_zone_gate("Return", Vector3(-7,0,13.5), str(links[0]), Vector3(0,1,-12))
	context.make_zone_gate("Continue", Vector3(7,0,-13.5), str(links[1]), Vector3(0,1,12))
