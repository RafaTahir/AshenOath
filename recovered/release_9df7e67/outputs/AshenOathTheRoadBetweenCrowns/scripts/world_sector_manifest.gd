extends RefCounted
class_name WorldSectorManifest

const PATH := "res://world_sector_manifest.json"
static var _data: Dictionary = {}
static var _load_error := ""
static var _aliases := {
	"deep_woods": "deep_wood",
	"long_road": "bandit_road",
	"castle_approach": "vargan_approach",
	"courtyard": "vargan_court"
}

static func is_valid() -> bool:
	_ensure_loaded()
	return _load_error == "" and not (_data.get("sectors", {}) as Dictionary).is_empty()

static func load_error() -> String:
	_ensure_loaded()
	return _load_error

static func canonical(zone_id: String) -> String:
	var normalized := zone_id.strip_edges().to_lower()
	return str(_aliases.get(normalized, normalized))

static func all_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for key in _data.get("sectors", {}).keys():
		result.append(str(key))
	result.sort()
	return result

static func sector(zone_id: String) -> Dictionary:
	_ensure_loaded()
	return (_data.get("sectors", {}) as Dictionary).get(canonical(zone_id), {}).duplicate(true)

static func is_exterior(zone_id: String) -> bool:
	return bool(sector(zone_id).get("exterior", false))

static func bounds(zone_id: String) -> Vector2:
	var raw: Array = sector(zone_id).get("bounds", [20.0, 16.0])
	return Vector2(float(raw[0]), float(raw[1])) if raw.size() >= 2 else Vector2(20.0, 16.0)

static func neighbors(zone_id: String) -> Array[String]:
	var result: Array[String] = []
	var record := sector(zone_id)
	for edge in (record.get("edges", {}) as Dictionary).values():
		var target := canonical(str(edge.get("target", "")))
		if target != "" and target not in result:
			result.append(target)
	for interior in record.get("interior_doors", []):
		var target := canonical(str(interior))
		if target != "" and target not in result:
			result.append(target)
	return result

static func open_edges(zone_id: String) -> Dictionary:
	return (sector(zone_id).get("edges", {}) as Dictionary).duplicate(true)

static func edge_between(source_zone: String, target_zone: String) -> Dictionary:
	var target := canonical(target_zone)
	for edge_id in open_edges(source_zone).keys():
		var edge: Dictionary = open_edges(source_zone).get(edge_id, {})
		if canonical(str(edge.get("target", ""))) == target:
			var result := edge.duplicate(true)
			result["id"] = str(edge_id)
			result["source"] = canonical(source_zone)
			return result
	return {}

static func edge_for_position(zone_id: String, position: Vector3, zone_bounds: Vector2, margin: float = 0.75) -> Dictionary:
	var edges := open_edges(zone_id)
	var candidates: Array[Dictionary] = []
	for edge_id in edges.keys():
		var edge: Dictionary = edges[edge_id]
		var half_width := float(edge.get("half_width", 3.0))
		var lane := float(edge.get("lane", 0.0))
		var valid := false
		# Authored gates can sit a few metres inside a sector boundary so their
		# approach has room for a readable landmark. Treat that threshold as part
		# of the same spatial contract; otherwise a player can reach the visible
		# gate and remain outside the boundary query forever.
		var raw_trigger: Array = edge.get("trigger", [])
		if raw_trigger.size() >= 3:
			var trigger := Vector3(float(raw_trigger[0]), float(raw_trigger[1]), float(raw_trigger[2]))
			var trigger_radius := maxf(float(edge.get("trigger_radius", 1.35)), margin + 0.45)
			valid = Vector2(position.x - trigger.x, position.z - trigger.z).length() <= trigger_radius
		match str(edge_id):
			"north": valid = valid or (position.z <= -zone_bounds.y + margin and absf(position.x - lane) <= half_width)
			"south": valid = valid or (position.z >= zone_bounds.y - margin and absf(position.x - lane) <= half_width)
			"west": valid = valid or (position.x <= -zone_bounds.x + margin and absf(position.z - lane) <= half_width)
			"east": valid = valid or (position.x >= zone_bounds.x - margin and absf(position.z - lane) <= half_width)
		if valid:
			var result := edge.duplicate(true)
			result["id"] = str(edge_id)
			result["source"] = canonical(zone_id)
			candidates.append(result)
	if candidates.is_empty():
		return {}
	return candidates[0]

static func local_to_world(zone_id: String, local_position: Vector3) -> Vector3:
	_ensure_loaded()
	var record := sector(zone_id)
	var coordinate: Array = record.get("coordinate", [0, 0])
	var cell: Array = _data.get("cell_size", [48.0, 40.0])
	return Vector3(
		float(coordinate[0]) * float(cell[0]) + local_position.x,
		local_position.y,
		float(coordinate[1]) * float(cell[1]) + local_position.z
	)

static func world_to_local(zone_id: String, world_position: Vector3) -> Vector3:
	_ensure_loaded()
	var record := sector(zone_id)
	var coordinate: Array = record.get("coordinate", [0, 0])
	var cell: Array = _data.get("cell_size", [48.0, 40.0])
	return Vector3(
		world_position.x - float(coordinate[0]) * float(cell[0]),
		world_position.y,
		world_position.z - float(coordinate[1]) * float(cell[1])
	)

static func _ensure_loaded() -> void:
	if not _data.is_empty():
		return
	if not FileAccess.file_exists(PATH):
		_load_error = "missing:%s" % PATH
		_data = {"sectors": {}}
		push_error("WORLD SECTOR MANIFEST: %s" % _load_error)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("sectors", null)) != TYPE_DICTIONARY:
		_load_error = "invalid:%s" % PATH
		_data = {"sectors": {}}
		push_error("WORLD SECTOR MANIFEST: %s" % _load_error)
		return
	_data = parsed
	if (_data.get("sectors", {}) as Dictionary).is_empty():
		_load_error = "empty:%s" % PATH
		push_error("WORLD SECTOR MANIFEST: %s" % _load_error)
