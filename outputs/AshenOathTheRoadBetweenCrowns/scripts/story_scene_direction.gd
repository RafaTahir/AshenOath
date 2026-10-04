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

const TOPICS := {
	"anwen_orens_coat":{"emotion":"grieving", "gesture":"remember"},
	"anwen_basket_handles":{"emotion":"concerned", "gesture":"offer"},
	"mira_medicine_labels":{"emotion":"concerned", "gesture":"remember"},
	"rook_bram_axle":{"emotion":"wry", "gesture":"acknowledge"},
	"rook_road_questions":{"emotion":"guarded", "gesture":"remember"},
	"tor_grinding_stone":{"emotion":"grieving", "gesture":"remember"},
	"tor_hammer_grip":{"emotion":"wry", "gesture":"explain"},
	"edric_seal_in_hand":{"emotion":"guarded", "gesture":"remember"},
	"senn_reading_refusal":{"emotion":"concerned", "gesture":"remember"},
	"halvern_preserved_words":{"emotion":"grieving", "gesture":"remember"}
}

static func for_topic(topic_id: String, variant: String, page: Dictionary, index: int, count: int) -> Dictionary:
	var profile: Dictionary = TOPICS.get(topic_id, {"emotion":"neutral", "gesture":"acknowledge"})
	var emotion := str(profile.emotion)
	if topic_id == "edric_seal_in_hand" and variant in ["exposed", "compelled"]:
		emotion = "stern" if variant == "exposed" else "guarded"
	elif topic_id == "mira_medicine_labels" and variant == "kept":
		emotion = "guarded"
	elif topic_id == "rook_road_questions" and variant == "erased":
		emotion = "grieving"
	var player_speaks := str(page.get("speaker_id", "")) == "player"
	var final_answer := not player_speaks and index == count - 1
	var gesture := str(profile.gesture) if final_answer else ""
	# The opening question establishes both people. The final answer has room
	# for a single reaction; short intervening questions keep their hands still.
	return {
		"emotion":("wry" if topic_id == "tor_hammer_grip" and index == 2 else "concerned") if player_speaks else emotion,
		"listener_emotion":emotion if player_speaks else ("wry" if emotion == "wry" else "concerned"),
		"gesture":gesture,
		"listener_gesture":"acknowledge" if final_answer and emotion == "wry" else "",
		"framing":"two_shot" if index == 0 else ("close" if final_answer and emotion in ["grieving", "guarded"] else "speaker"),
		"reaction_delay":0.38 if final_answer else 0.18
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
