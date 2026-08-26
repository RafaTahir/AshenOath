extends RefCounted

const CORE_ZONES: Array[String] = ["greyfen", "wychwood", "ruins"]
const CORE_BUILDER_PATHS := {
	"greyfen": "res://scripts/zones/greyfen_section.gd",
	"wychwood": "res://scripts/zones/wychwood_section.gd",
	"ruins": "res://scripts/zones/ruins_section.gd",
}
const CAMPAIGN_ZONES: Array[String] = [
	"deep_wood", "old_mill", "burned_farmstead", "marsh_crossing", "bandit_road",
	"vargan_approach", "vargan_court", "record_hall", "undercroft", "assembly", "hart_glade",
]
const CAMPAIGN_BUILDER_PATH := "res://scripts/zones/campaign_section.gd"

static func supports(zone_id: String) -> bool:
	var canonical_id := _canonical(zone_id)
	return canonical_id in CORE_ZONES or canonical_id in CAMPAIGN_ZONES

static func composition_kind(zone_id: String) -> String:
	var canonical_id := _canonical(zone_id)
	if not supports(canonical_id):
		push_error("No zone composition registered for '%s'." % zone_id)
		return ""
	return canonical_id if canonical_id in CORE_ZONES else "campaign"

static func build_core(host: Node, zone_id: String) -> Dictionary:
	var canonical_id := _canonical(zone_id)
	if canonical_id not in CORE_ZONES:
		return _failure(canonical_id, "unregistered core zone")
	var context := ZoneBuildContext.new(host, canonical_id)
	context.record_operation("begin:%s" % canonical_id)
	# Core builders live in the opening runtime pack. Resolve them only after
	# that pack has mounted so the production menu PCK stays small and the
	# browser never parses a resource it cannot provide yet.
	var builder_script: Script = load(str(CORE_BUILDER_PATHS.get(canonical_id, ""))) as Script
	if builder_script == null:
		return _failure(canonical_id, "core builder pack is not mounted")
	var builder = builder_script.new()
	if builder == null or not builder.has_method("build"):
		return _failure(canonical_id, "core builder is invalid")
	builder.build(context)
	return context.validate()

static func build_campaign(host: Node, zone_id: String) -> Dictionary:
	var canonical_id := _canonical(zone_id)
	if canonical_id not in CAMPAIGN_ZONES:
		return _failure(canonical_id, "unregistered campaign zone")
	var context := ZoneBuildContext.new(host, canonical_id)
	context.record_operation("begin:%s" % canonical_id)
	# Campaign builders are resolved only when a player reaches the campaign.
	# This keeps later-zone scripts and optional assets out of the startup graph.
	var builder_script: Script = load(CAMPAIGN_BUILDER_PATH) as Script
	if builder_script == null:
		return _failure(canonical_id, "campaign builder pack is not mounted")
	var builder = builder_script.new()
	if builder == null or not builder.has_method("build"):
		return _failure(canonical_id, "campaign builder is invalid")
	builder.build(context)
	return context.validate()

static func registered_zones() -> Array[String]:
	var result: Array[String] = []
	result.assign(CORE_ZONES)
	result.append_array(CAMPAIGN_ZONES)
	result.sort()
	return result

static func _canonical(zone_id: String) -> String:
	return zone_id.strip_edges().to_lower()

static func _failure(zone_id: String, message: String) -> Dictionary:
	push_error("Zone composition failed for '%s': %s." % [zone_id, message])
	return {
		"ok": false,
		"zone": zone_id,
		"errors": [message],
		"ground_count": 0,
		"bounds_count": 0,
		"gate_count": 0,
	}
