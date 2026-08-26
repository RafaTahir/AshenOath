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
const MAX_CONCURRENT_DOWNLOADS := 3
const STARTUP_PACK_IDS: Array[String] = ["opening", "characters", "monsters", "audio"]

var manifest: Dictionary = {}
var requests: Dictionary = {}
var mounted: Dictionary = {}
var cache_index: Dictionary = {}
var source_overrides: Dictionary = {}
var http_request: HTTPRequest
var active_download_id := ""
var downloaders: Dictionary = {}
var active_downloads: Dictionary = {}
var startup_requested := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_manifest()
	_load_cache_index()

func _downloader_for(id: String) -> HTTPRequest:
	var downloader := downloaders.get(id) as HTTPRequest
	if downloader != null and is_instance_valid(downloader):
		return downloader
	downloader = HTTPRequest.new()
	downloader.name = "RuntimePackHTTPRequest_%s" % id
	downloader.download_chunk_size = CHUNK_SIZE
	add_child(downloader)
	downloader.request_completed.connect(_on_download_completed.bind(id))
	downloaders[id] = downloader
	# Keep the historical field available for local diagnostics and older
	# tooling, while each pack gets its own request node.
	if http_request == null:
		http_request = downloader
	return downloader

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
	_ensure_cache_directory()
	var file := FileAccess.open(CACHE_INDEX_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(cache_index, "  "))
		file.close()

func _ensure_cache_directory() -> void:
	var absolute_root := ProjectSettings.globalize_path(CACHE_ROOT)
	if absolute_root != "":
		DirAccess.make_dir_recursive_absolute(absolute_root)
	# Some browser filesystem backends require the relative user:// mount to be
	# materialized before FileAccess can create its first downloaded artifact.
	var user_directory := DirAccess.open("user://")
	if user_directory != null:
		user_directory.make_dir_recursive("ashenoath_packs")

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

func request_startup_packs() -> bool:
	startup_requested = true
	var accepted := true
	for id in STARTUP_PACK_IDS:
		if not request_pack(id):
			accepted = false
	_emit_startup_progress()
	return accepted

func startup_packs_ready() -> bool:
	for id in STARTUP_PACK_IDS:
		if not is_ready(id):
			return false
	return true

func startup_pack_failures() -> Array[String]:
	var failures: Array[String] = []
	for id in STARTUP_PACK_IDS:
		if get_state(id) == "failed":
			failures.append("%s: %s" % [id, get_last_error(id)])
	return failures

func startup_pack_progress() -> float:
	var total := 0.0
	for id in STARTUP_PACK_IDS:
		total += get_progress(id)
	return total / float(STARTUP_PACK_IDS.size())

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
	# Desktop runs with every project resource available locally. Relative pack
	# URLs are only meaningful beside a Web export; treating them as embedded
	# keeps editor/headless tests deterministic while explicit HTTP overrides
	# still exercise the download path.
	if not OS.has_feature("web") and not url.begins_with("http://") and not url.begins_with("https://"):
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
	_start_pending_downloads()
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
	_start_pending_downloads()
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
	var downloader := downloaders.get(id) as HTTPRequest
	if active_downloads.has(id) and downloader != null:
		downloader.cancel_request()
		active_downloads.erase(id)
		if active_download_id == id:
			active_download_id = _first_active_download_id()
	_remove_file(str(request.get("temp_path", "")))
	request["state"] = "cancelled"
	request["error"] = ""
	requests[id] = request
	pack_cancelled.emit(id)
	_emit_startup_progress()
	_start_pending_downloads()

func clear_requests() -> void:
	for id in active_downloads.keys().duplicate():
		cancel_request(str(id))
	requests.clear()
	startup_requested = false

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

func _start_pending_downloads() -> void:
	while active_downloads.size() < MAX_CONCURRENT_DOWNLOADS:
		var started := false
		for value in requests.keys():
			var id := str(value)
			if get_state(id) == "queued":
				_start_download(id)
				started = true
				break
		if not started:
			break

func _first_active_download_id() -> String:
	for value in requests.keys():
		var id := str(value)
		if active_downloads.has(id):
			return id
	return ""

