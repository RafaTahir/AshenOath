extends SceneTree

## Pure schedules and existing controller ownership on disposable nodes. No
## imported models, journey manager, audio playback or filesystem saves.
const Life = preload("res://scripts/greyfen_life_controller.gd")
const Profile = preload("res://scripts/story_cast_profile.gd")
const Director = preload("res://scripts/systems/npc_routine_director.gd")
const Fixture = preload("res://tools/verify_greyfen_routine_ownership.gd")
const Stations = preload("res://scripts/living_cast_stations.gd")
const PEOPLE := {
	"saga_nessa":["greyfen","nessa","bake"], "widow_elna":["greyfen","elna","fold_cloth"],
	"farmer_toma":["greyfen","toma","tend"], "saga_nera":["marsh_crossing","nera","check_rope"],
	"captain_senn":["bandit_road","senn","watch"], "vargan_record_keeper":["record_hall","vale","read"],
	"vargan_steward":["vargan_court","merrow","check_supplies"], "edric":["record_hall","edric","review_dispatch"]
}

class Face extends Node:
	var mode := "neutral"
	var point := Vector3.ZERO
	var focus: Node3D
	func set_attention(value: String, target: Node3D = null, at: Vector3 = Vector3.ZERO) -> bool:
		mode=value; focus=target; point=at
		return true
	func set_focus_target(target: Node3D) -> void:
		mode="actor"; focus=target

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := Fixture.Host.new()
	root.add_child(host)
	var life := Life.new()
	host.zone_root.add_child(life)
	life.host=host; life.player=host.player
	life.set_process(false); life.set_physics_process(false)
	for id: String in PEOPLE:
		var expected: Array = PEOPLE[id]
		var profile := Profile.routine(id,str(expected[0]),host.story_state,host.quests,"day",600.0)
		_check(str(profile.get("identity","")) == str(expected[1]), id+" retains canonical identity")
		_check(str(profile.get("activity","")) == str(expected[2]), id+" resolves characteristic daytime work")
		var motion := Profile.life_motion_profile(str(expected[1]))
		_check(not str(motion.get("library", "")).is_empty() and str(expected[2]) in motion.get("work",[]), id+" has its own authored work library")
		_check(bool(motion.get("requires_station",false)) == (id != "captain_senn"), id+" distinguishes physical contact from observation")
		for minute in range(0,1440,15):
			var timed := Profile.routine(id,str(expected[0]),host.story_state,host.quests,"day",float(minute))
			_check(bool(timed.get("scheduled",false)) and not timed.path.is_empty() and timed.path.size()==timed.activities.size(),id+" schedule covers minute "+str(minute))
	_check(Profile.CAST.nessa.expression == "warmth", "Nessa authors the supported expression name")
	_check(str(Profile.routine("saga_lysa","record_hall",host.story_state,host.quests,"day",600.0).station.node)=="LifeWork_vale", "Vale's retained alias uses the supported desk, not the low quest fixture")
	var first := _entry(life,host,"saga_nessa",Vector3.ZERO)
	var second := _entry(life,host,"widow_elna",Vector3.ZERO)
	life.actors=[first,second]
	life._begin_activity(first)
	life._begin_activity(second)
	_check(first.activity_active and not second.activity_active,"one station has one actor; the other waits")
	_check(second.pause>0.0,"unavailable work produces bounded waiting")
	life._release_activity(first)
	life._begin_activity(second)
	_check(second.activity_active,"released station is available without stealing another owner's pose")
	life._release_activity(second)
	_verify_meals(host,first)
	_verify_rest(host,life,first)
	_verify_work_orientation(host,life)
	_verify_attention(host,life,first)
	_verify_contact_morph(host,life)
	_verify_satchel_owner(host,life)
	_verify_story_workstation(host,life)
	_verify_contact_binding(host,life)
	_verify_imported_grips(host)
	host.free()
	for failure: String in failures: printerr("STAGE2 ROUTINES: "+failure)
	print("STAGE2 ROUTINES: %s checks=%d" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _verify_imported_grips(host: Node) -> void:
	var prop := Node3D.new()
	host.zone_root.add_child(prop)
	prop.position = Vector3(4,1,-2)
	for side: String in ["Left","Right"]:
		var grip := Node3D.new()
		grip.name="Grip"+side
		grip.position=Vector3(-0.12 if side=="Left" else 0.12,0.02,0)
		prop.add_child(grip)
	var grips := Stations._task_grips(prop)
	_check(grips.size()==2 and (grips.Left as Vector3).is_equal_approx(Vector3(3.88,1.02,-2)),"verified Blender Node3D grip empties bind their actual world positions")
	prop.get_node("GripRight").free()
	_check(Stations._task_grips(prop).is_empty(),"one missing grip rejects both hands before station publication")
	var invalid := Node.new()
	invalid.name="GripRight"
	prop.add_child(invalid)
	_check(Stations._task_grips(prop).is_empty(),"non-spatial grip labels cannot stand in for physical contact markers")
	prop.free()

func _entry(life: Node, host: Node, id: String, point: Vector3) -> Dictionary:
	var actor := Node3D.new()
	actor.name=id; host.zone_root.add_child(actor); actor.position=point
	var driver := Fixture.Driver.new()
	actor.add_child(driver)
	var entry: Dictionary = life._make_entry(id,actor,[point],0.6,driver,true)
	entry.regional=true; entry.arrived_target=0
	entry.profile={"activity":"eat","activities":["eat"],"identity":Profile.canonical_identity(id),"hold_activity":false,"activity_seconds":18.0,"prop":"bread"}
	return entry

func _verify_meals(host: Node, entry: Dictionary) -> void:
	var profile: Dictionary = entry.profile.duplicate(true)
	profile.meal_group="nessa"; profile.path=[Vector3.ZERO]; profile.revision="noon"
	var unavailable := Director.shared_meal_routine(profile,entry,host)
	_check(not unavailable.has("meal_node"),"an absent meal table preserves the person's existing route")
	for index in 2:
		var marker := Marker3D.new()
		marker.name="LifeMeal_nessa_"+str(index)
		marker.position=Vector3(float(index)*2.0,0,1)
		marker.set_meta("meal_supported",true)
		host.zone_root.add_child(marker)
	var meal := Director.shared_meal_routine(profile,entry,host)
	_check(meal.has("meal_node") and not meal.hold_activity,"supported meals release reservations instead of occupying a seat for the whole hour")
	_check(float(meal.activity_seconds)==18.0 and meal.station.is_empty(),"meal has a bounded dwell and cannot bind the worker's task hands")
	_check(meal.path[0]==Director.shared_meal_routine(profile,entry,host).path[0],"shared meal place selection is deterministic")

func _verify_rest(host: Node, life: Node, entry: Dictionary) -> void:
	var anchor := Marker3D.new()
	anchor.name="LifeRest_nessa"
	anchor.position=Vector3(0,0.5,-0.56)
	anchor.set_meta("rest_kind","seated"); anchor.set_meta("rest_supported",true)
	anchor.set_meta("rest_identity","nessa"); anchor.set_meta("stand_offset",Vector3(0,-0.5,0.56))
	host.zone_root.add_child(anchor)
	var profile := {"identity":"nessa","sleeping":true}
	var path: Array=[Vector3.ZERO]
	life._bind_rest_anchor(profile,path)
	_check(not profile.rest_anchor.is_empty(),"verified supported seat binds the intended person's sleep")
	profile.identity="elna"
	life._bind_rest_anchor(profile,path)
	_check(profile.rest_anchor.is_empty(),"one person's named support is not silently borrowed")
	profile.identity="nessa"; anchor.set_meta("rest_supported",false)
	life._bind_rest_anchor(profile,path)
	_check(profile.rest_anchor.is_empty(),"unsupported geometry retains standing rest")

func _verify_work_orientation(host: Node, life: Node) -> void:
	var station := Node3D.new()
	station.name="SyntheticReverseStation"
	station.set_meta("work_identity","nessa")
	host.zone_root.add_child(station)
	for name: String in ["WorkStand","WorkContact","WorkLeft","WorkRight"]:
		var marker := Marker3D.new()
		marker.name=name
		marker.position=Vector3.ZERO if name=="WorkStand" else Vector3(0,1.02,0.40)
		station.add_child(marker)
	var profile := {"station":{"node":str(station.name),"markers":true,"activity":"bake"},"activities":["bake"]}
	var path: Array=[Vector3.ZERO]
	life._bind_workstation(profile,path)
	_check(not profile.workstation.is_empty() and profile.workstation.look.z>profile.workstation.stand.z,"a region station faces its physical contact even when its approach is on the opposite side")

func _verify_attention(host: Node, life: Node, entry: Dictionary) -> void:
	var face := Face.new()
	entry.node.add_child(face); entry.face=face
	life._begin_scene_attention(entry,{"mode":"point","offset":[0,3,-4],"seconds":0.8})
	life._apply_scene_attention(entry,host.player,0.1)
	_check(face.mode=="point" and face.point.is_equal_approx(Vector3(0,3,-4)),"personal sky glance uses a finite actor-relative point")
	life._apply_scene_attention(entry,host.player,1.0)
	life._apply_scene_attention(entry,host.player,0.1)
	_check(face.mode=="actor" and face.focus==host.player,"bounded glance returns to the conversation focus")
	life._begin_scene_attention(entry,{"mode":"point","anchor":"doorway","seconds":1.0})
	_check(not entry.has("scene_attention"),"missing geometry cannot invent a doorway attention target")
	var doorway := Marker3D.new()
	doorway.name="LifeAttention_Doorway"; doorway.position=Vector3(2,1,0)
	doorway.set_meta("attention_anchor","doorway"); doorway.set_meta("geometry_verified",true)
	host.zone_root.add_child(doorway)
	life._begin_scene_attention(entry,{"mode":"point","anchor":"doorway","seconds":1.0})
	_check(entry.scene_attention.point==doorway.position,"verified actual doorway anchor supplies the glance")
	life._begin_scene_attention(entry,{"mode":"point","offset":[100,0,0],"seconds":1.0})
	_check(not entry.has("scene_attention"),"out-of-range authored attention is rejected")
	life._begin_scene_attention(entry,{"mode":"neutral","seconds":1.2})
	life._apply_scene_attention(entry,host.player,0.1)
	_check(face.mode=="neutral","neutral shared rest suppresses automatic gaze")

func _verify_contact_morph(host: Node, life: Node) -> void:
	var actor := Node3D.new()
	host.zone_root.add_child(actor)
	var driver := preload("res://scripts/character_animation_driver.gd").new()
	actor.add_child(driver)
	var station := Node3D.new()
	station.set_meta("work_identity","nessa")
	host.zone_root.add_child(station)
	var prop := Node3D.new()
	station.add_child(prop)
	station.set_meta("task_prop",weakref(prop))
	var part := MeshInstance3D.new()
	part.name="WorkContactPart"
	part.mesh=_contact_mesh(false)
	part.position=Vector3(0,1,-0.4)
	prop.add_child(part)
	part.set_meta("contact_response","morph")
	part.set_meta("contact_shape","TaskPress")
	part.set_meta("contact_neutral_weight",0.2)
	part.set_meta("contact_target_weight",0.8)
	part.set_blend_shape_value(0,0.2)
	var entry := {"node":actor,"driver":driver,"activity_active":true,"profile":{"activity":"bake","workstation":{"node_ref":weakref(station)}}}
	life.actors.append(entry)
	var original := part.transform
	_check(life._begin_station_contact(actor,"nessa") and is_equal_approx(part.get_blend_shape_value(0),0.8),"verified task contact begins the actual shape immediately")
	_check(int(part.get_meta("living_contact_morph").index)==0,"task contact caches the actual mesh shape index")
	life._tick_work_contact_effects(0.175)
	_check(is_equal_approx(part.get_blend_shape_value(0),0.5),"task shape recovers through the shared 0.35-second owner")
	_check(part.transform.is_equal_approx(original),"morph response never also squashes or tilts the prop transform")
	life._clear_work_contact_effects(actor)
	_check(is_equal_approx(part.get_blend_shape_value(0),0.2),"interruption restores the exact declared nonzero neutral")
	for interruption: String in ["dialogue","distance","death","finish"]:
		life._begin_station_contact(actor,"nessa")
		match interruption:
			"dialogue": actor.set_meta("cast_dialogue_owner",1)
			"distance": driver.distance_suspended=true
			"death": driver.dead=true
		life._tick_work_contact_effects(0.4 if interruption=="finish" else 0.001)
		_check(life.work_contact_effects.is_empty() and is_equal_approx(part.get_blend_shape_value(0),0.2),interruption+" releases the stationary task shape")
		actor.remove_meta("cast_dialogue_owner")
		driver.distance_suspended=false
		driver.dead=false
	life._begin_station_contact(actor,"nessa")
	part.mesh=_contact_mesh(true)
	part.set_blend_shape_value(1,0.33)
	life._tick_work_contact_effects(0.1)
	_check(is_equal_approx(part.get_blend_shape_value(1),0.33),"old shape ownership cannot write into a replacement mesh")
	part.set_blend_shape_value(1,0.2)
	_check(life._begin_station_contact(actor,"nessa") and int(part.get_meta("living_contact_morph").index)==1,"a changed actual mesh resolves its new shape index")
	life._release_activity(entry)
	_check(is_equal_approx(part.get_blend_shape_value(1),0.2),"routine release restores the replacement shape neutral")
	life.actors.erase(entry)
	actor.free()
	station.free()

func _contact_mesh(prefix: bool) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if prefix: mesh.add_blend_shape("Unrelated")
	mesh.add_blend_shape("TaskPress")
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.FORWARD])
	var shape: Array=[]
	shape.resize(Mesh.ARRAY_MAX)
	shape[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3(1.02,0,0),Vector3(0,0,-1.02)])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[shape,shape] if prefix else [shape])
	return mesh

