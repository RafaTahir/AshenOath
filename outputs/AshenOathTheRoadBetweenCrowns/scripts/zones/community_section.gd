extends RefCounted

## Loaded by the destination router after the community pack is mounted.
const Rules = preload("res://scripts/community_campaign.gd")
const Presentation = preload("res://scripts/community_presentation.gd")
const ACTOR_POSITIONS := {
	"lantern_reach":{"nessa":Vector3(-6,0,3.2),"elna":Vector3(-9,0,-2),"toma":Vector3(-3,0,-4.4),"tor":Vector3(1,0,-5.5),"rook":Vector3(5,0,6),"nera":Vector3(10,0,-6)},
	"hearthward":{"anwen":Vector3(-8,0,1),"mira":Vector3(-7,0,-4),"vale":Vector3(7,0,-5),"merrow":Vector3(-2.5,0,5),"nessa":Vector3(-5.5,0,7.5),"nera":Vector3(8,0,7),"rook":Vector3(3,0,10),"tor":Vector3(-11,0,-1),"elna":Vector3(-10,0,5),"toma":Vector3(-2,0,-6),"edric":Vector3(3,0,-8),"senn":Vector3(9,0,2)}
}

func step_count(zone: String) -> int:
	return construction_steps(zone).size()

func build_step(context: ZoneBuildContext, index: int) -> bool:
	var steps := construction_steps(context.zone_id)
	return index >= 0 and index < steps.size() and steps[index].call(context) == true

func construction_steps(zone: String) -> Array[Callable]:
	if not ACTOR_POSITIONS.has(zone):
		return []
	var steps: Array[Callable] = [_ground, _shelters, _work, _people, _routes]
	return steps

func build(context: ZoneBuildContext) -> void:
	var steps := construction_steps(context.zone_id)
	if steps.is_empty():
		push_error("Community construction has no steps: " + context.zone_id)
		return
	for step: Callable in steps:
		if step.call(context) != true:
			push_error("Community construction failed: "+context.zone_id)
			return

func _ground(context: ZoneBuildContext) -> bool:
	if not Rules.enabled(context.story_state): return false
	var earth := Color(0.13,0.14,0.105) if context.zone_id=="lantern_reach" else Color(0.16,0.15,0.12)
	if context.zone_id=="lantern_reach":
		# A shallow branch of the river leaves two inspected banks. The old
		# service footway to the north remains available for the initial survey.
		context.make_ground(Vector3(-8.25,-0.08,0),Vector3(23.5,0.16,32),earth)
		context.make_ground(Vector3(14.75,-0.08,0),Vector3(10.5,0.16,32),earth)
		context.make_ground(Vector3(6.5,-0.08,-9),Vector3(6,0.16,14),earth)
		context.make_ground(Vector3(6.5,-0.08,9),Vector3(6,0.16,14),earth)
		context.make_ground(Vector3(6.5,-0.55,0),Vector3(6,0.16,4),earth.darkened(0.2))
		context.make_water_patch("LandingChannel",Vector3(6.5,-0.2,0),Vector3(6,0.025,4),Color(0.12,0.23,0.22,0.75))
		context.make_road(Vector3(6.5,0.02,-3),Vector3(7,0.04,1.5),earth.lightened(0.16))
	else:
		context.make_ground(Vector3(0,-0.08,0),Vector3(40,0.16,32),earth)
	context.make_play_area_bounds(40,32,earth.darkened(0.3))
	context.make_road(Vector3(-1,0.02,5),Vector3(3.5,0.04,20),earth.lightened(0.1))
	context.make_road(Vector3(-2,0.02,-7),Vector3(27,0.04,2.8),earth.lightened(0.1))
	context.make_light("CommunityHearthFill",Vector3(-4,3.2,2),Color(0.72,0.54,0.32),1.7)
	var marker := Node3D.new()
	marker.name="CampaignSection_"+context.zone_id
	context.add_node(marker)
	return true

