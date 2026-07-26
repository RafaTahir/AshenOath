extends RefCounted

const ZONES := ["undercroft", "assembly", "hart_glade"]

func build(context: ZoneBuildContext) -> void:
	match context.zone_id:
		"undercroft":
			_build_undercroft(context)
		"assembly":
			_build_assembly(context)
		"hart_glade":
			_build_hart_glade(context)

func _marker(context: ZoneBuildContext, zone_id: String, authored_name: String) -> void:
	var compatibility := Node3D.new()
	compatibility.name = "CampaignSection_%s" % zone_id
	context.add_node(compatibility)
	var authored := Node3D.new()
	authored.name = authored_name
	context.add_node(authored)

func _build_undercroft(context: ZoneBuildContext) -> void:
	var stone := Color(0.068, 0.068, 0.072)
	context.make_ground(Vector3(0, -0.08, 0), Vector3(36, 0.16, 34), stone)
	context.make_play_area_bounds(36.0, 34.0, stone.darkened(0.42))
	context.make_road(Vector3(0, 0.02, 0), Vector3(6.5, 0.05, 29), Color(0.11, 0.105, 0.10))
	_marker(context, "undercroft", "AuthoredVarganUndercroft")
	for x in [-14.5, 14.5]:
		context.make_prop_box("UndercroftWall", Vector3(x, 2.8, 0), Vector3(1.2, 5.6, 31), Color(0.12, 0.12, 0.125))
	for z in [-14.5, 14.5]:
		context.make_prop_box("UndercroftWall", Vector3(0, 2.8, z), Vector3(28, 5.6, 1.2), Color(0.12, 0.12, 0.125))
	for z in [-9.0, -3.0, 3.0, 9.0]:
		for x in [-6.5, 6.5]:
			context.make_pillar(Vector3(x, 0, z))
	for position in [Vector3(-10, 0.8, -7), Vector3(10, 0.8, -7), Vector3(-10, 0.8, 5), Vector3(10, 0.8, 5)]:
		context.make_prop_box("StoneCoffin", position, Vector3(4.2, 1.6, 2.1), Color(0.15, 0.145, 0.14))
	for position in [Vector3(-4, 0, 9), Vector3(4, 0, 9), Vector3(-4, 0, -8), Vector3(4, 0, -8)]:
		context.make_torch(position)
	context.make_light("UndercroftWitnessLight", Vector3(0, 4.5, -7), Color(0.38, 0.45, 0.58), 2.6)
	context.make_named_interactable("halvern", "dialogue", "Speak to Sir Halvern", Vector3(0, 0, -9), Color(0.42, 0.43, 0.48))
	if context.is_quest_active("main_last_witness") and not context.is_objective_done("main_last_witness", "break_halvern_guard"):
		var guardian = context.spawn_enemy("gravebound_knight", Vector3(0, 0.8, -5.5))
		if guardian != null:
			guardian.name = "HalvernGuard"
			guardian.leash_radius = 8.0
	context.make_zone_gate("Return to the Record Hall", Vector3(-6, 0, 14), "record_hall", Vector3(0, 1, -12))
	if str(context.get_story_flag("halvern_fate", "")) != "":
		context.make_zone_gate("Return to Greyfen for the assembly", Vector3(6, 0, -14), "assembly", Vector3(0, 1, 12))

func _build_assembly(context: ZoneBuildContext) -> void:
	var earth := Color(0.125, 0.105, 0.075)
	context.make_ground(Vector3(0, -0.08, 0), Vector3(42, 0.16, 34), earth)
	context.make_play_area_bounds(42.0, 34.0, earth.darkened(0.36))
	context.make_road(Vector3(0, 0.02, 1), Vector3(8, 0.05, 30), Color(0.17, 0.145, 0.105))
	_marker(context, "assembly", "AuthoredGreyfenAssembly")
	context.make_prop_box("AssemblyDais", Vector3(0, 0.35, -8.5), Vector3(10, 0.7, 5), Color(0.20, 0.145, 0.09))
	context.make_prop_box("WitnessTable", Vector3(0, 0.85, -6.5), Vector3(5.0, 1.7, 1.6), Color(0.20, 0.125, 0.065))
	for x in [-8.0, -4.0, 4.0, 8.0]:
		context.make_prop_box("AssemblyBench", Vector3(x, 0.4, 1.5), Vector3(3.0, 0.8, 1.2), Color(0.19, 0.12, 0.065))
		context.make_named_interactable("witness_%d" % int(x), "dialogue", "Hear testimony", Vector3(x, 0, -3.5), Color(0.27, 0.25, 0.22), Vector3(0.55, 0.55, 0.55))
	for position in [Vector3(-6, 0, -10), Vector3(6, 0, -10), Vector3(-7, 0, 8), Vector3(7, 0, 8)]:
		context.make_torch(position)
	context.make_clue("witnesses_ready", "Gather witnesses and records", Vector3(0, 0, -4.5), "main_crowns_without_mercy", "gather_witnesses", Color(0.42, 0.36, 0.26))
	context.make_named_interactable("assembly_choice", "dialogue", "Address Greyfen", Vector3(0, 0, -9), Color(0.49, 0.34, 0.18))
	context.make_zone_gate("Return beneath Castle Vargan", Vector3(-7, 0, 14), "undercroft", Vector3(0, 1, -12))
	if str(context.get_story_flag("confession_method", "")) != "":
		context.make_zone_gate("Walk the reopened road", Vector3(7, 0, -14), "hart_glade", Vector3(0, 1, 12))

func _build_hart_glade(context: ZoneBuildContext) -> void:
	var moss := Color(0.065, 0.105, 0.078)
	context.make_ground(Vector3(0, -0.08, 0), Vector3(44, 0.16, 38), moss)
	context.make_play_area_bounds(44.0, 38.0, moss.darkened(0.36))
	context.make_road(Vector3(0, 0.02, 2), Vector3(5.2, 0.05, 34), Color(0.12, 0.13, 0.10))
	_marker(context, "hart_glade", "AuthoredWhiteHartGlade")
	for position in [
		Vector3(-16, 0, -13), Vector3(-14, 0, -5), Vector3(-15, 0, 10),
		Vector3(16, 0, -13), Vector3(14, 0, -5), Vector3(15, 0, 10)
	]:
		context.make_tree(position)
	for position in [Vector3(-7, 0, -7), Vector3(7, 0, -7), Vector3(-9, 0, -2), Vector3(9, 0, -2)]:
		context.make_ritual_stone(position)
	context.make_light("HartWitnessLight", Vector3(0, 6, -9), Color(0.62, 0.86, 0.75), 4.2)
	context.make_named_interactable("white_hart", "dialogue", "Stand before the White Hart", Vector3(0, 0, -9), Color(0.78, 0.80, 0.68), Vector3(0.42, 0.72, 0.42))
	context.make_zone_gate("Return to Greyfen's assembly", Vector3(-7, 0, 16), "assembly", Vector3(0, 1, -12))
