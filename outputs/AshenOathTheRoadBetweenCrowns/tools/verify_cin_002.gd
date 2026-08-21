extends SceneTree

const DialogueManager = preload("res://scripts/dialogue_manager.gd")
var failures := 0

func _initialize() -> void:
	var dialogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_dialogue.json"))
	var manager := FileAccess.get_file_as_string("res://scripts/dialogue_manager.gd")
	var hud := FileAccess.get_file_as_string("res://scripts/hud.gd")
	var game := FileAccess.get_file_as_string("res://scripts/game.gd")
	var registry := FileAccess.get_file_as_string("res://scripts/runtime_service_registry.gd")
	for dialogue_id in ["captain_senn", "halvern", "edric_campaign", "white_hart", "crow_shrine_choice"]:
		check(dialogue.has(dialogue_id), "Missing performance-ready dialogue: %s" % dialogue_id)
		check(str(dialogue[dialogue_id].get("voice_direction", "")) != "", "Missing voice direction: %s" % dialogue_id)
		check(typeof(dialogue[dialogue_id].get("presentation", null)) == TYPE_DICTIONARY, "Missing presentation contract: %s" % dialogue_id)
	check("fallback_text" in manager or "fallback" in manager, "Dialogue subtitle fallback contract is missing")
	check("show_dialogue" in manager or "dialogue" in manager, "Dialogue presentation entry point is missing")
	check("speaker_id" in manager and "_speaker_id" in manager, "Dialogue pages do not expose stable speaker IDs")
	check("dialogue_page_changed" in hud, "HUD does not report dialogue turn changes")
	check("_on_dialogue_page_changed" in game, "Game does not refresh dialogue focus per turn")
	check("dialogue_page_changed.connect" in registry, "Dialogue page focus signal is not wired")
	_verify_resolved_turns()
	print("CIN-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _verify_resolved_turns() -> void:
	var manager := DialogueManager.new()
	get_root().add_child(manager)
	manager.load_dialogue("res://data/campaign_dialogue.json")
	manager.setup(null, null)
	var shrine: Dictionary = manager.get_dialogue("crow_shrine_choice")
	var pages: Array = shrine.get("pages", [])
	check(pages.size() >= 3, "Crow Shrine dialogue did not resolve into speaker turns")
	if pages.size() >= 3:
		check(str(pages[1].get("speaker_id", "")) == "sister_anwen", "Anwen turn lost its stable speaker ID")
		check(str(pages[2].get("speaker_id", "")) == "player", "Kael turn lost its stable speaker ID")
	check(bool(shrine.get("subtitle_fallback", false)), "Resolved dialogue is not subtitle-authoritative")
	var presentation: Dictionary = shrine.get("presentation", {})
	check(str(presentation.get("framing", "")) == "intimate_two_shot", "Crow Shrine framing contract was not resolved")
	manager.queue_free()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
