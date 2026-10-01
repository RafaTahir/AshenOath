extends SceneTree

func _initialize() -> void:
	var directory := "D:/Temp/AshenOath/recovery004_aligned_packs/"
	var candidates = JSON.parse_string(FileAccess.get_file_as_string(directory + "runtime_pack_candidates.json"))
	var record: Dictionary = {}
	for item in candidates["packs"]:
		if item["id"] == "opening":
			record = item
	var manager = load("res://scripts/runtime_pack_manager.gd").new()
	manager.manifest = {"packs": {"opening": record}}
	var metadata: Dictionary = {}
	var failure: String = manager._validate_artifact("opening", directory + "opening.pck", true, metadata)
	if failure != "" or metadata.get("bytes") != record["bytes"] or metadata.get("sha256") != record["sha256"]:
		_fail(manager, "Valid artifact metadata mismatch: " + failure)
		return
	record["sha256"] = "0".repeat(64)
	metadata.clear()
	if manager._validate_artifact("opening", directory + "opening.pck", true, metadata) == "" or not metadata.is_empty():
		_fail(manager, "Corrupt identity accepted or published")
		return
	for invalid_identity in [{"bytes": 0, "sha256": record["sha256"]}, {"bytes": record["bytes"], "sha256": ""}]:
		manager.manifest = {"packs": {"opening": invalid_identity}}
		if manager._validate_artifact("opening", directory + "opening.pck", true, metadata) == "" or not metadata.is_empty():
			_fail(manager, "Missing external identity accepted")
			return
	manager.free()
	print("PACK VALIDATION METADATA: PASS")
	quit(0)

func _fail(manager: Node, message: String) -> void:
	manager.free()
	printerr(message)
	quit(1)
