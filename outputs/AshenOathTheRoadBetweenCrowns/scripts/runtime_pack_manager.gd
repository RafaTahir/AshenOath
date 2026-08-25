extends Node
class_name RuntimePackManager

## Transactional split-pack lifecycle. The embedded PCK remains a safe fallback
## when a pack has no configured URL; downloaded packs are verified into a
## temporary user-cache file before they are mounted.
signal pack_progress(pack_id: String, progress: float)
signal pack_ready(pack_id: String)
signal pack_failed(pack_id: String, reason: String)
signal pack_cached(pack_id: String, path: String)
signal pack_mounted(pack_id: String, path: String)
signal pack_cancelled(pack_id: String)

const MANIFEST_PATH := "res://runtime_pack_manifest.json"
const CACHE_ROOT := "user://ashenoath_packs"
const CACHE_INDEX_PATH := "user://ashenoath_packs/cache_index.json"
const MAX_DEPLOYMENT_BYTES := 104857600
const MAX_RETRIES := 2
const CHUNK_SIZE := 1024 * 1024

var manifest: Dictionary = {}
var requests: Dictionary = {}
var mounted: Dictionary = {}
var cache_index: Dictionary = {}
var source_overrides: Dictionary = {}
var http_request: HTTPRequest
var active_download_id := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_manifest()
	_load_cache_index()
	http_request = HTTPRequest.new()
	http_request.name = "RuntimePackHTTPRequest"
	http_request.download_chunk_size = CHUNK_SIZE
	add_child(http_request)
	http_request.request_completed.connect(_on_download_completed)

func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		manifest = {}
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	manifest = parsed if parsed is Dictionary else {}

func _load_cache_index() -> void:
	cache_index = {}
	if not FileAccess.file_exists(CACHE_INDEX_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CACHE_INDEX_PATH))
	if parsed is Dictionary:
		cache_index = parsed

func _save_cache_index() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_ROOT))
	var file := FileAccess.open(CACHE_INDEX_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(cache_index, "  "))
		file.close()

func _normalise_id(pack_id: String) -> String:
	return pack_id.strip_edges().to_lower()

func get_pack(pack_id: String) -> Dictionary:
	var id := _normalise_id(pack_id)
	var value: Variant = manifest.get("packs", {}).get(id, {})
	return value if value is Dictionary else {}

func get_state(pack_id: String) -> String:
	return str(requests.get(_normalise_id(pack_id), {}).get("state", ""))

func get_last_error(pack_id: String) -> String:
	return str(requests.get(_normalise_id(pack_id), {}).get("error", ""))

func get_progress(pack_id: String) -> float:
	return clampf(float(requests.get(_normalise_id(pack_id), {}).get("progress", 0.0)), 0.0, 1.0)

func is_ready(pack_id: String) -> bool:
	var id := _normalise_id(pack_id)
	return bool(mounted.get(id, false)) or get_state(id) == "ready"

func is_cached(pack_id: String) -> bool:
	var id := _normalise_id(pack_id)
	var path := _cache_path(id)
	return FileAccess.file_exists(path) and _validate_artifact(id, path, false).is_empty()

func get_cache_path(pack_id: String) -> String:
	return _cache_path(_normalise_id(pack_id))

func set_pack_source(pack_id: String, url: String) -> void:
	var id := _normalise_id(pack_id)
	if id != "" and url.strip_edges() != "":
		source_overrides[id] = url.strip_edges()

func request_pack(pack_id: String) -> bool:
	var id := _normalise_id(pack_id)
	if id == "":
		return false
	if is_ready(id):
		return true
	var pack := get_pack(id)
	if pack.is_empty():
		_fail(id, "Unknown runtime pack")
		return false
	if get_state(id) in ["queued", "downloading", "verifying", "mounting"]:
		return true
	var cache_path := _cache_path(id)
	if FileAccess.file_exists(cache_path):
		if _validate_artifact(id, cache_path, false).is_empty() and _mount_cached_pack(id, cache_path):
			return true
		_remove_file(cache_path)
	var url := str(source_overrides.get(id, pack.get("url", ""))).strip_edges()
	if url == "":
		_mark_embedded_ready(id)
		return true
	var request := {
		"state": "queued",
		"progress": 0.0,
		"url": url,
		"attempt": int(requests.get(id, {}).get("attempt", 0)),
		"temp_path": cache_path + ".part",
		"error": "",
	}
	requests[id] = request
	_start_next_download()
	return true

