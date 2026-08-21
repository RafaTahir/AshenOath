extends Node
class_name RuntimePackManager

## Optional pack lifecycle for the Web candidate. The embedded PCK remains the
## playable fallback until a pack has a verified local or same-origin artifact.
signal pack_progress(pack_id: String, progress: float)
signal pack_ready(pack_id: String)
signal pack_failed(pack_id: String, reason: String)

const MANIFEST_PATH := "res://runtime_pack_manifest.json"
const MAX_DEPLOYMENT_BYTES := 104857600

var manifest: Dictionary = {}
var requests: Dictionary = {}
var mounted: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_manifest()

func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		manifest = {}
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	manifest = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func get_pack(pack_id: String) -> Dictionary:
	return manifest.get("packs", {}).get(pack_id.strip_edges().to_lower(), {})

func get_progress(pack_id: String) -> float:
	return clampf(float(requests.get(pack_id.strip_edges().to_lower(), {}).get("progress", 0.0)), 0.0, 1.0)

func is_ready(pack_id: String) -> bool:
	var id := pack_id.strip_edges().to_lower()
	return bool(mounted.get(id, false)) or str(requests.get(id, {}).get("state", "")) == "ready"

func request_pack(pack_id: String) -> bool:
	var id := pack_id.strip_edges().to_lower()
	if is_ready(id):
		return true
	var pack := get_pack(id)
	if pack.is_empty():
		pack_failed.emit(id, "Unknown runtime pack")
		return false
	var url := str(pack.get("url", ""))
	# Empty URLs intentionally mean the content is still embedded in the current
	# PCK. This makes the service safe before split artifacts exist.
	if url == "":
		requests[id] = {"state": "ready", "progress": 1.0}
		pack_progress.emit(id, 1.0)
		pack_ready.emit(id)
		return true
	requests[id] = {"state": "waiting_for_downloader", "progress": 0.0, "url": url}
	pack_failed.emit(id, "External pack download is not configured for this build")
	return false

func mount_local_pack(pack_id: String, absolute_path: String) -> bool:
	var id := pack_id.strip_edges().to_lower()
	if not FileAccess.file_exists(absolute_path):
		pack_failed.emit(id, "Missing local pack: %s" % absolute_path)
		return false
	if not ProjectSettings.load_resource_pack(absolute_path, false):
		pack_failed.emit(id, "Godot rejected resource pack: %s" % absolute_path)
		return false
	mounted[id] = true
	requests[id] = {"state": "ready", "progress": 1.0, "path": absolute_path}
	pack_progress.emit(id, 1.0)
	pack_ready.emit(id)
	return true

func cancel_request(pack_id: String) -> void:
	var id := pack_id.strip_edges().to_lower()
	if requests.has(id) and str(requests[id].get("state", "")) != "ready":
		requests.erase(id)

func clear_requests() -> void:
	requests.clear()

func retire_unneeded_packs(keep_ids: Array[String]) -> void:
	var keep := {}
	for id in keep_ids:
		keep[str(id).to_lower()] = true
	for id in requests.keys():
		if not keep.has(str(id).to_lower()) and not mounted.get(id, false):
			requests.erase(id)

func deployment_budget_ok(total_bytes: int) -> bool:
	return total_bytes <= int(manifest.get("max_deployment_bytes", MAX_DEPLOYMENT_BYTES))
