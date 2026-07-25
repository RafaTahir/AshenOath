extends RefCounted

const RiverSection = preload("res://scripts/zones/river_section.gd")

func build(context: ZoneBuildContext) -> void:
	seed(78233)
	var root := Node3D.new()
	root.name = "AuthoredWychwoodSection"
	root.set_meta("ticket", "WORLD-002")
	root.set_meta("main_route_half_width", 2.6)
	context.add_node(root)

	context.make_split_ground(44.0, 34.0, 0.0, 3.4, Color(0.065, 0.105, 0.07))
	RiverSection.new().build(context, 0.0, 44.0, 3.4)
	context.make_wychwood_terrain_layers()
	context.make_play_area_bounds(44, 34, Color(0.04, 0.075, 0.045))
	context.make_road(Vector3(0, 0.018, 3), Vector3(4.0, 0.04, 27.0), Color(0.065, 0.075, 0.052))
	context.make_road(Vector3(6, 0.019, -8), Vector3(10.0, 0.04, 3.0), Color(0.055, 0.065, 0.05))
	context.make_wychwood_path_edges()

	_build_light_composition(context)
	_build_gate_threshold(context)
	_build_forest_frame(context)
	_build_investigation_route(context)
	_build_combat_clearing(context)
	context.make_quality_wychwood_overhaul()
	_build_gameplay_content(context)

func _build_light_composition(context: ZoneBuildContext) -> void:
	context.make_light("Moon Shaft", Vector3(0, 6.6, -7), Color(0.48, 0.58, 0.78), 4.2)
	context.make_light("Sick Green Bounce", Vector3(9, 3.2, -9), Color(0.25, 0.42, 0.28), 1.7)
	context.make_light("Trail Threat", Vector3(0, 2.4, -2.8), Color(0.42, 0.68, 0.62), 1.4)
	context.make_fog_sheet(Vector3(0, 1.0, -6), Vector3(24, 1, 8), Color(0.24, 0.30, 0.28, 0.20))
	context.make_fog_sheet(Vector3(-10, 0.8, 5), Vector3(14, 1, 5), Color(0.16, 0.24, 0.18, 0.16))

func _build_gate_threshold(context: ZoneBuildContext) -> void:
	var marker := Node3D.new()
	marker.name = "WychwoodGateThreshold"
	marker.set_meta("clear_half_width", 3.4)
	context.add_node(marker)
	for x in [-3.7, 3.7]:
		context.make_torch(Vector3(x, 0, 13.4))
		context.make_tree(Vector3(x * 2.15, 0, 13.8))
	context.make_visual_box("WychwoodThresholdBrokenSign", Vector3(-4.2, 0.82, 12.8), Vector3(1.05, 0.12, 0.42), Color(0.10, 0.055, 0.028))

func _build_forest_frame(context: ZoneBuildContext) -> void:
	for x in [-20.0, -16.0, -12.0, -8.0, 8.0, 12.0, 16.0, 20.0]:
		context.make_tree(Vector3(x, 0, 15.2))
		context.make_tree(Vector3(x, 0, -15.2))
	context.make_tree_wall(16.0, -20.0, 7, false)
	context.make_tree_wall(16.0, 20.0, 7, false)
	context.make_tree_cluster([
		Vector3(-18,0,-12), Vector3(-15,0,-6), Vector3(-16,0,7), Vector3(-13,0,13),
		Vector3(16,0,-12), Vector3(18,0,-5), Vector3(17,0,5), Vector3(14,0,13),
		Vector3(-8,0,-14), Vector3(8,0,14), Vector3(-4,0,15), Vector3(5,0,-15),
	])
	for tree in [
		[Vector3(-13.0,0,10.0), 0.74, -12.0], [Vector3(12.5,0,9.2), 0.66, 17.0],
		[Vector3(-12.6,0,5.7), 0.64, 24.0], [Vector3(13.2,0,4.9), 0.76, -16.0],
		[Vector3(-12.8,0,-4.0), 0.72, 9.0], [Vector3(12.4,0,-3.8), 0.68, -22.0],
		[Vector3(-11.4,0,-11.0), 0.78, -6.0], [Vector3(11.8,0,-11.4), 0.74, 19.0],
	]:
		context.make_tree(tree[0])
		var marker := Node3D.new()
		marker.name = "WychwoodLandmarkTree"
		marker.position = tree[0]
		marker.set_meta("authored_scale", float(tree[1]))
		marker.set_meta("authored_yaw", float(tree[2]))
		marker.add_to_group("wychwood_landmark_tree")
		context.add_node(marker)

