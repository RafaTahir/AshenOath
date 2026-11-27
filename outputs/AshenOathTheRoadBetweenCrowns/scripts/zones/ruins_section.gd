extends RefCounted

const Ruins = preload("res://scripts/builders/ruins_builder.gd")

func step_count(_zone_id: String) -> int:
	return 4

func build_step(context: ZoneBuildContext, index: int) -> bool:
	match index:
		0: Ruins.ground_and_lights(context)
		1: Ruins.walls(context)
		2: Ruins.pillars_and_rubble(context)
		3: Ruins.routes_and_encounters(context)
		_: return false
	return true

func build(context: ZoneBuildContext) -> void:
	for index in range(step_count(context.zone_id)):
		build_step(context, index)
