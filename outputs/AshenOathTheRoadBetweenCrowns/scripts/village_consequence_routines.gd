extends RefCounted

## Work follows committed story outcomes. These schedules never commit them.
const FLAGS := ["cart_helped", "road_repaired", "assembly_relief_ready", "mill_operation", "final_choice_completed", "final_covenant"]

static func signature(state) -> String:
	var values: Array = []
	for flag in FLAGS:
		values.append(state.get_flag(flag, null))
	return str(hash(values))

static func for_actor(id: String, state) -> Dictionary:
	var result: Dictionary = {}
	var mill := str(state.get_flag("mill_operation", ""))
	if id in ["walker_well", "water_carrier"] and bool(state.get_flag("cart_helped", false)):
		result = {"activity":"kitchen", "occupation":"kitchen helper", "activity_seconds":4.2,
			"line":"Rook's flour reached the kitchen. I'm fetching water for the next pot.",
			"path":[Vector3(-7.6,0,-0.3), Vector3(-5.1,0,2.0), Vector3(-4.8,0,3.0)]}
	if id in ["forge_helper", "quality_sweeper"] and bool(state.get_flag("road_repaired", false)):
		result = {"activity":"drain", "occupation":"road keeper", "activity_seconds":3.5,
			"line":"The boards are holding. Keep the ditch clear and they might last the rain.",
			"path":[Vector3(8.0,0,2.0), Vector3(4.3,0,6.3), Vector3(3.5,0,7.8)]}
	if id == "walker_board" and mill != "":
		match mill:
			"closed":
				result = {"activity":"kitchen", "occupation":"reserve grain carrier", "activity_seconds":4.8,
					"line":"No mill shifts today. We weigh the reserve grain by household now.",
					"path":[Vector3(-6.3,0,8.0), Vector3(-5.1,0,3.2), Vector3(-3.5,0,1.8)]}
			"supervised":
				result = {"activity":"notice_board", "occupation":"mill account reader", "activity_seconds":5.0,
					"line":"They've signed the mill sheet. I still want to know which sacks are safe."}
			"restitution":
				result = {"activity":"forge", "occupation":"mill repair helper", "activity_seconds":4.5,
					"line":"Fresh boards for the mill. The copied accounts say whose wages come first.",
					"path":[Vector3(6.5,0,4.0), Vector3(8.1,0,2.0), Vector3(9.8,0,1.0)]}
	if id in ["shrine_pilgrim", "young_villager"] and bool(state.get_flag("assembly_relief_ready", false)):
		result = {"activity":"relief", "occupation":"household relief carrier", "activity_seconds":4.0,
			"line":"The household shares are accounted for. I'll take the empty bowls back.",
			"path":[Vector3(-4.8,0,2.1), Vector3(-8.3,0,3.8), Vector3(-5.8,0,5.2)]}
	if bool(state.get_flag("final_choice_completed", false)) and id in ["shrine_pilgrim", "quality_mourner"]:
		var covenant := str(state.get_flag("final_covenant", ""))
		var lines := {
			"witness":"The names are ours to keep now. I'm taking a copy to the next household.",
			"mercy":"No household owes a child. There's still supper to carry, and people to sit beside.",
			"duty":"Kael carries the oath. That doesn't lift the rest of us from our work.",
			"ash":"The binding is gone. We still have to decide how to live beside each other."
		}
		result = {"activity":"shrine", "occupation":"keeper of the returned names", "activity_seconds":5.0,
			"line":str(lines.get(covenant, "We keep the names, and tomorrow's work.")),
			"path":[Vector3(4.6,0,-6.6), Vector3(1.2,0,-4.0), Vector3(-3.6,0,2.6)]}
	return result
