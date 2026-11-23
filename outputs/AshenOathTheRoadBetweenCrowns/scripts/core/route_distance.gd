extends RefCounted

const SectorManifest = preload("res://scripts/world_sector_manifest.gd")

static func steps_to(source: String, destination: String, excluded_zone: String, quests: Node, story_state: Node) -> int:
	# The manifest supplies adjacency, not a revealed map. Only the available
	# gate in the current place is ever shown to the player.
	if source == destination:
		return 0
	var visited: Dictionary = {excluded_zone:true, source:true}
	var queue: Array = [[source, 0]]
	while not queue.is_empty():
		var entry: Array = queue.pop_front()
		for next_zone in SectorManifest.available_neighbors(str(entry[0]), quests, story_state):
			if visited.has(next_zone):
				continue
			var steps: int = int(entry[1]) + 1
			if next_zone == destination:
				return steps
			visited[next_zone] = true
			queue.append([next_zone, steps])
	return -1
