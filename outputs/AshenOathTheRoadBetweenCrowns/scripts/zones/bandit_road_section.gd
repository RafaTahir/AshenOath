extends RefCounted

const ZONES := ["bandit_road"]

func build(context: ZoneBuildContext) -> void:
	var ground := Color(0.105, 0.085, 0.058)
	context.make_ground(Vector3(0, -0.08, 0), Vector3(44, 0.16, 38), ground)
	context.make_play_area_bounds(44.0, 38.0, ground.darkened(0.38))
	context.make_road(Vector3(0, 0.02, 0), Vector3(5.4, 0.05, 35), Color(0.18, 0.145, 0.095))

	var marker := Node3D.new()
	marker.name = "CampaignSection_bandit_road"
	context.add_node(marker)
	var authored := Node3D.new()
	authored.name = "AuthoredBanditRoad"
	context.add_node(authored)

	# A collapsed customs post creates a readable silhouette without narrowing the route.
	for x in [-7.5, 7.5]:
		context.make_prop_box("CheckpointStone", Vector3(x, 1.4, -6), Vector3(2.3, 2.8, 2.3), Color(0.16, 0.15, 0.135))
		context.make_prop_box("CheckpointBeam", Vector3(x, 3.1, -6), Vector3(3.4, 0.28, 0.34), Color(0.20, 0.125, 0.065))
	context.make_prop_box("BrokenCrossbeam", Vector3(-3.8, 2.8, -6), Vector3(5.2, 0.30, 0.35), Color(0.18, 0.105, 0.055))
	context.make_prop_box("RoadsideDitch", Vector3(-5.2, 0.05, 2), Vector3(2.0, 0.10, 19), Color(0.075, 0.07, 0.045))
	context.make_prop_box("RoadsideDitch", Vector3(5.2, 0.05, 2), Vector3(2.0, 0.10, 19), Color(0.075, 0.07, 0.045))

	# Senn's camp is offset from the travel lane so combat never blocks either gate.
	context.make_prop_box("CommandTent", Vector3(9.5, 1.35, -1.5), Vector3(6.0, 2.7, 4.8), Color(0.19, 0.095, 0.055))
	context.make_prop_box("CampTable", Vector3(6.8, 0.55, 1.7), Vector3(2.6, 1.1, 1.4), Color(0.20, 0.13, 0.07))
	context.make_loose_role("cart", Vector3(-8.5, 0, 4.0), Vector3.ONE * 0.68, 12.0)
	for position in [Vector3(7.0, 0, -4.0), Vector3(11.5, 0, -4.0), Vector3(8.0, 0, 3.2)]:
		context.make_torch(position)
	for position in [Vector3(-14, 0, -12), Vector3(-13, 0, -2), Vector3(-14, 0, 10), Vector3(14, 0, -11), Vector3(14, 0, 8)]:
		context.make_tree(position)
	for position in [Vector3(-9, 0, -9), Vector3(10, 0, 9), Vector3(-10, 0, 11)]:
		context.make_rubble(position)

	context.make_named_interactable("captain_senn", "dialogue", "Confront Captain Senn", Vector3(8.7, 0, -1.2), Color(0.34, 0.20, 0.13))
	if context.is_quest_active("main_soldier_without_banner") and not context.is_objective_done("main_soldier_without_banner", "senn_confrontation"):
		for position in [Vector3(4.5, 0.8, -3.8), Vector3(11.0, 0.8, 1.5)]:
			var guard = context.spawn_enemy("bandit", position)
			if guard != null:
				guard.set_meta("senn_guard", true)
				guard.leash_radius = 8.0

	context.make_zone_gate("Return to the marsh crossing", Vector3(-7, 0, 16.5), "marsh_crossing", Vector3(0, 1, -12))
	context.make_zone_gate("Follow the Vargan road", Vector3(7, 0, -16.5), "vargan_approach", Vector3(0, 1, 12))
