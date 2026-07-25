extends RefCounted

const CastleVarganSection = preload("res://scripts/zones/castle_vargan_section.gd")

const SECTIONS := {
	"deep_wood":{"back":"wychwood","next":"old_mill","color":Color(0.045,0.075,0.05)},
	"old_mill":{"back":"deep_wood","next":"burned_farmstead","color":Color(0.12,0.10,0.075)},
	"burned_farmstead":{"back":"old_mill","next":"marsh_crossing","color":Color(0.13,0.075,0.045)},
	"marsh_crossing":{"back":"burned_farmstead","next":"bandit_road","color":Color(0.055,0.085,0.075)},
	"bandit_road":{"back":"marsh_crossing","next":"vargan_approach","color":Color(0.10,0.085,0.065)},
	"vargan_approach":{"back":"bandit_road","next":"vargan_court","color":Color(0.11,0.11,0.105)},
	"vargan_court":{"back":"vargan_approach","next":"record_hall","color":Color(0.10,0.10,0.10)},
	"record_hall":{"back":"vargan_court","next":"undercroft","color":Color(0.085,0.075,0.065)},
	"undercroft":{"back":"record_hall","next":"assembly","color":Color(0.055,0.06,0.065)},
	"assembly":{"back":"undercroft","next":"hart_glade","color":Color(0.13,0.12,0.09)},
	"hart_glade":{"back":"assembly","next":"","color":Color(0.075,0.10,0.085)}
}

func build(context: ZoneBuildContext) -> void:
	var zone_id := context.zone_id
	if zone_id in CastleVarganSection.CASTLE_ZONES:
		CastleVarganSection.new().build(context)
		return
	var definition: Dictionary = SECTIONS[zone_id]
	var ground_color: Color = definition.color
	context.make_ground(Vector3(0,-0.08,0), Vector3(40,0.16,32), ground_color)
	context.make_play_area_bounds(40.0, 32.0, ground_color.darkened(0.35))
	context.make_road(Vector3(0,0.02,0), Vector3(4,0.04,28), ground_color.lightened(0.08))
	context.make_fog_sheet(Vector3(0,0.8,-3), Vector3(30,1,12), Color(ground_color.r,ground_color.g,ground_color.b,0.16))
	for z in [-10.0,-3.0,4.0,11.0]:
		context.make_torch(Vector3(-3.2,0,z))
		context.make_torch(Vector3(3.2,0,z))
	if zone_id in ["deep_wood","burned_farmstead","marsh_crossing","bandit_road","hart_glade"]:
		context.make_tree_cluster([
			Vector3(-15,0,-12),Vector3(-12,0,-5),Vector3(-15,0,5),Vector3(-11,0,12),
			Vector3(15,0,-12),Vector3(12,0,-4),Vector3(15,0,5),Vector3(11,0,12),
		])
	if zone_id in ["vargan_approach","vargan_court","record_hall","undercroft","assembly"]:
		for pos in [Vector3(-10,0,-10),Vector3(10,0,-10),Vector3(-10,0,2),Vector3(10,0,2)]:
			context.make_pillar(pos)
		context.make_prop_box("VarganNorthWall",Vector3(0,1.5,-12),Vector3(24,3,1),Color(0.18,0.18,0.19))
		context.make_prop_box("VarganWestWall",Vector3(-11,1.2,-4),Vector3(1,2.4,16),Color(0.16,0.16,0.17))
		context.make_prop_box("VarganEastWall",Vector3(11,1.2,-4),Vector3(1,2.4,16),Color(0.16,0.16,0.17))
	var marker := Node3D.new()
	marker.name = "CampaignSection_%s" % zone_id
	context.add_node(marker)
	_add_content(context)
	context.make_zone_gate("Return",Vector3(-7,0,13.5),str(definition.back),Vector3(0,1,-12))
	if str(definition.next) != "":
		context.make_zone_gate("Continue",Vector3(7,0,-13.5),str(definition.next),Vector3(0,1,12))

