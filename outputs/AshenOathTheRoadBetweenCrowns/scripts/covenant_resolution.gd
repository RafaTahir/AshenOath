extends RefCounted

## The chosen covenant is enacted in the glade. These small physical actions
## preserve control, survive a save, and give peaceful outcomes their own scene.
const STEPS := {
	"expose": [
		["Lay the command ledger", "Kael lays the orders where anyone may read them. The Hart lowers its head: an account that no longer belongs to one house."],
		["Speak the recovered names", "Bram Kett. Sella Vey. Oren. The names travel along the road in living voices. No voice is taken from someone who refused."],
		["Speak of the retreat", "Kael: I obeyed a retreat. People behind us were still calling. I cannot make that right by asking you to confess. I can stay for what comes after."]
	],
	"free": [
		["Return the family tokens", "Kael places the tokens beneath the roots. A name can be restored without making a family's grief a public possession."],
		["Keep the public record", "The orders and the responsibility remain in the ledger. Only the families' private memories are sealed. Edric's actions stay on the record."],
		["Untie the witness", "Kael opens the knot without asking the Hart to forget. The witness steps beyond the circle. What the living remember is now their responsibility."]
	],
	"bind": [
		["Set down the old badge", "Kael puts down the badge that once made leaving feel lawful. This oath will have no command behind it."],
		["Name the limits of the promise", "Kael: I will keep the road and the record. No child's name. No hidden levy. Nobody carries this because I told them to."],
		["Take the willing burden", "The heat enters Kael's hands. He does not kneel until the Hart waits for his answer. Kael: Mine, then. And only while I keep choosing it."]
	]
}
const POSITIONS := [Vector3(-4.5, 0.0, -2.5), Vector3(0.0, 0.0, -5.0), Vector3(4.5, 0.0, -2.5)]

static func begin(game, ending: String) -> void:
	game.pending_ending = ending
	game.story_state.set_flag("covenant_ritual_started", true)
	game.story_state.set_flag("covenant_ritual_step", 0)
	game.active_interactable = null
	game.hud.set_prompt("")
	game.hud.hide_menus()
	game.get_tree().paused = false
	game.audio.set_game_paused(false)
	game._remove_interactable("white_hart")
	restore(game)
	game.hud.toast("The Hart waits. Your promise must be made here, with your own hands.", 6.0)
	game.story_save_pending = true
	game.call_deferred("_persist_story_action")

static func restore(game) -> void:
	if game.current_zone_id != "hart_glade" or game.zone_root == null:
		return
	var ending: String = str(game.pending_ending)
	if not STEPS.has(ending) or bool(game.story_state.get_flag("final_choice_completed", false)):
		return
	var completed: int = int(game.story_state.get_flag("covenant_ritual_step", 0))
	var entries: Array = STEPS[ending]
	game._remove_interactable("white_hart")
	if completed >= entries.size():
		game.story_state.set_flag("covenant_ritual_ready", true)
		return
	for index in entries.size():
		var id := "covenant_%s_%d" % [ending, index]
		if index < completed or game._has_interactable(id):
			continue
		var area = game._make_clue(id, str(entries[index][0]), POSITIONS[index], "", "", Color(0.60, 0.51, 0.34))
		if area == null:
			continue
		area.interaction_type = "covenant"
		area.set_meta("covenant_step", index)
		area.set_meta("covenant_ending", ending)
		area.state_label = "Keep your promise"
		var marker := Label3D.new()
		marker.text = "%d · %s" % [index + 1, str(entries[index][0])]
		marker.font_size = 34
		marker.pixel_size = 0.006
		marker.position.y = 1.15
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.modulate = Color(0.91, 0.84, 0.65)
		marker.no_depth_test = false
		area.add_child(marker)
	if completed < entries.size():
		game.hud.set_guidance_hint(str(entries[completed][0]), 12.0)

static func activate(game, area) -> void:
	var ending := str(area.get_meta("covenant_ending", ""))
	var step := int(area.get_meta("covenant_step", -1))
	if ending != str(game.pending_ending) or not STEPS.has(ending):
		return
	var completed := int(game.story_state.get_flag("covenant_ritual_step", 0))
	if completed >= (STEPS[ending] as Array).size():
		return
	if step != completed:
		game.hud.toast("First, %s." % str(STEPS[ending][completed][0]).to_lower())
		return
	game.story_state.set_flag("covenant_ritual_step", completed + 1)
	game.story_state.record_evidence(str(area.interaction_id), {"title": str(STEPS[ending][step][0]), "text": str(STEPS[ending][step][1]), "kind": "testimony", "zone": "hart_glade"})
	game._mark_interaction_removed(area)
	game.active_interactable = null
	game.hud.set_prompt("")
	area.queue_free()
	game.audio.play_event("shrine_bell", 0.04)
	game.hud.show_dialogue({
		"name": "The covenant", "greeting": str(STEPS[ending][step][1]),
		"lines": [], "pages": [{"speaker": "The road", "speaker_id": "narrator", "text": str(STEPS[ending][step][1]), "beat": "aftermath"}],
		"actions": [], "subtitle_fallback": true
	})
	game.get_tree().paused = true
	game.audio.set_game_paused(true)
	game.story_save_pending = true
	game.call_deferred("_persist_story_action")
	if completed + 1 >= (STEPS[ending] as Array).size():
		game.story_state.set_flag("covenant_ritual_ready", true)
	else:
		game.hud.set_guidance_hint(str(STEPS[ending][completed + 1][0]), 12.0)

static func finish_if_ready(game) -> void:
	if not bool(game.story_state.get_flag("covenant_ritual_ready", false)):
		return
	if bool(game.story_state.get_flag("final_choice_completed", false)):
		return
	var ending := str(game.pending_ending)
	if STEPS.has(ending):
		game._show_ending_consequence(ending)
