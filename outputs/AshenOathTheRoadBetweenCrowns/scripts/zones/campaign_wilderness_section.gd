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
	context.make_road(Vector3(0, 0.02, 0), Vector3(4.4, 0.04, 28), road_color)

func _build_deep_wood(context: ZoneBuildContext) -> void:
	_base(context, Color(0.040, 0.072, 0.047), Color(0.070, 0.083, 0.058))
	var marker := Node3D.new()
	marker.name = "AuthoredDeepWood"
	marker.set_meta("route_width", 3.0)
	context.add_node(marker)
	context.make_fog_sheet(Vector3(0, 0.9, -4), Vector3(28, 1, 13), Color(0.12, 0.19, 0.15, 0.20))
	for x in [-16.0, -12.5, -9.0, 9.0, 12.5, 16.0]:
		for z in [-12.0, -6.0, 1.0, 8.0, 13.0]:
			context.make_tree(Vector3(x, 0, z + sin(x + z) * 0.7))
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

func _build_old_mill(context: ZoneBuildContext) -> void:
	_base(context, Color(0.115, 0.094, 0.066), Color(0.125, 0.105, 0.075))
	var marker := Node3D.new()
	marker.name = "AuthoredAshMill"
	marker.set_meta("wheel_clearance", 3.2)
	context.add_node(marker)
	context.make_road(Vector3(-5.2, 0.025, -5.5), Vector3(8.0, 0.04, 3.0), Color(0.105, 0.083, 0.058))
	for segment in [
		[Vector3(-5.2,1.5,-7.5), Vector3(8.0,3.0,0.55)],
		[Vector3(-9.0,1.5,-4.5), Vector3(0.55,3.0,6.5)],
		[Vector3(-1.4,1.5,-4.5), Vector3(0.55,3.0,6.5)]
	]:
		context.make_prop_box("AshMillStoneWall", segment[0], segment[1], Color(0.22, 0.19, 0.15))
	for beam in [
		[Vector3(-5.2,3.25,-7.1), Vector3(8.8,0.32,0.32)],
		[Vector3(-8.6,3.15,-4.0), Vector3(0.32,0.32,7.0)],
		[Vector3(-1.8,3.15,-4.0), Vector3(0.32,0.32,7.0)]
	]:
		context.make_visual_box("AshMillCharredBeam", beam[0], beam[1], Color(0.105, 0.067, 0.038))
	context.make_loose_role("cart", Vector3(6.6, 0, 2.8), Vector3.ONE * 0.72, -22.0)
	for pos in [Vector3(5.2,0,-5), Vector3(8.0,0,-3), Vector3(7.2,0,5)]:
		context.make_rubble(pos)
	context.make_clue("millstones", "Inspect ash-caked millstones", Vector3(-5.0,0,-5), "main_ash_at_the_mill", "inspect_millstones", Color(0.4,0.35,0.3))
	if context.is_quest_active("main_ash_at_the_mill") and not context.is_objective_done("main_ash_at_the_mill", "mill_encounter"):
		for position in [Vector3(-3.2,0.8,-7.0), Vector3(-7.2,0.8,-6.2)]:
			var enemy = context.spawn_enemy("ghoulkin", position)
			if enemy != null:
				enemy.set_meta("ash_mill_enemy", true)
	elif context.is_objective_done("main_ash_at_the_mill", "mill_encounter") and not context.is_objective_done("main_ash_at_the_mill", "mill_choice"):
		context.make_named_interactable("miller_record", "dialogue", "Read the miller's record", Vector3(-7.0,0,-7), Color(0.5,0.4,0.25))

func _build_farmstead(context: ZoneBuildContext) -> void:
	_base(context, Color(0.115, 0.070, 0.043), Color(0.135, 0.092, 0.058))
	var marker := Node3D.new()
	marker.name = "AuthoredBurnedFarmstead"
	context.add_node(marker)
	for home in [
		[Vector3(-8,1.2,-5), Vector3(6.5,2.4,5.2)],
		[Vector3(7,1.0,2), Vector3(5.8,2.0,4.8)]
	]:
		context.make_prop_box("FarmsteadStoneFoundation", home[0], home[1], Color(0.16, 0.105, 0.070))
	for pos in [Vector3(-10,0,-8), Vector3(9,0,-4), Vector3(-8,0,7)]:
		context.make_loose_role("cart", pos, Vector3.ONE * 0.62, 18.0)
	for pos in [Vector3(-4,0,-3), Vector3(4,0,5), Vector3(10,0,7), Vector3(-11,0,2)]:
		context.make_rubble(pos)
	for x in [-12.0, -8.0, 6.0, 10.0]:
		context.make_fence(Vector3(x, 0.35, 10.5), false)
	context.make_fog_sheet(Vector3(0, 0.7, -2), Vector3(22, 1, 9), Color(0.24, 0.12, 0.07, 0.14))
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
		context.make_visual_box("MarshStillWater", pool[0], pool[1], Color(0.055, 0.12, 0.115, 0.82))
	for z in range(-12, 13, 2):
		context.make_prop_box("MarshBoardwalk", Vector3(0,0.12,float(z)), Vector3(3.4,0.20,1.55), Color(0.20,0.14,0.085))
	for pos in [Vector3(-5,0,-9), Vector3(6,0,-6), Vector3(-7,0,1), Vector3(7,0,8), Vector3(-5,0,11)]:
		context.make_visual_box("MarshReedClump", pos + Vector3(0,0.45,0), Vector3(0.45,0.9,0.45), Color(0.16,0.24,0.12))
	context.make_fog_sheet(Vector3(0,0.55,0), Vector3(30,1,14), Color(0.17,0.24,0.21,0.22))
	context.make_clue("register_mira", "Recover the healer's fragment", Vector3(3,0,-7), "main_names_they_burned", "fragment_mira", Color(0.35,0.3,0.2))

func _add_route_gates(context: ZoneBuildContext) -> void:
	var links: Array = LINKS[context.zone_id]
	context.make_zone_gate("Return", Vector3(-7,0,13.5), str(links[0]), Vector3(0,1,-12))
	context.make_zone_gate("Continue", Vector3(7,0,-13.5), str(links[1]), Vector3(0,1,12))
