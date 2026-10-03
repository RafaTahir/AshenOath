extends RefCounted

const WildsPresentation = preload("res://scripts/zones/campaign_wilds_presentation.gd")
const LandscapePresentation = preload("res://scripts/world_landscape_presentation.gd")
const BanditFrontier = preload("res://scripts/bandit_frontier.gd")
const StoryActorPresence = preload("res://scripts/story_actor_presence.gd")

const ZONES := ["bandit_road"]

func build(context: ZoneBuildContext) -> void:
	var ground := Color(0.105, 0.085, 0.058)
	context.make_ground(Vector3(0, -0.08, 0), Vector3(44, 0.16, 38), ground)
	context.make_play_area_bounds(44.0, 38.0, ground.darkened(0.38))
	WildsPresentation.landscape(context)
	BanditFrontier.build(context)

	var marker := Node3D.new()
	marker.name = "CampaignSection_bandit_road"
	context.add_node(marker)
	var authored := Node3D.new()
	authored.name = "AuthoredBanditRoad"
	context.add_node(authored)

	_make_checkpoint(context)

	# Camp structures are beyond both the testimony clearing and east approach.
	context.make_loose_role("cart", Vector3(-8.5, 0, 4.0), Vector3.ONE * 0.68, 12.0)
	for position in [Vector3(4.3, 0, -2.0), Vector3(11.7, 0, 2.7)]:
		context.make_torch(position)
	# Keep the east tree on the outer shoulder. At (14, 8) its collider cut
	# across the diagonal arrival lane toward the Vargan boundary.
	for position in [Vector3(-14, 0, -12), Vector3(-13, 0, -2), Vector3(-14, 0, 10), Vector3(19, 0, -2), Vector3(17, 0, 11)]:
		context.make_tree(position)
	# Keep the east-side rubble on the outer shoulder. The former (10, 9)
	# placement sat inside the diagonal approach from the marsh arrival to the
	# Vargan boundary and blocked a player-sized capsule before the edge.
	for position in [Vector3(-9, 0, -9), Vector3(16, 0, 10), Vector3(-10, 0, 11)]:
		context.make_rubble(position)

	if StoryActorPresence.remains("captain_senn", str(context.get_story_flag("senn_fate", ""))):
		context.make_named_interactable("captain_senn", "dialogue", "Confront Captain Senn", Vector3(8.7, 0, -1.2), Color(0.34, 0.20, 0.13))
	if context.is_quest_active("side_soldiers_debt") and not context.is_objective_done("side_soldiers_debt", "find_deserters"):
		context.make_clue("deserters_muster", "Read the deserters' hidden muster roll", Vector3(1.6, 0, 3.8), "side_soldiers_debt", "find_deserters", Color(0.38, 0.29, 0.19))
	if context.is_quest_active("main_soldier_without_banner") and not context.is_objective_done("main_soldier_without_banner", "senn_confrontation") and not bool(context.get_story_flag("senn_guards_stood_down", false)):
		for guard_spec in [[Vector3(4.5, 0.8, -3.8), "bandit_deserter"], [Vector3(11.0, 0.8, 1.5), "bandit_tracker"]]:
			var guard = context.spawn_enemy("bandit", guard_spec[0], guard_spec[1])
			if guard != null:
				guard.set_meta("senn_guard", true)
				guard.leash_radius = 8.0

	context.make_zone_gate("Return to the marsh crossing", Vector3(-7, 0, 16.5), "marsh_crossing", Vector3(0, 1, -12))
	context.make_zone_gate("Follow the Vargan road", Vector3(7, 0, -16.5), "vargan_approach", Vector3(0, 1, 12))

func _make_checkpoint(context: ZoneBuildContext) -> void:
	for x in [-7.5, 7.5]:
		context.make_collision_box("CheckpointStone", Vector3(x, 1.4, -6), Vector3(2.3, 2.8, 2.3))
		context.make_collision_box("CheckpointBeam", Vector3(x, 3.1, -6), Vector3(3.4, 0.28, 0.34))
	context.make_collision_box("RoadCrossbeam", Vector3(0, 3.1, -6), Vector3(12.8, 0.30, 0.35))
	for x in [-11.5, 11.5]:
		context.make_collision_box("CheckpointFence", Vector3(x, 0.625, -5), Vector3(2.4, 1.25, 0.25))
	context.make_collision_box("CommandTent", Vector3(12.0, 1.35, -8.0), Vector3(6.0, 2.7, 4.8))
	context.make_collision_box("CampTable", Vector3(9.5, 0.55, -2.3), Vector3(2.6, 1.1, 1.4))
	WildsPresentation.checkpoint(context)
