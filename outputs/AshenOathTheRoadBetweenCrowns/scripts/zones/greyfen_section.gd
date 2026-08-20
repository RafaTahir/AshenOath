extends RefCounted

const CemeterySection = preload("res://scripts/zones/cemetery_section.gd")
const GreyfenLifeController = preload("res://scripts/greyfen_life_controller.gd")
const RiverSection = preload("res://scripts/zones/river_section.gd")

func build(context: ZoneBuildContext) -> void:
	seed(41021)
	var root := Node3D.new()
	root.name = "AuthoredGreyfenSection"
	root.set_meta("ticket", "WORLD-001")
	root.set_meta("main_route_half_width", 2.8)
	context.add_node(root)

	context.make_split_ground(42.0, 34.0, 4.5, 3.4, Color(0.16, 0.18, 0.13))
	RiverSection.new().build(context, 4.5, 42.0, 3.4)
	context.make_greyfen_terrain_layers()
	context.make_play_area_bounds(42, 34, Color(0.09, 0.12, 0.08))
	context.make_road(Vector3(0, 0.018, 0), Vector3(4.2, 0.04, 30.0), Color(0.16, 0.13, 0.09))
	context.make_road(Vector3(-5, 0.02, 9), Vector3(14.0, 0.04, 3.0), Color(0.15, 0.12, 0.085))
	context.make_road(Vector3(15.2, 0.022, 0), Vector3(8.8, 0.045, 3.4), Color(0.145, 0.115, 0.078))
	context.make_greyfen_path_edges()

	_build_light_composition(context)
	_build_village_silhouette(context)
	_build_boundary_dressing(context)
	_build_landmarks(context)
	_build_authored_greyfen_details(context)

	context.make_village_dressing()
	context.make_greyfen_first_impression_dressing()
	context.make_quality_greyfen_overhaul()
	context.make_spawn_composition()
	context.make_tree_cluster([
		Vector3(-16,0,-12), Vector3(-14,0,12), Vector3(16,0,-11),
		Vector3(15,0,13), Vector3(0,0,15),
	])
	_build_gameplay_content(context)
	context.make_narrative_aftermath()

func _build_light_composition(context: ZoneBuildContext) -> void:
	context.make_light("Village Warmth", Vector3(-1.5, 5.2, 2), Color(1.0, 0.58, 0.30), 3.0)
	context.make_light("Blue Dusk Fill", Vector3(9, 6, -10), Color(0.34, 0.42, 0.58), 2.8)
	var shrine_state := str(context.get_story_flag("crow_shrine_state", ""))
	var shrine_color := Color(0.70, 0.86, 0.60)
	var shrine_energy := 3.0
	if shrine_state == "disturbed":
		shrine_color = Color(0.72, 0.40, 0.28)
		shrine_energy = 2.4
	elif shrine_state == "bound":
		shrine_color = Color(0.34, 0.38, 0.42)
		shrine_energy = 1.55
	context.make_light("Shrine Beacon", Vector3(4.8, 4.8, -5.4), shrine_color, shrine_energy)
	context.make_light("Wychwood Gate Lantern", Vector3(0, 3.2, -14.3), Color(1.0, 0.48, 0.16), 2.2)
	context.make_fog_sheet(Vector3(0, 1.1, -12), Vector3(18, 1, 5), Color(0.18, 0.22, 0.22, 0.12))

func _build_village_silhouette(context: ZoneBuildContext) -> void:
	context.make_village_house_dressed(Vector3(-5,0,-3), 8.0, "DressedVillageHouse_WestLane")
	context.make_village_house_dressed(Vector3(7,0,1), -18.0, "DressedVillageHouse_EastLane")
	context.make_village_house_dressed(Vector3(-10,0,8), 24.0, "DressedVillageHouse_SpawnFrame")
	context.make_village_house_dressed(Vector3(11.8,0,-7.8), -42.0, "DressedVillageHouse_ShrineFrame")

