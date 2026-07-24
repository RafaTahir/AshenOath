extends RefCounted

const CampaignSection = preload("res://scripts/zones/campaign_section.gd")
const ZoneBuildContext = preload("res://scripts/zone_build_context.gd")

const CORE_ZONES: Array[String] = ["greyfen", "wychwood", "ruins"]

static func supports(zone_id: String) -> bool:
	var canonical_id := zone_id.strip_edges().to_lower()
	return canonical_id in CORE_ZONES or CampaignSection.SECTIONS.has(canonical_id)

static func composition_kind(zone_id: String) -> String:
	var canonical_id := zone_id.strip_edges().to_lower()
	if not supports(canonical_id):
		push_error("No zone composition registered for '%s'." % zone_id)
		return ""
	return canonical_id if canonical_id in CORE_ZONES else "campaign"

static func build_campaign(host: Node, zone_id: String) -> Dictionary:
	var canonical_id := zone_id.strip_edges().to_lower()
	if not CampaignSection.SECTIONS.has(canonical_id):
		push_error("No campaign composition registered for '%s'." % zone_id)
		return {"ok": false, "zone": canonical_id, "errors": ["unregistered zone"]}
	var context = ZoneBuildContext.new(host, canonical_id)
	CampaignSection.new().build(context, canonical_id)
	return context.validate()

static func registered_zones() -> Array[String]:
	var result: Array[String] = []
	result.assign(CORE_ZONES)
	for zone_id in CampaignSection.SECTIONS.keys():
		result.append(str(zone_id))
	result.sort()
	return result
