extends RefCounted

## The Web pack keeps the complete source catalog. Byte ranges address UTF-8 records.
const PATH := "res://voice_production_manifest.json"
var ranges: Dictionary = {}
var matches: Dictionary = {}
var origin := 0
var generated_allowed := false

static func canonical_speaker(speaker: String) -> String:
	var identity: String = preload("res://scripts/story_cast_profile.gd").canonical_identity(speaker.strip_edges())
	return identity if not identity.is_empty() else speaker.strip_edges()

func open_index() -> bool:
	if not FileAccess.file_exists(PATH):
		return false
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null or file.get_line() != '{"runtime_voice_format":1,':
		return false
	var header := file.get_line()
	if not header.begins_with('"runtime_lookup":') or not header.ends_with(","):
		return false
	var index: Variant = JSON.parse_string(header.trim_prefix('"runtime_lookup":').trim_suffix(","))
	if not index is Dictionary or not index.get("takes") is Array:
		return false
	if file.get_line() not in ['"lines":[', '"lines":{']:
		return false
	origin = file.get_position()
	var aliases: Dictionary = {}
	for row: Array in index.takes:
		var speaker := str(row[1])
		if not aliases.has(speaker):
			aliases[speaker] = canonical_speaker(speaker)
		var key := str(aliases[speaker]) + "|" + str(row[2])
		if not matches.has(key):
			matches[key] = []
		matches[key].append([row[0], row[5]])
		ranges[row[0]] = Vector2i(int(row[3]), int(row[4]))
	generated_allowed = bool(index.get("allow_generated", false))
	return true

func candidates(speaker: String, text: String, scene: String) -> Array[String]:
	var ids: Array[String] = []
	for row: Array in matches.get(speaker + "|" + text.sha256_text(), []):
		if not scene.is_empty() and row[1] == scene:
			ids.push_front(str(row[0]))
		else:
			ids.append(str(row[0]))
	return ids

func read_take(id: String) -> Dictionary:
	if not ranges.has(id):
		return {}
	var span: Vector2i = ranges[id]
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null or span.x < 0 or span.y <= 0 or origin + span.x + span.y > file.get_length():
		return {}
	file.seek(origin + span.x)
	var value: Variant = JSON.parse_string(file.get_buffer(span.y).get_string_from_utf8())
	return value if value is Dictionary else {}
