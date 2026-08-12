extends SceneTree

const MANIFEST_PATH := "res://zone_scene_manifest.json"

func _init() -> void:
	var errors: Array[String] = []
	if not FileAccess.file_exists(MANIFEST_PATH):
		errors.append("zone scene manifest missing")
	else:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if typeof(parsed) != TYPE_DICTIONARY:
			errors.append("zone scene manifest is not an object")
		else:
			for zone_id in ["greyfen", "wychwood", "cemetery"]:
				var record: Dictionary = parsed.get("zones", {}).get(zone_id, {})
				for layer in ["gameplay", "decoration"]:
					var path := str(record.get(layer, ""))
					if path == "" or not ResourceLoader.exists(path):
						errors.append("%s %s layer missing" % [zone_id, layer])
						continue
					var packed := ResourceLoader.load(path) as PackedScene
					if packed == null:
						errors.append("%s %s layer is not PackedScene" % [zone_id, layer])
						continue
					var instance := packed.instantiate()
					if instance.get_child_count() < 1:
						errors.append("%s %s layer has no authored children" % [zone_id, layer])
					instance.free()
	if errors.is_empty():
		print("SCENE-001 VERIFIER: PASS (opening gameplay and decoration layers load)")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		print("SCENE-001 VERIFIER: FAIL")
		quit(1)
