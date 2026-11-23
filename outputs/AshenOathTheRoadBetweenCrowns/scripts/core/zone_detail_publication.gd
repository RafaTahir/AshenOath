extends RefCounted

static func apply(host: Node, context: ZoneBuildContext, builder: RefCounted, stage: String) -> Dictionary:
	var root := context.zone_root
	if not is_instance_valid(root) or root != host.zone_root:
		return failure(context.zone_id, "detail-stage owner is no longer current")
	var owns_reads: bool = host.story_state.world_reads.capturing.is_empty()
	if owns_reads:
		host._begin_zone_world_reads(context.zone_id, false)
	builder.build_detail_stage(context, stage)
	if owns_reads:
		host._end_zone_world_reads()
	# Configuration failures are recorded as each actor is created. The covered
	# opening has one full ownership pass just before the scene can draw.
	var errors: Array = context.construction_host().read_construction_tag(root, "actor_animation_errors", {}).values()
	return {"ok": errors.is_empty(), "errors": errors, "zone": context.zone_id, "stage": stage}

static func failure(zone_id: String, message: String) -> Dictionary:
	push_error("Zone composition failed for '%s': %s." % [zone_id, message])
	return {
		"ok": false,
		"zone": zone_id,
		"errors": [message],
		"ground_count": 0,
		"bounds_count": 0,
		"gate_count": 0,
	}
