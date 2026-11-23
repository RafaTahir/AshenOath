extends RefCounted
## Resource inputs for selected-road construction, resolved after its packs mount.

const WYCHWOOD_OPENING_WAVES: Array[String] = [
	"ghoulkin", "ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute",
]

static func paths(host: Node, target: String) -> Array[String]:
	var required: Array[String] = ["res://scripts/story_activity_director.gd", "res://scripts/journey_flow_director.gd"]
	if target == "greyfen":
		required.append(preload("res://scripts/core/prepared_greyfen_social_collision.gd").PATH)
		required.append_array(preload("res://scripts/greyfen_social_presentation.gd").MESHES.values())
		for actor_id: String in ["sister_anwen"] + host.OPENING_NAMED_ACTOR_IDS:
			var role: String = host._role_for_interactable(actor_id)
			var visual: String = host._visual_role_for_legacy_character(role)
			var use_visual: bool = not visual.is_empty() and host.asset_helper.has_visual_role(visual)
			var path: String = host.asset_helper.role_resource_path(visual, true, role) if use_visual else host.asset_helper.role_resource_path(role)
			required.append(path)
	elif target == "wychwood":
		required.append_array(preload("res://scripts/core/wychwood_ground_geometry.gd").resource_paths())
		if host.quests.is_active("main_road_of_crows") and not host.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
			var roles := preload("res://scripts/views/enemy_body_view.gd").CREATURE_VISUAL_ROLES
			for enemy_id: String in WYCHWOOD_OPENING_WAVES:
				var path: String = host.asset_helper.role_resource_path(roles[enemy_id], true)
				if path not in required:
					required.append(path)
	var music_id: String = host.audio.music_state_for_zone(target)
	var music_path: String = host.audio.prepared_audio.entries.get("music", {}).get(music_id, "")
	if not music_path.is_empty() and ResourceLoader.exists(music_path):
		required.append(music_path)
	return required
