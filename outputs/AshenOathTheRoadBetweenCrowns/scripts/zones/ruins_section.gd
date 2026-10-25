extends RefCounted

func build(context: ZoneBuildContext) -> void:
	context.make_ground(Vector3(0, -0.08, 0), Vector3(48, 0.16, 42), Color(0.13, 0.13, 0.13))
	context.make_play_area_bounds(48.0, 42.0, Color(0.075, 0.075, 0.075))
	context.make_road(Vector3(-5, 0.018, 3), Vector3(24.0, 0.04, 4.0), Color(0.09, 0.08, 0.075))
	context.make_light("Ruin Fire", Vector3(-4, 4, -5), Color(0.9, 0.42, 0.22), 4.0)
	context.make_torch(Vector3(-6.5, 0, -4.5))
	context.make_torch(Vector3(6.5, 0, -4.0))
	for pos in [Vector3(-8,0,-5), Vector3(0,0,-8), Vector3(8,0,-4), Vector3(0,0,8)]:
		context.make_prop_box("BrokenWall", pos + Vector3(0,1,0), Vector3(5,2,0.7), Color(0.24,0.24,0.23))
	for pos in [Vector3(-10,0,-10), Vector3(-5,0,-11), Vector3(5,0,-11), Vector3(10,0,-10), Vector3(-10,0,7), Vector3(10,0,7)]:
		context.make_pillar(pos)
	for pos in [Vector3(-1,0,-6.5), Vector3(1,0,-6.2), Vector3(3,0,-6.8)]:
		context.make_rubble(pos)
	var late_road: bool = context.is_quest_unlocked("main_hart_remembers") or context.is_quest_active("main_hart_remembers") or bool(context.get_story_flag("final_choice_completed", false))
	if late_road:
		context.make_road(Vector3(-15,0.018,5), Vector3(16,0.04,3.2), Color(0.12,0.14,0.10))
		context.make_zone_gate("Return along the Hart Glade path", Vector3(-21,0,5), "hart_glade", Vector3(18,1,9))
		return
	# Retain the legacy district's historical behavior only outside the new
	# late optional visit; no second Edric or Hart can skip the current campaign.
	context.make_zone_gate("Take the return journey to Greyfen", Vector3(20, 0, 5), "greyfen", Vector3(17, 1, -2))
	context.make_named_interactable("edric", "dialogue", "Talk to Lord Edric", Vector3(-14, 0, 3), Color(0.44, 0.35, 0.24))
	context.make_clue("old_hall", "Search old hall", Vector3(-2, 0, -4), "main_blood_under_stone", "locate_record_hall", Color(0.28, 0.24, 0.21))
	context.make_clue("ritual_inscription", "Read ritual inscription", Vector3(4, 0, -8), "main_blood_under_stone", "evidence_iron_binding", Color(0.43, 0.39, 0.35))
	context.make_clue("spirit_clearing", "Enter spirit clearing", Vector3(10, 0, 8), "main_hart_remembers", "enter_glade", Color(0.70, 0.72, 0.66))
	if context.is_quest_active("main_blood_under_stone") and not context.is_objective_done("main_blood_under_stone", "survive_haunting"):
		context.spawn_enemy("gravebound_knight", Vector3(3, 0.8, -3))
	if context.is_quest_active("main_hart_remembers") or context.is_quest_unlocked("main_hart_remembers"):
		context.make_named_interactable("white_hart", "dialogue", "Speak to the White Hart", Vector3(12, 0, 10), Color(0.86, 0.83, 0.70), Vector3(0.36, 0.64, 0.36))
