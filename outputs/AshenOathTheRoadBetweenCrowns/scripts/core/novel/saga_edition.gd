extends RefCounted

const Garden = preload("res://scripts/core/novel/garden_petition.gd")

static func project_row(record: Dictionary, id: String, state: Object) -> Dictionary:
	if Garden.active(id,state): return Garden.row(record)
	if id == "side_escort_06" and _refuge_receiving(state):
		var steps: Array = record.steps.duplicate(true)
		steps[0] = ["handover_relief","Unload the relief tray beside the refuge freight door","receiving","work",["Lay the wet gear out to dry","Give the receiving clerk the copy of the boat tally"],"Count the people received and the property lost separately. A missing blanket is not a missing passenger."]
		steps[1][1] = "Leave Nera a choice about the supper at the refuge"
		steps[1][2] = "receiving"
		steps[2] = ["return_home","Hand over the freight tally and collect the signed receipt","arrivals","work",["Compare the arrival count with the two passenger tallies","Give the next shift the receipt and put down the board"],"Nera collects the relief cord. The next departure will run to her freight schedule.",{"zone":"hearthward"}]
		return record.merged({"zone":"hearthward","completed_zone":"hearthward","site":"receiving","steps":steps},true)
	return record

static func _refuge_receiving(state: Object) -> bool:
	return state != null and state.get_flag("novel_edition",0)==1 and state.get_flag("final_covenant","")=="open_road" and state.get_flag("open_road_relocation_completed",false)==true

const PERFORMANCE_PATH := "res://data/regional_performances.json"
static var _performances: Dictionary = {}

static func performance(id: String) -> Dictionary:
	if _performances.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PERFORMANCE_PATH))
		if data is Dictionary and int(data.get("version", 0)) == 1:
			_performances = data.get("quests", {})
	return _performances.get(id, {})