func _build_boundary_dressing(context: ZoneBuildContext) -> void:
	context.make_tree_wall(20.0, 15.2, 7, true)
	context.make_tree_wall(20.0, -15.2, 7, true)
	for tree in [
		[Vector3(-16.2, 0, -10.8), 1.10, -18.0], [Vector3(-14.8, 0, -7.2), 0.92, 21.0],
		[Vector3(15.8, 0, -10.7), 1.04, 12.0], [Vector3(16.5, 0, -6.4), 0.88, -26.0],
		[Vector3(-16.0, 0, 11.6), 1.00, 8.0], [Vector3(16.2, 0, 12.0), 0.96, -11.0],
	]:
		context.make_loose_role("forest_tree", tree[0], Vector3.ONE * float(tree[1]), float(tree[2]))
	for pos in [Vector3(-5.3, 0, 3.4), Vector3(4.8, 0, -5.3), Vector3(-9.3, 0, 11.2)]:
		context.make_torch(pos)
	for x in [-17, -13, -9, -5, 5, 9, 13, 17]:
		context.make_fence(Vector3(x, 0.35, 14), false)
		context.make_fence(Vector3(x, 0.35, -14), false)
	for z in [-10, -6, -2, 2, 6, 10]:
		context.make_fence(Vector3(-19, 0.35, z), true)
		if absf(float(z)) > 2.5:
			context.make_fence(Vector3(19, 0.35, z), true)

func _build_landmarks(context: ZoneBuildContext) -> void:
	context.make_notice_board(Vector3(-2.0, 0, 9.4))
	context.make_shrine_scene(Vector3(6.0, 0, -7.0))
	context.make_blacksmith_scene(Vector3(10.5, 0, -1.2))
	CemeterySection.new().build(context, Vector3(14, 0, 8.6))
	context.make_cart(Vector3(-6.2, 0, 9.0))
	_build_castle_road(context)

func _build_authored_greyfen_details(context: ZoneBuildContext) -> void:
	var layer := Node3D.new()
	layer.name = "GreyfenAuthoredDetailLayer"
	layer.set_meta("ticket", "WORLD-012")
	context.add_node(layer)

	# Structural details give each quarter a function without narrowing the
	# reserved player lanes or adding new gameplay interactions.
	for detail in [
		["GreyfenWestDrainStone", Vector3(-5.0, 0.09, -4.90), Vector3(3.0, 0.18, 0.22), Color(0.31, 0.30, 0.27)],
		["GreyfenEastDrainStone", Vector3(7.0, 0.09, 2.95), Vector3(2.8, 0.18, 0.22), Color(0.29, 0.29, 0.27)],
		["GreyfenSpawnDrain", Vector3(-10.0, 0.09, 9.85), Vector3(2.8, 0.18, 0.22), Color(0.32, 0.30, 0.26)],
		["GreyfenShrineStep", Vector3(6.0, 0.10, -8.25), Vector3(2.55, 0.20, 0.46), Color(0.34, 0.33, 0.29)],
		["GreyfenForgeStep", Vector3(10.5, 0.10, -2.65), Vector3(2.3, 0.20, 0.42), Color(0.29, 0.28, 0.25)],
	]:
		context.make_prop_box(str(detail[0]), detail[1], detail[2], detail[3])
		_mark_detail(layer, str(detail[0]))

	# The shrine receives a readable arch and the forge receives a working yard
	# silhouette. Both sit outside the main road corridor.
	for x in [4.35, 7.65]:
		context.make_prop_box("GreyfenShrineArchStone", Vector3(x, 1.28, -7.75), Vector3(0.34, 2.56, 0.34), Color(0.34, 0.35, 0.32))
	context.make_prop_box("GreyfenShrineArchLintel", Vector3(6.0, 2.42, -7.75), Vector3(3.55, 0.30, 0.34), Color(0.14, 0.075, 0.038))
	_mark_detail(layer, "GreyfenShrineArchLintel")
	context.make_prop_box("GreyfenForgeCanopy", Vector3(10.5, 2.03, -1.30), Vector3(3.75, 0.18, 2.35), Color(0.14, 0.070, 0.035))
	_mark_detail(layer, "GreyfenForgeCanopy")
	context.make_prop_box("GreyfenForgeChimney", Vector3(11.75, 2.55, -0.25), Vector3(0.44, 1.55, 0.44), Color(0.25, 0.24, 0.22))
	context.make_prop_box("GreyfenForgeRack", Vector3(8.7, 0.78, -1.35), Vector3(0.16, 1.40, 1.45), Color(0.29, 0.29, 0.26))
	_mark_detail(layer, "GreyfenForgeRack")

	# River stones frame the water while leaving the bridge centre and both
	# bridge approaches clear for the spatial service.
	for detail in [
		["GreyfenRiverShoreStone", Vector3(-7.4, 0.18, 2.62), Vector3(0.72, 0.36, 0.50)],
		["GreyfenRiverShoreStone", Vector3(7.5, 0.18, 2.70), Vector3(0.62, 0.32, 0.44)],
		["GreyfenRiverShoreStone", Vector3(-7.0, 0.18, 6.28), Vector3(0.65, 0.34, 0.46)],
		["GreyfenRiverShoreStone", Vector3(7.2, 0.18, 6.36), Vector3(0.75, 0.38, 0.52)],
	]:
		context.make_prop_box(str(detail[0]), detail[1], detail[2], Color(0.27, 0.29, 0.27))

	# A small market rhythm makes the spawn street read as inhabited without
	# introducing new schedules or interaction ownership.
	context.make_prop_box("GreyfenMarketAwning", Vector3(-6.3, 1.82, 8.85), Vector3(2.85, 0.16, 1.35), Color(0.24, 0.12, 0.065))
	_mark_detail(layer, "GreyfenMarketAwning")
	context.make_prop_box("GreyfenMarketCounter", Vector3(-6.3, 0.62, 8.18), Vector3(2.35, 0.88, 0.48), Color(0.16, 0.085, 0.040))
	context.make_prop_box("GreyfenMarketSign", Vector3(-6.3, 2.22, 8.05), Vector3(1.10, 0.46, 0.10), Color(0.44, 0.25, 0.11))

