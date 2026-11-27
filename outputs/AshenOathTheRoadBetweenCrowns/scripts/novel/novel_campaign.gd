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
	"main_blood_under_stone":{"seals":"Establish the dates and custody of the orders."},
	"main_last_witness":{"felt_under_iron":"Bring the old command to the gate and preserve the hearing’s limits."},
	"main_house_many_names":{"dry_floor":"Make room for the first arrivals and put the records under cover.","omitted_return":"Meet at the writing board after the work is done."},
	"main_what_we_promise":{"alarm_test":"Try the refuge alarm from both sides of the house."}
}

static func saved_edition(payload: Dictionary) -> bool:
	return payload.get("story_state",{}).get("flags",{}).get("novel_edition",0) == 1

static func extend(defs: Dictionary) -> void:
	for quest: String in REQUIRED:
		if not defs.has(quest): continue
		for scene: String in REQUIRED[quest]:
			defs[quest].objectives.append({"id":"novel_"+scene,"text":REQUIRED[quest][scene]})

static func finish_scene(quests, id: String) -> void:
	for quest: String in REQUIRED:
		if REQUIRED[quest].has(id) and quests.is_active(quest):
			quests.complete_objective(quest,"novel_"+id)
			return
