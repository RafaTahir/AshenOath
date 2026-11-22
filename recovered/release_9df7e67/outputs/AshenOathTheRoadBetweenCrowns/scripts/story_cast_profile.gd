extends RefCounted

## Authored identity recipes shared by wardrobe, facial attitude and staging.
## Heights and authored faces remain owned by the existing imported rigs.
const CAST := {
	"kael": {"primary":"26352f", "secondary":"493b32", "hair":"77756f", "skin":"a9785f", "width":1.0, "depth":1.0, "expression":"guarded", "gesture":"acknowledge", "pace":0.86, "accent":"a18c60", "token":"broken_oath", "motif":"oath"},
	"anwen": {"primary":"28334b", "secondary":"646075", "hair":"b8b4aa", "skin":"a98270", "width":1.0, "depth":1.0, "expression":"concerned", "gesture":"offer", "pace":0.82, "accent":"b19b74", "token":"bell", "motif":"names"},
	"rook": {"primary":"263a32", "secondary":"756047", "hair":"3b2c23", "skin":"8f664f", "width":0.95, "depth":0.97, "expression":"wry", "gesture":"explain", "pace":1.06, "accent":"aa805a", "token":"road_knot", "motif":"road"},
	"mira": {"primary":"364a38", "secondary":"786e51", "hair":"33251e", "skin":"a97559", "width":0.98, "depth":1.01, "expression":"concerned", "gesture":"offer", "pace":0.88, "accent":"799672", "token":"root", "motif":"mercy"},
	"tor": {"primary":"312a27", "secondary":"6c4935", "hair":"66554a", "skin":"a88a6c", "width":1.07, "depth":1.04, "expression":"resolute", "gesture":"acknowledge", "pace":0.76, "accent":"897565", "token":"iron", "motif":"duty"},
	"elna": {"primary":"373341", "secondary":"646271", "hair":"96908a", "skin":"a47a66", "width":0.96, "depth":0.98, "expression":"grieving", "gesture":"remember", "pace":0.72, "accent":"c0ad87", "token":"name", "motif":"names"},
	"toma": {"primary":"594c36", "secondary":"918371", "hair":"5c4939", "skin":"b07f68", "width":1.02, "depth":1.0, "expression":"concerned", "gesture":"explain", "pace":0.96, "accent":"c4b999", "token":"grain", "motif":"road"},
	"senn": {"primary":"3e4a4c", "secondary":"544b42", "hair":"746b5a", "skin":"916b54", "width":1.02, "depth":1.02, "expression":"guarded", "gesture":"remember", "pace":0.78, "accent":"aa9470", "token":"broken_oath", "motif":"oath"},
	"edric": {"primary":"363b45", "secondary":"622f32", "hair":"574639", "skin":"a2765e", "width":1.03, "depth":1.0, "expression":"stern", "gesture":"explain", "pace":0.90, "accent":"ac945b", "token":"seal", "motif":"renewal"},
	"halvern": {"primary":"424953", "secondary":"574946", "hair":"7d7669", "skin":"89715e", "width":1.03, "depth":1.04, "expression":"grieving", "gesture":"acknowledge", "pace":0.70, "accent":"8c8370", "token":"broken_oath", "motif":"oath"},
}

static func identity(role: String, seed: String = "") -> String:
	var words := (role + " " + seed).to_lower()
	words = " " + words.replace("_", " ").replace("-", " ") + " "
	if role in ["player", "player_human", "player_kael"]:
		return "kael"
	for id in CAST:
		if words.contains(" " + str(id) + " "):
			return str(id)
	return ""

static func get_profile(role: String, seed: String = "") -> Dictionary:
	var id := identity(role, seed)
	if id == "":
		return {}
	var result: Dictionary = CAST[id].duplicate()
	result["id"] = id
	return result

static func expression_for(profile: Dictionary, state) -> String:
	var id := str(profile.get("id", ""))
	if state != null:
		if bool(state.get_flag("final_choice_completed", false)):
			return "relieved" if str(state.get_flag("final_covenant", "")) != "ash" else "resolute"
		if id == "kael" and bool(state.get_flag("kael_confessed", false)):
			return "resolute"
		if id == "edric" and str(state.get_flag("confession_method", "")) != "":
			return "guarded"
		if id == "mira" and str(state.get_flag("mira_truth", "")) != "":
			return "relieved"
	return str(profile.get("expression", "neutral"))