func _mark_detail(layer: Node3D, detail_id: String) -> void:
	var marker := Node3D.new()
	marker.name = detail_id
	layer.add_child(marker)

func _build_castle_road(context: ZoneBuildContext) -> void:
	var marker := Node3D.new()
	marker.name = "GreyfenCastleRoad"
	marker.position = Vector3(15.2, 0, 0)
	marker.add_to_group("castle_gateway_corridor")
	context.add_node(marker)
	for z in [-2.25, 2.25]:
		context.make_prop_box("CastleRoadWaystone", Vector3(17.9, 0.72, z), Vector3(0.62, 1.44, 0.62), Color(0.22, 0.22, 0.205))
		context.make_visual_box("VarganWaymark", Vector3(17.55, 0.88, z), Vector3(0.035, 0.34, 0.22), Color(0.42, 0.32, 0.16))
	context.make_visual_box("CastleRoadRuts", Vector3(15.0, 0.052, -0.72), Vector3(5.8, 0.025, 0.18), Color(0.065, 0.045, 0.030))
	context.make_visual_box("CastleRoadRuts", Vector3(15.0, 0.052, 0.72), Vector3(5.8, 0.025, 0.18), Color(0.065, 0.045, 0.030))

func _build_gameplay_content(context: ZoneBuildContext) -> void:
	context.make_named_interactable("notice_board", "dialogue", "Read notice board", Vector3(-2, 0, 9.4), Color(0.48, 0.28, 0.12), Vector3(0.45, 0.45, 0.45))
	var anwen_at_cemetery := context.is_quest_active("main_bell_beneath_greyfen")
	var anwen_position := Vector3(11.0, 0, 4.8) if anwen_at_cemetery else Vector3(3.2, 0, -5.0)
	var anwen_prompt := "Meet Sister Anwen at the cemetery gate" if anwen_at_cemetery else "Talk to Sister Anwen"
	context.make_named_interactable("sister_anwen", "dialogue", anwen_prompt, anwen_position, Color(0.34, 0.35, 0.48))
	context.make_named_interactable("mira", "dialogue", "Talk to Mira Fen", Vector3(-6.8, 0, -2.3), Color(0.22, 0.48, 0.32), Vector3(0.62, 0.62, 0.62))
	context.make_named_interactable("rook", "dialogue", "Talk to Rook", Vector3(-7.8, 0, 8.5), Color(0.42, 0.33, 0.23), Vector3(0.62, 0.62, 0.62))
	context.make_named_interactable("widow_elna", "dialogue", "Talk to Widow Elna", Vector3(13.0, 0, 7.0), Color(0.32, 0.30, 0.42), Vector3(0.54, 0.54, 0.54))
	context.make_named_interactable("blacksmith_tor", "dialogue", "Talk to Blacksmith Tor", Vector3(9.5, 0, -2.8), Color(0.43, 0.37, 0.31), Vector3(0.54, 0.54, 0.54))
	context.make_named_interactable("farmer_toma", "dialogue", "Talk to Farmer Toma", Vector3(12, 0, -9), Color(0.39, 0.30, 0.18), Vector3(0.46, 0.46, 0.46))
	context.make_named_interactable("side_contracts", "dialogue", "Read village requests", Vector3(-3.2,0,9.4), Color(0.42,0.27,0.14), Vector3(0.4,0.4,0.4))
	if context.is_quest_active("main_names_they_burned") and not context.is_objective_done("main_names_they_burned", "names_choice"):
		context.make_named_interactable("names_decision", "dialogue", "Decide the fate of the names", Vector3(4.4,0,-5.0), Color(0.36,0.32,0.25), Vector3(0.45,0.45,0.45))
	if context.crow_shrine_choice_ready():
		context.make_named_interactable("crow_shrine_choice", "dialogue", "Choose the Crow Shrine's fate", Vector3(6.5,0,-7.5), Color(0.3,0.38,0.3), Vector3(0.45,0.45,0.45))
	if context.road_ready_to_report():
		context.make_named_interactable("retain_evidence", "dialogue", "Keep Oren's token", Vector3(1.8,0,8.8), Color(0.38,0.24,0.16), Vector3(0.35,0.35,0.35))
	context.make_village_place("village_well", "village_place", "Draw from the village well", Vector3(-8.0,0,-0.5), Vector3(2.2,0.9,2.2), Color(0.19,0.18,0.16))
	context.make_village_place("forge_corner", "village_place", "Inspect Tor's old iron", Vector3(11.0,0,-1.2), Vector3(1.5,0.7,1.2), Color(0.28,0.18,0.10))
	context.make_village_place("shrine_prayer", "village_place", "Sit at the shrine bench", Vector3(8.0,0,-6.2), Vector3(2.4,0.55,0.7), Color(0.22,0.15,0.09))
	context.make_village_place("common_table", "minigame", "Play Three Marks with Rook", Vector3(-5.4,0,7.2), Vector3(2.8,0.85,1.8), Color(0.28,0.18,0.10))
	context.make_village_place("barrel_board", "minigame", "Play Greyfen Draughts with Tor", Vector3(7.0,0,6.8), Vector3(2.2,0.85,1.5), Color(0.24,0.15,0.08))
	if context.is_quest_active("side_widows_bell") and not context.is_objective_done("side_widows_bell", "find_bell"):
		context.make_clue("grave_bell", "Inspect Harl's grave bell", Vector3(15.8, 0, 9.5), "side_widows_bell", "find_bell", Color(0.60, 0.55, 0.44))
	if context.is_quest_active("side_iron_remembers") and not context.is_objective_done("side_iron_remembers", "recover_iron"):
		context.make_clue("massacre_iron", "Recover blackened chapel iron", Vector3(15.4, 0, 8.5), "side_iron_remembers", "recover_iron", Color(0.26, 0.24, 0.20))
	if context.is_quest_active("side_empty_grave") and not context.is_objective_done("side_empty_grave", "follow_empty_grave"):
		context.make_clue("empty_grave_tracks", "Follow prints from the empty grave", Vector3(16.0, 0, 6.7), "side_empty_grave", "follow_empty_grave", Color(0.25, 0.24, 0.22))
	if context.is_quest_active("side_empty_grave") and context.is_objective_done("side_empty_grave", "follow_empty_grave") and not context.is_objective_done("side_empty_grave", "walker_choice"):
		context.make_named_interactable("returned_soldier", "dialogue", "Speak to the returned soldier", Vector3(10.8, 0, 8.2), Color(0.28, 0.29, 0.31))
	if str(context.get_story_flag("widow_truth", "")) == "told":
		context.make_visual_box("HarlBellCutCord", Vector3(15.8, 0.8, 9.5), Vector3(0.05, 0.7, 0.05), Color(0.18, 0.12, 0.07))
	if str(context.get_story_flag("iron_fate", "")) == "memorial":
		context.make_visual_box("ForgeNameMemorial", Vector3(10.4, 1.0, -1.2), Vector3(1.6, 1.7, 0.14), Color(0.30, 0.25, 0.18))
	if str(context.get_story_flag("mira_truth", "")) == "confessed":
		context.make_visual_box("MiraTruthLabels", Vector3(-6.3, 0.8, -2.0), Vector3(1.4, 0.08, 0.6), Color(0.42, 0.38, 0.25))
	if str(context.get_story_flag("returned_soldier_fate", "")) == "named":
		context.make_visual_box("ReturnedSoldierNamedStone", Vector3(16.0, 0.65, 6.7), Vector3(0.55, 1.3, 0.20), Color(0.25, 0.25, 0.24))
	context.make_clue("grave_harl", "Inspect Harl's disturbed grave", Vector3(12.2,0,7.2), "main_bell_beneath_greyfen", "grave_harl", Color(0.3,0.28,0.25))
	context.make_clue("grave_child", "Inspect the nameless child's grave", Vector3(14.0,0,10.2), "main_bell_beneath_greyfen", "grave_child", Color(0.3,0.28,0.25))
	context.make_clue("grave_soldier", "Inspect the empty soldier's grave", Vector3(16.2,0,7.2), "main_bell_beneath_greyfen", "grave_soldier", Color(0.3,0.28,0.25))
	context.make_clue("chapel_door", "Open the ruined Crow Chapel", Vector3(16.3,0,8.0), "main_bell_beneath_greyfen", "open_chapel", Color(0.24,0.22,0.18))
	if context.is_quest_active("main_teeth_in_rain"):
		context.set_story_flag("teeth_in_rain_available", true)
		if context.is_objective_done("main_teeth_in_rain", "speak_mira") and not context.is_objective_done("main_teeth_in_rain", "read_chapel_names"):
			context.make_clue("chapel_names", "Read the erased names in the chapel", Vector3(15.0,0,8.2), "main_teeth_in_rain", "read_chapel_names", Color(0.44,0.39,0.31))
	if context.is_quest_active("main_names_they_burned"):
		context.make_clue("register_anwen", "Take Anwen's hidden register page", Vector3(5.4,0,-6.2), "main_names_they_burned", "fragment_anwen", Color(0.42,0.36,0.22))
		context.make_clue("register_tor", "Take the forge register page", Vector3(9.0,0,-1.0), "main_names_they_burned", "fragment_tor", Color(0.42,0.36,0.22))
	if context.is_quest_active("side_black_dog"):
		context.make_clue("sheepfold", "Inspect sheepfold", Vector3(15, 0, -11), "side_black_dog", "find_dog", Color(0.36, 0.24, 0.16))
	context.make_zone_gate("To Wychwood", Vector3(0, 0, -15.2), "wychwood", Vector3(0, 1, 13))
	context.make_zone_gate("The long road", Vector3(-18,0,-10), "deep_wood", Vector3(0,1,12))
	context.make_wychwood_gate_scene(Vector3(0, 0, -14.3))
	context.make_route_markers()
	context.make_greyfen_story_beats()
	var castle_gate = context.make_zone_gate("Road to Castle Vargan", Vector3(17.5, 0, 0), "vargan_approach", Vector3(0, 1, 14))
	if castle_gate != null:
		castle_gate.rotation_degrees.y = 90.0
		castle_gate.set_meta("always_accessible", true)
	var life = GreyfenLifeController.new()
	life.name = "GreyfenLifeController"
	context.add_node(life)
	context.configure_zone_controller(life)
