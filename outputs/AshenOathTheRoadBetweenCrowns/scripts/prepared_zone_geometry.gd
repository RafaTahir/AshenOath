extends RefCounted

const ROOT := "res://assets_external/environment/prepared/"
static var _resources: Dictionary = {}
static var _owners: Dictionary = {}
static var _scope := "shared"

static func set_zone_scope(zone: String) -> void:
	_scope = zone if zone != "" else "shared"

static func retain_zone_scopes(zones: Array) -> void:
	for id: String in _owners.keys():
		var owners: Dictionary = _owners[id]
		for zone: String in owners.keys():
			if zone != "shared" and zone not in zones:
				owners.erase(zone)
		if owners.is_empty():
			_resources.erase(id)
			_owners.erase(id)

static func geometry_key(size: Vector3, origin: Vector3) -> String:
	return var_to_bytes([size, origin]).hex_encode().sha256_text().substr(0, 24)

static func mesh(id: String) -> ArrayMesh:
	return resource(id) as ArrayMesh

static func resource(id: String) -> Resource:
	if not _resources.has(id):
		var path := ROOT + id + ".res"
		var loaded := load(path) if ResourceLoader.exists(path) else null
		if loaded == null:
			push_error("Required prepared zone geometry is missing: %s" % path)
			return null
		_resources[id] = loaded
	if not _owners.has(id):
		_owners[id] = {}
	_owners[id][_scope] = true
	return _resources[id]

static func clear() -> void:
	_resources.clear() # Live scene instances retain their own resource references.
	_owners.clear()
	_scope = "shared"
