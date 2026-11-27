extends RefCounted

## The existing arrival gate calls this with live flags or the prepared save.
## Carry props have to mount even when Continue reopens a different sector.
static func for_zone(zone: String, flags: Dictionary, completed: Dictionary) -> Array[String]:
	var packs: Array[String] = []
	var edition: Variant = flags.get("novel_edition",0)
	if typeof(edition) not in [TYPE_INT,TYPE_FLOAT] or edition != 1:
		return packs

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
