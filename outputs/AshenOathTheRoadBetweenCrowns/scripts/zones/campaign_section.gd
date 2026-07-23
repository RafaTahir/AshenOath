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

func build(host: Node, zone_id: String) -> void:
	if zone_id in CastleVarganSection.CASTLE_ZONES:
		CastleVarganSection.new().build(host, zone_id)
		return
	var d: Dictionary = SECTIONS[zone_id]
	host.call("_make_ground",Vector3(0,-0.08,0),Vector3(40,0.16,32),d.color)
	host.call("_make_play_area_bounds",40.0,32.0,d.color.darkened(0.35))
	host.call("_make_road",Vector3(0,0.02,0),Vector3(4,0.04,28),d.color.lightened(0.08))
	host.call("_make_fog_sheet",Vector3(0,0.8,-3),Vector3(30,1,12),Color(d.color.r,d.color.g,d.color.b,0.16))
	for z in [-10.0,-3.0,4.0,11.0]:
		host.call("_make_torch",Vector3(-3.2,0,z)); host.call("_make_torch",Vector3(3.2,0,z))
	if zone_id in ["deep_wood","burned_farmstead","marsh_crossing","bandit_road","hart_glade"]:
		host.call("_make_tree_cluster",[Vector3(-15,0,-12),Vector3(-12,0,-5),Vector3(-15,0,5),Vector3(-11,0,12),Vector3(15,0,-12),Vector3(12,0,-4),Vector3(15,0,5),Vector3(11,0,12)])
	if zone_id in ["vargan_approach","vargan_court","record_hall","undercroft","assembly"]:
		for p in [Vector3(-10,0,-10),Vector3(10,0,-10),Vector3(-10,0,2),Vector3(10,0,2)]: host.call("_make_pillar",p)
		host.call("_make_prop_box","VarganNorthWall",Vector3(0,1.5,-12),Vector3(24,3,1),Color(0.18,0.18,0.19))
		host.call("_make_prop_box","VarganWestWall",Vector3(-11,1.2,-4),Vector3(1,2.4,16),Color(0.16,0.16,0.17))
		host.call("_make_prop_box","VarganEastWall",Vector3(11,1.2,-4),Vector3(1,2.4,16),Color(0.16,0.16,0.17))
	var marker := Node3D.new(); marker.name = "CampaignSection_%s" % zone_id; host.zone_root.add_child(marker)
	_add_content(host,zone_id)
	host.call("_make_zone_gate","Return",Vector3(-7,0,13.5),str(d.back),Vector3(0,1,-12))
	if str(d.next) != "": host.call("_make_zone_gate","Continue",Vector3(7,0,-13.5),str(d.next),Vector3(0,1,12))

