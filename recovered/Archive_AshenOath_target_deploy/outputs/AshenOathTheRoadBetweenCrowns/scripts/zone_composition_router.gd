extends RefCounted

const CampaignSection = preload("res://scripts/zones/campaign_section.gd")
const GreyfenSection = preload("res://scripts/zones/greyfen_section.gd")
const RuinsSection = preload("res://scripts/zones/ruins_section.gd")
const WychwoodSection = preload("res://scripts/zones/wychwood_section.gd")

const CORE_ZONES: Array[String] = ["greyfen", "wychwood", "ruins"]

static func supports(zone_id: String) -> bool:
	var canonical_id := _canonical(zone_id)
	return canonical_id in CORE_ZONES or CampaignSection.SECTIONS.has(canonical_id)

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
	match canonical_id:
		"greyfen":
			GreyfenSection.new().build(context)
		"wychwood":
			WychwoodSection.new().build(context)
		"ruins":
			RuinsSection.new().build(context)
	return context.validate()

static func build_campaign(host: Node, zone_id: String) -> Dictionary:
	var canonical_id := _canonical(zone_id)
	if not CampaignSection.SECTIONS.has(canonical_id):
		return _failure(canonical_id, "unregistered campaign zone")
	var context := ZoneBuildContext.new(host, canonical_id)
	CampaignSection.new().build(context)
	return context.validate()

static func registered_zones() -> Array[String]:
	var result: Array[String] = []
	result.assign(CORE_ZONES)
	for zone_id in CampaignSection.SECTIONS.keys():
		result.append(str(zone_id))
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
