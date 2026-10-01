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
# The root Web PCK owns the menu, managers, core builders, and the small A-set
# hero/Anwen runtime layers. The shell verifies and copies the opening PCK into
# Web memory after first control, avoiding download/decompression contention
# with WebAssembly startup. Later campaign content remains independently streamed.
const STARTUP_PACK_IDS: Array[String] = ["base"]
const BACKGROUND_PACK_IDS: Array[String] = ["opening", "quality_materials", "characters", "monsters", "audio", "campaign"]

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
var background_requested := false
var scheduling_downloads := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_manifest()
	_load_cache_index()

func _downloader_for(id: String) -> HTTPRequest:
	var downloader := downloaders.get(id) as HTTPRequest
	if downloader != null and is_instance_valid(downloader):
		return downloader
	downloader = HTTPRequest.new()
	# Web Fetch has already decoded Content-Encoding before Godot receives
	# the bytes. Native HTTPRequest still needs its ordinary gzip handling.
	downloader.accept_gzip = not OS.has_feature("web")
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

func get_web_preloaded_state(pack_id: String) -> String:
	var id := _normalise_id(pack_id)
	if not OS.has_feature("web") or id != "opening":
		return ""
	var raw_metadata := str(JavaScriptBridge.eval(
		"JSON.stringify((window.__ashenOathPreloadedPacks || {}).opening || null)", true
	))
	var parsed: Variant = JSON.parse_string(raw_metadata)
	if not parsed is Dictionary:
		return ""
	return str((parsed as Dictionary).get("state", ""))

func has_embedded_content(pack_id: String) -> bool:
	# Builder scripts can live in the root PCK even when the scene assets belong
	# to an external pack. The generated manifest is the authority for Web
	# ownership; checking ResourceLoader here would incorrectly bypass a needed
	# streamed-pack request.
	var id := _normalise_id(pack_id)
	if id == "":
		return false
	return str(get_pack(id).get("status", "")).begins_with("embedded")

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

func request_background_packs() -> bool:
	# This is deliberately separate from startup readiness. Callers can use it
	# once the opening is playable without turning a later download into an
	# input lock or a false loading state.
	background_requested = true
	var accepted := true
	for id in BACKGROUND_PACK_IDS:
		if not request_pack(id):
			accepted = false
	return accepted

func required_zone_packs(zone_id: String) -> Array[String]:
	var result: Array[String] = ["base", "opening"]
	if zone_id != "greyfen":
		result.append("monsters")
	if zone_id not in ["greyfen", "wychwood", "cemetery", "ruins"]:
		result.append_array(["characters", "campaign"])
	return result

func request_zone_packs(zone_id: String) -> bool:
	var accepted := true
	for id in required_zone_packs(zone_id):
		if not request_pack(id):
			accepted = false
	return accepted

func zone_packs_ready(zone_id: String) -> bool:
	for id in required_zone_packs(zone_id):
		if not is_ready(id):
			return false
	return true

func zone_pack_failures(zone_id: String) -> Array[String]:
	var failures: Array[String] = []
	for id in required_zone_packs(zone_id):
		if get_state(id) == "failed":
			failures.append("%s: %s" % [id, get_last_error(id)])
	return failures

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
	var order: Array[String] = []
	var graph_error := _dependency_order(id, {}, order)
	if graph_error != "":
		_fail(id, graph_error)
		return false
	for required_id in order:
		if not _queue_pack(required_id):
			if required_id != id:
				_fail(id, "Dependency %s failed: %s" % [required_id, get_last_error(required_id)])
			return false
	_start_pending_downloads()
	return get_state(id) != "failed"

func _dependency_order(id: String, marks: Dictionary, order: Array[String]) -> String:
	if int(marks.get(id, 0)) == 1:
		return "Runtime pack dependency cycle at %s" % id
	if int(marks.get(id, 0)) == 2:
		return ""
	var pack := get_pack(id)
	if pack.is_empty():
		return "Unknown runtime pack dependency: %s" % id
	var dependencies: Variant = pack.get("dependencies", [])
	if not dependencies is Array:
		return "Invalid dependencies for %s" % id
	marks[id] = 1
	for dependency in dependencies:
		if not dependency is String or _normalise_id(dependency) == "":
			return "Invalid dependency ID for %s" % id
		var failure := _dependency_order(_normalise_id(dependency), marks, order)
		if failure != "":
			return failure
	marks[id] = 2
	order.append(id)
	return ""

func _dependencies_ready(id: String) -> bool:
	for dependency in get_pack(id).get("dependencies", []):
		if not is_ready(str(dependency)):
			return false
	return true

