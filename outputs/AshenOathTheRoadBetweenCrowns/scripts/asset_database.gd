extends Node

const MANIFEST_PATH = "res://asset_manifest.json"
const ROLE_MAPPING_PATH = "res://asset_role_mapping_suggested.json"
const VISUAL_UPGRADE_PATH = "res://visual_upgrade_manifest.json"

var manifest = {}
var role_mapping = {}
var visual_upgrade = {}

func _ready() -> void:
	reload()

func reload() -> void:
	manifest = _read_json(MANIFEST_PATH)
	role_mapping = _read_json(ROLE_MAPPING_PATH)
	visual_upgrade = _read_json(VISUAL_UPGRADE_PATH)

func get_asset_for_role(role_name: String) -> Dictionary:
	var roles = role_mapping.get("roles", {})
	for group in roles.keys():
		var entry = roles[group].get(role_name)
		if typeof(entry) == TYPE_DICTIONARY:
			var path = str(entry.get("path", ""))
			if path != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
				return entry
			return _placeholder_entry(role_name, group, entry)
	return _placeholder_entry(role_name, "", {})

func has_asset_for_role(role_name: String) -> bool:
	var entry = get_asset_for_role(role_name)
	var path = str(entry.get("path", ""))
	return path != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path))

func get_visual_asset_for_role(role_name: String) -> Dictionary:
	var found = _find_visual_entry(role_name)
	if typeof(found) == TYPE_DICTIONARY:
		var path = str(found.get("path", ""))
		if path != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
			return found
		return _placeholder_entry(role_name, str(found.get("group", "")), found)
	return _placeholder_entry(role_name, "", {})

func has_visual_asset_for_role(role_name: String) -> bool:
	var entry = get_visual_asset_for_role(role_name)
	var path = str(entry.get("path", ""))
	return path != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path))

func get_visual_upgrade_roles() -> Dictionary:
	return visual_upgrade.get("roles", {})

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