func retry_pack(pack_id: String) -> bool:
	var id := _normalise_id(pack_id)
	var request: Dictionary = requests.get(id, {})
	if request.is_empty() or get_state(id) == "ready":
		return request_pack(id)
	var attempt := int(request.get("attempt", 0))
	if attempt >= MAX_RETRIES:
		_fail(id, "Retry limit reached")
		return false
	request["attempt"] = attempt + 1
	request["state"] = "queued"
	request["progress"] = 0.0
	request["error"] = ""
	requests[id] = request
	_start_next_download()
	return true

func mount_local_pack(pack_id: String, absolute_path: String) -> bool:
	var id := _normalise_id(pack_id)
	if not FileAccess.file_exists(absolute_path):
		_fail(id, "Missing local pack: %s" % absolute_path)
		return false
	var validation := _validate_artifact(id, absolute_path, true)
	if not validation.is_empty():
		_fail(id, validation)
		return false
	if not ProjectSettings.load_resource_pack(absolute_path, false):
		_fail(id, "Godot rejected resource pack: %s" % absolute_path)
		return false
	_mark_mounted(id, absolute_path)
	return true

func cancel_request(pack_id: String) -> void:
	var id := _normalise_id(pack_id)
	var request: Dictionary = requests.get(id, {})
	if request.is_empty() or get_state(id) == "ready":
		return
	if active_download_id == id and http_request != null:
		http_request.cancel_request()
		active_download_id = ""
	_remove_file(str(request.get("temp_path", "")))
	request["state"] = "cancelled"
	request["error"] = ""
	requests[id] = request
	pack_cancelled.emit(id)
	_start_next_download()

func clear_requests() -> void:
	if active_download_id != "":
		cancel_request(active_download_id)
	requests.clear()

func retire_unneeded_packs(keep_ids: Array[String]) -> void:
	var keep: Dictionary = {}
	for value in keep_ids:
		keep[_normalise_id(str(value))] = true
	for value in requests.keys():
		var id := str(value)
		if keep.has(id) or mounted.get(id, false):
			continue
		cancel_request(id)
		requests.erase(id)

func deployment_budget_ok(total_bytes: int) -> bool:
	return total_bytes <= int(manifest.get("max_deployment_bytes", MAX_DEPLOYMENT_BYTES))

func _start_next_download() -> void:
	if active_download_id != "" or http_request == null:
		return
	for value in requests.keys():
		var id := str(value)
		if get_state(id) == "queued":
			_start_download(id)
			return

func _start_download(id: String) -> void:
	var request: Dictionary = requests.get(id, {})
	var url := str(request.get("url", ""))
	if url == "":
		_mark_embedded_ready(id)
		return
	var temp_path := str(request.get("temp_path", _cache_path(id) + ".part"))
	_remove_file(temp_path)
	request["state"] = "downloading"
	request["progress"] = 0.0
	request["temp_path"] = temp_path
	requests[id] = request
	http_request.download_file = temp_path
	active_download_id = id
	var error := http_request.request(url)
	if error != OK:
		active_download_id = ""
		_fail(id, "HTTP request failed: %s" % error_string(error))
		_start_next_download()
		return
	pack_progress.emit(id, 0.0)

func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var id := active_download_id
	active_download_id = ""
	if id == "":
		return
	var request: Dictionary = requests.get(id, {})
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_fail(id, "Pack download failed (%d, result %d)" % [response_code, result])
		_start_next_download()
		return
	request["state"] = "verifying"
	request["progress"] = 0.92
	requests[id] = request
	pack_progress.emit(id, 0.92)
	var temp_path := str(request.get("temp_path", ""))
	var validation := _validate_artifact(id, temp_path, true)
	if not validation.is_empty():
		_remove_file(temp_path)
		_fail(id, validation)
		_start_next_download()
		return
	var cache_path := _cache_path(id)
	_remove_file(cache_path)
	var rename_error := DirAccess.rename_absolute(temp_path, cache_path)
	if rename_error != OK:
		_fail(id, "Unable to commit cached pack: %s" % error_string(rename_error))
		_start_next_download()
		return
	cache_index[id] = {
		"version": str(get_pack(id).get("version", "dev")),
		"path": cache_path,
		"bytes": int(FileAccess.get_file_as_bytes(cache_path).size()),
		"sha256": _sha256(cache_path),
	}
	_save_cache_index()
	pack_cached.emit(id, cache_path)
	if not _mount_cached_pack(id, cache_path):
		_start_next_download()
		return
	_start_next_download()