func _queue_pack(id: String) -> bool:
	if is_ready(id):
		return true
	var pack := get_pack(id)
	if pack.is_empty():
		_fail(id, "Unknown runtime pack")
		return false
	if get_state(id) in ["queued", "downloading", "verifying", "mounting"]:
		return true
	var url := str(source_overrides.get(id, pack.get("url", ""))).strip_edges()
	if url == "" and not has_embedded_content(id):
		_fail(id, "External runtime pack has no download URL")
		return false
	var attempt := int(requests.get(id, {}).get("attempt", 0))
	if get_state(id) == "failed":
		if attempt >= MAX_RETRIES:
			return false
		attempt += 1
	var request := {
		"state": "queued",
		"progress": 0.0,
		"url": url,
		"attempt": attempt,
		"temp_path": _cache_path(id) + ".part",
		"error": "",
	}
	requests[id] = request
	return true

func retry_pack(pack_id: String) -> bool:
	var id := _normalise_id(pack_id)
	var request: Dictionary = requests.get(id, {})
	if request.is_empty() or get_state(id) == "ready":
		return request_pack(id)
	var attempt := int(request.get("attempt", 0))
	if attempt >= MAX_RETRIES:
		return false
	request["attempt"] = attempt + 1
	request["state"] = "retrying"
	request["progress"] = 0.0
	request["error"] = ""
	requests[id] = request
	# Reconstruct the request from the manifest. A failure may have happened
	# before download metadata existed (for example during cache validation).
	return request_pack(id)

func mount_local_pack(pack_id: String, absolute_path: String) -> bool:
	var id := _normalise_id(pack_id)
	var order: Array[String] = []
	var graph_error := _dependency_order(id, {}, order)
	if graph_error != "" or not _dependencies_ready(id):
		_fail(id, graph_error if graph_error != "" else "Runtime pack dependencies are not ready")
		return false
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
	if active_downloads.has(id):
		if downloader != null:
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
	var was_scheduling := scheduling_downloads
	scheduling_downloads = true
	for id in requests.keys():
		cancel_request(str(id))
	requests.clear()
	active_downloads.clear()
	active_download_id = ""
	startup_requested = false
	background_requested = false
	scheduling_downloads = was_scheduling

func retire_unneeded_packs(keep_ids: Array[String]) -> void:
	var keep: Dictionary = {}
	for value in keep_ids:
		keep[_normalise_id(str(value))] = true
		var order: Array[String] = []
		if _dependency_order(_normalise_id(value), {}, order) == "":
			for dependency in order:
				keep[dependency] = true
	var was_scheduling := scheduling_downloads
	scheduling_downloads = true
	for value in requests.keys():
		var id := str(value)
		if keep.has(id) or mounted.get(id, false):
			continue
		cancel_request(id)
		requests.erase(id)
	scheduling_downloads = was_scheduling
	_start_pending_downloads()

func deployment_budget_ok(total_bytes: int) -> bool:
	return total_bytes <= int(manifest.get("max_deployment_bytes", MAX_DEPLOYMENT_BYTES))

func _start_pending_downloads() -> void:
	if scheduling_downloads:
		return
	scheduling_downloads = true
	while active_downloads.size() < MAX_CONCURRENT_DOWNLOADS:
		var started := false
		for value in requests.keys():
			var id := str(value)
			if get_state(id) == "queued":
				var dependency_error := ""
				for dependency in get_pack(id).get("dependencies", []):
					if get_state(str(dependency)) in ["failed", "cancelled"]:
						dependency_error = "Dependency %s is %s: %s" % [dependency, get_state(str(dependency)), get_last_error(str(dependency))]
						break
				if dependency_error != "":
					_fail(id, dependency_error)
					started = true
					break
				if not _dependencies_ready(id):
					continue
				_start_download(id)
				started = true
				break
		if not started:
			break
	scheduling_downloads = false

func _first_active_download_id() -> String:
	for value in requests.keys():
		var id := str(value)
		if active_downloads.has(id):
			return id
	return ""

func _start_download(id: String) -> void:
	if not _dependencies_ready(id):
		_fail(id, "Runtime pack dependencies are not ready")
		return
	var request: Dictionary = requests.get(id, {})
	# Embedded content belongs to the running root, never to an old disk pack.
	# Ignore any stale base cache rather than mounting extra obsolete resources.
	if has_embedded_content(id) and str(request.get("url", "")) == "":
		_mark_embedded_ready(id)
		return
	if OS.has_feature("web") and _try_mount_web_preloaded_pack(id):
		return
	var cache_path := _cache_path(id)
	if FileAccess.file_exists(cache_path):
		if _validate_artifact(id, cache_path, false).is_empty() and _mount_cached_pack(id, cache_path):
			return
		_remove_file(cache_path)
	var url := _resolve_url(str(request.get("url", "")))
	if url == "":
		if has_embedded_content(id):
			_mark_embedded_ready(id)
		else:
			_fail(id, "External runtime pack has no download URL")
		return
	# Native project resources are local; explicit HTTP overrides still exercise
	# downloads. Neither native nor embedded content may bypass its dependencies.
	if not OS.has_feature("web") and not url.begins_with("http://") and not url.begins_with("https://"):
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
	print("LOADING: %s downloading id=%s url=%s" % [_pack_log_label(id), id, url])
	pack_progress.emit(id, 0.0)
	_emit_startup_progress()

