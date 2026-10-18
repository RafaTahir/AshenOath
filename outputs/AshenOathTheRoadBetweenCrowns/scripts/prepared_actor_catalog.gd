extends RefCounted

const INDEX := "res://data/prepared_actors.json"
static var _loaded := false
static var _entries: Dictionary = {}

static func entry(role: String, source: String, variant_seed: String = "") -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(INDEX):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
			if parsed is Dictionary:
				_entries = parsed
	var record: Dictionary = _entries.get(role + "|" + source, {})
	if not variant_seed.is_empty() and not bool(record.get("variant_safe", false)):
		return {}
	return record
