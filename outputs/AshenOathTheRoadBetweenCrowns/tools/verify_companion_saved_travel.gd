extends SceneTree

## Reads in-memory travel flags through the real companion reader. The host has
## no SaveManager: normalization belongs to the existing pure payload model.
const Companion = preload("res://scripts/companion_controller.gd")
const Fields = preload("res://scripts/models/save_payload_fields.gd")

class Story extends RefCounted:
	var value: Variant = {}
	func get_flag(_key: String, _fallback: Variant = null) -> Variant:
		return value

class Host extends Node:
	var story_state: Story = Story.new()

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _read(host: Host, raw: Variant) -> Dictionary:
	host.story_state.value = raw
	var before := var_to_str(raw)
	var result: Dictionary = Companion.saved_travel(host)
	_check(before == var_to_str(host.story_state.value), "Travel read must not mutate story flags")
	_check(result.size() == 3 and result.has("command") and result.has("zone") and result.has("position"), "Travel result format stays command/zone/position")
	return result

func _run() -> void:
	var host := Host.new()
	_check(Fields.RELEASED_ZONES.size() == 17, "Fixture covers all seventeen currently released zones")
	for zone: String in Fields.RELEASED_ZONES:
		for spelling in [zone, "  " + zone.to_upper() + "  "]:
			var result := _read(host, {"zone": spelling, "command": "wait", "position": [1, 2.5, -3]})
			_check(result.zone == zone and result.command == "wait" and result.position == Vector3(1, 2.5, -3), "Released zone/position retained: " + zone)
	var aliases := {"deep_woods": "deep_wood", "long_road": "bandit_road", "castle_approach": "vargan_approach", "courtyard": "vargan_court"}
	for alias: String in aliases:
		var result := _read(host, {"zone": " " + alias.to_upper() + " ", "command": "follow"})
		_check(result.zone == aliases[alias], "Legacy zone alias retained: " + alias)
	for unknown in ["", "nowhere", "wych wood", "../greyfen", 17, true, null, {}, []]:
		var result := _read(host, {"zone": unknown})
		_check(result.zone == "greyfen", "Invalid zone falls back to Greyfen")
	for raw in [null, 17, true, "invalid travel", [], {}]:
		var result := _read(host, raw)
		_check(result.zone == "greyfen" and result.command == "follow" and result.position == Companion.RESCUE_POSITION, "Missing/malformed travel defaults are unchanged")
	for command in ["follow", "WAIT", "unknown", 17, null]:
		_check(_read(host, {"command": command}).command == "follow", "Only literal wait selects the wait command")
	for coordinates in [[], [1, 2], [1, 2, 3, 4], ["1", 2, 3], [1, null, 3], [NAN, 0, 0], [0, INF, 0], [0, 0, -INF], [1000.01, 0, 0], [0, -1001, 0], {}]:
		_check(_read(host, {"position": coordinates}).position == Companion.RESCUE_POSITION, "Malformed/nonfinite/out-of-bounds coordinates retain rescue position")
	_check(_read(host, {"position": [-1000, 1000.0, 0]}).position == Vector3(-1000, 1000, 0), "Existing finite coordinate boundary remains inclusive")
	for zone: String in Fields.RELEASED_ZONES:
		var result := _read(host, {"zone": zone})
		_check(result.zone == Fields._normalize_zone(zone), "Companion and save codec use the same canonical zone model")
	host.free()
	print(JSON.stringify({"fixture": "companion_saved_travel", "passed": failures.is_empty(), "checks": checks,
		"failures": failures, "released_zones": Fields.RELEASED_ZONES.size(), "save_manager": false,
		"filesystem_save_data": false, "gameplay": false, "render_capture": false}))
	quit(0 if failures.is_empty() else 1)