func _verify_satchel_owner(host: Node, life: Node) -> void:
	var unrelated_bag := Node3D.new()
	unrelated_bag.name="RookStationSatchel"
	host.zone_root.add_child(unrelated_bag)
	var unrelated_knot := Node3D.new()
	unrelated_knot.name="SatchelKnot"
	unrelated_bag.add_child(unrelated_knot)
	var station := Node3D.new()
	host.zone_root.add_child(station)
	station.set_meta("work_identity","rook")
	var bag := Node3D.new()
	station.add_child(bag)
	var knot := Node3D.new()
	knot.name="SatchelKnot"
	bag.add_child(knot)
	station.set_meta("task_prop",weakref(bag))
	var actor := Node3D.new()
	host.zone_root.add_child(actor)
	var driver := preload("res://scripts/character_animation_driver.gd").new()
	actor.add_child(driver)
	var entry := {"node":actor,"driver":driver,"activity_active":true,"profile":{"workstation":{"node_ref":weakref(station)}}}
	life.actors.append(entry)
	_check(life._begin_satchel_cinch(actor) and knot.scale.x<1.0,"satchel contact animates its bound station knot")
	_check(unrelated_knot.scale==Vector3.ONE,"an earlier unrelated bag cannot receive another station's contact")
	driver.distance_suspended=true
	life._tick_work_contact_effects(0.001)
	_check(knot.scale==Vector3.ONE and life.work_contact_effects.is_empty(),"satchel immediately restores its knot on distance suspension")
	driver.distance_suspended=false
	life._begin_satchel_cinch(actor)
	driver.dead=true
	life._tick_work_contact_effects(0.001)
	_check(knot.scale==Vector3.ONE and life.work_contact_effects.is_empty(),"satchel immediately restores its knot on terminal interruption")
	driver.dead=false
	entry.activity_active=false
	_check(not life._begin_satchel_cinch(actor),"released routines cannot animate an unattended bag")
	entry.activity_active=true
	station.remove_meta("task_prop")
	_check(not life._begin_satchel_cinch(actor),"missing station props cannot fall back to an unrelated bag")
	life.actors.erase(entry)
	actor.free()
	station.free()
	unrelated_bag.free()

