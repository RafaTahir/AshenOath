extends RefCounted

## The existing arrival gate calls this with live flags or the prepared save.
## Carry props have to mount even when Continue reopens a different sector.
const SOURCE_SCENES := {
	"novel_field_gallery":"res://assets/narrative_props/field/gallery.tscn",
	"novel_field_culvert":"res://assets/narrative_props/field/culvert.tscn",
	"novel_field_willow":"res://assets/narrative_props/field/willow.tscn",
}

static func requests(zone: String, flags: Dictionary, completed: Dictionary, manager: Node) -> Array[String]:
	var wanted := for_zone(zone,flags,completed)
	if OS.has_feature("web") or manager == null: return wanted
	# Native source projects own the actual scenes directly. Exported projects
	# with an external manifest continue through the ordinary mount gate.
	for id: String in SOURCE_SCENES:
		if id in wanted and manager.get_pack(id).is_empty() and ResourceLoader.exists(SOURCE_SCENES[id]):
			wanted.erase(id)
	return wanted

static func for_zone(zone: String, flags: Dictionary, completed: Dictionary) -> Array[String]:
	var packs: Array[String] = []
	var edition: Variant = flags.get("novel_edition",0)
	if typeof(edition) not in [TYPE_INT,TYPE_FLOAT] or edition != 1:
		return packs

	if zone == "lantern_reach" and flags.get("final_covenant") == "open_road" and not flags.get("novel_bank_cleared",false) and not flags.get("novel_departure_second_rescue",false):
		packs.append("actor_m02") # Wychwood Stalker, shared with the existing hunt.

	var willow := int(flags.get("novel_step_willow_frame",0))
	if (zone == "wychwood" and willow < 3) or willow in [2,3] or (zone == "cemetery" and willow == 4):
		packs.append("novel_field_willow")

	var gallery := int(flags.get("novel_step_tor_wrist",0))
	if zone == "old_mill" and gallery < 3:
		packs.append("novel_field_gallery")

	var culvert := int(flags.get("novel_step_culvert",0))
	var washroom: bool = (
		zone == "vargan_approach"
		and culvert >= 4
		and flags.get("novel_done_counterpart",false) != true
		and not completed.has("main_blood_under_stone")
	)
	if (zone == "marsh_crossing" and culvert < 3) or culvert == 3 or washroom:
		packs.append("novel_field_culvert")
	return packs
