extends RefCounted

var entries: Dictionary = {}

func _init() -> void:
	var path := "res://data/prepared_audio.json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			entries = parsed

func stream(category: String, id: String) -> AudioStream:
	var path := str(entries.get(category, {}).get(id, ""))
	# Campaign entries are legal before their pack mounts; never cache a miss.
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as AudioStream
