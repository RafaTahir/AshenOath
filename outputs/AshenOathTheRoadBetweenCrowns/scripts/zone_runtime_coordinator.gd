class_name ZoneRuntimeCoordinator
extends RefCounted

const ZoneCompositionRouter = preload("res://scripts/zone_composition_router.gd")

## Small lifecycle contract shared by the host and release verifiers.
## Builders remain owned by ZoneCompositionRouter; this object owns the
## transition state and records failed/activated zone builds without hiding
## errors or changing manager ownership.

var host: Node
var quest_manager: Node
var quest_presentation: Node
var quest_beats: Node
var interaction_focus: Node
var pending_zone := ""
var active_zone := ""
var transition_count := 0
var failure_count := 0
var last_failure: Dictionary = {}
var last_activation: Dictionary = {}
var build_count := 0
var last_build: Dictionary = {}
var build_started_usec := 0

func _init(runtime_host: Node) -> void:
	host = runtime_host

func configure(presentation: Node, beats: Node, focus: Node, quests: Node) -> void:
	quest_presentation = presentation
	quest_beats = beats
	interaction_focus = focus
	quest_manager = quests

func normalize_zone_request(zone_id: String, spawn_position: Vector3) -> Dictionary:
	var normalized := zone_id.strip_edges().to_lower()
	var registered: Array[String] = ZoneCompositionRouter.registered_zones()
	# The router is preloaded by the host, so this fallback keeps the contract
	# usable in isolated unit tests without inventing an alternate zone list.
	if registered.is_empty() and host != null and host.has_method("_zone_display_name"):
		registered = [normalized]
	if normalized == "" or (not registered.is_empty() and normalized not in registered):
		return {"ok": false, "zone_id": normalized, "spawn_position": spawn_position, "error": "unknown_zone"}
	return {"ok": true, "zone_id": normalized, "spawn_position": spawn_position}

func sync_zone(zone_id: String) -> Dictionary:
	var normalized := zone_id.strip_edges().to_lower()
	if quest_presentation != null and quest_presentation.has_method("set_zone"):
		quest_presentation.set_zone(normalized)
	if quest_beats != null and quest_beats.has_method("set_zone"):
		quest_beats.set_zone(normalized)
	elif quest_manager != null and quest_manager.has_method("set_tracked_quest_for_zone"):
		quest_manager.set_tracked_quest_for_zone(normalized)
	return {
		"zone_id": normalized,
		"tracked_quest": str(quest_presentation.get_tracked_quest()) if quest_presentation != null and quest_presentation.has_method("get_tracked_quest") else str(quest_manager.get_tracked_quest()) if quest_manager != null else "",
		"display_name": str(quest_presentation.get_zone_display_name(normalized)) if quest_presentation != null and quest_presentation.has_method("get_zone_display_name") else normalized,
	}

func refresh_presentation() -> String:
	if quest_beats != null and quest_beats.has_method("refresh"):
		quest_beats.refresh()
	var tracker := str(quest_presentation.get_tracker_text()) if quest_presentation != null and quest_presentation.has_method("get_tracker_text") else str(quest_manager.get_tracker_text()) if quest_manager != null else "No objective in this area."
	if quest_beats != null and quest_beats.has_method("decorate_tracker"):
		tracker = quest_beats.decorate_tracker(tracker)
	return tracker

func choose_interaction(candidates: Array, player: Node3D, camera: Camera3D, validator: Callable) -> Node:
	if interaction_focus != null and interaction_focus.has_method("choose"):
		return interaction_focus.choose(candidates, player, camera, validator)
	return null

func record_playable_transition(zone_id: String, elapsed_ms: float, support_ready: bool) -> void:
	last_activation["zone"] = zone_id
	last_activation["state"] = "playable"
	last_activation["playable_ms"] = elapsed_ms
	last_activation["support_ready"] = support_ready

func begin_transition(zone_id: String, previous_zone: String, spawn_position: Vector3) -> void:
	pending_zone = zone_id
	transition_count += 1
	last_activation = {
		"zone": zone_id,
		"previous_zone": previous_zone,
		"spawn_position": spawn_position,
		"state": "building",
	}

func begin_build(zone_id: String, composition_kind: String) -> void:
	build_count += 1
	build_started_usec = Time.get_ticks_usec()
	last_build = {
		"zone": zone_id,
		"composition_kind": composition_kind,
		"state": "building",
		"build_index": build_count,
	}

func finish_build(result: Dictionary, root: Node3D) -> Dictionary:
	var elapsed_ms := float(Time.get_ticks_usec() - build_started_usec) / 1000.0 if build_started_usec > 0 else 0.0
	var completed := result.duplicate(true)
	completed["build_ms"] = elapsed_ms
	completed["node_count"] = _node_count(root)
	completed["state"] = "validated" if bool(result.get("ok", false)) else "failed"
	last_build = completed
	build_started_usec = 0
	return completed

func validate_build(zone_id: String, result: Dictionary, root: Node3D) -> Dictionary:
	var errors: Array[String] = []
	if not bool(result.get("ok", false)):
		errors.append_array(result.get("errors", []))
	if root == null or not is_instance_valid(root):
		errors.append("zone root is missing")
	elif root.get_child_count() == 0:
		errors.append("zone root is empty")
	for required_counter in ["ground_count", "bounds_count", "gate_count"]:
		if int(result.get(required_counter, 0)) < 1:
			errors.append("missing build contract: %s" % required_counter)
	var contract: Dictionary = root.get_meta("zone_build_contract", {})
	if not contract.is_empty() and not bool(contract.get("ok", false)):
		errors.append_array(contract.get("errors", []))
	return {"ok": errors.is_empty(), "zone": zone_id, "errors": errors}

func activate(zone_id: String, root: Node3D, reused: bool) -> void:
	active_zone = zone_id
	pending_zone = ""
	last_activation = {
		"zone": zone_id,
		"state": "active",
		"reused": reused,
		"node_count": _node_count(root),
	}

func rollback(zone_id: String, previous_zone: String, errors: Array) -> void:
	failure_count += 1
	pending_zone = ""
	last_failure = {
		"zone": zone_id,
		"previous_zone": previous_zone,
		"errors": errors.duplicate(),
	}

func snapshot() -> Dictionary:
	return {
		"pending_zone": pending_zone,
		"active_zone": active_zone,
		"transition_count": transition_count,
		"failure_count": failure_count,
		"last_failure": last_failure.duplicate(true),
		"last_activation": last_activation.duplicate(true),
		"build_count": build_count,
		"last_build": last_build.duplicate(true),
		"presentation_zone": str(quest_presentation.get_zone_id()) if quest_presentation != null and quest_presentation.has_method("get_zone_id") else "",
		"tracked_quest": str(quest_presentation.get_tracked_quest()) if quest_presentation != null and quest_presentation.has_method("get_tracked_quest") else str(quest_manager.get_tracked_quest()) if quest_manager != null else "",
	}

func _node_count(root: Node) -> int:
	if root == null or not is_instance_valid(root):
		return 0
	var count := 1
	for child in root.get_children():
		count += _node_count(child)
	return count
