extends RefCounted

const ZoneSceneCatalog = preload("res://scripts/zone_scene_catalog.gd")
const ZoneCompositionRouter = preload("res://scripts/zone_composition_router.gd")
const OPENING_WELL_MESH := "res://assets_external/environment/village/GreyfenWell_Authored.res"

static func scene_paths() -> Array[String]:
	var scene_paths := ZoneSceneCatalog.resource_paths("greyfen", ["gameplay"])
	scene_paths.append_array(ZoneCompositionRouter.resource_paths("greyfen"))
	scene_paths.append_array([
		OPENING_WELL_MESH,
		"res://assets_external/environment/village/GreyfenShrine_Authored.res",
		"res://assets_external/environment/village/GreyfenForge_Authored.res",
	])
	return scene_paths

static func actor_roles(game: Node) -> Array[String]:
	var named_roles: Array[String] = ["player_kael", "sister_anwen"]
	for actor_id in game.OPENING_NAMED_ACTOR_IDS:
		named_roles.append(game._role_for_interactable(actor_id))
	return named_roles
