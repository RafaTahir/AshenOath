extends RefCounted

## Edition 1 extends the expanded quest graph. Only a new journey opts in.
## These IDs are needed before regional text mounts, including in save summaries.
const REQUIRED := {
	"main_bell_beneath_greyfen":{"two_doors":"Lay out the two travelers’ burial doors at the cemetery."},
	"main_teeth_in_rain":{"willow_frame":"Follow the smaller tracks to the willow bank."},
	"main_names_they_burned":{"tally_house":"Compare the sanctuary receipt and ask about the second hand."},
	"main_ash_at_the_mill":{"tor_wrist":"Help make the south gallery safe."},
	"main_empty_tables":{"rook_schedule":"Work a serving turn and hear from the crew."},
	"main_soldier_without_banner":{"levy_inventory":"Inventory the seized goods and return the seed barley."},
	"main_blood_under_stone":{"culvert":"Bring the relief convoy in from the marsh road.","seals":"Establish the dates and custody of the orders."},
	"main_last_witness":{"felt_under_iron":"Bring the old command to the gate and preserve the hearing’s limits."},
	"main_house_many_names":{"dry_floor":"Make room for the first arrivals and put the records under cover.","omitted_return":"Meet at the writing board after the work is done."},
	"main_what_we_promise":{"alarm_test":"Try the refuge alarm from both sides of the house."}
}

static func saved_edition(payload: Dictionary) -> bool:
	return payload.get("story_state",{}).get("flags",{}).get("novel_edition",0) == 1

static func extend(defs: Dictionary) -> void:
	preload("res://scripts/novel/garden_petition.gd").project(defs)
	if defs.has("main_road_of_crows"):
		for objective: Dictionary in defs.main_road_of_crows.objectives:
			if objective.id == "vargan_wire": objective.text = "Examine the two loops of wire at the broken cart."
	for quest: String in REQUIRED:
		if not defs.has(quest): continue
		for scene: String in REQUIRED[quest]:
			defs[quest].objectives.append({"id":"novel_"+scene,"text":REQUIRED[quest][scene],"kind":"activity"})

static func owning_quest(id: String) -> String:
	for quest: String in REQUIRED:
		if REQUIRED[quest].has(id): return quest
	return ""

## Commit only the next performed action. A replayed UI callback cannot publish it twice.
static func record_step(state, quests, scene: Dictionary, beat: Dictionary, option: Dictionary, index: int) -> bool:
	var id := str(scene.id)
	if index < 0 or index >= scene.beats.size() or index != int(state.get_flag("novel_step_"+id,0)): return false
	var quest := owning_quest(id)
	if not quest.is_empty() and not quests.is_active(quest): return false
	state.begin_change()
	if beat.has("actor"): state.set_flag("novel_heard_"+str(beat.actor)+"_"+id,true)
	state.set_flag("novel_step_"+id,index+1)
	for outcome: Dictionary in [beat,option]:
		for key: String in outcome.get("set",{}): state.set_flag(key,outcome.set[key])
		if outcome.has("evidence"):
			var item: Dictionary = outcome.evidence
			state.record_evidence("novel:"+str(item.id),{"zone":beat.zone,"title":item.title,"text":item.text,"kind":item.get("kind","observed")})
	if index+1 == scene.beats.size():
		state.set_flag("novel_done_"+id,true)
		finish_scene(quests,id)
	state.end_change()
	return true

static func finish_scene(quests, id: String) -> void:
	var quest := owning_quest(id)
	if not quest.is_empty() and quests.is_active(quest):
		quests.complete_objective(quest,"novel_"+id)
