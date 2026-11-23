extends RefCounted

static func materials(context: ZoneBuildContext, stone: bool) -> Dictionary:
	# Staged and immediate construction share the same zone-owned finishes.
	var quality := context.quality_preset()
	var materials: Dictionary = context.scope.road_materials
	if str(materials.get("quality", "")) == quality:
		return materials
	var ground := context.make_world_material("cobblestone" if stone else "forest_ground", Color(0.43, 0.47, 0.40)).duplicate() as BaseMaterial3D
	var banks := context.make_world_material("medieval_brick" if stone else "forest_ground", Color(0.39, 0.43, 0.35)).duplicate() as BaseMaterial3D
	ground.cull_mode = BaseMaterial3D.CULL_DISABLED
	banks.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground.emission_enabled = true
	ground.emission = Color(0.06, 0.07, 0.06)
	ground.emission_energy_multiplier = 0.2
	var timber := context.make_world_material("timber", Color(0.52, 0.45, 0.32))
	var masonry := context.make_world_material("medieval_brick", Color(0.60, 0.61, 0.55)).duplicate() as BaseMaterial3D
	masonry.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials = {"quality": quality, "ground": ground, "banks": banks, "timber": timber, "masonry": masonry}
	context.scope.road_materials = materials
	return materials