func _mount_cached_pack(id: String, path: String) -> bool:
	var request: Dictionary = requests.get(id, {})
	request["state"] = "mounting"
	request["progress"] = 0.97
	request["path"] = path
	requests[id] = request
	if not ProjectSettings.load_resource_pack(path, false):
		_fail(id, "Godot rejected cached resource pack: %s" % path)
		return false
	_mark_mounted(id, path)
	return true

func _mark_embedded_ready(id: String) -> void:
	requests[id] = {"state": "ready", "progress": 1.0, "path": "embedded", "error": ""}
	pack_progress.emit(id, 1.0)
	pack_ready.emit(id)

func _mark_mounted(id: String, path: String) -> void:
	mounted[id] = true
	requests[id] = {"state": "ready", "progress": 1.0, "path": path, "error": ""}
	pack_progress.emit(id, 1.0)
	pack_mounted.emit(id, path)
	pack_ready.emit(id)

func _fail(id: String, reason: String) -> void:
	requests[id] = {"state": "failed", "progress": 0.0, "error": reason}
	pack_failed.emit(id, reason)

func _cache_path(id: String) -> String:
	var version := str(get_pack(id).get("version", "dev")).replace("/", "_").replace("\\", "_")
	return "%s/%s_%s.pck" % [CACHE_ROOT, id, version]

func _expected_bytes(id: String) -> int:
	var pack := get_pack(id)
	var declared := int(pack.get("bytes", 0))
	if declared > 0:
		return declared
	return int(pack.get("candidate_bytes", 0))

func _expected_hash(id: String) -> String:
	var pack := get_pack(id)
	var declared := str(pack.get("sha256", "")).strip_edges().to_lower()
	if declared.length() == 64:
		return declared
	return str(pack.get("candidate_sha256", "")).strip_edges().to_lower()

func _validate_artifact(id: String, path: String, check_magic: bool) -> String:
	if not FileAccess.file_exists(path):
		return "Missing pack artifact: %s" % path
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "Unable to read pack artifact: %s" % path
	var magic := file.get_buffer(4)
	file.close()
	if check_magic and magic != PackedByteArray([71, 68, 80, 67]):
		return "Invalid Godot PCK header for %s" % id
	var expected_size := _expected_bytes(id)
	var actual_size := int(FileAccess.get_file_as_bytes(path).size())
	if expected_size > 0 and actual_size != expected_size:
		return "Pack size mismatch for %s: %d != %d" % [id, actual_size, expected_size]
	var expected_hash := _expected_hash(id)
	if expected_hash != "" and _sha256(path) != expected_hash:
		return "Pack SHA-256 mismatch for %s" % id
	return ""

func _sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	while not file.eof_reached():
		var chunk: PackedByteArray = file.get_buffer(CHUNK_SIZE)
		if chunk.is_empty():
			break
		context.update(chunk)
	file.close()
	return context.finish().hex_encode()

func _remove_file(path: String) -> void:
	if path == "" or not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(path)

func _process(_delta: float) -> void:
	if active_download_id == "" or http_request == null:
		return
	var request: Dictionary = requests.get(active_download_id, {})
	if request.is_empty() or get_state(active_download_id) != "downloading":
		return
	var total := http_request.get_body_size()
	var downloaded := http_request.get_downloaded_bytes()
	var progress := 0.0
	if total > 0:
		progress = clampf(float(downloaded) / float(total), 0.0, 0.9)
	request["progress"] = progress
	requests[active_download_id] = request
	pack_progress.emit(active_download_id, progress)
