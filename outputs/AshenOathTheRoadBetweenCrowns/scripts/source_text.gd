extends RefCounted

## English source catalog is generated from stable content locations. Runtime
## text stays selectable and reflows. Additional languages require authored
## catalogs and appropriate licensed fonts before being exposed in Settings.
const CATALOG_PATH := "res://data/localization/en.json"
const COMMUNITY_PATH := "res://data/localization/community_en.json"
static var _strings: Dictionary = {}
static var _source_ids: Dictionary = {}
static var _loaded := false
static var _community_strings: Dictionary = {}
static var _community_ids: Dictionary = {}
static var _community_loaded := false

static func _load_catalog() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(CATALOG_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("strings")) != TYPE_DICTIONARY:
		return
	_strings = parsed.strings
	for id in _strings:
		var entry: Variant = _strings[id]
		if typeof(entry) == TYPE_DICTIONARY:
			_source_ids[str(entry.get("source", ""))] = str(id)

static func _load_community_catalog() -> void:
	# The story owner has already validated a needed mounted overlay. Generic
	# startup labels must not pull late prose into the opening localization cache.
	if _community_loaded or not preload("res://scripts/campaign_story_overlay.gd").is_loaded(): return
	if not FileAccess.file_exists(COMMUNITY_PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COMMUNITY_PATH))
	if not parsed is Dictionary or not parsed.get("strings") is Dictionary: return
	_community_strings=parsed.strings
	for id: String in _community_strings:
		var entry: Variant=_community_strings[id]
		if entry is Dictionary: _community_ids[str(entry.get("source",""))]=id
	_community_loaded=true

static func text(id: String, fallback: String = "") -> String:
	_load_catalog()
	var entry: Variant = _strings.get(id, {})
	if not entry is Dictionary or entry.is_empty():
		_load_community_catalog()
		entry=_community_strings.get(id,{})
	return str(entry.get("text", entry.get("source", fallback))) if typeof(entry) == TYPE_DICTIONARY else fallback

static func localize(source: String) -> String:
	_load_catalog()
	var id := source_id(source)
	return text(id, source) if id != "" else source

static func source_id(source: String) -> String:
	_load_catalog()
	if _source_ids.has(source): return str(_source_ids[source])
	_load_community_catalog()
	return str(_community_ids.get(source,""))

static func reading_seconds(source: String, words_per_minute: float = 155.0) -> float:
	return maxf(2.5, float(source.split(" ", false).size()) * 60.0 / maxf(words_per_minute, 60.0))
