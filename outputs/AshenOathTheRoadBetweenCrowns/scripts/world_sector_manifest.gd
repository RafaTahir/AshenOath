extends RefCounted
class_name WorldSectorManifest

const PATH := "res://world_sector_manifest.json"
static var _data: Dictionary = {}
static var _load_error := ""
static var _connection_cache: Dictionary = {}
static var _point_cache: Dictionary = {}
static var _corridor_cache: Dictionary = {}
const WALKABLE_LINKS := [
	["greyfen","north",0.0,"wychwood","south",0.0],
	["wychwood","north",10.8,"deep_wood","south",-7.0],
	["deep_wood","north",7.0,"old_mill","south",-7.0],
	["old_mill","north",7.0,"burned_farmstead","south",-7.0],
	["burned_farmstead","north",7.0,"marsh_crossing","south",0.0],
	["marsh_crossing","north",0.0,"bandit_road","south",-7.0],
	["bandit_road","east",7.0,"vargan_approach","west",16.0],
	["vargan_approach","north",0.0,"vargan_court","south",-10.5],
	["vargan_court","north",0.0,"record_hall","south",-6.0],
	["record_hall","north",6.0,"undercroft","south",-6.0],
	["greyfen","west",-10.0,"deep_wood","east",9.0],
	["greyfen","east",0.0,"vargan_approach","west",0.0],
	["greyfen","south",0.0,"hart_glade","north",-7.0],
	["hart_glade","east",9.0,"ruins","west",5.0]
]
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
	for link: Dictionary in connections(zone_id):
		if str(link.target) not in result: result.append(str(link.target))
	return result

static func available_neighbors(zone_id: String, quests, story = null) -> Array[String]:
	var result: Array[String] = []
	for target: String in neighbors(zone_id):
		var edge := connection_between(zone_id, target)
		if edge.is_empty():
			edge = edge_between(zone_id, target)
		if edge_available(edge, quests, story):
			result.append(target)
	return result