func _add_content(context: ZoneBuildContext) -> void:
	match context.zone_id:
		"deep_wood":
			if context.is_quest_active("main_teeth_in_rain") and context.is_objective_done("main_teeth_in_rain", "name_the_dead"):
				if not context.is_objective_done("main_teeth_in_rain", "fight_bog_wretch"):
					_spawn(context, "bog_wretch", Vector3(0,0.8,-8))
				elif not context.is_objective_done("main_teeth_in_rain", "bog_core_choice"):
					context.make_named_interactable("bog_core_choice","dialogue","Choose the memory core's fate",Vector3(0,0,-8),Color(0.35,0.58,0.52),Vector3(0.4,0.4,0.4))
		"old_mill":
			for pos in [Vector3(-4,1,-6),Vector3(4,1,-6),Vector3(0,3,-8)]:
				context.make_prop_box("AshMill",pos,Vector3(5,2,0.6),Color(0.24,0.18,0.12))
			context.make_clue("millstones","Inspect ash-caked millstones",Vector3(0,0,-5),"main_ash_at_the_mill","inspect_millstones",Color(0.4,0.35,0.3))
			context.make_clue("ash_bound","Clear the ash-bound mill",Vector3(-2,0,-8),"main_ash_at_the_mill","mill_encounter",Color(0.3,0.2,0.15))
			context.make_named_interactable("miller_record","dialogue","Read the miller's record",Vector3(2,0,-8),Color(0.5,0.4,0.25))
		"burned_farmstead":
			for pos in [Vector3(-6,1,-5),Vector3(5,1,2)]:
				context.make_prop_box("BurnedHome",pos,Vector3(6,2,5),Color(0.16,0.08,0.045))
			for pos in [Vector3(-8,0,-8),Vector3(7,0,-5),Vector3(-7,0,6)]:
				context.make_loose_role("cart",pos,Vector3.ONE*0.6,18.0)
			context.make_clue("register_rook","Recover charred names",Vector3(-5,0,-5),"main_names_they_burned","fragment_rook",Color(0.45,0.25,0.12))
		"marsh_crossing":
			for z in [-8,-4,0,4,8]:
				context.make_prop_box("MarshBoard",Vector3(0,0.08,z),Vector3(3.2,0.16,1.4),Color(0.22,0.15,0.09))
			context.make_clue("register_mira","Recover the healer's fragment",Vector3(3,0,-7),"main_names_they_burned","fragment_mira",Color(0.35,0.3,0.2))
		"bandit_road":
			context.make_clue("senn_guard","Break Senn's guard",Vector3(0,0,-4),"main_soldier_without_banner","senn_confrontation",Color(0.35,0.22,0.15))
			context.make_named_interactable("captain_senn","dialogue","Confront Captain Senn",Vector3(0,0,-7),Color(0.4,0.25,0.18))
			_spawn(context,"bandit",Vector3(-4,0.8,-5))
			_spawn(context,"bandit",Vector3(4,0.8,-5))
		"undercroft":
			context.make_named_interactable("halvern","dialogue","Speak to Halvern",Vector3(0,0,-9),Color(0.5,0.5,0.55))
			_spawn(context,"gravebound_knight",Vector3(0,0.8,-7))
		"assembly":
			for x in [-7,-3,3,7]:
				context.make_named_interactable("witness_%d"%x,"dialogue","Hear testimony",Vector3(x,0,-5),Color(0.32,0.3,0.28),Vector3(0.55,0.55,0.55))
			context.make_clue("witnesses_ready","Gather witnesses and records",Vector3(0,0,-4),"main_crowns_without_mercy","gather_witnesses",Color(0.45,0.4,0.3))
			context.make_named_interactable("assembly_choice","dialogue","Address Greyfen",Vector3(0,0,-9),Color(0.55,0.4,0.2))
		"hart_glade":
			for pos in [Vector3(-7,0,-8),Vector3(7,0,-8),Vector3(-9,0,-3),Vector3(9,0,-3)]:
				context.make_tree(pos)
			context.make_light("Hart Witness Light",Vector3(0,6,-8),Color(0.58,0.82,0.72),4.0)
			context.make_named_interactable("white_hart","dialogue","Speak to the White Hart",Vector3(0,0,-8),Color(0.85,0.85,0.72),Vector3(0.36,0.64,0.36))

func _spawn(context: ZoneBuildContext, enemy: String, pos: Vector3) -> void:
	if context.enemy_exists(enemy):
		context.spawn_enemy(enemy, pos)