func _verify_story_workstation(host: Node, life: Node) -> void:
	var entry := _entry(life,host,"vargan_record_keeper",Vector3(0,0,4))
	life.actors.append(entry)
	_check(life.story_workstation_for(entry.driver,"vale").is_empty(),"a personal ledger scene cannot invent a missing work surface")
	var station := Node3D.new()
	station.name="LifeWork_vale"
	station.set_meta("work_identity","vale")
	host.zone_root.add_child(station)
	var stand := Marker3D.new()
	stand.name="WorkStand"; station.add_child(stand)
	var contact := Marker3D.new()
	contact.name="WorkContact"; contact.position=Vector3(0,1.02,-0.4); station.add_child(contact)
	var prop := Node3D.new()
	station.add_child(prop)
	station.set_meta("task_prop",weakref(prop))
	prop.set_meta("actor_identity","vale")
	prop.set_meta("stationary_supported_prop",true)
	_check(life.story_workstation_for(entry.driver,"vale").is_empty(),"unverified ledger geometry cannot enable its personal scene")
	prop.set_meta("grip_geometry_verified",true)
	var resolved: Dictionary = life.story_workstation_for(entry.driver,"vale")
	_check(not resolved.is_empty() and resolved.stand==stand.global_position and resolved.point==contact.global_position,"personal scene uses the actual verified stand and ledger markers")
	var record := {"entry":entry,"workstation":resolved}
	_check(not life._story_workstation_valid(record),"a ledger scene must acquire the existing station reservation")
	life.activity_reservations[resolved.reservation]=entry.node
	_check(life._story_workstation_valid(record),"the reserved physical ledger remains eligible after ambient work is released")
	_check(not life._story_workstation_aligned(record),"a native ledger cue cannot start metres from its surface")
	entry.node.global_position=stand.global_position
	entry.node.rotation.y=0.0
	_check(life._story_workstation_aligned(record),"an exact stand and task-facing body permit the supported cue")
	entry.node.rotation.y=0.2
	_check(not life._story_workstation_aligned(record),"looking toward Kael with the body cannot redirect the native contact away from its ledger")
	entry.node.rotation.y=0.0
	entry.node.global_position.x=0.05
	_check(not life._story_workstation_aligned(record),"the ordinary twenty-centimetre conversation arrival radius is insufficient for physical work")
	entry.node.global_position=stand.global_position
	contact.position.z-=0.02
	_check(not life._story_workstation_valid(record),"a moved surface invalidates a captured ledger target")
	contact.position.z+=0.02
	var other := Node3D.new()
	host.zone_root.add_child(other)
	life.activity_reservations[resolved.reservation]=other
	_check(life.story_workstation_for(entry.driver,"vale").is_empty(),"an occupied ledger is not borrowed from another worker")
	life._release_story_workstation(record)
	_check(life.activity_reservations.get(resolved.reservation)==other,"late scene cleanup preserves a newer reservation owner")
	life.activity_reservations[resolved.reservation]=entry.node
	life._release_story_workstation(record)
	_check(not life.activity_reservations.has(resolved.reservation),"scene interruption releases only its own station reservation")
	prop.hide()
	_check(life.story_workstation_for(entry.driver,"vale").is_empty(),"a hidden ledger cannot support a visible personal gesture")
	life.actors.erase(entry)
	entry.node.free()
	station.free()
	other.free()

