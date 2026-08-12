class_name ZoneRuntimeCoordinator
extends RefCounted

## Small lifecycle contract shared by the host and release verifiers.
## Builders remain owned by ZoneCompositionRouter; this object owns the
## transition state and records failed/activated zone builds without hiding
## errors or changing manager ownership.

var host: Node
var pending_zone := ""
var active_zone := ""
var transition_count := 0
var failure_count := 0
var last_failure: Dictionary = {}
var last_activation: Dictionary = {}

func _init(runtime_host: Node) -> void:
	host = runtime_host

func begin_transition(zone_id: String, previous_zone: String, spawn_position: Vector3) -> void:
	pending_zone = zone_id
	transition_count += 1
	last_activation = {
		"zone": zone_id,
		"previous_zone": previous_zone,
		"spawn_position": spawn_position,
		"state": "building",
	}

func validate_build(zone_id: String, result: Dictionary, root: Node3D) -> Dictionary:
	var errors: Array[String] = []
	if not bool(result.get("ok", false)):
		errors.append_array(result.get("errors", []))
	if root == null or not is_instance_valid(root):
		errors.append("zone root is missing")
	elif root.get_child_count() == 0:
		errors.append("zone root is empty")
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
	}

func _node_count(root: Node) -> int:
	if root == null or not is_instance_valid(root):
		return 0
	var count := 1
	for child in root.get_children():
		count += _node_count(child)
	return count
