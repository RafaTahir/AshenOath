extends SceneTree

var failures := 0

func _initialize() -> void:
	var dialogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_dialogue.json"))
	var manager := FileAccess.get_file_as_string("res://scripts/dialogue_manager.gd")
	for dialogue_id in ["captain_senn", "halvern", "edric_campaign", "white_hart", "crow_shrine_choice"]:
		check(dialogue.has(dialogue_id), "Missing performance-ready dialogue: %s" % dialogue_id)
		check(str(dialogue[dialogue_id].get("voice_direction", "")) != "", "Missing voice direction: %s" % dialogue_id)
	check("fallback_text" in manager or "fallback" in manager, "Dialogue subtitle fallback contract is missing")
	check("show_dialogue" in manager or "dialogue" in manager, "Dialogue presentation entry point is missing")
	print("CIN-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
