extends Node

const CURATED_RUNTIME_PATH = "res://curated_runtime_assets.json"
const VISUAL_UPGRADE_PATH = "res://visual_upgrade_manifest.json"
const RUNTIME_ACCEPTANCE_PATH = "res://runtime_asset_manifest.json"

var manifest = {}
var role_mapping = {}
var visual_upgrade = {}
var runtime_acceptance = {}

func _ready() -> void:
	reload()

func reload() -> void:
	manifest = _read_json(CURATED_RUNTIME_PATH)
	role_mapping = manifest
	visual_upgrade = _read_json(VISUAL_UPGRADE_PATH)
	runtime_acceptance = _read_json(RUNTIME_ACCEPTANCE_PATH)

func get_asset_for_role(role_name: String) -> Dictionary:
	var roles = role_mapping.get("roles", {})
	for group in roles.keys():
		var entry = roles[group].get(role_name)
		if typeof(entry) == TYPE_DICTIONARY:
			var path = str(entry.get("path", ""))
			if path != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
				return _with_runtime_acceptance(role_name, entry)
			return _with_runtime_acceptance(role_name, _placeholder_entry(role_name, group, entry))
	return _with_runtime_acceptance(role_name, _placeholder_entry(role_name, "", {}))

func has_asset_for_role(role_name: String) -> bool:
	var entry = get_asset_for_role(role_name)
	var path = str(entry.get("path", ""))
	return path != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path))

func get_visual_asset_for_role(role_name: String) -> Dictionary:
	var found = _find_visual_entry(role_name)
	if typeof(found) == TYPE_DICTIONARY:
		var path = str(found.get("path", ""))
		if path != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
			return _with_runtime_acceptance(role_name, found)
		return _with_runtime_acceptance(role_name, _placeholder_entry(role_name, str(found.get("group", "")), found))
	return _with_runtime_acceptance(role_name, _placeholder_entry(role_name, "", {}))

func has_visual_asset_for_role(role_name: String) -> bool:
	var entry = get_visual_asset_for_role(role_name)
	var path = str(entry.get("path", ""))
	return path != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path))

func get_visual_upgrade_roles() -> Dictionary:
	return visual_upgrade.get("roles", {})

func get_runtime_acceptance(role_name: String) -> Dictionary:
	var roles: Dictionary = runtime_acceptance.get("roles", {})
	var entry = roles.get(role_name, {})
	return entry.duplicate(true) if typeof(entry) == TYPE_DICTIONARY else {}

func is_release_eligible(role_name: String) -> bool:
	return bool(get_runtime_acceptance(role_name).get("export_eligible", false))

func get_assets_by_category(category: String) -> Array:
	var results = []
	for bucket_name in ["models", "characters", "enemies", "environment", "animations", "textures", "audio", "ui"]:
		for asset in manifest.get(bucket_name, []):
			if str(asset.get("category", "")) == category:
				results.append(asset)
	return results

func get_model_path(role_name: String) -> String:
	return _path_for_role(role_name, [".glb", ".gltf", ".fbx", ".obj", ".dae"])

func get_audio_path(role_name: String) -> String:
	return _path_for_role(role_name, [".wav", ".ogg", ".mp3"])

func get_texture_path(role_name: String) -> String:
	return _path_for_role(role_name, [".png", ".jpg", ".jpeg", ".webp", ".tga"])

func _path_for_role(role_name: String, allowed_exts: Array) -> String:
	var entry = get_asset_for_role(role_name)
	var path = str(entry.get("path", ""))
	if path == "":
		return ""
	var ext = path.get_extension().to_lower()
	if allowed_exts.has("." + ext) and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		return path
	return ""

func _placeholder_entry(role_name: String, group: String, existing: Dictionary) -> Dictionary:
	var result = existing.duplicate(true)
	result["status"] = "placeholder"
	result["role"] = role_name
	result["group"] = group
	if not result.has("placeholder_type"):
		result["placeholder_type"] = "primitive_scene_required"
	return result

func _with_runtime_acceptance(role_name: String, entry: Dictionary) -> Dictionary:
	var result = entry.duplicate(true)
	var acceptance = get_runtime_acceptance(role_name)
	if not acceptance.is_empty():
		result["runtime_acceptance_status"] = str(acceptance.get("status", "unknown"))
		result["runtime_approved"] = bool(acceptance.get("approved", false))
		result["runtime_export_eligible"] = bool(acceptance.get("export_eligible", false))
		result["runtime_blocked_reason"] = str(acceptance.get("blocked_reason", ""))
	return result

func _find_visual_entry(role_name: String):
	var roles = visual_upgrade.get("roles", {})
	for group in roles.keys():
		var entry = roles[group].get(role_name)
		if typeof(entry) == TYPE_DICTIONARY:
			var result = entry.duplicate(true)
			result["role"] = role_name
			result["group"] = group
			return result
	return null

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}
