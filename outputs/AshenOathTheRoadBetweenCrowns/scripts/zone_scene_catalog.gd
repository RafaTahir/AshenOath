extends RefCounted
class_name ZoneSceneCatalog

## Resolves small authored gameplay/decoration layers without replacing the
## current procedural builder. The layers are deliberately lightweight markers
## until their visual, collision, and save contracts are approved.

const MANIFEST_PATH := "res://zone_scene_manifest.json"
const FALLBACK_PATHS := {
	"greyfen": {
		"gameplay": "res://scenes/zones/greyfen_gameplay.tscn",
		"decoration": "res://scenes/zones/greyfen_decoration.tscn",
	},
	"wychwood": {
		"gameplay": "res://scenes/zones/wychwood_gameplay.tscn",
		"decoration": "res://scenes/zones/wychwood_decoration.tscn",
	},
	"cemetery": {
		"gameplay": "res://scenes/zones/cemetery_gameplay.tscn",
		"decoration": "res://scenes/zones/cemetery_decoration.tscn",
	},
}

static func attach(zone_id: String, parent: Node3D) -> Dictionary:
	var result := {"ok": true, "zone": zone_id, "attached": [], "errors": []}
	if parent == null or not is_instance_valid(parent):
		result.ok = false
		result.errors.append("zone layer parent is invalid")
		return result
	var zone := _zone_record(zone_id)
	if zone.is_empty():
		return result
	for layer in ["gameplay", "decoration"]:
		var path := str(zone.get(layer, ""))
		if path == "":
			continue
		# Scene layers are part of the opening pack. Dynamic loading keeps them
		# out of the initial menu PCK while preserving the authored layer API.
		var packed: PackedScene
		if ResourceLoader.exists(path):
			packed = ResourceLoader.load(path) as PackedScene
		if packed == null:
			result.ok = false
			result.errors.append("missing or invalid %s layer: %s" % [layer, path])
			continue
		var instance := packed.instantiate()
		instance.name = "%s_%s" % [layer.capitalize(), zone_id]
		instance.set_meta("zone_layer_kind", layer)
		instance.set_meta("zone_layer_source", path)
		parent.add_child(instance)
		result.attached.append(layer)
	return result

static func _zone_record(zone_id: String) -> Dictionary:
	var fallback: Dictionary = FALLBACK_PATHS.get(zone_id.strip_edges().to_lower(), {})
	if not FileAccess.file_exists(MANIFEST_PATH):
		return fallback
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return fallback
	var record: Dictionary = parsed.get("zones", {}).get(zone_id.strip_edges().to_lower(), {})
	return record if not record.is_empty() else fallback
