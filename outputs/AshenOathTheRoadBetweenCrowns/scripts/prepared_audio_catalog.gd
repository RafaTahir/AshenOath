extends RefCounted

signal failures_changed

var entries: Dictionary = {}
var failures: Dictionary = {}
var available_owners: Dictionary = {"menu": true}

func _init() -> void:
	_load_catalog()
	if not OS.has_feature("web"):
		available_owners["opening"] = true
		available_owners["campaign"] = true

func _load_catalog() -> void:
	var path := "res://data/prepared_audio.json"
	if not FileAccess.file_exists(path):
		_record_failure("catalog", "catalog", path, "Audio catalog is missing")
		return
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(path))
	if error != OK or not parser.data is Dictionary:
		_record_failure("catalog", "catalog", path, "Audio catalog could not be read: %s" % parser.get_error_message())
		return
	for category in ["cues", "music", "ambience"]:
		if not parser.data.get(category) is Dictionary:
			_record_failure("catalog", "catalog", path, "Audio catalog has no valid %s table" % category)
			return
	entries = parser.data
	if failures.erase("catalog:catalog"):
		failures_changed.emit()

func recover_catalog() -> void:
	if failures.has("catalog:catalog"):
		_load_catalog()

func mark_pack_available(pack_id: String) -> void:
	if pack_id in ["opening", "campaign"]:
		available_owners[pack_id] = true

func stream(category: String, id: String) -> AudioStream:
	var path := str(entries.get(category, {}).get(id, ""))
	# Campaign entries are legal before their pack mounts; never cache a miss.
	# Recorded-only events also legitimately have no synthesized counterpart.
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		var owner := path.get_base_dir().get_file()
		if bool(available_owners.get(owner, false)):
			_record_failure(category, id, path, "Sound resource is missing from its mounted pack")
		return null
	var result := ResourceLoader.load(path) as AudioStream
	if result == null:
		_record_failure(category, id, path, "Sound resource could not be loaded as audio")
	elif failures.erase(category + ":" + id):
		failures_changed.emit()
	return result

func _record_failure(category: String, id: String, path: String, reason: String) -> void:
	var key := category + ":" + id
	if failures.has(key):
		return
	failures[key] = {"category": category, "id": id, "path": path, "reason": reason}
	push_warning("AUDIO: %s (%s): %s" % [id, path, reason])
	failures_changed.emit()