func _start_download(id: String) -> void:
	var request: Dictionary = requests.get(id, {})
	var url := _resolve_url(str(request.get("url", "")))
	if url == "":
		_mark_embedded_ready(id)
		return
	var temp_path := str(request.get("temp_path", _cache_path(id) + ".part"))
	_remove_file(temp_path)
	request["state"] = "downloading"
	request["progress"] = 0.0
	request["temp_path"] = temp_path
	requests[id] = request
	var downloader := _downloader_for(id)
	# Web exports cannot hand an HTTPRequest a user:// download_file sink. Keep
	# the response in memory and write it through FileAccess in the completion
	# callback, where Godot's browser filesystem abstraction is available.
	downloader.download_file = ""
	active_downloads[id] = true
	if active_download_id == "":
		active_download_id = id
	var error := downloader.request(url)
	if error != OK:
		active_downloads.erase(id)
		if active_download_id == id:
			active_download_id = _first_active_download_id()
		_fail(id, "HTTP request failed: %s" % error_string(error))
		_start_pending_downloads()
		return
	if startup_requested:
		print("LOADING: startup_pack downloading id=%s url=%s" % [id, url])
	pack_progress.emit(id, 0.0)
	_emit_startup_progress()

func _resolve_url(raw_url: String) -> String:
	var url := raw_url.strip_edges()
	if url == "" or url.begins_with("http://") or url.begins_with("https://"):
		return url
	if not OS.has_feature("web"):
		return url
	# Runtime packs are deployed beside the Web candidate. HTTPRequest needs an
	# absolute URL on Web, while keeping the manifest portable for local hosts.
	var origin := ""
	# This branch is reached only by Web exports. The class is still parsed by
	# desktop Godot, so keep the platform check outside the JavaScript call.
	origin = str(JavaScriptBridge.eval("window.location.origin"))
	if origin == "" or origin == "null":
		return url
	return origin.rstrip("/") + "/" + url.trim_prefix("/")

func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, id: String) -> void:
	active_downloads.erase(id)
	if active_download_id == id:
		active_download_id = _first_active_download_id()
	var request: Dictionary = requests.get(id, {})
	if request.is_empty() or get_state(id) == "cancelled":
		_start_pending_downloads()
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		if startup_requested:
			print("LOADING: startup_pack failed id=%s response=%d result=%d" % [id, response_code, result])
		_fail(id, "Pack download failed (%d, result %d)" % [response_code, result])
		_start_pending_downloads()
		return
	request["state"] = "verifying"
	request["progress"] = 0.92
	requests[id] = request
	pack_progress.emit(id, 0.92)
	var temp_path := str(request.get("temp_path", ""))
	if body.is_empty():
		_fail(id, "Pack download returned an empty body")
		_start_pending_downloads()
		return
	_ensure_cache_directory()
	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		_fail(id, "Unable to open temporary pack cache file")
		_start_pending_downloads()
		return
	temp_file.store_buffer(body)
	temp_file.close()
	var validation := _validate_artifact(id, temp_path, true)
	if not validation.is_empty():
		_remove_file(temp_path)
		_fail(id, validation)
		_start_pending_downloads()
		return
	var cache_path := _cache_path(id)
	_remove_file(cache_path)
	var rename_error := DirAccess.rename_absolute(temp_path, cache_path)
	if rename_error != OK:
		_fail(id, "Unable to commit cached pack: %s" % error_string(rename_error))
		_start_pending_downloads()
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
		_start_pending_downloads()
		return
	_start_pending_downloads()

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
	_emit_startup_progress()

func _mark_mounted(id: String, path: String) -> void:
	mounted[id] = true
	requests[id] = {"state": "ready", "progress": 1.0, "path": path, "error": ""}
	pack_progress.emit(id, 1.0)
	pack_mounted.emit(id, path)
	pack_ready.emit(id)
	if startup_requested:
		print("LOADING: startup_pack mounted id=%s" % id)
	_emit_startup_progress()

func _fail(id: String, reason: String) -> void:
	requests[id] = {"state": "failed", "progress": 0.0, "error": reason}
	pack_failed.emit(id, reason)
	if startup_requested:
		print("LOADING: startup_pack error id=%s reason=%s" % [id, reason])
	_emit_startup_progress()

func _emit_startup_progress() -> void:
	if not startup_requested:
		return
	pack_progress.emit("__startup__", startup_pack_progress())

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
	if active_downloads.is_empty():
		return
	for value in active_downloads.keys():
		var id := str(value)
		var request: Dictionary = requests.get(id, {})
		var downloader := downloaders.get(id) as HTTPRequest
		if request.is_empty() or get_state(id) != "downloading" or downloader == null:
			continue
		var total := downloader.get_body_size()
		var downloaded := downloader.get_downloaded_bytes()
		var progress := 0.0
		if total > 0:
			progress = clampf(float(downloaded) / float(total), 0.0, 0.9)
		request["progress"] = progress
		requests[id] = request
		pack_progress.emit(id, progress)
	_emit_startup_progress()
