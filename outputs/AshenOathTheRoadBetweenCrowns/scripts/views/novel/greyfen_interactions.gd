extends RefCounted

static func wait_for_soldier(service: Node, area: Area3D, pack: String) -> void:
	if area.is_in_group("waiting_for_soldier"):
		return
	area.add_to_group("waiting_for_soldier")
	var requested: bool = service.runtime_packs.retry_pack(pack, 0) if service.runtime_packs.get_state(pack) in ["cancelled", "failed"] else service.runtime_packs.request_pack(pack, 0)
	while requested and is_instance_valid(area) and service.active_interactable == area and not service.resource_shutdown_prepared:
		if service.runtime_packs.is_ready(pack):
			area.remove_from_group("waiting_for_soldier")
			service._systems["session"]._dispatch_gameplay_action("interact", area.get_instance_id())
			return
		if service.runtime_packs.get_state(pack) in ["failed", "cancelled"] or service._journey_load_pending():
			break
		await service._host.get_tree().process_frame
	if is_instance_valid(area):
		area.remove_from_group("waiting_for_soldier")
		if service.active_interactable == area and not service.resource_shutdown_prepared and service.runtime_packs.get_state(pack) == "failed":
			service.hud.toast("The soldier could not be loaded. Use the tracks to retry.")

static func visit(service: Node, id: String) -> void:
	match id:
		"village_well":
			service.player.stamina_component.restore(5.0)
			service.hud.toast("Cold iron in the water. Kael catches his breath.")
		"forge_corner":
			var identified: bool = service.story_state.get_flag("novel_edition",0) != 1 or service.story_state.has_evidence("novel:archive_wire")
			service.hud.toast("Vargan iron, hammered into Greyfen hinges. Tor never mentions the crest marks." if identified else "Tor has filed the hinge pins to bright flats. Cloth pushed across the join catches on one tooth.")
		"shrine_prayer":
			var activities: Node = service.zone_root.get_node_or_null("StoryActivities")
			if activities != null:
				activities.activate("shrine_prayer")
		"river_water":
			service.player.stamina_component.restore(18.0)
			service.hud.toast("Cold river water. Clean enough above Greyfen, for now.")
		_: service.hud.toast("Greyfen has made use of everything it could keep.")
