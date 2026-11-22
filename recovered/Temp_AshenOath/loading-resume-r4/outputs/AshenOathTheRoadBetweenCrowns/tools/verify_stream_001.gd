extends SceneTree

const TOPOLOGY_PATH := "res://zone_streaming_topology.json"
const ZoneStreamingService = preload("res://scripts/zone_streaming_service.gd")

class PackProbe extends Node:
	var ready_zones: Array[String] = []
	var requested: Array[String] = []
	func zone_packs_ready(zone_id: String) -> bool:
		return ready_zones.has(zone_id)
	func required_zone_packs(zone_id: String) -> Array[String]:
		return ["pack:" + zone_id]
	func request_pack(pack_id: String, _priority: int) -> bool:
		requested.append(pack_id)
		return true
	func zone_pack_failures(_zone_id: String) -> Array[String]:
		return []

class StreamingOwner extends Node:
	var runtime_packs: Node

class PrefetchProbe extends "res://scripts/zone_streaming_service.gd":
	var selected: Array[String] = []
	func request_zone(zone_id: String, _resource_path: String = "") -> void:
		selected.append(zone_id)

func _init() -> void:
	if "--prefetch-contract-only" in OS.get_cmdline_user_args():
		call_deferred("_prefetch_contract")
		return
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

func _prefetch_contract() -> void:
	var errors: Array[String] = []
	var owner := StreamingOwner.new()
	root.add_child(owner)
	var packs := PackProbe.new()
	owner.add_child(packs)
	owner.runtime_packs = packs
	var probe := PrefetchProbe.new()
	owner.add_child(probe)
	probe.setup(owner)
	probe.prewarm_neighbors("greyfen")
	if not probe.selected.is_empty() or not packs.requested.is_empty():
		errors.append("opportunistic Greyfen prefetch requested unmounted neighbor content")
	packs.ready_zones.append("wychwood")
	probe.prewarm_neighbors("greyfen")
	if probe.selected != ["wychwood"]:
		errors.append("already-mounted Wychwood neighbor was not retained for prefetch")
	var destination := ZoneStreamingService.new()
	owner.add_child(destination)
	destination.setup(owner)
	destination.request_zone("vargan_approach")
	if not packs.requested.has("pack:vargan_approach") or destination.get_state("vargan_approach") != "waiting_pack":
		errors.append("explicit destination no longer requests its complete missing content")
	var game = load("res://scripts/game.gd").new()
	var recorded := {"quests": {"active": {"main_bell_beneath_greyfen": {}}},
		"story_state": {"flags": {}}, "world_state": {"boss_states": {}}}
	if game._zone_encounter_packs("greyfen", recorded) != ["monsters"]:
		errors.append("selected Bell-Eater save does not require its monster content")
	for flag: String in ["bell_eater_defeated", "bell_eater_legacy_retired"]:
		recorded.story_state.flags = {}
		recorded.story_state.flags[flag] = true
		if not game._zone_encounter_packs("greyfen", recorded).is_empty():
			errors.append("completed/legacy Bell-Eater unnecessarily reactivates content: " + flag)
	recorded.story_state.flags = {}
	recorded.world_state.boss_states = {"bell_eater": {"outcome": "defeated"}}
	if not game._zone_encounter_packs("greyfen", recorded).is_empty():
		errors.append("recorded Bell-Eater defeat was ignored")
	recorded.world_state.boss_states = {"bell_eater": "invalid legacy value"}
	if game._zone_encounter_packs("greyfen", recorded) != ["monsters"]:
		errors.append("malformed optional boss record bypassed required content")
	# This detached coordinator never runs _ready(), which normally owns this node.
	game.zone_residency.free()
	game.free()
	owner.free()
	await process_frame
	for error in errors:
		push_error(error)
	print("STREAM PREFETCH CONTRACT: %s (mounted-only opportunism, explicit destination and saved encounter demand)" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
