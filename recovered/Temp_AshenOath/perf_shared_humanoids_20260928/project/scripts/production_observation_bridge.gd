class_name ProductionObservationBridge
extends Node

## Query-gated, read-only browser observation. It exposes no command channel
## and cannot mutate gameplay, story, saves, actors, or transitions.
const WINDOW_STATE := "window.__ashenOathReadOnlyObservation"
const PUBLISH_INTERVAL := 0.20

var _host: Node
var _enabled := false
var _elapsed := 0.0

func setup(host: Node) -> void:
	_host = host
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		set_process(false)
		return
	_enabled = bool(JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('observe') === '1'", true
	))
	set_process(_enabled)
	if _enabled:
		_publish()

func _process(delta: float) -> void:
	if not _enabled or _host == null or not is_instance_valid(_host):
		return
	_elapsed += delta
	if _elapsed < PUBLISH_INTERVAL:
		return
	_elapsed = 0.0
	_publish()

func _publish() -> void:
	var player := _host.get("player") as CharacterBody3D
	var camera_rig := _host.get("camera_rig") as Node
	var focus := _host.get("active_interactable") as Node3D
	var player_state := {}
	if player != null and is_instance_valid(player):
		player_state = {
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
			"velocity": [player.velocity.x, player.velocity.y, player.velocity.z],
			"can_control": bool(player.get("can_control")),
			"on_floor": player.is_on_floor(),
			"on_wall": player.is_on_wall(),
			"facing_yaw": player.rotation.y,
		}
	var focus_state := {}
	if focus != null and is_instance_valid(focus):
		focus_state = {
			"name": str(focus.name),
			"position": [focus.global_position.x, focus.global_position.y, focus.global_position.z],
			"distance": player.global_position.distance_to(focus.global_position) if player != null else -1.0,
		}
	var camera_state := {}
	if camera_rig != null and is_instance_valid(camera_rig):
		camera_state = {
			"yaw": float(camera_rig.get("yaw")),
			"pitch": float(camera_rig.get("pitch")),
		}
	var state := {
		"schema_version": 1,
		"read_only": true,
		"timestamp_ms": Time.get_ticks_msec(),
		"game_started": bool(_host.get("game_started")),
		"zone": str(_host.get("current_zone_id")),
		"transition_pending": bool(_host.get("zone_transition_pending")),
		"paused": get_tree().paused,
		"player": player_state,
		"camera": camera_state,
		"focus": focus_state,
	}
	JavaScriptBridge.eval("%s = %s;" % [WINDOW_STATE, JSON.stringify(state)], false)
