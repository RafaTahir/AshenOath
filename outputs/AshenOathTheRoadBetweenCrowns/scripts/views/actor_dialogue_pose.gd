extends RefCounted

const CastProfile = preload("res://scripts/story_cast_profile.gd")

static func speaker_matches(identity: String, speaker_id: String) -> bool:
	if speaker_id == "narrator" or identity.is_empty(): return false
	var canonical := CastProfile.canonical_identity(identity)
	if not canonical.is_empty(): return CastProfile.canonical_identity(speaker_id) == canonical
	return identity == speaker_id

static func supporting_speaker(actor_id: String, speaker: String) -> bool:
	var supporting_speakers: Dictionary = {
		"vargan_gate_guard":["vargan_steward", "merrow"],
		"vargan_patrol":["vargan_patrol_guard", "guard"],
		"vargan_steward":["steward_merrow", "merrow"],
		"vargan_servant":["tired_castle_servant", "servant"],
		"vargan_record_keeper":["record_keeper_vale", "vale"],
		"returned_soldier":["the_returned_soldier", "len"],
		"white_hart":["white_hart"]
	}
	return speaker in supporting_speakers.get(actor_id, [])

static func apply_pose(driver: Node, face: Node, eyeline: Node3D, speaking: bool, reacts: bool, profile: Dictionary, entry: Dictionary, direction: Dictionary) -> void:
	if is_instance_valid(driver):
		driver.set_story_listening(true)
	if is_instance_valid(face):
		face.play_story_gesture("")
		face.set_speech_amount(0.0)
		if is_instance_valid(eyeline):
			face.set_focus_target(eyeline)
		var rest_expression := str(profile.get("expression", "neutral"))
		var emotion := str(direction.get("emotion", entry.get("emotion", rest_expression))) if speaking else str(direction.get("listener_emotion", rest_expression))
		face.set_expression(emotion if speaking or reacts else rest_expression)