func _add_content(h: Node, id: String) -> void:
	match id:
		"deep_wood":
			if h.quests.is_active("main_teeth_in_rain") and h.quests.is_objective_done("main_teeth_in_rain", "name_the_dead"):
				if not h.quests.is_objective_done("main_teeth_in_rain", "fight_bog_wretch"):
					_spawn(h,"bog_wretch",Vector3(0,0.8,-8))
				elif not h.quests.is_objective_done("main_teeth_in_rain", "bog_core_choice"):
					h.call("_make_named_interactable","bog_core_choice","dialogue","Choose the memory core's fate",Vector3(0,0,-8),Color(0.35,0.58,0.52),Vector3(0.4,0.4,0.4))
		"old_mill":
			for p in [Vector3(-4,1,-6),Vector3(4,1,-6),Vector3(0,3,-8)]: h.call("_make_prop_box","AshMill",p,Vector3(5,2,0.6),Color(0.24,0.18,0.12))
			h.call("_make_clue","millstones","Inspect ash-caked millstones",Vector3(0,0,-5),"main_ash_at_the_mill","inspect_millstones",Color(0.4,0.35,0.3)); h.call("_make_clue","ash_bound","Clear the ash-bound mill",Vector3(-2,0,-8),"main_ash_at_the_mill","mill_encounter",Color(0.3,0.2,0.15)); h.call("_make_named_interactable","miller_record","dialogue","Read the miller's record",Vector3(2,0,-8),Color(0.5,0.4,0.25))
		"burned_farmstead":
			for p in [Vector3(-6,1,-5),Vector3(5,1,2)]: h.call("_make_prop_box","BurnedHome",p,Vector3(6,2,5),Color(0.16,0.08,0.045))
			for p in [Vector3(-8,0,-8),Vector3(7,0,-5),Vector3(-7,0,6)]: h.call("_make_loose_role","cart",p,Vector3.ONE*0.6,18.0)
			h.call("_make_clue","register_rook","Recover charred names",Vector3(-5,0,-5),"main_names_they_burned","fragment_rook",Color(0.45,0.25,0.12))
		"marsh_crossing":
			for z in [-8,-4,0,4,8]: h.call("_make_prop_box","MarshBoard",Vector3(0,0.08,z),Vector3(3.2,0.16,1.4),Color(0.22,0.15,0.09))
			h.call("_make_clue","register_mira","Recover the healer's fragment",Vector3(3,0,-7),"main_names_they_burned","fragment_mira",Color(0.35,0.3,0.2))
		"bandit_road":
			h.call("_make_clue","senn_guard","Break Senn's guard",Vector3(0,0,-4),"main_soldier_without_banner","senn_confrontation",Color(0.35,0.22,0.15)); h.call("_make_named_interactable","captain_senn","dialogue","Confront Captain Senn",Vector3(0,0,-7),Color(0.4,0.25,0.18)); _spawn(h,"bandit",Vector3(-4,0.8,-5)); _spawn(h,"bandit",Vector3(4,0.8,-5))
		"vargan_approach":
			h.call("_make_prop_box","VarganGatehouse",Vector3(0,3,-10),Vector3(12,6,3),Color(0.19,0.19,0.20)); h.call("_make_clue","castle_entry","Cross the portcullis",Vector3(0,0,-8),"main_blood_under_stone","enter_vargan",Color(0.4,0.4,0.4))
		"vargan_court": h.call("_make_named_interactable","edric_campaign","dialogue","Confront Lord Edric",Vector3(0,0,-6),Color(0.4,0.32,0.24))
		"record_hall": h.call("_make_clue","command_ledger","Recover the command ledger",Vector3(0,0,-8),"main_blood_under_stone","recover_ledger",Color(0.55,0.45,0.25))
		"undercroft": h.call("_make_named_interactable","halvern","dialogue","Speak to Halvern",Vector3(0,0,-9),Color(0.5,0.5,0.55)); _spawn(h,"gravebound_knight",Vector3(0,0.8,-7))
		"assembly":
			for x in [-7,-3,3,7]: h.call("_make_named_interactable","witness_%d"%x,"dialogue","Hear testimony",Vector3(x,0,-5),Color(0.32,0.3,0.28),Vector3(0.55,0.55,0.55))
			h.call("_make_clue","witnesses_ready","Gather witnesses and records",Vector3(0,0,-4),"main_crowns_without_mercy","gather_witnesses",Color(0.45,0.4,0.3)); h.call("_make_named_interactable","assembly_choice","dialogue","Address Greyfen",Vector3(0,0,-9),Color(0.55,0.4,0.2))
		"hart_glade":
			for p in [Vector3(-7,0,-8),Vector3(7,0,-8),Vector3(-9,0,-3),Vector3(9,0,-3)]: h.call("_make_tree",p)
			h.call("_make_light","Hart Witness Light",Vector3(0,6,-8),Color(0.58,0.82,0.72),4.0); h.call("_make_named_interactable","white_hart","dialogue","Speak to the White Hart",Vector3(0,0,-8),Color(0.85,0.85,0.72),Vector3(0.36,0.64,0.36))

func _spawn(h: Node, enemy: String, pos: Vector3) -> void:
	if h.enemy_defs.has(enemy): h.call("_spawn_enemy",enemy,pos)
