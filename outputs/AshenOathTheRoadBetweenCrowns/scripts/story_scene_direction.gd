extends RefCounted

## Performance direction only: no changes to dialogue meaning or decisions.
const SCENES := {
	"sister_anwen":{"emotion":"concerned", "listener":"guarded", "gesture":"remember"},
	"edric_campaign":{"emotion":"stern", "listener":"guarded", "gesture":"explain"},
	"halvern":{"emotion":"grieving", "listener":"concerned", "gesture":"remember"},
	"captain_senn":{"emotion":"guarded", "listener":"stern", "gesture":"remember"},
	"white_hart":{"emotion":"resolute", "listener":"grieving", "gesture":"acknowledge"},
	"report_decision":{"emotion":"grieving", "listener":"concerned", "gesture":"remember"},
}

static func for_page(scene_id: String, page: Dictionary, index: int) -> Dictionary:
	var profile: Dictionary = SCENES.get(scene_id, {"emotion":"neutral", "listener":"concerned", "gesture":"acknowledge"})
	if scene_id.begins_with("aftermath_"):
		profile = {"emotion":"resolute", "listener":"relieved", "gesture":"acknowledge"}
	elif scene_id.begins_with("opening_care_"):
		profile = {"emotion":"concerned", "listener":"concerned", "gesture":"remember"}
	var speaker := str(page.get("speaker_id", ""))
	var words := str(page.get("text", "")).to_lower()
	var admission: bool = speaker == "player" and (words.contains("i left") or words.contains("i abandoned") or words.contains("never went back"))
	return {
		"emotion":"grieving" if admission else str(profile.emotion),
		"listener_emotion":"concerned" if admission else str(profile.listener),
		"gesture":"remember" if admission else (str(profile.gesture) if index == 0 or index % 3 == 1 else ""),
		"framing":"two_shot" if speaker == "narrator" else ("close" if admission or scene_id in ["halvern", "report_decision"] else "speaker"),
		"reaction_delay":0.30 if admission else 0.14,
	}