func _build_investigation_route(context: ZoneBuildContext) -> void:
	var marker := Node3D.new()
	marker.name = "WychwoodInvestigationRoute"
	marker.set_meta("clue_laybys", 3)
	context.add_node(marker)
	context.make_wychwood_route_dressing()
	context.make_wychwood_corridor()
	context.make_wychwood_story_beats()
	for pos in [Vector3(-8,0,-3), Vector3(6.7,0,-9.2), Vector3(9.8,0,-12.0), Vector3(-5,0,9.8)]:
		context.make_deadfall(pos)
	for bush in [Vector3(-6.6,0,8.0), Vector3(6.2,0,6.2), Vector3(-6.7,0,3.2), Vector3(6.8,0,-2.4)]:
		context.make_visual_box("WychwoodRouteBush", bush + Vector3(0, 0.42, 0), Vector3(1.15, 0.72, 0.62), Color(0.08, 0.20, 0.09))
		var bush_marker := Node3D.new()
		bush_marker.name = "WychwoodRouteBushMarker"
		bush_marker.position = bush
		bush_marker.add_to_group("wychwood_route_bush")
		context.add_node(bush_marker)

func _build_combat_clearing(context: ZoneBuildContext) -> void:
	var marker := Node3D.new()
	marker.name = "AuthoredWychwoodCombatArena"
	marker.set_meta("safe_half_extents", Vector2(5.2, 4.2))
	context.add_node(marker)
	context.make_monster_clearing(Vector3(0, 0, -6.5))
	for pos in [Vector3(6.8,0,-10.2), Vector3(8.5,0,-11.6), Vector3(10.0,0,-9.8), Vector3(8.5,0,-8.1)]:
		context.make_ritual_stone(pos)

func _build_gameplay_content(context: ZoneBuildContext) -> void:
	context.make_zone_gate("Back to Greyfen", Vector3(0, 0, 15), "greyfen", Vector3(0, 1, -13))
	context.make_clue("corpse", "Identify Bram by his cart ledger", Vector3(-2, 0, 7.4), "main_road_of_crows", "bram", Color(0.32, 0.18, 0.16))
	context.make_clue("black_feathers", "Identify Sella by the red-thread feathers", Vector3(-4, 0, 4.0), "main_road_of_crows", "sella", Color(0.03, 0.03, 0.035))
	context.make_clue("oren_token", "Recover Oren's scratched shrine token", Vector3(3.8, 0, 2.2), "main_road_of_crows", "oren", Color(0.46, 0.28, 0.12))
	context.make_clue("claw_marks", "Recover the blackened Vargan wire", Vector3(2.5, 0, 4.8), "main_road_of_crows", "vargan_wire", Color(0.18, 0.18, 0.18))
	context.make_clue("tracks", "Read the deliberate drag marks", Vector3(0, 0, -4.2), "main_road_of_crows", "drag_marks", Color(0.15, 0.11, 0.08))
	if context.is_quest_active("main_teeth_in_rain") and context.is_objective_done("main_teeth_in_rain", "read_chapel_names"):
		if not context.is_objective_done("main_teeth_in_rain", "name_the_dead"):
			context.make_clue("ritual_stones", "Speak Oren's name at the ritual stones", Vector3(8, 0, -10), "main_teeth_in_rain", "name_the_dead", Color(0.38, 0.38, 0.36))
		else:
			context.make_zone_gate("Enter deeper Wychwood", Vector3(10.8, 0, -13.2), "deep_wood", Vector3(0, 1, 12))
	context.make_clue("bandit_camp", "Inspect bandit camp", Vector3(-12, 0, -12), "side_black_dog", "find_dog", Color(0.30, 0.18, 0.10))
	context.make_clue("bitter_roots", "Collect bitter roots", Vector3(8, 0, -7.8), "side_bitter_roots", "collect_roots", Color(0.46, 0.22, 0.16))
	context.make_clue("sacrifice_roots", "Study sacrifice roots", Vector3(10, 0, -9.2), "side_bitter_roots", "mira_choice", Color(0.38, 0.16, 0.13))
	context.make_herb("mooncap", Vector3(-7, 0, -6), Color(0.58, 0.65, 0.86))
	context.make_herb("redroot", Vector3(-10, 0, -2), Color(0.55, 0.12, 0.11))
	context.make_herb("grave_moss", Vector3(5, 0, -13), Color(0.24, 0.42, 0.24))
	if context.is_quest_active("main_road_of_crows") and not context.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
		context.spawn_enemy("ghoulkin", Vector3(-2.4, 0.8, -8.8))
		var second_ghoul = context.spawn_enemy("ghoulkin", Vector3(2.7, 0.8, -9.6))
		if second_ghoul != null:
			second_ghoul.set_encounter_active(false)
		context.spawn_enemy("wychwood_stalker", Vector3(-4.8, 0.8, -3.8))
		context.spawn_enemy("wychwood_raider", Vector3(4.6, 0.8, -5.3))
		var brute_z := -14.2 if context.is_objective_done("main_road_of_crows", "drag_marks") else -12.4
		context.spawn_enemy("wychwood_brute", Vector3(0.2, 0.8, brute_z))
	if context.is_quest_active("side_black_dog") and not context.is_objective_done("side_black_dog", "find_dog"):
		context.spawn_enemy("bandit", Vector3(-14, 0.8, -14))
		context.spawn_enemy("bandit", Vector3(-12, 0.8, -15))
