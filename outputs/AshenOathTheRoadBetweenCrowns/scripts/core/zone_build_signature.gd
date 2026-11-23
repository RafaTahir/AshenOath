extends RefCounted

static func for_zone(zone_id: String, quests: Node, story_state: Node, removed_interactions: Dictionary, quality: String) -> int:
	var quest_world_state: Dictionary = quests.world_signature_state(zone_id) if quests != null else {}
	var story_world_state: Dictionary = story_state.world_signature_state(zone_id) if story_state != null else {}
	if story_world_state.get("flags") is Dictionary:
		# Live companion movement and clothing wear do not change zone construction.
		var zone_flags: Dictionary = story_world_state.flags.duplicate()
		zone_flags.erase("bracken_travel")
		zone_flags.erase("everyday_wear")
		story_world_state.flags = zone_flags
	var zone_removed: Dictionary = {}
	for key: String in removed_interactions:
		if key.begins_with(zone_id + ":"): zone_removed[key] = removed_interactions[key]
	return hash([
		story_world_state,
		quest_world_state,
		zone_removed,
		quality,
	])
