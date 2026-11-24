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
	elif target in ["vargan_approach", "vargan_court"]:
		required.append("res://assets_external/environment/village/Wall_UnevenBrick_Straight.obj")
	var music_id: String = host.audio.music_state_for_zone(target)
	var music_path: String = host.audio.prepared_audio.entries.get("music", {}).get(music_id, "")
	if not music_path.is_empty() and ResourceLoader.exists(music_path):
		required.append(music_path)
	return required

static func arrival_point(edge: Dictionary, authored: Variant) -> Vector3:
	if authored is Vector3 and authored != Vector3.ZERO:
		return authored
	var raw: Array = edge.get("arrival",[])
	if raw.size() >= 3: return Vector3(float(raw[0]),float(raw[1]),float(raw[2]))
	var reverse := WorldSectorManifest.connection_between(str(edge.target),str(edge.source))
	if not reverse.is_empty():
		var inside := WorldSectorManifest.connector_points(reverse)[0]-WorldSectorManifest.direction(str(reverse.id))
		return Vector3(inside.x,1.0,inside.z)
	return Vector3(0,1,0)

static func kept_sector_ids(zone_id: String, story: Node) -> Array[String]:
	var kept: Array[String] = [zone_id]
	for neighbor in WorldSectorManifest.neighbors(zone_id,story):
		if neighbor not in kept:
			kept.append(neighbor)
	return kept

static func layers(zone_id: String) -> Array[String]:
	var selected: Array[String] = ["gameplay"]
	if zone_id != "greyfen":
		selected.append("decoration")
	return selected

static func distance_to(edge: Dictionary, position: Vector3) -> float:
	var points := WorldSectorManifest.connector_points(edge)
	var point := Vector2(position.x,position.z)
	var proximity := INF
	for i in range(points.size()-1):
		proximity = minf(proximity,point.distance_to(Geometry2D.get_closest_point_to_segment(point,Vector2(points[i].x,points[i].z),Vector2(points[i+1].x,points[i+1].z))))
	return proximity

static func current_job(jobs: Dictionary, target: String, host: Node) -> Dictionary:
	var job: Dictionary = jobs.get(target,{})
	if int(job.get("generation", -1)) != host.journey_arrival_generation or str(job.get("journey_id", "")) != str(host.save_manager.journey_id):
		return {}
	if str(job.get("source", "")) != str(host.current_zone_id) or str(job.get("quality", "")) != str(host.settings.settings.get("quality_preset", "balanced")):
		return {}
	return job

static func forest_road(edge: Dictionary) -> bool:
	return (edge.get("source") == "wychwood" and edge.get("target") == "deep_wood") \
		or (edge.get("source") == "deep_wood" and edge.get("target") == "wychwood")
