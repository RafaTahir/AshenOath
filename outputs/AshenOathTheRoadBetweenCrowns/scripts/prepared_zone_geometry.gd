extends RefCounted

const ROOT := "res://assets_external/environment/prepared/"
static var _resources: Dictionary = {}

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
	return _resources[id]

static func clear() -> void:
	_resources.clear() # Live scene instances retain their own resource references.
