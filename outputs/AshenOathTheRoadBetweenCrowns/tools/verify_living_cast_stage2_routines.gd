extends SceneTree

## Pure schedules and existing controller ownership on disposable nodes. No
## imported models, journey manager, audio playback or filesystem saves.
const Life = preload("res://scripts/greyfen_life_controller.gd")
const Profile = preload("res://scripts/story_cast_profile.gd")
const Director = preload("res://scripts/systems/npc_routine_director.gd")
const Fixture = preload("res://tools/verify_greyfen_routine_ownership.gd")
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
	_verify_attention(host,life,first)
	host.free()
	for failure: String in failures: printerr("STAGE2 ROUTINES: "+failure)
	print("STAGE2 ROUTINES: %s checks=%d" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

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

func _check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