func _verify_contact_binding(host: Node, life: Node) -> void:
	var entry := _entry(life,host,"saga_nessa",Vector3.ZERO)
	var original: Node = entry.driver
	life._connect_activity_contact(entry)
	life._connect_activity_contact(entry)
	_check(original.get_signal_connection_list("activity_contact").size()==1,"repeated routine enrollment retains one exact contact callable")
	var replacement := Fixture.Driver.new()
	entry.node.add_child(replacement)
	entry.driver=replacement
	life._connect_activity_contact(entry)
	_check(original.get_signal_connection_list("activity_contact").is_empty() and replacement.get_signal_connection_list("activity_contact").size()==1,"hydration replacement disconnects the old driver and connects the new owner once")
	life._connect_activity_contact(entry)
	_check(replacement.get_signal_connection_list("activity_contact").size()==1,"repeated hydrated-driver registration remains idempotent")
	var new_actor := Node3D.new()
	host.zone_root.add_child(new_actor)
	var old_actor: Node3D = entry.node
	entry.node=new_actor
	life._connect_activity_contact(entry)
	var callback: Callable = entry.contact_callback
	var bound: Array = callback.get_bound_arguments()
	_check(replacement.get_signal_connection_list("activity_contact").size()==1 and bound.size()==1 and bound[0].get_ref()==new_actor,"rebinding an actor replaces its weak contact target without another handler")
	old_actor.free()
	new_actor.free()

func _check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
