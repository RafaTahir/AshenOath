extends SceneTree

const TOPOLOGY_PATH := "res://zone_streaming_topology.json"
const ZoneStreamingService = preload("res://scripts/zone_streaming_service.gd")

func _init() -> void:
	var errors: Array[String] = []
	if not FileAccess.file_exists(TOPOLOGY_PATH):
		errors.append("streaming topology missing")
	else:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(TOPOLOGY_PATH))
		var topology: Dictionary = parsed.get("topology", {}) if typeof(parsed) == TYPE_DICTIONARY else {}
		for zone_id in ["greyfen", "wychwood", "cemetery", "deep_wood", "vargan_approach", "hart_glade"]:
			if not topology.has(zone_id) or topology[zone_id].is_empty():
				errors.append("missing neighbors for %s" % zone_id)
	var service := ZoneStreamingService.new()
	service.name = "StreamingVerifier"
	get_root().add_child(service)
	service.request_zone("greyfen", "")
	if not service.is_ready("greyfen") or service.get_progress("greyfen") < 1.0:
		errors.append("embedded zone request did not become ready")
	service.request_zone("unknown_zone", "")
	if service.is_ready("unknown_zone"):
		errors.append("unknown zone became ready")
	service.retire_unneeded_zones(["greyfen"])
	if errors.is_empty():
		print("STREAM-001 VERIFIER: PASS (topology, embedded request, retirement)")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		print("STREAM-001 VERIFIER: FAIL")
		quit(1)
