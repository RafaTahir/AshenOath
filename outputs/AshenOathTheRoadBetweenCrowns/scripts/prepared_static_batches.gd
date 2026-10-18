extends RefCounted

const PATH := "res://data/prepared_static_batches.res"
static var _catalog: Resource

static func entry(id: String) -> Dictionary:
	if _catalog == null:
		_catalog = load(PATH) as Resource
	if _catalog == null or not _catalog.has_meta("entries"):
		push_error("Required prepared static batch data is missing")
		return {}
	var entries: Dictionary = _catalog.get_meta("entries")
	if not entries.has(id):
		push_error("Required prepared static batch entry is missing: " + id)
		return {}
	return entries[id]