func _try_mount_web_preloaded_pack(id: String) -> bool:
	if id != "opening":
		return false
	var raw_metadata := str(JavaScriptBridge.eval(
		"JSON.stringify((window.__ashenOathPreloadedPacks || {}).opening || null)", true
	))
	var parsed: Variant = JSON.parse_string(raw_metadata)
	if not parsed is Dictionary:
		return false
	var metadata := parsed as Dictionary
	if str(metadata.get("state", "")) != "preloaded":
		return false
	var pack := get_pack(id)
	var expected_hash := str(pack.get("sha256", "")).to_lower()
	var expected_bytes := int(pack.get("bytes", 0))
	if str(metadata.get("sha256", "")).to_lower() != expected_hash \
			or int(metadata.get("bytes", 0)) != expected_bytes \
			or str(metadata.get("version", "")) != str(pack.get("version", "")):
		return false
	var path := str(metadata.get("path", ""))
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var magic := file.get_buffer(4)
	var actual_bytes := file.get_length()
	file.close()
	if actual_bytes != expected_bytes or magic != PackedByteArray([71, 68, 80, 67]):
		return false
	var request: Dictionary = requests.get(id, {})
	request["state"] = "mounting"
	request["progress"] = 0.97
	request["path"] = path
	requests[id] = request
	if not ProjectSettings.load_resource_pack(path, false):
		return false
	print("LOADING: startup_pack preloaded id=%s bytes=%d" % [id, actual_bytes])
	_mark_mounted(id, path)
	return true

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
		print("LOADING: %s failed id=%s response=%d result=%d" % [_pack_log_label(id), id, response_code, result])
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
	var verified_metadata: Dictionary = {}
	var validation := _validate_artifact(id, temp_path, true, verified_metadata)
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
		"bytes": verified_metadata["bytes"],
		"sha256": verified_metadata["sha256"],
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
	print("LOADING: %s mounted id=%s" % [_pack_log_label(id), id])
	_emit_startup_progress()

func _fail(id: String, reason: String) -> void:
	var request: Dictionary = requests.get(id, {}).duplicate()
	request["state"] = "failed"
	request["progress"] = 0.0
	request["error"] = reason
	requests[id] = request
	pack_failed.emit(id, reason)
	print("LOADING: %s error id=%s reason=%s" % [_pack_log_label(id), id, reason])
	_emit_startup_progress()

func _emit_startup_progress() -> void:
	if not startup_requested:
		return
	pack_progress.emit("__startup__", startup_pack_progress())

func _pack_log_label(id: String) -> String:
	return "startup_pack" if STARTUP_PACK_IDS.has(id) else "background_pack"

func _cache_path(id: String) -> String:
	var version := str(get_pack(id).get("version", "dev")).replace("/", "_").replace("\\", "_")
	return "%s/%s_%s.pck" % [CACHE_ROOT, id, version]

func _expected_bytes(id: String) -> int:
	var pack := get_pack(id)
	# An embedded pack is supplied by the current root PCK. Candidate metadata
	# belongs to an external build and may legitimately describe a different
	# artifact; using it here can reject a valid cache before the embedded path
	# is selected. Streamed packs retain strict declared/candidate validation.
	if str(pack.get("status", "")).begins_with("embedded"):
		return 0
	var declared := int(pack.get("bytes", 0))
	if declared > 0:
		return declared
	return int(pack.get("candidate_bytes", 0))

func _expected_hash(id: String) -> String:
	var pack := get_pack(id)
	if str(pack.get("status", "")).begins_with("embedded"):
		return ""
	var declared := str(pack.get("sha256", "")).strip_edges().to_lower()
	if declared.length() == 64:
		return declared
	return str(pack.get("candidate_sha256", "")).strip_edges().to_lower()

func _validate_artifact(id: String, path: String, check_magic: bool, verified_metadata: Dictionary = {}) -> String:
	if not FileAccess.file_exists(path):
		return "Missing pack artifact: %s" % path
	var expected_size := _expected_bytes(id)
	var expected_hash := _expected_hash(id)
	if not has_embedded_content(id) and (expected_size <= 0 or expected_hash.length() != 64):
		return "Missing declared identity for external pack: %s" % id
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "Unable to read pack artifact: %s" % path
	var magic := file.get_buffer(4)
	var actual_size := file.get_length()
	file.close()
	if check_magic and magic != PackedByteArray([71, 68, 80, 67]):
		return "Invalid Godot PCK header for %s" % id
	if expected_size > 0 and actual_size != expected_size:
		return "Pack size mismatch for %s: %d != %d" % [id, actual_size, expected_size]
	var actual_hash := _sha256(path)
	if actual_hash == "" or (expected_hash != "" and actual_hash != expected_hash):
		return "Pack SHA-256 mismatch for %s" % id
	verified_metadata["bytes"] = actual_size
	verified_metadata["sha256"] = actual_hash
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
