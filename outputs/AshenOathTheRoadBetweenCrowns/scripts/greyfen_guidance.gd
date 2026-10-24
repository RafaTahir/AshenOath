extends RefCounted

## Optional presentation, not a quest or reward authority. Only observed actions
## become lessons; pausing, skipping and choosing another quest do not teach them.
const PREFIX := "greyfen_lesson:"
const LESSONS := [
	["move", "Help where you can; the road can wait", "greyfen_cart_work", "greyfen", "Move through the arrival yard", "move_forward"],
	["look", "Take in the village", "greyfen_cart_work", "greyfen", "Turn the camera toward Rook's food cart", "camera_right"],
	["use", "A useful sort of entrance", "greyfen_cart_work", "greyfen", "Use the displayed work target beside Rook", "interact"],
	["journal", "Keep your own account", "notice_board", "greyfen", "Open the journal; tracking a promise remains your choice", "open_inventory"],
	["flour", "Bread before the road", "cart_kitchen_delivery", "greyfen", "Carry Rook's flour to the common kitchen", "interact"],
	["draw", "Check your equipment", "greyfen_detail:dummy", "greyfen", "Draw a blade beside the southern practice dummy", "weapon_sheath"],
	["light", "Let the edge do the work", "greyfen_detail:dummy", "greyfen", "Land a light blade strike on the dummy", "light_attack"],
	["heavy", "Commit, then recover", "greyfen_detail:dummy", "greyfen", "Land a heavy strike; watch the stamina it costs", "heavy_attack"],
	["dodge", "Keep room to move", "greyfen_detail:dummy", "greyfen", "Dodge in the clear practice strip", "dodge"],
	["sheath", "Leave the blade safe", "greyfen_detail:dummy", "greyfen", "Sheathe your blade after practice", "weapon_sheath"],
	["bow_third", "A steady hand", "lr_archery", "greyfen", "Start untimed practice and aim from third person", "aim_bow"],
	["bow_cancel", "A shot you choose not to take", "lr_archery", "greyfen", "Draw, then cancel without firing by leaving aim", "aim_bow"],
	["bow_hit", "Loose into the rings", "lr_archery", "greyfen", "Draw and release a practice arrow into the target", "fire_bow"],
	["bow_first", "Sight along the arrow", "lr_archery", "greyfen", "Zoom to first person and hit the practice target", "camera_zoom_in"],
	["oathfire", "Know where the light will go", "greyfen_detail:dummy", "greyfen", "Charge and release Oathfire toward the safe dummy", "oathfire_beam"],
	["cup", "Across the bridge", "opening_cup_pickup", "greyfen", "Bring Anwen's actual cup to the traveler's tray", "interact"],
	["coat", "A little shelter", "opening_coat_shelter", "greyfen", "Shelter Oren's coat beside Anwen", "interact"],
	["clue", "Marks are not the whole account", "massacre_iron", "greyfen", "Inspect the surviving chapel iron; a maker's mark is not proof of an order", "interact"],
	["prepare", "Useful, not compulsory", "mira", "greyfen", "Ask Mira about preparation; no purchase or crafting is required", "interact"],
	["road", "Before you take the road", "sister_anwen", "greyfen", "Hear Anwen's road concern, then leave when you choose", "interact"],
	["block", "Keep your footing", "", "wychwood", "Guard against a real incoming strike", "block"],
	["parry", "Meet the strike", "", "wychwood", "Begin guarding as a strike arrives to parry", "block"]
]

static func learn(game, id: String) -> void:
	if game == null or not bool(game.game_started) or str(game.story_state.get_flag("greyfen_guide", "")) != "active": return
	if bool(game.story_state.get_flag(PREFIX + id, false)): return
	game.story_state.set_flag(PREFIX + id, true)
	if next_lesson(game.story_state).is_empty():
		game.story_state.set_flag("greyfen_guide", "completed")
		game.hud.toast("The village route is kept in your journal. The road is yours.")
	game.story_save_pending = true
	game.call_deferred("_persist_story_action")

static func _done(state, id: String) -> bool:
	if bool(state.get_flag(PREFIX + id, false)): return true
	var retained := {"flour":"cart_helped", "cup":"opening_cup_delivered", "coat":"opening_coat_sheltered"}
	# Completed work is not repeated. It is not relabelled as learned controls.
	if retained.has(id): return bool(state.get_flag(retained[id], false))
	if id == "clue": return state.has_evidence("massacre_iron")
	return false

static func next_lesson(state) -> Array:
	for lesson: Array in LESSONS:
		if _available(state,str(lesson[0])) and not _done(state, str(lesson[0])): return lesson
	return []

static func _available(state, id: String) -> bool:
	if id in ["cup","coat"]:
		return bool(state.get_flag("opening_care_enabled",false)) and not bool(state.get_flag("greyfen_guide_care_closed",false))
	return true

static func view(state, zone: String) -> Dictionary:
	if state == null or str(state.get_flag("greyfen_guide", "")) != "active" or zone not in ["greyfen", "wychwood"]: return {}
	if bool(state.get_flag("final_choice_completed", false)): return {}
	var lesson := next_lesson(state)
	if lesson.is_empty(): return {}
	# Leaving early never blocks the real objective or drags the player back.
	if zone == "wychwood":
		lesson = LESSONS[-2] if not _done(state, "block") else LESSONS[-1] if not _done(state, "parry") else []
		if lesson.is_empty(): return {}
	var target := str(lesson[2])
	if str(lesson[0]) == "cup" and bool(state.get_flag("opening_cup_carried", false)): target = "opening_cup_deliver"
	return {"id":"greyfen_guide:" + str(lesson[0]), "title":"BEFORE YOU TAKE THE ROAD", "action":str(lesson[4]), "target_ids":[target] if target != "" else [], "destination_zone":str(lesson[3]), "destination_name":str(lesson[1]), "pinpoint":target != "", "guidance_scope":"local", "binding":str(lesson[5])}

static func journal(state) -> String:
	var lines: Array[String] = ["Optional village guidance. Leave, pause or resume whenever you choose. No reward or ending depends on this route."]
	for lesson: Array in LESSONS:
		var observed := bool(state.get_flag(PREFIX + str(lesson[0]), false))
		lines.append(("Learned: " if observed else "Work already done: " if _done(state, str(lesson[0])) else "Not present on this return: " if not _available(state,str(lesson[0])) else "Still available: ") + str(lesson[4]))
	return "\n".join(lines)

static func set_mode(game, mode: String) -> void:
	if mode not in ["active", "paused", "dismissed"]: return
	game.story_state.set_flag("greyfen_guide", mode)
	game.story_state.set_flag("greyfen_guide_offered", true)
	game.story_save_pending = true
	game.call_deferred("_persist_story_action")
	game._refresh_tracker()
	game._resume_game()
	if mode != "active": game.hud.set_guidance_hint("")
