extends SceneTree

const Presence = preload("res://scripts/story_actor_presence.gd")

func _initialize() -> void:
	var passed := true
	for id in ["captain_senn", "halvern"]:
		passed = passed and Presence.remains(id, "")
	for outcome in ["exile", "punished"]:
		passed = passed and not Presence.remains("captain_senn", outcome)
	for outcome in ["released", "destroyed"]:
		passed = passed and not Presence.remains("halvern", outcome)
	passed = passed and Presence.remains("captain_senn", "testimony") and Presence.remains("halvern", "witness")
	passed = passed and Presence.remains("unrelated_villager", "exile") and Presence.remains("halvern", "unknown_legacy_outcome")
	print("STORY ACTOR PRESENCE: %s - undecided/witnesses retained; exact departed outcomes only; logic scope" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