static func connections(zone_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var source := canonical(zone_id)
	if _connection_cache.has(source): return _connection_cache[source]
	for row: Array in WALKABLE_LINKS:
		var offset := 0 if str(row[0]) == source else (3 if str(row[3]) == source else -1)
		if offset < 0: continue
		var other := 3-offset
		var target := str(row[other])
		var edge := edge_between(source,target)
		edge.merge({"source":source,"target":target,"id":str(row[offset+1]),"lane":float(row[offset+2]),"half_width":2.4,"physical":true},true)
		if source == "greyfen" and target == "hart_glade":
			edge["requires_objective"] = ["main_crowns_without_mercy","confession_choice"]
		if source == "record_hall" and target == "undercroft":
			edge["requires_flag"] = "castle_haunting_cleared"
		if source == "ruins" and target == "hart_glade":
			edge["requires_unlocked_quest"] = "main_hart_remembers"
		result.append(edge)
	_connection_cache[source] = result
	return result

static func connection_between(source: String, target: String) -> Dictionary:
	for edge: Dictionary in connections(source):
		if str(edge.target) == canonical(target): return edge
	return {}

static func direction(edge_id: String) -> Vector3:
	match edge_id:
		"north": return Vector3.FORWARD
		"south": return Vector3.BACK
		"west": return Vector3.LEFT
	return Vector3.RIGHT

static func connector_points(edge: Dictionary) -> PackedVector3Array:
	var key := str(edge.source)+":"+str(edge.target)
	if _point_cache.has(key): return _point_cache[key]
	var normal := direction(str(edge.id))
	var side := normal.cross(Vector3.UP)
	var half := bounds(str(edge.source))
	var origin := Vector3(float(edge.lane),0,normal.z*half.y) if normal.z != 0.0 else Vector3(normal.x*half.x,0,float(edge.lane))
	# A short dogleg blocks the view between independently owned regions.
	# Both halves have real ground/collision; the common plane is at the end.
	var points := PackedVector3Array([origin-normal*2.0,origin+normal*4.0,origin+normal*4.0+side*6.0,origin+normal*8.0+side*6.0])
	_point_cache[key] = points
	return points

static func crossing_frame(edge: Dictionary) -> Transform3D:
	var points := connector_points(edge)
	var normal := direction(str(edge.id))
	return Transform3D(Basis(Vector3.UP,atan2(normal.x,normal.z)),points[-1])

static func crossing_transform(edge: Dictionary) -> Transform3D:
	var reverse := connection_between(str(edge.target),str(edge.source))
	return crossing_frame(reverse)*Transform3D(Basis(Vector3.UP,PI),Vector3.ZERO)*crossing_frame(edge).affine_inverse()

static func connector_contains(zone_id: String, position: Vector3, margin: float = 0.0) -> bool:
	var point := Vector2(position.x,position.z)
	for edge: Dictionary in connections(zone_id):
		if Geometry2D.is_point_in_polygon(point, connector_polygon(edge, margin)): return true
	return false

static func connector_polygon(edge: Dictionary, margin: float = 0.0) -> PackedVector2Array:
	var key := str(edge.source)+":"+str(edge.target)+":"+str(margin)
	if _corridor_cache.has(key):
		return _corridor_cache[key]
	var points := connector_points(edge)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(points.size()):
		var incoming := (points[i]-points[maxi(0,i-1)]).normalized()
		var outgoing := (points[mini(i+1,points.size()-1)]-points[i]).normalized()
		if i == 0: incoming = outgoing
		if i == points.size()-1: outgoing = incoming
		var normal_a := incoming.cross(Vector3.UP)
		var normal_b := outgoing.cross(Vector3.UP)
		var miter := (normal_a+normal_b).normalized()
		var extent := (float(edge.half_width)+margin)/maxf(0.5,miter.dot(normal_b))
		var a := points[i]-miter*extent
		var b := points[i]+miter*extent
		left.append(Vector2(a.x,a.z)); right.append(Vector2(b.x,b.z))
	right.reverse(); left.append_array(right)
	_corridor_cache[key] = left
	return left

static func clear_connector_position(zone_id: String, position: Vector3, clearance: float) -> Vector3:
	var point := Vector2(position.x,position.z)
	for _pass in range(3):
		for edge: Dictionary in connections(zone_id):
			var points := connector_points(edge)
			for i in range(points.size()-1):
				var a := Vector2(points[i].x,points[i].z)
				var b := Vector2(points[i+1].x,points[i+1].z)
				var closest := Geometry2D.get_closest_point_to_segment(point,a,b)
				var offset := point-closest
				var radius := float(edge.half_width)+clearance
				if offset.length_squared() >= radius*radius: continue
				var side := offset.normalized() if offset.length_squared() > 0.0001 else (b-a).normalized().orthogonal()
				point = closest+side*(radius+0.05)
	return Vector3(point.x,position.y,point.y)

static func open_edges(zone_id: String) -> Dictionary:
	return (sector(zone_id).get("edges", {}) as Dictionary).duplicate(true)

static func atlas() -> Dictionary:
	_ensure_loaded()
	var view: Dictionary = _data.get("atlas", {}).duplicate(true)
	var links: Array[Dictionary] = []
	var seen: Dictionary = {}
	var add_link := func(source: String, target: String):
		var pair: Array[String] = [source,target]; pair.sort()
		var key := ":".join(pair)
		if seen.has(key):
			var existing: Dictionary = seen[key]
			if source != str(existing.source): existing["return"] = true
			return
		var journey := false
		for raw: Array in view.get("journey_links", []):
			if source in raw and target in raw: journey = true
		var link := {"source":source,"target":target,"journey":journey,"return":false}
		seen[key] = link
		links.append(link)
	for source: String in all_ids():
		for target: String in neighbors(source): add_link.call(source,target)
	for pair: Array in view.get("local_links", []): add_link.call(str(pair[0]),str(pair[1]))
	view["links"] = links
	return view

static func edge_available(edge: Dictionary, quests, story = null) -> bool:
	if edge.has("requires_flag") and (story == null or not bool(story.get_flag(str(edge.requires_flag),false))): return false
	if edge.has("requires_unlocked_quest"):
		var id := str(edge.requires_unlocked_quest)
		if quests == null or not (quests.is_unlocked(id) or quests.is_active(id) or quests.is_completed(id) or (story != null and bool(story.get_flag("final_choice_completed",false)))): return false
	var requirement: Array = edge.get("requires_objective", [])
	if requirement.size() < 2: return true
	return quests != null and (quests.is_completed(str(requirement[0])) or quests.is_objective_done(str(requirement[0]),str(requirement[1])))

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