func _shelters(context: ZoneBuildContext) -> bool:
	# Retained village shells form the exterior silhouette; open timber rooms
	# keep every work surface and conversational approach visible and usable.
	context.make_village_house_dressed(Vector3(-14,0,-10),10,"CommunityStore")
	context.make_village_house_dressed(Vector3(14,0,-10),-12,"CommunityStoreEast")
	var shelter := Node3D.new()
	shelter.name="LandingKitchenShelter" if context.zone_id=="lantern_reach" else "OpenRefuge"
	context.add_node(shelter)
	var host = context.construction_host()
	var centre := Vector3(-5,0,0)
	for x in [-11.0,1.0]:
		for z in [-5.5,5.5]:
			Presentation._box(host,shelter,Vector3(x,1.8,z),Vector3(0.2,3.6,0.2),Presentation.WOOD)
			context.make_collision_box("RefugePost",Vector3(x,1.8,z),Vector3(0.2,3.6,0.2))
	for z in [-5.5,5.5]: Presentation._box(host,shelter,Vector3(-5,3.5,z),Vector3(12.3,0.22,0.24),Presentation.WOOD)
	for x in [-11,-8,-5,-2,1]:
		Presentation._box(host,shelter,Vector3(x,3.65,0),Vector3(0.16,0.18,11.4),Presentation.WOOD)
	var roof := Presentation._box(host,shelter,centre+Vector3(0,3.8,0),Vector3(12.5,0.08,11.6),Presentation.LINEN.darkened(0.22))
	roof.rotation_degrees.x=3
	_overhead(context,"CommunityRainShelter",centre+Vector3(0,3.8,0),Vector3(12.5,0.08,11.6))
	if context.zone_id=="hearthward":
		# Partial rear wall shelters beds without hiding arrivals or task targets.
		for x in [-10,-8,-6,-4,-2,0]: Presentation._box(host,shelter,Vector3(x,1.35,-5.5),Vector3(1.95,2.7,0.12),Presentation.WOOD.darkened(0.13))
		context.make_collision_box("RefugeBackWall",Vector3(-5,1.35,-5.5),Vector3(12,2.7,0.12))
		# The public shelves have their own dry, open porch beside the sleeping
		# room. Neither the canopy nor its posts cover the record work edges.
		for x in [2.0,9.0]:
			for z in [-7.0,1.0]:
				Presentation._box(host,shelter,Vector3(x,1.6,z),Vector3(0.16,3.2,0.16),Presentation.WOOD)
				context.make_collision_box("RecordPorchPost",Vector3(x,1.6,z),Vector3(0.16,3.2,0.16))
		Presentation._box(host,shelter,Vector3(5.5,3.25,-3),Vector3(7.4,0.10,8.4),Presentation.LINEN.darkened(0.25))
		_overhead(context,"RecordPorchRainShelter",Vector3(5.5,3.25,-3),Vector3(7.4,0.10,8.4))
	for position in [Vector3(-15,0,9),Vector3(16,0,10),Vector3(-17,0,-2),Vector3(17,0,-1)]: context.make_tree(position)
	context.make_cart(Vector3(-13,0,8))
	context.make_loose_role("barrel",Vector3(-10,0,8),Vector3.ONE*0.8,8)
	context.make_loose_role("crate",Vector3(-12,0,-6),Vector3.ONE*0.7,0)
	for position in [Vector3(-2.5,0,9),Vector3(10,0,-6),Vector3(-10,0,6)]: context.make_torch(position)
	# The existing rest owner supplies morning/evening waits for the two shifts.
	Presentation._box(host,shelter,Vector3(-9,0.48,4.8),Vector3(2,0.12,0.52),Presentation.WOOD)
	for x in [-9.75,-8.25]: Presentation._box(host,shelter,Vector3(x,0.24,4.8),Vector3(0.12,0.48,0.48),Presentation.WOOD)
	context.make_collision_box("CommunityRestBench",Vector3(-9,0.27,4.8),Vector3(2,0.54,0.52))
	return true

func _work(context: ZoneBuildContext) -> bool:
	Presentation.build(context)
	return true

func _overhead(context: ZoneBuildContext, id: String, position: Vector3, size: Vector3) -> void:
	var roof := StaticBody3D.new()
	roof.name=id
	roof.position=position
	roof.set_meta("walkable_support",false)
	var collision := CollisionShape3D.new()
	collision.shape=preload("res://scripts/immutable_collision_shapes.gd").box(size)
	roof.add_child(collision)
	context.add_node(roof)

func _people(context: ZoneBuildContext) -> bool:
	for id: String in ACTOR_POSITIONS[context.zone_id]:
		if not Rules.actor_available(id,context.story_state,context.quests): continue
		var row: Dictionary = Rules.data().participant_lines[id]
		var actor = context.make_named_interactable(str(Rules.ACTORS[id]),"dialogue","Speak to "+str(row.name),ACTOR_POSITIONS[context.zone_id][id],Color(0.40,0.36,0.28))
		if actor == null: return false
		actor.set_meta("community_actor_id",id)
		# Construct all eligible identities once, but publish at most eight NPCs.
		# The activity owner reconciles a later clock change and enrolls arrivals.
		var clock = context._host.get("day_night")
		actor.visible = Rules.actor_present(id,context.zone_id,float(clock.get_time()) if clock != null else 600.0,context.story_state,context.quests)
	return true

func _routes(context: ZoneBuildContext) -> bool:
	var lantern := context.zone_id=="lantern_reach"
	context.make_zone_gate("Return to the mill road" if lantern else "Return to the last witness's road",Vector3(18,0,10) if lantern else Vector3(0,0,14),"old_mill" if lantern else "undercroft",Vector3(-16,1,9) if lantern else Vector3(6,1,-12))
	return true
